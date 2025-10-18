import QtQuick
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root
    
    property int currentWorkspace: Hyprland.focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShow: false
    
    onCurrentWorkspaceChanged: {
        if (previousWorkspace !== currentWorkspace && previousWorkspace !== 0) {
            console.log("Workspace changed from", previousWorkspace, "to:", currentWorkspace);
            root.shouldShow = true;
            hideTimer.restart();
        }
        previousWorkspace = currentWorkspace;
    }
    
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shouldShow = false
    }
    
    PanelWindow {
        visible: root.shouldShow
        
        anchors {
            left: true
            top: true
        }
        
        implicitWidth: 150
        implicitHeight: 150
        
        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}
        
        margins {
            left: Screen.width * 0.005 + 20
            top: (screen.height - implicitHeight) / 2
        }
        
        Rectangle {
            id: osdCircle
            anchors.fill: parent
            radius: width / 2
            color: "#CC000000"
            border.color: "#ffffff"
            border.width: 3
            
            Text {
                anchors.centerIn: parent
                text: root.currentWorkspace
                font.pixelSize: 72
                font.bold: true
                color: "#ffffff"
            }
            
            states: [
                State {
                    name: "visible"
                    when: root.shouldShow
                    PropertyChanges { target: osdCircle; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !root.shouldShow
                    PropertyChanges { target: osdCircle; opacity: 0.0 }
                }
            ]
            
            transitions: [
                Transition {
                    from: "visible"
                    to: "hidden"
                    SequentialAnimation {
                        PauseAnimation { duration: 500 }
                        NumberAnimation { 
                            property: "opacity"
                            to: 0
                            duration: 1000
                            easing.type: Easing.InOutQuad
                        }
                    }
                },
                Transition {
                    from: "hidden"
                    to: "visible"
                    NumberAnimation { 
                        property: "opacity"
                        to: 1.0
                        duration: 100
                    }
                }
            ]
        }
    }
}
