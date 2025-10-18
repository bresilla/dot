//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    id: root
    
    property string currentBoard: Quickshell.env("BOARD") || "default"
    
    Variants {
        model: Quickshell.screens
        
        BoardMonitor {
            currentBoard: root.currentBoard
        }
    }
}
