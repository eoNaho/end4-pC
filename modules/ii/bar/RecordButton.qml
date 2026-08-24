import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    signal clicked(event: var)

    property bool material: false
    property bool showTextOnHover: false
    property bool vertical: Config.options.bar.vertical

    property bool isRecording: Persistent.states.record?.enable ?? false
    property bool isPaused: Persistent.states.record?.paused ?? false
    readonly property double recordStart: (Persistent.states.record?.start ?? 0) > 0
        ? Persistent.states.record.start / 1000 : 0
    property int elapsedSeconds: 0
    property double pauseStartTime: 0
    property double totalPausedDuration: 0

    onIsRecordingChanged: {
        if (!isRecording) {
            elapsedSeconds = 0;
            pauseStartTime = 0;
            totalPausedDuration = 0;
        }
    }

    onIsPausedChanged: {
        if (isPaused) {
            pauseStartTime = Date.now() / 1000;
        } else if (pauseStartTime > 0) {
            totalPausedDuration += (Date.now() / 1000 - pauseStartTime);
            pauseStartTime = 0;
        }
    }

    function formatTime(s) {
        return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
    }

    Timer {
        interval: 250
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: {
            if (root.recordStart > 0) {
                const now = Date.now() / 1000;
                root.elapsedSeconds = Math.max(0, Math.floor(now - root.recordStart - root.totalPausedDuration));
            }
        }
    }

    readonly property bool hoveredState: mouseArea.containsMouse
    readonly property bool textVisible: !root.vertical && (root.isRecording || (root.showTextOnHover && hoveredState))

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.isRecording) {
                    ScreenRecord.togglePauseRecord();
                } else {
                    GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.isRecording) {
                    ScreenRecord.discardRecord();
                }
            } else {
                root.clicked(mouse);
            }
        }
    }

    StyledToolTip {
        visible: root.hoveredState
        text: {
            if (root.isRecording) {
                if (root.isPaused) {
                    return Translation.tr("Recording Paused (%1)\nLeft-click: Stop\nRight-click: Resume\nMiddle-click: Discard").arg(root.formatTime(root.elapsedSeconds));
                }
                return Translation.tr("Recording (%1)\nLeft-click: Stop\nRight-click: Pause\nMiddle-click: Discard").arg(root.formatTime(root.elapsedSeconds));
            }
            return Translation.tr("Screen Recorder\nLeft-click: Record Region\nRight-click: Open Overlay");
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        implicitHeight: Math.max(26, layout.implicitHeight + 4)
        implicitWidth: {
            if (root.isRecording) return layout.implicitWidth + 20
            if (root.textVisible) return layout.implicitWidth + 24
            if (root.material && root.hoveredState) return 54
            return Math.max(26, layout.implicitWidth + 12)
        }

        radius: root.isRecording ? Appearance.rounding.normal : implicitHeight / 2
        color: {
            if (root.isRecording) {
                if (root.isPaused) {
                    return Appearance.colors.colSecondaryContainer
                }
                return Appearance.colors.colError
            }
            if (root.hoveredState) {
                return root.material
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colLayer1Hover
            }
            return root.material
                ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                : "transparent"
        }

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            id: layout
            anchors.centerIn: parent
            spacing: 6

            // Pulsing dot indicator when recording
            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isRecording
                color: root.isPaused ? Appearance.colors.colSecondary : Appearance.colors.colOnError

                SequentialAnimation on opacity {
                    running: root.isRecording && !root.isPaused
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.2; duration: 500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.2; to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                }
            }

            MaterialSymbol {
                id: symbol
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.isRecording) {
                        return root.isPaused ? "pause" : "stop"
                    }
                    return "screen_record"
                }
                iconSize: Appearance.font.pixelSize.large
                color: {
                    if (root.isRecording) {
                        return root.isPaused ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnError
                    }
                    if (root.hoveredState) {
                        return root.material ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
                    }
                    return root.material ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            StyledText {
                id: textLabel
                anchors.verticalCenter: parent.verticalCenter
                visible: root.textVisible || root.isRecording
                width: implicitWidth
                text: root.isRecording ? root.formatTime(root.elapsedSeconds) : Translation.tr("Record")
                color: {
                    if (root.isRecording) {
                        return root.isPaused ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnError
                    }
                    return symbol.color
                }
                font.pixelSize: Math.max(9, Math.round(Appearance.font.pixelSize.small))
                font.bold: true
                font.features: { "tnum": 1 }
                font.letterSpacing: -0.2
                transform: Translate { y: 1 }
                Component.onCompleted: width = implicitWidth
            }
        }
    }
}