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

    property bool shouldShowOSD: false
    property real battery: 1.0
    property bool isCharging: false
    readonly property real threshold: 0.15

    Timer {
        interval: 10000
        running: enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            OSD.Proc.runCommand("battery-check", ["bash", "-c",
                "cat /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status"
            ], (output, exitCode) => {
                if (exitCode === 0 && output) {
                    const lines = output.trim().split("\n");
                    if (lines.length >= 2) {
                        battery = parseInt(lines[0]) / 100;
                        isCharging = lines[1].trim() === "Charging";
                        shouldShowOSD = battery < threshold && !isCharging;
                    }
                }
            }, 0);
        }
    }

    readonly property string batteryIcon: "\u{f0083}"
    readonly property color warningColor: "#d32f2f"

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

        implicitWidth: monitorWidth * 0.05
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

            Item {
                id: flashLayer
                anchors.fill: parent

                SequentialAnimation on opacity {
                    running: shouldShowOSD
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                }

                Rectangle {
                    width: parent.height * 0.8
                    height: width
                    radius: width / 2
                    color: warningColor
                    anchors.centerIn: parent
                    border.color: OSD.Theme.color0
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: batteryIcon
                        font.family: "IosevkaTerm Nerd Font Mono"
                        font.pixelSize: parent.width * 0.5
                        color: "#ffffff"
                    }
                }
            }
        }
    }
}
