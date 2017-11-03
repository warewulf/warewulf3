At the moment, this is just a quick walkthrough of a process for setting up an image which includes Infiniband support. This example was carried out on Scientific Linux 6, and provisioned to a Dell PowerEdge 1950 with a Mellanox InfiniHost III Lx HCA.

## Creating the image

Starting point is the base image created using <tt>wwmkchroot</tt>.

```
# wwmkchroot sl-6 /var/chroots/ib-example-sl6
```

The image should also have a kernel present for building OFED. I typically also include grub in case I want to do a stateful install.

```
# yum --config=/var/chroots/ib-example-sl6/root/yum-ww.conf --installroot=/var/chroots/ib-example-sl6 -y install kernel kernel-devel grub
```

You'll also need some build tools:

```
# yum --config=/var/chroots/ib-example-sl6/root/yum-ww.conf --installroot=/var/chroots/ib-example-sl6 -y install \
  perl make gcc bison flex libtool tcl tcl-devel tk tcsh rpm gcc-c++ zlib-devel rpm-build
```

## Building OFED

Download OFED from the [OpenFabrics](http://www.openfabrics.org/) web site into the /root directory of the chroot, then do a chroot to build OFED. When you build OFED, make sure to build against the kernel present in the image, not the one that might be running on your master. In this example, OFED is being built in HPC mode.

```
# cd /var/chroots/ib-example-sl6/root/
# wget http://www.openfabrics.org/downloads/OFED/ofed-1.5.3/OFED-1.5.3.1.tgz
# tar xvzf OFED-1.5.3.1.tgz
# chroot /var/chroots/ib-example-sl6/
# cd root/OFED-1.5.3.1
# ./install.pl --hpc --kernel 2.6.32-131.6.1.el6.x86_64
```

This process will take a while (feel free to get a snack). Afterwards you will have OFED installed into the chroot. You will also have a collection of RPMs which you can re-use for other images with the same kernel, etc; in this example, they can be found in $chroot/root/OFED-1.5.3.1/RPMS/sl-release-6.0-6.0.1/x86_64\. It often makes sense to copy these to another location for later use. At this point you should <tt>exit</tt> the chroot.

> **NOTE:** After the chroot command, a file <tt>$chroot/dev/null</tt> may exist from the shell. You will want to remove this file.

## Building the VNFS and bootstrap

The default bootstrap.conf distributed with Warewulf should automatically import Infiniband drivers if they are present. The relevant lines are:

```
# Infiniband drivers and Mellanox drivers
drivers = ib_ipath, ib_iser, ib_srpt, ib_sdp, ib_mthca, ib_qib, iw_cxgb3, cxgb3
drivers = iw_nes, mlx4_ib, ib_srp, ib_ipoib, ib_addr, rdma_cm, ib_ucm
drivers = ib_ucm, ib_uverbs, ib_umad, ib_cm, ib_mad, iw_cm, ib_core
drivers = rdma_ucm, ib_sa, mlx4_en, mlx4_core
drivers = rds, rds_rdma, rds_tcp, mlx4_vnic, mlx4_vnic_helper
```

Now you should generate a bootstrap for the chroot's kernel:

```
# wwbootstrap --root /var/chroots/ib-example-sl6/ 2.6.32-131.6.1.el6.x86_64
```

And then build a vnfs from the chroot:

```
# wwvnfs --root /var/chroots/ib-example-sl6
```

## Setting Up ifcfg-ib0

Warewulf's file provisioning allows you to set up an ifcfg-ib0 template with node variables, which can be used to set up each node's static addressing at boot time. Create a file in your home directory called ifcfg-ib0 and set it up like this:

```
DEVICE=ib0
BOOTPROTO=static
IPADDR=%{NETDEVS::IB0::IPADDR}
NETMASK=%{NETDEVS::IB0::NETMASK}
ONBOOT=yes
```

Then import this file into Warewulf's datastore, and set its path for provisioning:

```
# wwsh file import ifcfg-ib0
# wwsh file set ifcfg-ib0 --path=/etc/sysconfig/network-scripts/ifcfg-ib0
```

## Provisioning A Node

Pick a node that has an Infiniband HCA installed, and add it to Warewulf if it isn't already in the datastore. On that node, create a netdev named ib0 and set its ipaddr and netmask:

```
Warewulf> node set rutc0024 --netdev=ib0 --ipaddr=10.120.1.24 --netmask=255.255.0.0
Are you sure you want to make the following 2 changes to node(s):

     SET: ib0.IPADDR           = 10.120.1.24
     SET: ib0.NETMASK          = 255.255.0.0
```

Then set the vnfs and bootstrap for the node to be the ones you just created:

```
# wwsh provision set rutc0024 --vnfs=ib-example-sl6 --bootstrap=2.6.32-131.6.1.el6.x86_64
```

And make sure that ifcfg-ib0 will be provisioned as well:

```
# wwsh provision set rutc0024 --fileadd=ifcfg-ib0
```

Then PXE-boot the node to provision it. If all has gone well, the node should boot with its IB interface up and IPoIB configured according to the node's netdev settings:

```
-bash-4.1# ibstat
CA 'mthca0'
        CA type: MT25204
        Number of ports: 1
        Firmware version: 1.2.0
        Hardware version: a0
        Node GUID: 0x0005ad000008c878
        System image GUID: 0x0005ad000008c87b
        Port 1:
                State: Active
                Physical state: LinkUp
                Rate: 20
                Base lid: 10
                LMC: 0
                SM lid: 2
                Capability mask: 0x02510a68
                Port GUID: 0x0005ad000008c879
                Link layer: IB
-bash-4.1# ip address show dev ib0
4: ib0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 2044 qdisc mq state UP qlen 1024
    link/infiniband xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx brd yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy
    inet 10.120.1.24/16 brd 10.120.255.255 scope global ib0
       valid_lft forever preferred_lft forever
    inet6 fe80::zzz:zzzz:z:zzzz/64 scope link
       valid_lft forever preferred_lft forever
```
