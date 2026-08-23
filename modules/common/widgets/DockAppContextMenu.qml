pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

PopupWindow {
    id: root

    property Item hoverTarget: null
    property var appToplevel: null
    property string appId: appToplevel?.appId ?? ""
    property var desktopEntry: DesktopEntries.heuristicLookup(root.appId)
    property bool isPinned: (Config.options?.dock?.pinnedApps ?? []).includes(root.appId)
    property var toplevels: appToplevel?.toplevels ?? []
    property bool active: false

    signal closeRequested()

    anchor {
        item: root.hoverTarget
        edges: Edges.Top
        gravity: Edges.Top
    }

    visible: root.active
    color: "transparent"
    implicitWidth: menuCard.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: menuCard.implicitHeight + Appearance.sizes.elevationMargin * 2 + 8

    Timer {
        id: autoCloseTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!menuMouseArea.containsMouse && (!root.hoverTarget || !root.hoverTarget.hovered)) {
                root.active = false;
                root.closeRequested();
            }
        }
    }

    Connections {
        target: root.hoverTarget
        function onHoveredChanged() {
            if (root.hoverTarget && !root.hoverTarget.hovered && !menuMouseArea.containsMouse) {
                autoCloseTimer.restart();
            }
        }
    }

    MouseArea {
        id: menuMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onExited: {
            if (!root.hoverTarget || !root.hoverTarget.hovered) {
                autoCloseTimer.restart();
            }
        }

        StyledRectangularShadow {
            target: menuCard
            visible: root.active
        }

        Rectangle {
            id: menuCard
            anchors.centerIn: parent
            implicitWidth: 230
            implicitHeight: menuContent.implicitHeight + 20
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: menuContent
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 4

                // Header: App Icon & Name
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    spacing: 8

                    IconImage {
                        implicitSize: 22
                        source: Quickshell.iconPath(
                            AppSearch.guessIcon(root.appId),
                            "image-missing"
                        )
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.desktopEntry?.name ?? root.appId
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                // Action: Open New Window
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        if (root.desktopEntry) {
                            Quickshell.execDetached(["gtk-launch", root.desktopEntry.id]);
                        } else if (root.appId) {
                            Quickshell.execDetached([root.appId]);
                        }
                        root.active = false;
                        root.closeRequested();
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: root.toplevels.length > 0 ? "add_to_photos" : "launch"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.toplevels.length > 0 ? Translation.tr("New Window") : Translation.tr("Open")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }
                }

                // Action: Toggle Pin to Dock
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        TaskbarApps.togglePin(root.appId);
                        root.active = false;
                        root.closeRequested();
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        MaterialSymbol {
                            text: root.isPinned ? "keep_off" : "keep"
                            iconSize: 18
                            color: Appearance.colors.colSecondary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.isPinned ? Translation.tr("Unpin from Dock") : Translation.tr("Pin to Dock")
                            color: Appearance.colors.colOnLayer0
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }
                }

                // Desktop Actions
                Repeater {
                    model: root.desktopEntry?.actions ?? []
                    delegate: RippleButton {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: {
                            if (typeof modelData.execute === "function") {
                                modelData.execute();
                            } else if (typeof modelData.exec === "function") {
                                modelData.exec();
                            }
                            root.active = false;
                            root.closeRequested();
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            MaterialSymbol {
                                text: "bolt"
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Running windows section
                Loader {
                    Layout.fillWidth: true
                    active: root.toplevels.length > 0
                    visible: active
                    sourceComponent: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colLayer0Border
                        }

                        StyledText {
                            Layout.leftMargin: 4
                            Layout.topMargin: 2
                            text: Translation.tr("Open Windows")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }

                        Repeater {
                            model: root.toplevels
                            delegate: RippleButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 30
                                buttonRadius: Appearance.rounding.small
                                colBackground: modelData.activated ? Appearance.colors.colPrimaryContainer : "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    modelData.activate();
                                    root.active = false;
                                    root.closeRequested();
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 4
                                    spacing: 4

                                    MaterialSymbol {
                                        text: modelData.activated ? "radio_button_checked" : "radio_button_unchecked"
                                        iconSize: 16
                                        color: modelData.activated ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.title.length > 0 ? modelData.title : `${root.appId} (${index + 1})`
                                        elide: Text.ElideRight
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: modelData.activated ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0
                                    }

                                    RippleButton {
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colErrorContainer
                                        onClicked: {
                                            modelData.close();
                                        }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                             text: "close"
                                            iconSize: 14
                                            color: parent.hovered ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                                        }
                                        StyledToolTip { text: Translation.tr("Close Window") }
                                    }
                                }
                            }
                        }

                        // Divider before Close All
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Appearance.colors.colLayer0Border
                        }

                        // Action: Close All Windows
                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colErrorContainer
                            onClicked: {
                                for (let i = 0; i < root.toplevels.length; i++) {
                                    root.toplevels[i].close();
                                }
                                root.active = false;
                                root.closeRequested();
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: "close"
                                    iconSize: 18
                                    color: Appearance.colors.colError
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Close All Windows")
                                    color: Appearance.colors.colError
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
