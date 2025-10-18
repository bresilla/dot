import QtQuick

Text {
    property string name: ""
    property int size: 24
    property alias iconColor: root.color
    
    id: root
    
    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.weight: 400
    color: Theme.surfaceText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
    antialiasing: true
}
