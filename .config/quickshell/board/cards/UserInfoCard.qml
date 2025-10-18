import QtQuick
import ".."

BaseCard {
    id: root
    
    Text {
        anchors.centerIn: parent
        text: "User Info"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }
}
