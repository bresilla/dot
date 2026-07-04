#!/usr/bin/env bash

pkill -f "qs.*board" 2>/dev/null
DISPLAY=:0 qs -p $HOME/.config/quickshell/board
