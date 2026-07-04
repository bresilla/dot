#!/usr/bin/env bash

pkill -f "qs.*border" 2>/dev/null
DISPLAY=:0 qs -p $HOME/.config/quickshell/border
