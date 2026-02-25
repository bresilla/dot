//@ pragma UseQApplication

import QtQuick
import Quickshell

import "./modules/settings/"

ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        SettingsManager {}
    }
}
