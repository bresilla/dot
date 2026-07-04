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
    
    // Raw wal colors
    readonly property string color0: wal.adapter.colors["color0"] || "#000000"
    readonly property string color1: wal.adapter.colors["color1"] || "#ffffff"
    readonly property string color236: wal.adapter.colors["color236"] || "#1e1e1e"
    readonly property string color238: wal.adapter.colors["color238"] || "#2a2a2a"
    readonly property string color240: wal.adapter.colors["color240"] || "#303030"
    readonly property string color244: wal.adapter.colors["color244"] || "#555555"
    
    // Design tokens
    readonly property var referenceScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real referenceShortSide: referenceScreen ? Math.min(referenceScreen.width, referenceScreen.height) : 2160
    readonly property real spacing: referenceShortSide * (12 / 2160)
    
    readonly property real cornerRadius: referenceShortSide * (10 / 2160)
    readonly property real iconSize: referenceShortSide * (36 / 2160)
    readonly property real progressLineHeight: referenceShortSide * (10 / 2160)
    readonly property real borderWidth: referenceShortSide * (1 / 2160)
    readonly property real fineInset: referenceShortSide * (2 / 2160)
    readonly property real smallRadius: referenceShortSide * (2 / 2160)
    
    readonly property real fontSizeSmall: referenceShortSide * (18 / 2160)
    readonly property real fontSizeMedium: referenceShortSide * (22 / 2160)
    readonly property real fontSizeLarge: referenceShortSide * (28 / 2160)
    
    readonly property int shortDuration: 200
    readonly property int mediumDuration: 300
    readonly property int longDuration: 400
    
    readonly property int standardEasing: Easing.InOutQuad
    
    // Semantic colors based on wal colors
    readonly property color primary: color1
    readonly property color background: color0
    readonly property color surface: color236
    readonly property color surfaceText: color1
    readonly property color surfaceVariantText: Qt.rgba(
        parseInt(color1?.substring(1, 3) || "ff", 16) / 255,
        parseInt(color1?.substring(3, 5) || "ff", 16) / 255,
        parseInt(color1?.substring(5, 7) || "ff", 16) / 255,
        0.7
    )
    readonly property color surfaceContainer: color238
    readonly property color surfaceContainerHigh: color240
    readonly property color outline: color244
    readonly property color onPrimary: color0
    readonly property color surfaceTint: primary
}
