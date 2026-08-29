pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common

/**
 * Tracks local usage/rate-limit quotas for AI CLI tools (Claude Code, Codex, ...)
 * by shelling out to scripts/ai/ai-usage.sh, which talks to each tool's own
 * locally-stored OAuth credentials. See that script for the data contract.
 *
 * Each enabled provider gets its own Process + Timer pair (via Instantiator),
 * so adding/removing providers from Config.options.ai.usage.providers just
 * works without touching this file.
 */
Singleton {
    id: root

    readonly property string scriptPath: Quickshell.shellPath("scripts/ai/ai-usage.sh")
    readonly property int fetchInterval: Math.max(1, Config.options.ai.usage.fetchInterval) * 60 * 1000
    readonly property var enabledProviders: Config.options.ai.usage.enable
        ? Array.from(Config.options.ai.usage.providers ?? [])
        : []

    // Static metadata for known providers. Adding a provider elsewhere (the
    // shell script + Config.options.ai.usage.providers) is enough for it to
    // show up; this just supplies a nicer name/icon when known.
    readonly property var providerMeta: ({
        claude: { name: "Claude", icon: "claude-symbolic" },
        codex: { name: "Codex", icon: "openai-symbolic" },
        cursor: { name: "Cursor", icon: "cursor-symbolic" }
    })

    // id -> {ok, loading, plan, limits: [{key, label, percent, resetsAt}], error, fetchedAt}
    property var providers: ({})

    function metaFor(id) {
        return root.providerMeta[id] ?? { name: id, icon: "spark-symbolic" }
    }

    function dataFor(id) {
        return root.providers[id] ?? { ok: false, loading: true, plan: null, limits: [] }
    }

    function setProviderData(id, data) {
        let updated = Object.assign({}, root.providers)
        updated[id] = data
        root.providers = updated
    }

    // What the ring should show: the highest (most critical) percentage
    // among a provider's limits.
    function worstPercent(id) {
        const d = root.dataFor(id)
        if (!d.ok || !d.limits || d.limits.length === 0) return 0
        return d.limits.reduce((max, l) => Math.max(max, l.percent ?? 0), 0)
    }

    // Colors matching the design: green -> yellow -> orange -> red
    function severityColor(percent) {
        if (percent >= 90) return "#ff453a"
        if (percent >= 70) return "#FB8C00"
        if (percent >= 50) return "#e9ff3f"
        return "#31e07a"
    }

    // Turns an epoch-seconds reset time into a short relative string ("42 min",
    // "3h", or a weekday for anything further out), for the popup detail rows.
    function formatResetsIn(epochSeconds) {
        if (!epochSeconds) return ""
        const diffMs = epochSeconds * 1000 - Date.now()
        if (diffMs <= 0) return ""
        const mins = Math.round(diffMs / 60000)
        if (mins < 60) return mins + " min"
        const hours = Math.round(mins / 60)
        if (hours < 48) return hours + "h"
        return new Date(epochSeconds * 1000).toLocaleDateString(Qt.locale(), "ddd, MMM d")
    }

    function refreshAll() {
        for (let i = 0; i < fetchers.count; i++) {
            const obj = fetchers.objectAt(i)
            if (obj) obj.fetch()
        }
    }

    function refreshProvider(id) {
        for (let i = 0; i < fetchers.count; i++) {
            const obj = fetchers.objectAt(i)
            if (obj && obj.providerId === id) {
                obj.fetch()
                return
            }
        }
    }

    Instantiator {
        id: fetchers
        model: root.enabledProviders

        delegate: Item {
            id: fetcherItem
            required property string modelData
            readonly property string providerId: modelData

            function fetch() {
                if (proc.running) return
                root.setProviderData(fetcherItem.providerId,
                    Object.assign({}, root.dataFor(fetcherItem.providerId), { loading: true }))
                proc.running = true
            }

            Process {
                id: proc
                command: ["bash", root.scriptPath, fetcherItem.providerId]
                stdout: StdioCollector {
                    onStreamFinished: {
                        if (text.length === 0) {
                            root.setProviderData(fetcherItem.providerId, { ok: false, loading: false, error: "empty_response", limits: [] })
                            return
                        }
                        try {
                            const parsed = JSON.parse(text)
                            root.setProviderData(fetcherItem.providerId,
                                Object.assign({ loading: false, fetchedAt: Date.now() }, parsed))
                        } catch (e) {
                            console.error("[AiUsage] JSON parse error for", fetcherItem.providerId, ":", e.message)
                            root.setProviderData(fetcherItem.providerId, { ok: false, loading: false, error: "parse_error", limits: [] })
                        }
                    }
                }
            }

            Timer {
                interval: root.fetchInterval
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: fetcherItem.fetch()
            }
        }
    }
}
