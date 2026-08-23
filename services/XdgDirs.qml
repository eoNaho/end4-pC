pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // path absoluto -> nome do ícone
    property var pathToIcon: ({})
    property bool ready: false

    readonly property var iconFor: ({
        DESKTOP: "folder-desktop",
        DOWNLOAD: "folder-download",
        TEMPLATES: "folder-templates",
        PUBLICSHARE: "folder-publicshare",
        DOCUMENTS: "folder-documents",
        MUSIC: "folder-music",
        PICTURES: "folder-pictures",
        VIDEOS: "folder-videos"
    })

    function registerPath(key, path) {
        const p = path.trim();
        if (p.length === 0)
            return;
        const map = Object.assign({}, pathToIcon);
        map[p] = iconFor[key];
        pathToIcon = map; // reassign pra disparar binding
    }

    // Um Process explícito por chave — mais confiável que criar
    // Process dinamicamente num loop.
    Process {
        id: pDesktop
        command: ["xdg-user-dir", "DESKTOP"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("DESKTOP", text)
        }
    }
    Process {
        id: pDownload
        command: ["xdg-user-dir", "DOWNLOAD"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("DOWNLOAD", text)
        }
    }
    Process {
        id: pTemplates
        command: ["xdg-user-dir", "TEMPLATES"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("TEMPLATES", text)
        }
    }
    Process {
        id: pPublicshare
        command: ["xdg-user-dir", "PUBLICSHARE"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("PUBLICSHARE", text)
        }
    }
    Process {
        id: pDocuments
        command: ["xdg-user-dir", "DOCUMENTS"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("DOCUMENTS", text)
        }
    }
    Process {
        id: pMusic
        command: ["xdg-user-dir", "MUSIC"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("MUSIC", text)
        }
    }
    Process {
        id: pPictures
        command: ["xdg-user-dir", "PICTURES"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("PICTURES", text)
        }
    }
    Process {
        id: pVideos
        command: ["xdg-user-dir", "VIDEOS"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.registerPath("VIDEOS", text)
        }
    }

    Component.onCompleted: root.ready = true
}
