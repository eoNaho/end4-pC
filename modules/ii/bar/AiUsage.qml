#pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: Config.options.bar.vertical
    readonly property var providers: AiUsage.enabledProviders
    readonly property real ringSize: Math.max(16, Appearance.sizes.barHeight - 10)

    visible: root.providers.length > 0
    implicitWidth: (visible && providers.length > 0) ? (vertical ? Appearance.sizes.barHeight : (contentLoader.item?.implicitWidth ?? 0) + 8) : 0
    implicitHeight: (visible && providers.length > 0) ? (vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight) : 0

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onPressed: mouse => {
        if (mouse.button === Qt.RightButton) {
            AiUsage.refreshAll();
            Quickshell.execDetached(["notify-send",
                Translation.tr("AI Usage"),
                Translation.tr("Refreshing (manually triggered)"),
                "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 8
            Repeater {
                model: root.providers
                delegate: AiUsageRing {
                    required property string modelData
                    providerId: modelData
                    ringSize: root.ringSize
                    lineWidth: 2
                    vertical: false
                    showPercentLabel: Config.options.ai.usage.showPercentLabel ?? false
                    isHovered: root.containsMouse
                }
            }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: 6
            Repeater {
                model: root.providers
                delegate: AiUsageRing {
                    required property string modelData
                    providerId: modelData
                    ringSize: root.ringSize
                    lineWidth: 2
                    vertical: true
                    showPercentLabel: false
                    isHovered: root.containsMouse
                }
            }
        }
    }

    AiUsagePopup {
        id: aiUsagePopup
        hoverTarget: root
    }
}
