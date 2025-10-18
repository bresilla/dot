#!/bin/bash

# Kill existing QuickShell instances
pkill -f "qs.*line" 2>/dev/null

# Launch QuickShell once (it will create windows for all monitors via Variants)
echo "Launching QuickShell line"
DISPLAY=:0 qs -p /home/bresilla/.config/quickshell/line &

echo "QuickShell line launched"