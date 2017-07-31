# Node Provisioning (Work In Progress)

## Configuring the provision package

Make sure /etc/warewulf/provision.conf has "network device" set to your current network device. (The default is eth1.)

Example for /etc/warewulf/provision.conf:

```bash
...
# What is the default network device that the nodes will be used to
# communicate to the nodes?
network device = eth1  ###change to eth0 as needed
...
```

## Node management

Nodes are stored within Warewulf as data store objects of type "node". Nodes can be generally manipulated with the **node** Warewulf command. The Warewulf provision package also includes a helper command called **provision** which facilitates setting up nodes for provisioning.

To configure nodes for provisioning you need to have several parameters set:

*   **vnfs**: The VNFS that this node will be provisioned with
*   **bootstrap**: This is the bootstrap image (kernel and initrd) that the node will be booted to
*   **netdevs (specifically the ipaddr and hwaddr entries)**: The netdev's entry is a list of sub objects each of which defines a particular network interface. Within the netdev's there needs to be an IP address and MAC address set. You can have as many netdev entries as you wish.

Here is an example for adding and configuring a node to be provisioned:

```bash
$ sudo wwsh
Warewulf> node new n0000 --netdev=eth0 --ipaddr=10.0.1.0 --hwaddr=00:00:00:00:00:00
Warewulf> provision set n0000 --vnfs=rhel-6 --bootstrap=2.6.32-71.18.2.el6.x86_64
```

### Adding nodes to Warewulf

There are two ways to add nodes to Warewulf (at the time of this writing). The first method is to add nodes automatically as they boot up using the **wwnodescan** utility. The second is to add them by hand, or via a script.

#### Automatically adding nodes

There is a tool that is included with the Warewulf provision package called **wwnodescan**. This tool monitors DHCP, and adds nodes as systems make DHCP requests. To add a single node to Warewulf as it boots use the following command (changing the necessary information):

```
$ sudo wwnodescan --netdev=eth0 --ipaddr=10.0.1.0 --netmask=255.255.0.0 --vnfs=rhel-6 --bootstrap=2.6.32-71.18.2.el6.x86_64 n0000
```

You can also specify multiple nodes or a node range which will continue scanning until all nodes have been added.

note: The IP address will be incremented to support subsequent nodes.

#### Manually adding nodes

Use the "node" command in wwsh to create node database entries by hand:

Example:

```
Warewulf> node new n0000 --netdev=eth0 --hwaddr=00:00:00:00:00:00 --ipaddr=10.0.1.0 --groups=newnodes
Warewulf> node new n0001 --netdev=eth0 --hwaddr=00:00:00:00:00:01 --ipaddr=10.0.1.1 --groups=newnodes
Warewulf> node new n0002 --netdev=eth0 --hwaddr=00:00:00:00:00:02 --ipaddr=10.0.1.2 --groups=newnodes
Warewulf> provision set --lookup groups newnodes --vnfs=rhel-6 --bootstrap=2.6.32-71.18.2.el6.x86_64
```

The first commands will create the new node objects in the datastore and associate them to the group _newnodes_, and the provision command will find all nodes in the _newnodes_ group and set their VNFS and BOOTSTRAP configurations.

Make sure apache, dhcp and tftp-server is running -- you should be ready to boot up your nodes!
