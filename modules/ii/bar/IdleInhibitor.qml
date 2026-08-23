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

    implicitWidth: 32
    implicitHeight: 32

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Idle.toggleInhibit()
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "local_cafe"
        iconSize: Appearance.font.pixelSize.larger
        fill: Idle.inhibit ? 1 : 0
        color: Idle.inhibit
            ? Appearance.colors.colPrimary
            : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
    }

    PopupToolTip {
        id: tooltip
        text: Idle.inhibit
            ? Translation.tr("Caffeine active (Sleep inhibited)")
            : Translation.tr("Caffeine (Inhibit sleep)")
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
