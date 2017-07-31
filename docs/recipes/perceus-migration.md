A quick reference guide for users of PERCEUS to assist in transitioning to Warewulf 3+.

| **PERCEUS Syntax** | **Warewulf 3+ Equivalent** |
|--------------------|----------------------------|
|Chroot Path: `/var/lib/perceus/vnfs/`_`name`_`/rootfs`</td> | Chroot path (typical): `/var/chroots/`_`name`<br/>VNFS images are stored in the Warewulf data store (database), not on disk.</td> |
| `perceus vnfs clone` _`oldname`__`newname`_| Not required. Simply `cp -a` _`oldpath`__`newpath` |
| `perceus vnfs mount` _`name`_| None needed. Closest equivalent would be `ln -s /var/chroots/`_`name`_ `/mnt/` |
| `perceus vnfs close` _`name`_| None needed. Closest equivalent would be `rm -f /mnt/`_`name`_ (see above) |
| `perceus vnfs umount` _`name`_| `wwvnfs` _`name`_ <br/> **NOTE:** Options for chroot jail paths, hybridization settings, etc. are best done in config files (`/etc/warewulf/vnfs/`_`name`_`.conf`)!</td> |
| `perceus vnfs livesync` _`name`__`list_of_nodes`_ | `wwlivesync` _`nodespec`_ <br/>Unlike with PERCEUS, node ranges like `'n00[00-99].lr1'` can be supplied. |
| `perceus node status` | No equivalent. This will be handled by Warewulf monitoring. |
| `perceus node list [` _`nodespec`_ `]`<br/>`perceus node summary [` _`nodespec`_ `]` | No exact equivalent. Closest is: `wwsh node list [` _`nodespec`_ `]` |
| `perceus node show [` _`nodespec`_ `]` | `wwsh node print [` _`nodespec`_ `]` |
| `perceus vnfs export` _`name`__`outfile`_ | `wwsh vnfs export` _`name(s)`__`outdir`_ <br/> **OR** while storing/updating: `wwvnfs` _`name`_ `-o` _`outfile`_ |
| `perceus vnfs import` _`infile`_ `[` _`name`_ `]` | `wwsh vnfs import [ -n` _`name`_ `]` _`infile`_ |
| `perceus node add` _`hwaddr`__`name`_`.`_`cluster`_ | `wwsh node new -D` _`ifname`_ `-H` _`hwaddr`_ `-c` _`cluster`__`name`_ <br/>May also want to specify: `-g` _`group(s)`_ `-I` _`ipaddr`_ `-M` _`netmask`_ `-G` _`gateway`_ |
| `perceus node delete` _`nodespec`_ | `wwsh node delete` _`nodespec`_ |
| `perceus node set hostname` _`name`_`.`_`cluster`__`oldname`_ | `wwsh node set -n` _`name`_ `-c` _`cluster`__`oldname`_ |
| `perceus -i node set hostname` _`name`_`.`_`cluster`__`hwaddr`_ | `wwsh -l hwaddr -n` _`name`_ `-c` _`cluster`__`hwaddr`_|
| `perceus node set vnfs` _`vnfs`__`nodespec`_ | `wwsh provision set -V` _`vnfs`__`nodespec`_ |
| `perceus group set vnfs` _`vnfs`__`group`_ | `wwsh provision set -l groups -V` _`vnfs`__`group(s)`_ |
| `perceus node set group` _`group`__`nodespec`_ | `wwsh node set -g` _`group(s)`__`nodespec`_ |
| `perceus node replace` _`realname`__`currentname`_ | No equivalent, but maybe there should be? <br/> For now, use `wwsh node print` _`currentname`_ to get the new machine's hardware address(es). Then `wwsh node delete` _`currentname`_ and `wwsh node set` _`realname`_ to set them on the object with the correct name. |
