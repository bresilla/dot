#!/bin/bash

pkill -f "qs.*border" 2>/dev/null
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/border
