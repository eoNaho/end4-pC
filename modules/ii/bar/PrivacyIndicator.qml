import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property bool isRecording: Privacy.micActive || Privacy.screenSharing

    implicitWidth: 32
    implicitHeight: 32

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: Privacy.screenSharing ? "screen_share" : (Privacy.micActive ? "mic" : "security")
        iconSize: Appearance.font.pixelSize.larger
        fill: root.isRecording ? 1 : 0
        color: root.isRecording
            ? Appearance.colors.colError
            : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
    }

    PopupToolTip {
        id: tooltip
        text: Privacy.screenSharing
            ? Translation.tr("Screen sharing is active")
            : (Privacy.micActive
                ? Translation.tr("Microphone is currently in use")
                : Translation.tr("No active recordings"))
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
