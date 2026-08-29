import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

Image {
    id: root
    required property var fileModelData
    asynchronous: true
    fillMode: Image.PreserveAspectFit

    readonly property string extension: (fileModelData?.fileName ?? "").split('.').pop().toLowerCase()
    readonly property bool isKnownImage: ["png", "jpg", "jpeg", "webp", "svg", "avif", "bmp", "gif"].includes(extension)
    readonly property bool isKnownVideo: ["mp4", "mkv", "webm", "avi", "mov"].includes(extension)
    readonly property bool isKnownAudio: ["mp3", "flac", "wav", "ogg", "m4a", "opus"].includes(extension)
    readonly property bool isKnownDoc: ["pdf", "txt", "md", "doc", "docx", "xls", "xlsx"].includes(extension)
    readonly property bool isKnownArchive: ["zip", "tar", "gz", "bz2", "xz", "7z", "rar"].includes(extension)
    readonly property bool isKnownCode: ["js", "qml", "py", "rs", "cpp", "c", "h", "sh", "json", "html", "css"].includes(extension)

    source: {
        if (!fileModelData) return Quickshell.iconPath("application-x-zerosize", "text-x-generic");
        if (fileModelData.fileIsDir) {
            const iconName = XdgDirs.pathToIcon[fileModelData.filePath];
            return Quickshell.iconPath(iconName ?? "folder", "folder");
        }
        if (isKnownImage) return fileModelData.fileUrl;
        if (isKnownVideo) return Quickshell.iconPath("video-x-generic", "video");
        if (isKnownAudio) return Quickshell.iconPath("audio-x-generic", "audio");
        if (isKnownDoc) return Quickshell.iconPath("text-x-generic", "document");
        if (isKnownArchive) return Quickshell.iconPath("package-x-generic", "archive");
        if (isKnownCode) return Quickshell.iconPath("text-x-script", "application-x-executable");
        return Quickshell.iconPath("application-x-zerosize", "text-x-generic");
    }

    // Recalcula o source assim que os paths do xdg-user-dir chegarem
    // (eles resolvem de forma assíncrona, podem terminar depois do primeiro paint)
    Connections {
        target: XdgDirs
        function onPathToIconChanged() {
            if (fileModelData?.fileIsDir) {
                const iconName = XdgDirs.pathToIcon[fileModelData.filePath];
                if (iconName)
                    root.source = Quickshell.iconPath(iconName, "folder");
            }
        }
    }

    onStatusChanged: {
        if (status === Image.Error && source != Quickshell.iconPath("folder"))
            source = Quickshell.iconPath("folder");
    }

    Process {
        running: !fileModelData.fileIsDir && !isKnownImage && !isKnownVideo && !isKnownAudio && !isKnownDoc && !isKnownArchive && !isKnownCode
        command: ["file", "--mime", "-b", fileModelData.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.split(";")[0].replace("/", "-");
                root.source = Images.validImageTypes.some(t => mime === `image-${t}`) ? fileModelData.fileUrl : Quickshell.iconPath(mime, "image-missing");
            }
        }
    }
}
