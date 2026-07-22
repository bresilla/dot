import Quickshell
import Quickshell.Io
import QtQuick
import "." as S
import "../../../shared/ribbon"

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    required property bool settingsOnRight
    readonly property string brightCommand: Quickshell.env("HOME") + "/.config/profile/functions/system/bright"

    // ─── Dimensions ───

    readonly property int barWidth: Math.round(monitorWidth * 0.005)
    readonly property int borderPadding: Math.round(Math.min(monitorWidth, monitorHeight) * (6 / 2160))
    readonly property int reservedThickness: barWidth + borderPadding
    readonly property real pillGap: Math.min(monitorWidth, monitorHeight) * (10 / 2160)
    readonly property real pillH: (monitorHeight * 0.5 - (pillGap * 9)) / 10
    readonly property real buttonSize: pillH

    // Panel layout (board-style)
    readonly property real panelWidth: monitorWidth * 0.2
    readonly property real panelPad: Math.min(monitorWidth, monitorHeight) * (12 / 2160)
    readonly property real cardPad: Math.min(monitorWidth, monitorHeight) * (8 / 2160)
    readonly property real rowH: pillH * 0.65
    readonly property real appRowH: pillH * 0.5
    readonly property real iconSize: rowH * 0.85
    readonly property real appSpacing: Math.min(monitorWidth, monitorHeight) * (6 / 2160)
    readonly property real popupGap: Math.min(monitorWidth, monitorHeight) * (24 / 2160)
    readonly property real popupSlide: Math.min(monitorWidth, monitorHeight) * (46 / 2160)
    readonly property real progressLineHeight: monitorHeight * 0.005

    // Card heights
    readonly property real mainCardH: cardPad * 2 + rowH
    readonly property int visibleApps: Math.min(sinkInputs.length, 5)
    readonly property real appCardH: visibleApps > 0
        ? (cardPad * 2 + visibleApps * appRowH + Math.max(0, visibleApps - 1) * appSpacing)
        : 0
    readonly property real volPanelH: panelPad + mainCardH + (visibleApps > 0 ? panelPad + appCardH : 0) + panelPad
    readonly property real brightPanelH: panelPad * 2 + mainCardH

    // Extension Y derived from the shared ribbon geometry.
    readonly property real ribbonTrackY: (monitorHeight - barPanel.trackHeight) / 2
    readonly property real volExtY: ribbonTrackY + volPillRect.y
    readonly property real brightExtY: ribbonTrackY + brightPillRect.y

    // ─── Volume state ───

    property bool volPillHovered: false
    property bool volExtHovered: false
    property bool volumeExpanded: false
    property bool volInteracting: false
    property bool volPanelShown: false
    property bool volWidePanel: false
    property real volBubbleMorph: 0.0
    property real volExpandMorph: 0.0

    property real volume: 0.5
    property bool isMuted: false
    property bool isHeadphone: false
    readonly property string procPrefix: {
        if (currentMonitor && currentMonitor.name) return "settings-" + currentMonitor.name
        if (modelData && modelData.name) return "settings-" + modelData.name
        return "settings-screen-" + String(modelData ? modelData.x : 0) + "-" + String(modelData ? modelData.y : 0)
    }

    function cmdId(suffix) {
        return procPrefix + "-" + suffix
    }

    // Per-app volume
    property var sinkInputs: []
    property bool appVolInteracting: false

    function updateVolPanel() {
        if (volPillHovered || volExtHovered || volInteracting || appVolInteracting) {
            volDismissTimer.stop()
            volPanelShown = true
        } else {
            volDismissTimer.restart()
        }
    }

    onVolPillHoveredChanged: updateVolPanel()
    onVolExtHoveredChanged: updateVolPanel()
    onVolumeExpandedChanged: {
        updateVolPanel()
        if (volumeExpanded) {
            volShrinkTimer.stop()
            volWidePanel = true
            volExpandMorphOut.stop()
            volExpandMorphIn.start()
        } else {
            volExpandMorphIn.stop()
            volExpandMorphOut.start()
            volShrinkTimer.start()
        }
    }
    onVolInteractingChanged: updateVolPanel()
    onAppVolInteractingChanged: updateVolPanel()
    onVolPanelShownChanged: {
        if (volPanelShown) {
            volPanelMorphOut.stop()
            volPanelMorphIn.start()
        } else {
            volPanelMorphIn.stop()
            volPanelMorphOut.start()
        }
    }

    Timer { id: volDismissTimer; interval: 300; onTriggered: { volPanelShown = false; volumeExpanded = false } }
    Timer { id: volShrinkTimer; interval: 260; onTriggered: volWidePanel = false }
    Timer { id: volAutoHideTimer; interval: 30000; onTriggered: volumeExpanded = false }

    NumberAnimation {
        id: volPanelMorphIn
        target: root
        property: "volBubbleMorph"
        from: 0
        to: 1
        duration: 240
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: volPanelMorphOut
        target: root
        property: "volBubbleMorph"
        from: 1
        to: 0
        duration: 180
        easing.type: Easing.InCubic
    }

    NumberAnimation {
        id: volExpandMorphIn
        target: root
        property: "volExpandMorph"
        from: volExpandMorph
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: volExpandMorphOut
        target: root
        property: "volExpandMorph"
        from: volExpandMorph
        to: 0
        duration: 220
        easing.type: Easing.InCubic
    }

    // ─── Brightness state ───

    property bool brightPillHovered: false
    property bool brightExtHovered: false
    property bool brightnessExpanded: false
    property bool brightInteracting: false
    property bool brightPanelShown: false
    property bool brightWidePanel: false
    property real brightBubbleMorph: 0.0
    property real brightExpandMorph: 0.0

    property real brightness: 0.7

    function updateBrightPanel() {
        if (brightPillHovered || brightExtHovered || brightInteracting) {
            brightDismissTimer.stop()
            brightPanelShown = true
        } else {
            brightDismissTimer.restart()
        }
    }

    onBrightPillHoveredChanged: updateBrightPanel()
    onBrightExtHoveredChanged: updateBrightPanel()
    onBrightnessExpandedChanged: {
        updateBrightPanel()
        if (brightnessExpanded) {
            brightShrinkTimer.stop()
            brightWidePanel = true
            brightExpandMorphOut.stop()
            brightExpandMorphIn.start()
        } else {
            brightExpandMorphIn.stop()
            brightExpandMorphOut.start()
            brightShrinkTimer.start()
        }
    }
    onBrightInteractingChanged: updateBrightPanel()
    onBrightPanelShownChanged: {
        if (brightPanelShown) {
            brightPanelMorphOut.stop()
            brightPanelMorphIn.start()
        } else {
            brightPanelMorphIn.stop()
            brightPanelMorphOut.start()
        }
    }

    Timer { id: brightDismissTimer; interval: 300; onTriggered: { brightPanelShown = false; brightnessExpanded = false } }
    Timer { id: brightShrinkTimer; interval: 260; onTriggered: brightWidePanel = false }
    Timer { id: brightAutoHideTimer; interval: 30000; onTriggered: brightnessExpanded = false }

    NumberAnimation {
        id: brightPanelMorphIn
        target: root
        property: "brightBubbleMorph"
        from: 0
        to: 1
        duration: 240
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: brightPanelMorphOut
        target: root
        property: "brightBubbleMorph"
        from: 1
        to: 0
        duration: 180
        easing.type: Easing.InCubic
    }

    NumberAnimation {
        id: brightExpandMorphIn
        target: root
        property: "brightExpandMorph"
        from: brightExpandMorph
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: brightExpandMorphOut
        target: root
        property: "brightExpandMorph"
        from: brightExpandMorph
        to: 0
        duration: 220
        easing.type: Easing.InCubic
    }

    // ─── Polling ───

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            S.Proc.runCommand(cmdId("mute-poll"), ["pamixer", "--get-mute"], (out, code) => {
                if (code !== 0 || !out) return
                const value = out.trim().toLowerCase()
                isMuted = value === "true" || value === "yes"
            }, 0)
        }
    }

    Timer {
        interval: 750
        running: volumeExpanded || brightnessExpanded
        repeat: true
        triggeredOnStart: true
        onTriggered: {
                if (volumeExpanded && !volInteracting) {
                    S.Proc.runCommand(cmdId("vol"), ["pamixer", "--get-volume"], (out, code) => {
                        if (code === 0 && out) volume = parseInt(out.trim()) / 100
                    }, 0)
                }
            if (brightnessExpanded && !brightInteracting) {
                S.Proc.runCommand(cmdId("bright"), [brightCommand, "get"], (out, code) => {
                    if (code === 0 && out) brightness = parseFloat(out.trim()) / 100
                }, 0)
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            S.Proc.runCommand(cmdId("sink"), ["bash", "-c",
                "default_sink=$(pactl get-default-sink | tr -d '\\n'); pactl list sinks | awk -v target=\"$default_sink\" '/^\\s*Name: /{enabled = ($2 == target)} /^\\s*Active Port:/ {if (enabled){print; exit}}' | tr 'A-Z' 'a-z' | grep -qiE 'headphone|headset|bluez' && echo true || echo false"
            ], (out, code) => {
                if (code === 0 && out) isHeadphone = out.trim() === "true"
            }, 0)
        }
    }

    // Per-app sink input polling
    Timer {
        interval: 1500
        running: volumeExpanded && !appVolInteracting
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            S.Proc.runCommand(cmdId("sink-inputs"), ["pactl", "list", "sink-inputs"], (out, code) => {
                if (code !== 0 || !out) { sinkInputs = []; return }
                let inputs = []
                const blocks = out.split(/\nSink Input #/)
                for (const block of blocks) {
                    if (!block.trim()) continue
                    const idxMatch = block.match(/(\d+)/)
                    const nameMatch = block.match(/application\.name = "([^"]+)"/)
                    const volMatch = block.match(/Volume:.*?(\d+)%/)
                    if (idxMatch && nameMatch && volMatch) {
                        inputs.push({
                            index: parseInt(idxMatch[1]),
                            name: nameMatch[1],
                            volume: parseInt(volMatch[1]) / 100
                        })
                    }
                }
                sinkInputs = inputs
            }, 0)
        }
    }

    // ─── Icons ───

    readonly property string volumeIcon: {
        if (isHeadphone) return "\u{f02cb}"
        return "\u{f057e}"
    }

    readonly property string brightnessIcon: {
        return "\u{f00e0}"
    }

    // ═══════════════════════════════════════════════
    // Bar — identical to Line.qml, pills always visible
    // ═══════════════════════════════════════════════

    Ribbon {
        id: barPanel
        screen: root.modelData
        sideRight: root.settingsOnRight
        ribbonWidth: root.barWidth
        trackHeight: (root.pillH * 2) + root.pillGap
        pillSpacing: root.pillGap

        Rectangle {
            id: volPillRect
            width: barPanel.pillWidth
            height: pillH
            radius: S.Theme.pillRadius
            color: volumeExpanded ? S.Theme.color1 : S.Theme.color240
            opacity: volumeExpanded ? 1.0 :
                     volPillMouse.containsMouse ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                id: volPillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: volPillHovered = containsMouse
                onClicked: if (volumeExpanded) volumeExpanded = false
            }
        }

        Rectangle {
            id: brightPillRect
            width: barPanel.pillWidth
            height: pillH
            radius: S.Theme.pillRadius
            color: brightnessExpanded ? S.Theme.color1 : S.Theme.color240
            opacity: brightnessExpanded ? 1.0 :
                     brightPillMouse.containsMouse ? 0.9 : 0.6

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                id: brightPillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: brightPillHovered = containsMouse
                onClicked: if (brightnessExpanded) brightnessExpanded = false
            }
        }
    }

    // ═══════════════════════════════════════════════
    // Volume extension — board-style panel
    // ═══════════════════════════════════════════════

    RibbonPopup {
        id: volExtPanel
        screen: root.modelData
        sideRight: root.settingsOnRight
        popupY: root.volExtY
        ribbonWidth: root.barWidth
        reservedThickness: root.reservedThickness
        expanded: root.volWidePanel
        expandProgress: root.volExpandMorph
        popupGap: root.popupGap
        popupSlide: root.popupSlide
        visible: volPanelShown || volPanelMorphOut.running

        readonly property real compactW: buttonSize + popupSlide + (popupGap * 0.33)
        readonly property real compactH: pillH
        readonly property real morphEase: volExpandMorph * volExpandMorph * (3 - (2 * volExpandMorph))

        implicitWidth: Math.round(compactW + ((panelWidth - compactW) * morphEase))
        implicitHeight: Math.round(compactH + ((volPanelH - compactH) * morphEase))

        Item {
            anchors.fill: parent
            opacity: 1.0

            // Icon button (only when hovering, not expanded, not dismissing)
            Rectangle {
                visible: (volPanelShown || volPanelMorphOut.running) && volExpandMorph < 0.98
                readonly property real startWidth: barPanel.pillWidth
                readonly property real startHeight: pillH
                readonly property real endSize: buttonSize

                width: startWidth + (endSize - startWidth) * (volBubbleMorph * volBubbleMorph)
                height: startHeight + (endSize - startHeight) * volBubbleMorph
                radius: S.Theme.pillRadius + ((endSize * 0.5 - S.Theme.pillRadius) * volBubbleMorph)
                color: isMuted ? S.Theme.color240 : S.Theme.color1
                opacity: 1 - volExpandMorph
                z: 1
                anchors {
                    right: settingsOnRight ? parent.right : undefined
                    left: !settingsOnRight ? parent.left : undefined
                    leftMargin: settingsOnRight ? 0 : volExtPanel.popupSlide * volBubbleMorph
                    rightMargin: settingsOnRight ? volExtPanel.popupSlide * volBubbleMorph : 0
                    verticalCenter: parent.verticalCenter
                }
                border.color: S.Theme.color0
                border.width: S.Theme.heavyBorderWidth + (S.Theme.morphBorderGrowth * volBubbleMorph)

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: volumeIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: Math.round(Math.min(width, height) * 0.495)
                    font.bold: true
                    font.weight: Font.Black
                    color: S.Theme.color0
                }

                Rectangle {
                    id: volBubbleMuteLine
                    anchors.centerIn: parent
                    width: Math.sqrt((parent.width * parent.width) + (parent.height * parent.height)) * 0.5
                    height: S.Theme.slashThickness
                    color: S.Theme.color0
                    rotation: -45
                    radius: S.Theme.tinyRadius
                    visible: isMuted
                    opacity: 0.9
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!volumeExpanded) volumeExpanded = true
                }
            }

            // Board-style container morphs from the round icon footprint into the full widget.
            Rectangle {
                visible: volWidePanel || volExpandMorph > 0
                readonly property real surfaceW: buttonSize + ((parent.width - buttonSize) * volExtPanel.morphEase)
                readonly property real surfaceH: buttonSize + ((parent.height - buttonSize) * volExtPanel.morphEase)

                width: surfaceW
                height: surfaceH
                x: settingsOnRight
                    ? parent.width - surfaceW - (volExtPanel.popupSlide * (1 - volExtPanel.morphEase))
                    : volExtPanel.popupSlide * (1 - volExtPanel.morphEase)
                y: 0
                color: S.Theme.color238
                radius: (buttonSize * 0.5) + ((S.Theme.panelRadius - (buttonSize * 0.5)) * volExtPanel.morphEase)
                opacity: volExpandMorph
                border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08 * volExpandMorph)
                border.width: S.Theme.borderWidth

                Column {
                    anchors.fill: parent
                    anchors.margins: panelPad
                    spacing: panelPad
                    opacity: volExtPanel.morphEase
                    visible: volExpandMorph > 0.08

                    // ── Main volume card ──
                    Rectangle {
                        width: parent.width
                        height: mainCardH
                        radius: S.Theme.cornerRadius
                        color: S.Theme.color236
                        border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08)
                        border.width: S.Theme.borderWidth

                        Row {
                            anchors.fill: parent
                            anchors.margins: cardPad
                            spacing: cardPad

                            Rectangle {
                                width: iconSize
                                height: iconSize
                                radius: width / 2
                                color: Qt.rgba(S.Theme.primary.r, S.Theme.primary.g, S.Theme.primary.b, isMuted ? 0.05 : 0.15)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: volumeIcon
                                    font.family: "IosevkaTerm Nerd Font Mono"
                                    font.pixelSize: parent.width * 0.5
                                    color: isMuted ? S.Theme.outline : S.Theme.primary
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.sqrt((parent.width * parent.width) + (parent.height * parent.height)) * 0.5
                                    height: S.Theme.slashThickness
                                    color: isMuted ? S.Theme.color0 : "transparent"
                                    rotation: -45
                                    radius: S.Theme.tinyRadius
                                    opacity: 0.95
                                    visible: isMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        isMuted = !isMuted
                                        S.Proc.runCommand(cmdId("mute-toggle"), ["pamixer", "-t"], () => {}, 0)
                                        volAutoHideTimer.restart()
                                    }
                                }
                            }

                            ProgressBar {
                                width: parent.width - iconSize - parent.spacing
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                value: volume
                                lineHeight: root.progressLineHeight
                                fillColor: S.Theme.primary
                                trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                indicatorColor: S.Theme.primary
                                showIndicator: true
                                interactive: true

                                onSeeking: pos => {
                                    volInteracting = true
                                    volume = pos
                                    volAutoHideTimer.restart()
                                    S.Proc.runCommand(cmdId("vol-set"), ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 50)
                                }

                                onClicked: pos => {
                                    volume = pos
                                    volInteracting = false
                                    volAutoHideTimer.restart()
                                    S.Proc.runCommand(cmdId("vol-set"), ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 0)
                                }
                            }
                        }
                    }

                    // ── Per-app volume card ──
                    Rectangle {
                        visible: sinkInputs.length > 0
                        width: parent.width
                        height: appCardH
                        radius: S.Theme.cornerRadius
                        color: S.Theme.color236
                        border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08)
                        border.width: S.Theme.borderWidth

                        Column {
                            anchors.fill: parent
                            anchors.margins: cardPad
                            spacing: appSpacing

                            Repeater {
                                model: sinkInputs.slice(0, 5)

                                Item {
                                    required property var modelData
                                    width: parent.width
                                    height: appRowH
                                    property real appVol: modelData.volume

                                    Row {
                                        anchors.fill: parent
                                        spacing: cardPad

                                        Text {
                                            width: parent.width * 0.25
                                            height: parent.height
                                            text: modelData.name
                                            elide: Text.ElideRight
                                            font.family: "IosevkaTerm Nerd Font Mono"
                                            font.pixelSize: appRowH * 0.45
                                            color: Qt.rgba(S.Theme.primary.r, S.Theme.primary.g, S.Theme.primary.b, 0.7)
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        ProgressBar {
                                            width: parent.width * 0.75 - parent.spacing
                                            height: parent.height
                                            anchors.verticalCenter: parent.verticalCenter
                                            value: appVol
                                            lineHeight: root.progressLineHeight
                                            fillColor: S.Theme.primary
                                            trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                            indicatorColor: S.Theme.primary
                                            showIndicator: true
                                            interactive: true

                                            onSeeking: pos => {
                                                appVol = pos
                                                appVolInteracting = true
                                                volAutoHideTimer.restart()
                                                S.Proc.runCommand(cmdId("app-vol-" + modelData.index),
                                                    ["pactl", "set-sink-input-volume", String(modelData.index), String(Math.round(pos * 100)) + "%"],
                                                    () => {}, 50)
                                            }

                                            onClicked: pos => {
                                                appVol = pos
                                                appVolInteracting = false
                                                volAutoHideTimer.restart()
                                                S.Proc.runCommand(cmdId("app-vol-" + modelData.index),
                                                    ["pactl", "set-sink-input-volume", String(modelData.index), String(Math.round(pos * 100)) + "%"],
                                                    () => {}, 0)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Hover tracking (LAST child = on top of everything)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: volExtHovered = containsMouse
            }
        }
    }

    // ═══════════════════════════════════════════════
    // Brightness extension — board-style panel
    // ═══════════════════════════════════════════════

    RibbonPopup {
        id: brightExtPanel
        screen: root.modelData
        sideRight: root.settingsOnRight
        popupY: root.brightExtY
        ribbonWidth: root.barWidth
        reservedThickness: root.reservedThickness
        expanded: root.brightWidePanel
        expandProgress: root.brightExpandMorph
        popupGap: root.popupGap
        popupSlide: root.popupSlide
        visible: brightPanelShown || brightPanelMorphOut.running

        readonly property real compactW: buttonSize + popupSlide + (popupGap * 0.33)
        readonly property real compactH: pillH
        readonly property real morphEase: brightExpandMorph * brightExpandMorph * (3 - (2 * brightExpandMorph))

        implicitWidth: Math.round(compactW + ((panelWidth - compactW) * morphEase))
        implicitHeight: Math.round(compactH + ((brightPanelH - compactH) * morphEase))

        Item {
            anchors.fill: parent
            opacity: 1.0

            // Icon button (only when hovering, not expanded, not dismissing)
            Rectangle {
                visible: (brightPanelShown || brightPanelMorphOut.running) && brightExpandMorph < 0.98
                readonly property real startWidth: barPanel.pillWidth
                readonly property real startHeight: pillH
                readonly property real endSize: buttonSize

                width: startWidth + (endSize - startWidth) * (brightBubbleMorph * brightBubbleMorph)
                height: startHeight + (endSize - startHeight) * brightBubbleMorph
                radius: S.Theme.pillRadius + ((endSize * 0.5 - S.Theme.pillRadius) * brightBubbleMorph)
                color: S.Theme.color1
                opacity: 1 - brightExpandMorph
                z: 1
                anchors {
                    right: settingsOnRight ? parent.right : undefined
                    left: !settingsOnRight ? parent.left : undefined
                    leftMargin: settingsOnRight ? 0 : brightExtPanel.popupSlide * brightBubbleMorph
                    rightMargin: settingsOnRight ? brightExtPanel.popupSlide * brightBubbleMorph : 0
                    verticalCenter: parent.verticalCenter
                }
                border.color: S.Theme.color0
                border.width: S.Theme.heavyBorderWidth + (S.Theme.morphBorderGrowth * brightBubbleMorph)

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: brightnessIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: Math.round(Math.min(width, height) * 0.495)
                    font.bold: true
                    font.weight: Font.Black
                    color: S.Theme.color0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!brightnessExpanded) brightnessExpanded = true
                }
            }

            // Board-style container morphs from the round icon footprint into the full widget.
            Rectangle {
                visible: brightWidePanel || brightExpandMorph > 0
                readonly property real surfaceW: buttonSize + ((parent.width - buttonSize) * brightExtPanel.morphEase)
                readonly property real surfaceH: buttonSize + ((parent.height - buttonSize) * brightExtPanel.morphEase)

                width: surfaceW
                height: surfaceH
                x: settingsOnRight
                    ? parent.width - surfaceW - (brightExtPanel.popupSlide * (1 - brightExtPanel.morphEase))
                    : brightExtPanel.popupSlide * (1 - brightExtPanel.morphEase)
                y: 0
                color: S.Theme.color238
                radius: (buttonSize * 0.5) + ((S.Theme.panelRadius - (buttonSize * 0.5)) * brightExtPanel.morphEase)
                opacity: brightExpandMorph
                border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08 * brightExpandMorph)
                border.width: S.Theme.borderWidth

                Column {
                    anchors.fill: parent
                    anchors.margins: panelPad
                    spacing: panelPad
                    opacity: brightExtPanel.morphEase
                    visible: brightExpandMorph > 0.08

                    Rectangle {
                        width: parent.width
                        height: mainCardH
                        radius: S.Theme.cornerRadius
                        color: S.Theme.color236
                        border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08)
                        border.width: S.Theme.borderWidth

                        Row {
                            anchors.fill: parent
                            anchors.margins: cardPad
                            spacing: cardPad

                            Rectangle {
                                width: iconSize
                                height: iconSize
                                radius: width / 2
                                color: Qt.rgba(S.Theme.primary.r, S.Theme.primary.g, S.Theme.primary.b, 0.15)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: brightnessIcon
                                    font.family: "IosevkaTerm Nerd Font Mono"
                                    font.pixelSize: parent.width * 0.5
                                    color: S.Theme.primary
                                }
                            }

                            ProgressBar {
                                width: parent.width - iconSize - parent.spacing
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                value: brightness
                                lineHeight: root.progressLineHeight
                                fillColor: S.Theme.primary
                                trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                indicatorColor: S.Theme.primary
                                showIndicator: true
                                interactive: true

                                onSeeking: pos => {
                                    brightInteracting = true
                                    brightness = pos
                                    brightAutoHideTimer.restart()
                                    S.Proc.runCommand(cmdId("bright-set"), [brightCommand, String(Math.round(pos * 100))], () => {}, 50)
                                }

                                onClicked: pos => {
                                    brightness = pos
                                    brightInteracting = false
                                    brightAutoHideTimer.restart()
                                    S.Proc.runCommand(cmdId("bright-set"), [brightCommand, String(Math.round(pos * 100))], () => {}, 0)
                                }
                            }
                        }
                    }
                }
            }

            // Hover tracking (LAST child = on top of everything)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: brightExtHovered = containsMouse
            }
        }
    }
}
