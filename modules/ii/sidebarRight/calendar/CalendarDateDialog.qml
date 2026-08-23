import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

WindowDialog {
    id: root

    property var selectedDate: new Date()

    function toIsoDate(d) {
        if (!d) return "";
        const dateObj = (d instanceof Date) ? d : new Date(d);
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    property string dateString: toIsoDate(selectedDate)
    property string dateDisplayString: selectedDate ? selectedDate.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM 'de' yyyy") : ""
    property bool isAllDay: false
    property string selectedColor: "#4285F4"
    property string selectedColorId: "1"

    property bool isSaving: false
    property string statusMessage: ""
    property bool isStatusSuccess: true
    property string pendingJson: ""

    backgroundHeight: 650

    // Filter events matching the selected date
    readonly property var dayEvents: {
        if (!dateString) return [];
        const events = GoogleService.calendarEvents ?? [];
        return events.filter(e => {
            const start = e.start ?? "";
            const end = e.end ?? "";
            if (start.startsWith(dateString)) return true;
            if (start.length >= 10 && end.length >= 10) {
                const sDate = start.substring(0, 10);
                const eDate = end.substring(0, 10);
                if (dateString >= sDate && dateString < eDate) return true;
            }
            return false;
        });
    }

    readonly property list<var> colorOptions: [
        { color: "#4285F4", id: "1", name: Translation.tr("Blue") },
        { color: "#0F9D58", id: "2", name: Translation.tr("Green") },
        { color: "#9C27B0", id: "3", name: Translation.tr("Purple") },
        { color: "#DB4437", id: "4", name: Translation.tr("Red") },
        { color: "#F4B400", id: "5", name: Translation.tr("Yellow") }
    ]

    Process {
        id: saveProcess
        command: ["python3", Quickshell.shellPath("scripts/google_sync.py"), "add-event", root.pendingJson]
        stdout: SplitParser {
            onRead: (data) => {
                if (data.includes("[RESULT]")) {
                    try {
                        const jsonStr = data.substring(data.indexOf("[RESULT]") + 8).trim();
                        const res = JSON.parse(jsonStr);
                        if (res.synced) {
                            root.statusMessage = Translation.tr("✓ Event saved and synced with Google Calendar");
                            root.isStatusSuccess = true;
                        } else {
                            root.statusMessage = Translation.tr("💾 Saved locally (will sync later)");
                            root.isStatusSuccess = false;
                        }
                    } catch (e) {
                        root.statusMessage = Translation.tr("💾 Saved locally");
                        root.isStatusSuccess = false;
                    }
                }
            }
        }
        onExited: (exitCode) => {
            root.isSaving = false;
            GoogleService.refreshCalendar();
            closeDelayTimer.restart();
        }
    }

    Timer {
        id: closeDelayTimer
        interval: 1400
        onTriggered: {
            titleInput.text = "";
            descriptionInput.text = "";
            root.statusMessage = "";
            root.dismiss();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2

        StyledText {
            Layout.fillWidth: true
            text: root.dateDisplayString ? (root.dateDisplayString.charAt(0).toUpperCase() + root.dateDisplayString.slice(1)) : ""
            font.weight: Font.DemiBold
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer0
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeight: 1.15
            elide: Text.ElideRight
        }
    }

    WindowDialogSeparator {}

    Flickable {
        Layout.fillHeight: true
        Layout.fillWidth: true
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 12

            // SECTION 1: Eventos Sincronizados
            StyledText {
                text: Translation.tr("Google Calendar Events")
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }

            Repeater {
                model: root.dayEvents
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: eventCol.implicitHeight + 16
                    radius: Appearance.rounding.medium
                    color: Appearance.colors.colLayer2
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    RowLayout {
                        id: eventCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: modelData.summary ?? "Sin título"
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnLayer0
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: {
                                    const s = modelData.start ?? "";
                                    const e = modelData.end ?? "";
                                    if (s.includes("T")) {
                                        const startTime = s.split("T")[1].substring(0, 5);
                                        const endTime = e.includes("T") ? e.split("T")[1].substring(0, 5) : "";
                                        return endTime ? `${startTime} - ${endTime}` : startTime;
                                    }
                                    return Translation.tr("All day");
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOutlineVariant
                            }

                            StyledText {
                                visible: (modelData.description ?? "") !== ""
                                text: modelData.description ?? ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.dayEvents.length === 0
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1

                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("No events scheduled for this day.")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOutlineVariant
                }
            }

            WindowDialogSeparator {
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // SECTION 2: Formulario Agregar Evento
            StyledText {
                text: Translation.tr("Add New Event")
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }

            // Título
            ToolbarTextField {
                id: titleInput
                Layout.fillWidth: true
                placeholderText: Translation.tr("Event title")
                enabled: !root.isSaving
            }

            // Switch Todo el día
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Translation.tr("All day")
                    color: Appearance.colors.colOnLayer0
                    Layout.fillWidth: true
                }
                ConfigSwitch {
                    checked: root.isAllDay
                    enabled: !root.isSaving
                    onCheckedChanged: root.isAllDay = checked
                }
            }

            // Horas (Inicio / Fin)
            RowLayout {
                visible: !root.isAllDay
                Layout.fillWidth: true
                spacing: 8

                ToolbarTextField {
                    id: startTimeInput
                    Layout.fillWidth: true
                    text: "09:00"
                    placeholderText: "09:00"
                    enabled: !root.isSaving
                }

                StyledText {
                    text: "—"
                    color: Appearance.colors.colOutlineVariant
                }

                ToolbarTextField {
                    id: endTimeInput
                    Layout.fillWidth: true
                    text: "10:00"
                    placeholderText: "10:00"
                    enabled: !root.isSaving
                }
            }

            // Repetición
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Translation.tr("Repetición")
                    color: Appearance.colors.colOnLayer0
                    Layout.fillWidth: true
                }
                Rectangle {
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    implicitWidth: repeatText.implicitWidth + 16
                    implicitHeight: 28
                    StyledText {
                        id: repeatText
                        anchors.centerIn: parent
                        text: Translation.tr("No se repite")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            // Color del puntito
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                StyledText {
                    text: Translation.tr("Color")
                    color: Appearance.colors.colOnLayer0
                    Layout.fillWidth: true
                }

                Repeater {
                    model: root.colorOptions
                    delegate: RippleButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: 12
                        colBackground: modelData.color
                        colBackgroundHover: modelData.color
                        enabled: !root.isSaving
                        onClicked: {
                            root.selectedColor = modelData.color;
                            root.selectedColorId = modelData.id;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: "white"
                            visible: root.selectedColor === modelData.color
                        }
                    }
                }
            }

            // Descripción
            ToolbarTextField {
                id: descriptionInput
                Layout.fillWidth: true
                placeholderText: Translation.tr("Agregar descripción")
                enabled: !root.isSaving
            }
        }
    }

    // Status Feedback Banner
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: Appearance.rounding.small
        visible: root.statusMessage !== ""
        color: root.isStatusSuccess ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
        border.width: 1
        border.color: root.isStatusSuccess ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            MaterialSymbol {
                text: root.isStatusSuccess ? "check_circle" : "cloud_sync"
                iconSize: 18
                color: root.isStatusSuccess ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: root.statusMessage
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
        }
    }

    StyledIndeterminateProgressBar {
        visible: root.isSaving
        Layout.fillWidth: true
        Layout.topMargin: -4
        Layout.bottomMargin: -4
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Cancelar")
            enabled: !root.isSaving
            onClicked: root.dismiss()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: root.isSaving ? Translation.tr("Saving...") : Translation.tr("Guardar en Google")
            enabled: !root.isSaving && titleInput.text.trim().length > 0
            onClicked: {
                const summary = titleInput.text.trim();
                const desc = descriptionInput.text.trim();
                let start, end;
                if (root.isAllDay) {
                    start = root.dateString;
                    end = root.dateString;
                } else {
                    const st = startTimeInput.text.trim() || "09:00";
                    const et = endTimeInput.text.trim() || "10:00";
                    start = `${root.dateString}T${st}:00`;
                    end = `${root.dateString}T${et}:00`;
                }

                root.isSaving = true;
                root.statusMessage = "";
                root.pendingJson = JSON.stringify({
                    summary: summary,
                    description: desc,
                    start: start,
                    end: end,
                    colorId: root.selectedColorId,
                    allDay: root.isAllDay
                });
                saveProcess.running = true;
            }
        }
    }
}
