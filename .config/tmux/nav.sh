#!/bin/bash
# Navigate windows while preserving popup state

DIRECTION=$1
CURRENT_SESSION=$(tmux display -p '#{session_name}')

# Debug logging
echo "=== NAV DEBUG $(date) ===" >> /tmp/nav_debug.log
echo "Direction: $DIRECTION" >> /tmp/nav_debug.log
echo "Current session: $CURRENT_SESSION" >> /tmp/nav_debug.log

# Check if we're in a popup
if [[ "$CURRENT_SESSION" == *"popup"* ]]; then
    # === IN POPUP ===
    PARENT_WINDOW=$(tmux show -t "$CURRENT_SESSION" -v @popup_parent_window 2>/dev/null)
    PARENT_SESSION=$(tmux show -t "$CURRENT_SESSION" -v @popup_parent_session 2>/dev/null)
    
    echo "Parent window: $PARENT_WINDOW" >> /tmp/nav_debug.log
    echo "Parent session: $PARENT_SESSION" >> /tmp/nav_debug.log
    
    if [ -z "$PARENT_WINDOW" ] || [ -z "$PARENT_SESSION" ]; then
        echo "No parent info, detaching" >> /tmp/nav_debug.log
        tmux detach-client
        exit 0
    fi
    
    # Save current popup to file
    echo "$CURRENT_SESSION" > "/tmp/tmux_popup_${PARENT_WINDOW}"
    echo "Saved popup to /tmp/tmux_popup_${PARENT_WINDOW}" >> /tmp/nav_debug.log
    
    # Navigate parent window FIRST
    if [ "$DIRECTION" = "next" ]; then
        tmux next-window -t "$PARENT_SESSION"
    else
        tmux previous-window -t "$PARENT_SESSION"
    fi
    
    # Detach from popup - restoration will happen via hook
    echo "Detaching from popup" >> /tmp/nav_debug.log
    tmux detach-client
    
else
    # === NOT IN POPUP ===
    echo "Not in popup, current window before nav: $(tmux display -p '#{window_id}')" >> /tmp/nav_debug.log
    
    # Navigate
    if [ "$DIRECTION" = "next" ]; then
        tmux next-window
    else
        tmux previous-window
    fi
    
    echo "After navigation: $(tmux display -p '#{window_id}')" >> /tmp/nav_debug.log
fi

echo "=== END NAV DEBUG ===" >> /tmp/nav_debug.log
