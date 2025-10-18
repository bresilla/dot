//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/line/"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        Workspace {}
    }
}
