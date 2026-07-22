import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    required property var modelData

    readonly property real monitorWidth: modelData ? modelData.width : (Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 3840)
    readonly property real monitorHeight: modelData ? modelData.height : (Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 2160)
    readonly property real monitorShortSide: Math.min(monitorWidth, monitorHeight)
    readonly property int thickness: Math.round(monitorWidth * 0.005)
    readonly property int padding: Math.round(monitorShortSide * (6 / 2160))
    readonly property int reservedThickness: thickness + padding
    readonly property int innerRadius: Math.round(monitorShortSide * (24 / 2160))
    readonly property int cornerSize: thickness + innerRadius
    readonly property color borderColor: wal.adapter.colors["color0"] || "#000000"

    FileView {
        id: wal
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            property JsonObject special: JsonObject {
                property string background: "#000000"
                property string foreground: "#ffffff"
            }
            property var colors: ({})
        }
    }

    component BorderWindow: PanelWindow {
        screen: root.modelData
        color: "transparent"
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        margins {
            top: -root.reservedThickness
            bottom: -root.reservedThickness
            left: -root.reservedThickness
            right: -root.reservedThickness
        }
    }

    component Edge: BorderWindow {
        required property string side

        exclusiveZone: 0
        WlrLayershell.namespace: "bresilla-border"

        implicitWidth: root.thickness
        implicitHeight: root.thickness

        anchors.top: side === "top" || side === "left" || side === "right"
        anchors.bottom: side === "bottom" || side === "left" || side === "right"
        anchors.left: side === "left" || side === "top" || side === "bottom"
        anchors.right: side === "right" || side === "top" || side === "bottom"

        Rectangle {
            anchors.fill: parent
            color: root.borderColor
        }
    }

    component Corner: BorderWindow {
        required property string corner

        exclusiveZone: 0
        implicitWidth: root.cornerSize
        implicitHeight: root.cornerSize

        WlrLayershell.namespace: "bresilla-border-corner"

        anchors.top: corner === "topLeft" || corner === "topRight"
        anchors.bottom: corner === "bottomLeft" || corner === "bottomRight"
        anchors.left: corner === "topLeft" || corner === "bottomLeft"
        anchors.right: corner === "topRight" || corner === "bottomRight"

        Canvas {
            id: cornerCanvas

            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            Connections {
                target: root

                function onBorderColorChanged() {
                    cornerCanvas.requestPaint()
                }
            }

            onPaint: {
                const ctx = getContext("2d")
                const s = root.cornerSize
                const r = root.innerRadius
                const centerX = corner === "topLeft" || corner === "bottomLeft" ? s : 0
                const centerY = corner === "topLeft" || corner === "topRight" ? s : 0

                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = root.borderColor
                ctx.fillRect(0, 0, width, height)
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath()
                ctx.arc(centerX, centerY, r, 0, Math.PI * 2)
                ctx.fill()
                ctx.globalCompositeOperation = "source-over"
            }
        }
    }

    component Reserve: PanelWindow {
        required property string side

        screen: root.modelData
        color: "transparent"
        exclusiveZone: root.reservedThickness
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "bresilla-border-reserve"

        implicitWidth: 1
        implicitHeight: 1

        anchors.top: side === "top"
        anchors.bottom: side === "bottom"
        anchors.left: side === "left"
        anchors.right: side === "right"
    }

    Edge {
        side: "top"
    }

    Edge {
        side: "bottom"
    }

    Edge {
        side: "left"
    }

    Edge {
        side: "right"
    }

    Corner {
        corner: "topLeft"
    }

    Corner {
        corner: "topRight"
    }

    Corner {
        corner: "bottomLeft"
    }

    Corner {
        corner: "bottomRight"
    }

    Reserve {
        side: "top"
    }

    Reserve {
        side: "bottom"
    }

    Reserve {
        side: "left"
    }

    Reserve {
        side: "right"
    }
}
