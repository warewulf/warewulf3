# Provisioning files

The default bootstrap capabilities make it possible to not only provision a VNFS to the node, but also provision straight files. You can do this by importing a file into the Warewulf datastore and then referencing that file in the node object.

## Importing a file into Warewulf

Inside of the Warewulf shell there is a command called **file** which allows you to manipulate files within the Warewulf datastore. Type **wwsh help file** to see the detailed usage summary and examples. To import the master's /etc/passwd file into Warewulf, do the following:

```bash
$ sudo wwsh file import /etc/passwd
```

By default the Warewulf datastore object's name will be referenced by the basename of the file or path given (e.g. passwd). You can change the name either at import time, or later by using the **--name=** option.

## Setting a node to provision a file in the Warewulf datastore

Once you have imported a file into Warewulf, you can set a node to provision this file automatically using the **provision** command as follows:

```bash
$ sudo wwsh provision set n[0000-0099] --fileadd passwd
```

The file metadata is already encoded within the object itself so Warewulf will know where to put the file, owner, group, permission attributes, etc.

## Changing the file's metadata

Once a file has been imported into Warewulf, you can change any of the file attributes using either the **file** command or the **object** command (for more advanced users). For example:

```bash
$ sudo wwsh file set passwd --path=/etc/passwd_test --mode=0600
```

You can view the object's metadata with the **print** command as follows:

```bash
$ sudo wwsh file print passwd
#### passwd ###################################################################
         passwd: ID               = 108
         passwd: NAME             = passwd
         passwd: PATH             = /etc/passwd_test
         passwd: ORIGIN           = /etc/passwd
         passwd: FORMAT           = data
         passwd: CHECKSUM         = 7d94c67a1b23f5fdd799a72411158709
         passwd: SIZE             = 1484
         passwd: MODE             = 0600
         passwd: UID              = 0
         passwd: GID              = 0
```

## Using dynamic information within a file

It is possible to populate a file dynamically with values that are referenced within the node object itself. This would be useful for doing things such as a file that configures the nodes hostname. On Red Hat compatible systems, this file is at **/etc/sysconfig/network**. So import that file into Warewulf from the master, and then edit to include a Warewulf variable.

```bash
$ sudo wwsh file import /etc/sysconfig/network
$ sudo wwsh file edit network
```

Then change the **HOSTNAME=** entry to look like the following:

```bash
HOSTNAME=%{NAME}
```

When this file is provisioned, the variable will be expanded to the node object's name.

### Dynamic replacement with subobjects

Warewulf objects may make use of subobjects (embedded objects within a main object). For example, the node object may have multiple network device objects associated with it. You can reference these subobjects generically by using a structure like:

```bash
IPADDR_ETH0=%{NETDEVS::ETH0::IPADDR}
NETMASK_ETH0=%{NETDEVS::ETH0::NETMASK}
HWADDR_ETH0=%{NETDEVS::ETH0::HWADDR}
IPADDR_ETH1=%{NETDEVS::ETH1::IPADDR}
NETMASK_ETH1=%{NETDEVS::ETH1::NETMASK}
HWADDR_ETH1=%{NETDEVS::ETH1::HWADDR}
HWADDR=%{HWADDR}[0]/%{HWADDR}[1]
```

Notice the last entry for HWADDR. In the node object, this is an array (multiple objects so this will reference the object at the specified array entry using the trailing square brackets. If this is left out, it assumes the first object in the array.
