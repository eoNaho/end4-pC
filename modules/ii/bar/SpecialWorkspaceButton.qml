import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property var specialToplevels: Hyprland.toplevels?.values?.filter(t => t.workspace?.name?.startsWith("special:")) ?? []
    readonly property int windowCount: specialToplevels.length
    readonly property bool hasWindows: windowCount > 0

    implicitWidth: vertical ? 32 : (root.hasWindows ? (contentRow.implicitWidth + 12) : 32)
    implicitHeight: 32

    Behavior on implicitWidth {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", "special:magic"]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "magic"]);
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: "inventory_2"
            iconSize: Appearance.font.pixelSize.larger
            fill: root.hasWindows ? 1 : 0
            color: root.hasWindows
                ? Appearance.colors.colPrimary
                : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
        }

        StyledText {
            visible: !root.vertical && root.hasWindows
            text: `${root.windowCount}`
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colPrimary
        }
    }

    PopupToolTip {
        id: tooltip
        text: root.hasWindows
            ? Translation.tr("Scratchpad: %1 window(s) hidden · Left-click toggle, Right-click send active").arg(root.windowCount)
            : Translation.tr("Scratchpad (Special Workspace) · Empty. Right-click to send window")
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
