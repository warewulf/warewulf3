#!/bin/sh
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#



VNFSDIR=$1

if [ -z "$VNFSDIR" ]; then
    echo "USAGE: $0 /path/to/chroot"
    exit 1
fi

VERSION=`rpm -qf /etc/redhat-release  --qf '%{VERSION}\n'`

mkdir -p $VNFSDIR
mkdir -p $VNFSDIR/etc

echo "Creating yum configuration based on master"
cp -rap /etc/yum.conf /etc/yum.repos.d $VNFSDIR/etc
sed -i -e "s/\$releasever/$VERSION/g" `find $VNFSDIR/etc/yum* -type f`

echo "Starting package installation"
yum --tolerant --installroot $VNFSDIR -y install \
    SysVinit basesystem bash redhat-release chkconfig coreutils e2fsprogs \
    ethtool filesystem findutils gawk grep initscripts iproute iputils \
    mingetty mktemp net-tools nfs-utils pam portmap procps psmisc rdate \
    sed setup shadow-utils rsyslog tcp_wrappers compat-termcap tzdata util-linux \
    words zlib tar less gzip which util-linux module-init-tools udev \
    openssh-clients openssh-server passwd dhclient pciutils vim-minimal \
    shadow-utils strace vixie-cron cronie crontabs

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create chroot"
fi

echo
echo "Creating default fstab"
echo "#GENERATED_ENTRIES#" > $VNFSDIR/etc/fstab
echo "tmpfs /dev/shm tmpfs defaults 0 0" >> $VNFSDIR/etc/fstab
echo "devpts /dev/pts devpts gid=5,mode=620 0 0" >> $VNFSDIR/etc/fstab
echo "sysfs /sys sysfs defaults 0 0" >> $VNFSDIR/etc/fstab
echo "proc /proc proc defaults 0 0" >> $VNFSDIR/etc/fstab

echo "NETWORKING=yes" > $VNFSDIR/etc/sysconfig/network

echo "Creating SSH host keys"
/usr/bin/ssh-keygen -q -t rsa1 -f $VNFSDIR/etc/ssh/ssh_host_key -C '' -N ''
/usr/bin/ssh-keygen -q -t rsa -f $VNFSDIR/etc/ssh/ssh_host_rsa_key -C '' -N ''
/usr/bin/ssh-keygen -q -t dsa -f $VNFSDIR/etc/ssh/ssh_host_dsa_key -C '' -N ''

if [ ! -f "$VNFSDIR/etc/shadow" ]; then
    echo "Creating shadow file"
    /usr/sbin/chroot $VNFSDIR /usr/sbin/pwconv
fi

if [ -f "$VNFSDIR/etc/pam.d/system-auth" ]; then
    sed -i -e '/^account.*pam_unix\.so\s*$/s/\s*$/\ broken_shadow/' $VNFSDIR/etc/pam.d/system-auth
fi

if [ -f "$VNFSDIR/etc/pam.d/password-auth" ]; then
    sed -i -e '/^account.*pam_unix\.so\s*$/s/\s*$/\ broken_shadow/' $VNFSDIR/etc/pam.d/password-auth
fi

if [ -x "$VNFSDIR/usr/bin/passwd" ]; then
    echo "Setting root password..."
    /usr/sbin/chroot $VNFSDIR /usr/bin/passwd root
else
    echo "Setting root password to NULL (be sure to fix this yourself)"
    sed -i -e 's/^root:\*:/root::/' $VNFSDIR/etc/shadow
fi

touch $VNFSDIR/fastboot

echo "Done."
