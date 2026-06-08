//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/border"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        Border {}
    }
}
