import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PopupWindow {
    id: root

    signal menuClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitWidth: popupBackground.implicitWidth + root.padding * 2
    implicitHeight: popupBackground.implicitHeight + root.padding * 2

    property var filesList: []

    function open() {
        refreshFiles();
        root.visible = true;
    }

    function close() {
        root.visible = false;
        root.menuClosed();
    }

    function refreshFiles() {
        fetchProc.running = false;
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        command: ["bash", "-c", "find ~/Pictures/Screenshots ~/Videos/Recordings ~/Imagens/Screenshots ~/Vídeos/Gravações -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.mp4' -o -name '*.mkv' -o -name '*.webp' \\) 2>/dev/null | xargs -r ls -t 2>/dev/null | head -n 6"]
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
        implicitWidth: 340
        implicitHeight: Math.min(500, contentCol.implicitHeight + 20)
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

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                MaterialSymbol {
                    text: "photo_library"
                    iconSize: Appearance.font.pixelSize.normal + 2
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Recent Captures & Recordings")
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                }

                MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refreshFiles()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Lista de Arquivos ───
            Repeater {
                model: root.filesList
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: Appearance.rounding.small
                    color: itemMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        // Preview Thumbnail / Ícone
                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer2
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: modelData.isVideo ? "" : `file://${modelData.path}`
                                sourceSize: Qt.size(64, 64)
                                visible: !modelData.isVideo
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: modelData.isVideo
                                text: "videocam"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colPrimary
                            }
                        }

                        // Nome do Arquivo
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            text: modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer0
                        }

                        // Ação: Copiar
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: Appearance.rounding.full
                            color: copyMouse.containsMouse ? Appearance.colors.colPrimaryContainer : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "content_copy"
                                iconSize: 16
                                color: copyMouse.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            MouseArea {
                                id: copyMouse
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
                            }
                        }

                        // Ação: Abrir
                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: Appearance.rounding.full
                            color: openMouse.containsMouse ? Appearance.colors.colPrimaryContainer : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "open_in_new"
                                iconSize: 16
                                color: openMouse.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            MouseArea {
                                id: openMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["xdg-open", modelData.path]);
                                    root.close();
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onDoubleClicked: {
                            Quickshell.execDetached(["xdg-open", modelData.path]);
                            root.close();
                        }
                    }
                }
            }

            StyledText {
                visible: root.filesList.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.topMargin: 12
                Layout.bottomMargin: 12
                text: Translation.tr("No recent captures found")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
}
