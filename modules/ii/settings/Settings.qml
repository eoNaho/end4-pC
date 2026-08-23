//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Scope {
    id: root

    readonly property real sizeScale: Config.options.settings.style === "minimal" ? 0.75 : 1.0
    property bool isMinimal: Config.options.settings.style === "minimal"

    Component.onCompleted: {
        GlobalStates.settingsOpen = false;
    }

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.settingsOpen

        function hide() {
            GlobalStates.settingsOpen = false;
        }

        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.settingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
                settingsWindow.userMoved = false;
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: GlobalStates.settingsOpen ? 1 : 0
            z: 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: false
                onClicked: panelWindow.hide()
            }
        }

        Rectangle {
            id: settingsWindow
            property real sizeScale: root.sizeScale
            property real defaultWidth: Config.options.settings.style === "minimal" ? Math.min(panelWindow.width - 70, 980 * sizeScale) : Math.min(panelWindow.width - 80, 980 * sizeScale)
            property real defaultHeight: Math.min(panelWindow.height - 80, 665 * sizeScale)
            property real customWidth: 0
            property real customHeight: 0

            width: customWidth > 0 ? Math.max(550, Math.min(panelWindow.width - 40, customWidth)) : defaultWidth
            height: customHeight > 0 ? Math.max(420, Math.min(panelWindow.height - 40, customHeight)) : defaultHeight
            color: Appearance.colors.colLayer0
            border.width: Config.options.settings.borderSize
            border.color: Appearance.getColorFromName(Config.options.settings.borderColor)
            radius: !isMinimal ? Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 5 : Appearance.rounding.screenRounding + 5
            z: 1

            property bool userMoved: false
            anchors.centerIn: userMoved ? undefined : parent

            opacity: GlobalStates.settingsOpen ? 1 : 0
            scale: GlobalStates.settingsOpen ? 1 : 0.95

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            Keys.onTabPressed: (event) => {
                const count = settingsContent.pages.length;
                settingsContent.currentPage = (settingsContent.currentPage + 1) % count;
                settingsContent.showingProfile = false;
                event.accepted = true;
            }

            Keys.onBacktabPressed: (event) => {
                const count = settingsContent.pages.length;
                settingsContent.currentPage = (settingsContent.currentPage - 1 + count) % count;
                settingsContent.showingProfile = false;
                event.accepted = true;
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    const instance = GlobalStates.currentPageInstance;
                    if (instance && instance.contentY !== undefined) {
                        const step = 60;
                        const delta = event.key === Qt.Key_Down ? step : -step;
                        const maxY = Math.max(0, (instance.contentHeight ?? 0) - instance.height);
                        instance.contentY = Math.max(0, Math.min(maxY, instance.contentY + delta));
                    }
                    event.accepted = true;
                    return;
                }
            }

            // Top Drag Handle (Move window)
            Rectangle {
                id: dragHandle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32
                color: "transparent"
                z: 2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeAllCursor
                    drag.target: settingsWindow
                    drag.axis: Drag.XAndYAxis
                    onPressed: settingsWindow.userMoved = true
                    onDoubleClicked: {
                        settingsWindow.userMoved = false
                        settingsWindow.customWidth = 0
                        settingsWindow.customHeight = 0
                    }
                }
            }

            SettingsContent {
                id: settingsContent
                anchors.fill: parent
            }

            // ─── Resize Handles (Borders and Corners) ───────────────────────
            // Right edge
            MouseArea {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                anchors.topMargin: 12; anchors.bottomMargin: 12
                width: 8
                cursorShape: Qt.SizeHorCursor
                z: 10
                property real startX: 0
                property real startW: 0
                onPressed: (mouse) => {
                    startX = mapToItem(null, mouse.x, mouse.y).x
                    startW = settingsWindow.width
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const curX = mapToItem(null, mouse.x, mouse.y).x
                    settingsWindow.customWidth = Math.max(550, startW + (curX - startX))
                }
            }

            // Bottom edge
            MouseArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.leftMargin: 12; anchors.rightMargin: 12
                height: 8
                cursorShape: Qt.SizeVerCursor
                z: 10
                property real startY: 0
                property real startH: 0
                onPressed: (mouse) => {
                    startY = mapToItem(null, mouse.x, mouse.y).y
                    startH = settingsWindow.height
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const curY = mapToItem(null, mouse.x, mouse.y).y
                    settingsWindow.customHeight = Math.max(420, startH + (curY - startY))
                }
            }

            // Left edge
            MouseArea {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                anchors.topMargin: 12; anchors.bottomMargin: 12
                width: 8
                cursorShape: Qt.SizeHorCursor
                z: 10
                property real startX: 0
                property real startW: 0
                property real startWinX: 0
                onPressed: (mouse) => {
                    settingsWindow.userMoved = true
                    startX = mapToItem(null, mouse.x, mouse.y).x
                    startW = settingsWindow.width
                    startWinX = settingsWindow.x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const curX = mapToItem(null, mouse.x, mouse.y).x
                    const dx = curX - startX
                    const newW = Math.max(550, startW - dx)
                    if (newW !== settingsWindow.width) {
                        settingsWindow.x = startWinX + (startW - newW)
                        settingsWindow.customWidth = newW
                    }
                }
            }

            // Bottom-Right Corner (with visual grip)
            Item {
                anchors { right: parent.right; bottom: parent.bottom }
                width: 24
                height: 24
                z: 11

                MaterialSymbol {
                    anchors.centerIn: parent
                    anchors.margins: 4
                    text: "drag_handle"
                    rotation: -45
                    iconSize: 14
                    color: Appearance.colors.colSubtext
                    opacity: cornerResizeArea.containsMouse || cornerResizeArea.pressed ? 0.9 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                MouseArea {
                    id: cornerResizeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeFDiagCursor
                    property real startX: 0
                    property real startY: 0
                    property real startW: 0
                    property real startH: 0
                    onPressed: (mouse) => {
                        startX = mapToItem(null, mouse.x, mouse.y).x
                        startY = mapToItem(null, mouse.x, mouse.y).y
                        startW = settingsWindow.width
                        startH = settingsWindow.height
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed) return
                        const curX = mapToItem(null, mouse.x, mouse.y).x
                        const curY = mapToItem(null, mouse.x, mouse.y).y
                        settingsWindow.customWidth = Math.max(550, startW + (curX - startX))
                        settingsWindow.customHeight = Math.max(420, startH + (curY - startY))
                    }
                    onDoubleClicked: {
                        settingsWindow.customWidth = 0
                        settingsWindow.customHeight = 0
                    }
                }
            }

            // Bottom-Left Corner
            MouseArea {
                anchors { left: parent.left; bottom: parent.bottom }
                width: 16
                height: 16
                cursorShape: Qt.SizeBDiagCursor
                z: 11
                property real startX: 0
                property real startY: 0
                property real startW: 0
                property real startH: 0
                property real startWinX: 0
                onPressed: (mouse) => {
                    settingsWindow.userMoved = true
                    startX = mapToItem(null, mouse.x, mouse.y).x
                    startY = mapToItem(null, mouse.x, mouse.y).y
                    startW = settingsWindow.width
                    startH = settingsWindow.height
                    startWinX = settingsWindow.x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const curX = mapToItem(null, mouse.x, mouse.y).x
                    const curY = mapToItem(null, mouse.x, mouse.y).y
                    const dx = curX - startX
                    const newW = Math.max(550, startW - dx)
                    settingsWindow.x = startWinX + (startW - newW)
                    settingsWindow.customWidth = newW
                    settingsWindow.customHeight = Math.max(420, startH + (curY - startY))
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalStates.settingsOpen = !GlobalStates.settingsOpen; }
        function open(): void   { GlobalStates.settingsOpen = true; }
        function close(): void  { GlobalStates.settingsOpen = false; }
    }

    CompositorGlobalShortcut {
        name: "settingsToggle"
        description: "Toggles settings panel"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen;
    }
}