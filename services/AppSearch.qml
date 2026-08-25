pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import Quickshell

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
    })
    property var regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]

    // Deduped list to fix double icons
    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .filter((app, index, self) => 
            app && app.id && index === self.findIndex((t) => (
                t && t.id === app.id
            ))
    )
    
    readonly property var preppedNames: list.filter(a => a && a.name).map(a => ({
        name: Fuzzy.prepare(`${a.name} `),
        entry: a
    }))

    readonly property var preppedIcons: list.filter(a => a && a.icon).map(a => ({
        name: Fuzzy.prepare(`${a.icon} `),
        entry: a
    }))

    function fuzzyQuery(search: string): var { // Idk why list<DesktopEntry> doesn't work
        if (!search || typeof search !== "string" || search.trim() === "") return [];
        const cleanSearch = search.trim();

        if (root.sloppySearch) {
            const results = list.filter(obj => obj && obj.name).map(obj => ({
                entry: obj,
                score: Levendist.computeScore(obj.name.toLowerCase(), cleanSearch.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score);
            return results
                .map(item => item.entry)
                .filter(e => e !== null && e !== undefined);
        }

        try {
            const results = Fuzzy.go(cleanSearch, preppedNames, {
                all: true,
                key: "name"
            });
            if (!results) return [];
            return results
                .map(r => (r && r.obj) ? r.obj.entry : null)
                .filter(e => e !== null && e !== undefined);
        } catch (err) {
            console.warn("[AppSearch] fuzzyQuery error:", err);
            return [];
        }
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getUndescoreToKebabAppName(str) {
        if (!str) return "";
        return str.toLowerCase().replace(/_/g, "-");
    }

    function getKebabNormalizedAppName(str) {
        if (!str) return "";
        return str.toLowerCase().replace(/[^a-z0-9]/g, "-");
    }

    property var _iconCache: new Map()

    onListChanged: {
        _iconCache.clear()
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";
        if (root._iconCache.has(str)) return root._iconCache.get(str);

        const result = root._computeGuessIcon(str);
        root._iconCache.set(str, result);
        return result;
    }

    function _computeGuessIcon(str) {
        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.byId(str);
        if (entry) return entry.icon;

        // Normal substitutions
        if (substitutions[str]) return substitutions[str];
        if (substitutions[str.toLowerCase()]) return substitutions[str.toLowerCase()];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        // Icon exists -> return as is
        if (iconExists(str)) return str;

        // Simple guesses
        const lowercased = str.toLowerCase();
        if (iconExists(lowercased)) return lowercased;

        const reverseDomainNameAppName = getReverseDomainNameAppName(str);
        if (iconExists(reverseDomainNameAppName)) return reverseDomainNameAppName;

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return lowercasedDomainNameAppName;

        const kebabNormalizedGuess = getKebabNormalizedAppName(str);
        if (iconExists(kebabNormalizedGuess)) return kebabNormalizedGuess;

        const undescoreToKebabGuess = getUndescoreToKebabAppName(str);
        if (iconExists(undescoreToKebabGuess)) return undescoreToKebabGuess;

        // Search in desktop entries
        try {
            const iconSearchResults = Fuzzy.go(str, preppedIcons, {
                all: true,
                key: "name"
            });
            if (iconSearchResults && iconSearchResults.length > 0 && iconSearchResults[0]?.obj?.entry?.icon) {
                const guess = iconSearchResults[0].obj.entry.icon;
                if (iconExists(guess)) return guess;
            }
        } catch (e) {}

        try {
            const nameSearchResults = root.fuzzyQuery(str);
            if (nameSearchResults && nameSearchResults.length > 0 && nameSearchResults[0]?.icon) {
                const guess = nameSearchResults[0].icon;
                if (iconExists(guess)) return guess;
            }
        } catch (e) {}

        // Quickshell's desktop entry lookup
        const heuristicEntry = DesktopEntries.heuristicLookup(str);
        if (heuristicEntry) return heuristicEntry.icon;

        // Give up
        return "application-x-executable";
    }
}
