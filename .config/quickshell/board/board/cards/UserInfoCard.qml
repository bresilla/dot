import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../../panels/media"

BaseCard {
    id: root
    
    readonly property real screenBasedLineHeight: Screen.height * 0.005
    readonly property real iconSize: Theme.iconSize * 1.5
    readonly property string brightCommand: Quickshell.env("HOME") + "/.config/profile/functions/system/bright"
    
    property real volume: -1
    property real brightness: -1
    
    Component.onCompleted: {
        volumeGetProc.running = true
        brightnessGetProc.running = true
    }
    
    Process {
        id: volumeGetProc
        command: ["pamixer", "--get-volume"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.volume = parseInt(data.trim()) / 100
            }
        }
    }
    
    Process {
        id: brightnessGetProc
        command: [root.brightCommand, "get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.brightness = parseFloat(data.trim()) / 100
            }
        }
    }
    
    Process {
        id: volumeSetProc
        running: false
    }
    
    Process {
        id: brightnessSetProc
        running: false
    }
    
    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing * 2
        
        Item {
            width: parent.width * 0.5 - parent.spacing
            height: parent.height
            
            Process {
                id: distroProc
                command: ["sh", "-c", "grep '^DISTRIB_ID=' /etc/lsb-release | cut -d'=' -f2 | tr -d '\"'"]
                running: true
                
                property string distroName: "Linux"
                
                onStarted: {
                    const text = stdout.readAll()
                    if (text) distroName = text.trim()
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacing * 1.5
                width: parent.width
                
                Text {
                    text: Quickshell.env("USER") || "User"
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: Theme.fontSizeLarge * 1.2
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "" // Nerd Font Arch Linux logo
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: Theme.iconSize * 1.5
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Process {
                    id: uptimeProc
                    command: ["sh", "-c", "uptime -p | sed 's/up //'"]
                    running: true
                    
                    property string uptimeText: ""
                    
                    onStarted: {
                        const text = stdout.readAll()
                        if (text) uptimeText = text.trim()
                    }
                }
                
                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: uptimeProc.running = true
                }
                
                Text {
                    text: uptimeProc.uptimeText || "Loading..."
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
        
        Item {
            width: parent.width * 0.5 - parent.spacing
            height: parent.height
            
            Column {
                anchors.centerIn: parent
                spacing: Theme.spacing * 2
                width: parent.width * 0.8
                
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    
                    Rectangle {
                        width: root.iconSize
                        height: root.iconSize
                        radius: width / 2
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "󰕾"
                            size: root.iconSize * 0.6
                            color: Theme.primary
                        }
                    }
                    
                    StyledProgressBar {
                        width: parent.width - parent.children[0].width - parent.spacing
                        value: root.volume
                        lineHeight: root.screenBasedLineHeight
                        showIndicator: true
                        interactive: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.volume >= 0
                        
                        onClicked: position => {
                            volumeSetProc.command = ["pamixer", "--set-volume", Math.round(position * 100).toString()]
                            volumeSetProc.running = true
                            root.volume = position
                        }
                        
                        onSeeking: position => {
                            volumeSetProc.command = ["pamixer", "--set-volume", Math.round(position * 100).toString()]
                            volumeSetProc.running = true
                            root.volume = position
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    spacing: Theme.spacing
                    
                    Rectangle {
                        width: root.iconSize
                        height: root.iconSize
                        radius: width / 2
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                        
                        DankIcon {
                            anchors.centerIn: parent
                            name: "󰃠"
                            size: root.iconSize * 0.6
                            color: Theme.primary
                        }
                    }
                    
                    StyledProgressBar {
                        width: parent.width - parent.children[0].width - parent.spacing
                        value: root.brightness
                        lineHeight: root.screenBasedLineHeight
                        showIndicator: true
                        interactive: true
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.brightness >= 0
                        
                        onClicked: position => {
                            brightnessSetProc.command = [root.brightCommand, Math.round(position * 100).toString()]
                            brightnessSetProc.running = true
                            root.brightness = position
                        }
                        
                        onSeeking: position => {
                            brightnessSetProc.command = [root.brightCommand, Math.round(position * 100).toString()]
                            brightnessSetProc.running = true
                            root.brightness = position
                        }
                    }
                }
            }
        }
    }
}
