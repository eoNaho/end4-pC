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
            implicitWidth: pillBackground.implicitWidth
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:aiUsageDock"
            WlrLayershell.layer: WlrLayer.Top

            mask: Region { item: edgeMouseArea }

            MouseArea {
                id: edgeMouseArea
                hoverEnabled: true
                width: parent.width
                height: pillBackground.implicitHeight
                y: Math.max(0, Math.min(dockRoot.height - height, (dockRoot.height - height) * Config.options.ai.usage.dock.position))
                x: root.isRight
                    ? (dockRoot.reveal ? 0 : Math.max(0, width - root.hoverRegionWidth))
                    : (dockRoot.reveal ? 0 : -Math.max(0, width - root.hoverRegionWidth))

                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: pillBackground
                }

                Rectangle {
                    id: pillBackground
                    anchors.fill: parent
                    implicitWidth: ringColumn.implicitWidth + 36
                    implicitHeight: ringColumn.implicitHeight + 40

                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Qt.alpha(Appearance.colors.colOnLayer0, 0.08)

                    topLeftRadius: root.isRight ? 26 : 0
                    bottomLeftRadius: root.isRight ? 26 : 0
                    topRightRadius: root.isRight ? 0 : 26
                    bottomRightRadius: root.isRight ? 0 : 26

                    // Top organic fillet corner connecting to screen edge
                    RoundCorner {
                        implicitSize: 22
                        color: Appearance.colors.colLayer0
                        corner: root.isRight ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.BottomLeft
                        anchors.top: pillBackground.top
                        anchors.topMargin: -implicitSize
                        anchors.right: root.isRight ? parent.right : undefined
                        anchors.left: root.isRight ? undefined : parent.left
                    }

                    // Bottom organic fillet corner connecting to screen edge
                    RoundCorner {
                        implicitSize: 22
                        color: Appearance.colors.colLayer0
                        corner: root.isRight ? RoundCorner.CornerEnum.TopRight : RoundCorner.CornerEnum.TopLeft
                        anchors.bottom: pillBackground.bottom
                        anchors.bottomMargin: -implicitSize
                        anchors.right: root.isRight ? parent.right : undefined
                        anchors.left: root.isRight ? undefined : parent.left
                    }

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
                                Layout.preferredWidth: ring.implicitWidth
                                Layout.preferredHeight: ring.implicitHeight
                                implicitWidth: ring.implicitWidth
                                implicitHeight: ring.implicitHeight
                                width: implicitWidth
                                height: implicitHeight
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    AiUsage.refreshProvider(ringSlot.modelData);
                                }

                                AiUsageRing {
                                    id: ring
                                    anchors.centerIn: parent
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
