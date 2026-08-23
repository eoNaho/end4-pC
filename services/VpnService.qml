pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false
    property string vpnName: ""
    property string interfaceName: ""

    Timer {
        interval: 2500
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
        command: ["bash", "-c", "vpn=0; name=\"\"; iface=\"\"; if command -v nmcli >/dev/null 2>&1; then nm_vpn=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep -E ':vpn:|:wireguard:' | head -n 1); if [ -n \"$nm_vpn\" ]; then vpn=1; name=$(echo \"$nm_vpn\" | cut -d: -f1); iface=$(echo \"$nm_vpn\" | cut -d: -f3); fi; fi; if [ \"$vpn\" -eq 0 ]; then for dev in /sys/class/net/{tun*,tap*,wg*,tailscale*,proton*,mullvad*}; do if [ -d \"$dev\" ]; then vpn=1; iface=$(basename \"$dev\"); name=\"$iface\"; break; fi; done; fi; echo \"$vpn|$name|$iface\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length >= 3) {
                    root.connected = parts[0] === "1";
                    root.vpnName = parts[1] || "";
                    root.interfaceName = parts[2] || "";
                }
            }
        }
    }
}
