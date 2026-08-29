import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * A single AI provider's usage ring: icon in the middle, animated
 * circular progress showing its most critical limit, and a percentage label.
 * Supports vertical (dock/notch) and horizontal (bar) layouts.
 */
Item {
    id: root

    required property string providerId
    property int ringSize: 48
    property int lineWidth: 4
    property bool showPercentLabel: true
    property bool vertical: true
    property bool isHovered: false

    readonly property var meta: AiUsage.metaFor(providerId)
    readonly property var usage: AiUsage.dataFor(providerId)
    readonly property real percent: AiUsage.worstPercent(providerId)
    readonly property bool available: usage.ok === true
    readonly property color ringColor: root.available ? AiUsage.severityColor(root.percent) : Appearance.colors.colOutline

    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight

    GridLayout {
        id: contentLayout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        rowSpacing: 4
        columnSpacing: 6

        // Ring container with smooth hover scale
        Item {
            id: ringContainer
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: root.ringSize
            Layout.preferredHeight: root.ringSize
            width: root.ringSize
            height: root.ringSize
            scale: root.isHovered ? 1.08 : 1.0

            Behavior on scale {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            CircularProgress {
                id: ring
                anchors.fill: parent
                implicitSize: root.ringSize
                lineWidth: root.lineWidth
                gapAngle: 0
                value: root.available ? Math.min(1, Math.max(0, root.percent / 100)) : 0
                colPrimary: root.ringColor
                colSecondary: Qt.alpha(Appearance.colors.colOnLayer0, 0.15)
                enableAnimation: true
                animationDuration: 1000

                CustomIcon {
                    anchors.centerIn: parent
                    width: root.ringSize - root.lineWidth * 4 - 8
                    height: width
                    source: root.meta.icon + ".svg"
                    colorize: true
                    color: root.available ? Appearance.colors.colOnLayer0 : Appearance.colors.colOutline
                }
            }

            // Pulsing live indicator dot when working / loaded
            Rectangle {
                id: liveDot
                visible: root.available && (root.usage.loading || root.percent > 0)
                width: 7
                height: 7
                radius: 3.5
                color: "#31e07a"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.rightMargin: 1

                SequentialAnimation on opacity {
                    running: liveDot.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 1000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
                }
            }
        }

        // Percentage text label
        StyledText {
            id: percentLabel
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: root.showPercentLabel
            text: root.available ? Math.round(root.percent) + "%" : "--%"
            font.pixelSize: root.vertical ? 12 : Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
