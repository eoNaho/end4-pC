import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true
    bottomContentPadding: 15

    //This was intended to go into the results more deeply but in the end I didn't like it but I left it just in case lol
    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }

            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "neurology"
            shape: MaterialShape.Shape.Ghostish
            title: Translation.tr("AI")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("System prompt")
                text: Config.options.ai.systemPrompt
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.options.ai.systemPrompt = text;
                    });
                }
            }
        }

        ContentSection {
            icon: "cell_tower"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Networking")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("User agent (for services that require it)")
                text: Config.options.networking.userAgent
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.networking.userAgent = text;
                }
            }
        }

        ContentSection {
            icon: "music_cast"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Music Recognition")

            GroupedList {
                ConfigSpinBox {
                    icon: "timer_off"
                    text: Translation.tr("Total duration timeout (s)")
                    value: Config.options.musicRecognition.timeout
                    from: 10
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.musicRecognition.timeout = value;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (s)")
                    value: Config.options.musicRecognition.interval
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.options.musicRecognition.interval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "screen_record"
            shape: MaterialShape.Shape.Flower
            title: Translation.tr("Screen Recording")

            GroupedList {
                ConfigTextArea {
                    id: videoRecordPathField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "video_file"
                    text: Translation.tr("Recording Save Path")
                    value: Config.options.screenRecord.savePath
                    onValueChanged: {
                        videoRecordPathDebounceTimer.restart();
                    }

                    Timer {
                        id: videoRecordPathDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.screenRecord.savePath = videoRecordPathField.value;
                        }
                    }
                }

                ConfigSelectionArray {
                    text: Translation.tr("Audio Source")
                    icon: "volume_up"
                    currentValue: Config.options.screenRecord.audioSource || "desktop"
                    onSelected: newValue => {
                        Config.options.screenRecord.audioSource = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("Muted"), value: "none" },
                        { displayName: Translation.tr("System"), value: "desktop" },
                        { displayName: Translation.tr("Mic"), value: "mic" },
                        { displayName: Translation.tr("Both"), value: "both" }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Framerate")
                    icon: "speed"
                    currentValue: Config.options.screenRecord.fps || 60
                    onSelected: newValue => {
                        Config.options.screenRecord.fps = Number(newValue);
                    }
                    options: [
                        { displayName: "30 FPS", value: 30 },
                        { displayName: "60 FPS", value: 60 },
                        { displayName: "120 FPS", value: 120 }
                    ]
                }

                ConfigComboBox {
                    text: Translation.tr("Encoder / Hardware Acceleration")
                    description: Translation.tr("Video encoding backend and hardware acceleration")
                    buttonIcon: "memory"
                    fieldWidth: 240
                    currentValue: Config.options.screenRecord.encoder || "auto"
                    onSelected: newValue => {
                        Config.options.screenRecord.encoder = newValue;
                    }
                    model: [
                        { displayName: Translation.tr("Auto (GPU / NVENC)"), value: "auto" },
                        { displayName: Translation.tr("NVIDIA NVENC (Hardware)"), value: "nvenc" },
                        { displayName: Translation.tr("VA-API (AMD / Intel)"), value: "vaapi" },
                        { displayName: Translation.tr("CPU (libx264 Software)"), value: "cpu" }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("File Format")
                    icon: "movie"
                    currentValue: Config.options.screenRecord.format || "mp4"
                    onSelected: newValue => {
                        Config.options.screenRecord.format = newValue;
                    }
                    options: [
                        { displayName: "MP4", value: "mp4" },
                        { displayName: "MKV", value: "mkv" },
                        { displayName: "WebM", value: "webm" },
                        { displayName: "GIF", value: "gif" }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Video Quality")
                    icon: "high_quality"
                    currentValue: Config.options.screenRecord.quality || "high"
                    onSelected: newValue => {
                        Config.options.screenRecord.quality = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("Low"), value: "low" },
                        { displayName: Translation.tr("Medium"), value: "medium" },
                        { displayName: Translation.tr("High"), value: "high" },
                        { displayName: Translation.tr("Lossless"), value: "lossless" }
                    ]
                }

                ConfigSelectionArray {
                    text: Translation.tr("Countdown Delay")
                    icon: "timer"
                    currentValue: Config.options.screenRecord.countdown || 0
                    onSelected: newValue => {
                        Config.options.screenRecord.countdown = Number(newValue);
                    }
                    options: [
                        { displayName: Translation.tr("None"), value: 0 },
                        { displayName: "3s", value: 3 },
                        { displayName: "5s", value: 5 }
                    ]
                }

                ConfigSwitch {
                    buttonIcon: "mouse"
                    text: Translation.tr("Record Mouse Cursor")
                    checked: Config.options.screenRecord.recordCursor
                    onCheckedChanged: {
                        Config.options.screenRecord.recordCursor = checked;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "notifications"
                    text: Translation.tr("Interactive Notification on Complete")
                    checked: Config.options.screenRecord.notifyOnComplete
                    onCheckedChanged: {
                        Config.options.screenRecord.notifyOnComplete = checked;
                    }
                }
            }
        }

        ContentSection {
            icon: "file_open"
            shape: MaterialShape.Shape.Slanted
            title: Translation.tr("Screenshot Save Path")

            GroupedList {
                ConfigTextArea {
                    id: screenshotPathField
                    Layout.fillWidth: true
                    fieldWidth: 250
                    buttonIcon: "screenshot_monitor"
                    text: Translation.tr("Screenshot Path (leave empty to just copy)")
                    value: Config.options.screenSnip.savePath
                    onValueChanged: {
                        screenshotPathDebounceTimer.restart();
                    }

                    Timer {
                        id: screenshotPathDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.screenSnip.savePath = screenshotPathField.value;
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "search"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Search")

            GroupedList {
                ConfigSwitch {
                    text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
                    checked: Config.options.search.sloppy
                    onCheckedChanged: {
                        Config.options.search.sloppy = checked;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Prefixes")

                GroupedList {
                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "bolt"
                            fieldWidth: 100
                            text: Translation.tr("Action")
                            value: Config.options.search.prefix.action
                            onValueChanged: {
                                Config.options.search.prefix.action = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "content_paste"
                            fieldWidth: 100
                            text: Translation.tr("Clipboard")
                            value: Config.options.search.prefix.clipboard
                            onValueChanged: {
                                Config.options.search.prefix.clipboard = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "mood"
                            fieldWidth: 100
                            text: Translation.tr("Emojis")
                            value: Config.options.search.prefix.emojis
                            onValueChanged: {
                                Config.options.search.prefix.emojis = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "emoji_symbols"
                            fieldWidth: 100
                            text: Translation.tr("Icons")
                            value: Config.options.search.prefix.symbols
                            onValueChanged: {
                                Config.options.search.prefix.symbols = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "terminal"
                            fieldWidth: 100
                            text: Translation.tr("Shell command")
                            value: Config.options.search.prefix.shellCommand
                            onValueChanged: {
                                Config.options.search.prefix.shellCommand = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            fieldWidth: 100
                            buttonIcon: "travel_explore"
                            text: Translation.tr("Web search")
                            value: Config.options.search.prefix.webSearch
                            onValueChanged: {
                                Config.options.search.prefix.webSearch = value;
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "apps"
                            fieldWidth: 100
                            text: Translation.tr("Apps")
                            value: Config.options.search.prefix.app
                            onValueChanged: {
                                Config.options.search.prefix.app = value;
                            }
                        }
                        ConfigTextArea {
                            Layout.fillWidth: true
                            buttonIcon: "keyboard_command_key"
                            fieldWidth: 100
                            text: Translation.tr("Keybinds")
                            value: Config.options.search.prefix.keybinds
                            onValueChanged: {
                                Config.options.search.prefix.keybinds = value;
                            }
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Web search")

                GroupedList {
                    ConfigTextArea {
                        id: baseUrlField
                        Layout.fillWidth: true
                        fieldWidth: 320
                        buttonIcon: "travel_explore"
                        text: Translation.tr("Base URL")
                        value: Config.options.search.engineBaseUrl
                        onValueChanged: {
                            baseUrlDebounceTimer.restart();
                        }

                        Timer {
                            id: baseUrlDebounceTimer
                            interval: 600
                            repeat: false
                            onTriggered: {
                                Config.options.search.engineBaseUrl = baseUrlField.value;
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "deployed_code_update"
            title: Translation.tr("System updates (Arch only)")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "update"
                    text: Translation.tr("Enable update checks")
                    checked: Config.options.updates.enableCheck
                    onCheckedChanged: {
                        Config.options.updates.enableCheck = checked;
                    }
                }

                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Check interval (mins)")
                    value: Config.options.updates.checkInterval
                    from: 60
                    to: 1440
                    stepSize: 60
                    onValueChanged: {
                        Config.options.updates.checkInterval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "weather_mix"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Weather")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "assistant_navigation"
                    text: Translation.tr("Enable GPS based location")
                    checked: Config.options.bar.weather.enableGPS
                    onCheckedChanged: {
                        Config.options.bar.weather.enableGPS = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "thermometer"
                    text: Translation.tr("Fahrenheit unit")
                    checked: Config.options.bar.weather.useUSCS
                    onCheckedChanged: {
                        Config.options.bar.weather.useUSCS = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (m)")
                    value: Config.options.bar.weather.fetchInterval
                    from: 5
                    to: 50
                    stepSize: 5
                    onValueChanged: {
                        Config.options.bar.weather.fetchInterval = value;
                    }
                }
                ConfigTextArea {
                    id: cityField
                    Layout.fillWidth: true
                    buttonIcon: "location_city"
                    text: Translation.tr("City name")
                    value: Config.options.bar.weather.city
                    onValueChanged: cityDebounceTimer.restart()

                    Timer {
                        id: cityDebounceTimer
                        interval: 1000
                        running: false
                        onTriggered: Config.options.bar.weather.city = cityField.value
                    }
                }
            }
        }

        ContentSection {
            icon: "cloud_sync"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Google Services & Sync")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "login"
                    text: Translation.tr("Connect Google Account")
                    checked: GoogleService.loggedIn
                    onClicked: {
                        GoogleService.login();
                    }
                }

                ConfigSwitch {
                    buttonIcon: "sync"
                    text: Translation.tr("Sync Tasks & Calendar Now")
                    checked: false
                    onClicked: {
                        GoogleService.sync();
                    }
                }
            }
        }

        ContentSection {
            icon: "monitoring"
            shape: MaterialShape.Shape.Ghostish
            title: Translation.tr("AI Usage")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "monitoring"
                    text: Translation.tr("Show AI usage (Claude, Codex, ...)")
                    checked: Config.options.ai.usage.enable
                    onCheckedChanged: {
                        Config.options.ai.usage.enable = checked;
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Providers")
                    visible: Config.options.ai.usage.enable

                    Repeater {
                        model: Object.keys(AiUsage.providerMeta)
                        delegate: ConfigSwitch {
                            required property string modelData
                            buttonIcon: "smart_toy"
                            text: AiUsage.providerMeta[modelData].name
                            checked: Config.options.ai.usage.providers.includes(modelData)
                            onCheckedChanged: {
                                let list = Array.from(Config.options.ai.usage.providers);
                                const has = list.includes(modelData);
                                if (checked && !has) list.push(modelData);
                                else if (!checked && has) list = list.filter(p => p !== modelData);
                                Config.options.ai.usage.providers = list;
                            }
                        }
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.ai.usage.enable
                    icon: "av_timer"
                    text: Translation.tr("Refresh interval (mins)")
                    value: Config.options.ai.usage.fetchInterval
                    from: 1
                    to: 60
                    stepSize: 1
                    onValueChanged: {
                        Config.options.ai.usage.fetchInterval = value;
                    }
                }

                ConfigSwitch {
                    visible: Config.options.ai.usage.enable
                    buttonIcon: "percent"
                    text: Translation.tr("Show percentage label")
                    checked: Config.options.ai.usage.showPercentLabel
                    onCheckedChanged: {
                        Config.options.ai.usage.showPercentLabel = checked;
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Edge Tab (Dock)")
                    visible: Config.options.ai.usage.enable

                    ConfigSwitch {
                        buttonIcon: "dock_to_right"
                        text: Translation.tr("Show as an auto-hiding tab on the screen edge")
                        checked: Config.options.ai.usage.dock.enable
                        onCheckedChanged: {
                            Config.options.ai.usage.dock.enable = checked;
                        }
                    }

                    ConfigSelectionArray {
                        visible: Config.options.ai.usage.dock.enable
                        text: Translation.tr("Edge")
                        icon: "align_horizontal_right"
                        currentValue: Config.options.ai.usage.dock.edge
                        onSelected: newValue => {
                            Config.options.ai.usage.dock.edge = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("Right"), value: "right" },
                            { displayName: Translation.tr("Left"), value: "left" }
                        ]
                    }

                    ConfigSpinBox {
                        visible: Config.options.ai.usage.dock.enable
                        icon: "swap_vert"
                        text: Translation.tr("Vertical position (%)")
                        value: Math.round((Config.options.ai.usage.dock.position ?? 0.5) * 100)
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: {
                            Config.options.ai.usage.dock.position = value / 100;
                        }
                    }

                    ConfigSpinBox {
                        visible: Config.options.ai.usage.dock.enable
                        icon: "swipe_right"
                        text: Translation.tr("Hover reveal width (px)")
                        value: Config.options.ai.usage.dock.hoverRegionWidth
                        from: 1
                        to: 20
                        stepSize: 1
                        onValueChanged: {
                            Config.options.ai.usage.dock.hoverRegionWidth = value;
                        }
                    }
                }
            }
        }

        WorldMap {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
        }
    }
}
