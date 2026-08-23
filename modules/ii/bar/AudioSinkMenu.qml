import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.volumeMixer
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
        implicitWidth: 320
        implicitHeight: Math.min(540, contentCol.implicitHeight + 20)
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: contentCol.implicitHeight
            clip: true

            ColumnLayout {
                id: contentCol
                width: flickable.width
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

                // ─── Slider de Volume Geral ───
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

                // ─── Lista de Dispositivos de Saída ───
                Repeater {
                    model: Audio.outputDevices
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 36
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
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Appearance.colors.colLayer0Border
                }

                // ─── Seção Mixer por Aplicativo ───
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin: 2
                    spacing: 8

                    MaterialSymbol {
                        text: "apps"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Applications")
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                    }
                }

                Repeater {
                    model: Audio.outputAppNodes
                    delegate: VolumeMixerEntry {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        required property var modelData
                        node: modelData
                    }
                }

                StyledText {
                    visible: !Audio.outputAppNodes || Audio.outputAppNodes.length === 0
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No applications playing audio")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
