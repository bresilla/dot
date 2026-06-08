import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property bool sideRight
    required property int ribbonWidth

    property real pillWidthFactor: 0.55
    property real trackHeight: 0
    property int pillSpacing: 10

    readonly property real pillWidth: ribbonWidth * pillWidthFactor

    signal wheel(point angleDelta)

    default property alias pills: pillColumn.data

    color: "transparent"
    exclusiveZone: 0
    implicitWidth: root.ribbonWidth

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: !root.sideRight
        right: root.sideRight
    }

    Item {
        anchors.fill: parent

        Column {
            id: pillColumn

            width: root.pillWidth
            height: root.trackHeight
            x: (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.pillSpacing
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.wheel(wheel.angleDelta)
        }
    }
}
