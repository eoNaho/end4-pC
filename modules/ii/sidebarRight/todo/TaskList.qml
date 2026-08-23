import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "todo_utils.js" as TodoUtils

Item {
    id: root
    required property var taskList
    property string emptyPlaceholderIcon
    property string emptyPlaceholderText
    property int todoListItemSpacing: 5
    property int todoListItemPadding: 8
    property int listBottomPadding: 80

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: root.todoListItemSpacing
        animateAppearance: false
        model: ScriptModel {
            values: root.taskList
        }
        delegate: Item {
            id: todoItem
            required property var modelData
            property bool pendingDoneToggle: false
            property bool pendingDelete: false
            property bool enableHeightAnimation: false

            property bool isUpdating: false
            property bool isDeleting: false
            property bool isStarring: false
            property string feedbackMsg: ""
            property bool feedbackSynced: true

            Process {
                id: actionProcess
                property string pendingAction: ""
                property string pendingId: ""
                property string pendingArg: ""
                command: (pendingAction === "update" || pendingAction === "star") ?
                    ["python3", Quickshell.shellPath("scripts/google_sync.py"), "update-task", pendingId, pendingArg] :
                    ["python3", Quickshell.shellPath("scripts/google_sync.py"), "delete-task", pendingId]
                stdout: SplitParser {
                    onRead: (data) => {
                        if (data.includes("[RESULT]")) {
                            try {
                                const jsonStr = data.substring(data.indexOf("[RESULT]") + 8).trim();
                                const res = JSON.parse(jsonStr);
                                todoItem.feedbackSynced = res.synced ?? false;
                                if (actionProcess.pendingAction === "update") {
                                    todoItem.feedbackMsg = res.synced ? "✓ Sincronizado" : "💾 Guardado local";
                                } else if (actionProcess.pendingAction === "star") {
                                    todoItem.feedbackMsg = res.synced ? "✓ Sincronizado" : "💾 Guardado local";
                                } else {
                                    todoItem.feedbackMsg = res.synced ? "✓ Eliminado" : "💾 Eliminado local";
                                }
                            } catch (e) {
                                todoItem.feedbackMsg = "✓ Listo";
                            }
                        }
                    }
                }
                onExited: (exitCode) => {
                    todoItem.isUpdating = false;
                    todoItem.isDeleting = false;
                    todoItem.isStarring = false;
                    actionFinishTimer.restart();
                }
            }

            Timer {
                id: actionFinishTimer
                interval: 800
                onTriggered: {
                    if (actionProcess.pendingAction === "update") {
                        if (!todoItem.modelData.done)
                            Todo.markDone(todoItem.modelData.originalIndex);
                        else
                            Todo.markUnfinished(todoItem.modelData.originalIndex);
                    } else if (actionProcess.pendingAction === "delete") {
                        Todo.deleteItem(todoItem.modelData.originalIndex);
                    }
                    todoItem.feedbackMsg = "";
                }
            }

            implicitHeight: todoItemRectangle.implicitHeight
            width: ListView.view.width
            clip: true

            Behavior on implicitHeight {
                enabled: enableHeightAnimation
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Rectangle {
                id: todoItemRectangle
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: todoContentRowLayout.implicitHeight
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                ColumnLayout {
                    id: todoContentRowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 4

                    // Header row: Title + Star Button
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 6
                        Layout.topMargin: todoListItemPadding
                        spacing: 6

                        StyledText {
                            id: todoContentText
                            Layout.fillWidth: true
                            text: todoItem.modelData.content
                            wrapMode: Text.Wrap
                            font.strikeout: todoItem.modelData.done ?? false
                            color: todoItem.modelData.done ? Appearance.m3colors.m3outline : Appearance.m3colors.m3onSurface
                        }

                        TodoItemActionButton {
                            visible: !Boolean(todoItem.modelData.done)
                            Layout.alignment: Qt.AlignTop
                            spinning: todoItem.isStarring
                            enabled: !todoItem.isUpdating && !todoItem.isDeleting && !todoItem.isStarring
                            onClicked: {
                                todoItem.isStarring = true;
                                const newStar = !Boolean(todoItem.modelData.starred);
                                Todo.toggleStarred(todoItem.modelData.originalIndex);
                                actionProcess.pendingAction = "star";
                                actionProcess.pendingId = todoItem.modelData.gtask_id ?? "";
                                actionProcess.pendingArg = JSON.stringify({ "starred": newStar });
                                if (actionProcess.pendingId) {
                                    actionProcess.running = true;
                                } else {
                                    actionFinishTimer.restart();
                                }
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.isStarring ? "sync" : (todoItem.modelData.starred ? "star" : "star_outline")
                                iconSize: Appearance.font.pixelSize.larger
                                color: todoItem.isStarring ? Appearance.colors.colPrimary : (todoItem.modelData.starred ? "#F4B400" : Appearance.colors.colOnLayer1)
                            }
                        }
                    }

                    // Notes / Description preview (if any)
                    StyledText {
                        visible: (todoItem.modelData.notes ?? "").length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        text: todoItem.modelData.notes ?? ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }

                    // Badges: Due date & Recurrence
                    RowLayout {
                        visible: (dueBadgeText !== "") || (recurrenceBadgeText !== "")
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        spacing: 6

                        property string dueBadgeText: TodoUtils.formatDueDate(todoItem.modelData)
                        property bool isOverdueVal: TodoUtils.isOverdue(todoItem.modelData)
                        property string recurrenceBadgeText: TodoUtils.formatRecurrence(todoItem.modelData.recurrence)

                        // Due Date Badge
                        Rectangle {
                            visible: parent.dueBadgeText !== ""
                            implicitWidth: dueBadgeRow.implicitWidth + 10
                            implicitHeight: dueBadgeRow.implicitHeight + 4
                            radius: Appearance.rounding.full
                            color: parent.isOverdueVal ? ColorUtils.transparentize(Appearance.colors.colError, 0.8) : Appearance.colors.colLayer1

                            RowLayout {
                                id: dueBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: "calendar_today"
                                    iconSize: Appearance.font.pixelSize.smaller
                                    color: todoContentRowLayout.parent ? (todoItem.modelData.done ? Appearance.m3colors.m3outline : (todoContentRowLayout.isOverdueVal ? Appearance.colors.colError : Appearance.colors.colPrimary)) : Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: parent.parent.parent.dueBadgeText
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: todoItem.modelData.done ? Appearance.m3colors.m3outline : (todoContentRowLayout.isOverdueVal ? Appearance.colors.colError : Appearance.colors.colPrimary)
                                }
                            }
                        }

                        // Recurrence Badge
                        Rectangle {
                            visible: parent.recurrenceBadgeText !== ""
                            implicitWidth: recBadgeRow.implicitWidth + 10
                            implicitHeight: recBadgeRow.implicitHeight + 4
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colLayer1

                            RowLayout {
                                id: recBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: "repeat"
                                    iconSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSecondary
                                }
                                StyledText {
                                    text: parent.parent.parent.recurrenceBadgeText
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSecondary
                                }
                            }
                        }
                    }

                    // Bottom Action Row
                    RowLayout {
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.bottomMargin: todoListItemPadding
                        spacing: 5

                        StyledText {
                            visible: todoItem.feedbackMsg !== ""
                            text: todoItem.feedbackMsg
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: todoItem.feedbackSynced ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        TodoItemActionButton {
                            Layout.fillWidth: false
                            spinning: todoItem.isUpdating
                            enabled: !todoItem.isUpdating && !todoItem.isDeleting
                            onClicked: {
                                todoItem.isUpdating = true;
                                actionProcess.pendingAction = "update";
                                actionProcess.pendingId = todoItem.modelData.gtask_id ?? "";
                                actionProcess.pendingArg = !todoItem.modelData.done ? "true" : "false";
                                if (actionProcess.pendingId) {
                                    actionProcess.running = true;
                                } else {
                                    actionFinishTimer.restart();
                                }
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.isUpdating ? "sync" : (todoItem.modelData.done ? "remove_done" : "check")
                                iconSize: Appearance.font.pixelSize.larger
                                color: todoItem.isUpdating ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                        }
                        TodoItemActionButton {
                            Layout.fillWidth: false
                            spinning: todoItem.isDeleting
                            enabled: !todoItem.isUpdating && !todoItem.isDeleting
                            onClicked: {
                                todoItem.isDeleting = true;
                                actionProcess.pendingAction = "delete";
                                actionProcess.pendingId = todoItem.modelData.gtask_id ?? "";
                                if (actionProcess.pendingId) {
                                    actionProcess.running = true;
                                } else {
                                    actionFinishTimer.restart();
                                }
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.isDeleting ? "sync" : "delete_forever"
                                iconSize: Appearance.font.pixelSize.larger
                                color: todoItem.isDeleting ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        // Placeholder when list is empty
        visible: opacity > 0
        opacity: taskList.length === 0 ? 1 : 0
        anchors.fill: parent

        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: emptyPlaceholderIcon
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: emptyPlaceholderText
            }
        }
    }
}
