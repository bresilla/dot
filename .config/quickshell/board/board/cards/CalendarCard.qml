import QtQuick
import ".."

BaseCard {
    id: root
    
    Text {
        anchors.centerIn: parent
        text: "Calendar"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }
}
