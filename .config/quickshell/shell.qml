//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./line/modules/line/"
import "./settings/modules/settings/"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Workspace {}
    }

    Variants {
        model: Quickshell.screens
        SettingsManager {}
    }
}
