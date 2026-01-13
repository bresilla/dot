#!/bin/bash
# Uptime for zjstatus (compact format)
uptime -p | sed 's/up //' | sed 's/ hours\?/h/' | sed 's/ minutes\?/m/' | sed 's/ days\?/d/' | sed 's/, /:/g'
