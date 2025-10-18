import QtQuick
import Quickshell
import "../../board"

Rectangle {
    id: root
    
    readonly property real digitSize: Math.min(width, height) * 0.35
    readonly property real digitWidth: digitSize * 0.58
    
    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
    
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: colonBlink.opacity = colonBlink.opacity === 1 ? 0 : 1
    }
    
    radius: Theme.cornerRadius
    color: Theme.color236
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    
    Column {
        anchors.centerIn: parent
        spacing: root.height * 0.02
        
        Row {
            spacing: root.digitWidth * 0.15
            anchors.horizontalCenter: parent.horizontalCenter
            
            Text {
                text: String(systemClock.date.getHours()).padStart(2, '0').charAt(0)
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: root.digitSize
                color: Theme.color1
                font.weight: Font.Medium
                width: root.digitWidth
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                text: String(systemClock.date.getHours()).padStart(2, '0').charAt(1)
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: root.digitSize
                color: Theme.color1
                font.weight: Font.Medium
                width: root.digitWidth
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                id: colonBlink
                text: ":"
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: root.digitSize
                color: Theme.color1
                font.weight: Font.Medium
                width: root.digitWidth * 0.4
                horizontalAlignment: Text.AlignHCenter
                opacity: 1
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            
            Text {
                text: String(systemClock.date.getMinutes()).padStart(2, '0').charAt(0)
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: root.digitSize
                color: Theme.color1
                font.weight: Font.Medium
                width: root.digitWidth
                horizontalAlignment: Text.AlignHCenter
            }
            
            Text {
                text: String(systemClock.date.getMinutes()).padStart(2, '0').charAt(1)
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: root.digitSize
                color: Theme.color1
                font.weight: Font.Medium
                width: root.digitWidth
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        Text {
            text: systemClock.date.toLocaleDateString(Qt.locale(), "MMM dd")
            font.family: "IosevkaTerm Nerd Font Mono"
            font.pixelSize: root.digitSize * 0.375
            color: Qt.rgba(
                parseInt(Theme.color1?.substring(1, 3) || "ff", 16) / 255,
                parseInt(Theme.color1?.substring(3, 5) || "ff", 16) / 255,
                parseInt(Theme.color1?.substring(5, 7) || "ff", 16) / 255,
                0.7
            )
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
