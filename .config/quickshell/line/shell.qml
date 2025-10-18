//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/line/"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        Line {}
    }

    Variants {
        model: Quickshell.screens
        WorkspaceOSD {}
    }
}
