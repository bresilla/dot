import QtQuick
import Quickshell
import "." as Board
import "./panels/clock"
import "./panels/calendar"
import "./panels/media"
import "./cards"

Scope {
    id: root
    property var screen: null
    property bool mouseInside: false
    property bool isPinned: false
    
    PanelWindow {
        id: mainWindow
        screen: root.screen
        implicitWidth: Screen.width * 0.5
        implicitHeight: Screen.height * 0.5
        color: "transparent"
        exclusiveZone: 0
        mask: Region { item: container }
        
        margins {
            left: Screen.width * 0.25
            top: Screen.height * 0.25
        }
        
        MouseArea {
            id: containerHoverArea
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: root.mouseInside = containsMouse
            
            Rectangle {
                id: container
                anchors.fill: parent
                color: WalColors.color238
                opacity: 0.98
                radius: 20
                
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.InOutQuad
                    }
                }
                
                Item {
                    id: grid
                anchors.fill: parent
                anchors.margins: Theme.spacing
                
                readonly property real spacing: Theme.spacing
                
                readonly property real leftColWidth: (width - spacing) * 0.25
                readonly property real rightColWidth: (width - spacing) * 0.75
                
                readonly property real leftColX: 0
                readonly property real rightColX: leftColWidth + spacing
                
                readonly property real clockHeight: (height - spacing) * 0.4
                readonly property real systemHeight: (height - spacing) * 0.6
                
                readonly property real userHeight: (height - spacing) * 0.25
                readonly property real bottomHeight: (height - spacing) * 0.75
                
                readonly property real infoWidth: (rightColWidth - spacing) * 0.75
                readonly property real logoWidth: (rightColWidth - spacing) * 0.25
                
                readonly property real calendarWidth: (rightColWidth - spacing) * 0.6
                readonly property real mediaWidth: (rightColWidth - spacing) * 0.4
                
                LogoCard {
                    x: grid.leftColX
                    y: 0
                    width: grid.leftColWidth
                    height: grid.clockHeight
                    
                    onPinToggled: root.isPinned = !root.isPinned
                }
                
                SystemCard {
                    x: grid.leftColX
                    y: grid.clockHeight + grid.spacing
                    width: grid.leftColWidth
                    height: grid.systemHeight
                }
                
                UserInfoCard {
                    x: grid.rightColX
                    y: 0
                    width: grid.infoWidth
                    height: grid.userHeight
                }
                
                ClockPanel {
                    x: grid.rightColX + grid.infoWidth + grid.spacing
                    y: 0
                    width: grid.logoWidth
                    height: grid.userHeight
                }
                
                CalendarPanel {
                    x: grid.rightColX
                    y: grid.userHeight + grid.spacing
                    width: grid.calendarWidth
                    height: grid.bottomHeight
                }
                
                MediaPanel {
                    x: grid.rightColX + grid.calendarWidth + grid.spacing
                    y: grid.userHeight + grid.spacing
                    width: grid.mediaWidth
                    height: grid.bottomHeight
                }
            }
        }
        }
    }
}
