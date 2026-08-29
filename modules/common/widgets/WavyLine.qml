import qs.modules.common
import qs.services
import QtQuick

Canvas {
    id: root
    property real amplitudeMultiplier: 0.8
    property real frequency: 7
    property color color: Appearance?.colors.colPrimary ?? "#685496"
    property real lineWidth: 4
    property real fullLength: width
    property bool active: MprisController.isPlaying
    property real waveTransition: active ? 1.0 : 0.0
    property real wavePhase: 0.0

    Behavior on waveTransition {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    onWaveTransitionChanged: requestPaint()

    FrameAnimation {
        running: root.waveTransition > 0.001
        onTriggered: {
            root.wavePhase = (root.wavePhase + Math.PI * 2 * frameTime / 2.0) % (Math.PI * 2);
            root.requestPaint();
        }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var amplitude = root.lineWidth * root.amplitudeMultiplier * root.waveTransition;
        var frequency = root.frequency;
        var centerY = height / 2;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();

        var step = 3;
        var startX = ctx.lineWidth / 2;
        var endX = Math.max(startX, root.width - ctx.lineWidth / 2);

        for (var x = startX; x <= endX; x += step) {
            var waveY = centerY + amplitude * Math.sin(frequency * 2 * Math.PI * (x / Math.max(1, root.fullLength)) + root.wavePhase);
            if (x === startX)
                ctx.moveTo(x, waveY);
            else
                ctx.lineTo(x, waveY);
        }
        ctx.stroke();
    }
}
