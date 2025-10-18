import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    required property var modelData
    required property string currentBoard
    
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    property var focusedWorkspace: Hyprland.focusedWorkspace
    property int currentWorkspace: focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShowBoard: false
    property bool mouseInsideBoard: false
    property bool mouseHasMoved: false
    property point lastMousePos: Qt.point(0, 0)
    
    Connections {
        target: boardLoader.item
        function onMouseInsideChanged() {
            if (boardLoader.item) {
                root.mouseInsideBoard = boardLoader.item.mouseInside
            }
        }
    }
    
    Timer {
        id: mouseMovementChecker
        interval: 150
        running: shouldShowBoard && !mouseHasMoved
        repeat: true
        onTriggered: {
            Proc.runCommand("mousePosCheck", ["hyprctl", "cursorpos", "-j"], function(stdout) {
                try {
                    const pos = JSON.parse(stdout)
                    const currentPos = Qt.point(pos.x, pos.y)
                    
                    if (lastMousePos.x === 0 && lastMousePos.y === 0) {
                        lastMousePos = currentPos
                    } else {
                        const dx = Math.abs(currentPos.x - lastMousePos.x)
                        const dy = Math.abs(currentPos.y - lastMousePos.y)
                        
                        if (dx > 10 || dy > 10) {
                            mouseHasMoved = true
                        }
                        
                        lastMousePos = currentPos
                    }
                } catch(e) {}
            })
        }
    }
    
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "movewindow" || event.name === "openwindow" || event.name === "closewindow") {
                Hyprland.refreshWorkspaces()
            }
        }
    }
    
    onFocusedWorkspaceChanged: {
        if (previousWorkspace !== currentWorkspace && previousWorkspace !== 0) {
            const isOnThisMonitor = focusedWorkspace && focusedWorkspace.monitor === currentMonitor
            const isEmpty = focusedWorkspace?.lastIpcObject?.windows === 0
            
            if (isOnThisMonitor && isEmpty) {
                shouldShowBoard = true
                mouseHasMoved = false
                lastMousePos = Qt.point(0, 0)
                hideTimer.restart()
            } else {
                shouldShowBoard = false
            }
        }
        previousWorkspace = currentWorkspace
    }
    
    onMouseInsideBoardChanged: {
        if (!mouseInsideBoard && shouldShowBoard && mouseHasMoved) {
            hideTimer.restart()
        } else if (mouseInsideBoard && mouseHasMoved) {
            hideTimer.stop()
        }
    }
    
    onMouseHasMovedChanged: {
        if (mouseHasMoved && mouseInsideBoard && shouldShowBoard) {
            hideTimer.stop()
        }
    }
    
    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: {
            if (!mouseInsideBoard || !mouseHasMoved) {
                shouldShowBoard = false
            }
        }
    }
    
    Loader {
        id: boardLoader
        active: shouldShowBoard
        source: "./" + currentBoard + "/Board.qml"
        
        onLoaded: {
            if (item) {
                item.screen = modelData
            }
        }
    }
    
    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
    }
}
