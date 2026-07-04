import QtQuick
import Quickshell
import Quickshell.Io
import ".."

BaseCard {
    id: root
    
    signal pinToggled()
    
    FileView {
        id: logoFile
        path: Quickshell.env("HOME") + "/.config/bresilla.svg"
        watchChanges: true
        onFileChanged: {
            logoImage.source = ""
            logoImage.source = "file://" + path
        }
    }
    
    Process {
        id: batteryProcess
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        running: true
        stdout: SplitParser {
            onRead: batteryLevel = parseInt(data) || 0
        }
    }
    
    property int batteryLevel: 0
    
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: batteryProcess.running = true
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 0
        topPadding: root.height * 0.05
        
        Image {
            id: logoImage
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width, root.height) * 0.8
            height: width
            source: "file://" + logoFile.path
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: false
        }
        
        Item {
            width: root.width * 0.7
            height: Screen.height * 0.005 * 6
            anchors.horizontalCenter: parent.horizontalCenter
            
            property real lineHeight: Theme.progressLineHeight
            property color trackColor: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            property color fillColor: batteryLevel > 20 ? Theme.primary : "#ff5555"
            
            Rectangle {
                height: parent.lineHeight
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width * (batteryLevel / 100))
                radius: 2
                color: parent.fillColor
                
                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            
            Rectangle {
                height: parent.lineHeight
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * (batteryLevel / 100)
                width: Math.max(0, parent.width - x)
                radius: 2
                color: parent.trackColor
                
                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pinToggled()
    }
}
