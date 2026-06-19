#!/bin/bash

$HOME/.config/quickshell/border/launch.sh &
$HOME/.config/quickshell/board/launch.sh &
$HOME/.config/quickshell/osd/launch.sh &
qs kill -p $HOME/.config/quickshell --any-display 2>/dev/null
DISPLAY=:0 qs -n -p $HOME/.config/quickshell &
