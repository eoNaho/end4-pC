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
        if (!getClients.running) getClients.running = true;
    }

    function updateLayers() {
        if (WM.compositor !== "hyprland") return;
        if (!getLayers.running) getLayers.running = true;
    }

    function updateMonitors() {
        if (WM.compositor !== "hyprland") return;
        if (!getMonitors.running) getMonitors.running = true;
    }

    function updateWorkspaces() {
        if (WM.compositor !== "hyprland") return;
        if (!getWorkspaces.running) getWorkspaces.running = true;
        if (!getActiveWorkspace.running) getActiveWorkspace.running = true;
    }

    function updateAll() {
        if (WM.compositor !== "hyprland") return;
        debounceTimer.restart();
    }

    function executeAll() {
        if (WM.compositor !== "hyprland") return;
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    Timer {
        id: debounceTimer
        interval: 50
        repeat: false
        onTriggered: root.executeAll()
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
            if (["openlayer", "closelayer", "screencast"].includes(event.name)) return;
            root.updateAll()
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