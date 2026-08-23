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

        mask: Region {
            item: GlobalStates.startMenuOpen ? mainContainer : null
        }

        property string searchText: ""
        property bool showAllApps: false
        property var searchResults: searchText.trim() === "" ? [] : AppSearch.fuzzyQuery(searchText)

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
            const pinned = Config.options.dock.pinnedApps ?? [];
            let list = pinned.map(id => DesktopEntries.heuristicLookup(id)).filter(e => e !== null);
            if (list.length === 0) {
                list = AppSearch.list.slice(0, 6);
            }
            return list;
        }

        // Dynamic recommended items based on active running windows & favorite apps
        readonly property var recommendedList: {
            let list = [];
            const running = TaskbarApps.apps.filter(a => a.appId !== "SEPARATOR" && a.toplevels && a.toplevels.length > 0);
            for (let i = 0; i < running.length && list.length < 4; i++) {
                const app = running[i];
                const desk = DesktopEntries.heuristicLookup(app.appId);
                if (desk) {
                    const topTitle = app.toplevels[0]?.title ?? desk.name;
                    list.push({
                        id: app.appId,
                        name: desk.name,
                        subtitle: (topTitle !== desk.name && topTitle.length > 0) ? topTitle : Translation.tr("Active window"),
                        icon: desk.icon,
                        execute: () => {
                            if (app.toplevels.length > 0) app.toplevels[0].activate();
                            else desk.execute();
                            GlobalStates.startMenuOpen = false;
                        }
                    });
                }
            }
            const pinned = Config.options.dock.pinnedApps ?? [];
            for (let i = 0; i < pinned.length && list.length < 4; i++) {
                const id = pinned[i];
                if (!list.some(item => item.id === id)) {
                    const desk = DesktopEntries.heuristicLookup(id);
                    if (desk) {
                        list.push({
                            id: id,
                            name: desk.name,
                            subtitle: Translation.tr("Quick access"),
                            icon: desk.icon,
                            execute: () => {
                                desk.execute();
                                GlobalStates.startMenuOpen = false;
                            }
                        });
                    }
                }
            }
            return list;
        }

        Connections {
            target: GlobalStates
            function onStartMenuOpenChanged() {
                if (GlobalStates.startMenuOpen) {
                    root.searchText = "";
                    searchInput.text = "";
                    root.showAllApps = false;
                    searchInput.forceActiveFocus();
                    kdeCheckProc.running = true;
                    GlobalFocusGrab.addDismissable(root);
                } else {
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

        // Main Dual Panel Layout (Windows 11 Start Menu + Companion Panel)
        Item {
            id: mainContainer
            width: mainRow.implicitWidth
            height: mainRow.implicitHeight
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut + 75
            anchors.horizontalCenter: parent.horizontalCenter

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
                    radius: Appearance.rounding.large + 2
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.18)
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    StyledRectangularShadow {
                        target: startMenuCard
                        visible: GlobalStates.startMenuOpen
                    }

                    // Top Chamfer Highlight
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

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
                                        text: root.searchText
                                        focus: GlobalStates.startMenuOpen
                                        onTextChanged: root.searchText = text
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
                                                if (root.searchText !== "") {
                                                    root.searchText = "";
                                                    searchInput.text = "";
                                                } else {
                                                    GlobalStates.startMenuOpen = false;
                                                }
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (root.searchResults.length > 0) {
                                                    root.searchResults[0].execute();
                                                    GlobalStates.startMenuOpen = false;
                                                }
                                            }
                                        }
                                    }

                                    RippleButton {
                                        visible: root.searchText.length > 0
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                        onClicked: {
                                            root.searchText = "";
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

                        // ---------------- Main Body ----------------
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 20
                            Layout.rightMargin: 20
                            contentHeight: contentColumn.implicitHeight + 16
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: contentColumn
                                width: parent.width
                                spacing: 14

                                // State 1: SEARCH RESULTS
                                Loader {
                                    Layout.fillWidth: true
                                    active: root.searchText.trim() !== ""
                                    visible: active
                                    sourceComponent: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        StyledText {
                                            Layout.leftMargin: 6
                                            text: Translation.tr("Search Results")
                                            font.weight: Font.DemiBold
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer1
                                        }

                                        Repeater {
                                            model: root.searchResults
                                            delegate: RippleButton {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 48
                                                buttonRadius: 8
                                                colBackground: "transparent"
                                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                                onClicked: {
                                                    modelData.execute();
                                                    GlobalStates.startMenuOpen = false;
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 12

                                                    IconImage {
                                                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                        implicitSize: 30
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        StyledText {
                                                            Layout.fillWidth: true
                                                            text: modelData.name
                                                            font.weight: Font.Medium
                                                            font.pixelSize: Appearance.font.pixelSize.normal
                                                            color: Appearance.colors.colOnLayer0
                                                            elide: Text.ElideRight
                                                        }
                                                        StyledText {
                                                            Layout.fillWidth: true
                                                            text: modelData.comment || modelData.id
                                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                                            color: Appearance.colors.colOnLayer1
                                                            elide: Text.ElideRight
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
                                }

                                // State 2: ALL APPS LIST (when "All apps" is active)
                                Loader {
                                    Layout.fillWidth: true
                                    active: root.searchText.trim() === "" && root.showAllApps
                                    visible: active
                                    sourceComponent: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

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

                                        Repeater {
                                            model: AppSearch.list
                                            delegate: RippleButton {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 40
                                                buttonRadius: 6
                                                colBackground: "transparent"
                                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                                onClicked: {
                                                    modelData.execute();
                                                    GlobalStates.startMenuOpen = false;
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    spacing: 10

                                                    IconImage {
                                                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                        implicitSize: 24
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        text: modelData.name
                                                        font.pixelSize: Appearance.font.pixelSize.normal
                                                        color: Appearance.colors.colOnLayer0
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // State 3: DEFAULT (PINNED + RECOMMENDED + CATEGORIES)
                                Loader {
                                    Layout.fillWidth: true
                                    active: root.searchText.trim() === "" && !root.showAllApps
                                    visible: active
                                    sourceComponent: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 14

                                        // --- Pinned Header ---
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 6
                                            Layout.rightMargin: 6

                                            StyledText {
                                                text: Translation.tr("Pinned")
                                                font.weight: Font.DemiBold
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnLayer1
                                            }

                                            Item { Layout.fillWidth: true }

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

                                        // --- Pinned Flow Layout ---
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: root.pinnedList

                                                delegate: RippleButton {
                                                    required property var modelData
                                                    width: 86
                                                    implicitHeight: 76
                                                    buttonRadius: 8
                                                    colBackground: "transparent"
                                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                                    onClicked: {
                                                        modelData.execute();
                                                        GlobalStates.startMenuOpen = false;
                                                    }

                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 6

                                                        Item {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            width: 36
                                                            height: 36

                                                            IconImage {
                                                                anchors.fill: parent
                                                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                                implicitSize: 36
                                                            }
                                                        }

                                                        StyledText {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            Layout.preferredWidth: 80
                                                            text: modelData.name
                                                            font.pixelSize: 11
                                                            color: Appearance.colors.colOnLayer0
                                                            horizontalAlignment: Text.AlignHCenter
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // --- Recommended Section ---
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            StyledText {
                                                Layout.leftMargin: 6
                                                text: Translation.tr("Recommended")
                                                font.weight: Font.DemiBold
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnLayer1
                                            }

                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: 2
                                                columnSpacing: 8
                                                rowSpacing: 4

                                                Repeater {
                                                    model: root.recommendedList
                                                    delegate: RippleButton {
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        implicitHeight: 46
                                                        buttonRadius: 8
                                                        colBackground: "transparent"
                                                        colBackgroundHover: Appearance.colors.colLayer1Hover
                                                        onClicked: {
                                                            modelData.execute();
                                                        }

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 10
                                                            anchors.rightMargin: 10
                                                            spacing: 10

                                                            IconImage {
                                                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                                                implicitSize: 28
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 1

                                                                StyledText {
                                                                    Layout.fillWidth: true
                                                                    text: modelData.name
                                                                    font.weight: Font.Medium
                                                                    font.pixelSize: Appearance.font.pixelSize.small
                                                                    color: Appearance.colors.colOnLayer0
                                                                    elide: Text.ElideRight
                                                                }

                                                                StyledText {
                                                                    Layout.fillWidth: true
                                                                    text: modelData.subtitle
                                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                                    color: Appearance.colors.colOnLayer1
                                                                    elide: Text.ElideRight
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
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
                        }

                        // ---------------- Footer (Profile & Power) ----------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 56
                            color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.4)
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border

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

                                // Power Button
                                RippleButton {
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    buttonRadius: 8
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                    onClicked: {
                                        GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
                                        GlobalStates.startMenuOpen = false;
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "power_settings_new"
                                        iconSize: 20
                                        color: parent.hovered ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                                    }

                                    StyledToolTip { text: Translation.tr("Power / Session Menu") }
                                }
                            }
                        }
                    }
                }

                // ==========================================
                // RIGHT PANEL (Companion / KDE Connect Panel)
                // ==========================================
                Rectangle {
                    id: companionCard
                    implicitWidth: 320
                    implicitHeight: 640
                    radius: Appearance.rounding.large + 2
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.18)
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    StyledRectangularShadow {
                        target: companionCard
                        visible: GlobalStates.startMenuOpen
                    }

                    // Top Subtle Highlight
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        // Phone Status Top Card
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 155

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                // Phone Visual Mockup (Clickable to open KDE Connect)
                                RippleButton {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 44
                                    implicitHeight: 66
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
                                        height: 58
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

                        // Quick Action Buttons
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            spacing: 6

                            // KDE Connect SMS
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["kdeconnect-sms"]);
                                    GlobalStates.startMenuOpen = false;
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 10
                                    MaterialSymbol { text: "sms"; iconSize: 18; color: Appearance.colors.colPrimary }
                                    StyledText { text: Translation.tr("Messages (SMS)"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }

                            // Ring Phone / Find My Phone
                            RippleButton {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                buttonRadius: 8
                                colBackground: Appearance.colors.colLayer1
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: {
                                    Quickshell.execDetached(["bash", "-c", "kdeconnect-cli --ring || notify-send 'KDE Connect' 'No phone reachable'"]);
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 10
                                    MaterialSymbol { text: "ring_volume"; iconSize: 18; color: Appearance.colors.colSecondary }
                                    StyledText { text: Translation.tr("Ring Phone"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
                                }
                            }
                        }

                        // Recent Phone Notifications Header
                        StyledText {
                            Layout.leftMargin: 18
                            Layout.topMargin: 14
                            Layout.bottomMargin: 4
                            text: Translation.tr("Phone Notifications")
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                        }

                        // Recent Phone Notifications List
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.leftMargin: 14
                            Layout.rightMargin: 14
                            contentHeight: notifCol.implicitHeight
                            clip: true

                            ColumnLayout {
                                id: notifCol
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: root.phoneNotifications.length > 0 ? root.phoneNotifications : Notifications.list.filter(n => (n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect")))).slice(0, 4)
                                    delegate: RippleButton {
                                        required property var modelData
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
                                                    text: modelData.title || modelData.summary || modelData.appName || Translation.tr("Phone Alert")
                                                    font.weight: Font.Medium
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Appearance.colors.colOnLayer0
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: modelData.body || modelData.app || Translation.tr("Notification")
                                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                                    color: Appearance.colors.colOnLayer1
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    visible: (root.phoneNotifications.length === 0) && (Notifications.list.filter(n => (n.appName && (n.appName.toLowerCase().includes("kde") || n.appName.toLowerCase().includes("connect")))).length === 0)
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 20
                                    text: root.kdeConnected ? Translation.tr("No phone notifications") : Translation.tr("Connect phone via KDE Connect")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                        }

                        // Bottom Footer: KDE Connect App button
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 56
                            color: ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colLayer1, 0.4)
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border

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
