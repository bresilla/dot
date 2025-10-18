#!/bin/bash

pkill -f "qs.*osd" 2>/dev/null
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/osd
