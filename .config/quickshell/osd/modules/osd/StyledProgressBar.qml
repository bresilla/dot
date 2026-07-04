import QtQuick
import "." as OSD

Item {
    id: root
    
    property real value: 0
    property color trackColor: OSD.Theme.color240
    property color fillColor: OSD.Theme.color0
    property color indicatorColor: OSD.Theme.color0
    property bool showIndicator: false
    property bool interactive: true
    property real lineHeight: parent ? parent.height * 0.16 : 1
    property real indicatorWidth: lineHeight * 0.3
    property real indicatorGap: lineHeight * 0.8
    
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
        radius: root.lineHeight * 0.2
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
        radius: root.indicatorWidth * 0.5
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
        radius: root.lineHeight * 0.2
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
