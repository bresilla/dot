//@ pragma UseQApplication

import QtQuick
import Quickshell
import "./board"

ShellRoot {
    id: root
    
    Variants {
        model: Quickshell.screens
        
        Watcher {}
    }
}
