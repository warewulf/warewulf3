#!/bin/bash

apt install apache2 libapache2-mod-perl2 tftpd-hpa mysql-server debootstrap isc-dhcp-server tcpdump openssh-client nfs-kernel-server nfs-common rpcbind ntp wget build-essential perl make automake pkg-config libarchive-tools ipxe libtirpc-dev libselinux-dev gcc python python3 libssl-dev uuid-dev libblkid-dev gettext libdevmapper-dev liblzma-dev ipmitool 

if [ $? -eq 0 ]; then
    for SUBDIR in common cluster vnfs ipmi provision; do
        OPTIONS=" "
        cd ../$SUBDIR
        if [ $? -ne 0 ]; then
            break
        fi
        if [ "$SUBDIR" = "ipmi" ]; then
          OPTIONS="--with-local-ipmitool"
        fi
          ./autogen.sh --prefix=/ --bindir=/usr/bin $OPTIONS
        if [ $? -eq 0 ]; then
            make
        else
            echo "$SUBDIR: autogen failed"
            break
        fi
        if [ $? -eq 0 ]; then
            make install
        else
            echo "$SUBDIR: make failed"
            break
        fi
        if [ $? -ne 0 ]; then
            echo "$SUBDIR: make install failed"
            break
        fi
    done
fi

