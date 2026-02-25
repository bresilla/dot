pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var wal: FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property JsonObject special: JsonObject {
                property string background: "#000000"
                property string foreground: "#ffffff"
            }
            property var colors: ({})
        }
    }

    readonly property string color0: wal.adapter.colors["color0"] || "#000000"
    readonly property string color1: wal.adapter.colors["color1"] || "#ffffff"
    readonly property string color236: wal.adapter.colors["color236"] || "#1e1e1e"
    readonly property string color238: wal.adapter.colors["color238"] || "#2a2a2a"
    readonly property string color240: wal.adapter.colors["color240"] || "#303030"
    readonly property string color244: wal.adapter.colors["color244"] || "#555555"

    // Semantic colors (typed so .r/.g/.b work in Qt.rgba)
    readonly property color primary: color1
    readonly property color background: color0
    readonly property color surface: color236
    readonly property color surfaceContainer: color238
    readonly property color surfaceContainerHigh: color240
    readonly property color outline: color244

    readonly property int cornerRadius: 10
}
