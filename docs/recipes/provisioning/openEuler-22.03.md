# Provisioning openEuler Systems Stateless

> _note: This recipe assumes you have already [installed](../setup/installation.md) and [initialized](../setup/initialization.md) Warewulf._

The following snippet will install the requirements to provision nodes, create the VNFS and bootstrap images and then scan for 20 new nodes.

```bash
$ sudo su -
# dnf install warewulf-provision warewulf-cluster warewulf-provision-server warewulf-vnfs tcpdump perl-DBD-MySQL mysql-server
# wwinit ALL
# wwmkchroot openEuler /var/chroots/openEuler
# wwvnfs --chroot /var/chroots/openEuler
# wwnodescan --netdev=eth0 --ipaddr=10.0.0.100 --netmask=255.255.255.0 --vnfs=openEuler --bootstrap=`uname -r` --groups=newnodes n00[00-19]
```

While wwnodescan is running you can boot your nodes and they will be added in the order that they are seen.

> _note: tcpdump is part of the yum install command because wwnodescan uses it to listen for DHCP requests. Its not a strict requirement as it is only required by wwnodescan and not general functionality of provisioning which is why it isn't installed automatically as a dependency._
