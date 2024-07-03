#!/bin/bash
export IFNAME=eno1
export BRNAME=br0
export IPADDRESS='192.168.1.40/24'
export GATEWAY='192.168.1.1'
printf "[Match]\nName=$IFNAME\n\n[Network]\nBridge=$BRNAME\n" \
        > /etc/systemd/network/20-$IFNAME-$BRNAME-slave.network
printf "[NetDev]\nName=$BRNAME\nKind=bridge\n\n[Bridge]\nSTP=yes\n" \
        > /etc/systemd/network/20-bridge-$BRNAME.netdev
printf "[Match]\nName=$BRNAME\n\n\
[Network]\nAddress=$IPADDRESS\nGateway=$GATEWAY\n\
DNS=1.1.1.1\nDNS=1.0.0.1\n" \
        > /etc/systemd/network/20-bridge-$BRNAME.network
