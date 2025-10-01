import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    anchors { top: true; left: true; bottom: true }
    implicitWidth: Screen.width * 0.015
    color: "transparent"

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

    Rectangle {
        id: box
        anchors { fill: parent; margins: 6 }
        color: wal.adapter.special.background
        opacity: 0.95
        radius: 10
        Behavior on color { ColorAnimation { duration: 300 } }

        readonly property var currentMonitor: Hyprland.monitorFor(screen)

        Rectangle {
            id: clockBox
            implicitWidth: parent.width * 0.7
            implicitHeight: parent.height * 0.05
            anchors { bottom: parent.bottom; right: parent.right; left: parent.left; margins: 6 }
            color: wal.adapter.colors["color1"]
            opacity: 0.95
            radius: 8

            Text {
                id: clock
                anchors.centerIn: parent
                rotation: -90
                color: wal.adapter.colors["color0"]
                font.pixelSize: 18

                Process {
                    id: dateProc
                    command: ["date", "+%H:%M:%S"]
                    running: true
                    stdout: StdioCollector { onStreamFinished: clock.text = text }
                }
                Timer { interval: 1000; repeat: true; running: true; onTriggered: dateProc.running = true }
            }
        }

        Item {
            id: wsArea
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: clockBox.top }

            ListView {
                id: wsList
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: Math.min(parent.height, contentHeight)
                spacing: 8
                interactive: false
                orientation: ListView.Vertical
                model: Hyprland.workspaces

                delegate: Rectangle {
                    required property HyprlandWorkspace modelData
                    readonly property bool isSpecial: modelData.id < 0 || (modelData.name && modelData.name.startsWith("special:"))
                    readonly property bool isOnThisMonitor: modelData.monitor === box.currentMonitor
                    visible: !isSpecial && isOnThisMonitor
                    width: wsList.width
                    height: visible ? 20 : 0
                    radius: 4
                    color: modelData.active ? wal.adapter.colors["color2"] : wal.adapter.colors["color8"]
                    opacity: modelData.active ? 1.0 : 0.6
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name || (modelData.id + 1)
                        color: wal.adapter.special.foreground
                        font.pixelSize: 10
                        rotation: -90
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: modelData.activate()
                    }
                }
            }
        }
    }

    Component.onCompleted: Hyprland.refreshWorkspaces()
}

