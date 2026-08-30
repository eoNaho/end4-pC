pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * XDG Recent Files manager.
 * Reads and parses ~/.local/share/recently-used.xbel to provide recent files for Windows 11 Start Menu.
 */
Singleton {
    id: root

    property string filePath: FileUtils.trimFileProtocol("file://" + Quickshell.env("HOME") + "/.local/share/recently-used.xbel")
    property var list: []

    function reload() {
        recentFileView.reload();
    }

    function formatRelativeTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        const now = new Date();
        const diffMs = now.getTime() - date.getTime();
        const diffSec = Math.floor(diffMs / 1000);
        const diffMin = Math.floor(diffSec / 60);

        if (diffSec < 60) return Translation.tr("Just now");
        if (diffMin < 60) return Translation.tr("About %1 min ago").arg(diffMin);
        
        const hours = date.getHours().toString().padStart(2, "0");
        const minutes = date.getMinutes().toString().padStart(2, "0");
        
        // Same day
        if (now.toDateString() === date.toDateString()) {
            return Translation.tr("Today at %1:%2").arg(hours).arg(minutes);
        }
        
        // Yesterday
        const yesterday = new Date(now);
        yesterday.setDate(yesterday.getDate() - 1);
        if (yesterday.toDateString() === date.toDateString()) {
            return Translation.tr("Yesterday at %1:%2").arg(hours).arg(minutes);
        }

        const day = date.getDate().toString().padStart(2, "0");
        const month = (date.getMonth() + 1).toString().padStart(2, "0");
        return `${day}/${month}`;
    }

    function guessFileIcon(filename, mime) {
        const lowerName = (filename || "").toLowerCase();
        const lowerMime = (mime || "").toLowerCase();

        if (lowerMime.startsWith("image/") || /\.(png|jpg|jpeg|webp|gif|svg|bmp|ico)$/.test(lowerName)) return "image-x-generic";
        if (lowerMime.startsWith("video/") || /\.(mp4|mkv|webm|avi|mov|flv|wmv)$/.test(lowerName)) return "video-x-generic";
        if (lowerMime.startsWith("audio/") || /\.(mp3|wav|flac|ogg|m4a|aac|opus)$/.test(lowerName)) return "audio-x-generic";
        if (lowerMime.includes("pdf") || lowerName.endsWith(".pdf")) return "application-pdf";
        if (lowerMime.includes("zip") || lowerMime.includes("tar") || /\.(zip|tar|gz|xz|7z|rar|bz2)$/.test(lowerName)) return "package-x-generic";
        if (lowerMime.includes("document") || lowerMime.includes("word") || /\.(doc|docx|odt|rtf)$/.test(lowerName)) return "x-office-document";
        if (lowerMime.includes("spreadsheet") || lowerMime.includes("excel") || /\.(xls|xlsx|ods|csv)$/.test(lowerName)) return "x-office-spreadsheet";
        if (lowerMime.includes("presentation") || lowerMime.includes("powerpoint") || /\.(ppt|pptx|odp)$/.test(lowerName)) return "x-office-presentation";
        if (/\.(qml|js|ts|py|c|cpp|h|json|md|txt|sh|html|css|rs|go|lua|xml|yaml|yml)$/.test(lowerName)) return "text-x-generic";
        
        return "text-x-generic";
    }

    function parseXbel(text) {
        if (!text || text.trim() === "") return [];
        const regex = /<bookmark\s+([^>]+)>([\s\S]*?)<\/bookmark>/g;
        let matches = [];
        let match;
        while ((match = regex.exec(text)) !== null) {
            matches.push({ attr: match[1], body: match[2] });
        }

        const items = [];
        const seenPaths = new Set();

        // Process in reverse (most recent first)
        for (let i = matches.length - 1; i >= 0 && items.length < 20; i--) {
            const m = matches[i];
            const hrefMatch = m.attr.match(/href=["']([^"']+)["']/);
            if (!hrefMatch) continue;

            const rawHref = hrefMatch[1];
            if (!rawHref.startsWith("file://")) continue;

            let path = "";
            try {
                path = decodeURIComponent(rawHref.slice(7));
            } catch (_) {
                path = rawHref.slice(7);
            }

            if (!path || seenPaths.has(path)) continue;
            seenPaths.add(path);

            const filename = path.split("/").pop();
            if (!filename) continue;

            const modMatch = m.attr.match(/modified=["']([^"']+)["']/) || m.attr.match(/added=["']([^"']+)["']/);
            const modDate = modMatch ? new Date(modMatch[1]) : new Date();

            const mimeMatch = m.body.match(/mime-type\s+type=["']([^"']+)["']/);
            const mime = mimeMatch ? mimeMatch[1] : "";

            const appMatch = m.body.match(/application\s+name=["']([^"']+)["']/);
            const appName = appMatch ? appMatch[1] : "";

            const parentDir = path.substring(0, path.lastIndexOf("/")) || "";
            const home = Quickshell.env("HOME") || "";
            const displayDir = (home && parentDir.startsWith(home)) ? "~" + parentDir.slice(home.length) : parentDir;

            items.push({
                name: filename,
                path: path,
                displayDir: displayDir,
                mime: mime,
                appName: appName,
                icon: guessFileIcon(filename, mime),
                modified: modDate,
                relativeTime: formatRelativeTime(modDate),
                execute: () => {
                    Quickshell.execDetached(["xdg-open", path]);
                }
            });
        }

        return items;
    }

    Component.onCompleted: {
        recentFileView.reload();
    }

    FileView {
        id: recentFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            try {
                const content = recentFileView.text();
                root.list = root.parseXbel(content);
            } catch (e) {
                console.warn("[RecentFiles] Parse error:", e);
            }
        }
        onLoadFailed: (error) => {
            console.log("[RecentFiles] Note: recently-used.xbel not loaded: " + error);
        }
    }
}
