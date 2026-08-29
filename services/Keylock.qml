pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool capsLock: false
    property bool numLock: false

    property bool initialized: false

    Process {
        id: checkKeylockProc
        running: false
        command: ["bash", "-c", `
            caps=0
            num=0
            for f in /sys/class/leds/*capslock*/brightness; do
                if [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" -gt 0 ]; then caps=1; break; fi
            done
            for f in /sys/class/leds/*numlock*/brightness; do
                if [ -f "$f" ] && [ "$(cat "$f" 2>/dev/null)" -gt 0 ]; then num=1; break; fi
            done
            echo "$caps|$num"
        `]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|");
                if (parts.length < 2) return;
                const newCaps = (parts[0] === "1");
                const newNum = (parts[1] === "1");

                if (!root.initialized) {
                    root.capsLock = newCaps;
                    root.numLock = newNum;
                    root.initialized = true;
                    return;
                }

                if (root.capsLock !== newCaps) {
                    root.capsLock = newCaps;
                }
                if (root.numLock !== newNum) {
                    root.numLock = newNum;
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (!checkKeylockProc.running)
                checkKeylockProc.running = true;
        }
    }

    Component.onCompleted: checkKeylockProc.running = true
}
