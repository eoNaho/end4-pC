import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property bool isMuted: Audio.sink?.audio?.muted ?? false
    readonly property real volume: Audio.sink?.audio?.volume ?? 1.0

    implicitWidth: 32
    implicitHeight: 32

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onWheel: (wheel) => {
            if (Audio.sink?.audio) {
                const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                Audio.sink.audio.volume = Math.max(0, Math.min(1.5, Audio.sink.audio.volume + delta));
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted;
            } else {
                if (menuLoader.active && menuLoader.item) {
                    menuLoader.item.close();
                } else {
                    menuLoader.open();
                }
            }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: Appearance.font.pixelSize.larger
        fill: root.isMuted ? 0 : 1
        color: (menuLoader.active || mouseArea.containsMouse) ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1)
        text: {
            if (root.isMuted) return "volume_off";
            if (root.volume > 0.6) return "volume_up";
            if (root.volume > 0.2) return "volume_down";
            return "volume_mute";
        }
    }

    PopupToolTip {
        id: tooltip
        text: Translation.tr("Audio: %1 (%2%) · Click for devices, Scroll to adjust, Right-click to mute")
            .arg(Audio.friendlyDeviceName(Audio.sink))
            .arg(Math.round(root.volume * 100))
        extraVisibleCondition: mouseArea.containsMouse && !menuLoader.active
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

    Loader {
        id: menuLoader
        function open() {
            menuLoader.active = true;
        }
        active: false
        sourceComponent: AudioSinkMenu {
            Component.onCompleted: this.open()
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                menuLoader.active = false;
            }
        }
    }
}
