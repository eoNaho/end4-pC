pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Backwards-compatible shim for the bar's lock indicators.
 * Delegates to the single Keylock poller instead of spawning its own
 * bash process every few hundred milliseconds.
 */
Singleton {
    id: root

    readonly property bool capsLock: Keylock.capsLock
    readonly property bool numLock: Keylock.numLock
}
