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

    property var focusedWorkspace: Hyprland.focusedWorkspace
    property int currentWorkspace: focusedWorkspace?.id ?? 1
    property int previousWorkspace: currentWorkspace
    property bool shouldShowOSD: false
    property real morphProgress: 0.0
    
    readonly property int containerHeight: monitorHeight * 0.5
    readonly property int itemHeight: containerHeight / 10
    readonly property int spacing: 10
    readonly property int containerStartY: (monitorHeight - containerHeight) / 2
    
    function getWorkspaceYOffset(workspaceId) {
        var index = workspaceId - 1;
        var offset = (itemHeight * index) + (spacing * index);
        console.log("getWorkspaceYOffset for ws", workspaceId, "index:", index, "offset:", offset);
        return offset;
    }
    
    property real startYOffset: 0
    property real endYOffset: 0
    property real currentYOffset: 0
    
    onCurrentWorkspaceChanged: {
        const isOnThisMonitor = focusedWorkspace && focusedWorkspace.monitor === currentMonitor;
        
        if (isOnThisMonitor && previousWorkspace !== currentWorkspace) {
            startYOffset = getWorkspaceYOffset(previousWorkspace);
            endYOffset = getWorkspaceYOffset(currentWorkspace);
            currentYOffset = startYOffset;
            console.log("Switching from ws", previousWorkspace, "to", currentWorkspace);
            console.log("startYOffset:", startYOffset, "endYOffset:", endYOffset);
            shouldShowOSD = true;
            morphProgress = 0.0;
            morphInAnimation.start();
            hideTimer.restart();
            previousWorkspace = currentWorkspace;
        } else if (!isOnThisMonitor) {
            shouldShowOSD = false;
        }
    }
    
    NumberAnimation {
        id: morphInAnimation
        target: root
        property: "morphProgress"
        from: 0.0
        to: 1.0
        duration: 600
        easing.type: Easing.OutCubic
        onRunningChanged: {
            if (!running) {
                currentYOffset = endYOffset;
            }
        }
    }
    
    onMorphProgressChanged: {
        if (morphInAnimation.running) {
            currentYOffset = startYOffset + (endYOffset - startYOffset) * morphProgress;
        }
    }
    
    NumberAnimation {
        id: morphOutAnimation
        target: root
        property: "morphProgress"
        from: 1.0
        to: 0.0
        duration: 300
        easing.type: Easing.InCubic
        onFinished: shouldShowOSD = false
    }
    
    Timer {
        id: hideTimer
        interval: 800
        onTriggered: morphOutAnimation.start()
    }
    
    PanelWindow {
        id: osdWindow
        screen: modelData
        visible: shouldShowOSD
        
        anchors {
            left: !barOnRight
            right: barOnRight
            top: true
        }
        
        implicitWidth: 140
        implicitHeight: containerHeight + (spacing * 9)
        
        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}
        
        readonly property int containerHeight: monitorHeight * 0.5
        readonly property int itemHeight: containerHeight / 10
        readonly property int spacing: 10
        readonly property int containerStartY: (monitorHeight - containerHeight) / 2
        readonly property int lineWidth: Screen.width * 0.005
        
        margins {
            left: barOnRight ? 0 : -lineWidth
            right: barOnRight ? -lineWidth : 0
            top: containerStartY
        }
        
        Rectangle {
            id: morphingOSD
            visible: shouldShowOSD
            
            anchors {
                left: barOnRight ? undefined : parent.left
                right: barOnRight ? parent.right : undefined
                leftMargin: barOnRight ? 0 : 30 * morphProgress
                rightMargin: barOnRight ? 30 * morphProgress : 0
            }
            
            y: currentYOffset
            
            readonly property real startWidth: osdWindow.lineWidth * 0.7
            readonly property real startHeight: osdWindow.itemHeight
            readonly property real endSize: 110
            
            readonly property real widthProgress: morphProgress * morphProgress
            readonly property real heightProgress: morphProgress
            
            width: startWidth + (endSize - startWidth) * widthProgress
            height: startHeight + (endSize - startHeight) * heightProgress
            radius: 4 + (51 * morphProgress)
            
            color: wal.adapter.colors["color1"] || "#CC000000"
            border.color: wal.adapter.colors["color0"] || "#000000"
            border.width: 2 + (4 * morphProgress)
            
            Text {
                anchors.centerIn: parent
                text: currentWorkspace
                font.pixelSize: 20 + (30 * morphProgress)
                font.bold: true
                font.weight: Font.Black
                color: wal.adapter.colors["color0"] || "#ffffff"
                opacity: morphProgress > 0.3 ? 1.0 : 0.0
            }
        }
    }
}
