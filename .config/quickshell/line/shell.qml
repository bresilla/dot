//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/line/"

ShellRoot {
    id: root

    Loader {
        active: true
        sourceComponent: Line{}
    }
    
    WorkspaceOSD {}
}
