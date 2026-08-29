#!/usr/bin/env bash

CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
STATE_FILE="$HOME/.local/state/quickshell/states.json"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PID_FILE="${RUNTIME_DIR}/imi-screenrecord.pid"
RECORD_INFO_FILE="${RUNTIME_DIR}/imi-screenrecord.info"
DISCARD_FLAG_FILE="${RUNTIME_DIR}/imi-screenrecord.discard"

# --- Safe Configuration Readers ---
read_config() {
    local key="$1"
    local default_val="$2"
    if [[ -f "$CONFIG_FILE" ]]; then
        local val
        val=$(jq -r "$key // empty" "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$val" && "$val" != "null" ]]; then
            echo "$val"
            return
        fi
    fi
    echo "$default_val"
}

RECORDING_DIR=$(read_config ".screenRecord.savePath" "$HOME/Videos")
CONFIG_AUDIO=$(read_config ".screenRecord.audioSource" "desktop")
CONFIG_ENCODER=$(read_config ".screenRecord.encoder" "auto")
CONFIG_FORMAT=$(read_config ".screenRecord.format" "mp4")
CONFIG_FPS=$(read_config ".screenRecord.fps" "60")
CONFIG_QUALITY=$(read_config ".screenRecord.quality" "high")
CONFIG_COUNTDOWN=$(read_config ".screenRecord.countdown" "0")
CONFIG_CURSOR=$(read_config ".screenRecord.recordCursor" "true")
CONFIG_NOTIFY=$(read_config ".screenRecord.notifyOnComplete" "true")

set_recording_state() {
    local state="$1"
    local start_time="${2:-0}"
    local is_paused="${3:-false}"
    
    mkdir -p "$(dirname "$STATE_FILE")"
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"record":{"enable":false,"start":0,"paused":false}}' > "$STATE_FILE"
    fi

    local tmp
    tmp=$(mktemp)
    jq --argjson en "$state" \
       --argjson st "$start_time" \
       --argjson ps "$is_paused" \
       '.record.enable = $en | .record.start = $st | .record.paused = $ps' \
       "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE"
}

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}

get_epoch_ms() {
    date +%s%3N
}

detect_compositor() {
    local combined
    combined="$(echo "${XDG_CURRENT_DESKTOP:-} ${XDG_SESSION_DESKTOP:-}" | tr '[:upper:]' '[:lower:]')"
    if [[ "$combined" == *"niri"* ]]; then
        echo "niri"
    elif [[ "$combined" == *"hyprland"* ]]; then
        echo "hyprland"
    else
        echo "unknown"
    fi
}

getactivemonitor() {
    if [[ "$(detect_compositor)" == "niri" ]]; then
        niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.is_focused == true) | .output' || echo ""
    else
        hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' || echo ""
    fi
}

# --- Stop / Pause Operations ---
is_recording_active() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    if pgrep -x wf-recorder >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

stop_recording_signal() {
    local discard="${1:-false}"
    if [[ "$discard" == "true" ]]; then
        touch "$DISCARD_FLAG_FILE"
    fi

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            kill -INT "$pid" 2>/dev/null || true
        fi
    fi
    pkill -INT -x wf-recorder 2>/dev/null || true

    # Wait up to 2 seconds for parent process to finalize
    local waited=0
    while is_recording_active && [[ $waited -lt 20 ]]; do
        sleep 0.1
        waited=$((waited + 1))
    done

    # Force kill if still lingering
    if is_recording_active; then
        pkill -9 -x wf-recorder 2>/dev/null || true
        rm -f "$PID_FILE" "$RECORD_INFO_FILE"
        set_recording_state false 0 false
    fi
}

toggle_pause_recording() {
    if ! is_recording_active; then
        return 1
    fi
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || pgrep -x wf-recorder | head -n1)
    if [[ -n "$pid" ]]; then
        kill -USR2 "$pid" 2>/dev/null || kill -USR1 "$pid" 2>/dev/null || true
        local current_paused="false"
        if [[ -f "$STATE_FILE" ]]; then
            current_paused=$(jq -r '.record.paused // false' "$STATE_FILE" 2>/dev/null)
        fi
        if [[ "$current_paused" == "true" ]]; then
            set_recording_state true "$(jq -r '.record.start // 0' "$STATE_FILE" 2>/dev/null)" false
            notify-send "Recording Resumed" "Screen recording continued" -a 'Recorder' -i "media-playback-start" &
        else
            set_recording_state true "$(jq -r '.record.start // 0' "$STATE_FILE" 2>/dev/null)" true
            notify-send "Recording Paused" "Screen recording is paused" -a 'Recorder' -i "media-playback-pause" &
        fi
    fi
}

handle_completed_recording() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return
    fi

    local filename
    filename=$(basename "$file")
    local size_str
    size_str=$(du -h "$file" 2>/dev/null | cut -f1 || echo "")

    if [[ "$CONFIG_NOTIFY" != "true" ]]; then
        return
    fi

    (
        local action
        action=$(notify-send "Recording Saved" "${filename} (${size_str})\nSaved to $(dirname "$file")" \
            -a 'Recorder' \
            -i "video-x-generic" \
            --action="open=Open Video" \
            --action="folder=Open Folder" \
            --action="copy=Copy File" \
            --action="delete=Delete" 2>/dev/null || true)

        case "$action" in
            open)
                xdg-open "$file" & disown
                ;;
            folder)
                xdg-open "$(dirname "$file")" & disown
                ;;
            copy)
                if command -v wl-copy >/dev/null 2>&1; then
                    wl-copy --type video/mp4 < "$file" 2>/dev/null || wl-copy "$file"
                    notify-send "Copied" "File path copied to clipboard" -a 'Recorder' -i "edit-copy" & disown
                fi
                ;;
            delete)
                rm -f "$file"
                notify-send "Deleted" "Recording deleted: $filename" -a 'Recorder' -i "user-trash" & disown
                ;;
        esac
    ) & disown
}

# --- CLI Arguments Parsing ---
MANUAL_REGION=""
AUDIO_MODE=""
FORCE_FULLSCREEN=0
REQUEST_STOP=0
REQUEST_PAUSE=0
REQUEST_DISCARD=0
CUSTOM_FPS=""
CUSTOM_FORMAT=""
CUSTOM_ENCODER=""
CUSTOM_QUALITY=""
CUSTOM_COUNTDOWN=""
NO_CURSOR=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --region)
            if [[ -n "$2" && "$2" != --* ]]; then
                MANUAL_REGION="$2"
                shift 2
            else
                notify-send "Recording Cancelled" "No region specified for --region" -a 'Recorder' &
                exit 1
            fi
            ;;
        --fullscreen)
            FORCE_FULLSCREEN=1
            shift
            ;;
        --sound|--audio)
            AUDIO_MODE="${CONFIG_AUDIO:-desktop}"
            if [[ "$AUDIO_MODE" == "none" ]]; then
                AUDIO_MODE="desktop"
            fi
            shift
            ;;
        --audio-source)
            if [[ -n "$2" ]]; then
                AUDIO_MODE="$2"
                shift 2
            else
                shift
            fi
            ;;
        --no-sound|--mute)
            AUDIO_MODE="none"
            shift
            ;;
        --stop)
            REQUEST_STOP=1
            shift
            ;;
        --pause)
            REQUEST_PAUSE=1
            shift
            ;;
        --discard|--cancel)
            REQUEST_DISCARD=1
            shift
            ;;
        --fps)
            if [[ -n "$2" ]]; then
                CUSTOM_FPS="$2"
                shift 2
            else
                shift
            fi
            ;;
        --format)
            if [[ -n "$2" ]]; then
                CUSTOM_FORMAT="$2"
                shift 2
            else
                shift
            fi
            ;;
        --gif)
            CUSTOM_FORMAT="gif"
            shift
            ;;
        --encoder)
            if [[ -n "$2" ]]; then
                CUSTOM_ENCODER="$2"
                shift 2
            else
                shift
            fi
            ;;
        --quality)
            if [[ -n "$2" ]]; then
                CUSTOM_QUALITY="$2"
                shift 2
            else
                shift
            fi
            ;;
        --delay|--countdown)
            if [[ -n "$2" ]]; then
                CUSTOM_COUNTDOWN="$2"
                shift 2
            else
                shift
            fi
            ;;
        --no-cursor)
            NO_CURSOR=1
            shift
            ;;
        --status)
            if is_recording_active; then
                echo '{"recording": true, "paused": '$(jq -r '.record.paused // false' "$STATE_FILE" 2>/dev/null)'}'
            else
                echo '{"recording": false, "paused": false}'
            fi
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# If an active recording exists, handle toggle / stop / pause / discard
if is_recording_active; then
    if [[ $REQUEST_PAUSE -eq 1 ]]; then
        toggle_pause_recording
        exit 0
    elif [[ $REQUEST_DISCARD -eq 1 ]]; then
        stop_recording_signal true
        exit 0
    else
        stop_recording_signal false
        exit 0
    fi
fi

# If caller only requested stop/pause/discard and nothing is recording, exit
if [[ $REQUEST_STOP -eq 1 || $REQUEST_PAUSE -eq 1 || $REQUEST_DISCARD -eq 1 ]]; then
    set_recording_state false 0 false
    exit 0
fi

# --- Start New Recording (Parent Process) ---
mkdir -p "$RECORDING_DIR"

AUDIO_CHOICE="${AUDIO_MODE:-$CONFIG_AUDIO}"
FORMAT_CHOICE="${CUSTOM_FORMAT:-$CONFIG_FORMAT}"
FPS_CHOICE="${CUSTOM_FPS:-$CONFIG_FPS}"
ENCODER_CHOICE="${CUSTOM_ENCODER:-$CONFIG_ENCODER}"
QUALITY_CHOICE="${CUSTOM_QUALITY:-$CONFIG_QUALITY}"
COUNTDOWN_CHOICE="${CUSTOM_COUNTDOWN:-$CONFIG_COUNTDOWN}"

if [[ -z "$FORMAT_CHOICE" ]]; then
    FORMAT_CHOICE="mp4"
fi
if [[ -z "$FPS_CHOICE" ]]; then
    FPS_CHOICE="60"
fi

# Output File
OUTPUT_EXT="$FORMAT_CHOICE"
IS_GIF=0
if [[ "$FORMAT_CHOICE" == "gif" ]]; then
    IS_GIF=1
    OUTPUT_EXT="mp4"
fi

OUTPUT_FILE="${RECORDING_DIR}/recording_$(getdate).${OUTPUT_EXT}"
FINAL_GIF_FILE=""
if [[ $IS_GIF -eq 1 ]]; then
    FINAL_GIF_FILE="${RECORDING_DIR}/recording_$(getdate).gif"
fi

echo "$OUTPUT_FILE" > "$RECORD_INFO_FILE"
rm -f "$DISCARD_FLAG_FILE"

# Region selection if not fullscreen
TARGET_REGION=""
if [[ $FORCE_FULLSCREEN -eq 0 ]]; then
    if [[ -n "$MANUAL_REGION" ]]; then
        TARGET_REGION="$MANUAL_REGION"
    else
        if ! TARGET_REGION="$(slurp 2>&1)"; then
            notify-send "Recording Cancelled" "Selection was cancelled" -a 'Recorder' &
            rm -f "$RECORD_INFO_FILE"
            exit 0
        fi
    fi
fi

# Optional Countdown
if [[ "$COUNTDOWN_CHOICE" =~ ^[0-9]+$ ]] && (( COUNTDOWN_CHOICE > 0 )); then
    for (( c=COUNTDOWN_CHOICE; c>0; c-- )); do
        notify-send "Recording in $c..." "Prepare your screen" -a 'Recorder' -t 900 -i "timer" &
        sleep 1
    done
fi

# Audio Device Setup & Loopback Cleanup Management
AUDIO_DEV_ARGS=()
NULL_SINK_ID=""
LOOP_SINK_ID=""
LOOP_MIC_ID=""

cleanup_audio() {
    if [[ -n "$LOOP_MIC_ID" ]]; then
        pactl unload-module "$LOOP_MIC_ID" 2>/dev/null || true
        LOOP_MIC_ID=""
    fi
    if [[ -n "$LOOP_SINK_ID" ]]; then
        pactl unload-module "$LOOP_SINK_ID" 2>/dev/null || true
        LOOP_SINK_ID=""
    fi
    if [[ -n "$NULL_SINK_ID" ]]; then
        pactl unload-module "$NULL_SINK_ID" 2>/dev/null || true
        NULL_SINK_ID=""
    fi
}

cleanup() {
    cleanup_audio
    rm -f "$PID_FILE" "$RECORD_INFO_FILE"
    set_recording_state false 0 false
}
trap cleanup EXIT INT TERM

if [[ "$AUDIO_CHOICE" == "desktop" ]]; then
    DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null || pactl info | awk -F': ' '/Default Sink/ {print $2}')
    if [[ -n "$DEFAULT_SINK" ]]; then
        AUDIO_DEV_ARGS=(--audio="${DEFAULT_SINK}.monitor")
    else
        AUDIO_DEV_ARGS=(--audio)
    fi
elif [[ "$AUDIO_CHOICE" == "mic" ]]; then
    DEFAULT_SOURCE=$(pactl get-default-source 2>/dev/null || pactl info | awk -F': ' '/Default Source/ {print $2}')
    if [[ -n "$DEFAULT_SOURCE" ]]; then
        AUDIO_DEV_ARGS=(--audio="${DEFAULT_SOURCE}")
    else
        AUDIO_DEV_ARGS=(--audio)
    fi
elif [[ "$AUDIO_CHOICE" == "both" ]]; then
    DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null || pactl info | awk -F': ' '/Default Sink/ {print $2}')
    DEFAULT_SOURCE=$(pactl get-default-source 2>/dev/null || pactl info | awk -F': ' '/Default Source/ {print $2}')
    
    NULL_SINK_ID=$(pactl load-module module-null-sink sink_name=qs_record_mix sink_properties=device.description="QuickShellMix" 2>/dev/null || echo "")
    if [[ -n "$NULL_SINK_ID" && -n "$DEFAULT_SINK" && -n "$DEFAULT_SOURCE" ]]; then
        LOOP_SINK_ID=$(pactl load-module module-loopback source="${DEFAULT_SINK}.monitor" sink=qs_record_mix latency_msec=20 2>/dev/null || echo "")
        LOOP_MIC_ID=$(pactl load-module module-loopback source="${DEFAULT_SOURCE}" sink=qs_record_mix latency_msec=20 2>/dev/null || echo "")
        AUDIO_DEV_ARGS=(--audio="qs_record_mix.monitor")
    elif [[ -n "$DEFAULT_SINK" ]]; then
        AUDIO_DEV_ARGS=(--audio="${DEFAULT_SINK}.monitor")
    else
        AUDIO_DEV_ARGS=(--audio)
    fi
fi

# Build wf-recorder command arguments
CMD_ARGS=()

if [[ -n "$TARGET_REGION" ]]; then
    CMD_ARGS+=(--geometry "$TARGET_REGION")
else
    ACTIVE_OUTPUT="$(getactivemonitor)"
    if [[ -n "$ACTIVE_OUTPUT" ]]; then
        CMD_ARGS+=(-o "$ACTIVE_OUTPUT")
    fi
fi

if [[ -n "$FPS_CHOICE" ]]; then
    CMD_ARGS+=(-r "$FPS_CHOICE")
fi

CMD_ARGS+=(--pixel-format yuv420p)

if [[ "$CONFIG_CURSOR" == "false" || $NO_CURSOR -eq 1 ]]; then
    CMD_ARGS+=(--no-dmabuf)
fi

SELECTED_CODEC="libx264"
HAS_NVENC=0
if ffmpeg -encoders 2>/dev/null | grep -q "h264_nvenc"; then
    HAS_NVENC=1
elif [[ -e /dev/nvidia0 ]] || lspci 2>/dev/null | grep -iq nvidia; then
    if command -v ffmpeg >/dev/null 2>&1 && ffmpeg -encoders 2>/dev/null | grep -q "nvenc"; then
        HAS_NVENC=1
    fi
fi

if [[ "$ENCODER_CHOICE" == "nvenc" ]] || [[ "$ENCODER_CHOICE" == "auto" && $HAS_NVENC -eq 1 ]]; then
    SELECTED_CODEC="h264_nvenc"
    CMD_ARGS+=(-c "$SELECTED_CODEC")
    case "$QUALITY_CHOICE" in
        low)      CMD_ARGS+=(-p cq=28 -p preset=p2 -p tune=hq) ;;
        medium)   CMD_ARGS+=(-p cq=23 -p preset=p4 -p tune=hq) ;;
        lossless) CMD_ARGS+=(-p cq=0 -p preset=p7 -p tune=lossless) ;;
        high|*)   CMD_ARGS+=(-p cq=19 -p preset=p5 -p tune=hq) ;;
    esac
elif [[ "$ENCODER_CHOICE" == "vaapi" && -e /dev/dri/renderD128 ]]; then
    SELECTED_CODEC="h264_vaapi"
    CMD_ARGS+=(-c "$SELECTED_CODEC" -d /dev/dri/renderD128)
else
    SELECTED_CODEC="libx264"
    CMD_ARGS+=(-c "$SELECTED_CODEC")
    case "$QUALITY_CHOICE" in
        low)      CMD_ARGS+=(-p crf=28 -p preset=faster) ;;
        medium)   CMD_ARGS+=(-p crf=23 -p preset=medium) ;;
        lossless) CMD_ARGS+=(-p crf=0 -p preset=fast) ;;
        high|*)   CMD_ARGS+=(-p crf=18 -p preset=slow) ;;
    esac
fi

if [[ ${#AUDIO_DEV_ARGS[@]} -gt 0 ]]; then
    CMD_ARGS+=("${AUDIO_DEV_ARGS[@]}")
    CMD_ARGS+=(-C aac)
fi

CMD_ARGS+=(-f "$OUTPUT_FILE" -y)

START_MS=$(get_epoch_ms)
set_recording_state true "$START_MS" false

notify-send "Recording Started" "File: $(basename "$OUTPUT_FILE")" -a 'Recorder' -i "media-record" &

wf-recorder "${CMD_ARGS[@]}" &
WF_PID=$!
echo "$WF_PID" > "$PID_FILE"

wait "$WF_PID" || true

# Check if discard was requested
WAS_DISCARDED=0
if [[ -f "$DISCARD_FLAG_FILE" ]]; then
    WAS_DISCARDED=1
    rm -f "$DISCARD_FLAG_FILE"
fi

if [[ $WAS_DISCARDED -eq 1 ]]; then
    rm -f "$OUTPUT_FILE" "$FINAL_GIF_FILE"
    cleanup
    notify-send "Recording Discarded" "The recording was cancelled and deleted." -a 'Recorder' -i "user-trash" &
    exit 0
fi

if [[ $IS_GIF -eq 1 && -f "$OUTPUT_FILE" ]]; then
    notify-send "Generating GIF..." "Optimizing palette and converting" -a 'Recorder' -i "image-x-generic" &
    ffmpeg -y -i "$OUTPUT_FILE" -vf "fps=${FPS_CHOICE:-15},scale=flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" "$FINAL_GIF_FILE" 2>/dev/null || true
    rm -f "$OUTPUT_FILE"
    OUTPUT_FILE="$FINAL_GIF_FILE"
fi

cleanup
handle_completed_recording "$OUTPUT_FILE"