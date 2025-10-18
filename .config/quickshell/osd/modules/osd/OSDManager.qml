import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    required property var modelData
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    readonly property int monitorHeight: modelData ? modelData.height : 1080
    readonly property int monitorWidth: modelData ? modelData.width : 1920
    
    property string positionMode: "auto"
    property string mainMonitorName: "eDP-1"

    readonly property int thisCenterX: modelData ? modelData.x + (modelData.width / 2) : 0
    
    readonly property int mainCenterX: {
        const allScreens = Quickshell.screens;
        for (let i = 0; i < allScreens.length; i++) {
            const screen = allScreens[i];
            const mon = Hyprland.monitorFor(screen);
            if (mon && mon.name === mainMonitorName) {
                const centerX = screen.x + (screen.width / 2);
                return centerX;
            }
        }
        const firstScreen = allScreens[0];
        return firstScreen ? firstScreen.x + (firstScreen.width / 2) : 0;
    }
    
    readonly property bool isMainMonitor: currentMonitor && currentMonitor.name === mainMonitorName
    
    readonly property bool barOnRight: {
        if (positionMode === "left") return false;
        if (positionMode === "right") return true;
        if (isMainMonitor) return false;
        return thisCenterX < mainCenterX;
    }
    
    readonly property bool osdOnLeft: barOnRight

    VolumeOSD {
        modelData: root.modelData
        currentMonitor: root.currentMonitor
        monitorHeight: root.monitorHeight
        monitorWidth: root.monitorWidth
        osdOnLeft: root.osdOnLeft
    }

    BrightnessOSD {
        modelData: root.modelData
        currentMonitor: root.currentMonitor
        monitorHeight: root.monitorHeight
        monitorWidth: root.monitorWidth
        osdOnLeft: root.osdOnLeft
    }
}
