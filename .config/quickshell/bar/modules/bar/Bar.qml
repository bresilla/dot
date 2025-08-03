import Quickshell
import Quickshell.Io
import QtQuick

PanelWindow {
    anchors {
        top: true
        left: true
        bottom: true
    }
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
            property var colors: { }
        }
    }

    Rectangle {
        anchors{
            fill: parent
            margins: 6
        }
        color: wal.adapter.special.background
        opacity: 0.95
        radius: 10

        Behavior on color {
            ColorAnimation { duration: 300 }
        }

        Rectangle {
            implicitWidth: parent.width * 0.7
            implicitHeight: parent.height * 0.05
            anchors {
                bottom: parent.bottom
                right: parent.right
                left: parent.left
                margins: 6
            }
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
                    stdout: StdioCollector {
                        onStreamFinished: clock.text = text
                    }
                }
                Timer {
                    interval: 1000; repeat: true
                    onTriggered: dateProc.running = true
                }
            }
        }
    }
}

