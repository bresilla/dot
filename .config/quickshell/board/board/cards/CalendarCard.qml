import QtQuick
import ".."

BaseCard {
    id: root
    
    Text {
        anchors.centerIn: parent
        text: "Calendar"
        font.family: "IosevkaTerm Nerd Font Mono"
        font.pixelSize: Theme.fontSizeLarge
        color: Theme.surfaceText
    }
}
