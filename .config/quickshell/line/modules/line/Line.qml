import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../../../shared/ribbon"

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    required property int lineBarWidth
    required property bool barOnRight
    property var workspaceRows: []
    property string monitorsJson: ""
    property string workspacesJson: ""

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

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2"
                    || event.name === "movewindow" || event.name === "openwindow" || event.name === "closewindow"
                    || event.name === "moveworkspace" || event.name === "createworkspace" || event.name === "destroyworkspace") {
                refreshDebounce.restart();
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 50
        onTriggered: refreshWorkspaceRows()
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.monitorsJson = text || "";
                root.buildWorkspaceRows();
            }
        }
    }

    Process {
        id: workspacesProc
        command: ["hyprctl", "workspaces", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.workspacesJson = text || "";
                root.buildWorkspaceRows();
            }
        }
    }

    Process {
        id: dispatchProc
        running: false
    }

    function refreshWorkspaceRows() {
        if (!monitorsProc.running) monitorsProc.running = true;
        if (!workspacesProc.running) workspacesProc.running = true;
    }

    function workspaceBase(workspaceId) {
        if (!workspaceId || workspaceId <= 0) return 1;
        return workspaceId - ((workspaceId - 1) % 10);
    }

    function dispatchWorkspace(target) {
        dispatchProc.command = ["hyprctl", "dispatch", "workspace", String(target)];
        dispatchProc.running = true;
    }

    function buildWorkspaceRows() {
        if (!monitorsJson || !workspacesJson) return;

        try {
            const monitors = JSON.parse(monitorsJson);
            const workspaces = JSON.parse(workspacesJson);
            const monitorName = currentMonitor?.name ?? "";
            const monitor = monitors.find(mon => mon.name === monitorName);
            const activeId = monitor?.activeWorkspace?.id ?? currentMonitor?.activeWorkspace?.id ?? 1;
            const base = workspaceBase(activeId);
            const rows = [];

            for (let offset = 0; offset < 10; offset++) {
                const id = base + offset;
                const matches = workspaces.filter(ws => ws.id === id && ws.monitor === monitorName);
                let windows = 0;

                for (const ws of matches) {
                    windows = Math.max(windows, ws.windows ?? 0);
                }

                rows.push({
                    id: id,
                    active: id === activeId,
                    windows: windows
                });
            }

            workspaceRows = rows;
        } catch (e) {
            console.warn("line workspace parse error:", e);
        }
    }

    Ribbon {
        id: lineWindow
        screen: root.modelData
        sideRight: root.barOnRight
        ribbonWidth: root.lineBarWidth
        trackHeight: root.monitorHeight * 0.5
        pillSpacing: 10
        onWheel: angleDelta => {
            const direction = angleDelta.y > 0 ? "r-1" : "r+1";
            root.dispatchWorkspace(direction);
        }

        Repeater {
            model: root.workspaceRows
            delegate: Rectangle {
                required property var modelData
                readonly property bool hasWindows: modelData.windows > 0
                visible: true
                width: lineWindow.pillWidth
                height: Math.max(8, (lineWindow.trackHeight - (lineWindow.pillSpacing * 9)) / 10)
                radius: 4
                color: modelData.active ? wal.adapter.colors["color1"] :
                       hasWindows ? wal.adapter.colors["color244"] :
                       wal.adapter.colors["color240"]
                opacity: modelData.active ? 1.0 :
                         wsMouseArea.containsMouse ? 0.9 : 0.6
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    id: wsMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dispatchWorkspace(modelData.id)
                }
            }
        }

        Component.onCompleted: refreshWorkspaceRows()
    }
}
