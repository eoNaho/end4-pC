import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property var dateObject

    signal dayClicked(var date)

    readonly property string dateString: {
        if (!dateObject) return "";
        const d = (dateObject instanceof Date) ? dateObject : new Date(dateObject);
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const dayNum = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${dayNum}`;
    }

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

    function getColorForEvent(e) {
        const colorIdMap = {
            "1": "#4285F4",
            "2": "#0F9D58",
            "3": "#9C27B0",
            "4": "#DB4437",
            "5": "#F4B400",
            "6": "#F4511E",
            "7": "#039BE5",
            "8": "#757575",
            "9": "#3F51B5",
            "10": "#0B8043",
            "11": "#D50000"
        };
        return colorIdMap[e.colorId] ?? Appearance.colors.colPrimary;
    }

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small

    onClicked: {
        if (button.dateObject) {
            button.dayClicked(button.dateObject);
        }
    }
    
    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 1

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: day
                horizontalAlignment: Text.AlignHCenter
                font.weight: bold ? Font.DemiBold : Font.Normal
                color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : 
                    (isToday == 0) ? Appearance.colors.colOnLayer1 : 
                    Appearance.colors.colOutlineVariant

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            // Google Calendar event dots
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                visible: button.dayEvents.length > 0

                Repeater {
                    model: button.dayEvents.slice(0, 3)
                    delegate: Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: button.isToday == 1 ? "white" : button.getColorForEvent(modelData)
                    }
                }
            }
        }
    }
}

