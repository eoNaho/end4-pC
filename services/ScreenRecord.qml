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
 * State is driven cleanly by Persistent.states.record,
 * maintained by scripts/videos/record.sh.
 */
Singleton {
    id: root

    readonly property var opts: Config.options.screenRecord
    readonly property bool recording: Persistent.states.record?.enable ?? false
    readonly property bool recordPaused: Persistent.states.record?.paused ?? false
    readonly property double recordStart: (Persistent.states.record?.start ?? 0) > 0
        ? Persistent.states.record.start / 1000 : 0

    function toggleRecordScreen(customArgs = []) {
        if (root.recording) {
            root.stopRecord()
            return
        }
        const args = [Directories.recordScriptPath, "--fullscreen", ...customArgs]
        Quickshell.execDetached(args)
    }

    function recordRegion(customArgs = []) {
        if (root.recording) {
            root.stopRecord()
            return
        }
        const args = [Directories.recordScriptPath, ...customArgs]
        Quickshell.execDetached(args)
    }

    function recordGif(fullscreen = false) {
        if (root.recording) {
            root.stopRecord()
            return
        }
        const args = [Directories.recordScriptPath, "--gif"]
        if (fullscreen) args.push("--fullscreen")
        Quickshell.execDetached(args)
    }

    function stopRecord() {
        Quickshell.execDetached([Directories.recordScriptPath, "--stop"])
    }

    function discardRecord() {
        Quickshell.execDetached([Directories.recordScriptPath, "--discard"])
    }

    function togglePauseRecord() {
        if (!root.recording) return
        Quickshell.execDetached([Directories.recordScriptPath, "--pause"])
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
    GlobalShortcut {
        name: "screenRecordDiscard"
        description: "Cancels and deletes the active recording"
        onPressed: root.discardRecord()
    }

    IpcHandler {
        target: "record"

        function toggleScreen(): void { root.toggleRecordScreen() }
        function recordRegion(): void { root.recordRegion() }
        function recordGif(): void { root.recordGif() }
        function stop(): void { root.stopRecord() }
        function pause(): void { root.togglePauseRecord() }
        function discard(): void { root.discardRecord() }
        function status(): string {
            return JSON.stringify({
                recording: root.recording,
                paused: root.recordPaused,
                start: root.recordStart
            })
        }
    }
}

