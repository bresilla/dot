pragma Singleton
import QtQuick

QtObject {
    readonly property int durShort: 200
    readonly property int durMed: 300
    readonly property int durLong: 400
    
    readonly property var standard: [0.20, 0.00, 0.00, 1.00, 1.00, 1.00]
    readonly property var emphasizedDecel: [0.05, 0.70, 0.10, 1.00, 1.00, 1.00]
}
