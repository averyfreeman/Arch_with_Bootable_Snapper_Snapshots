#!/bin/bash
export IFNAME=eno1
export BRNAME=br0
export IPADDRESS='192.168.1.40/24'
export GATEWAY='192.168.1.1'
export INSTALL_DIR='/etc/systemd/network/test'
if ! test -d $INSTALL_DIR; then
	mkdir -v $INSTALL_DIR;
fi
cd $INSTALL_DIR
printf "[Match]\nName=%s\n\n[Network]\nBridge=%s\n" \
        > %s/10-%s-%s-slave.network \
        $IFNAME $BRNAME $INSTALL_DIR $IFNAME $BRNAME



printf "[Match]\nName=$IFNAME\n\n[Network]\nBridge=$BRNAME\n" \
        > $INSTALL_DIR/10-$IFNAME-$BRNAME-slave.network \
        $IFNAME $BRNAME $INSTALL_DIR $IFNAME $BRNAME

printf "[NetDev]\nName=$BRNAME\nKind=bridge\n\n[Bridge]\nSTP=yes\n" \
        > $INSTALL_DIR/10-bridge-$BRNAME.netdev
printf "[Match]\nName=$BRNAME\n\n\
[Network]\nAddress=$IPADDRESS\nGateway=$GATEWAY\n\
DNS=1.1.1.1\nDNS=1.0.0.1\n" \
        > $INSTALL_DIR/20-bridge-$BRNAME.network
