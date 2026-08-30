pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.worldclock
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.pomodoro
import qs.modules.ii.background.widgets.captures
import qs.modules.ii.background.widgets.vpn

Variants {
    id: root
    model: Quickshell.screens

    function getShapeFromName(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            case "Diamond":       return MaterialShape.Shape.Diamond
            case "ClamShell":     return MaterialShape.Shape.ClamShell
            case "Pentagon":      return MaterialShape.Shape.Pentagon
            case "Gem":           return MaterialShape.Shape.Gem
            case "Sunny":         return MaterialShape.Shape.Sunny
            case "VerySunny":     return MaterialShape.Shape.VerySunny
            case "Cookie4Sided":  return MaterialShape.Shape.Cookie4Sided
            case "Cookie6Sided":  return MaterialShape.Shape.Cookie6Sided
            case "Cookie7Sided":  return MaterialShape.Shape.Cookie7Sided
            case "Cookie9Sided":  return MaterialShape.Shape.Cookie9Sided
            case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided
            case "Ghostish":      return MaterialShape.Shape.Ghostish
            case "Clover4Leaf":   return MaterialShape.Shape.Clover4Leaf
            case "Clover8Leaf":   return MaterialShape.Shape.Clover8Leaf
            case "Burst":         return MaterialShape.Shape.Burst
            case "SoftBurst":     return MaterialShape.Shape.SoftBurst
            case "Boom":          return MaterialShape.Shape.Boom
            case "SoftBoom":      return MaterialShape.Shape.SoftBoom
            case "Flower":        return MaterialShape.Shape.Flower
            case "Puffy":         return MaterialShape.Shape.Puffy
            case "PuffyDiamond":  return MaterialShape.Shape.PuffyDiamond
            case "PixelCircle":   return MaterialShape.Shape.PixelCircle
            case "PixelTriangle": return MaterialShape.Shape.PixelTriangle
            case "Bun":           return MaterialShape.Shape.Bun
            case "Heart":         return MaterialShape.Shape.Heart
            default:              return MaterialShape.Shape.Cookie7Sided
        }
    }

    function getColorFromName(name) {
        switch (name) {
            case "primary":            return Appearance.colors.colPrimary
            case "secondary":          return Appearance.colors.colSecondary
            case "tertiary":           return Appearance.colors.colTertiary
            case "primaryContainer":   return Appearance.colors.colPrimaryContainer
            case "secondaryContainer": return Appearance.colors.colSecondaryContainer
            case "tertiaryContainer":  return Appearance.colors.colTertiaryContainer
            case "layer0":             return Appearance.colors.colLayer0
            case "layer1":             return Appearance.colors.colLayer1
            default:                  return Appearance.colors.colPrimaryContainer
        }
    }

    PanelWindow {
        id: bgRoot

        required property var modelData
        property string currentWallpaperSource: Config.options.background.wallpaperPath
        property string previousWallpaperSource: Config.options.background.wallpaperPath
        property bool videoRevealed: false

        //centered Wallpaper
        property bool centeredWallpaperEnabled: Config.options.background.centeredWallpaper && (!Config.options.background.centeredWallpaperOnlyWhenLocked || GlobalStates.screenLocked)
        property int centeredWallpaperShape: getShapeFromName(Config.options.background.centeredWallpaperShape)
        property int centeredWallpaperSize: Config.options.background.centeredWallpaperSize
        property color centeredWallpaperColor: root.getColorFromName(Config.options.background.centeredWallpaperColor)

        property var shaderList: ["circlePit", "circleSelect", "magic", "Doom", "Peel", "transition", "pixelate", "stripes", "crt", "dissolve", "glitch", "ripple", "shatter"]
        property string currentShader: "pixelate"
        property string wallpaperAnimation: Config.options.background.wallpaperAnimation ?? "random"

        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace?.monitor && monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace?.toplevels?.values?.filter(window => window?.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: true

        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

        property string effectiveWallpaperPath: {
            if (GlobalStates.screenLocked && Config.options.background.lockWall !== "")
                return Config.options.background.lockWall;
            return Wallpapers.previewPath || Wallpapers.confirmedPath || Config.options.background.wallpaperPath;
        }

        property bool wallpaperIsVideo: bgRoot.effectiveWallpaperPath.endsWith(".mp4") || bgRoot.effectiveWallpaperPath.endsWith(".webm") || bgRoot.effectiveWallpaperPath.endsWith(".mkv") || bgRoot.effectiveWallpaperPath.endsWith(".avi") || bgRoot.effectiveWallpaperPath.endsWith(".mov")
        property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : bgRoot.effectiveWallpaperPath
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }

        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        property real transitionProgress: 1.0

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (GlobalStates.screenLocked && !scaleAnim.running) ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Component.onCompleted: {
            previousWallpaper.source = ""
            wallpaper.source = bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.wallpaperPath
            bgRoot.currentWallpaperSource = bgRoot.wallpaperPath
            bgRoot.previousWallpaperSource = ""
            bgRoot.transitionProgress = 1.0
            bgRoot.updateZoomScale()
            if (bgRoot.wallpaperAnimation !== "") {
                bgRoot.currentShader = bgRoot.wallpaperAnimation === "random"
                    ? bgRoot.shaderList[Math.floor(Math.random() * bgRoot.shaderList.length)]
                    : bgRoot.wallpaperAnimation
            }
            bgRoot.videoRevealed = bgRoot.wallpaperIsVideo
        }

        onWallpaperPathChanged: {
            bgRoot.videoRevealed = false
            bgRoot.updateZoomScale()
            if (wallpaperSafetyTriggered) {
                transitionAnim.stop()
                previousWallpaper.source = ""
                wallpaper.source = ""
                bgRoot.transitionProgress = 1.0
                return
            }
            if (bgRoot.wallpaperAnimation === "") {
                transitionAnim.stop()
                wallpaper.source = wallpaperPath
                bgRoot.currentWallpaperSource = wallpaperPath
                bgRoot.transitionProgress = 1.0
                if (!bgRoot.wallpaperIsVideo) return
                bgRoot.videoRevealed = true
                return
            }

            // If the wallpaper source didn't change and is already loaded, avoid re-triggering transition
            if (bgRoot.currentWallpaperSource === wallpaperPath && wallpaper.status === Image.Ready) {
                bgRoot.transitionProgress = 1.0
                if (bgRoot.wallpaperIsVideo) bgRoot.videoRevealed = true
                return
            }

            // If we don't have a valid previous wallpaper source, show directly without transition
            if (!bgRoot.currentWallpaperSource || bgRoot.currentWallpaperSource.length === 0) {
                transitionAnim.stop()
                wallpaper.source = wallpaperPath
                bgRoot.currentWallpaperSource = wallpaperPath
                bgRoot.transitionProgress = 1.0
                if (bgRoot.wallpaperIsVideo) bgRoot.videoRevealed = true
                return
            }

            previousWallpaper.source = bgRoot.currentWallpaperSource
            if (bgRoot.wallpaperAnimation === "random") {
                bgRoot.currentShader = bgRoot.shaderList[Math.floor(Math.random() * bgRoot.shaderList.length)]
            } else {
                bgRoot.currentShader = bgRoot.wallpaperAnimation
            }

            transitionAnim.stop()
            bgRoot.transitionProgress = 0.0
            bgRoot.currentWallpaperSource = wallpaperPath
            wallpaper.source = wallpaperPath

            // If image is already ready (e.g. cached synchronously by Qt from first screen), start animation immediately
            if (wallpaper.status === Image.Ready) {
                transitionAnim.restart()
            } else if (wallpaper.status === Image.Error) {
                bgRoot.transitionProgress = 1.0
            }
        }

        NumberAnimation {
            id: transitionAnim
            target: bgRoot
            property: "transitionProgress"
            from: 0.0
            to: 1.0
            duration: 1200
            easing.type: Easing.InOutCubic
            onFinished: {
                previousWallpaper.source = ""
                bgRoot.previousWallpaperSource = ""
                bgRoot.transitionProgress = 1.0
                bgRoot.videoRevealed = bgRoot.wallpaperIsVideo
            }
        }

        Timer {
            id: wallpaperChangeTimer
            interval: Config.options.wallpaperSelector.changeInterval
            running: Config.options.wallpaperSelector.changeInterval > 0
            repeat: true
            onTriggered: {
                if (Wallpapers.folderModel.count > 0) {
                    Wallpapers.randomFromCurrentFolder()
                }
            }
        }

        Connections {
            target: GlobalStates
            function onScreenLockedChanged() {
                if (!GlobalStates.screenLocked) {
                    bgRoot.videoRevealed = bgRoot.wallpaperIsVideo
                }
            }
        }

        // Parallax calculations
        readonly property real parallaxRation: 1.1
        readonly property real additionalScaleFactor: Config.options.background.parallax.workspaceZoom
        property real effectiveWallpaperScale: 1
        property int wallpaperWidth: modelData.width
        property int wallpaperHeight: modelData.height
        property real scaledWallpaperWidth: wallpaperWidth * effectiveWallpaperScale
        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
        property real parallaxTotalPixelsX: Math.max(0, scaledWallpaperWidth - screen.width)
        property real parallaxTotalPixelsY: Math.max(0, scaledWallpaperHeight - screen.height)
        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical

        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        property int workspaceChunkSize: Config?.options.bar.workspaces.shown ?? 10
        property int totalWorkspaces: Math.ceil(lastWorkspaceId / workspaceChunkSize) * workspaceChunkSize

        property int workspaceIndex: (bgRoot.monitor?.activeWorkspace?.id ?? 1) - 1
        property real middleFraction: 0.5
        property real fraction: {
            if (bgRoot.totalWorkspaces <= 1) return middleFraction;
            return Math.max(0, Math.min(1, workspaceIndex / (bgRoot.totalWorkspaces - 1)));
        }
        property real usedFractionX: {
            let usedFraction = middleFraction;
            if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                usedFraction = fraction;
            }
            if (Config.options.background.parallax.enableSidebar) {
                let sidebarFraction = bgRoot.parallaxRation / bgRoot.workspaceChunkSize / 2;
                usedFraction += (sidebarFraction * GlobalStates.sidebarRightOpen - sidebarFraction * GlobalStates.sidebarLeftOpen);
            }
            return Math.max(0, Math.min(1, usedFraction));
        }
        property real usedFractionY: {
            let usedFraction = middleFraction;
            if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                usedFraction = fraction;
            }
            return Math.max(0, Math.min(1, usedFraction));
        }

        property real targetWallpaperX: {
            if (bgRoot.screen.width >= bgRoot.scaledWallpaperWidth) {
                return (bgRoot.screen.width - bgRoot.scaledWallpaperWidth) / 2;
            }
            return - bgRoot.parallaxTotalPixelsX * usedFractionX;
        }
        property real targetWallpaperY: {
            if (bgRoot.screen.height >= bgRoot.scaledWallpaperHeight) {
                return (bgRoot.screen.height - bgRoot.scaledWallpaperHeight) / 2;
            }
            return - bgRoot.parallaxTotalPixelsY * usedFractionY;
        }

        function updateZoomScale() {
            if (bgRoot.wallpaperPath && bgRoot.wallpaperPath.length > 0) {
                getWallpaperSizeProc.path = bgRoot.wallpaperPath;
                getWallpaperSizeProc.running = true;
            }
        }

        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const parts = output.trim().split(" ");
                    if (parts.length >= 2) {
                        const width = Number(parts[0]);
                        const height = Number(parts[1]);
                        if (width > 0 && height > 0) {
                            bgRoot.wallpaperWidth = width;
                            bgRoot.wallpaperHeight = height;
                            const minSuitableScale = Math.max(bgRoot.screen.width / width, bgRoot.screen.height / height);
                            bgRoot.effectiveWallpaperScale = minSuitableScale * bgRoot.additionalScaleFactor * bgRoot.parallaxRation;
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: GlobalStates.screenLocked || (!(bgRoot.activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

            Image {
                id: previousWallpaper
                x: bgRoot.targetWallpaperX
                y: bgRoot.targetWallpaperY
                width: bgRoot.scaledWallpaperWidth
                height: bgRoot.scaledWallpaperHeight
                sourceSize.width: bgRoot.scaledWallpaperWidth
                sourceSize.height: bgRoot.scaledWallpaperHeight
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                layer.enabled: bgRoot.transitionProgress < 1.0
                visible: false
            }

            StyledImage {
                id: wallpaper
                x: bgRoot.targetWallpaperX
                y: bgRoot.targetWallpaperY
                width: bgRoot.scaledWallpaperWidth
                height: bgRoot.scaledWallpaperHeight
                sourceSize.width: bgRoot.scaledWallpaperWidth
                sourceSize.height: bgRoot.scaledWallpaperHeight
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                layer.enabled: (bgRoot.transitionProgress < 1.0) || blurLoader.active
                visible: !blurLoader.active && !bgRoot.centeredWallpaperEnabled && !bgRoot.videoRevealed
                    && (bgRoot.wallpaperAnimation === "" || bgRoot.transitionProgress >= 1.0)
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                onStatusChanged: {
                    if (status === Image.Ready) {
                        if (bgRoot.transitionProgress === 0.0 && !transitionAnim.running) {
                            transitionAnim.restart();
                        }
                    } else if (status === Image.Error) {
                        bgRoot.transitionProgress = 1.0;
                    }
                }
            }

            ShaderEffect {
                id: transitionEffect
                anchors.fill: parent
                visible: !blurLoader.active && bgRoot.wallpaperAnimation !== "" && !bgRoot.centeredWallpaperEnabled && !bgRoot.videoRevealed
                    && bgRoot.transitionProgress < 1.0

                property var fromImage: previousWallpaper
                property var toImage: wallpaper
                property var source1: previousWallpaper
                property var source2: wallpaper
                property real time: 0.0
                property real progress: bgRoot.transitionProgress
                property real aspectX: width / height
                property real aspectY: 1.0
                property vector2d aspectRatio: Qt.vector2d(aspectX, aspectY)
                property vector2d origin: Qt.vector2d(0.5, 0.5)

                fragmentShader: bgRoot.wallpaperAnimation !== ""
                    ? Qt.resolvedUrl(`shaders/${bgRoot.currentShader}.frag.qsb`)
                    : ""

                Timer {
                    interval: 16
                    repeat: true
                    running: transitionEffect.visible && transitionAnim.running
                    onTriggered: transitionEffect.time += interval / 1000.0
                }
                onVisibleChanged: if (!visible) transitionEffect.time = 0.0
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    samples: Config.options.lock.blur.size 
                    width: wallpaper.width
                    height: wallpaper.height
                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            Rectangle {
                id: centeredWallpaperBg
                anchors.fill: parent
                color: bgRoot.centeredWallpaperColor
                opacity: bgRoot.centeredWallpaperEnabled ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }

            MaterialShape {
                id: centeredWallpaperShapeItem
                anchors.centerIn: parent
                width: bgRoot.centeredWallpaperSize
                height: bgRoot.centeredWallpaperSize
                color: bgRoot.centeredWallpaperColor
                shape: bgRoot.centeredWallpaperShape
                transformOrigin: Item.Center
                visible: opacity > 0

                state: bgRoot.centeredWallpaperEnabled ? "shown" : "hidden"

                states: [
                    State {
                        name: "shown"
                        PropertyChanges { target: centeredWallpaperShapeItem; scale: 1; opacity: 1 }
                    },
                    State {
                        name: "hidden"
                        PropertyChanges { target: centeredWallpaperShapeItem; scale: 1.4; opacity: 0 }
                    }
                ]

                transitions: [
                    Transition {
                        to: "shown"
                        ParallelAnimation {
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "scale"; from: 0; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "opacity"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                        }
                    },
                    Transition {
                        to: "hidden"
                        ParallelAnimation {
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "scale"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "opacity"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                        }
                    }
                ]

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: MaterialShape {
                        width: centeredWallpaperShapeItem.width
                        height: centeredWallpaperShapeItem.height
                        shape: bgRoot.centeredWallpaperShape
                    }
                }

                StyledImage {
                    anchors.fill: parent
                    source: bgRoot.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                }
            }

            DropArea {
                id: wallpaperDropArea
                anchors.fill: parent
                keys: ["text/uri-list"]

                property var currentUrls: []

                onEntered: (drag) => {
                    drag.accepted = drag.hasUrls
                    wallpaperDropArea.currentUrls = drag.hasUrls ? drag.urls : []
                }

                onExited: {
                    wallpaperDropArea.currentUrls = []
                }

                onDropped: (drop) => {
                    if (!drop.hasUrls) {
                        drop.accepted = false
                        wallpaperDropArea.currentUrls = []
                        return
                    }

                    if (drop.urls.length === 1) {
                        const path = CF.FileUtils.trimFileProtocol(decodeURIComponent(drop.urls[0].toString()))
                        const validExt = /\.(png|jpe?g|webp|bmp|gif)$/i.test(path)
                        if (validExt) {
                            Wallpapers.select(path, Appearance.m3colors.darkmode)
                        } else {
                            const globalPos = wallpaperDropArea.mapToGlobal(drop.x, drop.y)
                            DropShelf.show(drop.urls, globalPos.x, globalPos.y)
                        }
                    } else {
                        const globalPos = wallpaperDropArea.mapToGlobal(drop.x, drop.y)
                        DropShelf.show(drop.urls, globalPos.x, globalPos.y)
                    }
                    drop.accept()
                    wallpaperDropArea.currentUrls = []
                }

                Rectangle {
                    id: dropOverlay
                    anchors.fill: parent
                    visible: wallpaperDropArea.containsDrag
                    color: CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

                    property bool isSingleImage: wallpaperDropArea.currentUrls.length === 1
                        && /\.(png|jpe?g|webp|bmp|gif)$/i.test(
                            CF.FileUtils.trimFileProtocol(wallpaperDropArea.currentUrls[0].toString())
                        )

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: dropOverlay.isSingleImage ? "wallpaper" : "stacks"
                            iconSize: 64
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: dropOverlay.isSingleImage
                                ? Translation.tr("Drop to set as wallpaper")
                                : Translation.tr("Drop to add to shelf")
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            WidgetCanvas {
                id: widgetCanvas
                anchors.fill: parent

                transitions: Transition {
                    PropertyAnimation {
                        properties: "width,height"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                    AnchorAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.visualizer.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: VisualizerWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.customImage.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: CustomImage {
                        screenWidth:        bgRoot.screen.width
                        screenHeight:       bgRoot.screen.height
                        scaledScreenWidth:  bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale:     1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.calendar.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: CalendarWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.weather.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: WeatherWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.clock.enable
                        && (GlobalStates.screenLocked
                            || Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: ClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.notes.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: NotesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    id: mediaLoader
                    property bool enableLoading: true
                    shown: Config.options.background.widgets.media.enable && enableLoading
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: MediaWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                    onLoaded: {
                        if (item && item.requestReset) {
                            item.requestReset.connect(() => {
                                mediaLoader.enableLoading = false
                                mediaTimer.running = true
                            })
                        }
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.images.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: ImageConverterWidget {
                        screenWidth:        bgRoot.screen.width
                        screenHeight:       bgRoot.screen.height
                        scaledScreenWidth:  bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale:     1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.resources.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: ResourcesWidget {
                        screenWidth:        bgRoot.screen.width
                        screenHeight:       bgRoot.screen.height
                        scaledScreenWidth:  bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale:     1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.worldClock.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: WorldClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.userCard.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: UserCardWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.pomodoro.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: PomodoroWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.captures.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: CapturesWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
                FadeLoader {
                    shown: Config.options.background.widgets.vpn.enable
                        && (Config.options.background.screenList.length === 0
                            || Config.options.background.screenList.includes(bgRoot.screen.name))
                    sourceComponent: VpnWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
            }

            MouseArea {
                id: desktopRightClickArea
                anchors.fill: parent
                z: -2
                acceptedButtons: Qt.RightButton
                onClicked: (mouse) => {
                    GlobalStates.desktopMenuScreen = bgRoot.screen
                    GlobalStates.desktopMenuX = mouse.x
                    GlobalStates.desktopMenuY = mouse.y
                    GlobalStates.desktopMenuOpen = true
                }
            }
        }
    }
}