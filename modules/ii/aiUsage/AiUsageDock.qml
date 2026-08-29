import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

/**
 * Auto-hiding edge tab showing AiUsageRing icons for every enabled AI usage
 * provider, one per monitor. Same peek mechanic as modules/ii/dock/Dock.qml
 * (a MouseArea slides via an animated anchor margin, leaving a thin sliver
 * exposed at the screen edge when not hovered), just rotated 90° to sit on
 * a vertical edge instead of the bottom.
 */
Scope {
    id: root

    readonly property bool isRight: Config.options.ai.usage.dock.edge !== "left"
    readonly property int hoverRegionWidth: Math.max(1, Config.options.ai.usage.dock.hoverRegionWidth)

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.ai.usage.dock.screenList;
            if (!list || list.length === 0) return screens;
            return screens.filter(s => list.includes(s.name));
        }

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked && AiUsage.enabledProviders.length > 0

            property var monitor: WM.monitorFor(modelData)
            property bool fullscreenOnThisMonitor: WM.fullscreenOnMonitor(monitor?.name)
            property bool reveal: !fullscreenOnThisMonitor && edgeMouseArea.containsMouse

            color: "transparent"
            anchors { top: true; bottom: true; left: !root.isRight; right: root.isRight }
            implicitWidth: pillBackground.implicitWidth + Appearance.sizes.elevationMargin
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:aiUsageDock"
            WlrLayershell.layer: WlrLayer.Top

            mask: Region { item: edgeMouseArea }

            MouseArea {
                id: edgeMouseArea
                hoverEnabled: true
                width: dockRoot.implicitWidth
                height: pillBackground.implicitHeight + Appearance.sizes.elevationMargin * 2
                anchors {
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: (Config.options.ai.usage.dock.position - 0.5) * (dockRoot.height - pillBackground.implicitHeight)
                    right: root.isRight ? parent.right : undefined
                    left: root.isRight ? undefined : parent.left
                    rightMargin: root.isRight
                        ? (dockRoot.reveal ? 0 : -Math.max(0, pillBackground.implicitWidth - root.hoverRegionWidth))
                        : 0
                    leftMargin: root.isRight
                        ? 0
                        : (dockRoot.reveal ? 0 : -Math.max(0, pillBackground.implicitWidth - root.hoverRegionWidth))
                }

                Behavior on anchors.rightMargin {
                    enabled: root.isRight
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on anchors.leftMargin {
                    enabled: !root.isRight
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: pillBackground
                }

                Item {
                    id: pillContainer
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: root.isRight ? parent.right : undefined
                    anchors.left: root.isRight ? undefined : parent.left
                    width: pillBackground.width
                    height: pillBackground.height

                    // Top organic fillet corner connecting to screen edge
                    RoundCorner {
                        implicitSize: 22
                        color: Appearance.colors.colLayer0
                        corner: root.isRight ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.TopLeft
                        anchors.top: pillBackground.top
                        anchors.topMargin: -implicitSize
                        anchors.right: root.isRight ? parent.right : undefined
                        anchors.left: root.isRight ? undefined : parent.left
                    }

                    // Bottom organic fillet corner connecting to screen edge
                    RoundCorner {
                        implicitSize: 22
                        color: Appearance.colors.colLayer0
                        corner: root.isRight ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.BottomLeft
                        anchors.bottom: pillBackground.bottom
                        anchors.bottomMargin: -implicitSize
                        anchors.right: root.isRight ? parent.right : undefined
                        anchors.left: root.isRight ? undefined : parent.left
                    }

                    Rectangle {
                        id: pillBackground
                        anchors.fill: parent
                        implicitWidth: ringColumn.implicitWidth + 28
                        implicitHeight: ringColumn.implicitHeight + 36

                        color: Appearance.colors.colLayer0
                        border.width: 1
                        border.color: Qt.alpha(Appearance.colors.colOnLayer0, 0.08)

                        topLeftRadius: root.isRight ? 26 : 0
                        bottomLeftRadius: root.isRight ? 26 : 0
                        topRightRadius: root.isRight ? 0 : 26
                        bottomRightRadius: root.isRight ? 0 : 26

                        ColumnLayout {
                            id: ringColumn
                            anchors.centerIn: parent
                            spacing: 20

                            Repeater {
                                model: AiUsage.enabledProviders

                                delegate: MouseArea {
                                    id: ringSlot
                                    required property string modelData
                                    Layout.alignment: Qt.AlignHCenter
                                    hoverEnabled: true
                                    implicitWidth: ring.implicitWidth
                                    implicitHeight: ring.implicitHeight

                                    AiUsageRing {
                                        id: ring
                                        providerId: ringSlot.modelData
                                        ringSize: 48
                                        lineWidth: 4
                                        showPercentLabel: true
                                        vertical: true
                                        isHovered: ringSlot.containsMouse
                                    }

                                    AiUsagePopup {
                                        providerId: ringSlot.modelData
                                        hoverTarget: ringSlot
                                        edgeOverride: root.isRight ? "right" : "left"
                                        thicknessOverride: pillBackground.implicitWidth + 14
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
