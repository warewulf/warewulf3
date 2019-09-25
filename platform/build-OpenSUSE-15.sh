#!/bin/bash

zypper install autoconf automake libacl-devel libattr-devel libuuid-devel nfs-kernel-server device-mapper-devel xz-devel apache2 apache2-mod_perl tftp dhcp-server xinetd tcpdump python3-policycoreutils util-linux mariadb perl-DBD-mysql libopenssl-devel wget gcc ipmitool ipxe-bootimgs python3 make libtirpc-devel parted autofs bzip2 ntp perl-CGI

if [ $? -eq 0 ]; then
    for SUBDIR in common cluster vnfs ipmi provision; do
        OPTIONS=" "
        cd ../$SUBDIR
        if [ $? -ne 0 ]; then
            break
        fi
        if [ "$SUBDIR" = "provision" ]; then
	  OPTIONS="--with-apache2moddir=/usr/lib64/apache2"
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

