import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    title: Translation.tr("Countdown")
    minimumWidth: 280
    minimumHeight: 180

    contentItem: CountdownContent {
        radius: root.contentRadius
    }
}
