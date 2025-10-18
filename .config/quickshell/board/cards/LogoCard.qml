import QtQuick
import Quickshell
import Quickshell.Io

BaseCard {
    id: root
    
    FileView {
        id: logoFile
        path: Quickshell.env("HOME") + "/.config/bresilla.svg"
        watchChanges: true
        onFileChanged: {
            logoImage.source = ""
            logoImage.source = "file://" + path
        }
    }
    
    Image {
        id: logoImage
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.9
        height: width
        source: "file://" + logoFile.path
        fillMode: Image.PreserveAspectFit
        smooth: true
        cache: false
    }
}
