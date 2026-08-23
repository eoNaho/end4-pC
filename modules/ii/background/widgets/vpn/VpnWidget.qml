import QtQuick
import QtQuick.Layouts
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
            radius: Appearance.rounding.verylarge

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
                    id: detailsCol
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    StyledText {
                        text: VpnService.connected ? Translation.tr("Secure Tunnel Active") : Translation.tr("VPN Tunnel Inactive")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: VpnService.connected ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        id: detailText
                        text: VpnService.connected ? `${VpnService.vpnName} (${VpnService.interfaceName})` : Translation.tr("Not routed through a VPN")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // ─── Ações ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        id: toggleBtn
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Appearance.rounding.normal
                        color: toggleMouse.containsMouse
                            ? (VpnService.connected ? Appearance.colors.colError : Appearance.colors.colPrimary)
                            : (VpnService.connected ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: VpnService.connected ? "link_off" : "link"
                                iconSize: 16
                                color: toggleMouse.containsMouse
                                    ? Appearance.colors.colOnPrimary
                                    : (VpnService.connected ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer0)
                            }
                            StyledText {
                                text: VpnService.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: toggleMouse.containsMouse
                                    ? Appearance.colors.colOnPrimary
                                    : (VpnService.connected ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer0)
                            }
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c",
                                    "nm-connection-editor 2>/dev/null || notify-send 'Network' 'No network manager found'"
                                ]);
                            }
                        }
                    }

                    // Ação secundária: abrir configurações de rede
                    Rectangle {
                        id: settingsBtn
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Appearance.rounding.normal
                        color: settingsMouse.containsMouse ? Appearance.colors.colLayer1 : Appearance.colors.colLayer2

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "settings"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["bash", "-c",
                                    "nm-connection-editor 2>/dev/null || notify-send 'Network' 'No network manager found'"
                                ]);
                            }
                        }
                    }
                }
            }
        }
    }
}
