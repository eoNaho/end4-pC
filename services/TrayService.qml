pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options.tray.filterPassive
    property var pinnedConfigList: Array.from(Config.options.tray.pinnedItems || [])
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => (root.pinnedConfigList.includes(i.id) && (!smartTray || i.status !== Status.Passive)))
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => (!root.pinnedConfigList.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

    property bool invertPins: Config.options.tray.invertPinnedItems
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        var result = item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray.showItemId) result += "\n[" + item.id + "]";
        return result;
    }

    function getPins() {
        return Array.from(Config.options?.tray?.pinnedItems || []);
    }

    // Pinning: makes the item appear on the main bar
    function pin(itemId) {
        let pins = root.getPins();
        if (root.invertPins) {
            Config.options.tray.pinnedItems = pins.filter(id => id !== itemId);
        } else {
            if (!pins.includes(itemId)) {
                pins.push(itemId);
                Config.options.tray.pinnedItems = pins;
            }
        }
    }

    // Unpinning: makes the item move to the hidden/overflow dropdown
    function unpin(itemId) {
        let pins = root.getPins();
        if (root.invertPins) {
            if (!pins.includes(itemId)) {
                pins.push(itemId);
                Config.options.tray.pinnedItems = pins;
            }
        } else {
            Config.options.tray.pinnedItems = pins.filter(id => id !== itemId);
        }
    }

    function isPinned(itemId) {
        for (var i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i].id === itemId)
                return true;
        }
        return false;
    }

    function togglePin(itemId) {
        if (root.isPinned(itemId)) {
            root.unpin(itemId);
        } else {
            root.pin(itemId);
        }
    }

}
