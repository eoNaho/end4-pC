import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "todo_utils.js" as TodoUtils

Rectangle {
    id: root

    signal taskAdded()
    signal cancelled()

    color: Appearance.m3colors.m3surfaceContainerHigh
    radius: Appearance.rounding.normal

    property bool isAdding: false
    property string addFeedbackMsg: ""
    property bool addFeedbackSynced: true

    // Form states
    property bool isStarred: false
    property bool hasDueDate: false
    property int dueYear: new Date().getFullYear()
    property int dueMonth: new Date().getMonth() + 1
    property int dueDay: new Date().getDate()

    property bool hasDueTime: false
    property int dueHour: 10
    property int dueMinute: 0

    property bool isRepeating: false
    property int repeatInterval: 1
    property int repeatFreqIndex: 1 // 0: Días, 1: Semanas, 2: Meses, 3: Años
    property var weeklyDays: [false, false, false, false, false, false, false]
    property int monthlyRepeatType: 0 // 0: Día X, 1: Posición día semana
    property int monthlyDay: new Date().getDate()
    property int monthlyPosIndex: 0 // 0: Primer, 1: Segundo, 2: Tercer, 3: Cuarto, 4: Último
    property int monthlyWeekdayIndex: 0 // 0: Lunes, 1: Martes...
    property int repeatEndType: 0 // 0: Nunca, 1: En fecha, 2: Después de X
    property int repeatEndYear: new Date().getFullYear() + 1
    property int repeatEndMonth: new Date().getMonth() + 1
    property int repeatEndDay: new Date().getDate()
    property int repeatEndCount: 10

    readonly property var monthNames: [
        Translation.tr("January"), Translation.tr("February"), Translation.tr("March"),
        Translation.tr("April"), Translation.tr("May"), Translation.tr("June"),
        Translation.tr("July"), Translation.tr("August"), Translation.tr("September"),
        Translation.tr("October"), Translation.tr("November"), Translation.tr("December")
    ]

    readonly property var weekdayShortNames: [
        Translation.tr("Mo"), Translation.tr("Tu"), Translation.tr("We"),
        Translation.tr("Th"), Translation.tr("Fr"), Translation.tr("Sa"), Translation.tr("Su")
    ]

    function resetForm() {
        titleInput.text = "";
        notesInput.text = "";
        isStarred = false;
        hasDueDate = false;
        const now = new Date();
        dueYear = now.getFullYear();
        dueMonth = now.getMonth() + 1;
        dueDay = now.getDate();
        hasDueTime = false;
        dueHour = 10;
        dueMinute = 0;
        isRepeating = false;
        repeatInterval = 1;
        repeatFreqIndex = 1;
        const todayDayOfWeek = (now.getDay() + 6) % 7;
        const days = [false, false, false, false, false, false, false];
        days[todayDayOfWeek] = true;
        weeklyDays = days;
        monthlyRepeatType = 0;
        monthlyDay = now.getDate();
        monthlyPosIndex = 0;
        monthlyWeekdayIndex = todayDayOfWeek;
        repeatEndType = 0;
        repeatEndYear = now.getFullYear() + 1;
        repeatEndMonth = now.getMonth() + 1;
        repeatEndDay = now.getDate();
        repeatEndCount = 10;
        addFeedbackMsg = "";
        isAdding = false;
    }

    function setQuickDate(daysOffset) {
        if (daysOffset < 0) {
            hasDueDate = false;
            hasDueTime = false;
            isRepeating = false;
            return;
        }
        const d = new Date();
        d.setDate(d.getDate() + daysOffset);
        dueYear = d.getFullYear();
        dueMonth = d.getMonth() + 1;
        dueDay = d.getDate();
        hasDueDate = true;

        const dayIdx = (d.getDay() + 6) % 7;
        const arr = [false, false, false, false, false, false, false];
        arr[dayIdx] = true;
        weeklyDays = arr;
        monthlyDay = d.getDate();
        monthlyWeekdayIndex = dayIdx;
    }

    function toggleWeekday(index) {
        const arr = root.weeklyDays.slice(0);
        arr[index] = !arr[index];
        root.weeklyDays = arr;
    }

    Process {
        id: addTaskProcess
        property string pendingPayload: ""
        command: ["python3", Quickshell.shellPath("scripts/google_sync.py"), "add-task", pendingPayload]
        stdout: SplitParser {
            onRead: (data) => {
                if (data.includes("[RESULT]")) {
                    try {
                        const jsonStr = data.substring(data.indexOf("[RESULT]") + 8).trim();
                        const res = JSON.parse(jsonStr);
                        root.addFeedbackSynced = res.synced ?? false;
                        root.addFeedbackMsg = res.synced ? Translation.tr("✓ Sincronizado con Google Tasks") : Translation.tr("💾 Guardado localmente");
                    } catch (e) {
                        root.addFeedbackMsg = Translation.tr("✓ Tarea agregada");
                    }
                }
            }
        }
        onExited: (exitCode) => {
            root.isAdding = false;
            Todo.refresh();
            addFinishTimer.restart();
        }
    }

    Timer {
        id: addFinishTimer
        interval: 900
        onTriggered: {
            root.resetForm();
            root.taskAdded();
        }
    }

    function submitTask() {
        const title = titleInput.text.trim();
        if (title.length === 0 || root.isAdding) return;

        root.isAdding = true;
        root.addFeedbackMsg = "";

        const payloadObj = {
            "content": title,
            "notes": notesInput.text.trim(),
            "starred": root.isStarred,
            "done": false
        };

        if (root.hasDueDate) {
            const mm = String(root.dueMonth).padStart(2, '0');
            const dd = String(root.dueDay).padStart(2, '0');
            payloadObj.due_date = `${root.dueYear}-${mm}-${dd}`;
            payloadObj.has_time = root.hasDueTime;
            if (root.hasDueTime) {
                const hh = String(root.dueHour).padStart(2, '0');
                const min = String(root.dueMinute).padStart(2, '0');
                payloadObj.due_time = `${hh}:${min}`;
                payloadObj.due = `${payloadObj.due_date}T${hh}:${min}:00.000Z`;
            } else {
                payloadObj.due = `${payloadObj.due_date}T00:00:00.000Z`;
            }
        }

        if (root.isRepeating && root.hasDueDate) {
            const freqs = ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"];
            const daysCode = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"];
            const posCode = ["FIRST", "SECOND", "THIRD", "FOURTH", "LAST"];
            const rec = {
                "interval": root.repeatInterval,
                "frequency": freqs[root.repeatFreqIndex] || "DAILY"
            };

            if (rec.frequency === "WEEKLY") {
                const selDays = [];
                for (let i = 0; i < 7; i++) {
                    if (root.weeklyDays[i]) selDays.push(daysCode[i]);
                }
                rec.weekdays = selDays.length > 0 ? selDays : [daysCode[(new Date(root.dueYear, root.dueMonth - 1, root.dueDay).getDay() + 6) % 7]];
            } else if (rec.frequency === "MONTHLY") {
                if (root.monthlyRepeatType === 1) {
                    rec.monthly_type = "weekday_position";
                    rec.month_pos = posCode[root.monthlyPosIndex] || "FIRST";
                    rec.month_weekday = daysCode[root.monthlyWeekdayIndex] || "MO";
                } else {
                    rec.monthly_type = "day_of_month";
                    rec.month_day = root.monthlyDay;
                }
            }

            if (root.repeatEndType === 1) {
                rec.end_type = "date";
                const em = String(root.repeatEndMonth).padStart(2, '0');
                const ed = String(root.repeatEndDay).padStart(2, '0');
                rec.end_date = `${root.repeatEndYear}-${em}-${ed}`;
            } else if (root.repeatEndType === 2) {
                rec.end_type = "count";
                rec.end_count = root.repeatEndCount;
            } else {
                rec.end_type = "never";
            }

            payloadObj.recurrence = rec;
        }

        Todo.addItem(payloadObj);
        addTaskProcess.pendingPayload = JSON.stringify(payloadObj);
        addTaskProcess.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header: Title & Star Toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                font.weight: Font.DemiBold
                font.pixelSize: Appearance.font.pixelSize.larger
                color: Appearance.m3colors.m3onSurface
                text: Translation.tr("Add Task")
            }

            RippleButton {
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: root.isStarred ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8) : "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.isStarred = !root.isStarred

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.isStarred ? "star" : "star_outline"
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.isStarred ? "#F4B400" : Appearance.colors.colOnLayer1
                }
            }
        }

        // Scrollable content form
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: formLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: formLayout
                width: parent.width
                spacing: 12

                // Task title
                TextField {
                    id: titleInput
                    Layout.fillWidth: true
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Task title")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: true
                    enabled: !root.isAdding
                    onAccepted: root.submitTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: titleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: titleInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                // Notes input
                TextField {
                    id: notesInput
                    Layout.fillWidth: true
                    padding: 8
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Detalles o notas (opcional)")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    enabled: !root.isAdding

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 1
                        border.color: notesInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        color: Appearance.colors.colLayer1
                    }
                }

                // SECTION: Due Date
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dateSectionCol.implicitHeight + 16
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        id: dateSectionCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "calendar_today"
                                iconSize: Appearance.font.pixelSize.normal
                                color: root.hasDueDate ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Due date")
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer0
                            }
                            Item { Layout.fillWidth: true }
                            StyledSwitch {
                                checked: root.hasDueDate
                                onCheckedChanged: {
                                    root.hasDueDate = checked;
                                    if (!checked) {
                                        root.hasDueTime = false;
                                        root.isRepeating = false;
                                    }
                                }
                            }
                        }

                        // Quick Chips
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: !root.hasDueDate ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                onClicked: root.setQuickDate(-1)
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("No date")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: !root.hasDueDate ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                            }
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: (root.hasDueDate && root.dueDay === new Date().getDate() && root.dueMonth === (new Date().getMonth() + 1)) ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                onClicked: root.setQuickDate(0)
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("Today")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: (root.hasDueDate && root.dueDay === new Date().getDate() && root.dueMonth === (new Date().getMonth() + 1)) ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                            }
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: Appearance.colors.colLayer2
                                onClicked: root.setQuickDate(1)
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("Tomorrow")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 28
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: Appearance.colors.colLayer2
                                onClicked: root.setQuickDate(7)
                                contentItem: StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("+7 days")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }

                        // Date Pickers (when enabled)
                        RowLayout {
                            visible: root.hasDueDate
                            Layout.fillWidth: true
                            spacing: 6

                            StyledSpinBox {
                                Layout.preferredWidth: 65
                                from: 1
                                to: 31
                                value: root.dueDay
                                onValueChanged: root.dueDay = value
                            }
                            StyledComboBox {
                                Layout.fillWidth: true
                                model: root.monthNames
                                currentIndex: root.dueMonth - 1
                                onCurrentIndexChanged: root.dueMonth = currentIndex + 1
                            }
                            StyledSpinBox {
                                Layout.preferredWidth: 80
                                from: 2026
                                to: 2035
                                value: root.dueYear
                                onValueChanged: root.dueYear = value
                            }
                        }
                    }
                }

                // SECTION: Time Picker
                Rectangle {
                    visible: root.hasDueDate
                    Layout.fillWidth: true
                    implicitHeight: timeSectionCol.implicitHeight + 16
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        id: timeSectionCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "schedule"
                                iconSize: Appearance.font.pixelSize.normal
                                color: root.hasDueTime ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Set time")
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer0
                            }
                            Item { Layout.fillWidth: true }
                            StyledSwitch {
                                checked: root.hasDueTime
                                onCheckedChanged: root.hasDueTime = checked
                            }
                        }

                        RowLayout {
                            visible: root.hasDueTime
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            StyledSpinBox {
                                from: 0
                                to: 23
                                value: root.dueHour
                                onValueChanged: root.dueHour = value
                            }
                            StyledText {
                                text: ":"
                                font.weight: Font.Bold
                                font.pixelSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer0
                            }
                            StyledSpinBox {
                                from: 0
                                to: 59
                                stepSize: 5
                                value: root.dueMinute
                                onValueChanged: root.dueMinute = value
                            }
                        }
                    }
                }

                // SECTION: Recurrence (Repetir)
                Rectangle {
                    visible: root.hasDueDate
                    Layout.fillWidth: true
                    implicitHeight: repeatSectionCol.implicitHeight + 16
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        id: repeatSectionCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "repeat"
                                iconSize: Appearance.font.pixelSize.normal
                                color: root.isRepeating ? Appearance.colors.colSecondary : Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Repeat task")
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer0
                            }
                            Item { Layout.fillWidth: true }
                            StyledSwitch {
                                checked: root.isRepeating
                                onCheckedChanged: root.isRepeating = checked
                            }
                        }

                        ColumnLayout {
                            visible: root.isRepeating
                            Layout.fillWidth: true
                            spacing: 8

                            // Interval & Frequency Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                StyledText {
                                    text: Translation.tr("Every:")
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledSpinBox {
                                    Layout.preferredWidth: 65
                                    from: 1
                                    to: 99
                                    value: root.repeatInterval
                                    onValueChanged: root.repeatInterval = value
                                }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: [
                                        Translation.tr("Day(s)"),
                                        Translation.tr("Week(s)"),
                                        Translation.tr("Month(s)"),
                                        Translation.tr("Year(s)")
                                    ]
                                    currentIndex: root.repeatFreqIndex
                                    onCurrentIndexChanged: root.repeatFreqIndex = currentIndex
                                }
                            }

                            // WEEKLY Options: Day of week buttons
                            ColumnLayout {
                                visible: root.repeatFreqIndex === 1
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    text: Translation.tr("Days of the week:")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOutlineVariant
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Repeater {
                                        model: 7
                                        delegate: RippleButton {
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            buttonRadius: Appearance.rounding.verysmall
                                            colBackground: root.weeklyDays[index] ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                                            onClicked: root.toggleWeekday(index)
                                            contentItem: StyledText {
                                                anchors.centerIn: parent
                                                text: root.weekdayShortNames[index]
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: root.weeklyDays[index] ? Font.DemiBold : Font.Normal
                                                color: root.weeklyDays[index] ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                                            }
                                        }
                                    }
                                }
                            }

                            // MONTHLY Options: Day of month vs Position
                            ColumnLayout {
                                visible: root.repeatFreqIndex === 2
                                Layout.fillWidth: true
                                spacing: 6

                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: [
                                        Translation.tr("El mismo día del mes"),
                                        Translation.tr("Por posición del día en la semana")
                                    ]
                                    currentIndex: root.monthlyRepeatType
                                    onCurrentIndexChanged: root.monthlyRepeatType = currentIndex
                                }

                                // Option 0: Day of month
                                RowLayout {
                                    visible: root.monthlyRepeatType === 0
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledText {
                                        text: Translation.tr("Day of the month:")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledSpinBox {
                                        from: 1
                                        to: 31
                                        value: root.monthlyDay
                                        onValueChanged: root.monthlyDay = value
                                    }
                                }

                                // Option 1: Weekday position
                                RowLayout {
                                    visible: root.monthlyRepeatType === 1
                                    Layout.fillWidth: true
                                    spacing: 6

                                    StyledComboBox {
                                        Layout.fillWidth: true
                                        model: [
                                            Translation.tr("Primer"),
                                            Translation.tr("Segundo"),
                                            Translation.tr("Tercer"),
                                            Translation.tr("Cuarto"),
                                            Translation.tr("Último")
                                        ]
                                        currentIndex: root.monthlyPosIndex
                                        onCurrentIndexChanged: root.monthlyPosIndex = currentIndex
                                    }
                                    StyledComboBox {
                                        Layout.fillWidth: true
                                        model: [
                                            Translation.tr("Lunes"), Translation.tr("Martes"), Translation.tr("Miércoles"),
                                            Translation.tr("Jueves"), Translation.tr("Viernes"), Translation.tr("Sábado"), Translation.tr("Domingo")
                                        ]
                                        currentIndex: root.monthlyWeekdayIndex
                                        onCurrentIndexChanged: root.monthlyWeekdayIndex = currentIndex
                                    }
                                }
                            }

                            // END Condition (Finaliza)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                StyledText {
                                    text: Translation.tr("Ends:")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOutlineVariant
                                }

                                StyledComboBox {
                                    Layout.fillWidth: true
                                    model: [
                                        Translation.tr("Never"),
                                        Translation.tr("En la fecha..."),
                                        Translation.tr("Después de un número de repeticiones")
                                    ]
                                    currentIndex: root.repeatEndType
                                    onCurrentIndexChanged: root.repeatEndType = currentIndex
                                }

                                // End Date Picker
                                RowLayout {
                                    visible: root.repeatEndType === 1
                                    Layout.fillWidth: true
                                    spacing: 6

                                    StyledSpinBox {
                                        Layout.preferredWidth: 65
                                        from: 1
                                        to: 31
                                        value: root.repeatEndDay
                                        onValueChanged: root.repeatEndDay = value
                                    }
                                    StyledComboBox {
                                        Layout.fillWidth: true
                                        model: root.monthNames
                                        currentIndex: root.repeatEndMonth - 1
                                        onCurrentIndexChanged: root.repeatEndMonth = currentIndex + 1
                                    }
                                    StyledSpinBox {
                                        Layout.preferredWidth: 80
                                        from: 2026
                                        to: 2035
                                        value: root.repeatEndYear
                                        onValueChanged: root.repeatEndYear = value
                                    }
                                }

                                // End Count SpinBox
                                RowLayout {
                                    visible: root.repeatEndType === 2
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledText {
                                        text: Translation.tr("Repeats:")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer1
                                    }
                                    StyledSpinBox {
                                        from: 1
                                        to: 100
                                        value: root.repeatEndCount
                                        onValueChanged: root.repeatEndCount = value
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Progress Bar
        StyledIndeterminateProgressBar {
            visible: root.isAdding
            Layout.fillWidth: true
        }

        // Feedback Message
        StyledText {
            visible: root.addFeedbackMsg !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.addFeedbackMsg
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: root.addFeedbackSynced ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        }

        // Action Button Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            DialogButton {
                buttonText: Translation.tr("Cancel")
                enabled: !root.isAdding
                onClicked: {
                    root.resetForm();
                    root.cancelled();
                }
            }

            Item { Layout.fillWidth: true }

            DialogButton {
                buttonText: root.isAdding ? Translation.tr("Guardando...") : Translation.tr("Add Task")
                enabled: !root.isAdding && titleInput.text.trim().length > 0
                onClicked: root.submitTask()
            }
        }
    }
}
