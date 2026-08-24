pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    minimumWidth: 360
    minimumHeight: isRecording ? 140 : 180

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
        const mins = Math.floor(s / 60).toString().padStart(2, '0');
        const secs = (s % 60).toString().padStart(2, '0');
        return mins + ":" + secs;
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

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 12

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ==========================================
            // ACTIVE RECORDING DASHBOARD
            // ==========================================
            ColumnLayout {
                id: activeRecordingLayout
                visible: root.isRecording
                Layout.fillWidth: true
                spacing: 12

                // Header with live indicator & timer
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: root.isPaused ? Appearance.colors.colSecondary : Appearance.colors.colError

                        SequentialAnimation on opacity {
                            running: root.isRecording && !root.isPaused
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.2; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.2; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }

                    StyledText {
                        text: root.isPaused ? Translation.tr("Recording Paused") : Translation.tr("Recording Live")
                        font.bold: true
                        font.pixelSize: Appearance.font.pixelSize.medium
                        color: root.isPaused ? Appearance.colors.colSecondary : Appearance.colors.colError
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: root.formatTime(root.elapsedSeconds)
                        font.bold: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.features: { "tnum": 1 }
                        color: Appearance.colors.colOnLayer0
                    }
                }

                // Control Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Pause / Resume
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        buttonRadius: Appearance.rounding.small
                        colBackground: root.isPaused ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: {
                            ScreenRecord.togglePauseRecord();
                        }
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.isPaused ? "play_arrow" : "pause"
                                iconSize: 20
                                color: root.isPaused ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.isPaused ? Translation.tr("Resume") : Translation.tr("Pause")
                                color: root.isPaused ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3
                            }
                        }
                    }

                    // Stop
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colError
                        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                        colRipple: Appearance.colors.colError
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            ScreenRecord.stopRecord();
                        }
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "stop"
                                iconSize: 20
                                color: Appearance.colors.colOnError
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Stop")
                                font.bold: true
                                color: Appearance.colors.colOnError
                            }
                        }
                    }

                    // Discard
                    RippleButton {
                        implicitHeight: 42
                        implicitWidth: 42
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            ScreenRecord.discardRecord();
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer3
                        }
                        StyledToolTip {
                            text: Translation.tr("Discard and Delete")
                        }
                    }
                }
            }

            // ==========================================
            // IDLE CAPTURE ACTIONS & QUICK OPTIONS
            // ==========================================
            ColumnLayout {
                id: idleLayout
                visible: !root.isRecording
                Layout.fillWidth: true
                spacing: 12

                // Top Capture Buttons
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    BigRecorderButton {
                        materialSymbol: "screenshot_region"
                        name: Translation.tr("Screenshot Region")
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                        }
                    }

                    BigRecorderButton {
                        materialSymbol: "photo_camera"
                        name: Translation.tr("Screenshot Screen")
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached(["bash", "-c", "grim - | wl-copy && notify-send 'Screenshot' 'Captured full screen' -a 'Screen Snip'"]);
                        }
                    }

                    BigRecorderButton {
                        materialSymbol: "screen_record"
                        name: Translation.tr("Record Region")
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "recordWithSound"]);
                        }
                    }

                    BigRecorderButton {
                        materialSymbol: "capture"
                        name: Translation.tr("Record Screen")
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen"]);
                        }
                    }

                    BigRecorderButton {
                        materialSymbol: "gif_box"
                        name: Translation.tr("Record GIF")
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached([Directories.recordScriptPath, "--gif"]);
                        }
                    }
                }

                // Quick Settings Selector Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Audio Mode Cycle Button
                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: {
                            const modes = ["desktop", "mic", "both", "none"];
                            const current = Config.options.screenRecord.audioSource || "desktop";
                            const nextIndex = (modes.indexOf(current) + 1) % modes.length;
                            Config.options.screenRecord.audioSource = modes[nextIndex];
                        }
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    switch (Config.options.screenRecord.audioSource) {
                                        case "mic": return "mic";
                                        case "both": return "multitrack_audio";
                                        case "none": return "mic_off";
                                        case "desktop":
                                        default: return "volume_up";
                                    }
                                }
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    switch (Config.options.screenRecord.audioSource) {
                                        case "mic": return Translation.tr("Microphone");
                                        case "both": return Translation.tr("System + Mic");
                                        case "none": return Translation.tr("Muted");
                                        case "desktop":
                                        default: return Translation.tr("System Sound");
                                    }
                                }
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                        StyledToolTip {
                            text: Translation.tr("Click to toggle audio source")
                        }
                    }

                    // Countdown Cycle Button
                    RippleButton {
                        implicitWidth: 70
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: {
                            const delays = [0, 3, 5];
                            const current = Config.options.screenRecord.countdown || 0;
                            const nextIndex = (delays.indexOf(current) + 1) % delays.length;
                            Config.options.screenRecord.countdown = delays[nextIndex];
                        }
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "timer"
                                iconSize: 18
                                color: Config.options.screenRecord.countdown > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Config.options.screenRecord.countdown > 0 ? `${Config.options.screenRecord.countdown}s` : Translation.tr("Off")
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                        StyledToolTip {
                            text: Translation.tr("Countdown timer before recording")
                        }
                    }
                }

                // Bottom Links Row (Open folder & settings)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`);
                        }
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "folder"
                                iconSize: 18
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Open Folder")
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 34
                        implicitHeight: 34
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        colRipple: Appearance.colors.colLayer3Active
                        onClicked: {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "settings", "open", "services"]);
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "settings"
                            iconSize: 18
                        }
                        StyledToolTip {
                            text: Translation.tr("Recording Settings")
                        }
                    }
                }
            }
        }
    }

    component BigRecorderButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        implicitHeight: 56
        implicitWidth: 56
        buttonRadius: Appearance.rounding.normal

        colBackground: Appearance.colors.colLayer3
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colRipple: Appearance.colors.colLayer3Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 26
            color: Appearance.colors.colOnLayer3
        }

        StyledToolTip {
            text: bigButton.name
        }
    }
}

