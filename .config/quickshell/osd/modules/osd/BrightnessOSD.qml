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
    readonly property string brightCommand: Quickshell.env("HOME") + "/.config/profile/functions/system/bright"

    property bool shouldShowOSD: false
    property real brightness: 0.7
    property real lastBrightness: -1
    property bool isInteracting: false

    Timer {
        interval: 300
        running: enabled
        repeat: true
        onTriggered: {
            if (isInteracting) return;

            OSD.Proc.runCommand("brightness-check", [brightCommand, "get"], (output, exitCode) => {
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

        implicitWidth: monitorHeight * 0.4
        implicitHeight: monitorWidth * 0.05

        exclusiveZone: 0
        color: "#00000000"

        margins.bottom: 40

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
                width: parent.height * 0.6
                height: width
                radius: width / 2
                color: OSD.Theme.color1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 40
                border.color: OSD.Theme.color0
                border.width: 2

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
                anchors.left: parent.left
                anchors.leftMargin: parent.height * 0.9
                height: parent.height * 0.4
                width: parent.width - parent.height * 0.9
                color: OSD.Theme.color1
                radius: 8
                border.color: OSD.Theme.color0
                border.width: 2

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
                        OSD.Proc.runCommand("brightness-set", [brightCommand, String(Math.round(pos * 100))], () => {}, 50);
                    }

                    onClicked: pos => {
                        brightness = pos;
                        lastBrightness = pos;
                        OSD.Proc.runCommand("brightness-set", [brightCommand, String(Math.round(pos * 100))], () => {}, 0);
                        isInteracting = false;
                        hideTimer.restart();
                    }
                }
            }
        }
    }
}
