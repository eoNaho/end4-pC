import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Scope {
    id: root
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            property var monitor: WM.monitorFor(modelData)
            property bool fullscreenOnThisMonitor: WM.fullscreenOnMonitor(monitor?.name)

            property bool reveal: {
                if (fullscreenOnThisMonitor)
                    return (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse)
                        || GlobalStates.startMenuOpen
                return root.pinned
                    || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse)
                    || activeAppsArea.requestDockShow
                    || dragSlots.requestDockShow
                    || GlobalStates.startMenuOpen
                    || (!ToplevelManager.activeToplevel?.activated)
            }

            exclusiveZone: (root.pinned && !fullscreenOnThisMonitor)
                ? implicitHeight - Appearance.sizes.hyprlandGapsOut
                  - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)
                : 0

            anchors { bottom: true; left: true; right: true }
            implicitWidth: dockBackground.implicitWidth
            WlrLayershell.namespace: "quickshell:dock"
            color: "transparent"

            implicitHeight: (Config.options?.dock.height ?? 70)
                + Appearance.sizes.elevationMargin
                + Appearance.sizes.hyprlandGapsOut

            mask: Region { item: dockMouseArea }

            MouseArea {
                id: dockMouseArea
                height: parent.height
                anchors {
                    top: parent.top
                    topMargin: dockRoot.reveal
                        ? 0
                        : Config.options?.dock.hoverToReveal
                            ? (dockRoot.implicitHeight - Config.options.dock.hoverRegionHeight)
                            : (dockRoot.implicitHeight + 1)
                    horizontalCenter: parent.horizontalCenter
                }
                implicitWidth: dockHoverRegion.implicitWidth + Appearance.sizes.elevationMargin * 2
                hoverEnabled: true

                Behavior on anchors.topMargin {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth

                    Item {
                        id: dockBackground
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }
                        implicitWidth: dockRow.implicitWidth + 5 * 2
                        height: parent.height
                            - Appearance.sizes.elevationMargin
                            - Appearance.sizes.hyprlandGapsOut

                        StyledRectangularShadow {
                            target: dockVisualBackground
                            visible: false
                        }

                        Rectangle {
                            id: dockVisualBackground
                            property real margin: Appearance.sizes.elevationMargin
                            anchors.fill: parent
                            anchors.topMargin:    Appearance.sizes.elevationMargin
                            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
                            color: Config.options.dock.showBackground
                                   ? Appearance.colors.colLayer0 : "transparent"
                            border.width: Config.options.dock.showBackground ? 1 : 0
                            border.color: Appearance.colors.colLayer0Border
                            radius: Appearance.rounding.normal + 6
                        }

                        RowLayout {
                            id: dockRow
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            property real padding: 5
                            property bool hasPinnedApps: (Config.options?.dock.pinnedApps?.length ?? 0) > 0

                            VerticalButtonGroup {
                                Layout.topMargin: 3
                                Layout.leftMargin:  root.pinned
                                    ? Appearance.sizes.hyprlandGapsOut + 4
                                    : Appearance.sizes.hyprlandGapsOut
                                Layout.rightMargin: root.pinned
                                    ? Appearance.sizes.hyprlandGapsOut + 4
                                    : Appearance.sizes.hyprlandGapsOut

                                GroupButton {
                                    baseWidth: 35; baseHeight: 35
                                    visible: Config.options.dock.showPinButton
                                    clickedWidth: baseWidth; clickedHeight: baseHeight + 20
                                    buttonRadius: Appearance.rounding.normal
                                    toggled: root.pinned
                                    onClicked: root.pinned = !root.pinned
                                    contentItem: MaterialSymbol {
                                        text: "keep"
                                        horizontalAlignment: Text.AlignHCenter
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: root.pinned
                                               ? Appearance.m3colors.m3onPrimary
                                               : Appearance.colors.colOnLayer0
                                    }
                                }
                            }

                            DockSeparator {
                                visible: Config.options.dock.showPinButton
                                    && (dockRow.hasPinnedApps
                                        || !(Config.options.dock.showMedia && dockMedia.hasTrack))
                            }

                            DragApps {
                                id: dragSlots
                                visible: dockRow.hasPinnedApps
                                Layout.fillHeight: false
                                Layout.topMargin: 2
                                Layout.leftMargin: Config.options.dock.showPinButton ? 0 : -18
                                pinnedApps:    Config.options?.dock.pinnedApps ?? []
                                buttonPadding: dockRow.padding
                                btnSize:       46
                                btnSpacing:    1
                            }

                            DockSeparator {
                                visible: dockRow.hasPinnedApps && (activeAppsArea.activeUnpinned.length > 0 || (Config.options.dock.showMedia && MprisController.activePlayer !== null))
                            }

                            Item {
                                id: activeAppsArea
                                Layout.fillHeight: true
                                Layout.topMargin: 0
                                property bool requestDockShow: unpinnedPreviewPopup.show

                                property var activeUnpinned: {
                                    return TaskbarApps.apps.filter(
                                        a => !a.pinned
                                          && a.appId !== "SEPARATOR"
                                          && a.toplevels.length > 0
                                    )
                                }
                                property bool hasActiveUnpinned: activeUnpinned.length > 0 || dockMedia.visible

                                implicitWidth:  activeRow.implicitWidth
                                implicitHeight: parent.height

                                Behavior on implicitWidth {
                                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                }

                                RowLayout {
                                    id: activeRow
                                    anchors.fill: parent
                                    Layout.rightMargin: 10
                                    spacing: -4

                                    DockMedia {
                                        id: dockMedia
                                        visible: Config.options.dock.showMedia
                                        Layout.fillHeight: true
                                        Layout.topMargin: 12
                                        Layout.bottomMargin: 8
                                        Layout.leftMargin: 0
                                        buttonPadding: dockRow.padding
                                    }

                                    Repeater {
                                        model: activeAppsArea.activeUnpinned
                                        delegate: DockAppButton {
                                            required property var modelData
                                            appToplevel: modelData
                                            Layout.fillHeight: true
                                            Layout.topMargin: 2
                                            appListRoot: appListBridge
                                            topInset:    dockRow.padding + 8
                                            bottomInset: dockRow.padding + 8
                                        }
                                    }

                                    DockSeparator {
                                        visible: true
                                    }

                                    DockRecordButton {
                                        visible: ScreenRecord.recording || (Config.options?.dock?.showRecorder ?? false)
                                        Layout.fillHeight: true
                                        Layout.topMargin: 2
                                        topInset: dockRow.padding + 8
                                        bottomInset: dockRow.padding + 8
                                    }

                                    DockTrashButton {
                                        Layout.fillHeight: true
                                        Layout.topMargin: 2
                                        topInset: dockRow.padding + 8
                                        bottomInset: dockRow.padding + 8
                                    }
                                }

                                QtObject {
                                    id: appListBridge
                                    property Item lastHoveredButton: null
                                    property bool buttonHovered: false
                                }

                                PopupWindow {
                                    id: unpinnedPreviewPopup
                                    property var appTopLevel: appListBridge.lastHoveredButton?.appToplevel ?? null

                                    property bool shouldShow: (Config.options.dock?.showWindowPreviews ?? true)
                                                              && WM.compositor === "hyprland"
                                                              && (unpinnedPopupMouseArea.containsMouse || appListBridge.buttonHovered)
                                                              && appTopLevel
                                                              && appTopLevel.toplevels
                                                              && appTopLevel.toplevels.length > 0

                                    property bool show: false
                                    property real cachedCenterX: 0

                                    function getCenterX(btn) {
                                        if (!btn || !activeAppsArea.QsWindow) return 0;
                                        return activeAppsArea.QsWindow.mapFromItem(btn, btn.width / 2, 0).x;
                                    }

                                    Connections {
                                        target: appListBridge
                                        function onLastHoveredButtonChanged() {
                                            if (appListBridge.lastHoveredButton)
                                                unpinnedPreviewPopup.cachedCenterX = unpinnedPreviewPopup.getCenterX(appListBridge.lastHoveredButton);
                                        }
                                        function onButtonHoveredChanged() {
                                            if (appListBridge.buttonHovered && appListBridge.lastHoveredButton)
                                                unpinnedPreviewPopup.cachedCenterX = unpinnedPreviewPopup.getCenterX(appListBridge.lastHoveredButton);
                                            unpinnedUpdateTimer.restart();
                                        }
                                    }

                                    onShouldShowChanged: {
                                        unpinnedUpdateTimer.restart();
                                    }

                                    Timer {
                                        id: unpinnedUpdateTimer
                                        interval: 100
                                        onTriggered: {
                                            unpinnedPreviewPopup.show = unpinnedPreviewPopup.shouldShow;
                                        }
                                    }

                                    anchor {
                                        window: activeAppsArea.QsWindow?.window ?? null
                                        adjustment: PopupAdjustment.None
                                        gravity: Edges.Top | Edges.Right
                                        edges: Edges.Top | Edges.Left
                                    }

                                    visible: unpinnedPopupBackground.opacity > 0
                                    color: "transparent"
                                    implicitWidth: activeAppsArea.QsWindow?.window?.width ?? 1
                                    implicitHeight: unpinnedPopupMouseArea.implicitHeight + 30 + Appearance.sizes.elevationMargin * 2

                                    MouseArea {
                                        id: unpinnedPopupMouseArea
                                        anchors.bottom: parent.bottom
                                        implicitWidth:  unpinnedPopupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
                                        implicitHeight: 200 + 30 + Appearance.sizes.elevationMargin * 2
                                        hoverEnabled: true
                                        x: unpinnedPreviewPopup.cachedCenterX - width / 2

                                        StyledRectangularShadow {
                                            target: unpinnedPopupBackground
                                            opacity: unpinnedPreviewPopup.show ? 1 : 0
                                            visible: opacity > 0
                                            Behavior on opacity {
                                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                            }
                                        }

                                        Rectangle {
                                            id: unpinnedPopupBackground
                                            property real padding: 6
                                            opacity: unpinnedPreviewPopup.show ? 1 : 0
                                            visible: opacity > 0
                                            Behavior on opacity {
                                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                            }
                                            clip: true
                                            color: Appearance.colors.colLayer0
                                            border.width: 1
                                            border.color: Appearance.colors.colLayer0Border
                                            radius: Appearance.rounding.large
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Appearance.sizes.elevationMargin
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            implicitHeight: unpinnedPreviewRowLayout.implicitHeight + padding * 2
                                            implicitWidth:  unpinnedPreviewRowLayout.implicitWidth  + padding * 2
                                            Behavior on implicitWidth {
                                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                            }
                                            Behavior on implicitHeight {
                                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                            }

                                            RowLayout {
                                                id: unpinnedPreviewRowLayout
                                                anchors.centerIn: parent
                                                spacing: 8

                                                Repeater {
                                                    model: ScriptModel {
                                                        values: WM.compositor === "hyprland" ? (unpinnedPreviewPopup.appTopLevel?.toplevels ?? []) : []
                                                    }

                                                    RippleButton {
                                                        id: unpinnedWindowBtn
                                                        Layout.preferredWidth: 210
                                                        Layout.preferredHeight: 160
                                                        implicitWidth: 210
                                                        implicitHeight: 160
                                                        clip: true
                                                        required property var modelData
                                                        padding: 0
                                                        buttonRadius: Appearance.rounding.normal

                                                        middleClickAction: () => { unpinnedWindowBtn.modelData?.close() }
                                                        onClicked: { unpinnedWindowBtn.modelData?.activate() }

                                                        contentItem: ColumnLayout {
                                                            anchors.fill: parent
                                                            spacing: 4

                                                            RowLayout {
                                                                Layout.fillWidth: true
                                                                Layout.leftMargin: 8
                                                                Layout.rightMargin: 6
                                                                Layout.topMargin: 4
                                                                spacing: 4

                                                                StyledText {
                                                                    Layout.fillWidth: true
                                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                                    text: unpinnedWindowBtn.modelData?.title ?? ""
                                                                    elide: Text.ElideRight
                                                                    color: Appearance.colors.colOnLayer0
                                                                }

                                                                RippleButton {
                                                                    id: unpinnedCloseBtn
                                                                    colBackground: "transparent"
                                                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                                                    implicitWidth:  22
                                                                    implicitHeight: 22
                                                                    buttonRadius:   Appearance.rounding.full
                                                                    contentItem: MaterialSymbol {
                                                                        anchors.centerIn: parent
                                                                        horizontalAlignment: Text.AlignHCenter
                                                                        text: "close"
                                                                        iconSize: 14
                                                                        color: unpinnedCloseBtn.hovered ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                                                                    }
                                                                    onClicked: { unpinnedWindowBtn.modelData?.close() }
                                                                    StyledToolTip { text: Translation.tr("Close") }
                                                                }
                                                            }

                                                            Item {
                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                Layout.bottomMargin: 6
                                                                clip: true

                                                                ScreencopyView {
                                                                    id: unpinnedScreencopy
                                                                    anchors.centerIn: parent
                                                                    captureSource: unpinnedWindowBtn.modelData
                                                                    live: true
                                                                    paintCursor: true
                                                                    constraintSize: Qt.size(196, 120)
                                                                    layer.enabled: true
                                                                    layer.effect: OpacityMask {
                                                                        maskSource: Rectangle {
                                                                            width:  unpinnedScreencopy.width
                                                                            height: unpinnedScreencopy.height
                                                                            radius: Appearance.rounding.small
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            DockSeparator {
                                visible: Config.options.dock.showAppsButton
                                Layout.leftMargin: Config.options.dock.showAppsButton ? 0 : -3
                            }

                            DockButton {
                                Layout.fillHeight: true
                                Layout.topMargin: 0
                                visible: Config.options.dock.showAppsButton
                                onClicked: GlobalStates.startMenuOpen = !GlobalStates.startMenuOpen
                                topInset:    dockRow.padding + 10
                                bottomInset: dockRow.padding + 7
                                contentItem: MaterialSymbol {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: parent.width / 2
                                    text: "apps"
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
