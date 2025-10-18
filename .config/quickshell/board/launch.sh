#!/bin/bash

pkill -f "qs.*board" 2>/dev/null
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/board
