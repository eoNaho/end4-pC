pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

/**
 * Service to manage Google Tasks & Google Calendar synchronization.
 */
Singleton {
    id: root

    property bool loggedIn: false
    property var calendarEvents: []

    function login() {
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "login"]);
    }

    function sync() {
        authCheckProc.exec(["bash", "-c", "[ -s ~/.config/illogical-impulse/gauth.json ] && grep -q 'refresh_token' ~/.config/illogical-impulse/gauth.json"]);
    }

    Process {
        id: authCheckProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                syncProc.exec(["python3", Quickshell.shellPath("scripts/google_sync.py"), "sync"]);
            }
        }
    }

    Process {
        id: syncProc
        onExited: {
            Todo.refresh();
            calendarFileView.reload();
        }
    }

    function refreshCalendar() {
        calendarFileView.reload();
    }

    function addEvent(eventObj) {
        const jsonStr = JSON.stringify(eventObj);
        Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/google_sync.py"), "add-event", jsonStr]);
    }

    Timer {
        interval: 300000 // Every 5 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }

    FileView {
        id: calendarFileView
        path: `${Directories.state}/user/calendar_events.json`
        onLoaded: {
            try {
                root.calendarEvents = JSON.parse(calendarFileView.text());
            } catch (e) {
                root.calendarEvents = [];
            }
        }
    }
}
