import QtQuick
import ".."

Rectangle {
    id: root
    
    radius: Theme.cornerRadius
    color: WalColors.color240
    border.color: Qt.rgba(
        parseInt(WalColors.color1?.substring(1, 3) || "ff", 16) / 255,
        parseInt(WalColors.color1?.substring(3, 5) || "ff", 16) / 255,
        parseInt(WalColors.color1?.substring(5, 7) || "ff", 16) / 255,
        0.08
    )
    border.width: 1
}
