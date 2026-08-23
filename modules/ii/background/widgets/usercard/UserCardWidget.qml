import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "userCard"
    hoverEnabled: true

    readonly property real snapWidth1: 132
    readonly property real snapWidth2: 276
    readonly property real snapWidth3: 276
    readonly property real snapWidth4: 420

    readonly property real snapHeight1: 120
    readonly property real snapHeight2: 120
    readonly property real snapHeight3: 252
    readonly property real snapHeight4: 252

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"
    property string cardStyle: root.configEntry.style ?? "glass"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return snapWidth1
            case "1x2": return snapWidth2
            case "2x3": return snapWidth4
            default:    return snapWidth3
        }
    }
    property real widgetHeight: {
        switch (root.sizeMode) {
            case "1x1": return snapHeight1
            case "1x2": return snapHeight2
            case "2x3": return snapHeight4
            default:    return snapHeight3
        }
    }

    readonly property string avatarSource: {
        if (Config.options.profile.avatarPicture && Config.options.profile.avatarPicture !== "") {
            let p = Config.options.profile.avatarPicture;
            return p.startsWith("/") ? ("file://" + p) : p;
        }
        if (Config.options.profile.avatarPath && Config.options.profile.avatarPath !== "") {
            let p = Config.options.profile.avatarPath;
            return p.startsWith("/") ? ("file://" + p) : p;
        }
        return "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face";
    }

    property int avatarSize: 64
    property string hostname: SystemInfo.hostname
    property string username: (Config.options.profile.displayName && Config.options.profile.displayName !== "") ? Config.options.profile.displayName : SystemInfo.username
    property string userDisplay: username.length > 14 ? username : (username + "@" + hostname)
    property string userBio: Config.options.profile.bio ?? ""
    property var currentQuip: weatherQuip()

    function weatherQuip() {
        const desc = (Weather.data?.description ?? "").toLowerCase();
        if (desc.includes("rain"))
            return { text: Translation.tr("Raining, grab a coffee"), icon: "coffee" };
        if (desc.includes("clear") || desc.includes("sun"))
            return { text: Translation.tr("Good day to touch grass"), icon: "eco" };
        if (desc.includes("cloud"))
            return { text: Translation.tr("A bit cloudy today"), icon: "cloud" };
        if (desc.includes("snow"))
            return { text: Translation.tr("Snowing outside"), icon: "ac_unit" };
        return { text: Weather.data?.description ?? Translation.tr("Have a productive day!"), icon: "auto_awesome" };
    }

    function greetingFor(hour) {
        if (hour < 12) return Translation.tr("Good Morning")
        if (hour < 18) return Translation.tr("Good Afternoon")
        return Translation.tr("Good Evening")
    }

    readonly property string greetingText: greetingFor(DateTime.hour24)
    readonly property string todayString: DateTime.clock.date.toLocaleDateString(Qt.locale(), "dddd, d MMM")

    implicitWidth: root.widgetWidth
    implicitHeight: root.widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // ─── Componente de Fundo Dinâmico (Frosted Glass vs Flat Material) ───
    component CardBackground: Item {
        id: cardBg
        anchors.fill: parent
        property real cardRadius: Appearance.rounding?.verylarge ?? 30
        property color solidColor: Appearance.colors.colPrimaryContainer

        StyledDropShadow { target: cardBg }

        // Fundo Flat / Sólido
        Rectangle {
            anchors.fill: parent
            radius: cardBg.cardRadius
            color: cardBg.solidColor
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            visible: root.cardStyle === "flat" || root.cardStyle === "material"
        }

        // Fundo Frosted Glass (Vidro Fosco Real)
        Item {
            anchors.fill: parent
            visible: root.cardStyle === "glass"

            Item {
                id: wallpaperSource
                anchors.fill: parent
                visible: false

                Image {
                    anchors.fill: parent
                    source: {
                        if (Config.options.background.widgets.userCard.customBackground && Config.options.background.widgets.userCard.customBackground !== "") {
                            let p = Config.options.background.widgets.userCard.customBackground;
                            return p.startsWith("/") ? ("file://" + p) : p;
                        }
                        return "file://" + (GlobalStates.screenLocked && Config.options.background.lockWall !== ""
                            ? Config.options.background.lockWall
                            : Config.options.background.wallpaperPath);
                    }
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            FastBlur {
                id: blurSurface
                anchors.fill: parent
                source: wallpaperSource
                radius: Config.options.background.widgets.userCard.blurRadius ?? 18
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: blurSurface.width
                        height: blurSurface.height
                        radius: cardBg.cardRadius
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: cardBg.cardRadius
                color: Appearance.colors.colPrimaryContainer
                opacity: Config.options.background.widgets.userCard.backgroundOpacity ?? 0.50
            }

            Rectangle {
                anchors.fill: parent
                radius: cardBg.cardRadius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.20)
            }
        }
    }

    // ─── Componente de Avatar 100% Recortado em Círculo com OpacityMask ───
    component RoundAvatar: Item {
        id: avatarComp
        property real avatarRadius: width / 2
        property real borderWidth: 0
        property color borderColor: "transparent"
        property color bgColor: Appearance.colors.colLayer0

        implicitWidth: 64
        implicitHeight: 64
        Layout.preferredWidth: width
        Layout.preferredHeight: height

        Rectangle {
            id: bgCircle
            anchors.fill: parent
            radius: avatarComp.avatarRadius
            color: avatarComp.bgColor

            MaterialSymbol {
                anchors.centerIn: parent
                text: "account_circle"
                iconSize: Math.min(parent.width * 0.75, 48)
                color: Appearance.colors.colOnPrimaryContainer
                visible: avatarImg.status !== Image.Ready
            }
        }

        Item {
            id: maskContainer
            anchors.fill: parent
            anchors.margins: avatarComp.borderWidth
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: Math.max(0, avatarComp.avatarRadius - avatarComp.borderWidth)
            }
        }

        Image {
            id: avatarImg
            anchors.fill: parent
            anchors.margins: avatarComp.borderWidth
            source: root.avatarSource
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: maskContainer
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: avatarComp.avatarRadius
            color: "transparent"
            border.width: avatarComp.borderWidth
            border.color: avatarComp.borderColor
            visible: avatarComp.borderWidth > 0
            z: 3
        }
    }

    function openEditDialog() {
        if (editLoader.active && editLoader.item) {
            editLoader.item.close();
        } else {
            editLoader.open();
        }
    }

    function cycleSize() {
        if (root.sizeMode === "1x1") root.sizeMode = "1x2"
        else if (root.sizeMode === "1x2") root.sizeMode = "2x2"
        else if (root.sizeMode === "2x2") root.sizeMode = "2x3"
        else root.sizeMode = "1x1"
        root.configEntry.sizeMode = root.sizeMode
    }

    Item {
        id: cardContainer
        anchors.fill: parent

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                if (root.sizeMode === "2x3") return twoByThreeContent
                return twoByTwoContent
            }
        }

        // ══════════════════════════════════════════
        // ─── 1x1 (Avatar Circular Compacto) ───
        // ══════════════════════════════════════════
        Component {
            id: oneByOneContent
            Item {
                id: avatarSingleWrap
                anchors.fill: parent

                CardBackground {
                    cardRadius: Appearance.rounding?.verylarge ?? 30
                }

                Item {
                    anchors.fill: parent

                    RoundAvatar {
                        anchors.fill: parent
                        avatarRadius: (Appearance.rounding?.verylarge ?? 30)
                    }

                    // Botão discreto para alterar tamanho / editar
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 24
                        height: 24
                        radius: 12
                        color: Appearance.colors.colPrimary
                        opacity: avatarSingleMouse.containsMouse ? 1 : 0.7
                        z: 5

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "aspect_ratio"
                            iconSize: 14
                            color: Appearance.colors.colOnPrimary
                        }
                    }

                    MouseArea {
                        id: avatarSingleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openEditDialog()
                        onDoubleClicked: root.cycleSize()
                    }
                }
            }
        }

        // ══════════════════════════════════════════
        // ─── 1x2 (Banner Compacto Horizontal) ───
        // ══════════════════════════════════════════
        Component {
            id: oneByTwoContent
            Item {
                anchors.fill: parent

                CardBackground {
                    cardRadius: Appearance.rounding?.verylarge ?? 30
                }

                RowLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 12

                    RoundAvatar {
                        width: parent.height
                        height: parent.height
                        Layout.preferredWidth: parent.height
                        Layout.preferredHeight: parent.height
                        avatarRadius: (Appearance.rounding?.verylarge ?? 30) - 6

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openEditDialog()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: root.username
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }

                            MaterialSymbol {
                                text: "edit"
                                iconSize: 15
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: editWideMouse.containsMouse ? 1.0 : 0.6
                                MouseArea {
                                    id: editWideMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEditDialog()
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.userBio.length > 0 ? root.userBio : root.greetingText
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.85
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: root.configEntry.showUptime ?? true
                            Layout.fillWidth: true
                            text: "Up • " + DateTime.uptime
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════
        // ─── 2x2 (Card Completo de Perfil) ───
        // ══════════════════════════════════════════
        Component {
            id: twoByTwoContent
            Item {
                implicitWidth: root.snapWidth3
                implicitHeight: root.snapHeight3

                CardBackground {
                    cardRadius: Appearance.rounding?.verylarge ?? 30
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 10

                    // Top: Avatar + Nome + Uptime
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RoundAvatar {
                            width: root.avatarSize
                            height: root.avatarSize
                            Layout.preferredWidth: root.avatarSize
                            Layout.preferredHeight: root.avatarSize
                            avatarRadius: root.avatarSize / 2
                            borderWidth: 2
                            borderColor: Appearance.colors.colPrimary

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEditDialog()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: root.username
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: "@" + root.hostname
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                                elide: Text.ElideRight
                            }

                            StyledText {
                                visible: root.configEntry.showUptime ?? true
                                text: "Up • " + DateTime.uptime
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colPrimary
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Divisor
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.25
                    }

                    // Bio ou Frase do Clima
                    RowLayout {
                        visible: root.configEntry.showQuip ?? true
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            iconSize: Appearance.font.pixelSize.normal
                            text: root.userBio.length > 0 ? "format_quote" : root.currentQuip.icon
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.85
                        }

                        StyledText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.85
                            text: root.userBio.length > 0 ? root.userBio : root.currentQuip.text
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Botões de Ação Rápida
                    RowLayout {
                        visible: root.configEntry.showActions ?? true
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colOnPrimaryContainer

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    iconSize: Appearance.font.pixelSize.small
                                    text: "lock"
                                    color: Appearance.colors.colPrimaryContainer
                                }
                                StyledText {
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colPrimaryContainer
                                    text: GlobalStates.screenLocked ? Translation.tr("Locked") : Translation.tr("Lock")
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.screenLocked = true
                            }
                        }

                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: editBtnMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent"
                            border.width: 1
                            border.color: Appearance.colors.colOnPrimaryContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 16
                                text: "edit"
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                id: editBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEditDialog()
                            }
                        }

                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: "transparent"
                            border.width: 1
                            border.color: Appearance.colors.colOnPrimaryContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 16
                                text: "settings"
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.settingsOpen = true
                            }
                        }

                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: 18
                            color: "transparent"
                            border.width: 1
                            border.color: Appearance.colors.colOnPrimaryContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: 16
                                text: "power_settings_new"
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: GlobalStates.sessionOpen = true
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════
        // ─── 2x3 (Card Panorâmico Estendido) ───
        // ══════════════════════════════════════════
        Component {
            id: twoByThreeContent
            Item {
                anchors.fill: parent

                CardBackground {
                    cardRadius: Appearance.rounding?.verylarge ?? 30
                }

                RowLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 16

                    // Coluna 1: Avatar Grande e Identidade
                    ColumnLayout {
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        spacing: 8

                        RoundAvatar {
                            Layout.alignment: Qt.AlignHCenter
                            width: 80
                            height: 80
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 80
                            avatarRadius: 40
                            borderWidth: 3
                            borderColor: Appearance.colors.colPrimary

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openEditDialog()
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.username
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "@" + root.hostname
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        color: Appearance.colors.colOutlineVariant
                        opacity: 0.4
                    }

                    // Coluna 2: Bio, Estatísticas e Ações
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: root.userBio.length > 0 ? ("“" + root.userBio + "”") : root.greetingText
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.italic: root.userBio.length > 0
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.9
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }

                        // Stats do Sistema
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                spacing: 1
                                StyledText {
                                    text: Translation.tr("Uptime")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: DateTime.uptime
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                spacing: 1
                                StyledText {
                                    text: Translation.tr("Distro")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                                StyledText {
                                    text: SystemInfo.distroName
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnPrimaryContainer
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }
                            }
                        }

                        // Ações Rápidas
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colOnPrimaryContainer

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        iconSize: 14
                                        text: "lock"
                                        color: Appearance.colors.colPrimaryContainer
                                    }
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colPrimaryContainer
                                        text: Translation.tr("Lock")
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.screenLocked = true
                                }
                            }

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "edit"
                                    color: Appearance.colors.colPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openEditDialog()
                                }
                            }

                            Rectangle {
                                implicitWidth: 34
                                implicitHeight: 34
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer2

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: "settings"
                                    color: Appearance.colors.colPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.settingsOpen = true
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════
        // ─── Resize Handler ───
        // ══════════════════════════════════════════
        ResizeHandler {
            anchorItem: cardContainer
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            onResized: (newWidth) => {
                if (newWidth < 190) {
                    root.sizeMode = "1x1";
                } else if (newWidth < 340) {
                    root.sizeMode = "1x2";
                } else if (newWidth < 400) {
                    root.sizeMode = "2x2";
                } else {
                    root.sizeMode = "2x3";
                }
            }
            onResizeFinished: {
                root.configEntry.sizeMode = root.sizeMode;
            }
        }
    }

    Loader {
        id: editLoader
        function open() {
            editLoader.active = true;
        }
        active: false
        sourceComponent: EditProfileDialog {
            Component.onCompleted: this.open()
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Edges.Bottom
                edges: Edges.Top
            }
            onDialogClosed: {
                editLoader.active = false;
            }
        }
    }
}