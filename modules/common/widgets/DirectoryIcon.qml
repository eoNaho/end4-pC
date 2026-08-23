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

    source: {
        if (!fileModelData || !fileModelData.fileIsDir)
            return Quickshell.iconPath("application-x-zerosize", "text-x-generic");

        const iconName = XdgDirs.pathToIcon[fileModelData.filePath];
        return Quickshell.iconPath(iconName ?? "folder", "folder");
    }

    // Recalcula o source assim que os paths do xdg-user-dir chegarem
    // (eles resolvem de forma assíncrona, podem terminar depois do primeiro paint)
    Connections {
        target: XdgDirs
        function onPathToIconChanged() {
            const iconName = XdgDirs.pathToIcon[fileModelData.filePath];
            if (iconName)
                root.source = Quickshell.iconPath(iconName, "folder");
        }
    }

    onStatusChanged: {
        if (status === Image.Error && source != Quickshell.iconPath("folder"))
            source = Quickshell.iconPath("folder");
    }

    Process {
        running: !fileModelData.fileIsDir
        command: ["file", "--mime", "-b", fileModelData.filePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.split(";")[0].replace("/", "-");
                root.source = Images.validImageTypes.some(t => mime === `image-${t}`) ? fileModelData.fileUrl : Quickshell.iconPath(mime, "image-missing");
            }
        }
    }
}
