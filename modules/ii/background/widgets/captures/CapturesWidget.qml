import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "captures"
    hoverEnabled: true

    implicitWidth: 320
    implicitHeight: 280

    property var filesList: []

    function refreshFiles() {
        fetchProc.running = false;
        fetchProc.running = true;
    }

    Component.onCompleted: refreshFiles()

    Process {
        id: fetchProc
        command: ["bash", "-c", "find ~/Pictures/Screenshots ~/Videos/Recordings ~/Imagens/Screenshots ~/Vídeos/Gravações -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.mp4' -o -name '*.mkv' -o -name '*.webp' \\) 2>/dev/null | xargs -r ls -t 2>/dev/null | head -n 4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                root.filesList = lines.map(p => {
                    const parts = p.split("/");
                    const name = parts[parts.length - 1];
                    const isVideo = p.endsWith(".mp4") || p.endsWith(".mkv");
                    return { path: p, name: name, isVideo: isVideo };
                });
            }
        }
    }

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
                anchors.margins: 14
                spacing: 8

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "photo_library"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Captures")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    MaterialSymbol {
                        text: "refresh"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimaryContainer
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshFiles()
                        }
                    }
                }

                // ─── Grid de 4 Miniaturas ───
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: root.filesList
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer1
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: modelData.isVideo ? "" : `file://${modelData.path}`
                                sourceSize: Qt.size(128, 128)
                                visible: !modelData.isVideo
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: modelData.isVideo
                                text: "videocam"
                                iconSize: 28
                                color: Appearance.colors.colPrimary
                            }

                            // Botão Copiar no Hover
                            Rectangle {
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: 4
                                }
                                implicitWidth: 28
                                implicitHeight: 28
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colLayer0
                                opacity: cardMouse.containsMouse ? 0.9 : 0.0

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "content_copy"
                                    iconSize: 14
                                    color: Appearance.colors.colPrimary
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.isVideo) {
                                        Quickshell.execDetached(["bash", "-c", `wl-copy < "${modelData.path}"`]);
                                    } else {
                                        Quickshell.execDetached(["bash", "-c", `wl-copy --type image/png < "${modelData.path}"`]);
                                    }
                                }
                                onDoubleClicked: {
                                    Quickshell.execDetached(["xdg-open", modelData.path]);
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.filesList.length === 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("No captures found")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
