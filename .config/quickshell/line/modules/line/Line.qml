import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    anchors { top: true; left: true; bottom: true }
    implicitWidth: Screen.width * 0.005
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
        anchors { fill: parent; margins: 0 }
        color: "#000000"
        opacity: 0.95
        Behavior on color { ColorAnimation { duration: 300 } }
        readonly property var currentMonitor: Hyprland.monitorFor(screen)

        Item {
            id: wsArea
            width: parent.width * 0.5
            anchors { top: parent.top; left: parent.left; right: parent.right; bottom: parent.bottom }

            ListView {
                id: wsList
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: Math.min(parent.height, contentHeight)
                property int thisheight: parent.height
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
                    height: visible ? wsList.thisheight / 20 : 0
                    radius: 4
                    color: modelData.active ? wal.adapter.colors["color2"] : wal.adapter.colors["color7"]
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

    Component.onCompleted: Hyprland.refreshWorkspaces()
}

