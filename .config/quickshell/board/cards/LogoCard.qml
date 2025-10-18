import QtQuick

BaseCard {
    id: root
    
    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.9
        height: width
        source: "file:///home/bresilla/.config/bresilla.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
