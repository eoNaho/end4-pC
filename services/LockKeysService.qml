pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool capsLock: false
    property bool numLock: false

    Timer {
        interval: 400
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            checkProc.running = false;
            checkProc.running = true;
        }
    }

    Process {
        id: checkProc
        command: ["bash", "-c", "caps=0; for f in /sys/class/leds/*::capslock/brightness; do [ -f \"$f\" ] && [ \"$(cat \"$f\" 2>/dev/null)\" -gt 0 ] && caps=1 && break; done; num=0; for f in /sys/class/leds/*::numlock/brightness; do [ -f \"$f\" ] && [ \"$(cat \"$f\" 2>/dev/null)\" -gt 0 ] && num=1 && break; done; echo \"$caps $num\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(" ");
                if (parts.length >= 2) {
                    root.capsLock = parts[0] === "1";
                    root.numLock = parts[1] === "1";
                }
            }
        }
    }
}
