#!/usr/bin/env bash

qs kill -p "$HOME/.config/quickshell/border" --any-display 2>/dev/null
DISPLAY=:0 qs -d -p "$HOME/.config/quickshell/border"
