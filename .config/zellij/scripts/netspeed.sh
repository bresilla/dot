#!/bin/bash
# Network speed for zjstatus (matches promptline __netspeed)
# Shows: ▲upload | ▼download

INLABEL="▼"
OUTLABEL="▲"

iface=$(ip route | awk '/^default/ { print $5 ; exit }')
[[ -z "$iface" ]] && exit 0

RXB=$(</sys/class/net/"$iface"/statistics/rx_bytes)
TXB=$(</sys/class/net/"$iface"/statistics/tx_bytes)
sleep 1
RXBN=$(</sys/class/net/"$iface"/statistics/rx_bytes)
TXBN=$(</sys/class/net/"$iface"/statistics/tx_bytes)

rx_rate=$((RXBN - RXB))
tx_rate=$((TXBN - TXB))

# Format output
output=""

# Outgoing
tx_kib=$((tx_rate >> 10))
if [[ "$tx_rate" -gt 1048576 ]]; then
    output+="${OUTLABEL}$(echo "scale=1; $tx_kib / 1024" | bc)M"
else
    output+="${OUTLABEL}${tx_kib}K"
fi

output+=" | "

# Incoming
rx_kib=$((rx_rate >> 10))
if [[ "$rx_rate" -gt 1048576 ]]; then
    output+="${INLABEL}$(echo "scale=1; $rx_kib / 1024" | bc)M"
else
    output+="${INLABEL}${rx_kib}K"
fi

echo "$output"
