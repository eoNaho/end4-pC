pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
    id: startMenuScope

    IpcHandler {
        target: "startmenu"

        function toggle() {
            GlobalStates.startMenuOpen = !GlobalStates.startMenuOpen;
        }
        function open() {
            GlobalStates.startMenuOpen = true;
        }
        function close() {
            GlobalStates.startMenuOpen = false;
        }
    }

    CompositorGlobalShortcut {
        name: "startMenuToggle"
        description: "Toggles Windows 11 Start Menu"
        onPressed: {
            GlobalStates.startMenuOpen = !GlobalStates.startMenuOpen;
        }
    }

    PanelWindow {
        id: root

        visible: GlobalStates.startMenuOpen && !GlobalStates.screenLocked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "quickshell:win11StartMenu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.startMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusiveZone: 0
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        property string searchText: ""
        property string rawSearchInput: ""
        property int searchSelectedIndex: 0
        property bool powerFlyoutOpen: false
        property bool showAllApps: false
        property var contextMenuTargetApp: null
        property var contextMenuTargetFile: null
        property point contextMenuPos: Qt.point(0, 0)
        property bool appContextMenuOpen: false
        property var activeFolder: null
        property bool folderModalOpen: false
        property bool newFolderDialogOpen: false
        property string newFolderNameInput: ""
        property bool folderPickerOpen: false
        property var folderPickerTargetApp: null
        property bool addAppToFolderDialogOpen: false
        property string addAppSearchQuery: ""
        property var draggingApp: null
        property point dragCurrentPos: Qt.point(0, 0)
        property bool isDraggingApp: false
        property var dragDropTargetFolder: null
        property var dragDropTargetApp: null
        property string recommendedTab: "all"
        property string searchFilterTab: "all" // "all", "apps", "files", "settings"
        property bool alphabetJumpModalOpen: false
        property string copiedToastText: ""

        readonly property bool startMenuCentered: Config.options?.dock?.startMenuCentered ?? true
        readonly property bool showCompanion: Config.options?.dock?.startMenuCompanion ?? true
        readonly property bool acrylicBg: Config.options?.dock?.startMenuAcrylicBackground ?? false

        readonly property var settingsShortcuts: [
            { name: Translation.tr("Wallpaper & Style"), comment: Translation.tr("Settings"), icon: "wallpaper", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open appearance || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Interface & Start Menu"), comment: Translation.tr("Settings"), icon: "dashboard", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open interface || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Bluetooth"), comment: Translation.tr("Settings"), icon: "bluetooth", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open bluetooth || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Wi-Fi & Network"), comment: Translation.tr("Settings"), icon: "wifi", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open network || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Audio & Sound"), comment: Translation.tr("Settings"), icon: "volume_up", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open audio || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Power & Battery"), comment: Translation.tr("Settings"), icon: "battery_charging_full", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open power || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } },
            { name: Translation.tr("Displays"), comment: Translation.tr("Settings"), icon: "monitor", isSetting: true, execute: () => { Quickshell.execDetached(["bash", "-c", "quickshell ipc call settings open displays || quickshell ipc call settings toggle"]); GlobalStates.startMenuOpen = false; } }
        ]

        function isAppPinned(app) {
            if (!app) return false;
            const id = app.id ?? app.appId ?? "";
            return (Config.options?.dock?.pinnedApps ?? []).includes(id);
        }

        function togglePinApp(app) {
            if (!app) return;
            const id = app.id ?? app.appId ?? "";
            if (id) {
                TaskbarApps.togglePin(id);
            }
        }

        function evaluateMath(raw) {
            if (!raw || typeof raw !== "string") return null;
            let s = raw.trim();
            if (s.length < 2) return null;
            
            s = s.replace(/(\d+(\.\d+)?)\s*%\s*(of|\*)\s*(\d+(\.\d+)?)/gi, "($1/100)*$4");
            s = s.replace(/(\d+(\.\d+)?)\s*%/g, "($1/100)");
            s = s.replace(/\^/g, "**");
            
            if (!/[\d\)]\s*[\+\-\*\/\%]\s*[\d\(]/.test(s) && !/^(sqrt|sin|cos|tan|log|abs|pow|round|floor|ceil)\s*\(/.test(s) && !/^\d+\s*(\*\*|\^)\s*\d+/.test(s)) {
                return null;
            }
            
            let safeExpr = s
                .replace(/\b(sqrt|sin|cos|tan|log|abs|pow|round|floor|ceil)\b/gi, "Math.$1")
                .replace(/\bpi\b/gi, "Math.PI")
                .replace(/\be\b/gi, "Math.E");
                
            if (/[^0-9\s\+\-\*\/\(\)\.\,MathPIEsqrtincosabwelfr]/.test(safeExpr)) return null;

            try {
                const val = Function('"use strict"; return (' + safeExpr + ')')();
                if (typeof val === "number" && isFinite(val) && !isNaN(val)) {
                    const formatted = (Math.round(val * 1000000) / 1000000).toString();
                    return {
                        isCalculator: true,
                        expression: raw.trim(),
                        result: formatted,
                        name: "= " + formatted,
                        comment: raw.trim() + "  •  " + Translation.tr("Copied to clipboard"),
                        icon: "calculate",
                        execute: () => {
                            Quickshell.clipboardText = formatted;
                            root.showCopiedToast(formatted);
                        }
                    };
                }
            } catch (_) {}
            return null;
        }

        function showCopiedToast(text) {
            root.copiedToastText = text;
            copiedToastTimer.restart();
        }

        Timer {
            id: copiedToastTimer
            interval: 2000
            repeat: false
            onTriggered: root.copiedToastText = ""
        }

        property var searchResults: {
            const query = searchText.trim();
            if (query === "") return [];
            let list = [];
            
            // 1. Math calculation (in "all")
            if (root.searchFilterTab === "all" && (Config.options?.dock?.startMenuEnableCalculator ?? true)) {
                const mathRes = evaluateMath(query);
                if (mathRes) {
                    list.push(mathRes);
                }
            }

            const qLower = query.toLowerCase();

            // 2. Apps
            if (root.searchFilterTab === "all" || root.searchFilterTab === "apps") {
                try {
                    const results = AppSearch.fuzzyQuery(query);
                    if (results && Array.isArray(results)) {
                        list = list.concat(results.filter(item => item !== null && item !== undefined).slice(0, (root.searchFilterTab === "apps" ? 20 : 8)));
                    }
                } catch (err) {
                    console.warn("[Win11StartMenu] Search error:", err);
                }
            }

            // 3. Settings
            if (root.searchFilterTab === "all" || root.searchFilterTab === "settings") {
                const matchingSettings = root.settingsShortcuts.filter(s => s && (s.name.toLowerCase().includes(qLower) || s.comment.toLowerCase().includes(qLower)));
                list = list.concat(matchingSettings.slice(0, 4));
            }

            // 4. Recent Files
            if (root.searchFilterTab === "all" || root.searchFilterTab === "files") {
                const matchingFiles = (RecentFiles.list || []).filter(f => f && (f.name.toLowerCase().includes(qLower) || f.displayDir.toLowerCase().includes(qLower)));
                for (let i = 0; i < matchingFiles.length && list.length < (root.searchFilterTab === "files" ? 20 : 12); i++) {
                    const f = matchingFiles[i];
                    list.push({
                        isFile: true,
                        fileObj: f,
                        name: f.name,
                        comment: f.displayDir,
                        icon: f.icon,
                        execute: () => {
                            f.execute();
                            GlobalStates.startMenuOpen = false;
                        }
                    });
                }
            }

            return list;
        }

        readonly property var allAppsFlatList: {
            const apps = (AppSearch.list || []).slice(0).sort((a, b) => (a?.name || "").localeCompare(b?.name || ""));
            const list = [];
            let currentLetter = "";
            for (let i = 0; i < apps.length; i++) {
                const app = apps[i];
                if (!app || !app.name) continue;
                const firstChar = app.name.charAt(0).toUpperCase();
                const letter = /[A-Z]/.test(firstChar) ? firstChar : "#";
                if (letter !== currentLetter) {
                    currentLetter = letter;
                    list.push({ isHeader: true, letter: letter });
                }
                list.push({ isHeader: false, app: app, letter: letter });
            }
            return list;
        }

        readonly property var alphabetLetterIndices: {
            const map = {};
            const flat = root.allAppsFlatList;
            for (let i = 0; i < flat.length; i++) {
                if (flat[i].isHeader) {
                    map[flat[i].letter] = i;
                }
            }
            return map;
        }

        Timer {
            id: searchDebounceTimer
            interval: 50
            repeat: false
            onTriggered: {
                root.searchText = root.rawSearchInput;
            }
        }

        // KDE Connect integration state
        property bool kdeConnected: false
        property string kdeDeviceName: ""
        property string kdeDeviceId: ""
        property var phoneNotifications: []

        Process {
            id: kdeCheckProc
            command: ["bash", "-c", "DEV=$(kdeconnect-cli -a --name-only 2>/dev/null | grep -v 'dispositivo' | head -n 1); ID=$(kdeconnect-cli -a --id-only 2>/dev/null | grep -v 'dispositivo' | head -n 1); if [ -n \"$DEV\" ]; then echo \"CONNECTED|$DEV|$ID\"; else echo \"DISCONNECTED\"; fi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const raw = text ? text.trim() : "";
                    if (raw.startsWith("CONNECTED|")) {
                        const parts = raw.split("|");
                        root.kdeConnected = true;
                        root.kdeDeviceName = parts[1] ? parts[1].trim() : Translation.tr("Connected Phone");
                        root.kdeDeviceId = parts[2] ? parts[2].trim() : "";
                        if (root.kdeDeviceId.length > 0) {
                            kdeNotifProc.running = true;
                        }
                    } else if (BluetoothStatus.connected && BluetoothStatus.firstActiveDevice) {
                        root.kdeConnected = true;
                        root.kdeDeviceName = BluetoothStatus.firstActiveDevice.name;
                    } else {
                        root.kdeConnected = false;
                        root.kdeDeviceName = "";
                        root.kdeDeviceId = "";
                        root.phoneNotifications = [];
                    }
                }
            }
        }

        Process {
            id: kdeNotifProc
            command: ["bash", "-c", "kdeconnect-cli -d \"" + root.kdeDeviceId + "\" --list-notifications 2>/dev/null | grep -v 'Nenhum' | head -n 5"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text ? text.trim().split("\n").filter(l => l.trim().length > 0) : [];
                    let list = [];
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i];
                        const parts = line.split(":");
                        if (parts.length >= 2) {
                            list.push({
                                app: parts[0].trim(),
                                title: parts[1] ? parts[1].trim() : "",
                                body: parts.slice(2).join(":").trim()
                            });
                        } else {
                            list.push({
                                app: "Phone",
                                title: line.trim(),
                                body: ""
                            });
                        }
                    }
                    root.phoneNotifications = list;
                }
            }
        }

        // Pinned applications (user's configured pinned apps)
        readonly property var pinnedList: {
            const pinned = Config.options?.dock?.pinnedApps ?? [];
            let list = pinned.map(id => DesktopEntries.heuristicLookup(id)).filter(e => e !== null && e !== undefined);
            if (list.length === 0) {
                list = (AppSearch.list || []).slice(0, 6);
            }
            return list;
        }

        // Combined Recommended List: Apps + Real Recent Files
        readonly property var combinedRecommendedList: {
            let list = [];
            const running = (TaskbarApps.apps || []).filter(a => a && a.appId !== "SEPARATOR" && a.toplevels && a.toplevels.length > 0);
            
            // 1. Running & Active apps
            if (root.recommendedTab === "all" || root.recommendedTab === "apps") {
                for (let i = 0; i < running.length && list.length < 3; i++) {
                    const app = running[i];
                    const desk = DesktopEntries.heuristicLookup(app.appId);
                    if (desk) {
                        const topTitle = app.toplevels[0]?.title ?? desk.name;
                        list.push({
                            isFile: false,
                            id: app.appId,
                            name: desk.name,
                            subtitle: (topTitle !== desk.name && topTitle && topTitle.length > 0) ? topTitle : Translation.tr("Active window"),
                            icon: desk.icon,
                            execute: () => {
                                try {
                                    if (app.toplevels && app.toplevels.length > 0 && app.toplevels[0]) app.toplevels[0].activate();
                                    else if (desk.runInTerminal && desk.command) {
                                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(desk.command.join(' '))}'`]);
                                    } else if (typeof desk.execute === "function") {
                                        desk.execute();
                                    }
                                } catch (e) {
                                    console.warn("[Win11StartMenu] Execution error:", e);
                                }
                                GlobalStates.startMenuOpen = false;
                            }
                        });
                    }
                }
            }

            // 2. Real Recent Files from RecentFiles service
            if ((Config.options?.dock?.startMenuShowRecentFiles ?? true) && (root.recommendedTab === "all" || root.recommendedTab === "files")) {
                const maxFiles = (root.recommendedTab === "files") ? 6 : (6 - list.length);
                const recFiles = (RecentFiles.list || []).slice(0, maxFiles);
                for (let i = 0; i < recFiles.length; i++) {
                    const f = recFiles[i];
                    list.push({
                        isFile: true,
                        fileObj: f,
                        name: f.name,
                        subtitle: f.relativeTime ? `${f.relativeTime}  •  ${f.displayDir}` : f.displayDir,
                        icon: f.icon,
                        path: f.path,
                        execute: () => {
                            f.execute();
                            GlobalStates.startMenuOpen = false;
                        }
                    });
                }
            }

            // Fallback: Pinned shortcuts if still under 4 items
            if (list.length < 4 && root.recommendedTab !== "files") {
                const pinned = Config.options?.dock?.pinnedApps ?? [];
                for (let i = 0; i < pinned.length && list.length < 6; i++) {
                    const id = pinned[i];
                    if (!list.some(item => item.id === id)) {
                        const desk = DesktopEntries.heuristicLookup(id);
                        if (desk) {
                            list.push({
                                isFile: false,
                                id: id,
                                name: desk.name,
                                subtitle: Translation.tr("Quick access"),
                                icon: desk.icon,
                                execute: () => {
                                    try {
                                        if (desk.runInTerminal && desk.command) {
                                            Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(desk.command.join(' '))}'`]);
                                        } else if (typeof desk.execute === "function") {
                                            desk.execute();
                                        }
                                    } catch (e) {
                                        console.warn("[Win11StartMenu] Execution error:", e);
                                    }
                                    GlobalStates.startMenuOpen = false;
                                }
                            });
                        }
                    }
                }
            }

            return list;
        }

        Connections {
            target: GlobalStates
            function onStartMenuOpenChanged() {
                if (GlobalStates.startMenuOpen) {
                    searchDebounceTimer.stop();
                    root.rawSearchInput = "";
                    root.searchText = "";
                    root.searchSelectedIndex = 0;
                    root.powerFlyoutOpen = false;
                    root.appContextMenuOpen = false;
                    root.contextMenuTargetApp = null;
                    root.contextMenuTargetFile = null;
                    root.folderModalOpen = false;
                    root.activeFolder = null;
                    root.newFolderDialogOpen = false;
                    root.folderPickerOpen = false;
                    root.folderPickerTargetApp = null;
                    root.addAppToFolderDialogOpen = false;
                    root.alphabetJumpModalOpen = false;
                    RecentFiles.reload();
                    if (searchInput) {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }
                    root.showAllApps = false;
                    kdeCheckProc.running = true;
                    GlobalFocusGrab.addDismissable(root);
                } else {
                    root.powerFlyoutOpen = false;
                    root.appContextMenuOpen = false;
                    root.contextMenuTargetApp = null;
                    root.contextMenuTargetFile = null;
                    root.folderModalOpen = false;
                    root.activeFolder = null;
                    root.newFolderDialogOpen = false;
                    root.folderPickerOpen = false;
                    root.folderPickerTargetApp = null;
                    root.addAppToFolderDialogOpen = false;
                    root.alphabetJumpModalOpen = false;
                    GlobalFocusGrab.dismiss();
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.startMenuOpen = false;
            }
        }

        // Fullscreen transparent background dismiss area
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: false
            z: 0
            onClicked: {
                GlobalStates.startMenuOpen = false;
            }
        }

        // Main Dual Panel Layout (Windows 11 Start Menu + Companion Panel)
        Item {
            id: mainContainer
            z: 1
            width: mainRow.implicitWidth
            height: mainRow.implicitHeight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut + 75
            anchors.horizontalCenter: root.startMenuCentered ? parent.horizontalCenter : undefined
            anchors.left: root.startMenuCentered ? undefined : parent.left
            anchors.leftMargin: root.startMenuCentered ? 0 : (Appearance.sizes.hyprlandGapsOut + 20)
            transformOrigin: Item.Bottom

            scale: GlobalStates.startMenuOpen ? 1.0 : 0.96
            opacity: GlobalStates.startMenuOpen ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                id: mainRow
                anchors.fill: parent
                spacing: 12

                // ==========================================
                // LEFT PANEL (Windows 11 Start Menu)
                // ==========================================
                Rectangle {
                    id: startMenuCard
                    implicitWidth: 600
                    implicitHeight: 640
                    radius: Appearance.rounding.large + 4
                    color: root.acrylicBg ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25) : Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // ---------------- Search Bar ----------------
                        Item {
                            Layout.fillWidth: true
                            Layout.topMargin: 20
                            Layout.leftMargin: 24
                            Layout.rightMargin: 24
                            Layout.bottomMargin: 14
                            implicitHeight: 40

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    MaterialSymbol {
                                        text: "search"
                                        iconSize: 18
                                        color: searchInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1Inactive
                                    }

                                    TextInput {
                                        id: searchInput
                                        Layout.fillWidth: true
                                        focus: GlobalStates.startMenuOpen
                                        onTextChanged: {
                                            root.searchSelectedIndex = 0;
                                            root.rawSearchInput = text;
                                            if (text.trim() === "") {
                                                searchDebounceTimer.stop();
                                                root.searchText = "";
                                            } else {
                                                searchDebounceTimer.restart();
                                            }
                                        }
                                        color: Appearance.colors.colOnLayer0
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.family: Appearance.font.family.main
                                        selectByMouse: true
                                        verticalAlignment: TextInput.AlignVCenter

                                        Text {
                                            text: Translation.tr("Search for apps, settings, and documents...")
                                            color: Appearance.colors.colOnLayer1Inactive
                                            font: parent.font
                                            visible: !parent.text && !parent.inputMethodComposing
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Escape) {
                                                if (root.addAppToFolderDialogOpen) {
                                                    root.addAppToFolderDialogOpen = false;
                                                    event.accepted = true;
                                                } else if (root.folderPickerOpen) {
                                                    root.folderPickerOpen = false;
                                                    event.accepted = true;
                                                } else if (root.newFolderDialogOpen) {
                                                    root.newFolderDialogOpen = false;
                                                    event.accepted = true;
                                                } else if (root.appContextMenuOpen) {
                                                    root.appContextMenuOpen = false;
                                                    root.contextMenuTargetApp = null;
                                                    event.accepted = true;
                                                } else if (root.folderModalOpen) {
                                                    root.folderModalOpen = false;
                                                    event.accepted = true;
                                                } else if (root.powerFlyoutOpen) {
                                                    root.powerFlyoutOpen = false;
                                                    event.accepted = true;
                                                } else if (searchInput.text !== "") {
                                                    searchDebounceTimer.stop();
                                                    root.rawSearchInput = "";
                                                    root.searchText = "";
                                                    searchInput.text = "";
                                                    root.searchSelectedIndex = 0;
                                                    event.accepted = true;
                                                } else {
                                                    GlobalStates.startMenuOpen = false;
                                                    event.accepted = true;
                                                }
                                            } else if (event.key === Qt.Key_Down) {
                                                if (root.searchResults.length > 0) {
                                                    root.searchSelectedIndex = Math.min(root.searchSelectedIndex + 1, root.searchResults.length - 1);
                                                    event.accepted = true;
                                                }
                                            } else if (event.key === Qt.Key_Up) {
                                                if (root.searchResults.length > 0) {
                                                    root.searchSelectedIndex = Math.max(root.searchSelectedIndex - 1, 0);
                                                    event.accepted = true;
                                                }
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (searchDebounceTimer.running) {
                                                    searchDebounceTimer.stop();
                                                    root.searchText = root.rawSearchInput;
                                                }
                                                const idx = (root.searchSelectedIndex >= 0 && root.searchSelectedIndex < root.searchResults.length) ? root.searchSelectedIndex : 0;
                                                if (root.searchResults && root.searchResults.length > idx) {
                                                    const topApp = root.searchResults[idx];
                                                    if (topApp) {
                                                        try {
                                                            if (topApp.runInTerminal && topApp.command) {
                                                                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(topApp.command.join(' '))}'`]);
                                                            } else if (typeof topApp.execute === "function") {
                                                                topApp.execute();
                                                            }
                                                        } catch (e) {
                                                            console.warn("[Win11StartMenu] App launch error:", e);
                                                        }
                                                        GlobalStates.startMenuOpen = false;
                                                    }
                                                }
                                                event.accepted = true;
                                            }
                                        }
                                    }

                                    RippleButton {
                                        visible: searchInput.text.length > 0
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            searchDebounceTimer.stop();
                                            root.rawSearchInput = "";
                                            root.searchText = "";
                                            root.searchSelectedIndex = 0;
                                            searchInput.text = "";
                                            searchInput.forceActiveFocus();
                                        }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: 14
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }

                        // ---------------- Dedicated All Apps View (Virtualized ListView) ----------------
                        ColumnLayout {
                            id: allAppsViewContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 20
                            Layout.rightMargin: 20
                            visible: root.searchText.trim() === "" && root.showAllApps
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                Layout.rightMargin: 6

                                StyledText {
                                    text: Translation.tr("All Applications")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }

                                Item { Layout.fillWidth: true }

                                RippleButton {
                                    implicitWidth: 72
                                    implicitHeight: 26
                                    buttonRadius: 6
                                    colBackground: Appearance.colors.colLayer1
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.showAllApps = false
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        MaterialSymbol { text: "arrow_back"; iconSize: 14; color: Appearance.colors.colPrimary }
                                        StyledText { text: Translation.tr("Back"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                    }
                                }
                            }

                            ListView {
                                id: allAppsListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 2
                                model: (root.showAllApps && root.searchText.trim() === "") ? root.allAppsFlatList : []

                                delegate: Item {
                                    id: allAppsDelegateItem
                                    required property var modelData
                                    required property int index
                                    width: allAppsListView.width
                                    height: modelData.isHeader ? 36 : 40

                                    // Letter Header Item
                                    RippleButton {
                                        visible: modelData.isHeader === true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: Appearance.colors.colLayer1
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: root.alphabetJumpModalOpen = true
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData.letter ?? ""
                                            font.weight: Font.Bold
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colPrimary
                                        }
                                        StyledToolTip { text: Translation.tr("Jump to letter") }
                                    }

                                    // Application Item
                                    RippleButton {
                                        id: allAppsBtn
                                        visible: modelData.isHeader !== true
                                        anchors.fill: parent
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        altAction: (event) => {
                                            root.contextMenuTargetApp = modelData.app;
                                            root.contextMenuTargetFile = null;
                                            const p = mapToItem(startMenuCard, event.x, event.y);
                                            root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 180));
                                            root.appContextMenuOpen = true;
                                            root.powerFlyoutOpen = false;
                                        }
                                        onClicked: {
                                            const app = modelData.app;
                                            if (app) {
                                                try {
                                                    if (app.runInTerminal && app.command) {
                                                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(' '))}'`]);
                                                    } else if (typeof app.execute === "function") {
                                                        app.execute();
                                                    }
                                                } catch (e) {
                                                    console.warn("[Win11StartMenu] Launch error:", e);
                                                }
                                                GlobalStates.startMenuOpen = false;
                                            }
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            IconImage {
                                                source: Quickshell.iconPath(modelData.app?.icon ?? "", "application-x-executable")
                                                implicitSize: 24
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData.app?.name ?? ""
                                                font.pixelSize: Appearance.font.pixelSize.normal
                                                color: Appearance.colors.colOnLayer0
                                                elide: Text.ElideRight
                                            }

                                            RippleButton {
                                                visible: allAppsBtn.hovered || root.isAppPinned(modelData.app)
                                                implicitWidth: 28
                                                implicitHeight: 28
                                                buttonRadius: Appearance.rounding.full
                                                colBackground: "transparent"
                                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                                onClicked: {
                                                    root.togglePinApp(modelData.app);
                                                }
                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: root.isAppPinned(modelData.app) ? "keep" : "keep_public"
                                                    iconSize: 16
                                                    color: root.isAppPinned(modelData.app) ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---------------- Main Body Flickable (Pinned, Folders, Recommended, Search) ----------------
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 20
                            Layout.rightMargin: 20
                            visible: !(root.searchText.trim() === "" && root.showAllApps)
                            contentHeight: contentColumn.implicitHeight + 16
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: contentColumn
                                width: parent.width
                                spacing: 14

                                // State 1: SEARCH RESULTS
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: root.searchText.trim() !== ""
                                    spacing: 6

                                    // Search Filter Tabs [Todos] [Apps] [Arquivos] [Configurações]
                                    RowLayout {
                                        Layout.leftMargin: 6
                                        Layout.bottomMargin: 4
                                        spacing: 4

                                        RippleButton {
                                            implicitHeight: 24
                                            implicitWidth: 48
                                            buttonRadius: 5
                                            colBackground: root.searchFilterTab === "all" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: root.searchFilterTab = "all"
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: Translation.tr("All")
                                                font.pixelSize: 10
                                                font.weight: root.searchFilterTab === "all" ? Font.Bold : Font.Normal
                                                color: root.searchFilterTab === "all" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                            }
                                        }

                                        RippleButton {
                                            implicitHeight: 24
                                            implicitWidth: 48
                                            buttonRadius: 5
                                            colBackground: root.searchFilterTab === "apps" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: root.searchFilterTab = "apps"
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: Translation.tr("Apps")
                                                font.pixelSize: 10
                                                font.weight: root.searchFilterTab === "apps" ? Font.Bold : Font.Normal
                                                color: root.searchFilterTab === "apps" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                            }
                                        }

                                        RippleButton {
                                            implicitHeight: 24
                                            implicitWidth: 54
                                            buttonRadius: 5
                                            colBackground: root.searchFilterTab === "files" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: root.searchFilterTab = "files"
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: Translation.tr("Files")
                                                font.pixelSize: 10
                                                font.weight: root.searchFilterTab === "files" ? Font.Bold : Font.Normal
                                                color: root.searchFilterTab === "files" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                            }
                                        }

                                        RippleButton {
                                            implicitHeight: 24
                                            implicitWidth: 86
                                            buttonRadius: 5
                                            colBackground: root.searchFilterTab === "settings" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: root.searchFilterTab = "settings"
                                            StyledText {
                                                anchors.centerIn: parent
                                                text: Translation.tr("Settings")
                                                font.pixelSize: 10
                                                font.weight: root.searchFilterTab === "settings" ? Font.Bold : Font.Normal
                                                color: root.searchFilterTab === "settings" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                            }
                                        }
                                    }

                                    Repeater {
                                        model: root.searchResults
                                        delegate: RippleButton {
                                            id: searchResultBtn
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            implicitHeight: 48
                                            buttonRadius: 8
                                            colBackground: (index === root.searchSelectedIndex) ? Appearance.colors.colLayer1Hover : (modelData?.isCalculator ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85) : "transparent")
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onHoveredChanged: {
                                                if (hovered) root.searchSelectedIndex = index;
                                            }
                                            altAction: (event) => {
                                                if (!modelData?.isCalculator && !modelData?.isSetting) {
                                                    root.contextMenuTargetApp = modelData;
                                                    root.contextMenuTargetFile = null;
                                                    const p = mapToItem(startMenuCard, event.x, event.y);
                                                    root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 180));
                                                    root.appContextMenuOpen = true;
                                                    root.powerFlyoutOpen = false;
                                                }
                                            }
                                            onClicked: {
                                                if (modelData) {
                                                    try {
                                                        if (modelData.isCalculator) {
                                                            modelData.execute();
                                                        } else if (modelData.runInTerminal && modelData.command) {
                                                            Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(modelData.command.join(' '))}'`]);
                                                            GlobalStates.startMenuOpen = false;
                                                        } else if (typeof modelData.execute === "function") {
                                                            modelData.execute();
                                                            GlobalStates.startMenuOpen = false;
                                                        }
                                                    } catch (e) {
                                                        console.warn("[Win11StartMenu] Launch error:", e);
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 2
                                                width: 3
                                                height: 20
                                                radius: 1.5
                                                color: Appearance.colors.colPrimary
                                                visible: index === root.searchSelectedIndex
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 8
                                                spacing: 12

                                                Item {
                                                    width: 30
                                                    height: 30
                                                    Layout.alignment: Qt.AlignVCenter

                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        visible: modelData?.isCalculator === true
                                                        text: "calculate"
                                                        iconSize: 26
                                                        color: Appearance.colors.colPrimary
                                                    }

                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        visible: modelData?.isSetting === true
                                                        text: modelData?.icon ?? "settings"
                                                        iconSize: 22
                                                        color: Appearance.colors.colPrimary
                                                    }

                                                    IconImage {
                                                        anchors.fill: parent
                                                        visible: !modelData?.isCalculator && !modelData?.isSetting
                                                        source: Quickshell.iconPath(modelData?.icon ?? "", "application-x-executable")
                                                        implicitSize: 30
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: modelData?.name ?? ""
                                                        font.weight: modelData?.isCalculator ? Font.Bold : Font.Medium
                                                        font.pixelSize: modelData?.isCalculator ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.normal
                                                        color: modelData?.isCalculator ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                                                        elide: Text.ElideRight
                                                    }
                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: (modelData?.comment || modelData?.id) ?? ""
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        color: Appearance.colors.colOnLayer1
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                RippleButton {
                                                    visible: !modelData?.isCalculator && (searchResultBtn.hovered || root.isAppPinned(modelData))
                                                    implicitWidth: 30
                                                    implicitHeight: 30
                                                    buttonRadius: Appearance.rounding.full
                                                    colBackground: "transparent"
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    onClicked: {
                                                        root.togglePinApp(modelData);
                                                    }
                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        text: root.isAppPinned(modelData) ? "keep" : "keep_public"
                                                        iconSize: 18
                                                        color: root.isAppPinned(modelData) ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                                    }
                                                    StyledToolTip {
                                                        text: root.isAppPinned(modelData) ? Translation.tr("Unpin from Start") : Translation.tr("Pin to Start")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        visible: root.searchResults.length === 0
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: 40
                                        text: Translation.tr("No results found")
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnLayer1
                                    }
                                }

                                // State 3: FOLDER VIEW (When a folder is opened in Windows 11 style)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: root.searchText.trim() === "" && !root.showAllApps && root.folderModalOpen && root.activeFolder !== null
                                    spacing: 14

                                    // Folder Header Bar (Back button, Editable Name, Add App, Delete Folder)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 4
                                        Layout.rightMargin: 4
                                        spacing: 8

                                        RippleButton {
                                            implicitWidth: 34
                                            implicitHeight: 34
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                root.folderModalOpen = false;
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "arrow_back"
                                                iconSize: 18
                                                color: Appearance.colors.colOnLayer0
                                            }
                                            StyledToolTip { text: Translation.tr("Back") }
                                        }

                                        // Editable Folder Name Input
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            radius: 6
                                            color: folderNameInput.activeFocus ? Appearance.colors.colLayer1 : "transparent"
                                            border.width: folderNameInput.activeFocus ? 1 : 0
                                            border.color: Appearance.colors.colPrimary

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 8

                                                MaterialSymbol {
                                                    text: "folder"
                                                    iconSize: 20
                                                    color: Appearance.colors.colPrimary
                                                }

                                                TextInput {
                                                    id: folderNameInput
                                                    Layout.fillWidth: true
                                                    text: root.activeFolder?.name ?? ""
                                                    font.weight: Font.DemiBold
                                                    font.pixelSize: Appearance.font.pixelSize.large
                                                    color: Appearance.colors.colOnLayer0
                                                    font.family: Appearance.font.family.main
                                                    verticalAlignment: TextInput.AlignVCenter
                                                    selectByMouse: true
                                                    onEditingFinished: {
                                                        if (root.activeFolder && text.trim() !== "") {
                                                            StartMenuFolders.renameFolder(root.activeFolder.id, text.trim());
                                                            root.activeFolder = StartMenuFolders.getFolder(root.activeFolder.id);
                                                        }
                                                    }
                                                }

                                                MaterialSymbol {
                                                    text: "edit"
                                                    iconSize: 14
                                                    color: Appearance.colors.colOnLayer1
                                                    visible: !folderNameInput.activeFocus
                                                }
                                            }
                                        }

                                        // Add App to Folder Button
                                        RippleButton {
                                            implicitWidth: 34
                                            implicitHeight: 34
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                root.addAppSearchQuery = "";
                                                root.addAppToFolderDialogOpen = true;
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "add"
                                                iconSize: 18
                                                color: Appearance.colors.colPrimary
                                            }
                                            StyledToolTip { text: Translation.tr("Add App to Folder") }
                                        }

                                        // Delete Folder Button
                                        RippleButton {
                                            implicitWidth: 34
                                            implicitHeight: 34
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colErrorContainer
                                            onClicked: {
                                                if (root.activeFolder) {
                                                    StartMenuFolders.deleteFolder(root.activeFolder.id);
                                                    root.activeFolder = null;
                                                    root.folderModalOpen = false;
                                                }
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "delete"
                                                iconSize: 18
                                                color: Appearance.colors.colError
                                            }
                                            StyledToolTip { text: Translation.tr("Delete Folder") }
                                        }
                                    }

                                    // Apps inside folder Flow
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: (StartMenuFolders.getFolderResolvedApps(root.activeFolder) || []).length > 0

                                        Repeater {
                                            model: StartMenuFolders.getFolderResolvedApps(root.activeFolder)
                                            delegate: Item {
                                                id: folderAppItem
                                                required property var modelData
                                                width: 86
                                                implicitHeight: 84

                                                // 1. Background Hover highlight
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: (folderAppMouseArea.containsMouse || removeBtn.hovered) ? Appearance.colors.colLayer1Hover : "transparent"
                                                }

                                                // 2. MouseArea for launching / context menu
                                                MouseArea {
                                                    id: folderAppMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    z: 1

                                                    onClicked: (mouse) => {
                                                        if (mouse.button === Qt.RightButton) {
                                                            root.contextMenuTargetApp = modelData;
                                                            const p = mapToItem(startMenuCard, mouse.x, mouse.y);
                                                            root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 240));
                                                            root.appContextMenuOpen = true;
                                                        } else if (mouse.button === Qt.LeftButton) {
                                                            if (modelData) {
                                                                try {
                                                                    if (modelData.runInTerminal && modelData.command) {
                                                                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(modelData.command.join(' '))}'`]);
                                                                    } else if (typeof modelData.execute === "function") {
                                                                        modelData.execute();
                                                                    }
                                                                } catch (e) {
                                                                    console.warn("[Win11StartMenu] Launch error:", e);
                                                                }
                                                                GlobalStates.startMenuOpen = false;
                                                            }
                                                        }
                                                    }
                                                }

                                                // 3. App icon + label layout
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    z: 2

                                                    Item {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        width: 38
                                                        height: 38

                                                        IconImage {
                                                            anchors.fill: parent
                                                            source: Quickshell.iconPath(modelData?.icon ?? "", "application-x-executable")
                                                            implicitSize: 38
                                                        }
                                                    }

                                                    StyledText {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        Layout.preferredWidth: 80
                                                        text: modelData?.name ?? ""
                                                        font.pixelSize: 11
                                                        color: Appearance.colors.colOnLayer0
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                // 4. Close 'X' Button on TOP (z: 10) so clicks are isolated and NEVER trigger the MouseArea underneath
                                                RippleButton {
                                                    id: removeBtn
                                                    z: 10
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.margins: 2
                                                    visible: folderAppMouseArea.containsMouse || removeBtn.hovered
                                                    implicitWidth: 22
                                                    implicitHeight: 22
                                                    buttonRadius: Appearance.rounding.full
                                                    colBackground: Appearance.colors.colLayer1
                                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                                    onClicked: {
                                                        if (root.activeFolder && modelData) {
                                                            const targetId = modelData.id || modelData.appId || modelData.name;
                                                            StartMenuFolders.removeAppFromFolder(root.activeFolder.id, targetId);
                                                            root.activeFolder = StartMenuFolders.getFolder(root.activeFolder.id);
                                                        }
                                                    }
                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        text: "close"
                                                        iconSize: 12
                                                        color: Appearance.colors.colError
                                                    }
                                                    StyledToolTip { text: Translation.tr("Remove from Folder") }
                                                }
                                            }
                                        }
                                    }

                                    // Empty Folder placeholder
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 24
                                        visible: (StartMenuFolders.getFolderResolvedApps(root.activeFolder) || []).length === 0
                                        spacing: 12

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: Translation.tr("Folder is empty. Click '+' to add applications.")
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colOnLayer1
                                        }

                                        RippleButton {
                                            Layout.alignment: Qt.AlignHCenter
                                            implicitWidth: 160
                                            implicitHeight: 34
                                            buttonRadius: 6
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                root.addAppSearchQuery = "";
                                                root.addAppToFolderDialogOpen = true;
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                MaterialSymbol { text: "add"; iconSize: 18; color: Appearance.colors.colPrimary }
                                                StyledText { text: Translation.tr("Add Application"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                            }
                                        }
                                    }
                                }

                                // State 4: DEFAULT (PINNED + RECOMMENDED + CATEGORIES)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    visible: root.searchText.trim() === "" && !root.showAllApps && !root.folderModalOpen
                                    spacing: 14

                                    // --- Pinned Header ---
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 6
                                        Layout.rightMargin: 6
                                        spacing: 6

                                        StyledText {
                                            text: Translation.tr("Pinned")
                                            font.weight: Font.DemiBold
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                        }

                                        Item { Layout.fillWidth: true }

                                        // + Nova Pasta Button
                                        RippleButton {
                                            implicitWidth: 104
                                            implicitHeight: 26
                                            buttonRadius: 6
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                root.newFolderNameInput = "";
                                                root.newFolderDialogOpen = true;
                                            }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                MaterialSymbol {
                                                    text: "create_new_folder"
                                                    iconSize: 14
                                                    color: Appearance.colors.colPrimary
                                                }
                                                StyledText {
                                                    text: Translation.tr("New folder")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                            }
                                        }

                                        RippleButton {
                                            implicitWidth: 84
                                            implicitHeight: 26
                                            buttonRadius: 6
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: root.showAllApps = true

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                StyledText {
                                                    text: Translation.tr("All apps")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                                MaterialSymbol {
                                                    text: "chevron_right"
                                                    iconSize: 14
                                                    color: Appearance.colors.colOnLayer1
                                                }
                                            }
                                        }
                                    }

                                    // --- Pinned Flow Layout (Folders + Apps with Drag-and-Drop) ---
                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        // App Folders
                                        Repeater {
                                            model: StartMenuFolders.list
                                            delegate: Item {
                                                id: folderCardBtn
                                                required property var modelData
                                                width: 86
                                                implicitHeight: 84

                                                readonly property bool isHoveredByDrag: {
                                                    if (!root.isDraggingApp) return false;
                                                    const local = mapFromItem(startMenuCard, root.dragCurrentPos.x, root.dragCurrentPos.y);
                                                    return local.x >= 0 && local.x <= width && local.y >= 0 && local.y <= height;
                                                }

                                                onIsHoveredByDragChanged: {
                                                    if (isHoveredByDrag) {
                                                        root.dragDropTargetFolder = modelData;
                                                        root.dragDropTargetApp = null;
                                                    } else if (root.dragDropTargetFolder === modelData) {
                                                        root.dragDropTargetFolder = null;
                                                    }
                                                }

                                                Rectangle {
                                                    id: folderBg
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: folderMouseArea.containsMouse ? Appearance.colors.colLayer1Hover : (folderCardBtn.isHoveredByDrag ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7) : "transparent")
                                                    border.width: folderCardBtn.isHoveredByDrag ? 2 : 0
                                                    border.color: Appearance.colors.colPrimary
                                                    scale: folderCardBtn.isHoveredByDrag ? 1.08 : (folderMouseArea.pressed ? 0.95 : 1.0)
                                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                    Behavior on color { ColorAnimation { duration: 100 } }

                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        // 2x2 Miniature Preview Container matching Windows 11 Start Menu
                                                        Rectangle {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            width: 48
                                                            height: 48
                                                            radius: 12
                                                            color: ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colLayer0, 0.4)
                                                            border.width: 1
                                                            border.color: Appearance.colors.colLayer0Border

                                                            // 2x2 Icons Grid
                                                            GridLayout {
                                                                anchors.centerIn: parent
                                                                columns: 2
                                                                rows: 2
                                                                rowSpacing: 3
                                                                columnSpacing: 3
                                                                visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 0

                                                                // Slot 1 (Top-Left)
                                                                Item {
                                                                    width: 18; height: 18
                                                                    visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 0
                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        source: Quickshell.iconPath(StartMenuFolders.getFolderResolvedApps(modelData)[0]?.icon ?? "", "application-x-executable")
                                                                        implicitSize: 18
                                                                    }
                                                                }

                                                                // Slot 2 (Top-Right)
                                                                Item {
                                                                    width: 18; height: 18
                                                                    visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 1
                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        source: Quickshell.iconPath(StartMenuFolders.getFolderResolvedApps(modelData)[1]?.icon ?? "", "application-x-executable")
                                                                        implicitSize: 18
                                                                    }
                                                                }

                                                                // Slot 3 (Bottom-Left)
                                                                Item {
                                                                    width: 18; height: 18
                                                                    visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 2
                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        source: Quickshell.iconPath(StartMenuFolders.getFolderResolvedApps(modelData)[2]?.icon ?? "", "application-x-executable")
                                                                        implicitSize: 18
                                                                    }
                                                                }

                                                                // Slot 4 (Bottom-Right)
                                                                Item {
                                                                    width: 18; height: 18
                                                                    visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 3

                                                                    // 1 single icon if exactly 4 apps
                                                                    IconImage {
                                                                        anchors.fill: parent
                                                                        visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length === 4
                                                                        source: Quickshell.iconPath(StartMenuFolders.getFolderResolvedApps(modelData)[3]?.icon ?? "", "application-x-executable")
                                                                        implicitSize: 18
                                                                    }

                                                                    // 2x2 micro-grid cluster if > 4 apps (Windows 11 style)
                                                                    GridLayout {
                                                                        anchors.fill: parent
                                                                        columns: 2
                                                                        rows: 2
                                                                        rowSpacing: 1
                                                                        columnSpacing: 1
                                                                        visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length > 4

                                                                        Repeater {
                                                                            model: (StartMenuFolders.getFolderResolvedApps(modelData) || []).slice(3, 7)
                                                                            delegate: IconImage {
                                                                                required property var modelData
                                                                                source: Quickshell.iconPath(modelData?.icon ?? "", "application-x-executable")
                                                                                implicitSize: 8
                                                                                width: 8; height: 8
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            // Empty folder fallback icon
                                                            MaterialSymbol {
                                                                anchors.centerIn: parent
                                                                visible: (StartMenuFolders.getFolderResolvedApps(modelData) || []).length === 0
                                                                text: "folder"
                                                                iconSize: 24
                                                                color: Appearance.colors.colPrimary
                                                            }
                                                        }

                                                        StyledText {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            Layout.preferredWidth: 80
                                                            text: modelData?.name ?? Translation.tr("Folder")
                                                            font.pixelSize: 11
                                                            color: Appearance.colors.colOnLayer0
                                                            horizontalAlignment: Text.AlignHCenter
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: folderMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                    onClicked: (mouse) => {
                                                        if (mouse.button === Qt.RightButton) {
                                                            root.activeFolder = modelData;
                                                            root.contextMenuTargetApp = null;
                                                            const p = mapToItem(startMenuCard, mouse.x, mouse.y);
                                                            root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 180));
                                                            root.appContextMenuOpen = true;
                                                            root.powerFlyoutOpen = false;
                                                        } else if (mouse.button === Qt.LeftButton) {
                                                            root.activeFolder = modelData;
                                                            root.folderModalOpen = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Individual Pinned Apps (With Drag & Drop support)
                                        Repeater {
                                            model: root.pinnedList

                                            delegate: Item {
                                                id: pinnedAppItem
                                                required property var modelData
                                                width: 86
                                                implicitHeight: 84

                                                readonly property bool isHoveredByDrag: {
                                                    if (!root.isDraggingApp || root.draggingApp === modelData) return false;
                                                    const local = mapFromItem(startMenuCard, root.dragCurrentPos.x, root.dragCurrentPos.y);
                                                    return local.x >= 0 && local.x <= width && local.y >= 0 && local.y <= height;
                                                }

                                                onIsHoveredByDragChanged: {
                                                    if (isHoveredByDrag) {
                                                        root.dragDropTargetApp = modelData;
                                                        root.dragDropTargetFolder = null;
                                                    } else if (root.dragDropTargetApp === modelData) {
                                                        root.dragDropTargetApp = null;
                                                    }
                                                }

                                                Rectangle {
                                                    id: appCardBg
                                                    anchors.fill: parent
                                                    radius: 8
                                                    color: appMouseArea.containsMouse ? Appearance.colors.colLayer1Hover : (pinnedAppItem.isHoveredByDrag ? ColorUtils.transparentize(Appearance.colors.colSecondary, 0.7) : "transparent")
                                                    border.width: pinnedAppItem.isHoveredByDrag ? 2 : 0
                                                    border.color: Appearance.colors.colSecondary
                                                    scale: pinnedAppItem.isHoveredByDrag ? 1.08 : (appMouseArea.pressed ? 0.95 : 1.0)
                                                    opacity: (root.isDraggingApp && root.draggingApp === modelData) ? 0.3 : 1.0
                                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                                    Behavior on color { ColorAnimation { duration: 100 } }

                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Item {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            width: 38
                                                            height: 38

                                                            IconImage {
                                                                anchors.fill: parent
                                                                source: Quickshell.iconPath(modelData?.icon ?? "", "application-x-executable")
                                                                implicitSize: 38
                                                            }
                                                        }

                                                        StyledText {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            Layout.preferredWidth: 80
                                                            text: modelData?.name ?? ""
                                                            font.pixelSize: 11
                                                            color: Appearance.colors.colOnLayer0
                                                            horizontalAlignment: Text.AlignHCenter
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: appMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                                    property point pressPos: Qt.point(0, 0)
                                                    property bool dragTriggered: false

                                                    onPressed: (mouse) => {
                                                        if (mouse.button === Qt.RightButton) {
                                                            root.contextMenuTargetApp = modelData;
                                                            root.activeFolder = null;
                                                            const p = mapToItem(startMenuCard, mouse.x, mouse.y);
                                                            root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 240));
                                                            root.appContextMenuOpen = true;
                                                            root.powerFlyoutOpen = false;
                                                        } else if (mouse.button === Qt.LeftButton) {
                                                            pressPos = Qt.point(mouse.x, mouse.y);
                                                            dragTriggered = false;
                                                        }
                                                    }

                                                    onPositionChanged: (mouse) => {
                                                        if (mouse.buttons & Qt.LeftButton) {
                                                            const dx = mouse.x - pressPos.x;
                                                            const dy = mouse.y - pressPos.y;
                                                            if (!dragTriggered && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) {
                                                                dragTriggered = true;
                                                                root.isDraggingApp = true;
                                                                root.draggingApp = modelData;
                                                            }
                                                            if (root.isDraggingApp) {
                                                                root.dragCurrentPos = mapToItem(startMenuCard, mouse.x, mouse.y);
                                                            }
                                                        }
                                                    }

                                                    onReleased: (mouse) => {
                                                        if (mouse.button === Qt.LeftButton) {
                                                            if (root.isDraggingApp) {
                                                                if (root.dragDropTargetFolder) {
                                                                    StartMenuFolders.addAppToFolder(root.dragDropTargetFolder.id, root.draggingApp.id);
                                                                    if (root.isAppPinned(root.draggingApp)) {
                                                                        root.togglePinApp(root.draggingApp);
                                                                    }
                                                                } else if (root.dragDropTargetApp && root.dragDropTargetApp !== root.draggingApp) {
                                                                    StartMenuFolders.createFolderFromApps(root.dragDropTargetApp.id, root.draggingApp.id, "Nova Pasta");
                                                                    if (root.isAppPinned(root.dragDropTargetApp)) {
                                                                        root.togglePinApp(root.dragDropTargetApp);
                                                                    }
                                                                    if (root.isAppPinned(root.draggingApp)) {
                                                                        root.togglePinApp(root.draggingApp);
                                                                    }
                                                                }
                                                                root.isDraggingApp = false;
                                                                root.draggingApp = null;
                                                                root.dragDropTargetFolder = null;
                                                                root.dragDropTargetApp = null;
                                                                dragTriggered = false;
                                                            } else if (!dragTriggered) {
                                                                if (modelData) {
                                                                    try {
                                                                        if (modelData.runInTerminal && modelData.command) {
                                                                            Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(modelData.command.join(' '))}'`]);
                                                                        } else if (typeof modelData.execute === "function") {
                                                                            modelData.execute();
                                                                        }
                                                                    } catch (e) {
                                                                        console.warn("[Win11StartMenu] Launch error:", e);
                                                                    }
                                                                    GlobalStates.startMenuOpen = false;
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // --- Recommended Section (Apps + Real Recent Files) ---
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 6
                                            Layout.rightMargin: 6
                                            spacing: 6

                                            StyledText {
                                                text: Translation.tr("Recommended")
                                                font.weight: Font.DemiBold
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnLayer1
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Filter Chips [Todos] [Arquivos] [Apps]
                                            RowLayout {
                                                visible: Config.options?.dock?.startMenuShowRecentFiles ?? true
                                                spacing: 4

                                                RippleButton {
                                                    implicitHeight: 24
                                                    implicitWidth: 48
                                                    buttonRadius: 5
                                                    colBackground: root.recommendedTab === "all" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    onClicked: root.recommendedTab = "all"
                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: Translation.tr("All")
                                                        font.pixelSize: 10
                                                        font.weight: root.recommendedTab === "all" ? Font.Bold : Font.Normal
                                                        color: root.recommendedTab === "all" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                                    }
                                                }

                                                RippleButton {
                                                    implicitHeight: 24
                                                    implicitWidth: 54
                                                    buttonRadius: 5
                                                    colBackground: root.recommendedTab === "files" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    onClicked: root.recommendedTab = "files"
                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: Translation.tr("Files")
                                                        font.pixelSize: 10
                                                        font.weight: root.recommendedTab === "files" ? Font.Bold : Font.Normal
                                                        color: root.recommendedTab === "files" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                                    }
                                                }

                                                RippleButton {
                                                    implicitHeight: 24
                                                    implicitWidth: 48
                                                    buttonRadius: 5
                                                    colBackground: root.recommendedTab === "apps" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    onClicked: root.recommendedTab = "apps"
                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: Translation.tr("Apps")
                                                        font.pixelSize: 10
                                                        font.weight: root.recommendedTab === "apps" ? Font.Bold : Font.Normal
                                                        color: root.recommendedTab === "apps" ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                                    }
                                                }
                                            }
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 2
                                            columnSpacing: 8
                                            rowSpacing: 4

                                            Repeater {
                                                model: root.combinedRecommendedList
                                                delegate: RippleButton {
                                                    id: recItemBtn
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    implicitHeight: 52
                                                    buttonRadius: 8
                                                    colBackground: "transparent"
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    altAction: (event) => {
                                                        if (modelData.isFile) {
                                                            root.contextMenuTargetFile = modelData.fileObj;
                                                            root.contextMenuTargetApp = null;
                                                        } else {
                                                            root.contextMenuTargetApp = modelData;
                                                            root.contextMenuTargetFile = null;
                                                        }
                                                        root.activeFolder = null;
                                                        const p = mapToItem(startMenuCard, event.x, event.y);
                                                        root.contextMenuPos = Qt.point(Math.min(p.x, startMenuCard.width - 220), Math.min(p.y, startMenuCard.height - 240));
                                                        root.appContextMenuOpen = true;
                                                        root.powerFlyoutOpen = false;
                                                    }
                                                    onClicked: {
                                                        if (modelData && typeof modelData.execute === "function") {
                                                            modelData.execute();
                                                        }
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 10
                                                        spacing: 10

                                                        Item {
                                                            width: 28
                                                            height: 28
                                                            Layout.alignment: Qt.AlignVCenter

                                                            IconImage {
                                                                anchors.fill: parent
                                                                source: Quickshell.iconPath(modelData?.icon ?? "text-x-generic", "application-x-executable")
                                                                implicitSize: 28
                                                            }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 2
                                                            StyledText {
                                                                Layout.fillWidth: true
                                                                text: modelData?.name ?? ""
                                                                font.weight: Font.Medium
                                                                font.pixelSize: Appearance.font.pixelSize.small
                                                                color: Appearance.colors.colOnLayer0
                                                                elide: Text.ElideRight
                                                            }
                                                            StyledText {
                                                                Layout.fillWidth: true
                                                                text: modelData?.subtitle ?? ""
                                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                                color: Appearance.colors.colOnLayer1
                                                                elide: Text.ElideRight
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        StyledText {
                                            visible: root.combinedRecommendedList.length === 0
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.topMargin: 14
                                            text: Translation.tr("No recommended items yet")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }

                                    // --- Quick Categories ---
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        spacing: 8

                                        // Internet & Web
                                        RippleButton {
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            buttonRadius: 8
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                searchInput.text = "browser";
                                                searchInput.forceActiveFocus();
                                            }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                MaterialSymbol { text: "language"; iconSize: 16; color: Appearance.colors.colPrimary }
                                                StyledText { text: Translation.tr("Internet"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                            }
                                        }

                                        // Development
                                        RippleButton {
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            buttonRadius: 8
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                searchInput.text = "terminal";
                                                searchInput.forceActiveFocus();
                                            }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                MaterialSymbol { text: "terminal"; iconSize: 16; color: Appearance.colors.colSecondary }
                                                StyledText { text: Translation.tr("Dev Tools"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                            }
                                        }

                                        // Media & Games
                                        RippleButton {
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            buttonRadius: 8
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                searchInput.text = "media";
                                                searchInput.forceActiveFocus();
                                            }

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                MaterialSymbol { text: "sports_esports"; iconSize: 16; color: Appearance.colors.colTertiary }
                                                StyledText { text: Translation.tr("Media & Games"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---------------- Footer (Profile & Power) ----------------
                        Rectangle {
                            id: footerBar
                            Layout.fillWidth: true
                            implicitHeight: 56
                            color: root.acrylicBg ? ColorUtils.transparentize(Appearance.colors.colLayer1, 0.4) : ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.4)
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            radius: startMenuCard.radius

                            // Square off the top corners, keeping only the
                            // bottom two rounded to match startMenuCard's clip
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: parent.radius
                                color: parent.color
                            }

                            // Re-draw the top border since the mask above
                            // covers it
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: parent.border.width
                                color: parent.border.color
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20

                                // Profile Card Clickable
                                RippleButton {
                                    implicitHeight: 40
                                    implicitWidth: profileRow.implicitWidth + 20
                                    buttonRadius: 8
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        GlobalStates.settingsOpen = true;
                                        GlobalStates.settingsPage = "Profile";
                                        GlobalStates.startMenuOpen = false;
                                    }

                                    RowLayout {
                                        id: profileRow
                                        anchors.centerIn: parent
                                        spacing: 10

                                        Item {
                                            width: 32
                                            height: 32

                                            Item {
                                                id: avatarMask
                                                anchors.fill: parent
                                                visible: false
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                }
                                            }

                                            Image {
                                                id: avatarImg
                                                anchors.fill: parent
                                                source: Avatar.effectiveAvatarSource
                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectCrop
                                                visible: status === Image.Ready && source != ""
                                                layer.enabled: true
                                                layer.effect: OpacityMask {
                                                    maskSource: avatarMask
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: Appearance.colors.colPrimary
                                                visible: !avatarImg.visible

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "person"
                                                    iconSize: 18
                                                    color: Appearance.m3colors.m3onPrimary
                                                }
                                            }
                                        }

                                        StyledText {
                                            text: Config.options.profile.displayName !== "" ? Config.options.profile.displayName : SystemInfo.username
                                            font.weight: Font.Medium
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Quick Folder Shortcuts (Home, Downloads, Documents, Pictures, Terminal, Settings)
                                RowLayout {
                                    visible: Config.options?.dock?.startMenuShowQuickFolders ?? true
                                    spacing: 2

                                    // Home Folder
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", "dolphin ~ || xdg-open ~"]);
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "home"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Home") }
                                    }

                                    // Downloads Folder
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", "dolphin ~/Downloads || xdg-open ~/Downloads"]);
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "download"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Downloads") }
                                    }

                                    // Documents Folder
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", "dolphin ~/Documents || xdg-open ~/Documents"]);
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "description"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Documents") }
                                    }

                                    // Pictures Folder
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", "dolphin ~/Pictures || xdg-open ~/Pictures"]);
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "photo_library"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Pictures") }
                                    }

                                    // Terminal
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            Quickshell.execDetached(["bash", "-c", Config.options.apps.terminal]);
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "terminal"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Terminal") }
                                    }

                                    // Settings
                                    RippleButton {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        buttonRadius: 6
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            GlobalStates.settingsOpen = true;
                                            GlobalStates.startMenuOpen = false;
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        StyledToolTip { text: Translation.tr("Settings") }
                                    }
                                }

                                // Power Button
                                RippleButton {
                                    id: powerButton
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    buttonRadius: 8
                                    colBackground: root.powerFlyoutOpen ? Appearance.colors.colLayer1Hover : "transparent"
                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                    onClicked: {
                                        root.powerFlyoutOpen = !root.powerFlyoutOpen;
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "power_settings_new"
                                        iconSize: 20
                                        color: (parent.hovered || root.powerFlyoutOpen) ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                                    }

                                    StyledToolTip { text: Translation.tr("Power / Session Menu") }
                                }
                            }
                        }
                    }

                    // Dismiss overlay for power flyout, context menu & dialogs
                    MouseArea {
                        anchors.fill: parent
                        visible: root.powerFlyoutOpen || root.appContextMenuOpen || root.newFolderDialogOpen || root.folderPickerOpen || root.addAppToFolderDialogOpen
                        z: 190
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPressed: {
                            root.powerFlyoutOpen = false;
                            root.appContextMenuOpen = false;
                            root.contextMenuTargetApp = null;
                            root.newFolderDialogOpen = false;
                            root.folderPickerOpen = false;
                            root.folderPickerTargetApp = null;
                            root.addAppToFolderDialogOpen = false;
                        }
                    }

                    // Power Flyout Popup Menu
                    Rectangle {
                        id: powerFlyout
                        visible: root.powerFlyoutOpen
                        z: 200
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 64
                        width: 190
                        height: powerFlyoutCol.implicitHeight + 16
                        radius: Appearance.rounding.normal
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.8)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow {
                            target: powerFlyout
                        }

                        ColumnLayout {
                            id: powerFlyoutCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.powerFlyoutOpen = false;
                                    GlobalStates.startMenuOpen = false;
                                    Session.lock();
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    MaterialSymbol { text: "lock"; iconSize: 16; color: Appearance.colors.colOnLayer0 }
                                    StyledText { text: Translation.tr("Lock"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.powerFlyoutOpen = false;
                                    GlobalStates.startMenuOpen = false;
                                    Session.suspend();
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    MaterialSymbol { text: "bedtime"; iconSize: 16; color: Appearance.colors.colOnLayer0 }
                                    StyledText { text: Translation.tr("Sleep"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.powerFlyoutOpen = false;
                                    GlobalStates.startMenuOpen = false;
                                    Session.reboot();
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    MaterialSymbol { text: "restart_alt"; iconSize: 16; color: Appearance.colors.colOnLayer0 }
                                    StyledText { text: Translation.tr("Restart"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colErrorContainer
                                onClicked: {
                                    root.powerFlyoutOpen = false;
                                    GlobalStates.startMenuOpen = false;
                                    Session.poweroff();
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    MaterialSymbol { text: "power_settings_new"; iconSize: 16; color: Appearance.colors.colError }
                                    StyledText { text: Translation.tr("Shut down"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colError }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Appearance.colors.colLayer0Border
                            }

                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.powerFlyoutOpen = false;
                                    GlobalStates.startMenuOpen = false;
                                    Session.logout();
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10
                                    MaterialSymbol { text: "logout"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                                    StyledText { text: Translation.tr("Sign out"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }
                        }
                    }

                    // App, Folder & Recent File Context Menu (Right-click)
                    Rectangle {
                        id: appContextMenu
                        visible: root.appContextMenuOpen && (root.contextMenuTargetApp !== null || root.activeFolder !== null || root.contextMenuTargetFile !== null)
                        z: 220
                        x: Math.max(8, Math.min(root.contextMenuPos.x, startMenuCard.width - 220))
                        y: Math.max(8, Math.min(root.contextMenuPos.y, startMenuCard.height - 240))
                        width: 210
                        height: appContextMenuCol.implicitHeight + 16
                        radius: Appearance.rounding.normal
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.85)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow {
                            target: appContextMenu
                        }

                        ColumnLayout {
                            id: appContextMenuCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            // 1. Header when targeting a Recent File
                            RowLayout {
                                visible: root.contextMenuTargetFile !== null
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                Layout.topMargin: 2
                                Layout.bottomMargin: 4
                                spacing: 8

                                IconImage {
                                    source: Quickshell.iconPath(root.contextMenuTargetFile?.icon ?? "text-x-generic", "text-x-generic")
                                    implicitSize: 20
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.contextMenuTargetFile?.name ?? ""
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                            }

                            // 2. Header when targeting a Folder
                            RowLayout {
                                visible: root.contextMenuTargetApp === null && root.contextMenuTargetFile === null && root.activeFolder !== null
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                Layout.topMargin: 2
                                Layout.bottomMargin: 4
                                spacing: 8

                                MaterialSymbol {
                                    text: "folder"
                                    iconSize: 20
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.activeFolder?.name ?? Translation.tr("Folder")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                            }

                            // 3. Header when targeting an App
                            RowLayout {
                                visible: root.contextMenuTargetApp !== null
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                Layout.topMargin: 2
                                Layout.bottomMargin: 4
                                spacing: 8

                                IconImage {
                                    source: Quickshell.iconPath(root.contextMenuTargetApp?.icon ?? "", "application-x-executable")
                                    implicitSize: 20
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.contextMenuTargetApp?.name ?? ""
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Appearance.colors.colLayer0Border
                            }

                            // Recent File Actions
                            RippleButton {
                                visible: root.contextMenuTargetFile !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const file = root.contextMenuTargetFile;
                                    root.appContextMenuOpen = false;
                                    if (file && typeof file.execute === "function") {
                                        file.execute();
                                        GlobalStates.startMenuOpen = false;
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "open_in_new"; iconSize: 16; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Open"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                visible: root.contextMenuTargetFile !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const file = root.contextMenuTargetFile;
                                    root.appContextMenuOpen = false;
                                    if (file?.path) {
                                        Quickshell.clipboardText = file.path;
                                        root.showCopiedToast(file.path);
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "content_copy"; iconSize: 16; color: Appearance.colors.colSecondary }
                                    StyledText { text: Translation.tr("Copy path"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                visible: root.contextMenuTargetFile !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const file = root.contextMenuTargetFile;
                                    root.appContextMenuOpen = false;
                                    if (file?.path) {
                                        const dir = file.path.substring(0, file.path.lastIndexOf("/"));
                                        Quickshell.execDetached(["xdg-open", dir]);
                                        GlobalStates.startMenuOpen = false;
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "folder_open"; iconSize: 16; color: Appearance.colors.colTertiary }
                                    StyledText { text: Translation.tr("Open containing folder"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            // Folder Actions
                            RippleButton {
                                visible: root.contextMenuTargetApp === null && root.activeFolder !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.appContextMenuOpen = false;
                                    root.folderModalOpen = true;
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "folder_open"; iconSize: 16; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Open Folder"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            RippleButton {
                                visible: root.contextMenuTargetApp === null && root.activeFolder !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colErrorContainer
                                onClicked: {
                                    if (root.activeFolder) {
                                        StartMenuFolders.deleteFolder(root.activeFolder.id);
                                        root.activeFolder = null;
                                    }
                                    root.appContextMenuOpen = false;
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "delete"; iconSize: 16; color: Appearance.colors.colError }
                                    StyledText { text: Translation.tr("Delete Folder"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colError }
                                }
                            }

                            // App Actions: Open / Run
                            RippleButton {
                                visible: root.contextMenuTargetApp !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const app = root.contextMenuTargetApp;
                                    root.appContextMenuOpen = false;
                                    if (app) {
                                        try {
                                            if (app.runInTerminal && app.command) {
                                                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(' '))}'`]);
                                            } else if (typeof app.execute === "function") {
                                                app.execute();
                                            }
                                        } catch (e) {
                                            console.warn("[Win11StartMenu] Launch error:", e);
                                        }
                                        GlobalStates.startMenuOpen = false;
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "play_arrow"; iconSize: 16; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Open"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            // App Action: Pin / Unpin from Start
                            RippleButton {
                                visible: root.contextMenuTargetApp !== null
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.togglePinApp(root.contextMenuTargetApp);
                                    root.appContextMenuOpen = false;
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol {
                                        text: root.isAppPinned(root.contextMenuTargetApp) ? "keep_off" : "keep"
                                        iconSize: 16
                                        color: Appearance.colors.colSecondary
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: root.isAppPinned(root.contextMenuTargetApp) ? Translation.tr("Unpin from Start") : Translation.tr("Pin to Start")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer0
                                    }
                                }
                            }

                            // App Action: Add to Folder (Direct Submenu List)
                            ColumnLayout {
                                visible: root.contextMenuTargetApp !== null
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 6
                                    Layout.rightMargin: 6
                                    Layout.topMargin: 2
                                    spacing: 6
                                    MaterialSymbol { text: "folder_open"; iconSize: 14; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Add to folder"); font.weight: Font.DemiBold; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                                }

                                Repeater {
                                    model: StartMenuFolders.list
                                    delegate: RippleButton {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        buttonRadius: 5
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            if (root.contextMenuTargetApp?.id && modelData?.id) {
                                                StartMenuFolders.addAppToFolder(modelData.id, root.contextMenuTargetApp.id);
                                                if (root.isAppPinned(root.contextMenuTargetApp)) {
                                                    root.togglePinApp(root.contextMenuTargetApp);
                                                }
                                            }
                                            root.appContextMenuOpen = false;
                                        }
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 8
                                            spacing: 6
                                            MaterialSymbol { text: "folder"; iconSize: 14; color: Appearance.colors.colPrimary }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: modelData?.name ?? Translation.tr("Folder")
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colOnLayer0
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                RippleButton {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    buttonRadius: 5
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        const app = root.contextMenuTargetApp;
                                        root.appContextMenuOpen = false;
                                        if (app?.id) {
                                            root.newFolderNameInput = "";
                                            const newF = StartMenuFolders.createFolder("Nova Pasta", app.id);
                                            if (root.isAppPinned(app)) {
                                                root.togglePinApp(app);
                                            }
                                            root.activeFolder = newF;
                                            root.folderModalOpen = true;
                                        }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        MaterialSymbol { text: "create_new_folder"; iconSize: 14; color: Appearance.colors.colPrimary }
                                        StyledText { text: Translation.tr("Create New Folder"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colPrimary }
                                    }
                                }
                            }

                            // App Action: Run in Terminal
                            RippleButton {
                                visible: root.contextMenuTargetApp !== null && (root.contextMenuTargetApp?.command !== undefined || root.contextMenuTargetApp?.exec !== undefined)
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const app = root.contextMenuTargetApp;
                                    root.appContextMenuOpen = false;
                                    if (app) {
                                        const cmd = app.command ? app.command.join(' ') : (app.exec || app.id);
                                        Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(cmd)}'`]);
                                        GlobalStates.startMenuOpen = false;
                                    }
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    MaterialSymbol { text: "terminal"; iconSize: 16; color: Appearance.colors.colTertiary }
                                    StyledText { text: Translation.tr("Run in Terminal"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // ALPHABET JUMP LIST MODAL (Windows 11 A-Z)
                    // ==========================================
                    Rectangle {
                        id: alphabetJumpModal
                        visible: root.alphabetJumpModalOpen
                        z: 240
                        anchors.centerIn: parent
                        width: 320
                        height: 320
                        radius: Appearance.rounding.large
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.95)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow { target: alphabetJumpModal }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: Translation.tr("Jump to letter")
                                    font.weight: Font.Bold
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                }
                                Item { Layout.fillWidth: true }
                                RippleButton {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.alphabetJumpModalOpen = false
                                    MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                                }
                            }

                            GridLayout {
                                id: alphabetGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 6
                                rowSpacing: 6
                                columnSpacing: 6

                                readonly property var availableLetters: Object.keys(root.alphabetLetterIndices || {})
                                readonly property var allChars: ["#", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

                                Repeater {
                                    model: alphabetGrid.allChars
                                    delegate: RippleButton {
                                        required property string modelData
                                        readonly property bool hasApps: alphabetGrid.availableLetters.includes(modelData)
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        buttonRadius: 6
                                        enabled: hasApps
                                        colBackground: hasApps ? Appearance.colors.colLayer1 : Qt.rgba(1, 1, 1, 0.02)
                                        colBackgroundHover: Appearance.colors.colPrimary
                                        onClicked: {
                                            const idx = root.alphabetLetterIndices[modelData];
                                            if (idx !== undefined && allAppsListView) {
                                                allAppsListView.positionViewAtIndex(idx, ListView.Beginning);
                                            }
                                            root.alphabetJumpModalOpen = false;
                                        }
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.weight: hasApps ? Font.Bold : Font.Normal
                                            font.pixelSize: 13
                                            color: hasApps ? Appearance.colors.colOnLayer0 : Appearance.colors.colLayer0Border
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // COPIED TOAST NOTIFICATION
                    // ==========================================
                    Rectangle {
                        id: copiedToast
                        visible: root.copiedToastText !== ""
                        z: 250
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 64
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: toastRow.implicitWidth + 24
                        implicitHeight: 36
                        radius: 18
                        color: Appearance.colors.colPrimary
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        RowLayout {
                            id: toastRow
                            anchors.centerIn: parent
                            spacing: 8
                            MaterialSymbol {
                                text: "check_circle"
                                iconSize: 18
                                color: Appearance.m3colors.m3onPrimary
                            }
                            StyledText {
                                text: Translation.tr("Copied") + ": " + root.copiedToastText
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.m3colors.m3onPrimary
                                elide: Text.ElideRight
                                Layout.maximumWidth: 300
                            }
                        }
                    }

                    // ==========================================
                    // NEW FOLDER DIALOG (Modal Popover)
                    // ==========================================
                    Rectangle {
                        id: newFolderDialog
                        visible: root.newFolderDialogOpen
                        z: 230
                        anchors.centerIn: parent
                        width: 320
                        height: newFolderCol.implicitHeight + 32
                        radius: Appearance.rounding.large
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.9)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow { target: newFolderDialog }

                        ColumnLayout {
                            id: newFolderCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol { text: "create_new_folder"; iconSize: 22; color: Appearance.colors.colPrimary }
                                StyledText { text: Translation.tr("New Folder"); font.weight: Font.DemiBold; font.pixelSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer0 }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: 6
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border

                                TextInput {
                                    id: newFolderNameTextInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                    font.family: Appearance.font.family.main
                                    selectByMouse: true
                                    text: root.newFolderNameInput
                                    onTextChanged: root.newFolderNameInput = text
                                    onAccepted: {
                                        if (text.trim() !== "") {
                                            StartMenuFolders.createFolder(text.trim());
                                            root.newFolderDialogOpen = false;
                                        }
                                    }

                                    Text {
                                        text: Translation.tr("Folder name...")
                                        color: Appearance.colors.colOnLayer1Inactive
                                        font: parent.font
                                        visible: !parent.text
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item { Layout.fillWidth: true }

                                RippleButton {
                                    implicitWidth: 80
                                    implicitHeight: 32
                                    buttonRadius: 6
                                    colBackground: Appearance.colors.colLayer1
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.newFolderDialogOpen = false
                                    StyledText { anchors.centerIn: parent; text: Translation.tr("Cancel"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }

                                RippleButton {
                                    implicitWidth: 80
                                    implicitHeight: 32
                                    buttonRadius: 6
                                    colBackground: Appearance.colors.colPrimary
                                    colBackgroundHover: Appearance.colors.colPrimaryHover
                                    onClicked: {
                                        if (root.newFolderNameInput.trim() !== "") {
                                            StartMenuFolders.createFolder(root.newFolderNameInput.trim());
                                            root.newFolderDialogOpen = false;
                                        }
                                    }
                                    StyledText { anchors.centerIn: parent; text: Translation.tr("Create"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.m3colors.m3onPrimary }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // FOLDER PICKER DIALOG (Add App to existing/new folder)
                    // ==========================================
                    Rectangle {
                        id: folderPickerDialog
                        visible: root.folderPickerOpen && root.folderPickerTargetApp !== null
                        z: 230
                        anchors.centerIn: parent
                        width: 320
                        height: Math.min(380, folderPickerCol.implicitHeight + 32)
                        radius: Appearance.rounding.large
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.9)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow { target: folderPickerDialog }

                        ColumnLayout {
                            id: folderPickerCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol { text: "folder"; iconSize: 20; color: Appearance.colors.colPrimary }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Add to Folder")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                }
                            }

                            // Folders list
                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(180, folderPickerListCol.implicitHeight)
                                contentHeight: folderPickerListCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: folderPickerListCol
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: StartMenuFolders.list
                                        delegate: RippleButton {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 34
                                            buttonRadius: 6
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                if (root.folderPickerTargetApp?.id && modelData?.id) {
                                                    StartMenuFolders.addAppToFolder(modelData.id, root.folderPickerTargetApp.id);
                                                    root.folderPickerOpen = false;
                                                    root.folderPickerTargetApp = null;
                                                }
                                            }
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                spacing: 8
                                                MaterialSymbol { text: "folder"; iconSize: 16; color: Appearance.colors.colPrimary }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData?.name ?? Translation.tr("Folder")
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: Appearance.colors.colLayer0Border
                            }

                            // Create New Folder and Add
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                buttonRadius: 6
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    const app = root.folderPickerTargetApp;
                                    root.folderPickerOpen = false;
                                    if (app?.id) {
                                        root.newFolderNameInput = "";
                                        const newF = StartMenuFolders.createFolder("Nova Pasta", app.id);
                                        root.activeFolder = newF;
                                    }
                                }
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MaterialSymbol { text: "add"; iconSize: 16; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Create New Folder"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }
                                }
                            }
                        }
                    }

                    // ==========================================
                    // ADD APP TO FOLDER DIALOG (App search & picker)
                    // ==========================================
                    Rectangle {
                        id: addAppToFolderDialog
                        visible: root.addAppToFolderDialogOpen && root.activeFolder !== null
                        z: 230
                        anchors.centerIn: parent
                        width: 360
                        height: 420
                        radius: Appearance.rounding.large
                        color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.9)
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border
                        clip: true

                        StyledRectangularShadow { target: addAppToFolderDialog }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol { text: "apps"; iconSize: 20; color: Appearance.colors.colPrimary }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Add Application")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                }
                                RippleButton {
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: root.addAppToFolderDialogOpen = false
                                    MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                                }
                            }

                            // Search bar
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: 6
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    MaterialSymbol { text: "search"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                                    TextInput {
                                        id: addAppSearchInput
                                        Layout.fillWidth: true
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer0
                                        font.family: Appearance.font.family.main
                                        selectByMouse: true
                                        text: root.addAppSearchQuery
                                        onTextChanged: root.addAppSearchQuery = text

                                        Text {
                                            text: Translation.tr("Search apps...")
                                            color: Appearance.colors.colOnLayer1Inactive
                                            font: parent.font
                                            visible: !parent.text
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }

                            // Apps list
                            Flickable {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                contentHeight: addAppListCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: addAppListCol
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: {
                                            const all = AppSearch.list || [];
                                            const q = root.addAppSearchQuery.trim().toLowerCase();
                                            if (q === "") return all.slice(0, 30);
                                            return all.filter(a => a && a.name && a.name.toLowerCase().includes(q)).slice(0, 30);
                                        }
                                        delegate: RippleButton {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            buttonRadius: 6
                                            colBackground: Appearance.colors.colLayer1
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                if (root.activeFolder?.id && modelData?.id) {
                                                    StartMenuFolders.addAppToFolder(root.activeFolder.id, modelData.id);
                                                    root.activeFolder = StartMenuFolders.getFolder(root.activeFolder.id);
                                                    root.addAppToFolderDialogOpen = false;
                                                }
                                            }
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 10

                                                IconImage {
                                                    source: Quickshell.iconPath(modelData?.icon ?? "", "application-x-executable")
                                                    implicitSize: 22
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData?.name ?? ""
                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                    color: Appearance.colors.colOnLayer0
                                                    elide: Text.ElideRight
                                                }

                                                MaterialSymbol {
                                                    text: (root.activeFolder && Array.isArray(root.activeFolder.apps) && root.activeFolder.apps.includes(modelData?.id)) ? "check" : "add"
                                                    iconSize: 16
                                                    color: Appearance.colors.colPrimary
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Floating Drag Proxy
                    Rectangle {
                        id: dragProxy
                        visible: root.isDraggingApp && root.draggingApp !== null
                        z: 999
                        x: root.dragCurrentPos.x - 24
                        y: root.dragCurrentPos.y - 24
                        width: 52
                        height: 52
                        radius: 12
                        color: ColorUtils.mix(Appearance.colors.colLayer1, Appearance.colors.colLayer0, 0.2)
                        border.width: 2
                        border.color: Appearance.colors.colPrimary
                        rotation: 5
                        scale: 1.1
                        opacity: 0.92

                        StyledRectangularShadow { target: dragProxy }

                        IconImage {
                            anchors.centerIn: parent
                            source: Quickshell.iconPath(root.draggingApp?.icon ?? "", "application-x-executable")
                            implicitSize: 36
                            width: 36
                            height: 36
                        }
                    }
                }

                // ==========================================
                // RIGHT PANEL (Companion / KDE Connect Panel)
                // ==========================================
                Rectangle {
                    id: companionCard
                    visible: root.showCompanion
                    implicitWidth: 320
                    implicitHeight: 640
                    radius: Appearance.rounding.large + 4
                    color: root.acrylicBg ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25) : Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Mini Media Player (Now Playing) if an active player is playing/available
                        Item {
                            id: miniMediaCard
                            readonly property MprisPlayer activeMedia: MprisController.activePlayer
                            readonly property bool hasMedia: (Config.options?.dock?.startMenuShowMedia ?? true) && activeMedia !== null && ((activeMedia.trackTitle && activeMedia.trackTitle.length > 0) || (activeMedia.trackArtist && activeMedia.trackArtist.length > 0))
                            visible: hasMedia
                            Layout.fillWidth: true
                            implicitHeight: hasMedia ? 72 : 0
                            Layout.topMargin: 12
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.medium
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Track Art / Music Icon
                                    Rectangle {
                                        width: 44
                                        height: 44
                                        radius: 8
                                        color: Appearance.colors.colPrimaryContainer
                                        clip: true

                                        Image {
                                            id: trackArtImg
                                            anchors.fill: parent
                                            source: miniMediaCard.activeMedia?.trackArtUrl ?? ""
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready && source != ""
                                        }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            visible: !trackArtImg.visible
                                            text: "music_note"
                                            iconSize: 22
                                            color: Appearance.colors.colPrimary
                                        }
                                    }

                                    // Title & Artist
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: miniMediaCard.activeMedia?.trackTitle || Translation.tr("Unknown Title")
                                            font.weight: Font.DemiBold
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer0
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: miniMediaCard.activeMedia?.trackArtist || Translation.tr("Unknown Artist")
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Media Controls (Prev, Play/Pause, Next)
                                    RowLayout {
                                        spacing: 2

                                        RippleButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            buttonRadius: 14
                                            colBackground: "transparent"
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                if (miniMediaCard.activeMedia) {
                                                    miniMediaCard.activeMedia.previous();
                                                }
                                            }
                                            MaterialSymbol { anchors.centerIn: parent; text: "skip_previous"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        }

                                        RippleButton {
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            buttonRadius: 16
                                            colBackground: Appearance.colors.colPrimary
                                            colBackgroundHover: Appearance.colors.colPrimaryHover
                                            onClicked: {
                                                if (miniMediaCard.activeMedia) {
                                                    if (typeof miniMediaCard.activeMedia.togglePlaying === "function") {
                                                        miniMediaCard.activeMedia.togglePlaying();
                                                    } else if (typeof miniMediaCard.activeMedia.playPause === "function") {
                                                        miniMediaCard.activeMedia.playPause();
                                                    }
                                                }
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: (miniMediaCard.activeMedia?.isPlaying || miniMediaCard.activeMedia?.playbackState === MprisPlaybackState.Playing) ? "pause" : "play_arrow"
                                                iconSize: 20
                                                color: Appearance.m3colors.m3onPrimary
                                            }
                                        }

                                        RippleButton {
                                            implicitWidth: 28
                                            implicitHeight: 28
                                            buttonRadius: 14
                                            colBackground: "transparent"
                                            colBackgroundHover: Appearance.colors.colLayer1Hover
                                            onClicked: {
                                                if (miniMediaCard.activeMedia) {
                                                    miniMediaCard.activeMedia.next();
                                                }
                                            }
                                            MaterialSymbol { anchors.centerIn: parent; text: "skip_next"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                        }
                                    }
                                }
                            }
                        }

                        // Mini Weather Widget (Modern Beautiful Weather Card)
                        Item {
                            id: miniWeatherCard
                            readonly property bool hasWeather: (Config.options?.dock?.startMenuShowWeather ?? true) && Weather.data !== null
                            visible: hasWeather
                            Layout.fillWidth: true
                            implicitHeight: hasWeather ? 104 : 0
                            Layout.topMargin: miniMediaCard.visible ? 8 : 12
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border

                                // Subtle accent top highlight
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 46
                                    radius: 12
                                    opacity: 0.12
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0.0; color: Appearance.colors.colPrimary }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    anchors.topMargin: 10
                                    anchors.bottomMargin: 10
                                    spacing: 8

                                    // Top Row: Icon + Temp + Condition + Location + Refresh
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        MaterialShapeWrappedMaterialSymbol {
                                            shape: MaterialShape.Shape.Cookie12Sided
                                            color: Appearance.colors.colPrimaryContainer
                                            colSymbol: Appearance.colors.colPrimary
                                            text: Icons.getWeatherIcon(Weather.data?.wCode) ?? "partly_cloudy_day"
                                            iconSize: 20
                                            implicitSize: 36
                                        }

                                        ColumnLayout {
                                            spacing: 0
                                            RowLayout {
                                                spacing: 6
                                                StyledText {
                                                    text: Weather.data?.temp || "--°"
                                                    font.weight: Font.Bold
                                                    font.pixelSize: 18
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                                StyledText {
                                                    text: Weather.data?.description ? (Weather.data.description.charAt(0).toUpperCase() + Weather.data.description.slice(1)) : Translation.tr("Weather")
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: Appearance.colors.colPrimary
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 90
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        // City Location
                                        RowLayout {
                                            spacing: 2
                                            MaterialSymbol {
                                                text: "location_on"
                                                iconSize: 12
                                                color: Appearance.colors.colOnLayer1
                                            }
                                            StyledText {
                                                text: Weather.data?.city || "São Paulo"
                                                font.pixelSize: 11
                                                color: Appearance.colors.colOnLayer1
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 65
                                            }
                                        }

                                        RippleButton {
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            buttonRadius: 13
                                            colBackground: "transparent"
                                            colBackgroundHover: Appearance.colors.colLayer2Hover
                                            onClicked: Weather.getData()
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "refresh"
                                                iconSize: 14
                                                color: Appearance.colors.colOnLayer1
                                            }
                                            StyledToolTip { text: Translation.tr("Refresh weather") }
                                        }
                                    }

                                    // Bottom Row: 3 Stats Pills (Humidity, Feels Like, Wind)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        // Humidity Pill
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 24
                                            radius: 6
                                            color: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.45)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                MaterialSymbol { text: "water_drop"; iconSize: 12; color: "#38BDF8" }
                                                StyledText {
                                                    text: Weather.data?.humidity || "--"
                                                    font.pixelSize: 10
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                            }
                                        }

                                        // Feels Like Pill
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 24
                                            radius: 6
                                            color: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.45)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                MaterialSymbol { text: "thermostat"; iconSize: 12; color: "#F97316" }
                                                StyledText {
                                                    text: Weather.data?.tempFeelsLike || "--"
                                                    font.pixelSize: 10
                                                    color: Appearance.colors.colOnLayer0
                                                }
                                            }
                                        }

                                        // Wind Pill
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 24
                                            radius: 6
                                            color: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.45)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                MaterialSymbol { text: "air"; iconSize: 12; color: "#A855F7" }
                                                StyledText {
                                                    text: Weather.data?.wind || "--"
                                                    font.pixelSize: 10
                                                    color: Appearance.colors.colOnLayer0
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: 55
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // System Quick Glance Card (CPU, RAM, Battery)
                        Item {
                            id: systemResourcesCard
                            readonly property bool showResources: Config.options?.dock?.startMenuShowSystemResources ?? true
                            visible: showResources
                            Layout.fillWidth: true
                            implicitHeight: showResources ? 40 : 0
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            Layout.topMargin: showResources ? 4 : 0
                            Layout.bottomMargin: showResources ? 2 : 0

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    // CPU
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        MaterialSymbol { text: "memory"; iconSize: 15; color: Appearance.colors.colPrimary }
                                        ColumnLayout {
                                            spacing: -2
                                            StyledText { text: "CPU"; font.pixelSize: 8; color: Appearance.colors.colOnLayer1 }
                                            StyledText { text: `${Math.round(ResourceUsage.cpuUsage * 100)}%`; font.weight: Font.Bold; font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                        }
                                    }

                                    Rectangle { width: 1; height: 18; color: Appearance.colors.colLayer0Border }

                                    // RAM
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        MaterialSymbol { text: "storage"; iconSize: 15; color: Appearance.colors.colSecondary }
                                        ColumnLayout {
                                            spacing: -2
                                            StyledText { text: "RAM"; font.pixelSize: 8; color: Appearance.colors.colOnLayer1 }
                                            StyledText { text: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`; font.weight: Font.Bold; font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                        }
                                    }

                                    Rectangle { width: 1; height: 18; color: Appearance.colors.colLayer0Border }

                                    // Battery / Power
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 5
                                        MaterialSymbol {
                                            text: Battery.available ? (Battery.isCharging ? "battery_charging_full" : "battery_full") : "power"
                                            iconSize: 15
                                            color: Battery.percentage < 0.2 ? Appearance.colors.colError : "#10B981"
                                        }
                                        ColumnLayout {
                                            spacing: -2
                                            StyledText { text: Battery.available ? Translation.tr("Battery") : Translation.tr("Power"); font.pixelSize: 8; color: Appearance.colors.colOnLayer1 }
                                            StyledText { text: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "AC"; font.weight: Font.Bold; font.pixelSize: 11; color: Appearance.colors.colOnLayer0 }
                                        }
                                    }
                                }
                            }
                        }

                        // Phone Status Top Card
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: visible ? 130 : 0
                            visible: Config.options?.dock?.startMenuShowKdeConnect ?? true

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                // Phone Visual Mockup (Clickable to open KDE Connect)
                                RippleButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 44
                                    implicitHeight: 60
                                    buttonRadius: 10
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        Quickshell.execDetached(["kdeconnect-app"]);
                                        GlobalStates.startMenuOpen = false;
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 36
                                        height: 52
                                        radius: 8
                                        color: root.kdeConnected ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                                        border.width: 2
                                        border.color: Appearance.colors.colOnLayer0

                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.topMargin: 3
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 12
                                            height: 3
                                            radius: 2
                                            color: Appearance.colors.colLayer0
                                        }

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "smartphone"
                                            iconSize: 20
                                            color: root.kdeConnected ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                                        }
                                    }
                                    StyledToolTip { text: Translation.tr("Open KDE Connect") }
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.kdeConnected ? (root.kdeDeviceName.length > 0 ? root.kdeDeviceName : Translation.tr("Connected Phone")) : Translation.tr("No Phone Connected")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer0
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: 14
                                        implicitHeight: 14
                                        radius: 7
                                        color: root.kdeConnected ? "#107C41" : "#757575"
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: root.kdeConnected ? "check" : "close"
                                            iconSize: 10
                                            color: "white"
                                        }
                                    }

                                    MaterialSymbol {
                                        text: root.kdeConnected ? "phonelink_ring" : "phonelink_erase"
                                        iconSize: 15
                                        color: root.kdeConnected ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    }

                                    RowLayout {
                                        spacing: 4
                                        visible: Battery.available
                                        MaterialSymbol {
                                            text: Battery.isCharging ? "battery_charging_full" : "battery_full"
                                            iconSize: 14
                                            color: Appearance.colors.colOnLayer0
                                        }
                                        StyledText {
                                            text: `${Math.round(Battery.percentage * 100)}%`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }

                                    RowLayout {
                                        spacing: 4
                                        visible: !Battery.available
                                        MaterialSymbol {
                                            text: "power"
                                            iconSize: 14
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            text: Translation.tr("AC Power")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colOnLayer1
                                        }
                                    }
                                }
                            }
                        }

                        // Quick Action Buttons (2x2 Grid)
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            visible: Config.options?.dock?.startMenuShowKdeConnect ?? true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6

                            // KDE Connect SMS
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["kdeconnect-sms"]);
                                    GlobalStates.startMenuOpen = false;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 6
                                    MaterialSymbol { text: "sms"; iconSize: 16; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Messages (SMS)"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }

                            // Ring Phone / Find My Phone
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "kdeconnect-cli --ring || notify-send 'KDE Connect' 'No phone reachable'"]);
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 6
                                    MaterialSymbol { text: "ring_volume"; iconSize: 16; color: Appearance.colors.colSecondary }
                                    StyledText { text: Translation.tr("Ring Phone"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }

                            // Send Clipboard
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "kdeconnect-cli --share-text \"$(wl-paste)\" || notify-send 'KDE Connect' 'Sent clipboard'"]);
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 6
                                    MaterialSymbol { text: "content_paste_go"; iconSize: 16; color: "#38BDF8" }
                                    StyledText { text: Translation.tr("Send Clipboard"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }

                            // Send File / App
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["kdeconnect-app"]);
                                    GlobalStates.startMenuOpen = false;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    spacing: 6
                                    MaterialSymbol { text: "share"; iconSize: 16; color: "#A855F7" }
                                    StyledText { text: Translation.tr("Send File"); font.pixelSize: 11; color: Appearance.colors.colOnLayer0; elide: Text.ElideRight; Layout.fillWidth: true }
                                }
                            }
                        }

                        // Recent Phone Notifications Header
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 18
                            Layout.rightMargin: 14
                            Layout.topMargin: 12
                            Layout.bottomMargin: 4
                            visible: Config.options?.dock?.startMenuShowKdeConnect ?? true

                            StyledText {
                                text: Translation.tr("Phone Notifications")
                                font.weight: Font.DemiBold
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                            }

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                readonly property int notifCount: root.phoneNotifications.length > 0 ? root.phoneNotifications.length : (Notifications.list || []).filter(n => n && n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect"))).length
                                visible: notifCount > 0
                                implicitHeight: 22
                                implicitWidth: 54
                                buttonRadius: 4
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    root.phoneNotifications = [];
                                    const kdeNotifs = (Notifications.list || []).filter(n => n && n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect")));
                                    for (let i = 0; i < kdeNotifs.length; i++) {
                                        if (kdeNotifs[i].notificationId !== undefined) {
                                            Notifications.discardNotification(kdeNotifs[i].notificationId);
                                        }
                                    }
                                }
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    MaterialSymbol { text: "delete_sweep"; iconSize: 13; color: Appearance.colors.colOnLayer1 }
                                    StyledText { text: Translation.tr("Clear"); font.pixelSize: 10; color: Appearance.colors.colOnLayer1 }
                                }
                                StyledToolTip { text: Translation.tr("Clear notifications") }
                            }
                        }

                        // Recent Phone Notifications List
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            visible: Config.options?.dock?.startMenuShowKdeConnect ?? true
                            contentHeight: notifCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: notifCol
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: root.phoneNotifications.length > 0 ? root.phoneNotifications : (Notifications.list || []).filter(n => n && n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect"))).slice(0, 5)
                                    delegate: RippleButton {
                                        id: notifItemBtn
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        buttonRadius: 8
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 6
                                                color: Appearance.colors.colPrimaryContainer

                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "smartphone"
                                                    iconSize: 16
                                                    color: Appearance.colors.colPrimary
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData?.title || modelData?.summary || modelData?.appName || Translation.tr("Phone Alert")
                                                    font.weight: Font.Medium
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colOnLayer0
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData?.body || modelData?.app || Translation.tr("Notification")
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: Appearance.colors.colOnLayer1
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Dismiss button (visible on hover)
                                            RippleButton {
                                                visible: notifItemBtn.hovered
                                                implicitWidth: 22
                                                implicitHeight: 22
                                                buttonRadius: 11
                                                colBackground: "transparent"
                                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                                onClicked: {
                                                    if (modelData?.notificationId !== undefined) {
                                                        Notifications.discardNotification(modelData.notificationId);
                                                    }
                                                    if (root.phoneNotifications && root.phoneNotifications.length > 0) {
                                                        root.phoneNotifications = root.phoneNotifications.filter((_, idx) => idx !== index);
                                                    }
                                                }
                                                MaterialSymbol {
                                                    anchors.centerIn: parent
                                                    text: "close"
                                                    iconSize: 14
                                                    color: Appearance.colors.colOnLayer1
                                                }
                                                StyledToolTip { text: Translation.tr("Dismiss") }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    visible: (root.phoneNotifications.length === 0) && ((Notifications.list || []).filter(n => n && n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect"))).length === 0)
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 16
                                    text: root.kdeConnected ? Translation.tr("No phone notifications") : Translation.tr("Connect phone via KDE Connect")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }

                        // Bottom Footer: KDE Connect App button
                        Item {
                            id: companionFooterBar
                            Layout.fillWidth: true
                            implicitHeight: 56

                            // 1px top divider line
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Appearance.colors.colLayer0Border
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 8

                                RippleButton {
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    buttonRadius: 8
                                    colBackground: Appearance.colors.colLayer1
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        Quickshell.execDetached(["kdeconnect-app"]);
                                        GlobalStates.startMenuOpen = false;
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialSymbol { text: "share"; iconSize: 16; color: Appearance.colors.colPrimary }
                                        StyledText { text: Translation.tr("KDE Connect App"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    buttonRadius: 8
                                    colBackground: Appearance.colors.colLayer1
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        GlobalStates.settingsOpen = true;
                                        GlobalStates.startMenuOpen = false;
                                    }
                                    MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: 18; color: Appearance.colors.colOnLayer0 }
                                    StyledToolTip { text: Translation.tr("Settings") }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
