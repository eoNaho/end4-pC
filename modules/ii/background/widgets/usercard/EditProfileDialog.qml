import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PopupWindow {
    id: root

    signal dialogClosed

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitWidth: popupBackground.implicitWidth + root.padding * 2
    implicitHeight: popupBackground.implicitHeight + root.padding * 2

    property string tempDisplayName: Config.options.profile.displayName
    property string tempBio: Config.options.profile.bio
    property string tempAvatarPath: Config.options.profile.avatarPath
    property bool tempShowUptime: Config.options.profile.showUptime
    property bool tempShowWeatherQuip: Config.options.profile.showWeatherQuip

    function open() {
        tempDisplayName = Config.options.profile.displayName;
        tempBio = Config.options.profile.bio;
        tempAvatarPath = Config.options.profile.avatarPicture !== "" ? Config.options.profile.avatarPicture : Config.options.profile.avatarPath;
        tempShowUptime = Config.options.profile.showUptime;
        tempShowWeatherQuip = Config.options.profile.showWeatherQuip;
        root.visible = true;
        GlobalStates.desktopWidgetKeyboardFocus = true;
    }

    function close() {
        root.visible = false;
        GlobalStates.desktopWidgetKeyboardFocus = false;
        root.dialogClosed();
    }

    function save() {
        Config.options.profile.displayName = tempDisplayName;
        Config.options.profile.bio = tempBio;
        Config.options.profile.avatarPath = tempAvatarPath;
        Config.options.profile.avatarPicture = tempAvatarPath;
        Config.options.profile.showUptime = tempShowUptime;
        Config.options.profile.showWeatherQuip = tempShowWeatherQuip;
        root.close();
    }

    Process {
        id: pickImageProc
        command: ["bash", "-c", "zenity --file-selection --title='Escolha seu Avatar' --file-filter='Imagens (*.png *.jpg *.jpeg *.webp) | *.png *.jpg *.jpeg *.webp' 2>/dev/null || kdialog --getopenfilename ~ 'image/png image/jpeg image/webp' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) {
                    root.tempAvatarPath = path;
                }
            }
        }
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root);
    }
    Component.onDestruction: {
        GlobalFocusGrab.removeDismissable(root);
        GlobalStates.desktopWidgetKeyboardFocus = false;
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close();
        }
    }

    StyledRectangularShadow {
        target: popupBackground
        opacity: popupBackground.opacity
    }

    Rectangle {
        id: popupBackground
        anchors.centerIn: parent
        implicitWidth: 340
        implicitHeight: contentCol.implicitHeight + 24
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: contentCol
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            // ─── Header ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "edit"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Edit Profile")
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                }

                MaterialSymbol {
                    text: "close"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Avatar Preview & Alteração ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 54
                    radius: 27
                    color: Appearance.colors.colPrimaryContainer
                    border.width: 2
                    border.color: Appearance.colors.colPrimary
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.tempAvatarPath !== ""
                            ? `file://${root.tempAvatarPath}`
                            : `file:///home/${Quickshell.env("USER") ?? "user"}/.face`
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(108, 108)
                        onStatusChanged: if (status === Image.Error) visible = false
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "account_circle"
                        iconSize: 32
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Profile Picture")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                    }

                    Rectangle {
                        implicitWidth: changePicRow.implicitWidth + 16
                        implicitHeight: 28
                        radius: Appearance.rounding.small
                        color: pickMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1

                        RowLayout {
                            id: changePicRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: "add_photo_alternate"
                                iconSize: 14
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: Translation.tr("Choose image...")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer0
                            }
                        }

                        MouseArea {
                            id: pickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pickImageProc.running = false;
                                pickImageProc.running = true;
                            }
                        }
                    }
                }
            }

            // ─── Campo: Nome de Exibição ───
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Display Name")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: nameField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

                    TextInput {
                        id: nameField
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.tempDisplayName
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        onTextChanged: root.tempDisplayName = text
                    }
                }
            }

            // ─── Campo: Bio / Frase de Status ───
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Custom Bio / Status Message")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: bioField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

                    TextInput {
                        id: bioField
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.tempBio
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        wrapMode: TextInput.Wrap
                        onTextChanged: root.tempBio = text
                    }
                }
            }

            // ─── Opções de Exibição ───
            ConfigSwitch {
                Layout.fillWidth: true
                buttonIcon: "timelapse"
                text: Translation.tr("Show System Uptime")
                checked: root.tempShowUptime
                onCheckedChanged: root.tempShowUptime = checked
            }

            ConfigSwitch {
                Layout.fillWidth: true
                buttonIcon: "partly_cloudy_day"
                text: Translation.tr("Show Weather Quip")
                checked: root.tempShowWeatherQuip
                onCheckedChanged: root.tempShowWeatherQuip = checked
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colLayer0Border
            }

            // ─── Botões de Ação (Salvar / Cancelar) ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: 80
                    implicitHeight: 34
                    radius: Appearance.rounding.small
                    color: cancelMouse.containsMouse ? Appearance.colors.colLayer1 : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr("Cancel")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 34
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colPrimary

                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr("Save")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.save()
                    }
                }
            }
        }
    }
}
