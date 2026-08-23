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

    readonly property bool hasActiveLock: LockKeysService.capsLock || LockKeysService.numLock

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
        text: LockKeysService.capsLock ? "keyboard_capslock" : "keyboard"
        iconSize: Appearance.font.pixelSize.larger
        fill: root.hasActiveLock ? 1 : 0
        color: root.hasActiveLock
            ? Appearance.colors.colPrimary
            : (mouseArea.containsMouse ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1))
    }

    PopupToolTip {
        id: tooltip
        text: LockKeysService.capsLock
            ? Translation.tr("Caps Lock is ON")
            : (LockKeysService.numLock ? Translation.tr("Num Lock is ON") : Translation.tr("Keyboard Locks: OFF"))
        extraVisibleCondition: mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
