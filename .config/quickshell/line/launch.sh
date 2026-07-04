#!/usr/bin/env bash

qs kill -p $HOME/.config/quickshell --any-display 2>/dev/null
DISPLAY=:0 qs -n -p $HOME/.config/quickshell
