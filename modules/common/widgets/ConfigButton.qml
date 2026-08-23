import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    property string buttonIcon: ""
    property string text: ""
    property alias iconSize: iconWidget.iconSize
    colBackgroundHover: Appearance.colors.colLayer2

    Layout.fillWidth: true
    Layout.bottomMargin: 6
    implicitHeight: 44
    font.pixelSize: Appearance.font.pixelSize.small

    contentItem: RowLayout {
        spacing: 10
        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            opacity: root.enabled ? 1 : 0.4
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colPrimary
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.normal
            text: "chevron_right"
            color: Appearance.colors.colOutlineVariant
            opacity: root.enabled ? 0.8 : 0.3
        }
    }
}
