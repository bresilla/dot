#!/bin/bash

pkill -f "qs.*settings" 2>/dev/null
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/settings
