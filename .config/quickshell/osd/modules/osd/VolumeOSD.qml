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
    property real volume: 0.5
    property real lastVolume: -1
    property bool isMuted: false
    property bool isHeadphone: false
    property bool isInteracting: false
    readonly property string procPrefix: {
        if (currentMonitor && currentMonitor.name) return "volume-osd-" + currentMonitor.name
        if (modelData && modelData.name) return "volume-osd-" + modelData.name
        return "volume-osd-screen-" + String(modelData ? modelData.x : 0) + "-" + String(modelData ? modelData.y : 0)
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

            OSD.Proc.runCommand(cmdId("volume-check"), ["pamixer", "--get-volume"], (output, exitCode) => {
                if (exitCode === 0 && output) {
                    const newVolume = parseInt(output.trim()) / 100;
                    if (Math.abs(newVolume - lastVolume) > 0.01 || lastVolume < 0) {
                        volume = newVolume;
                        lastVolume = newVolume;
                        shouldShowOSD = true;
                        hideTimer.restart();
                    }
                }
            }, 0);

            OSD.Proc.runCommand(cmdId("mute-check"), ["pamixer", "--get-mute"], (output, exitCode) => {
                if (exitCode === 0 && output) {
                    const muted = output.trim() === "true";
                    if (muted !== isMuted) {
                        isMuted = muted;
                        shouldShowOSD = true;
                        hideTimer.restart();
                    }
                }
            }, 0);
        }
    }

    // Headphone detection (less frequent)
    Timer {
        interval: 3000
        running: enabled
        repeat: true
        onTriggered: {
            OSD.Proc.runCommand(cmdId("sink-check"), ["bash", "-c", "pactl get-default-sink && pactl list sinks | grep -i 'Active Port'"], (output, exitCode) => {
                if (exitCode === 0 && output) {
                    const lower = output.toLowerCase();
                    isHeadphone = lower.includes("bluez") || lower.includes("headphone");
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

    readonly property string volumeIcon: {
        if (isMuted) return isHeadphone ? "󰟎" : "󰖁";
        if (isHeadphone) return "󰋋";
        if (volume < 0.33) return "󰕿";
        if (volume < 0.66) return "󰖀";
        return "󰕾";
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
                color: isMuted ? OSD.Theme.color240 : OSD.Theme.color1
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: root.osdPadding
                border.color: OSD.Theme.color0
                border.width: OSD.Theme.borderWidth

                Behavior on color {
                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                Text {
                    anchors.centerIn: parent
                    text: volumeIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: parent.width * 0.5
                    color: OSD.Theme.color0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        isMuted = !isMuted;
                        OSD.Proc.runCommand(cmdId("mute-toggle"), ["pamixer", "-t"], () => {}, 0);
                        hideTimer.restart();
                    }
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
                    value: volume
                    lineHeight: parent.height * 0.8
                    showIndicator: true
                    interactive: true

                    onSeeking: pos => {
                        isInteracting = true;
                        volume = pos;
                        OSD.Proc.runCommand(cmdId("volume-set"), ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 50);
                    }

                    onClicked: pos => {
                        volume = pos;
                        lastVolume = pos;
                        OSD.Proc.runCommand(cmdId("volume-set"), ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 0);
                        isInteracting = false;
                        hideTimer.restart();
                    }
                }
            }
        }
    }
}
