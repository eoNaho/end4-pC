pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 200

    // For percentage-based resources (CPU, RAM, Swap, Disk)
    property list<var> resources: [
        {
            "icon": "planner_review",
            "name": Translation.tr("CPU"),
            "history": ResourceUsage.cpuUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableCpuString,
            "isTemp": false
        },
        {
            "icon": "memory",
            "name": Translation.tr("RAM"),
            "history": ResourceUsage.memoryUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableMemoryString,
            "isTemp": false
        },
        {
            "icon": "swap_horiz",
            "name": Translation.tr("Swap"),
            "history": ResourceUsage.swapUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableSwapString,
            "isTemp": false
        },
        {
            "icon": "storage",
            "name": Translation.tr("Disk"),
            "history": ResourceUsage.diskUsageHistory,
            "maxAvailableString": ResourceUsage.maxAvailableDiskString,
            "isTemp": false
        },
        {
            "icon": "thermometer",
            "name": Translation.tr("Temp"),
            "history": [],       // unused — temp is a scalar, not a rate
            "maxAvailableString": "100°C",
            "isTemp": true
        },
    ]

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 4
        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: parent.padding
            }
            spacing: 8

            SecondaryTabBar {
                id: tabBar

                currentIndex: Persistent.states.overlay.resources.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.resources.tabIndex = tabBar.currentIndex;
                }

                Repeater {
                    model: root.resources.length
                    delegate: SecondaryTabButton {
                        required property int index
                        property var modelData: root.resources[index]
                        buttonIcon: modelData.icon
                        buttonText: modelData.name
                    }
                }
            }

            // Temperature tab — shows °C scalar + color-coded gauge
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                active: root.resources[tabBar.currentIndex]?.isTemp ?? false
                visible: active
                sourceComponent: TempSummary {}
            }

            // Percentage tabs — history graph
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 8
                active: !(root.resources[tabBar.currentIndex]?.isTemp ?? false)
                visible: active
                sourceComponent: ResourceSummary {
                    history: root.resources[tabBar.currentIndex]?.history ?? []
                    maxAvailableString: root.resources[tabBar.currentIndex]?.maxAvailableString ?? "--"
                }
            }
        }
    }

    // Percentage-based resource summary (CPU, RAM, Swap, Disk)
    component ResourceSummary: RowLayout {
        id: resourceSummary
        required property list<real> history
        required property string maxAvailableString
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        ColumnLayout {
            spacing: 2
            StyledText {
                text: (resourceSummary.history[resourceSummary.history.length - 1] * 100).toFixed(1) + "%"
                font {
                    family: Appearance.font.family.numbers
                    variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.huge
                }
            }
            StyledText {
                text: Translation.tr("of %1").arg(resourceSummary.maxAvailableString)
                font {
                    // family: Appearance.font.family.numbers
                    // variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.smallie
                }
                color: Appearance.colors.colSubtext
            }
            Item {
                Layout.fillHeight: true
            }
        }
        Rectangle {
            id: graphBg
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            color: Appearance.colors.colSecondaryContainer
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: graphBg.width
                    height: graphBg.height
                    radius: graphBg.radius
                }
            }
            Graph {
                anchors.fill: parent
                values: root.resources[tabBar.currentIndex]?.history ?? []
                points: ResourceUsage.historyLength
                alignment: Graph.Alignment.Right
            }
        }
    }

    // Temperature summary — scalar °C with color-coded indicator
    component TempSummary: RowLayout {
        id: tempSummary
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12

        // Normalized temperature 0-1 against 100°C max
        readonly property real normalized: Math.min(ResourceUsage.cpuTemp / 100, 1.0)
        // Color: blue (<40) → green (40-60) → yellow (60-75) → orange (75-90) → red (90+)
        readonly property color tempColor: ResourceUsage.cpuTemp >= 90 ? "#e53935"
            : ResourceUsage.cpuTemp >= 75 ? "#FB8C00"
            : ResourceUsage.cpuTemp >= 60 ? "#FDD835"
            : ResourceUsage.cpuTemp >= 40 ? "#43A047"
            : Appearance.colors.colPrimary

        ColumnLayout {
            spacing: 2
            StyledText {
                text: ResourceUsage.cpuTemp > 0
                    ? ResourceUsage.cpuTemp.toFixed(1) + "°C"
                    : "--°C"
                color: tempSummary.tempColor
                font {
                    family: Appearance.font.family.numbers
                    variableAxes: Appearance.font.variableAxes.numbers
                    pixelSize: Appearance.font.pixelSize.huge
                }
            }
            StyledText {
                text: Translation.tr("of %1").arg("100°C")
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
            }
            Item {
                Layout.fillHeight: true
            }
        }

        // Vertical gauge bar
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.small
            color: Appearance.colors.colSecondaryContainer

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * tempSummary.normalized
                radius: Appearance.rounding.small
                color: tempSummary.tempColor
                opacity: 0.7

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
