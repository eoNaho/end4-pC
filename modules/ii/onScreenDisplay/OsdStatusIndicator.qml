pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string icon
    required property string name
    required property string statusText
    required property bool active

    implicitWidth: Appearance.sizes.osdWidth + 4 * Appearance.sizes.elevationMargin + 80
    implicitHeight: statusIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    Rectangle {
        id: statusIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colLayer0
        implicitWidth: statusRow.implicitWidth
        implicitHeight: statusRow.implicitHeight

        RowLayout {
            id: statusRow
            anchors.fill: parent
            anchors.margins: 6
            spacing: 12

            Rectangle {
                id: iconBg
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                width: 40
                radius: height / 2
                color: root.active ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.icon
                    iconSize: 22
                    color: root.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    text: root.name
                    font.weight: Font.Medium
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }

                StyledText {
                    text: root.statusText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: root.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
