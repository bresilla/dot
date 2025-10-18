#!/bin/bash

BOARD=${1:-default}

pkill -f "qs.*board" 2>/dev/null

echo "Launching QuickShell board: $BOARD"
DISPLAY=:0 BOARD=$BOARD qs -p /env/dot/.config/quickshell/board &

echo "QuickShell board '$BOARD' launched"
