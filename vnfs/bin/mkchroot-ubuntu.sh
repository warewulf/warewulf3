#!/bin/bash
#
# Modified June 2011 from mkchroot-rh.sh by Adam DeConinck at R Systems NA, Inc.
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


VNFSDIR=$2
SUITE=$1

if [ -z "$VNFSDIR" ]; then
	echo "USAGE: $0 suite /path/to/chroot"
	echo "where suite is maverick, lucid, karmic, etc"
	exit 1
fi

mkdir -p $VNFSDIR

echo "Running debootstrap for minimal Ubuntu $SUITE"
echo "debootstrap --variant=minbase $SUITE $VNFSDIR"

debootstrap --components=main,restricted,universe --variant=minbase \
	--include=openssh-server,openssh-client,dhcp-client,pciutils,strace,nfs-common,nfs-kernel-server,ethtool,iproute,iputils-ping,iputils-arping,net-tools,linux-image-server \
	$SUITE $VNFSDIR http://us.archive.ubuntu.com/ubuntu/

if [ $? -ne 0 ]; then
	echo "ERROR: Failed to create chroot"
fi

echo
echo "Generating default fstab"
echo "#GENERATED_ENTRIES" > $VNFSDIR/etc/fstab
echo "tmpfs /dev/shm tmpfs defaults 0 0" >> $VNFSDIR/etc/fstab
echo "devpts /dev/pts devpts gid=5,mode=620 0 0" >> $VNFSDIR/etc/fstab
echo "sysfs /sys sysfs defaults 0 0" >> $VNFSDIR/etc/fstab
echo "proc /proc proc defaults 0 0" >> $VNFSDIR/etc/fstab

echo "Creating SSH host keys"
/usr/bin/ssh-keygen -q -t rsa1 -f $VNFSDIR/etc/ssh/ssh_host_key -C '' -N ''
/usr/bin/ssh-keygen -q -t rsa -f $VNFSDIR/etc/ssh/ssh_host_rsa_key -C '' -N ''
/usr/bin/ssh-keygen -q -t dsa -f $VNFSDIR/etc/ssh/ssh_host_dsa_key -C '' -N ''

if [ ! -f "$VNFSDIR/etc/shadow" ]; then
	echo "Creating show file"
	/usr/sbin/chroot $VNFSDIR /usr/sbin/pwconv
fi

# add broken_shadow to pam.d/common-account
if [ -f "$VNFSDIR/etc/pam.d/common-account" ]; then
    sed -i -e '/^account.*pam_unix\.so\s*$/s/\s*$/\ broken_shadow/' $VNFSDIR/etc/pam.d/common-account
fi

if [ -x "$VNFSDIR/usr/bin/passwd" ]; then
	echo "Setting root password"
	/usr/sbin/chroot $VNFSDIR /usr/bin/passwd root
else
	echo "Setting root password to NULL, be sure to fix this yourself"
	sed -i -e 's/^root:\*:/root::/' $VNFSDIR/etc/shadow
fi
