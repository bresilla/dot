import QtQuick

Item {
    id: root

    property real value: 0
    property color trackColor: "#303030"
    property color fillColor: "#000000"
    property color indicatorColor: "#000000"
    property bool showIndicator: false
    property bool interactive: true
    property real lineHeight: 60
    property real indicatorWidth: 3
    property real indicatorGap: 8

    signal clicked(real position)
    signal seeking(real position)

    implicitHeight: lineHeight * 6

    readonly property real indicatorPosition: width * root.value
    readonly property real indicatorHeight: lineHeight * 2.0

    Rectangle {
        id: pastTrack
        height: root.lineHeight
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, root.indicatorPosition - root.indicatorGap)
        radius: 2
        color: root.fillColor

        Behavior on width {
            enabled: !mouseArea.pressed
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: indicator
        visible: root.showIndicator
        width: root.indicatorWidth
        height: indicatorHeight
        radius: 1
        color: root.indicatorColor
        x: root.indicatorPosition - width / 2
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            enabled: !mouseArea.pressed
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: futureTrack
        height: root.lineHeight
        anchors.verticalCenter: parent.verticalCenter
        x: root.indicatorPosition + root.indicatorGap
        width: Math.max(0, parent.width - x)
        radius: 2
        color: root.trackColor

        Behavior on x {
            enabled: !mouseArea.pressed
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => {
            const pos = Math.max(0, Math.min(1, mouse.x / width))
            root.seeking(pos)
        }

        onPositionChanged: mouse => {
            if (pressed) {
                const pos = Math.max(0, Math.min(1, mouse.x / width))
                root.seeking(pos)
            }
        }

        onReleased: mouse => {
            const pos = Math.max(0, Math.min(1, mouse.x / width))
            root.clicked(pos)
        }
    }
}
