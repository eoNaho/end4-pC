import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Popover card for AI usage providers matching the notch design.
 */
StyledPopup {
    id: root
    property string providerId: ""

    readonly property var shownProviders: root.providerId !== "" ? [root.providerId] : AiUsage.enabledProviders

    ColumnLayout {
        implicitWidth: 300
        spacing: 16

        Repeater {
            model: root.shownProviders
            delegate: ColumnLayout {
                id: card
                required property string modelData
                readonly property var meta: AiUsage.metaFor(modelData)
                readonly property var usage: AiUsage.dataFor(modelData)

                Layout.fillWidth: true
                spacing: 12

                // Card Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 9

                    CustomIcon {
                        source: card.meta.icon + ".svg"
                        colorize: true
                        color: Appearance.colors.colOnLayer0
                        width: 20
                        height: 20
                    }
                    StyledText {
                        text: Translation.tr("%1 Usage").arg(card.meta.name)
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer0
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        visible: card.usage.loading
                        text: Translation.tr("Updating…")
                        font.pixelSize: 12
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        visible: !card.usage.loading && !card.usage.ok
                        text: Translation.tr("Unavailable")
                        font.pixelSize: 12
                        color: Appearance.colors.colOutline
                    }
                }

                // Limits list
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: card.usage.ok && card.usage.limits.length > 0
                    spacing: 12

                    Repeater {
                        model: card.usage.ok ? card.usage.limits : []
                        delegate: ColumnLayout {
                            id: limitRow
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: limitRow.modelData.label
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    readonly property string resetsIn: AiUsage.formatResetsIn(limitRow.modelData.resetsAt)
                                    visible: resetsIn !== ""
                                    text: Translation.tr("Resets in %1").arg(resetsIn)
                                    font.pixelSize: 12
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 6
                                radius: 3
                                color: Qt.alpha(Appearance.colors.colOnLayer0, 0.15)

                                Rectangle {
                                    width: parent.width * Math.min(1, Math.max(0, limitRow.modelData.percent / 100))
                                    height: parent.height
                                    radius: 3
                                    color: AiUsage.severityColor(limitRow.modelData.percent)

                                    Behavior on width {
                                        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                                    }
                                }
                            }

                            StyledText {
                                text: Translation.tr("%1% used").arg(Math.round(limitRow.modelData.percent))
                                font.pixelSize: 12
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                // Divider when multiple providers shown
                Rectangle {
                    visible: index < root.shownProviders.length - 1
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.alpha(Appearance.colors.colOnLayer0, 0.08)
                }
            }
        }
    }
}
