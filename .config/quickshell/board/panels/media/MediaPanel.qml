import QtQuick
import Quickshell.Services.Mpris
import "../../board"
import "."

Rectangle {
    id: root
    
    property MprisPlayer activePlayer: MprisController.activePlayer
    property real currentPosition: activePlayer?.positionSupported ? activePlayer.position : 0
    property real displayPosition: currentPosition
    property bool isSeeking: false

    readonly property real ratio: {
        if (!activePlayer || activePlayer.length <= 0) return 0
        const pos = displayPosition % Math.max(1, activePlayer.length)
        const calculatedRatio = pos / activePlayer.length
        return Math.max(0, Math.min(1, calculatedRatio))
    }
    
    readonly property real scaledIconSize: Math.min(width, height) * 0.12
    readonly property real scaledFontSmall: Math.min(width, height) * 0.05
    readonly property real scaledFontMedium: Math.min(width, height) * 0.055
    readonly property real scaledSpacing: Math.min(width, height) * 0.02
    readonly property real scaledButtonSize: Math.min(width, height) * 0.12

    onActivePlayerChanged: {
        if (activePlayer?.positionSupported) {
            currentPosition = Qt.binding(() => activePlayer?.position || 0)
        } else {
            currentPosition = 0
        }
    }

    Timer {
        interval: 300
        running: activePlayer?.playbackState === MprisPlaybackState.Playing && !isSeeking
        repeat: true
        onTriggered: activePlayer?.positionSupported && activePlayer.positionChanged()
    }

    radius: Theme.cornerRadius
    color: Theme.color236
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 1

    Column {
        anchors.centerIn: parent
        spacing: scaledSpacing
        visible: !activePlayer

        DankIcon {
            name: "music_note"
            size: scaledIconSize
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: I18n.tr("No Media")
            font.pixelSize: scaledFontSmall
            color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - scaledSpacing * 2
        spacing: scaledSpacing * 2
        visible: activePlayer

        Item {
            width: parent.width
            height: scaledSpacing * 2
            
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.5
                height: 4
                radius: 2
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                
                Rectangle {
                    width: parent.width * (activePlayer?.volume ?? 0)
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                    
                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (activePlayer) {
                            activePlayer.volume = mouse.x / width
                        }
                    }
                }
            }
        }

        Item {
            width: root.width * 0.6
            height: root.height * 0.35
            anchors.horizontalCenter: parent.horizontalCenter
            clip: false

            DankAlbumArt {
                width: Math.min(parent.width, parent.height)
                height: width
                anchors.centerIn: parent
                activePlayer: root.activePlayer
                albumSize: width * 0.9
                animationScale: 1.05
            }
        }

        Column {
            width: parent.width
            spacing: scaledSpacing * 0.5

            StyledText {
                text: activePlayer?.trackTitle || "Unknown"
                font.pixelSize: scaledFontMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                text: activePlayer?.trackArtist || "Unknown Artist"
                font.pixelSize: scaledFontSmall
                color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.7)
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Item {
            width: parent.width
            height: scaledSpacing * 3
            
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.8
                height: 6
                radius: 3
                color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                
                Rectangle {
                    width: parent.width * root.ratio
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                    
                    Behavior on width {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (activePlayer && activePlayer.canSeek) {
                            const newPos = (mouse.x / width) * activePlayer.length
                            activePlayer.position = newPos
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: scaledButtonSize

            Row {
                spacing: scaledSpacing
                anchors.centerIn: parent

                Rectangle {
                    width: scaledButtonSize * 0.6
                    height: scaledButtonSize * 0.6
                    radius: width / 2
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: activePlayer?.shuffle ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : shuffleArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "shuffle"
                        size: scaledButtonSize * 0.35
                        color: activePlayer?.shuffle ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: shuffleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!activePlayer) return
                            activePlayer.shuffle = !activePlayer.shuffle
                        }
                    }
                }

                Rectangle {
                    width: scaledButtonSize * 0.8
                    height: scaledButtonSize * 0.8
                    radius: width / 2
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: prevArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: scaledButtonSize * 0.5
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!activePlayer) return
                            if (activePlayer.position > 8 && activePlayer.canSeek) {
                                activePlayer.position = 0
                            } else {
                                activePlayer.previous()
                            }
                        }
                    }
                }

                Rectangle {
                    id: playPauseButton
                    width: scaledButtonSize
                    height: scaledButtonSize
                    radius: width / 2
                    color: Theme.primary

                    DankIcon {
                        anchors.centerIn: parent
                        name: activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        size: scaledButtonSize * 0.6
                        color: Theme.background
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: activePlayer?.togglePlaying()
                    }
                }

                Rectangle {
                    width: scaledButtonSize * 0.8
                    height: scaledButtonSize * 0.8
                    radius: width / 2
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: nextArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: scaledButtonSize * 0.5
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: activePlayer?.next()
                    }
                }

                Rectangle {
                    width: scaledButtonSize * 0.6
                    height: scaledButtonSize * 0.6
                    radius: width / 2
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: activePlayer?.loopState !== MprisLoopState.None ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : repeatArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: activePlayer?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                        size: scaledButtonSize * 0.35
                        color: activePlayer?.loopState !== MprisLoopState.None ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: repeatArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!activePlayer) return
                            if (activePlayer.loopState === MprisLoopState.None) {
                                activePlayer.loopState = MprisLoopState.Playlist
                            } else if (activePlayer.loopState === MprisLoopState.Playlist) {
                                activePlayer.loopState = MprisLoopState.Track
                            } else {
                                activePlayer.loopState = MprisLoopState.None
                            }
                        }
                    }
                }
            }
        }
    }
}
