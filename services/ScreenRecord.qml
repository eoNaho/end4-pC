pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions
import qs.services
import qs

/**
 * Screen recording management service.
 * State is driven cleanly by Persistent.states.record.enable,
 * maintained by scripts/videos/record.sh.
 */
Singleton {
    id: root

    readonly property var opts: Config.options.screenRecord
    readonly property bool recording: Persistent.states.record?.enable ?? false
    property bool recordPaused: false

    onRecordingChanged: {
        if (!recording) recordPaused = false
    }

    function toggleRecordScreen() {
        const args = [Directories.recordScriptPath, "--fullscreen"]
        Quickshell.execDetached(args)
    }

    function stopRecord() {
        Quickshell.execDetached([Directories.recordScriptPath])
        Quickshell.execDetached(["bash", "-c", "pkill -INT wf-recorder 2>/dev/null; pkill -INT gpu-screen-recorder 2>/dev/null"])
        Persistent.states.record.enable = false
    }

    function togglePauseRecord() {
        if (!root.recording) return
        pauseProc.running = true
        root.recordPaused = !root.recordPaused
    }
    Process {
        id: pauseProc
        command: ["bash", "-c",
            `kill -USR2 "$(cat "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/imi-screenrecord.pid" 2>/dev/null)" 2>/dev/null || pkill -USR2 wf-recorder 2>/dev/null`]
    }

    GlobalShortcut {
        name: "screenRecordToggle"
        description: "Starts/stops a fullscreen recording"
        onPressed: {
            if (root.recording) root.stopRecord()
            else root.toggleRecordScreen()
        }
    }
    GlobalShortcut {
        name: "screenRecordPause"
        description: "Pauses/resumes the current recording"
        onPressed: root.togglePauseRecord()
    }

    IpcHandler {
        target: "record"

        function toggleScreen(): void { root.toggleRecordScreen() }
        function stop(): void { root.stopRecord() }
        function pause(): void { root.togglePauseRecord() }
        function status(): string {
            return JSON.stringify({
                recording: root.recording,
                paused: root.recordPaused
            })
        }
    }
}
