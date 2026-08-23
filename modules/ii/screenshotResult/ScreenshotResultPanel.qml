import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Screenshot result popup: unified glassmorphism card with live preview,
 * one-click copy, OCR text extraction, countdown timer bar, and click-to-expand.
 */
Scope {
    id: root

    property string currentPath: ""
    property bool fileIsScratch: currentPath.startsWith(Directories.screenshotTemp)
        || currentPath.startsWith("/tmp/")
    property string editorBinary: ""

    // Feedback states
    property bool copiedFeedback: false
    property bool ocrFeedback: false
    property bool ocrRunning: false

    Connections {
        target: ScreenshotEvents
        function onScreenshotTaken(path) {
            if (!(Config.options.screenshotResult?.enable ?? true)) return;
            if (root.currentPath !== "" && root.currentPath !== path)
                root.releaseCurrent(false);
            root.currentPath = path;
            root.copiedFeedback = false;
            root.ocrFeedback = false;
            root.ocrRunning = false;
            dismissTimer.restart();
        }
    }

    function releaseCurrent(clearClipboard = false) {
        if (root.currentPath === "") return;
        if (root.fileIsScratch)
            Quickshell.execDetached(["rm", "-f", "--", root.currentPath]);
        if (clearClipboard) {
            Quickshell.execDetached(["bash", "-c", "cliphist list | head -n 1 | cliphist delete 2>/dev/null; wl-copy --clear 2>/dev/null"]);
            Cliphist.refresh();
        }
        root.currentPath = "";
    }

    function saveCurrent() {
        if (root.currentPath === "") return;
        Quickshell.execDetached(["bash", "-c",
            'd="$1/Screenshots"; mkdir -p "$d"; ' +
            'n="$d/Screenshot_$(date +%Y-%m-%d_%H.%M.%S).png"; ' +
            'while [ -e "$n" ]; do n="${n%.png}_$RANDOM.png"; done; ' +
            'cp -n -- "$2" "$n" && [ "$3" = "1" ] && rm -f -- "$2"',
            "_", FileUtils.trimFileProtocol(Directories.pictures), root.currentPath,
            root.fileIsScratch ? "1" : "0"]);
        root.currentPath = "";
    }

    function copyImage() {
        if (root.currentPath === "") return;
        Quickshell.execDetached(["bash", "-c", 'wl-copy -t image/png < "$1"', "_", root.currentPath]);
        root.copiedFeedback = true;
        feedbackTimer.restart();
    }

    function extractText() {
        if (root.currentPath === "" || root.ocrRunning) return;
        root.ocrRunning = true;
        Quickshell.execDetached(["bash", "-c",
            'if command -v tesseract >/dev/null 2>&1; then ' +
            '  text=$(tesseract "$1" stdout -l por+eng 2>/dev/null || tesseract "$1" stdout 2>/dev/null); ' +
            '  if [ -n "$text" ]; then ' +
            '    echo -n "$text" | wl-copy; ' +
            '    notify-send -a "Screenshot OCR" "Texto Copiado!" "$text" -i "edit-copy"; ' +
            '  else ' +
            '    notify-send -a "Screenshot OCR" "Nenhum texto detectado" "Não foi possível reconhecer caracteres na imagem." -i "dialog-warning"; ' +
            '  fi; ' +
            'else ' +
            '  notify-send -a "Screenshot OCR" "Tesseract não instalado" "Instale com: sudo pacman -S tesseract tesseract-data-por" -i "dialog-error"; ' +
            'fi',
            "_", root.currentPath]);
        
        ocrFeedbackTimer.restart();
    }

    function openInViewer() {
        if (root.currentPath === "") return;
        Quickshell.execDetached(["xdg-open", root.currentPath]);
        root.releaseCurrent(false);
    }

    function editCurrent() {
        const custom = Config.options.screenshotResult?.editorCommand ?? [];
        if (root.currentPath === "" || (root.editorBinary === "" && custom.length === 0)) return;
        const args = custom.length > 0
            ? custom.concat([root.currentPath])
            : (root.editorBinary.endsWith("satty")
                ? [root.editorBinary, "--filename", root.currentPath]
                : [root.editorBinary, "-f", root.currentPath]);
        Quickshell.execDetached(args);
        root.currentPath = "";
    }

    Process {
        id: editorProbe
        running: true
        command: ["bash", "-c", "command -v swappy satty 2>/dev/null | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.editorBinary = text.trim()
        }
    }

    Timer {
        id: feedbackTimer
        interval: 1800
        onTriggered: root.copiedFeedback = false
    }

    Timer {
        id: ocrFeedbackTimer
        interval: 1800
        onTriggered: {
            root.ocrRunning = false;
            root.ocrFeedback = true;
            ocrResetTimer.restart();
        }
    }

    Timer {
        id: ocrResetTimer
        interval: 1800
        onTriggered: root.ocrFeedback = false
    }

    Timer {
        id: dismissTimer
        interval: Config.options.screenshotResult?.timeoutMs ?? 7000
        onTriggered: {
            if (panelLoader.item?.hovered) { dismissTimer.restart(); return; }
            root.releaseCurrent(false);
        }
    }

    LazyLoader {
        id: panelLoader
        active: root.currentPath !== ""

        component: PanelWindow {
            id: popupWindow
            readonly property bool hovered: hoverHandler.hovered
            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: Appearance.sizes.hyprlandGapsOut + 16
                left: 16
            }
            implicitWidth: 350 + Appearance.sizes.elevationMargin * 2
            implicitHeight: 270 + Appearance.sizes.elevationMargin * 2
            color: "transparent"
            WlrLayershell.namespace: "quickshell:screenshotResult"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: 0

            Item {
                anchors.fill: parent

                HoverHandler { id: hoverHandler }

                Connections {
                    target: root
                    function onCurrentPathChanged() {
                        if (root.currentPath !== "") {
                            enterAnimation.restart();
                            countdownAnim.restart();
                        }
                    }
                }

                Connections {
                    target: popupWindow
                    function onHoveredChanged() {
                        if (popupWindow.hovered) {
                            countdownAnim.pause();
                        } else {
                            countdownAnim.resume();
                        }
                    }
                }

                StyledRectangularShadow {
                    target: unifiedCard
                }

                Rectangle {
                    id: unifiedCard
                    anchors.centerIn: parent
                    implicitWidth: 350
                    implicitHeight: 250
                    
                    color: Qt.rgba(Appearance.colors.colLayer0.r, Appearance.colors.colLayer0.g, Appearance.colors.colLayer0.b, 0.92)
                    radius: Appearance.rounding.large
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    Component.onCompleted: {
                        enterAnimation.restart();
                        countdownAnim.restart();
                    }

                    ParallelAnimation {
                        id: enterAnimation
                        NumberAnimation {
                            target: unifiedCard
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                        NumberAnimation {
                            target: unifiedCard
                            property: "scale"
                            from: 0.92
                            to: 1
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // 🔍 Image Preview Container (Click to Expand)
                        Item {
                            id: imageWrapper
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.openInViewer()

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    source: root.currentPath !== "" ? "file://" + root.currentPath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true

                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: previewImage.width
                                            height: previewImage.height
                                            radius: Appearance.rounding.large
                                            Rectangle {
                                                width: parent.width
                                                height: parent.radius
                                                anchors.bottom: parent.bottom
                                            }
                                        }
                                    }
                                }

                                // Overlay badge on hover: Click to expand
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: expandRow.implicitWidth + 20
                                    height: 32
                                    radius: Appearance.rounding.full
                                    color: Qt.rgba(Appearance.colors.colLayer0.r, Appearance.colors.colLayer0.g, Appearance.colors.colLayer0.b, 0.85)
                                    border.width: 1
                                    border.color: Appearance.colors.colLayer0Border
                                    opacity: parent.containsMouse ? 1 : 0
                                    scale: parent.containsMouse ? 1 : 0.8
                                    visible: opacity > 0

                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                    RowLayout {
                                        id: expandRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialSymbol { text: "open_in_new"; iconSize: 16; color: Appearance.colors.colPrimary }
                                        StyledText { text: Translation.tr("Expand"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer0 }
                                    }
                                }
                            }

                            // Dismiss Floating Button (Top-Right)
                            RippleButton {
                                id: dismissButton
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                    margins: 8
                                }
                                width: 28
                                height: 28
                                opacity: popupWindow.hovered ? 1 : 0
                                buttonRadius: Appearance.rounding.full
                                colBackground: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 0.85)
                                colBackgroundHover: Appearance.colors.colErrorContainer
                                onClicked: root.releaseCurrent()

                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 16
                                    color: dismissButton.hovered ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                                }
                                StyledToolTip { text: Translation.tr("Dismiss") }
                            }
                        }

                        // Bottom Action Bar
                        RowLayout {
                            id: actionBar
                            Layout.fillWidth: true
                            Layout.margins: 8
                            spacing: 6

                            // 📋 Copy Image Button with animated feedback
                            RippleButton {
                                Layout.fillWidth: true
                                buttonRadius: Appearance.rounding.normal
                                implicitHeight: 38
                                colBackground: root.copiedFeedback ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer
                                colBackgroundHover: root.copiedFeedback ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainerHover
                                onClicked: root.copyImage()

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        text: root.copiedFeedback ? "check" : "content_copy"
                                        iconSize: 18
                                        color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnSecondaryContainer
                                    }
                                    StyledText {
                                        text: root.copiedFeedback ? Translation.tr("Copied!") : Translation.tr("Copy")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnSecondaryContainer
                                    }
                                }
                                StyledToolTip { text: Translation.tr("Copy image to clipboard") }
                            }

                            // 🔤 OCR Text Extraction Button with feedback
                            RippleButton {
                                Layout.fillWidth: true
                                buttonRadius: Appearance.rounding.normal
                                implicitHeight: 38
                                colBackground: root.ocrFeedback ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                                colBackgroundHover: root.ocrFeedback ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1Hover
                                onClicked: root.extractText()

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        text: root.ocrFeedback ? "check" : (root.ocrRunning ? "sync" : "text_fields")
                                        iconSize: 18
                                        color: root.ocrFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    }
                                    StyledText {
                                        text: root.ocrFeedback ? Translation.tr("Text Copied!") : (root.ocrRunning ? Translation.tr("Reading...") : "OCR")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: root.ocrFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    }
                                }
                                StyledToolTip { text: Translation.tr("Extract text from image (OCR)") }
                            }

                            // 💾 Save to Pictures Button
                            RippleButton {
                                implicitWidth: 38
                                implicitHeight: 38
                                buttonRadius: Appearance.rounding.normal
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                                onClicked: root.saveCurrent()

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "save"
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledToolTip { text: Translation.tr("Save to Pictures") }
                            }
                            
                            // ✏️ Annotate / Edit Button
                            RippleButton {
                                visible: root.editorBinary !== "" || (Config.options.screenshotResult?.editorCommand ?? []).length > 0
                                implicitWidth: 38
                                implicitHeight: 38
                                buttonRadius: Appearance.rounding.normal
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: root.editCurrent()

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "edit"
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledToolTip { text: Translation.tr("Annotate with external editor") }
                            }
                            
                            // 🗑️ Discard Button
                            RippleButton {
                                implicitWidth: 38
                                implicitHeight: 38
                                buttonRadius: Appearance.rounding.normal
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colErrorContainerHover
                                onClicked: root.releaseCurrent(true)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 18
                                    color: Appearance.colors.colError
                                }
                                StyledToolTip { text: Translation.tr("Discard") }
                            }
                        }

                        // ⏳ Countdown Timer Bar at the very bottom
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 3

                            Rectangle {
                                id: countdownBar
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * countdownProgress.value
                                color: Appearance.colors.colPrimary
                                radius: 1.5
                                opacity: 0.8
                            }

                            QtObject {
                                id: countdownProgress
                                property real value: 1.0
                            }

                            NumberAnimation {
                                id: countdownAnim
                                target: countdownProgress
                                property: "value"
                                from: 1.0
                                to: 0.0
                                duration: Config.options.screenshotResult?.timeoutMs ?? 7000
                            }
                        }
                    }
                }
            }
        }
    }
}
