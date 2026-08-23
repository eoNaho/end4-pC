import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    readonly property var monitor: WM.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property string activeWindowAddress: activeWindow?.HyprlandToplevel?.address ? `0x${activeWindow.HyprlandToplevel.address}` : ""
    property bool focusingThisMonitor: WM.focusedMonitor?.name === monitor?.name
    property var biggestWindow: WM.biggestWindowForWorkspace(WM.activeWorkspaceForMonitor(monitor?.name)?.id ?? 1)

    property string activeAppClass: {
        if (!root.focusingThisMonitor || !root.activeWindow?.activated)
            return root.biggestWindow?.class ?? ""
        return root.activeWindow?.appId ?? root.biggestWindow?.class ?? ""
    }

    property var mainAppIconSource: {
        if (!root.activeAppClass || root.activeAppClass === "")
            return Quickshell.iconPath("user-desktop", "image-missing")
        return Quickshell.iconPath(AppSearch.guessIcon(root.activeAppClass), 
            Quickshell.iconPath("user-desktop", "image-missing"))
    }

    implicitWidth:  vertical ? Appearance.sizes.verticalBarWidth : Math.min(colLayout.implicitWidth + 12, 280)
    implicitHeight: vertical ? iconItem.implicitHeight : Appearance.sizes.barHeight

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (inspectorLoader.active && inspectorLoader.item) {
                inspectorLoader.item.close();
            } else {
                inspectorLoader.open();
            }
        }
    }

    // Vertical
    Item {
        id: iconItem
        visible: root.vertical
        anchors.centerIn: parent
        implicitWidth: 22
        implicitHeight: 22

        IconImage {
            anchors.centerIn: parent
            source: root.mainAppIconSource
            implicitSize: 18
            visible: root.mainAppIconSource !== ""
        }
    }

    // Horizontal
    ColumnLayout {
        id: colLayout
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ?
                root.activeWindow?.appId :
                (root.biggestWindow?.class) ?? Translation.tr("Desktop")
        }
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: clickArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow ?
                root.activeWindow?.title :
                (root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${WM.activeWorkspaceForMonitor(monitor?.name)?.id ?? 1}`
        }
    }

    PopupToolTip {
        id: tooltip
        text: Translation.tr("Click to inspect and manage active window")
        extraVisibleCondition: clickArea.containsMouse && !inspectorLoader.active
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

    Loader {
        id: inspectorLoader
        function open() {
            inspectorLoader.active = true;
        }
        active: false
        sourceComponent: WindowInspectorMenu {
            activeWindow: root.activeWindow
            activeAppClass: root.activeAppClass
            iconSource: root.mainAppIconSource
            Component.onCompleted: this.open()
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                inspectorLoader.active = false;
            }
        }
    }
}
