#!/bin/bash

pkill -f "qs.*line" 2>/dev/null
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/line
