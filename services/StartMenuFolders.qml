pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Windows 11 Start Menu App Folders / Categories manager.
 * Manages custom folders, categorizing pinned applications, and disk persistence.
 */
Singleton {
    id: root

    property var filePath: Directories.startMenuFoldersPath
    property var list: []

    readonly property var defaultFolders: [
        {
            "id": "folder_internet",
            "name": "Internet",
            "icon": "language",
            "apps": ["firefox.desktop", "google-chrome.desktop", "com.google.Chrome.desktop", "chromium.desktop", "discord.desktop"]
        },
        {
            "id": "folder_dev",
            "name": "Desenvolvimento",
            "icon": "terminal",
            "apps": ["kitty.desktop", "code-oss.desktop", "code.desktop", "Alacritty.desktop"]
        },
        {
            "id": "folder_productivity",
            "name": "Produtividade",
            "icon": "work",
            "apps": ["org.kde.dolphin.desktop", "org.kde.kate.desktop", "kwrite.desktop", "org.gnome.Calculator.desktop"]
        },
        {
            "id": "folder_media",
            "name": "Mídia & Jogos",
            "icon": "sports_esports",
            "apps": ["spotify.desktop", "vlc.desktop", "steam.desktop", "mpv.desktop"]
        }
    ]

    function findApp(appId) {
        if (!appId || typeof appId !== "string") return null;
        const cleanId = appId.trim();
        if (cleanId === "") return null;

        // 1. Quickshell DesktopEntries.byId
        try {
            let entry = DesktopEntries.byId(cleanId);
            if (entry) return entry;
        } catch (_) {}

        // 2. Direct heuristic lookup
        try {
            let entry = DesktopEntries.heuristicLookup(cleanId);
            if (entry) return entry;
        } catch (_) {}

        // 3. Lookup with/without .desktop
        try {
            if (!cleanId.endsWith(".desktop")) {
                let entry = DesktopEntries.byId(cleanId + ".desktop") || DesktopEntries.heuristicLookup(cleanId + ".desktop");
                if (entry) return entry;
            } else {
                const noExt = cleanId.replace(/\.desktop$/, "");
                let entry = DesktopEntries.byId(noExt) || DesktopEntries.heuristicLookup(noExt);
                if (entry) return entry;
            }
        } catch (_) {}

        // 4. Match from DesktopEntries.applications.values
        try {
            const allApps = Array.from(DesktopEntries.applications.values);
            const low = cleanId.toLowerCase().replace(/\.desktop$/, "");
            // Exact ID match
            let entry = allApps.find(a => a && a.id && (a.id.toLowerCase() === low || a.id.toLowerCase().replace(/\.desktop$/, "") === low));
            if (entry) return entry;
            // Exact name match
            entry = allApps.find(a => a && a.name && a.name.toLowerCase() === low);
            if (entry) return entry;
            // Partial ID / name / icon match
            entry = allApps.find(a => a && ((a.id && a.id.toLowerCase().includes(low)) || (a.name && a.name.toLowerCase().includes(low)) || (a.icon && a.icon.toLowerCase().includes(low))));
            if (entry) return entry;
        } catch (_) {}

        // 5. Fallback from AppSearch.list
        try {
            if (typeof AppSearch !== "undefined" && AppSearch.list) {
                const low = cleanId.toLowerCase().replace(/\.desktop$/, "");
                let entry = AppSearch.list.find(a => a && a.id && a.id.toLowerCase().replace(/\.desktop$/, "") === low);
                if (entry) return entry;
            }
        } catch (_) {}

        return null;
    }

    function getFolderResolvedApps(folder) {
        if (!folder) return [];
        const f = (typeof folder === "string") ? getFolder(folder) : (getFolder(folder?.id) || folder);
        if (!f || !Array.isArray(f.apps)) return [];
        return f.apps.map(id => findApp(id)).filter(e => e !== null && e !== undefined);
    }

    function save() {
        foldersFileView.setText(JSON.stringify(root.list, null, 2));
    }

    function createFolder(name, initialAppId = "") {
        const cleanName = (name && name.trim() !== "") ? name.trim() : "Nova Pasta";
        const newId = "folder_" + Date.now();
        const apps = (initialAppId && String(initialAppId).trim() !== "") ? [String(initialAppId).trim()] : [];
        const newFolder = {
            "id": newId,
            "name": cleanName,
            "icon": "folder",
            "apps": apps
        };
        root.list = root.list.concat([newFolder]);
        save();
        return newFolder;
    }

    function createFolderFromApps(appId1, appId2, name = "Nova Pasta") {
        if (!appId1 || !appId2) return null;
        const cleanName = (name && name.trim() !== "") ? name.trim() : "Nova Pasta";
        const newId = "folder_" + Date.now();
        const newFolder = {
            "id": newId,
            "name": cleanName,
            "icon": "folder",
            "apps": [String(appId1).trim(), String(appId2).trim()]
        };
        root.list = root.list.concat([newFolder]);
        save();
        return newFolder;
    }

    function deleteFolder(folderId) {
        root.list = root.list.filter(f => f && f.id !== folderId);
        save();
    }

    function renameFolder(folderId, newName) {
        if (!newName || newName.trim() === "") return;
        root.list = root.list.map(f => {
            if (f && f.id === folderId) {
                return Object.assign({}, f, { "name": newName.trim() });
            }
            return f;
        });
        save();
    }

    function addAppToFolder(folderId, appId) {
        if (!folderId || !appId) return;
        const targetId = String(appId).trim();
        let changed = false;
        const updated = root.list.map(f => {
            if (f && f.id === folderId) {
                const curApps = Array.isArray(f.apps) ? f.apps.slice(0) : [];
                if (!curApps.includes(targetId)) {
                    curApps.push(targetId);
                    changed = true;
                    return Object.assign({}, f, { "apps": curApps });
                }
            }
            return f;
        });
        if (changed) {
            root.list = updated.slice(0);
            save();
        }
    }

    function removeAppFromFolder(folderId, appId) {
        if (!folderId || !appId) return;
        const targetId = String(appId).trim().toLowerCase();
        const targetNoExt = targetId.replace(/\.desktop$/, "");
        let changed = false;
        const updated = root.list.map(f => {
            if (f && f.id === folderId) {
                const curApps = Array.isArray(f.apps) ? f.apps : [];
                changed = true;
                return Object.assign({}, f, {
                    "apps": curApps.filter(id => {
                        const curId = String(id).trim().toLowerCase();
                        const curNoExt = curId.replace(/\.desktop$/, "");
                        return curId !== targetId && curNoExt !== targetNoExt;
                    })
                });
            }
            return f;
        });
        if (changed) {
            root.list = updated.slice(0);
            save();
        }
    }

    function getFolder(folderId) {
        return root.list.find(f => f && f.id === folderId) || null;
    }

    function isAppInFolder(folderId, appId) {
        const f = getFolder(folderId);
        return f && Array.isArray(f.apps) && f.apps.includes(String(appId).trim());
    }

    Component.onCompleted: {
        foldersFileView.reload();
    }

    FileView {
        id: foldersFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                const fileContents = foldersFileView.text();
                if (fileContents && fileContents.trim() !== "") {
                    const parsed = JSON.parse(fileContents);
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.list = parsed;
                        console.log("[StartMenuFolders] Loaded " + parsed.length + " folders.");
                        return;
                    }
                }
            } catch (e) {
                console.warn("[StartMenuFolders] Parse error:", e);
            }
            // Fallback to default folders
            root.list = root.defaultFolders;
            save();
        }
        onLoadFailed: (error) => {
            console.log("[StartMenuFolders] Initializing default folders: " + error);
            root.list = root.defaultFolders;
            save();
        }
    }
}
