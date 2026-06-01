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
    required property real lineBarWidth
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

    PanelWindow {
        id: lineWindow
        screen: modelData
        anchors {
            top: true
            left: !barOnRight
            right: barOnRight
            bottom: true
        }
        implicitWidth: lineBarWidth
        color: "transparent"

        Rectangle {
            id: box
            anchors { fill: parent; margins: 0 }
            color: "#000000"
            opacity: 0.95
            Behavior on color { ColorAnimation { duration: 300 } }

            Column {
                id: wsContainer
                anchors {
                    left: barOnRight ? undefined : parent.left
                    right: barOnRight ? parent.right : undefined
                    verticalCenter: parent.verticalCenter
                }
                width: parent.width * 0.7
                height: monitorHeight * 0.5
                spacing: 10
                Repeater {
                    model: root.workspaceRows
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool hasWindows: modelData.windows > 0
                        visible: true
                        width: wsContainer.width
                        height: wsContainer.height / 10
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
            }

            // Scroll overlay: accepts wheel events without blocking clicks
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const direction = wheel.angleDelta.y > 0 ? "r-1" : "r+1";
                    root.dispatchWorkspace(direction);
                }
            }
        }

        Component.onCompleted: {
            refreshWorkspaceRows();
        }
    }
}
