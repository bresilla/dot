import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../board"
import "."

Rectangle {
    id: root
    
    readonly property real screenBasedLineHeight: Theme.progressLineHeight
    
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
    
    readonly property real scaledIconSize: Math.min(width, height) * 0.15
    readonly property real scaledFontSmall: Math.min(width, height) * 0.05
    readonly property real scaledFontMedium: Math.min(width, height) * 0.055
    readonly property real scaledSpacing: Math.min(width, height) * 0.02
    readonly property real scaledButtonSize: Math.min(width, height) * 0.14

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
    border.width: Theme.borderWidth

    Column {
        anchors.centerIn: parent
        spacing: scaledSpacing
        visible: !activePlayer

        DankIcon {
            name: "󰝚"
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
            
            StyledProgressBar {
                anchors.centerIn: parent
                width: parent.width * 0.5
                value: activePlayer?.volume ?? 0
                lineHeight: root.screenBasedLineHeight
                showIndicator: true
                interactive: activePlayer !== null
                
                onClicked: position => {
                    if (activePlayer) {
                        activePlayer.volume = position
                    }
                }
                
                onSeeking: position => {
                    if (activePlayer) {
                        activePlayer.volume = position
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
            
            StyledProgressBar {
                anchors.centerIn: parent
                width: parent.width * 0.8
                value: root.ratio
                lineHeight: root.screenBasedLineHeight
                showIndicator: true
                interactive: activePlayer?.canSeek ?? false
                
                property real pendingSeekPosition: -1
                
                Timer {
                    id: seekDebounceTimer
                    interval: 150
                    onTriggered: {
                        if (parent.pendingSeekPosition >= 0 && activePlayer && activePlayer.canSeek && activePlayer.length > 0) {
                            const clamped = Math.min(parent.pendingSeekPosition, activePlayer.length * 0.99)
                            activePlayer.position = clamped
                            parent.pendingSeekPosition = -1
                            root.isSeeking = false
                        }
                    }
                }
                
                onSeeking: position => {
                    root.isSeeking = true
                    if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                        pendingSeekPosition = position * activePlayer.length
                        seekDebounceTimer.restart()
                    }
                }
                
                onClicked: position => {
                    root.isSeeking = false
                    seekDebounceTimer.stop()
                    if (activePlayer && activePlayer.length > 0 && activePlayer.canSeek) {
                        if (pendingSeekPosition >= 0) {
                            const clamped = Math.min(pendingSeekPosition, activePlayer.length * 0.99)
                            activePlayer.position = clamped
                            pendingSeekPosition = -1
                        } else {
                            activePlayer.position = position * activePlayer.length
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
                        name: "󰒟"
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
                        name: "󰒮"
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
                        name: activePlayer?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
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
                        name: "󰒭"
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
                        name: activePlayer?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
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
