#!/bin/bash
# CPU usage for zjstatus (matches promptline __cpustats)
# Uses /env/bin/cpu-stat if available, otherwise calculates from /proc/stat

if [[ -x "/env/bin/cpu-stat" ]]; then
    cpu=$(/env/bin/cpu-stat)
    cpu=${cpu%.*}
    echo "${cpu}%"
else
    # Fallback: calculate from /proc/stat
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle1=$idle
    sleep 1
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle2=$idle
    
    total_diff=$((total2 - total1))
    idle_diff=$((idle2 - idle1))
    
    if [[ $total_diff -gt 0 ]]; then
        cpu_usage=$(( (total_diff - idle_diff) * 100 / total_diff ))
        echo "${cpu_usage}%"
    else
        echo "0%"
    fi
fi
