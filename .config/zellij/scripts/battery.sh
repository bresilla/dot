#!/bin/bash
# Battery indicator for zjstatus (matches promptline __battery)
# Only outputs if battery exists
# Shows percentage + icon

BAT_PATH="/sys/class/power_supply/BAT0"
[ ! -d "$BAT_PATH" ] && BAT_PATH="/sys/class/power_supply/BAT1"
[ ! -d "$BAT_PATH" ] && exit 0

capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null)
status=$(cat "$BAT_PATH/status" 2>/dev/null)

[ -z "$capacity" ] && exit 0

# Nerd font battery icons
if [ "$status" = "Charging" ]; then
    icon="󰂄"
elif [ "$status" = "Full" ]; then
    icon="󰁹"
elif [ "$capacity" -ge 90 ]; then
    icon="󰂂"
elif [ "$capacity" -ge 80 ]; then
    icon="󰂁"
elif [ "$capacity" -ge 70 ]; then
    icon="󰂀"
elif [ "$capacity" -ge 60 ]; then
    icon="󰁿"
elif [ "$capacity" -ge 50 ]; then
    icon="󰁾"
elif [ "$capacity" -ge 40 ]; then
    icon="󰁽"
elif [ "$capacity" -ge 30 ]; then
    icon="󰁼"
elif [ "$capacity" -ge 20 ]; then
    icon="󰁻"
elif [ "$capacity" -ge 10 ]; then
    icon="󰁺"
else
    icon="󰂃"
fi

echo "${icon} ${capacity}%"
