import QtQuick
import ".."

Rectangle {
    id: root
    
    radius: Theme.cornerRadius
    color: Theme.color236
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: Theme.borderWidth
}
