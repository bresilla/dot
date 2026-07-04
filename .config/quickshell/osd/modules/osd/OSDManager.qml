import Quickshell
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    required property var modelData
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    readonly property var referenceScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property int monitorHeight: modelData ? modelData.height : (referenceScreen ? referenceScreen.height : 2160)
    readonly property int monitorWidth: modelData ? modelData.width : (referenceScreen ? referenceScreen.width : 3840)

    property string mainMonitorName: "eDP-1"
    readonly property bool isMainMonitor: currentMonitor && currentMonitor.name === mainMonitorName

    VolumeOSD {
        modelData: root.modelData
        currentMonitor: root.currentMonitor
        monitorHeight: root.monitorHeight
        monitorWidth: root.monitorWidth
        enabled: root.isMainMonitor
    }

    BrightnessOSD {
        modelData: root.modelData
        currentMonitor: root.currentMonitor
        monitorHeight: root.monitorHeight
        monitorWidth: root.monitorWidth
        enabled: root.isMainMonitor
    }

    BatteryOSD {
        modelData: root.modelData
        currentMonitor: root.currentMonitor
        monitorHeight: root.monitorHeight
        monitorWidth: root.monitorWidth
        enabled: root.isMainMonitor
    }
}
