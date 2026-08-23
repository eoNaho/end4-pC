import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property int minutes: Math.floor(TimerService.pomodoroSecondsLeft / 60)
    readonly property int seconds: TimerService.pomodoroSecondsLeft % 60
    readonly property string formattedTime: `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`

    implicitWidth: vertical ? 32 : (TimerService.pomodoroRunning ? (contentRow.implicitWidth + 12) : 32)
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
                TimerService.resetPomodoro();
            } else {
                TimerService.togglePomodoro();
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            text: TimerService.pomodoroBreak ? "coffee" : "timer"
            iconSize: Appearance.font.pixelSize.larger
            fill: TimerService.pomodoroRunning ? 1 : 0
            color: TimerService.pomodoroRunning
                ? (TimerService.pomodoroBreak ? Appearance.colors.colTertiary : Appearance.colors.colPrimary)
                : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
        }

        StyledText {
            visible: !root.vertical && TimerService.pomodoroRunning
            text: root.formattedTime
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: TimerService.pomodoroBreak ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
        }
    }

    PopupToolTip {
        id: tooltip
        text: TimerService.pomodoroRunning
            ? (TimerService.pomodoroBreak
                ? Translation.tr("Pomodoro: Break (%1) · Left-click pause, Right-click reset").arg(root.formattedTime)
                : Translation.tr("Pomodoro: Focus (%1) · Left-click pause, Right-click reset").arg(root.formattedTime))
            : Translation.tr("Pomodoro Timer · Click to start")
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
