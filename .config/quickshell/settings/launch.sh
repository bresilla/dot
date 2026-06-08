#!/bin/bash

qs kill -p /home/bresilla/.config/quickshell --any-display 2>/dev/null
DISPLAY=:0 qs -n -p /home/bresilla/.config/quickshell
