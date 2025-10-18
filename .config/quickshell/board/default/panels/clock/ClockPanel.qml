import QtQuick
import Quickshell
import "../.."

Rectangle {
    id: root
    
    readonly property real digitSize: Math.min(width, height) * 0.27
    readonly property real digitWidth: digitSize * 0.58
    
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }
    
    radius: Theme.cornerRadius
    color: WalColors.color236
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1
    
    Column {
        anchors.centerIn: parent
        spacing: root.height * 0.03
        
        Column {
            spacing: -root.height * 0.04
            anchors.horizontalCenter: parent.horizontalCenter
            
            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text {
                    text: String(systemClock.date.getHours()).padStart(2, '0').charAt(0)
                    font.pixelSize: root.digitSize
                    color: WalColors.color1
                    font.weight: Font.Medium
                    width: root.digitWidth
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: String(systemClock.date.getHours()).padStart(2, '0').charAt(1)
                    font.pixelSize: root.digitSize
                    color: WalColors.color1
                    font.weight: Font.Medium
                    width: root.digitWidth
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            
            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                
                Text {
                    text: String(systemClock.date.getMinutes()).padStart(2, '0').charAt(0)
                    font.pixelSize: root.digitSize
                    color: WalColors.color1
                    font.weight: Font.Medium
                    width: root.digitWidth
                    horizontalAlignment: Text.AlignHCenter
                }
                
                Text {
                    text: String(systemClock.date.getMinutes()).padStart(2, '0').charAt(1)
                    font.pixelSize: root.digitSize
                    color: WalColors.color1
                    font.weight: Font.Medium
                    width: root.digitWidth
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            

        }
        
        Text {
            text: systemClock.date.toLocaleDateString(Qt.locale(), "MMM dd")
            font.pixelSize: root.digitSize * 0.25
            color: Qt.rgba(
                parseInt(WalColors.color1?.substring(1, 3) || "ff", 16) / 255,
                parseInt(WalColors.color1?.substring(3, 5) || "ff", 16) / 255,
                parseInt(WalColors.color1?.substring(5, 7) || "ff", 16) / 255,
                0.7
            )
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
