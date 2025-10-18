import QtQuick

Text {
    property string name: ""
    property int size: 24
    property alias iconColor: root.color
    
    id: root
    
    text: {
        const icons = {
            "music_note": "♪",
            "skip_previous": "⏮",
            "skip_next": "⏭",
            "play_arrow": "▶",
            "pause": "⏸",
            "chevron_left": "‹",
            "chevron_right": "›",
            "arrow_back": "←",
            "dashboard": "📊",
            "settings": "⚙",
            "notifications": "🔔"
        }
        return icons[name] || name
    }
    font.pixelSize: size
    color: Theme.surfaceText
}
