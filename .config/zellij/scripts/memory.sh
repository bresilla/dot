#!/bin/bash
# Memory usage for zjstatus
free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2}'
