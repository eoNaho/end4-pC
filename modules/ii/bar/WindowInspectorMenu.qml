import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PopupWindow {
    id: root

    signal menuClosed

    property var activeWindow: null
    property string activeAppClass: ""
    property var iconSource: ""

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitWidth: popupBackground.implicitWidth + root.padding * 2
    implicitHeight: popupBackground.implicitHeight + root.padding * 2

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }
    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    StyledRectangularShadow {
        target: popupBackground
        opacity: popupBackground.opacity
    }

    Rectangle {
        id: popupBackground
        anchors.centerIn: parent
        implicitWidth: 320
        implicitHeight: contentCol.implicitHeight + 18
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: contentCol
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 10

            // ─── Header com Ícone e Dados da Janela ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colPrimaryContainer

                    IconImage {
                        anchors.centerIn: parent
                        source: root.iconSource || Quickshell.iconPath("application-x-executable", "image-missing")
                        implicitSize: 28
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.activeAppClass || Translation.tr("Application")
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.activeWindow?.title || Translation.tr("No window selected")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Ações Rápidas da Janela ───
            StyledText {
                text: Translation.tr("Window Actions")
                font.weight: Font.Medium
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                Layout.leftMargin: 4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 6
                rowSpacing: 6

                // Botão: Flutuante
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: floatBtnMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        MaterialSymbol {
                            text: "picture_in_picture_alt"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Toggle Float")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        id: floatBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["hyprctl", "dispatch", "togglefloating"]);
                            root.close();
                        }
                    }
                }

                // Botão: Tela Cheia
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: fullBtnMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        MaterialSymbol {
                            text: "fullscreen"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Fullscreen")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        id: fullBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["hyprctl", "dispatch", "fullscreen", "1"]);
                            root.close();
                        }
                    }
                }

                // Botão: Enviar para Scratchpad
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: scratchBtnMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        MaterialSymbol {
                            text: "inventory_2"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colTertiary
                        }
                        StyledText {
                            text: Translation.tr("To Scratchpad")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        id: scratchBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", "special:magic"]);
                            root.close();
                        }
                    }
                }

                // Botão: Fechar Janela
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: closeBtnMouse.containsMouse ? Appearance.colors.colErrorContainer : "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        MaterialSymbol {
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colError
                        }
                        StyledText {
                            text: Translation.tr("Close Window")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: closeBtnMouse.containsMouse ? Appearance.colors.colOnErrorContainer : Appearance.colors.colError
                        }
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["hyprctl", "dispatch", "killactive"]);
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
