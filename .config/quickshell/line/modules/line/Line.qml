import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    required property real lineBarWidth
    required property bool barOnRight

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
        id: wsSwitchProc
        running: false
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
        implicitWidth: lineBarWidth
        color: "transparent"

        Rectangle {
            id: box
            anchors { fill: parent; margins: 0 }
            color: "#000000"
            opacity: 0.95
            Behavior on color { ColorAnimation { duration: 300 } }

            Column {
                id: wsContainer
                anchors {
                    left: barOnRight ? undefined : parent.left
                    right: barOnRight ? parent.right : undefined
                    verticalCenter: parent.verticalCenter
                }
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
                        opacity: modelData.active ? 1.0 :
                                 wsMouseArea.containsMouse ? 0.9 : 0.6
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        MouseArea {
                            id: wsMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.activate()
                        }
                    }
                }
            }

            // Scroll overlay: accepts wheel events without blocking clicks
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const direction = wheel.angleDelta.y > 0 ? "r-1" : "r+1";
                    wsSwitchProc.command = ["hyprctl", "dispatch", "workspace", direction];
                    wsSwitchProc.running = true;
                }
            }
        }

        Component.onCompleted: {
            Hyprland.refreshWorkspaces();
        }
    }
}
