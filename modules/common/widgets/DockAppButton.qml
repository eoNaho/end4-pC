pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 33
    property real countDotWidth: 10
    property real countDotHeight: 4
    property bool appIsActive: (appToplevel?.toplevels ?? []).some(t => t.activated === true)
    
    // Zoom magnification
    property bool isMagnified: (Config.options?.dock?.magnification ?? true) && root.hovered
    property real magScale: isMagnified ? (Config.options?.dock?.magnificationScale ?? 1.3) : 1.0
    property real magYOffset: isMagnified ? -6 : 0.0

    readonly property bool isSeparator: appToplevel?.appId === "SEPARATOR"
    property var desktopEntry: DesktopEntries.heuristicLookup(appToplevel?.appId ?? "")
    enabled: !isSeparator
    implicitWidth: isSeparator ? 1 : implicitHeight - topInset - bottomInset

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.desktopEntry = DesktopEntries.heuristicLookup(root.appToplevel?.appId ?? "");
        }
    }

    hoverEnabled: true
    onHoveredChanged: {
        if (root.appListRoot) {
            if (hovered) {
                root.appListRoot.lastHoveredButton = root;
                root.appListRoot.buttonHovered = true;
                root.lastFocused = (root.appToplevel?.toplevels?.length ?? 1) - 1;
            } else if (root.appListRoot.lastHoveredButton === root) {
                root.appListRoot.buttonHovered = false;
            }
        }
    }

    Loader {
        active: root.isSeparator
        anchors {
            fill: parent
            topMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
            bottomMargin: dockVisualBackground.margin + dockRow.padding + Appearance.rounding.normal
        }
        sourceComponent: DockSeparator {}
    }

    onClicked: {
        launchAnims.play(Config.options.dock.launchAnimation);
        const toplevels = root.appToplevel?.toplevels ?? [];
        if (toplevels.length === 0) {
            if (root.desktopEntry) Quickshell.execDetached(["gtk-launch", root.desktopEntry.id]);
            return;
        }
        root.lastFocused = (root.lastFocused + 1) % toplevels.length;
        toplevels[root.lastFocused].activate();
    }

    middleClickAction: () => {
        if (root.desktopEntry) Quickshell.execDetached(["gtk-launch", root.desktopEntry.id]);
    }

    altAction: () => {
        if (Config.options.dock?.showContextMenu ?? true) {
            contextMenu.active = !contextMenu.active;
        }
    }

    contentItem: Loader {
        active: !root.isSeparator
        sourceComponent: Item {
            anchors.fill: parent

            Item {
                id: iconArea
                width: root.iconSize
                height: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.magYOffset
                scale: launchAnims.scale * root.magScale
                rotation: launchAnims.rot
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

                Loader {
                    id: iconImageLoader
                    anchors.fill: parent
                    active: !root.isSeparator
                    sourceComponent: IconImage {
                        source: Quickshell.iconPath(AppSearch.guessIcon(root.appToplevel?.appId ?? ""), "image-missing")
                        implicitSize: root.iconSize
                    }
                }

                Loader {
                    active: Config.options.dock.monochromeIcons
                    anchors.fill: iconImageLoader
                    sourceComponent: Item {
                        Desaturate {
                            id: desaturatedIcon
                            visible: false
                            anchors.fill: parent
                            source: iconImageLoader
                            desaturation: 0.8
                        }
                        ColorOverlay {
                            anchors.fill: desaturatedIcon
                            source: desaturatedIcon
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                        }
                    }
                }
            }

            // Running indicator dots
            RowLayout {
                spacing: 3
                anchors {
                    top: iconArea.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                visible: (root.appToplevel?.toplevels?.length ?? 0) > 0

                Repeater {
                    model: Math.min(root.appToplevel?.toplevels?.length ?? 0, 3)
                    delegate: Rectangle {
                        required property int index
                        radius: Appearance.rounding.full
                        implicitWidth: (root.appToplevel?.toplevels?.length === 1) ? root.countDotWidth : root.countDotHeight
                        implicitHeight: root.countDotHeight
                        color: root.appIsActive
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.45)
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                        Behavior on implicitWidth {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    DockLaunchAnimations {
        id: launchAnims
    }

    DockAppContextMenu {
        id: contextMenu
        hoverTarget: root
        appToplevel: root.appToplevel
    }
}