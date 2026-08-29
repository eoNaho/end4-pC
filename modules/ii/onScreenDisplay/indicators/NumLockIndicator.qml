import qs.services
import QtQuick
import qs.modules.ii.onScreenDisplay

OsdStatusIndicator {
    id: root
    name: Translation.tr("Num Lock")
    statusText: Keylock.numLock ? Translation.tr("ON") : Translation.tr("OFF")
    icon: Keylock.numLock ? "pin" : "dialpad"
    active: Keylock.numLock
}
