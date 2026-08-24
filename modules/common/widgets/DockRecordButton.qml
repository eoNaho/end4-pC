pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

DockButton {
    id: root

    property bool isHovered: root.hovered
    readonly property bool isRecording: Persistent.states.record?.enable ?? false
    readonly property bool isPaused: Persistent.states.record?.paused ?? false
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
        const mins = Math.floor(s / 60).toString().padStart(2, '0');
        const secs = (s % 60).toString().padStart(2, '0');
        return mins + ":" + secs;
    }

    Timer {
        interval: 250
        running: root.isRecording && !root.isPaused
        repeat: true
        onTriggered: {
            if (root.recordStart > 0) {
                const now = Date.now() / 1000;
                root.elapsedSeconds = Math.max(0, Math.floor(now - root.recordStart - root.totalPausedDuration));
            }
        }
    }

    onClicked: {
        if (root.isRecording) {
            ScreenRecord.stopRecord();
        } else {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
    }

    altAction: () => {
        recordContextMenu.active = true;
    }

    StyledToolTip {
        text: {
            if (root.isRecording) {
                if (root.isPaused) {
                    return Translation.tr("Recording Paused (%1)\nClick: Stop · Right-click: Menu").arg(root.formatTime(root.elapsedSeconds));
                }
                return Translation.tr("Screen Recording (%1)\nClick: Stop · Right-click: Menu").arg(root.formatTime(root.elapsedSeconds));
            }
            return Translation.tr("Screen Recorder\nClick: Open Recorder · Right-click: Quick Actions");
        }
    }

    contentItem: Item {
        anchors.fill: parent

        Item {
            id: iconArea
            width: 33
            height: 33
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

            // Pulsing background when recording
            Rectangle {
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: 16
                visible: root.isRecording
                color: root.isPaused ? Appearance.colors.colSecondaryContainer : Appearance.colors.colErrorContainer

                SequentialAnimation on opacity {
                    running: root.isRecording && !root.isPaused
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.9; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 0.9; duration: 600; easing.type: Easing.InOutQuad }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: {
                    if (root.isRecording) {
                        return root.isPaused ? "pause_circle" : "stop_circle";
                    }
                    return "screen_record";
                }
                iconSize: 26
                color: {
                    if (root.isRecording) {
                        return root.isPaused ? Appearance.colors.colSecondary : Appearance.colors.colError;
                    }
                    return Appearance.colors.colOnLayer0;
                }
            }
        }
    }

    PopupWindow {
        id: recordContextMenu
        property bool active: false

        anchor {
            item: root
            edges: Edges.Top
            gravity: Edges.Top
        }

        visible: active
        color: "transparent"
        implicitWidth: recordMenuCard.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: recordMenuCard.implicitHeight + Appearance.sizes.elevationMargin * 2 + 8

        Timer {
            id: autoCloseTimer
            interval: 400
            repeat: false
            onTriggered: {
                if (!recordMenuMouseArea.containsMouse && !root.isHovered) {
                    recordContextMenu.active = false;
                }
            }
        }

        Connections {
            target: root
            function onIsHoveredChanged() {
                if (!root.isHovered && !recordMenuMouseArea.containsMouse) {
                    autoCloseTimer.restart();
                }
            }
        }

        MouseArea {
            id: recordMenuMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onExited: {
                if (!root.isHovered) {
                    autoCloseTimer.restart();
                }
            }

            StyledRectangularShadow {
                target: recordMenuCard
                visible: recordContextMenu.active
            }

            Rectangle {
                id: recordMenuCard
                anchors.centerIn: parent
                implicitWidth: 210
                implicitHeight: recordMenuContent.implicitHeight + 16
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                ColumnLayout {
                    id: recordMenuContent
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 4

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol {
                            text: root.isRecording ? (root.isPaused ? "pause_circle" : "stop_circle") : "screen_record"
                            iconSize: 18
                            color: root.isRecording ? (root.isPaused ? Appearance.colors.colSecondary : Appearance.colors.colError) : Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.isRecording
                                ? (root.isPaused ? Translation.tr("Paused (%1)").arg(root.formatTime(root.elapsedSeconds)) : Translation.tr("Recording (%1)").arg(root.formatTime(root.elapsedSeconds)))
                                : Translation.tr("Screen Recorder")
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer0
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    // Active Recording Actions
                    ColumnLayout {
                        visible: root.isRecording
                        Layout.fillWidth: true
                        spacing: 4

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                ScreenRecord.togglePauseRecord();
                                recordContextMenu.active = false;
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: root.isPaused ? "play_arrow" : "pause"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.isPaused ? Translation.tr("Resume Recording") : Translation.tr("Pause Recording")
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colErrorContainer
                            onClicked: {
                                ScreenRecord.stopRecord();
                                recordContextMenu.active = false;
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: "stop"
                                    iconSize: 18
                                    color: Appearance.colors.colError
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Stop Recording")
                                    color: Appearance.colors.colError
                                    font.bold: true
                                }
                            }
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                ScreenRecord.discardRecord();
                                recordContextMenu.active = false;
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: "delete"
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer1Inactive
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Discard Recording")
                                    color: Appearance.colors.colOnLayer1Inactive
                                }
                            }
                        }
                    }

                    // Idle Actions
                    ColumnLayout {
                        visible: !root.isRecording
                        Layout.fillWidth: true
                        spacing: 4

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                recordContextMenu.active = false;
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "recordWithSound"]);
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: "screen_record"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Record Region")
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                recordContextMenu.active = false;
                                ScreenRecord.toggleRecordScreen();
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: "capture"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Record Fullscreen")
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }

                        RippleButton {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: {
                                recordContextMenu.active = false;
                                ScreenRecord.recordGif();
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                MaterialSymbol {
                                    text: "gif_box"
                                    iconSize: 18
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Record GIF")
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.colors.colLayer0Border
                    }

                    // Open Folder
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 30
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        onClicked: {
                            recordContextMenu.active = false;
                            Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`);
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            MaterialSymbol {
                                text: "folder_open"
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Open Folder")
                                color: Appearance.colors.colOnLayer0
                            }
                        }
                    }
                }
            }
        }
    }
}
