import QtQuick

Rectangle {
    color: WalColors.color236
    radius: 12
    
    Column {
        anchors.centerIn: parent
        spacing: 8
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "hh:mm")
            font.pixelSize: 48
            font.bold: true
            color: WalColors.color7
        }
        
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dddd, MMMM d")
            font.pixelSize: 16
            color: WalColors.color8
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: parent.children[0].children[0].text = Qt.formatTime(new Date(), "hh:mm")
    }
}
