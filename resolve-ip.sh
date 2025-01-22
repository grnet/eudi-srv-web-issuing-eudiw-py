#!/bin/bash

interface=""
if ip link show eth0 > /dev/null 2>&1; then
    interface="eth0"
else
    interface="wlp0s20f3"
fi

IP_NEW=$(ip -o addr show dev "$interface" |
    while read IFNUM IFNAME ADDRTYPE ADDR REST; do [ "$ADDRTYPE" == "inet" ] && echo $ADDR; done)

echo $IP_NEW | awk -F'/' '{print $1}' > .config.ip
echo $(<.config.ip)
