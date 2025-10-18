pragma Singleton
import QtQuick

QtObject {
    id: root
    
    readonly property int spacing: 12
    
    readonly property int cornerRadius: 10
    readonly property int iconSize: 36
    
    readonly property int fontSizeSmall: 18
    readonly property int fontSizeMedium: 22
    readonly property int fontSizeLarge: 28
    
    readonly property int shortDuration: 200
    readonly property int mediumDuration: 300
    readonly property int longDuration: 400
    
    readonly property int standardEasing: Easing.InOutQuad
    
    readonly property color primary: WalColors.color1
    readonly property color background: WalColors.color0
    readonly property color surface: WalColors.color236
    readonly property color surfaceText: WalColors.color1
    readonly property color surfaceVariantText: Qt.rgba(
        parseInt(WalColors.color1?.substring(1, 3) || "ff", 16) / 255,
        parseInt(WalColors.color1?.substring(3, 5) || "ff", 16) / 255,
        parseInt(WalColors.color1?.substring(5, 7) || "ff", 16) / 255,
        0.7
    )
    readonly property color surfaceContainer: WalColors.color238
    readonly property color surfaceContainerHigh: WalColors.color240
    readonly property color outline: WalColors.color244
    readonly property color onPrimary: WalColors.color0
    readonly property color surfaceTint: primary
}
