import QtQuick
import Quickshell
import Quickshell.Io
import "./cards"

Scope {
    id: root
    
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
    
    PanelWindow {
        id: mainWindow
        screen: Quickshell.screens[0]
        implicitWidth: Screen.width * 0.3
        implicitHeight: Screen.height * 0.3
        color: "transparent"
        exclusiveZone: 0
        mask: Region { item: container }
        
        margins {
            left: Screen.width * 0.35
            top: Screen.height * 0.35
        }
        
        Rectangle {
            id: container
            anchors.fill: parent
            color: WalColors.color238
            opacity: 0.98
            radius: 20
            
            Item {
                id: grid
                anchors.fill: parent
                anchors.margins: Theme.spacing
                
                readonly property real spacing: Theme.spacing
                
                ClockCard {
                    anchors.fill: parent
                }
            }
        }
    }
}
