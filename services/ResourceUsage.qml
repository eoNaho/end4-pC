pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU and Disk usage.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property real cpuTemp: 0

    property real diskTotal: 1
    property real diskUsed: 0
    property real diskFree: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0
    property list<real> diskUsageHistory: []
    property string maxAvailableDiskString: kbToGbString(diskTotal)

    property string detectedTempPath: ""
    Process {
        id: tempProc
        // Reads CPU temperature from cached sysfs hwmon path directly.
        // If not cached yet, discovers the path once and caches it.
        command: ["bash", "-c", `
            if [ -n "${root.detectedTempPath}" ] && [ -f "${root.detectedTempPath}" ]; then
                awk '{printf "%.1f", $1/1000}' "${root.detectedTempPath}" 2>/dev/null && exit 0
            fi
            for f in /sys/class/hwmon/hwmon*/; do
                for temp_label in "$f"temp*_label; do
                    [ -f "$temp_label" ] || continue
                    label=$(cat "$temp_label" 2>/dev/null)
                    case "$label" in
                        "Tctl"|"Tdie"|"Package id 0")
                            input="\${temp_label%_label}_input"
                            if [ -f "$input" ]; then
                                val=$(awk '{printf "%.1f", $1/1000}' "$input" 2>/dev/null)
                                echo "PATH:$input|$val"
                                exit 0
                            fi
                            ;;
                    esac
                done
            done
            val=$(sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1)
            [ -n "$val" ] && echo "$val"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim()
                if (trimmed.startsWith("PATH:")) {
                    const parts = trimmed.substring(5).split("|")
                    root.detectedTempPath = parts[0]
                    const val = parseFloat(parts[1])
                    if (!isNaN(val)) root.cpuTemp = val
                } else {
                    const val = parseFloat(trimmed)
                    if (!isNaN(val)) root.cpuTemp = val
                }
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2,$3,$4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ").map(Number)
                if (parts.length >= 3) {
                    root.diskTotal = parts[0]
                    root.diskUsed  = parts[1]
                    root.diskFree  = parts[2]
                }
            }
        }
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) memoryUsageHistory.shift()
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) swapUsageHistory.shift()
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) cpuUsageHistory.shift()
    }
    function updateDiskUsageHistory() {
        diskUsageHistory = [...diskUsageHistory, diskUsedPercentage]
        if (diskUsageHistory.length > historyLength) diskUsageHistory.shift()
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateDiskUsageHistory()
    }

    property int _pollCount: 0

    Timer {
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()

            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree  = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal   = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree    = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            const textStat = fileStat.text()
            const cpuLine  = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle  = stats[3]
                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff  = idle  - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }
                previousCpuStats = { total, idle }
            }

            root.updateHistories()

            if ((Config.options?.bar?.resources?.alwaysShowCpuTemp || GlobalStates.overlayOpen) && !tempProc.running) {
                tempProc.running = true
            }

            // Poll disk less frequently (every ~30s) to avoid unnecessary df subprocess forks
            _pollCount++
            if (_pollCount >= 10 || diskTotal <= 1) {
                _pollCount = 0
                if (!diskProc.running) diskProc.running = true
            }
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat;    path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
