//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    id: root
    
    Variants {
        model: Quickshell.screens
        
        BoardMonitor {}
    }
}
