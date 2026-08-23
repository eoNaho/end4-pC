pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

DockButton {
    id: root

    property bool isHovered: hoverHandler.hovered
    property bool isEmpty: true

    implicitWidth: implicitHeight - topInset - bottomInset

    Process {
        id: trashCheck
        command: ["bash", "-c", "ls -A ~/.local/share/Trash/files/ 2>/dev/null | wc -l"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    const count = parseInt(text.trim());
                    root.isEmpty = (!isNaN(count) && count === 0);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!trashCheck.running) {
                trashCheck.running = true;
            }
        }
    }

    function openTrash() {
        Quickshell.execDetached(["bash", "-c", "dolphin trash:/ || gio open trash:/// || xdg-open ~/.local/share/Trash/files/"]);
    }

    function emptyTrash() {
        Quickshell.execDetached(["bash", "-c", "rm -rf ~/.local/share/Trash/files/* ~/.local/share/Trash/info/* && notify-send 'Trash' 'Trash emptied' -a 'Quickshell'"]);
        root.isEmpty = true;
    }

    onClicked: {
        openTrash();
    }

    altAction: () => {
        trashContextMenu.active = true;
    }

    StyledToolTip {
        text: root.isEmpty ? Translation.tr("Trash (Empty)") : Translation.tr("Trash (Full)")
    }

    contentItem: Item {
        anchors.fill: parent

        Item {
            id: iconArea
            width: 33
            height: 33
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.isHovered ? -6 : 0
            scale: root.isHovered ? (Config.options?.dock?.magnificationScale ?? 1.3) : 1.0
            transformOrigin: Item.Center

            Behavior on scale { 
                NumberAnimation { 
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2 
                } 
            }
            Behavior on anchors.verticalCenterOffset { 
                NumberAnimation { 
                    duration: 180
                    easing.type: Easing.OutCubic 
                } 
            }

            MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.isEmpty ? "delete_outline" : "delete"
                iconSize: 26
                color: root.isEmpty 
                    ? Appearance.colors.colOnLayer0 
                    : Appearance.colors.colPrimary
            }
        }
    }

    PopupWindow {
        id: trashContextMenu
        property bool active: false

        anchor {
            item: root
            edges: Edges.Top
            gravity: Edges.Top
        }

        visible: active
        color: "transparent"
        implicitWidth: trashMenuCard.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: trashMenuCard.implicitHeight + Appearance.sizes.elevationMargin * 2 + 8

        Timer {
            id: autoCloseTimer
            interval: 400
            repeat: false
            onTriggered: {
                if (!trashMenuMouseArea.containsMouse && !root.isHovered) {
                    trashContextMenu.active = false;
                }
            }
        }

        Connections {
            target: root
            function onIsHoveredChanged() {
                if (!root.isHovered && !trashMenuMouseArea.containsMouse) {
                    autoCloseTimer.restart();
                }
            }
        }

        MouseArea {
            id: trashMenuMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onExited: {
                if (!root.isHovered) {
                    autoCloseTimer.restart();
                }
            }

            StyledRectangularShadow {
                target: trashMenuCard
                visible: trashContextMenu.active
            }

            Rectangle {
                id: trashMenuCard
                anchors.centerIn: parent
                implicitWidth: 190
                implicitHeight: trashMenuContent.implicitHeight + 16
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                ColumnLayout {
                    id: trashMenuContent
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 4

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: root.isEmpty ? "delete_outline" : "delete"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Trash")
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    // Open Trash
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: {
                            root.openTrash();
                            trashContextMenu.active = false;
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            MaterialSymbol {
                                text: "folder_open"
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Open Trash")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }

                    // Empty Trash
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        enabled: !root.isEmpty
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colErrorContainer
                        onClicked: {
                            root.emptyTrash();
                            trashContextMenu.active = false;
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            MaterialSymbol {
                                text: "delete_sweep"
                                iconSize: 18
                                color: root.isEmpty ? Appearance.colors.colOnLayer1Inactive : Appearance.colors.colError
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Empty Trash")
                                color: root.isEmpty ? Appearance.colors.colOnLayer1Inactive : Appearance.colors.colError
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }
                }
            }
        }
    }
}
