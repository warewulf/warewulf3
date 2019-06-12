#!/bin/bash

zypper install autoconf automake libacl-devel libattr-devel libuuid-devel nfs-kernel-server device-mapper-devel xz-devel apache2 apache2-mod_perl tftp dhcp-server xinetd tcpdump policycoreutils-python sles-release util-linux mysql perl-DBD-mysql openssl-devel wget gcc ipmitool ipxe

if [ $? -eq 0 ]; then
    for SUBDIR in common cluster vnfs ipmi provision; do
        cd ../$SUBDIR
        if [ $? -ne 0 ]; then
            break
        fi
        if [ "$SUBDIR" = "ipmi" ]; then
          ./autogen.sh --with-local-ipmitool --prefix=/
        else
          ./autogen.sh --prefix=/
        fi
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

