pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * Simple to-do list manager.
 * Each item is an object with "content" and "done" properties.
 */
Singleton {
    id: root
    property var filePath: Directories.todoPath
    property var list: []
    
    function addItem(item) {
        list.push(item)
        // Reassign to trigger onListChanged
        root.list = list.slice(0)
        todoFileView.setText(JSON.stringify(root.list))
    }

    function addTask(descOrObj) {
        let item = {};
        if (typeof descOrObj === "string") {
            item = {
                "content": descOrObj,
                "done": false,
                "starred": false
            };
        } else if (typeof descOrObj === "object" && descOrObj !== null) {
            item = Object.assign({ "done": false, "starred": false }, descOrObj);
        }
        addItem(item);
        const payload = (typeof descOrObj === "string") ? descOrObj : JSON.stringify(descOrObj);
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "add-task", payload]);
    }

    function toggleStarred(index) {
        if (index >= 0 && index < list.length) {
            const gtaskId = list[index].gtask_id ?? "";
            list[index].starred = !Boolean(list[index].starred);
            root.list = list.slice(0);
            todoFileView.setText(JSON.stringify(root.list));
            if (gtaskId) {
                const payload = JSON.stringify({ "starred": list[index].starred });
                Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "update-task", gtaskId, payload]);
            }
        }
    }

    function markDone(index) {
        if (index >= 0 && index < list.length) {
            const gtaskId = list[index].gtask_id ?? "";
            list[index].done = true
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
            if (gtaskId) {
                Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "update-task", gtaskId, "true"]);
            }
        }
    }

    function markUnfinished(index) {
        if (index >= 0 && index < list.length) {
            const gtaskId = list[index].gtask_id ?? "";
            list[index].done = false
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
            if (gtaskId) {
                Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "update-task", gtaskId, "false"]);
            }
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < list.length) {
            const gtaskId = list[index].gtask_id ?? "";
            list.splice(index, 1)
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
            if (gtaskId) {
                Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "delete-task", gtaskId]);
            }
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const fileContents = todoFileView.text()
            root.list = JSON.parse(fileContents)
            console.log("[To Do] File loaded")
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[To Do] File not found, creating new file.")
                root.list = []
                todoFileView.setText(JSON.stringify(root.list))
            } else {
                console.log("[To Do] Error loading file: " + error)
            }
        }
    }
}

