import QtQuick

Text {
    property string name: ""
    property int size: 24
    property alias iconColor: root.color
    property string fontFamily: "IosevkaTerm Nerd Font Mono"
    
    id: root
    
    text: name
    font.family: fontFamily
    font.pixelSize: size
    font.weight: 400
    color: Theme.surfaceText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
    antialiasing: true
}
