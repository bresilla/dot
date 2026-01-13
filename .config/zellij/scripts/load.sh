#!/bin/bash
# Load average for zjstatus (1-min average)
cut -d' ' -f1 /proc/loadavg
