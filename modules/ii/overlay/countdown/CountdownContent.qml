pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

OverlayBackground {
    id: root

    // ── Persistent state ─────────────────────────────────────────────────────
    // Events are stored as a JSON array in ~/.local/share/quickshell/countdowns.json
    // Each entry: { "name": string, "target": ISO8601 string }
    property string dataFilePath: Directories.state + "/countdowns.json"
    property var events: []

    // ── Internal state ────────────────────────────────────────────────────────
    property bool addingNew: false
    property string newName: ""
    property string newDate: ""     // ISO date string from the input

    // ── Helpers ───────────────────────────────────────────────────────────────
    function saveEvents() {
        dataFile.setText(JSON.stringify(root.events))
    }

    function addEvent() {
        if (root.newName.trim() === "" || root.newDate.trim() === "") return
        const target = new Date(root.newDate)
        if (isNaN(target.getTime())) return
        root.events = [...root.events, { name: root.newName.trim(), target: target.toISOString() }]
        root.saveEvents()
        root.newName = ""
        root.newDate = ""
        root.addingNew = false
    }

    function removeEvent(index) {
        let copy = root.events.slice()
        copy.splice(index, 1)
        root.events = copy
        root.saveEvents()
    }

    // Formats the remaining time into a human-readable string
    function formatRemaining(isoTarget) {
        const now = Date.now()
        const target = new Date(isoTarget).getTime()
        const diff = target - now
        if (diff <= 0) return Translation.tr("Today! 🎉")
        const days  = Math.floor(diff / 86400000)
        const hours = Math.floor((diff % 86400000) / 3600000)
        const mins  = Math.floor((diff % 3600000)  / 60000)
        if (days > 0)  return Translation.tr("%1d %2h").arg(days).arg(hours)
        if (hours > 0) return Translation.tr("%1h %2m").arg(hours).arg(mins)
        return Translation.tr("%1m").arg(mins)
    }

    function formatDate(isoTarget) {
        return new Date(isoTarget).toLocaleDateString(Qt.locale(), "d MMM yyyy")
    }

    // ── Data file ─────────────────────────────────────────────────────────────
    FileView {
        id: dataFile
        path: Qt.resolvedUrl(root.dataFilePath)
        onLoaded: {
            try { root.events = JSON.parse(dataFile.text()) } catch (e) { root.events = [] }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.events = []
                dataFile.setText("[]")
            }
        }
    }

    // Tick every minute to refresh remaining time
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { /* binding refresh — events list read forces re-eval */ root.events = root.events.slice() }
    }

    Component.onCompleted: dataFile.reload()

    // ── UI ────────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 6

        // Header row
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: Translation.tr("Countdowns")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            Item { Layout.fillWidth: true }
            RippleButton {
                implicitWidth: 26
                implicitHeight: 26
                buttonRadius: 13
                colBackground: root.addingNew ? Appearance.colors.colPrimary : "transparent"
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                downAction: () => { root.addingNew = !root.addingNew }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.addingNew ? "close" : "add"
                    iconSize: Appearance.font.pixelSize.large
                    fill: 1
                    color: root.addingNew ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                }
            }
        }

        // Add new event form
        Loader {
            active: root.addingNew
            visible: active
            Layout.fillWidth: true
            sourceComponent: ColumnLayout {
                spacing: 4

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Event name")
                    text: root.newName
                    onTextChanged: root.newName = text
                }

                RowLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: "YYYY-MM-DD"
                        text: root.newDate
                        onTextChanged: root.newDate = text
                        inputMethodHints: Qt.ImhDate
                    }

                    RippleButton {
                        implicitWidth: 64
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.normal
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive
                        downAction: () => root.addEvent()
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Add")
                            color: Appearance.colors.colOnPrimary
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }
        }

        // Empty state
        Loader {
            active: root.events.length === 0 && !root.addingNew
            visible: active
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "event_upcoming"
                    iconSize: 32
                    color: Appearance.colors.colSubtext
                    opacity: 0.5
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No countdowns yet")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
        }

        // Event list
        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.events.length > 0
            contentHeight: eventCol.implicitHeight
            clip: true

            ColumnLayout {
                id: eventCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.events.length
                    delegate: Rectangle {
                        id: eventRow
                        required property int index
                        readonly property var ev: root.events[index]
                        Layout.fillWidth: true
                        implicitHeight: rowInner.implicitHeight + 12
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSecondaryContainer

                        RowLayout {
                            id: rowInner
                            anchors { fill: parent; margins: 6 }
                            spacing: 6

                            ColumnLayout {
                                spacing: -2
                                Layout.fillWidth: true
                                StyledText {
                                    text: eventRow.ev?.name ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnSecondaryContainer
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    text: root.formatDate(eventRow.ev?.target ?? "")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: 0.6
                                }
                            }

                            StyledText {
                                text: root.formatRemaining(eventRow.ev?.target ?? "")
                                font {
                                    family: Appearance.font.family.numbers
                                    pixelSize: Appearance.font.pixelSize.normal
                                }
                                color: Appearance.colors.colPrimary
                                Layout.alignment: Qt.AlignVCenter
                            }

                            RippleButton {
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: 11
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer4Hover
                                colRipple: Appearance.colors.colLayer4Active
                                downAction: () => root.removeEvent(eventRow.index)
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: Appearance.font.pixelSize.small
                                    fill: 0
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
