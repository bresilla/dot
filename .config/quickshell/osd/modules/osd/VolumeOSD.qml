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
    required property bool osdOnLeft

    property bool shouldShowOSD: false
    property real volume: 0.5
    property real lastVolume: -1
    
    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            OSD.Proc.runCommand("volume-check", ["pamixer", "--get-volume"], (output, exitCode) => {
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
        }
    }
    
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: shouldShowOSD = false
    }
    
    PanelWindow {
        id: osdWindow
        screen: modelData
        visible: true
        
        anchors {
            left: osdOnLeft
            right: !osdOnLeft
            top: false
            bottom: false
        }
        
        implicitWidth: monitorWidth * 0.05
        implicitHeight: monitorHeight * 0.4
        
        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}
        
        margins {
            left: osdOnLeft ? 20 : 0
            right: osdOnLeft ? 0 : 20
            top: (monitorHeight - implicitHeight) / 2
            bottom: 40
        }
        
        Rectangle {
            width: parent.width * 0.6
            height: width
            radius: width / 2
            color: OSD.Theme.color1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            opacity: shouldShowOSD ? 1.0 : 0.0
            border.color: OSD.Theme.color0
            border.width: 2
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            
            Text {
                anchors.centerIn: parent
                text: "󰕾"
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: parent.width * 0.5
                color: OSD.Theme.color0
            }
        }
        
        Rectangle {
            id: progressRect
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.width * 0.9
            width: parent.width * 0.4
            height: parent.height - parent.width * 0.9
            color: OSD.Theme.color1
            radius: 8
            opacity: shouldShowOSD ? 1.0 : 0.0
            border.color: OSD.Theme.color0
            border.width: 2
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            
            StyledProgressBar {
                anchors.centerIn: parent
                width: parent.height * 0.95
                height: parent.width * 0.8
                rotation: -90
                transformOrigin: Item.Center
                value: volume
                lineHeight: parent.width * 0.8
                showIndicator: true
                interactive: false
            }
        }
    }
}
