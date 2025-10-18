//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/osd/"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        OSDManager {}
    }
}
