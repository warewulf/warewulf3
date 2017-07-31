# Provisioning Debian Compatible Systems Stateless

**NOTE:** This recipe assumes you have already [installed](../setup/installation.md#InstallingWarewulfonDebian) Warewulf on Debian.  
The following snippet will create the VNFS image, and then scan for 20 new nodes.

The fastest way to start booting nodes on Debian is to use the provided generic recipe file. The recipe will create a generic debian chroot. Make note of the bootstrap **name** using **sudo wwsh bootstrap list** for use in wwnodescan.

```
$ sudo wwmkchroot debian7-64 /var/chroots/debian7-64
$ wwvnfs --chroot /var/chroots/debian7-64
$ sudo wwnodescan --netdev=eth0 --ipaddr=10.0.0.100 --netmask=255.255.255.0 --vnfs=debian7-64 --bootstrap=name --groups=newnodes n00[00-19]
```

While wwnodescan is running you can boot your nodes and they will be added in the order that they are seen.

Custom recipe files can be created, and are located in **_(install prefix)/libexec/warwulf/wwmkchroot/_**  
Additional information including a full list of advanced recipe options and Debian supported architectures can be seen with.

```
wwmkchroot -h debian
```
