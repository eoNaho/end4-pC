import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    id: root
    required property string materialSymbol
    required property bool current
    property bool isError: false
    horizontalPadding: 10

    implicitHeight: 40
    implicitWidth: implicitContentWidth + horizontalPadding * 2
    buttonRadius: height / 2

    colBackground: isError && current ? Appearance.colors.colErrorContainer : ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
    colBackgroundHover: isError ? (current ? Appearance.colors.colErrorContainerHover : Appearance.colors.colErrorContainer) : ColorUtils.transparentize(Appearance.colors.colOnSurface, current ? 1 : 0.95)
    colRipple: isError ? Appearance.colors.colErrorContainerActive : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)

    readonly property color colContent: isError ? (current ? Appearance.colors.colOnErrorContainer : Appearance.colors.colError) : (current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface)

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
            color: root.colContent
        }
        StyledText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.colContent
        }
    }
}
