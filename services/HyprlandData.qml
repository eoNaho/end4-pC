pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        if (WM.compositor !== "hyprland") return;
        debounceClientsTimer.restart();
    }

    function updateLayers() {
        if (WM.compositor !== "hyprland") return;
        debounceLayersTimer.restart();
    }

    function updateMonitors() {
        if (WM.compositor !== "hyprland") return;
        debounceMonitorsTimer.restart();
    }

    function updateWorkspaces() {
        if (WM.compositor !== "hyprland") return;
        debounceWorkspacesTimer.restart();
    }

    function updateAll() {
        if (WM.compositor !== "hyprland") return;
        debounceClientsTimer.restart();
        debounceWorkspacesTimer.restart();
        debounceMonitorsTimer.restart();
    }

    function executeClients() {
        if (WM.compositor !== "hyprland") return;
        if (!getClients.running) getClients.running = true;
        if (!getActiveWorkspace.running) getActiveWorkspace.running = true;
    }

    function executeWorkspaces() {
        if (WM.compositor !== "hyprland") return;
        if (!getWorkspaces.running) getWorkspaces.running = true;
        if (!getActiveWorkspace.running) getActiveWorkspace.running = true;
    }

    function executeMonitors() {
        if (WM.compositor !== "hyprland") return;
        if (!getMonitors.running) getMonitors.running = true;
    }

    function executeLayers() {
        if (WM.compositor !== "hyprland") return;
        if (!getLayers.running) getLayers.running = true;
    }

    function executeAll() {
        if (WM.compositor !== "hyprland") return;
        executeClients();
        executeWorkspaces();
        executeMonitors();
        executeLayers();
    }

    Timer {
        id: debounceClientsTimer
        interval: 120
        repeat: false
        onTriggered: root.executeClients()
    }

    Timer {
        id: debounceWorkspacesTimer
        interval: 100
        repeat: false
        onTriggered: root.executeWorkspaces()
    }

    Timer {
        id: debounceMonitorsTimer
        interval: 250
        repeat: false
        onTriggered: root.executeMonitors()
    }

    Timer {
        id: debounceLayersTimer
        interval: 300
        repeat: false
        onTriggered: root.executeLayers()
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        executeAll();
    }

    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"

        function onRawEvent(event) {
            const name = event.name;
            if (!name || ["screencast", "windowtitle", "windowtitlev2", "submap", "bell", "urgent"].includes(name)) return;

            if (["workspace", "workspacev2", "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2", "focusedmon", "focusedmonv2"].includes(name)) {
                debounceWorkspacesTimer.restart();
            } else if (["openwindow", "closewindow", "movewindow", "movewindowv2", "activewindow", "activewindowv2", "fullscreen", "changefloatingmode", "pin"].includes(name)) {
                debounceClientsTimer.restart();
            } else if (["monitoradded", "monitoraddedv2", "monitorremoved"].includes(name)) {
                debounceMonitorsTimer.restart();
            } else if (["openlayer", "closelayer"].includes(name)) {
                debounceLayersTimer.restart();
            } else {
                root.updateAll();
            }
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                if (!clientsCollector.text || clientsCollector.text.trim().length === 0) return;
                try {
                    root.windowList = JSON.parse(clientsCollector.text)
                    let tempWinByAddress = {};
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i];
                        tempWinByAddress[win.address] = win;
                    }
                    root.windowByAddress = tempWinByAddress;
                    root.addresses = root.windowList.map(win => win.address);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse clients JSON:", e);
                }
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                if (!monitorsCollector.text || monitorsCollector.text.trim().length === 0) return;
                try {
                    root.monitors = JSON.parse(monitorsCollector.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse monitors JSON:", e);
                }
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                if (!layersCollector.text || layersCollector.text.trim().length === 0) return;
                try {
                    root.layers = JSON.parse(layersCollector.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse layers JSON:", e);
                }
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                if (!workspacesCollector.text || workspacesCollector.text.trim().length === 0) return;
                try {
                    var rawWorkspaces = JSON.parse(workspacesCollector.text);
                    root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                    let tempWorkspaceById = {};
                    for (var i = 0; i < root.workspaces.length; ++i) {
                        var ws = root.workspaces[i];
                        tempWorkspaceById[ws.id] = ws;
                    }
                    root.workspaceById = tempWorkspaceById;
                    root.workspaceIds = root.workspaces.map(ws => ws.id);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse workspaces JSON:", e);
                }
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                if (!activeWorkspaceCollector.text || activeWorkspaceCollector.text.trim().length === 0) return;
                try {
                    root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
                } catch (e) {
                    console.warn("[HyprlandData] Failed to parse activeworkspace JSON:", e);
                }
            }
        }
    }
}