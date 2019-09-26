#!/bin/bash

dnf install autoconf automake libacl-devel libattr-devel libuuid-devel nfs-utils device-mapper-devel xz-devel httpd tftp dhcp-server xinetd tcpdump python3-policycoreutils util-linux mariadb-server perl-DBD-mysql openssl-devel wget gcc ipmitool ipxe-bootimgs python3 make libtirpc-devel parted autofs bzip2 chrony perl-CGI tar e2fsprogs libarchive bsdtar
dnf install perl-Sys-Syslog tftp-server perl-JSON-PP

if [ $? -eq 0 ]; then
    for SUBDIR in common cluster vnfs ipmi provision; do
        OPTIONS=" "
        cd ../$SUBDIR
        if [ $? -ne 0 ]; then
            break
        fi
        if [ "$SUBDIR" = "provision" ]; then
	  OPTIONS="--with-apache2moddir=/usr/lib64/apache2 --with-local-e2fsprogs  --with-local-libarchive --with-local-parted --with-local-partprobe"
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
