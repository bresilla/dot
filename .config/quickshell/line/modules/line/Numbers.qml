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
    property bool shouldShowOSD: false
    property real morphProgress: 0.0
    property real displayY: 0
    property int lastShownWorkspace: -1

    readonly property int containerHeight: monitorHeight * 0.5
    readonly property int itemHeight: containerHeight / 10
    readonly property int wsSpacing: 10

    function getWorkspaceYOffset(workspaceId) {
        var index = (workspaceId - 1) % 10;
        if (index < 0) index = 0;
        return (itemHeight + wsSpacing) * index;
    }

    // --- Animations: morph (shape) and slide (position) are independent ---

    NumberAnimation {
        id: slideAnim
        target: root
        property: "displayY"
        duration: 250
        easing.type: Easing.InOutQuad
    }

    function slideTo(targetY) {
        slideAnim.stop();
        slideAnim.from = displayY;
        slideAnim.to = targetY;
        slideAnim.start();
    }

    NumberAnimation {
        id: morphInAnim
        target: root
        property: "morphProgress"
        from: 0; to: 1
        duration: 400
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: morphOutAnim
        target: root
        property: "morphProgress"
        from: 1; to: 0
        duration: 300
        easing.type: Easing.InCubic
        onFinished: shouldShowOSD = false
    }

    Timer {
        id: hideTimer
        interval: 800
        onTriggered: morphOutAnim.start()
    }

    onFocusedWorkspaceChanged: {
        if (!focusedWorkspace) return;

        const wsId = focusedWorkspace.id;
        const monName = focusedWorkspace.monitor?.name ?? "";
        const isThisMonitor = monName === currentMonitor?.name;

        if (!isThisMonitor) return;

        const targetOffset = getWorkspaceYOffset(wsId);

        if (!shouldShowOSD) {
            // Fresh show: slide from previous position if different workspace
            if (lastShownWorkspace >= 0 && lastShownWorkspace !== wsId) {
                displayY = getWorkspaceYOffset(lastShownWorkspace);
                slideTo(targetOffset);
            } else {
                displayY = targetOffset;
            }
            shouldShowOSD = true;
            morphOutAnim.stop();
            morphProgress = 0;
            morphInAnim.start();
        } else if (morphOutAnim.running) {
            // Was fading out: cancel and stay
            morphOutAnim.stop();
            morphProgress = 1.0;
            if (lastShownWorkspace !== wsId) slideTo(targetOffset);
        } else {
            // Already visible: slide if workspace changed
            if (lastShownWorkspace !== wsId) slideTo(targetOffset);
        }

        hideTimer.restart();
        lastShownWorkspace = wsId;
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
        implicitHeight: containerHeight + (wsSpacing * 9)

        exclusiveZone: 0
        color: "#00000000"
        mask: Region {}

        readonly property int lineWidth: Screen.width * 0.005
        readonly property int containerStartY: (monitorHeight - containerHeight) / 2

        margins {
            left: barOnRight ? 0 : -lineWidth
            right: barOnRight ? -lineWidth : 0
            top: containerStartY
        }

        Rectangle {
            id: morphingOSD

            anchors {
                left: barOnRight ? undefined : parent.left
                right: barOnRight ? parent.right : undefined
                leftMargin: barOnRight ? 0 : 30 * morphProgress
                rightMargin: barOnRight ? 30 * morphProgress : 0
            }

            y: displayY

            readonly property real startWidth: osdWindow.lineWidth * 0.7
            readonly property real startHeight: root.itemHeight
            readonly property real endSize: 110

            width: startWidth + (endSize - startWidth) * (morphProgress * morphProgress)
            height: startHeight + (endSize - startHeight) * morphProgress
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
                opacity: morphProgress
            }
        }
    }
}
