import QtQuick
import ".."
import Quickshell

BaseCard {
    id: root
    
    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
    
    Text {
        anchors.centerIn: parent
        text: "Clock"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }
}
