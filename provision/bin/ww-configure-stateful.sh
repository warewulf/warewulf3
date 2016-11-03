#!/bin/bash

# ww-configure-stateful.sh
#   Script to set up basic stateful provisioning with Warewulf.
#   Adam DeConinck @ R Systems, 2011

NODE=$1
ROOTSIZE=$2
SWAPSIZE=$3
DISK=$4

ROOTDEFAULT=20480
SWAPDEFAULT=4096
DISKDEFAULT="sda"

if [ -z "$NODE" ]; then
	echo
	echo "$0: Configure a node for stateful provisioning under Warewulf"
	echo "Usage: $0 nodename [ rootfs_in_mb swap_in_mb disk]"
	echo "If omitted, rootfs = $ROOTDEFAULT, swap = $SWAPDEFAULT, and"
    echo "disk = $DISKDEFAULT."
	echo "REMEMBER: If you're going to do this, make sure you have a "
	echo "kernel and grub installed in your VNFS!"
	echo
	exit 1
fi

if [ -z "$ROOTSIZE" ]; then
	ROOTSIZE=$ROOTDEFAULT;
fi
if [ -z "$SWAPSIZE" ]; then
	SWAPSIZE=$SWAPDEFAULT;
fi
if [ -z "$DISK" ]; then
    DISK=$DISKDEFAULT
fi

ROOTP=$DISK"1"
SWAPP=$DISK"2"

echo
echo "Configuring stateful provisioning for $NODE, using :"
echo "    filesystems=\"mountpoint=/:type=ext2:dev=$ROOTP:size=$ROOTSIZE,dev=$SWAPP:type=swap:size=$SWAPSIZE\""
echo "    diskformat=$ROOTP,$SWAPP"
echo "    diskpartition=$DISK"
echo "    bootloader=$DISK"
echo

wwsh << EOF
quiet
object $NODE -s filesystems="mountpoint=/:type=ext2:dev=$ROOTP:size=$ROOTSIZE,dev=$SWAPP:type=swap:size=$SWAPSIZE"
object $NODE -s diskformat=$ROOTP,$SWAPP
object $NODE -s diskpartition=$DISK
object $NODE -s bootloader=$DISK
EOF

echo
echo
echo "-----------------------------------------------------"
echo " $NODE has been set to boot from $DISK, with $ROOTP as "
echo " the / partition and $SWAPP as swap."
echo
echo " Make sure the VNFS for $NODE has a kernel and grub  "
echo " installed!"
echo " After you've provisioned $NODE, remember to do: "
echo "     wwsh \"object $NODE -s bootlocal=1\""
echo " to set the node to boot from its disk."
echo "-----------------------------------------------------"
echo
