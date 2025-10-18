#!/bin/bash

# Kill existing QuickShell instances
pkill -f "qs.*line" 2>/dev/null

# Get list of connected monitors
monitors=$(hyprctl monitors -j | jq -r '.[].name')

# Launch QuickShell for each monitor
for monitor in $monitors; do
    echo "Launching QuickShell line for monitor: $monitor"
    DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/line &
    sleep 0.5  # Small delay between launches
done

echo "QuickShell line launched for all monitors"