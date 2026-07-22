import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "../../../shared/ribbon"
import "../../../settings/modules/settings" as S

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    required property real lineBarWidth
    required property bool barOnRight

    property var activeWorkspace: currentMonitor?.activeWorkspace
    property int currentWorkspace: 1
    property bool shouldShowOSD: false
    property real morphProgress: 0.0
    property real displayY: 0
    property int lastShownWorkspace: -1

    readonly property real wsSpacing: Math.min(monitorWidth, monitorHeight) * (10 / 2160)
    readonly property int containerHeight: monitorHeight * 0.5
    readonly property real itemHeight: (containerHeight - (wsSpacing * 9)) / 10
    readonly property real pillWidthFactor: 0.55
    readonly property real popupGap: Math.round(Math.min(monitorWidth, monitorHeight) * (6 / 2160))
    readonly property real popupSlide: (lineBarWidth * (1 + ((1 + pillWidthFactor) / 2))) + popupGap
    readonly property real popupBorderWidth: Math.max(1, Math.min(monitorWidth, monitorHeight) * (2 / 2160))
    readonly property real popupBorderGrowth: Math.min(monitorWidth, monitorHeight) * (4 / 2160)

    function readableTextColor(bg) {
        const raw = String(bg || "").replace("#", "");
        if (raw.length < 6) return "#ffffff";

        const r = parseInt(raw.substring(0, 2), 16);
        const g = parseInt(raw.substring(2, 4), 16);
        const b = parseInt(raw.substring(4, 6), 16);
        const luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
        return luminance < 0.45 ? "#ffffff" : "#000000";
    }

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

    function hideThisMonitorOSD() {
        hideTimer.stop();
        morphOutAnim.stop();
        shouldShowOSD = false;
        morphProgress = 0;
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

    function showWorkspace(workspace) {
        if (!workspace) return;

        const wsId = workspace.id;
        showWorkspaceId(wsId);
    }

    function showWorkspaceId(wsId, force) {
        if (!wsId || wsId <= 0) return;

        if (!force && !shouldShowOSD && lastShownWorkspace === wsId) {
            return;
        }

        currentWorkspace = wsId;

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

    onActiveWorkspaceChanged: showWorkspace(activeWorkspace)

    function showFocusedMonitorEvent(event) {
        const data = event.data ?? "";
        const parts = data.split(",");

        if (parts.length < 2 || parts[0] !== currentMonitor?.name) {
            return;
        }

        const wsId = parseInt(parts[1], 10);

        if (!Number.isNaN(wsId)) {
            showWorkspaceId(wsId, true);
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2"
                    || event.name === "moveworkspace") {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            } else if (event.name === "focusedmonv2") {
                showFocusedMonitorEvent(event);
            }
        }
    }

    RibbonPopup {
        id: osdWindow
        screen: modelData
        visible: shouldShowOSD
        sideRight: root.barOnRight
        popupY: osdWindow.containerStartY
        ribbonWidth: Math.round(root.lineBarWidth)
        reservedThickness: Math.round(root.lineBarWidth + 6)
        expanded: false
        expandProgress: 0
        popupGap: root.popupGap
        popupSlide: root.popupSlide

        implicitWidth: Math.round(root.itemHeight + root.popupSlide + (root.popupGap * 0.66))
        implicitHeight: containerHeight

        readonly property real lineWidth: lineBarWidth
        readonly property int containerStartY: (monitorHeight - containerHeight) / 2

        Rectangle {
            id: morphingOSD

            anchors {
                left: barOnRight ? undefined : parent.left
                right: barOnRight ? parent.right : undefined
                leftMargin: barOnRight ? 0 : root.popupSlide * morphProgress
                rightMargin: barOnRight ? root.popupSlide * morphProgress : 0
            }

            y: displayY

            readonly property real startWidth: osdWindow.lineWidth * root.pillWidthFactor
            readonly property real startHeight: root.itemHeight
            readonly property real endSize: root.itemHeight

            width: startWidth + (endSize - startWidth) * (morphProgress * morphProgress)
            height: startHeight + (endSize - startHeight) * morphProgress
            radius: S.Theme.pillRadius + ((endSize * 0.5 - S.Theme.pillRadius) * morphProgress)

            color: S.Theme.color1
            border.color: S.Theme.color0
            border.width: root.popupBorderWidth + (root.popupBorderGrowth * morphProgress)

            Text {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: currentWorkspace
                font.family: "IosevkaTerm Nerd Font Mono"
                font.pixelSize: Math.round(Math.min(width, height) * 0.495)
                font.bold: true
                font.weight: Font.Black
                color: root.readableTextColor(morphingOSD.color)
                opacity: morphProgress
            }
        }
    }
}
