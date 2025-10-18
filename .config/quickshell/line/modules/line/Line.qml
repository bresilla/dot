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

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "movewindow" || event.name === "openwindow" || event.name === "closewindow") {
                Hyprland.refreshWorkspaces();
            }
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
    
    Component.onCompleted: {
        console.log("Line.qml - Monitor:", currentMonitor?.name, 
                    "| mainMonitor:", mainMonitor?.name,
                    "| mainCenterX:", mainCenterX,
                    "| thisCenterX:", thisCenterX,
                    "| isMainMonitor:", isMainMonitor,
                    "| barOnRight:", barOnRight);
    }

    PanelWindow {
        id: lineWindow
        screen: modelData
        anchors { 
            top: true
            left: !barOnRight
            right: barOnRight
            bottom: true
        }
        implicitWidth: Screen.width * 0.005
        color: "transparent"

        Rectangle {
            id: box
            anchors { fill: parent; margins: 0 }
            color: "#000000"
            opacity: 0.95
            Behavior on color { ColorAnimation { duration: 300 } }

            Column {
                id: wsContainer
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.7
                height: monitorHeight * 0.5
                spacing: 10
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        required property HyprlandWorkspace modelData
                        readonly property bool isSpecial: modelData.id < 0 || (modelData.name && modelData.name.startsWith("special:"))
                        readonly property bool isOnThisMonitor: modelData.monitor?.name === currentMonitor?.name
                        readonly property bool hasWindows: modelData.lastIpcObject && modelData.lastIpcObject.windows > 0
                        visible: !isSpecial && isOnThisMonitor
                        width: wsContainer.width
                        height: visible ? wsContainer.height / 10 : 0
                        radius: 4
                        color: modelData.active ? wal.adapter.colors["color1"] : 
                               hasWindows ? wal.adapter.colors["color244"] : 
                               wal.adapter.colors["color240"]
                        opacity: modelData.active ? 1.0 : 0.6
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }
                    }
                }
            }
        }

        Component.onCompleted: {
            Hyprland.refreshWorkspaces();
        }
    }
}

