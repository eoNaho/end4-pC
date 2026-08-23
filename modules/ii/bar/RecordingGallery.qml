import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: 32
    implicitHeight: 32

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (galleryLoader.active && galleryLoader.item) {
                galleryLoader.item.close();
            } else {
                galleryLoader.open();
            }
        }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: "photo_library"
        iconSize: Appearance.font.pixelSize.larger
        color: (galleryLoader.active || mouseArea.containsMouse) ? Appearance.colors.colPrimary : (root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1)
    }

    PopupToolTip {
        id: tooltip
        text: Translation.tr("Captures Gallery · View and copy recent screenshots and recordings")
        extraVisibleCondition: mouseArea.containsMouse && !galleryLoader.active
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

    Loader {
        id: galleryLoader
        function open() {
            galleryLoader.active = true;
        }
        active: false
        sourceComponent: RecordingGalleryMenu {
            Component.onCompleted: this.open()
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                galleryLoader.active = false;
            }
        }
    }
}
