pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false
    property string vpnName: ""
    property string interfaceName: ""

    // false quando não há nmcli disponível pra checar nada
    property bool vpnSupported: true

    // Guarda o último nome de conexão VPN visto, mesmo depois de
    // desconectar, pra que toggle() saiba o que reconectar sem
    // precisar perguntar de novo.
    property string lastVpnName: ""

    function toggle() {
        if (root.connected) {
            root.disconnect();
        } else {
            root.connectVpn();
        }
    }

    function disconnect() {
        const name = root.vpnName || root.lastVpnName;
        if (!name)
            return;
        actionProc.exec(["bash", "-c", `nmcli connection down "${name}" 2>/dev/null`]);
    }

    function connectVpn() {
        if (root.lastVpnName) {
            actionProc.exec(["bash", "-c", `nmcli connection up "${root.lastVpnName}" 2>/dev/null`]);
        } else {
            // Sem VPN conhecida ainda — pega a primeira conexão
            // vpn/wireguard configurada no NetworkManager e sobe ela.
            actionProc.exec(["bash", "-c",
                "name=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -E ':vpn$|:wireguard$' | head -n 1 | cut -d: -f1); " +
                "[ -n \"$name\" ] && nmcli connection up \"$name\" 2>/dev/null"
            ]);
        }
    }

    Process {
        id: actionProc
    }

    Connections {
        target: Network
        function onNetworkNameChanged() { if (!checkProc.running) checkProc.running = true; }
        function onWifiStatusChanged() { if (!checkProc.running) checkProc.running = true; }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running) checkProc.running = true;
        }
    }

    Process {
        id: checkProc
        // Ordem de detecção:
        // 1. nmcli (VPN/WireGuard ativa via NetworkManager) — mais confiável, pega o nome certo
        // 2. Interfaces de rede com prefixo conhecido (tun/tap/wg/tailscale/proton/mullvad)
        // 3. Fallback: a rota default está passando por uma interface tun/tap/wg? (pega VPNs
        //    com nome de interface fora do padrão, ex. clientes corporativos)
        command: ["bash", "-c",
            "vpn=0; name=\"\"; iface=\"\"; supported=0; " +
            "if command -v nmcli >/dev/null 2>&1; then " +
            "  supported=1; " +
            "  nm_vpn=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null | grep -E ':vpn:|:wireguard:' | head -n 1); " +
            "  if [ -n \"$nm_vpn\" ]; then vpn=1; name=$(echo \"$nm_vpn\" | cut -d: -f1); iface=$(echo \"$nm_vpn\" | cut -d: -f3); fi; " +
            "fi; " +
            "if [ \"$vpn\" -eq 0 ]; then " +
            "  shopt -s nullglob; " +
            "  for dev in /sys/class/net/tun* /sys/class/net/tap* /sys/class/net/wg* /sys/class/net/tailscale* /sys/class/net/proton* /sys/class/net/mullvad*; do " +
            "    if [ -d \"$dev\" ]; then vpn=1; iface=$(basename \"$dev\"); name=\"$iface\"; break; fi; " +
            "  done; " +
            "fi; " +
            "if [ \"$vpn\" -eq 0 ]; then " +
            "  dr=$(ip route show default 2>/dev/null | grep -oE 'dev [^ ]+' | head -n1 | cut -d' ' -f2); " +
            "  if echo \"$dr\" | grep -qE '^(tun|tap|wg)'; then vpn=1; iface=\"$dr\"; name=\"$dr\"; fi; " +
            "fi; " +
            "echo \"$vpn|$name|$iface|$supported\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length >= 4) {
                    root.connected = parts[0] === "1";
                    root.vpnName = parts[1] || "";
                    root.interfaceName = parts[2] || "";
                    root.vpnSupported = parts[3] === "1";
                    if (root.connected && root.vpnName)
                        root.lastVpnName = root.vpnName;
                }
            }
        }
    }
}
