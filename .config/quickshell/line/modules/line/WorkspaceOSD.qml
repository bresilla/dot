import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    required property var modelData
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    readonly property int monitorHeight: modelData ? modelData.height : 1080
    readonly property int monitorWidth: modelData ? modelData.width : 1920
    
    property string positionMode: "right"
    
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

    Process {
        id: hyprctl
        running: true
        command: ["sh", "-c", "hyprctl monitors -j"]
        stdout: SplitParser {
            id: monitorJson
        }
    }

    readonly property var monitorsData: {
        try {
            return JSON.parse(monitorJson.data || "[]");
        } catch (e) {
            return [];
        }
    }

    readonly property var mainMonitor: {
        for (let i = 0; i < monitorsData.length; i++) {
            if (monitorsData[i].focused) return monitorsData[i];
        }
        return monitorsData.length > 0 ? monitorsData[0] : null;
    }

    readonly property int mainCenterX: mainMonitor ? mainMonitor.x + (mainMonitor.width / 2) : 0
    readonly property int thisCenterX: modelData ? (modelData.x + (modelData.width / 2)) : 0
    readonly property bool isMainMonitor: mainMonitor && modelData && mainMonitor.name === currentMonitor?.name
    readonly property bool barOnRight: {
        if (positionMode === "left") return false;
        if (positionMode === "right") return true;
        return isMainMonitor ? false : thisCenterX < mainCenterX;
    }

    property var focusedWorkspace: Hyprland.focusedWorkspace
    property int currentWorkspace: focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShowOSD: false
    
    onFocusedWorkspaceChanged: {
        if (previousWorkspace !== currentWorkspace && previousWorkspace !== 0) {
            const isOnThisMonitor = focusedWorkspace && focusedWorkspace.monitor === currentMonitor;
            
            if (isOnThisMonitor) {
                shouldShowOSD = true;
                hideTimer.restart();
            } else {
                shouldShowOSD = false;
            }
        }
        previousWorkspace = currentWorkspace;
    }
    
    Timer {
        id: hideTimer
        interval: 750
        onTriggered: shouldShowOSD = false
    }
    
    PanelWindow {
        id: osdWindow
        screen: modelData
        visible: shouldShowOSD
        
        anchors {
            left: !barOnRight
            right: barOnRight
            top: true
        }
        
        implicitWidth: 120
        implicitHeight: containerHeight + (spacing * 9)
        
        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}
        
        readonly property int containerHeight: monitorHeight * 0.5
        readonly property int itemHeight: containerHeight / 10
        readonly property int spacing: 10
        readonly property int containerStartY: (monitorHeight - containerHeight) / 2
        readonly property int lineWidth: Screen.width * 0.005
        
        margins {
            left: barOnRight ? 0 : lineWidth + 10
            right: barOnRight ? lineWidth + 10 : 0
            top: containerStartY
        }
        
        Column {
            id: osdContainer
            anchors.left: parent.left
            anchors.top: parent.top
            width: osdWindow.implicitWidth
            height: osdWindow.containerHeight
            spacing: osdWindow.spacing
            
            Repeater {
                model: Hyprland.workspaces
                
                delegate: Item {
                    required property HyprlandWorkspace modelData
                    
                    readonly property bool isSpecial: modelData.id < 0 || (modelData.name && modelData.name.startsWith("special:"))
                    readonly property bool isOnThisMonitor: modelData.monitor?.name === currentMonitor?.name
                    readonly property bool isActive: modelData.active
                    
                    visible: !isSpecial && isOnThisMonitor
                    width: osdContainer.width
                    height: visible ? osdContainer.height / 10 : 0
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        visible: isActive
                        color: wal.adapter.colors["color1"] || "#CC000000"
                        border.color: wal.adapter.colors["color0"] || "#000000"
                        border.width: 6
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            font.pixelSize: 50
                            font.bold: true
                            font.weight: Font.Black
                            color: wal.adapter.colors["color0"] || "#ffffff"
                        }
                        
                        opacity: shouldShowOSD ? 1.0 : 0.0
                        
                        Behavior on opacity {
                            NumberAnimation { 
                                duration: shouldShowOSD ? 100 : 500
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }
        }
    }
}
