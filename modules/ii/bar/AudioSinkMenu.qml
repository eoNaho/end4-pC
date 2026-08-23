import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: root

    signal menuClosed

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
        implicitWidth: 280
        implicitHeight: contentCol.implicitHeight + 16
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
            spacing: 8

            // ─── Header com título e volume atual ───
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                MaterialSymbol {
                    text: Audio.sink?.audio?.muted ? "volume_off" : "headphones"
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Audio Output")
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colPrimary
                }
            }

            // ─── Slider de Volume ───
            StyledSlider {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.sink?.audio) {
                        Audio.sink.audio.volume = value;
                    }
                }
                configuration: StyledSlider.Configuration.S
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Lista de Dispositivos ───
            Repeater {
                model: Audio.outputDevices
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Appearance.rounding.small
                    readonly property bool isCurrent: modelData.id === Pipewire.defaultAudioSink?.id
                    color: isCurrent
                        ? Appearance.colors.colPrimaryContainer
                        : (devMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent")

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: isCurrent ? "check_circle" : "radio_button_unchecked"
                            iconSize: Appearance.font.pixelSize.normal
                            fill: isCurrent ? 1 : 0
                            color: isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Audio.friendlyDeviceName(modelData)
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0
                        }
                    }

                    MouseArea {
                        id: devMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Audio.setDefaultSink(modelData);
                            root.close();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Botão para abrir o pavucontrol / mixer do sistema ───
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: Appearance.rounding.small
                color: mixerMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    MaterialSymbol {
                        text: "tune"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Open Volume Mixer")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                MouseArea {
                    id: mixerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close();
                        const mixerApp = Config.options.apps.volumeMixer || "pavucontrol";
                        Quickshell.execDetached(["bash", "-c", mixerApp]);
                    }
                }
            }
        }
    }
}
