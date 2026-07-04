#!/usr/bin/env bash
# Restore popup for current window if one exists

CURRENT_WINDOW=$(tmux display -p '#{window_id}')
POPUP_FILE="/tmp/tmux_popup_${CURRENT_WINDOW}"

echo "=== RESTORE CHECK $(date) ===" >> /tmp/nav_debug.log
echo "Window: $CURRENT_WINDOW" >> /tmp/nav_debug.log

if [ -f "$POPUP_FILE" ]; then
    POPUP_SESSION=$(cat "$POPUP_FILE")
    echo "Found popup file: $POPUP_SESSION" >> /tmp/nav_debug.log
    
    if tmux has-session -t "$POPUP_SESSION" 2>/dev/null; then
        echo "Restoring popup: $POPUP_SESSION" >> /tmp/nav_debug.log
        tmux display-popup -w 80% -h 70% -E "tmux attach-session -t $POPUP_SESSION"
    else
        echo "Popup session $POPUP_SESSION no longer exists, cleaning up" >> /tmp/nav_debug.log
        rm -f "$POPUP_FILE"
    fi
else
    echo "No popup file for window $CURRENT_WINDOW" >> /tmp/nav_debug.log
fi

echo "=== END RESTORE CHECK ===" >> /tmp/nav_debug.log
