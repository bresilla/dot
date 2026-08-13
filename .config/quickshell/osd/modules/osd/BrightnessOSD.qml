import Quickshell
import Quickshell.Io
import QtQuick
import "." as OSD

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    property bool enabled: true
    readonly property string brightCommand: Quickshell.env("HOME") + "/.local/sbin/bright"

    property bool shouldShowOSD: false
    property real brightness: 0.7
    property real lastBrightness: -1
    property bool isInteracting: false
    readonly property string procPrefix: {
        if (currentMonitor && currentMonitor.name) return "brightness-osd-" + currentMonitor.name
        if (modelData && modelData.name) return "brightness-osd-" + modelData.name
        return "brightness-osd-screen-" + String(modelData ? modelData.x : 0) + "-" + String(modelData ? modelData.y : 0)
    }

    function cmdId(suffix) {
        return procPrefix + "-" + suffix
    }

    Timer {
        interval: 750
        running: enabled
        repeat: true
        onTriggered: {
            if (isInteracting) return;

            OSD.Proc.runCommand(cmdId("brightness-check"), [brightCommand, "get"], (output, exitCode) => {
                if (exitCode === 0 && output) {
                    const newBrightness = parseFloat(output.trim()) / 100;
                    if (Math.abs(newBrightness - lastBrightness) > 0.01 || lastBrightness < 0) {
                        brightness = newBrightness;
                        lastBrightness = newBrightness;
                        shouldShowOSD = true;
                        hideTimer.restart();
                    }
                }
            }, 0);
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: {
            if (!isInteracting) shouldShowOSD = false;
        }
    }

    readonly property string brightnessIcon: {
        if (brightness < 0.33) return "󰃞";
        if (brightness < 0.66) return "󰃟";
        return "󰃠";
    }
    readonly property int osdWidth: Math.round(monitorWidth * 0.272)
    readonly property int osdHeight: Math.round(monitorHeight * 0.065)
    readonly property int osdPadding: Math.round(osdHeight * 0.32)
    readonly property int osdGap: Math.round(osdHeight * 0.22)

    PanelWindow {
        id: osdWindow
        screen: modelData
        visible: shouldShowOSD || fadeAnim.running

        anchors {
            left: false
            right: false
            top: false
            bottom: true
        }

        implicitWidth: osdWidth
        implicitHeight: osdHeight

        exclusiveZone: 0
        color: "#00000000"

        margins.bottom: Math.round(monitorHeight * 0.05)

        Item {
            id: osdContent
            anchors.fill: parent
            opacity: shouldShowOSD ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    id: fadeAnim
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: iconCircle
                width: parent.height * 0.6
                height: width
                radius: width / 2
                color: OSD.Theme.color1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.osdPadding
                border.color: OSD.Theme.color0
                border.width: OSD.Theme.borderWidth

                Text {
                    anchors.centerIn: parent
                    text: brightnessIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: parent.width * 0.5
                    color: OSD.Theme.color0
                }
            }

            Rectangle {
                id: progressRect
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: iconCircle.right
                anchors.leftMargin: root.osdGap
                height: parent.height * 0.4
                width: Math.max(0, parent.width - x - root.osdPadding)
                color: OSD.Theme.color1
                radius: OSD.Theme.progressRadius
                border.color: OSD.Theme.color0
                border.width: OSD.Theme.borderWidth

                StyledProgressBar {
                    anchors.centerIn: parent
                    width: parent.width * 0.95
                    height: parent.height * 0.8
                    value: brightness
                    lineHeight: parent.height * 0.8
                    showIndicator: true
                    interactive: true

                    onSeeking: pos => {
                        isInteracting = true;
                        brightness = pos;
                        OSD.Proc.runCommand(cmdId("brightness-set"), [brightCommand, String(Math.round(pos * 100))], () => {}, 50);
                    }

                    onClicked: pos => {
                        brightness = pos;
                        lastBrightness = pos;
                        OSD.Proc.runCommand(cmdId("brightness-set"), [brightCommand, String(Math.round(pos * 100))], () => {}, 0);
                        isInteracting = false;
                        hideTimer.restart();
                    }
                }
            }
        }
    }
}
