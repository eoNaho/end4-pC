pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.ii.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

DockButton {
    id: root

    required property string providerId
    property bool isHovered: root.hovered
    readonly property var meta: AiUsage.metaFor(providerId)
    readonly property var usage: AiUsage.dataFor(providerId)
    readonly property real percent: AiUsage.worstPercent(providerId)
    readonly property bool available: usage.ok === true

    implicitWidth: implicitHeight - topInset - bottomInset

    altAction: () => {
        AiUsage.refreshProvider(root.providerId);
        Quickshell.execDetached(["notify-send",
            Translation.tr("AI Usage"),
            Translation.tr("Refreshing %1").arg(root.meta.name),
            "-a", "Shell"
        ]);
    }

    contentItem: Item {
        anchors.fill: parent

        Item {
            id: iconArea
            width: 38
            height: 38
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

            AiUsageRing {
                anchors.centerIn: parent
                providerId: root.providerId
                ringSize: 36
                lineWidth: 3
                vertical: true
                showPercentLabel: false
                isHovered: root.isHovered
            }
        }
    }

    AiUsagePopup {
        id: popup
        providerId: root.providerId
        hoverTarget: root
        edgeOverride: "bottom"
    }
}
