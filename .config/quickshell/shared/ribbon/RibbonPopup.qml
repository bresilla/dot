import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property bool sideRight
    required property real popupY
    required property int ribbonWidth
    required property int reservedThickness

    property bool expanded: false
    property real expandProgress: expanded ? 1 : 0
    property int popupGap: 24
    property int popupSlide: 46

    readonly property real compactInset: -ribbonWidth
    readonly property real expandedInset: reservedThickness + popupGap
    readonly property real horizontalInset: compactInset + ((expandedInset - compactInset) * expandProgress)

    color: "#00000000"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        left: !root.sideRight
        right: root.sideRight
        top: true
        bottom: false
    }

    margins {
        left: root.sideRight ? 0 : root.horizontalInset
        right: root.sideRight ? root.horizontalInset : 0
        top: Math.round(root.popupY)
    }
}
