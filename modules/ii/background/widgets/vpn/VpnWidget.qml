import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "vpn"
    hoverEnabled: true

    implicitWidth: 260
    implicitHeight: 180

    Item {
        id: cardWrapper
        anchors.fill: parent

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: VpnService.connected ? "vpn_lock" : "vpn_key"
                        iconSize: Appearance.font.pixelSize.larger
                        color: VpnService.connected ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("VPN & Network")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: VpnService.connected ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                    }
                }

                // ─── Detalhes de Conexão ───
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    StyledText {
                        text: VpnService.connected ? Translation.tr("Secure Tunnel Active") : Translation.tr("VPN Disconnected")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: VpnService.connected ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: VpnService.connected ? `${VpnService.vpnName} (${VpnService.interfaceName})` : Translation.tr("Traffic unencrypted")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                }

                // ─── Botão Ação ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.normal
                    color: btnMouse.containsMouse ? Appearance.colors.colLayer1 : Appearance.colors.colLayer2

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "settings"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Network Settings")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "nm-connection-editor 2>/dev/null || notify-send 'Network' 'No network manager found'"]);
                        }
                    }
                }
            }
        }
    }
}
