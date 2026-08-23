import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "pomodoro"
    hoverEnabled: true

    implicitWidth: 260
    implicitHeight: 220

    readonly property int minutes: Math.floor(TimerService.pomodoroSecondsLeft / 60)
    readonly property int seconds: TimerService.pomodoroSecondsLeft % 60
    readonly property string formattedTime: `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    readonly property real totalDuration: TimerService.pomodoroBreak ? (Config.options?.timer?.breakDuration ?? 300) : (Config.options?.timer?.focusDuration ?? 1500)
    readonly property real progress: totalDuration > 0 ? (1 - (TimerService.pomodoroSecondsLeft / totalDuration)) : 0

    Item {
        id: cardWrapper
        anchors.fill: parent

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: TimerService.pomodoroBreak ? "coffee" : "timer"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: TimerService.pomodoroBreak ? Translation.tr("Break Time") : Translation.tr("Focus Time")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                // ─── Display de Tempo Central ───
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -4

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formattedTime
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            color: TimerService.pomodoroRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: TimerService.pomodoroRunning ? Translation.tr("Running...") : Translation.tr("Paused")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // ─── Barra de Progresso Suave ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer2

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1.0, Math.max(0.0, root.progress))
                        radius: Appearance.rounding.full
                        color: TimerService.pomodoroBreak ? Appearance.colors.colTertiary : Appearance.colors.colPrimary

                        Behavior on width {
                            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // ─── Botões de Controle ───
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    // Botão Reset
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: Appearance.rounding.full
                        color: resetMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "restart_alt"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        MouseArea {
                            id: resetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TimerService.resetPomodoro()
                        }
                    }

                    // Botão Play / Pause
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: TimerService.pomodoroRunning ? "pause" : "play_arrow"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TimerService.togglePomodoro()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
