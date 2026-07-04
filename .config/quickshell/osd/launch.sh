#!/usr/bin/env bash

pkill -f "qs.*osd" 2>/dev/null
DISPLAY=:0 qs -p $HOME/.config/quickshell/osd
