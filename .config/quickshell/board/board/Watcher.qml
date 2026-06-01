import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root
    required property var modelData
    
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    property var focusedWorkspace: Hyprland.focusedWorkspace
    property int currentWorkspace: focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShowBoard: false
    property bool mouseInsideBoard: false
    property bool mouseHasMoved: false
    property point lastMousePos: Qt.point(0, 0)
    property bool windowMoving: false
    property int activeWorkspaceId: focusedWorkspace?.id ?? 1
    property string activeWorkspaceMonitor: focusedWorkspace?.monitor?.name ?? ""
    property int activeWorkspaceWindows: -1

    function isActiveWorkspaceOnThisMonitor() {
        return currentMonitor && activeWorkspaceMonitor === currentMonitor.name
    }

    function isActiveWorkspaceEmpty() {
        return activeWorkspaceWindows === 0
    }

    function refreshActiveWorkspaceState(callback) {
        Proc.runCommand("boardActiveWorkspace", ["hyprctl", "activeworkspace", "-j"], function(stdout, exitCode) {
            if (exitCode !== 0) {
                if (typeof callback === "function") callback(false)
                return
            }

            try {
                const workspace = JSON.parse(stdout)
                activeWorkspaceId = workspace.id ?? focusedWorkspace?.id ?? 1
                activeWorkspaceMonitor = workspace.monitor ?? focusedWorkspace?.monitor?.name ?? ""
                activeWorkspaceWindows = workspace.windows ?? -1
                if (typeof callback === "function") callback(true)
            } catch(e) {
                if (typeof callback === "function") callback(false)
            }
        }, 0)
    }

    function updateBoardForFocusedWorkspace() {
        if (boardLoader.item && boardLoader.item.isPinned) {
            return
        }

        const isOnThisMonitor = isActiveWorkspaceOnThisMonitor()
        const isEmpty = isActiveWorkspaceEmpty()

        if (windowMoving) {
            return
        }

        if (isOnThisMonitor && isEmpty) {
            shouldShowBoard = true
            mouseHasMoved = false
            lastMousePos = Qt.point(0, 0)
            hideTimer.restart()
        } else {
            shouldShowBoard = false
        }
    }
    
    Connections {
        target: boardLoader.item
        function onMouseInsideChanged() {
            if (boardLoader.item) {
                root.mouseInsideBoard = boardLoader.item.mouseInside
            }
        }
        function onIsPinnedChanged() {
            if (boardLoader.item) {
                if (boardLoader.item.isPinned) {
                    hideTimer.stop()
                    shouldShowBoard = true
                } else {
                    refreshActiveWorkspaceState(function() {
                        if (!isActiveWorkspaceEmpty() || !isActiveWorkspaceOnThisMonitor()) {
                            shouldShowBoard = false
                        }
                    })
                }
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
                if (event.name === "movewindow" || event.name === "openwindow") {
                    windowMoving = true
                    windowMoveTimer.restart()
                    if (shouldShowBoard && boardLoader.item && !boardLoader.item.isPinned) {
                        shouldShowBoard = false
                    }
                }
                Hyprland.refreshWorkspaces()
                refreshActiveWorkspaceState(function() {
                    if (!isActiveWorkspaceEmpty() || !isActiveWorkspaceOnThisMonitor()) {
                        shouldShowBoard = false
                    }
                })
            }
        }
    }
    
    onFocusedWorkspaceChanged: {
        if (previousWorkspace !== currentWorkspace && previousWorkspace !== 0) {
            refreshActiveWorkspaceState(function() {
                updateBoardForFocusedWorkspace()
            })
        }
        previousWorkspace = currentWorkspace
    }
    
    onMouseInsideBoardChanged: {
        if (boardLoader.item && boardLoader.item.isPinned) return
        
        if (!mouseInsideBoard && shouldShowBoard && mouseHasMoved) {
            hideTimer.restart()
        } else if (mouseInsideBoard && mouseHasMoved) {
            hideTimer.stop()
        }
    }
    
    onMouseHasMovedChanged: {
        if (boardLoader.item && boardLoader.item.isPinned) return
        
        if (mouseHasMoved && mouseInsideBoard && shouldShowBoard) {
            hideTimer.stop()
        }
    }
    
    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: {
            if (boardLoader.item && boardLoader.item.isPinned) return
            
            if (!mouseInsideBoard || !mouseHasMoved) {
                shouldShowBoard = false
            }
        }
    }
    
    Timer {
        id: windowMoveTimer
        interval: 300
        onTriggered: {
            windowMoving = false
        }
    }
    
    Loader {
        id: boardLoader
        active: shouldShowBoard
        source: "./Board.qml"
        
        onLoaded: {
            if (item) {
                item.screen = modelData
            }
        }
    }
    
    Component.onCompleted: {
        Hyprland.refreshWorkspaces()
        refreshActiveWorkspaceState()
    }
}
