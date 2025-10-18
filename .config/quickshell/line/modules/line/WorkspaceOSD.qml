import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

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
    
    property int currentWorkspace: Hyprland.focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShow: false
    
    property int activeIndex: {
        let count = 0;
        for (let i = 0; i < Hyprland.workspaces.length; i++) {
            let ws = Hyprland.workspaces.at(i);
            if (ws.id >= 0 && !ws.name?.startsWith("special:")) {
                if (ws.active) return count;
                count++;
            }
        }
        return 0;
    }
    
    onCurrentWorkspaceChanged: {
        if (previousWorkspace !== currentWorkspace && previousWorkspace !== 0) {
            console.log("Workspace changed from", previousWorkspace, "to:", currentWorkspace, "index:", activeIndex);
            root.shouldShow = true;
            hideTimer.restart();
        }
        previousWorkspace = currentWorkspace;
    }
    
    Timer {
        id: hideTimer
        interval: 750
        onTriggered: root.shouldShow = false
    }
    
    PanelWindow {
        visible: root.shouldShow
        
        anchors {
            left: true
            top: true
        }
        
        implicitWidth: 105
        implicitHeight: 105
        
        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}
        
        margins {
            left: Screen.width * 0.005 + 5
            top: {
                let itemHeight = screen.height / 20;
                let spacing = 10;
                let totalHeight = 10 * itemHeight + 9 * spacing;
                let listTop = (screen.height - totalHeight) / 2;
                let wsIndex = currentWorkspace - 1; // workspace 1 = index 0
                return listTop + wsIndex * (itemHeight + spacing) + (itemHeight - implicitHeight) / 2 + 10;
            }
        }
        
        Rectangle {
            id: osdCircle
            anchors.fill: parent
            radius: width / 2
            color: wal.adapter.colors["color1"] || "#CC000000"
            border.color: wal.adapter.colors["color0"] || "#000000"
            border.width: 6
            
            Text {
                anchors.centerIn: parent
                text: root.currentWorkspace
                font.pixelSize: 50
                font.bold: true
                font.weight: Font.Black
                color: wal.adapter.colors["color0"] || "#ffffff"
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
                        PauseAnimation { duration: 250 }
                        NumberAnimation { 
                            property: "opacity"
                            to: 0
                            duration: 500
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
