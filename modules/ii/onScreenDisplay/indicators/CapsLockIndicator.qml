import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay

OsdStatusIndicator {
    id: root
    name: Translation.tr("Caps Lock")
    statusText: Keylock.capsLock ? Translation.tr("ON") : Translation.tr("OFF")
    icon: Keylock.capsLock ? "lock" : "lock_open_right"
    active: Keylock.capsLock
}
