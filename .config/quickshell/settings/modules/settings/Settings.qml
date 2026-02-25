import Quickshell
import Quickshell.Io
import QtQuick
import "." as S

Scope {
    id: root
    required property var modelData
    required property var currentMonitor
    required property int monitorHeight
    required property int monitorWidth
    required property bool settingsOnRight

    // ─── Dimensions ───

    readonly property real barWidth: monitorWidth * 0.005
    readonly property real pillW: barWidth * 0.7
    readonly property real pillH: monitorHeight * 0.5 / 10
    readonly property real pillGap: 10
    readonly property real buttonSize: pillH

    // Panel layout (board-style)
    readonly property real panelWidth: monitorWidth * 0.2
    readonly property real panelPad: 12
    readonly property real cardPad: 8
    readonly property real rowH: pillH * 0.65
    readonly property real appRowH: pillH * 0.5
    readonly property real iconSize: rowH * 0.85
    readonly property real appSpacing: 6

    // Card heights
    readonly property real mainCardH: cardPad * 2 + rowH
    readonly property int visibleApps: Math.min(sinkInputs.length, 5)
    readonly property real appCardH: visibleApps > 0
        ? (cardPad * 2 + visibleApps * appRowH + Math.max(0, visibleApps - 1) * appSpacing)
        : 0
    readonly property real volPanelH: panelPad + mainCardH + (visibleApps > 0 ? panelPad + appCardH : 0) + panelPad
    readonly property real brightPanelH: panelPad * 2 + mainCardH

    // Extension Y derived from actual rendered pill positions
    readonly property real volExtY: settingsColumn.y + volPillRect.y
    readonly property real brightExtY: settingsColumn.y + brightPillRect.y

    // ─── Volume state ───

    property bool volPillHovered: false
    property bool volExtHovered: false
    property bool volumeExpanded: false
    property bool volInteracting: false
    property bool volPanelShown: false
    property bool volWidePanel: false

    property real volume: 0.5
    property bool isMuted: false
    property bool isHeadphone: false

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
        } else {
            volShrinkTimer.start()
        }
    }
    onVolInteractingChanged: updateVolPanel()
    onAppVolInteractingChanged: updateVolPanel()

    Timer { id: volDismissTimer; interval: 300; onTriggered: { volPanelShown = false; volumeExpanded = false } }
    Timer { id: volShrinkTimer; interval: 250; onTriggered: volWidePanel = false }
    Timer { id: volAutoHideTimer; interval: 30000; onTriggered: volumeExpanded = false }

    // ─── Brightness state ───

    property bool brightPillHovered: false
    property bool brightExtHovered: false
    property bool brightnessExpanded: false
    property bool brightInteracting: false
    property bool brightPanelShown: false
    property bool brightWidePanel: false

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
        } else {
            brightShrinkTimer.start()
        }
    }
    onBrightInteractingChanged: updateBrightPanel()

    Timer { id: brightDismissTimer; interval: 300; onTriggered: { brightPanelShown = false; brightnessExpanded = false } }
    Timer { id: brightShrinkTimer; interval: 250; onTriggered: brightWidePanel = false }
    Timer { id: brightAutoHideTimer; interval: 30000; onTriggered: brightnessExpanded = false }

    // ─── Polling (only when expanded) ───

    Timer {
        interval: 300
        running: volumeExpanded || brightnessExpanded
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (volumeExpanded && !volInteracting) {
                S.Proc.runCommand("settings-vol", ["pamixer", "--get-volume"], (out, code) => {
                    if (code === 0 && out) volume = parseInt(out.trim()) / 100
                }, 0)
                S.Proc.runCommand("settings-mute", ["pamixer", "--get-mute"], (out, code) => {
                    if (code === 0 && out) isMuted = out.trim() === "true"
                }, 0)
            }
            if (brightnessExpanded && !brightInteracting) {
                S.Proc.runCommand("settings-bright", ["light", "-G"], (out, code) => {
                    if (code === 0 && out) brightness = parseFloat(out.trim()) / 100
                }, 0)
            }
        }
    }

    Timer {
        interval: 2000
        running: volumeExpanded
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            S.Proc.runCommand("settings-sink", ["bash", "-c",
                "(pactl get-default-sink; pactl list sinks | grep -i 'Active Port') | grep -qiE 'bluez|headphone' && echo true || echo false"
            ], (out, code) => {
                if (code === 0 && out) isHeadphone = out.trim() === "true"
            }, 0)
        }
    }

    // Per-app sink input polling
    Timer {
        interval: 1000
        running: volumeExpanded && !appVolInteracting
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            S.Proc.runCommand("settings-sink-inputs", ["pactl", "list", "sink-inputs"], (out, code) => {
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
        if (isMuted) return isHeadphone ? "\u{f07ce}" : "\u{f0581}"
        if (isHeadphone) return "\u{f02cb}"
        if (volume < 0.33) return "\u{f057f}"
        if (volume < 0.66) return "\u{f0580}"
        return "\u{f057e}"
    }

    readonly property string brightnessIcon: {
        if (brightness < 0.33) return "\u{f00de}"
        if (brightness < 0.66) return "\u{f00df}"
        return "\u{f00e0}"
    }

    // ═══════════════════════════════════════════════
    // Bar — identical to Line.qml, pills always visible
    // ═══════════════════════════════════════════════

    PanelWindow {
        id: barPanel
        screen: modelData
        anchors {
            top: true
            left: !settingsOnRight
            right: settingsOnRight
            bottom: true
        }
        implicitWidth: Screen.width * 0.005
        color: "transparent"

        Rectangle {
            id: box
            anchors { fill: parent; margins: 0 }
            color: "#000000"
            opacity: 0.95
            Behavior on color { ColorAnimation { duration: 300 } }

            Column {
                id: settingsColumn
                anchors {
                    left: settingsOnRight ? undefined : parent.left
                    right: settingsOnRight ? parent.right : undefined
                    verticalCenter: parent.verticalCenter
                }
                width: parent.width * 0.7
                spacing: 10

                Rectangle {
                    id: volPillRect
                    width: settingsColumn.width
                    height: pillH
                    radius: 4
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
                    width: settingsColumn.width
                    height: pillH
                    radius: 4
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
        }
    }

    // ═══════════════════════════════════════════════
    // Volume extension — board-style panel
    // ═══════════════════════════════════════════════

    PanelWindow {
        id: volExtPanel
        screen: modelData
        visible: volPanelShown || volFadeAnim.running

        anchors {
            left: !settingsOnRight
            right: settingsOnRight
            top: true
            bottom: false
        }

        implicitWidth: volWidePanel ? Math.round(panelWidth) : Math.round(buttonSize + 8)
        implicitHeight: volWidePanel ? Math.round(volPanelH) : Math.round(pillH)
        exclusiveZone: 0
        color: "#00000000"

        margins {
            left: settingsOnRight ? 0 : Math.round(barWidth) + 4
            right: settingsOnRight ? Math.round(barWidth) + 4 : 0
            top: Math.round(volExtY)
        }

        Item {
            anchors.fill: parent
            opacity: volPanelShown ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    id: volFadeAnim
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Icon button (only when hovering, not expanded, not dismissing)
            Rectangle {
                visible: volPanelShown && !volumeExpanded
                width: buttonSize
                height: buttonSize
                radius: buttonSize / 2
                color: S.Theme.color1
                z: 1
                anchors {
                    right: settingsOnRight ? parent.right : undefined
                    left: !settingsOnRight ? parent.left : undefined
                    verticalCenter: parent.verticalCenter
                }
                border.color: S.Theme.color0
                border.width: 6

                Text {
                    anchors.centerIn: parent
                    text: volumeIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: parent.width * 0.45
                    color: S.Theme.color0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volumeExpanded = true
                }
            }

            // Board-style container (stays visible during fade-out via volWidePanel)
            Rectangle {
                visible: volWidePanel
                anchors.fill: parent
                color: S.Theme.color238
                radius: 12

                Column {
                    anchors.fill: parent
                    anchors.margins: panelPad
                    spacing: panelPad

                    // ── Main volume card ──
                    Rectangle {
                        width: parent.width
                        height: mainCardH
                        radius: S.Theme.cornerRadius
                        color: S.Theme.color236
                        border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08)
                        border.width: 1

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

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        isMuted = !isMuted
                                        S.Proc.runCommand("settings-mute-toggle", ["pamixer", "-t"], () => {}, 0)
                                        volAutoHideTimer.restart()
                                    }
                                }
                            }

                            ProgressBar {
                                width: parent.width - iconSize - parent.spacing
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                value: volume
                                lineHeight: monitorHeight * 0.005
                                fillColor: S.Theme.primary
                                trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                indicatorColor: S.Theme.primary
                                showIndicator: true
                                interactive: true

                                onSeeking: pos => {
                                    volInteracting = true
                                    volume = pos
                                    volAutoHideTimer.restart()
                                    S.Proc.runCommand("settings-vol-set", ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 50)
                                }

                                onClicked: pos => {
                                    volume = pos
                                    volInteracting = false
                                    volAutoHideTimer.restart()
                                    S.Proc.runCommand("settings-vol-set", ["pamixer", "--set-volume", String(Math.round(pos * 100))], () => {}, 0)
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
                        border.width: 1

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
                                            lineHeight: monitorHeight * 0.004
                                            fillColor: S.Theme.primary
                                            trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                            indicatorColor: S.Theme.primary
                                            showIndicator: true
                                            interactive: true

                                            onSeeking: pos => {
                                                appVol = pos
                                                appVolInteracting = true
                                                volAutoHideTimer.restart()
                                                S.Proc.runCommand("settings-app-vol-" + modelData.index,
                                                    ["pactl", "set-sink-input-volume", String(modelData.index), String(Math.round(pos * 100)) + "%"],
                                                    () => {}, 50)
                                            }

                                            onClicked: pos => {
                                                appVol = pos
                                                appVolInteracting = false
                                                volAutoHideTimer.restart()
                                                S.Proc.runCommand("settings-app-vol-" + modelData.index,
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

    PanelWindow {
        id: brightExtPanel
        screen: modelData
        visible: brightPanelShown || brightFadeAnim.running

        anchors {
            left: !settingsOnRight
            right: settingsOnRight
            top: true
            bottom: false
        }

        implicitWidth: brightWidePanel ? Math.round(panelWidth) : Math.round(buttonSize + 8)
        implicitHeight: brightWidePanel ? Math.round(brightPanelH) : Math.round(pillH)
        exclusiveZone: 0
        color: "#00000000"

        margins {
            left: settingsOnRight ? 0 : Math.round(barWidth) + 4
            right: settingsOnRight ? Math.round(barWidth) + 4 : 0
            top: Math.round(brightExtY)
        }

        Item {
            anchors.fill: parent
            opacity: brightPanelShown ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    id: brightFadeAnim
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            // Icon button (only when hovering, not expanded, not dismissing)
            Rectangle {
                visible: brightPanelShown && !brightnessExpanded
                width: buttonSize
                height: buttonSize
                radius: buttonSize / 2
                color: S.Theme.color1
                z: 1
                anchors {
                    right: settingsOnRight ? parent.right : undefined
                    left: !settingsOnRight ? parent.left : undefined
                    verticalCenter: parent.verticalCenter
                }
                border.color: S.Theme.color0
                border.width: 6

                Text {
                    anchors.centerIn: parent
                    text: brightnessIcon
                    font.family: "IosevkaTerm Nerd Font Mono"
                    font.pixelSize: parent.width * 0.45
                    color: S.Theme.color0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: brightnessExpanded = true
                }
            }

            // Board-style container (stays visible during fade-out via brightWidePanel)
            Rectangle {
                visible: brightWidePanel
                anchors.fill: parent
                color: S.Theme.color238
                radius: 12

                Column {
                    anchors.fill: parent
                    anchors.margins: panelPad
                    spacing: panelPad

                    Rectangle {
                        width: parent.width
                        height: mainCardH
                        radius: S.Theme.cornerRadius
                        color: S.Theme.color236
                        border.color: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.08)
                        border.width: 1

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
                                lineHeight: monitorHeight * 0.005
                                fillColor: S.Theme.primary
                                trackColor: Qt.rgba(S.Theme.outline.r, S.Theme.outline.g, S.Theme.outline.b, 0.15)
                                indicatorColor: S.Theme.primary
                                showIndicator: true
                                interactive: true

                                onSeeking: pos => {
                                    brightInteracting = true
                                    brightness = pos
                                    brightAutoHideTimer.restart()
                                    S.Proc.runCommand("settings-bright-set", ["light", "-S", String(Math.round(pos * 100))], () => {}, 50)
                                }

                                onClicked: pos => {
                                    brightness = pos
                                    brightInteracting = false
                                    brightAutoHideTimer.restart()
                                    S.Proc.runCommand("settings-bright-set", ["light", "-S", String(Math.round(pos * 100))], () => {}, 0)
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
