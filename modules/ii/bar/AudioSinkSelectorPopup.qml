import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

StyledPopup {
    id: root

    ColumnLayout {
        spacing: 8
        width: 260

        RowLayout {
            spacing: 8
            Layout.bottomMargin: 2

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.ClamShell
                text: "headphones"
                iconSize: Appearance.font.pixelSize.large
                implicitSize: 36
                color: Appearance.colors.colSecondaryContainer
                colSymbol: Appearance.colors.colOnSecondaryContainer
            }

            ColumnLayout {
                spacing: -2
                StyledText {
                    text: Translation.tr("Audio Output")
                    font.weight: Font.Medium
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    text: Audio.friendlyDeviceName(Audio.sink)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.6
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180
                }
            }
        }

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
                    : (sinkArea.containsMouse ? Appearance.colors.colLayer1 : "transparent")

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    MaterialSymbol {
                        text: isCurrent ? "check_circle" : "radio_button_unchecked"
                        iconSize: Appearance.font.pixelSize.normal
                        fill: isCurrent ? 1 : 0
                        color: isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colOutline
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Audio.friendlyDeviceName(modelData)
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: isCurrent
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer0
                    }
                }

                MouseArea {
                    id: sinkArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.setDefaultSink(modelData)
                }
            }
        }
    }
}
