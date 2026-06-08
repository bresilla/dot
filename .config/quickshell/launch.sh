#!/bin/bash

/home/bresilla/.config/quickshell/border/launch.sh &
/home/bresilla/.config/quickshell/board/launch.sh &
/home/bresilla/.config/quickshell/osd/launch.sh &
qs kill -p /home/bresilla/.config/quickshell --any-display 2>/dev/null
DISPLAY=:0 qs -n -p /home/bresilla/.config/quickshell &
