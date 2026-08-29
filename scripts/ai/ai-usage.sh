#!/usr/bin/env bash
# Fetches usage/rate-limit data for a local AI CLI tool (Claude Code, Codex, ...)
# and prints it as normalized JSON on stdout:
#
#   {"id":"claude","ok":true,"plan":"max","limits":[
#     {"key":"session","label":"Current session","percent":93,"resetsAt":1787961600}]}
#   {"id":"claude","ok":false,"error":"missing_credentials"}
#
# Always emits valid JSON, never an empty stdout, so callers get a single
# parsing path regardless of success/failure.
#
# Usage: ai-usage.sh <claude|codex>

set -uo pipefail

provider="${1:-}"

fail() {
    jq -n --arg id "$provider" --arg error "$1" '{id: $id, ok: false, error: $error}'
    exit 0
}

[[ -z "$provider" ]] && { echo '{"ok":false,"error":"missing_provider"}'; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "{\"id\":\"$provider\",\"ok\":false,\"error\":\"missing_jq\"}"; exit 1; }
command -v curl >/dev/null 2>&1 || fail "missing_curl"

# Converts an ISO-8601 timestamp to epoch seconds. Empty/invalid -> empty string.
iso_to_epoch() {
    [[ -z "$1" || "$1" == "null" ]] && return
    date -d "$1" +%s 2>/dev/null
}

case "$provider" in
claude)
    creds_file="$HOME/.claude/.credentials.json"
    [[ -f "$creds_file" ]] || fail "missing_credentials"

    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    [[ -n "$token" ]] || fail "missing_token"

    expires_at=$(jq -r '.claudeAiOauth.expiresAt // empty' "$creds_file" 2>/dev/null)
    if [[ -n "$expires_at" ]]; then
        now_ms=$(( $(date +%s) * 1000 ))
        [[ "$expires_at" -lt "$now_ms" ]] && fail "expired"
    fi

    # Header goes through stdin (curl -K -) so the token never appears in argv
    # (and therefore never in /proc/<pid>/cmdline or process listings).
    response=$(printf 'header = "Authorization: Bearer %s"\n' "$token" | curl -s --max-time 10 -K - \
        -H "Accept: application/json" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1.34" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    [[ -n "$response" ]] && echo "$response" | jq -e . >/dev/null 2>&1 || fail "request_failed"
    if echo "$response" | jq -e '.type == "error"' >/dev/null 2>&1; then
        err_type=$(echo "$response" | jq -r '.error.type // "api_error"')
        fail "$err_type"
    fi
    echo "$response" | jq -e 'has("limits")' >/dev/null 2>&1 || fail "unexpected_response"

    label_for_kind() {
        case "$1" in
        session) echo "Current session" ;;
        weekly_all) echo "All models" ;;
        weekly_opus) echo "Opus (weekly)" ;;
        weekly_sonnet) echo "Sonnet (weekly)" ;;
        *) echo "$1" | tr '_' ' ' | sed -E 's/(^| )(.)/\1\U\2/g' ;;
        esac
    }

    limits_json="[]"
    len=$(echo "$response" | jq '(.limits // []) | length' 2>/dev/null)
    for ((i = 0; i < ${len:-0}; i++)); do
        entry=$(echo "$response" | jq -c ".limits[$i]")
        kind=$(echo "$entry" | jq -r '.kind // empty')
        percent=$(echo "$entry" | jq -r '.percent // 0')
        resets_at_iso=$(echo "$entry" | jq -r '.resets_at // empty')
        resets_at_epoch=$(iso_to_epoch "$resets_at_iso")
        label=$(label_for_kind "$kind")
        limits_json=$(echo "$limits_json" | jq -c \
            --arg key "$kind" --arg label "$label" \
            --argjson percent "${percent:-0}" \
            --argjson resetsAt "${resets_at_epoch:-null}" \
            '. + [{key: $key, label: $label, percent: $percent, resetsAt: $resetsAt}]')
    done

    jq -n --arg id "$provider" --argjson limits "$limits_json" '{id: $id, ok: true, plan: null, limits: $limits}'
    ;;

codex)
    auth_file="$HOME/.codex/auth.json"
    [[ -f "$auth_file" ]] || fail "missing_credentials"

    token=$(jq -r '.tokens.access_token // empty' "$auth_file" 2>/dev/null)
    account_id=$(jq -r '.tokens.account_id // empty' "$auth_file" 2>/dev/null)
    [[ -n "$token" && -n "$account_id" ]] || fail "missing_token"

    codex_version=$(jq -r '.latest_version // empty' "$HOME/.codex/version.json" 2>/dev/null)
    codex_version="${codex_version:-0.0.0}"

    response=$(printf 'header = "Authorization: Bearer %s"\n' "$token" | curl -s --max-time 10 -K - \
        -H "Accept: application/json" \
        -H "chatgpt-account-id: $account_id" \
        -H "originator: codex_cli_rs" \
        -H "User-Agent: codex_cli_rs/${codex_version}" \
        "https://chatgpt.com/backend-api/codex/usage" 2>/dev/null)

    [[ -n "$response" ]] && echo "$response" | jq -e . >/dev/null 2>&1 || fail "request_failed"
    echo "$response" | jq -e '.rate_limit' >/dev/null 2>&1 || fail "unexpected_response"

    plan=$(echo "$response" | jq -r '.plan_type // empty')

    limits_json="[]"
    for window_key_label in "primary_window:session" "secondary_window:weekly"; do
        window_key="${window_key_label%%:*}"
        norm_key="${window_key_label##*:}"
        window=$(echo "$response" | jq -c ".rate_limit.${window_key} // empty")
        [[ -z "$window" || "$window" == "null" ]] && continue

        percent=$(echo "$window" | jq -r '.used_percent // 0')
        reset_epoch=$(echo "$window" | jq -r '.reset_at // empty')
        label=$([[ "$norm_key" == "session" ]] && echo "Current session" || echo "Weekly")
        limits_json=$(echo "$limits_json" | jq -c \
            --arg key "$norm_key" --arg label "$label" \
            --argjson percent "${percent:-0}" \
            --argjson resetsAt "${reset_epoch:-null}" \
            '. + [{key: $key, label: $label, percent: $percent, resetsAt: $resetsAt}]')
    done

    jq -n --arg id "$provider" --arg plan "$plan" --argjson limits "$limits_json" \
        '{id: $id, ok: true, plan: ($plan // null), limits: $limits}'
    ;;

cursor)
    cursor_creds="$HOME/.config/Cursor/User/globalStorage/state.vscdb"
    if [[ ! -f "$cursor_creds" ]] && [[ ! -f "$HOME/.cursor/credentials.json" ]]; then
        fail "missing_credentials"
    fi
    fail "missing_credentials"
    ;;

*)
    fail "unknown_provider"
    ;;
esac
