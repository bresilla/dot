import Quickshell
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root
    required property var modelData
    readonly property var currentMonitor: Hyprland.monitorFor(modelData)
    readonly property int monitorHeight: modelData ? modelData.height : 1080
    readonly property int monitorWidth: modelData ? modelData.width : 1920

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
