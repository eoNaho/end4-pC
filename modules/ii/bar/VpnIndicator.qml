import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: 32
    implicitHeight: 32

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Se houver script de VPN ou nm-connection-editor
            Quickshell.execDetached(["bash", "-c", "nm-connection-editor 2>/dev/null || notify-send 'VPN' 'No GUI manager found'"]);
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: VpnService.connected ? "vpn_lock" : "vpn_key"
        iconSize: Appearance.font.pixelSize.larger
        fill: VpnService.connected ? 1 : 0
        color: VpnService.connected
            ? Appearance.colors.colPrimary
            : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
    }

    PopupToolTip {
        id: tooltip
        text: VpnService.connected
            ? Translation.tr("VPN Connected: %1 (%2) · Click for network settings").arg(VpnService.vpnName).arg(VpnService.interfaceName)
            : Translation.tr("VPN: Disconnected · Click for network settings")
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
