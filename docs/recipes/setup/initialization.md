# Warewulf Initialization and Setup

## WWInit

Warewulf includes a modular initialization utility called **wwinit**. WWInit will walk through various configuration and initialization tests, checks and implement changes as needed. Here is an example run:

```
# wwinit ALL
database:     Checking /etc/rc.d/init.d/mysqld is installed                  OK
database:     Confirming mysqld is configured to start at boot:
database:      + chkconfig mysqld on                                         OK
database:     Checking to see if MySQL needs to be started:
database:      + service mysqld start                                        OK
wwsh:         Confirming that wwsh accepts some basic commands
wwsh:          + wwsh quit                                                   OK
wwsh:          + wwsh help                                                   OK
wwsh:          + wwsh node new testnode0000                                  OK
wwsh:          + wwsh node list                                              OK
wwsh:          + wwsh node delete testnode0000                               OK
domain:       Setting default node domain to: "cluster"                      OK
authfiles:    Checking to see if /etc/passwd is in the WW Datastore          NO
authfiles:    Adding /etc/passwd to the datastore:
authfiles:     + wwsh file import /etc/passwd --name=passwd                  OK
authfiles:    Adding passwd to default new node configuration                OK
authfiles:    Checking to see if /etc/group is in the WW Datastore           NO
authfiles:    Adding /etc/group to the datastore:
authfiles:     + wwsh file import /etc/group --name=group                    OK
authfiles:    Adding group to default new node configuration                 OK
nfsd:         Setting domain "cluster" for IDMAPD/NFSv4                      OK
nfsd:          + chkconfig nfs on                                            OK
nfsd:          + service nfs restart                                         OK
nfsd:          + exportfs -a                                                 OK
ntpd:         Configured NTP services
ntpd:          + chkconfig ntpd on                                           OK
ntpd:          + service ntpd restart                                        OK
ssh_keys:     Checking ssh keys for root                                     OK
ssh_keys:     Checking root's ssh config                                     OK
ssh_keys:     Checking for default RSA host key for nodes                    NO
ssh_keys:     Creating default node ssh_host_rsa_key:
ssh_keys:      + ssh-keygen -q -t rsa -f /etc/warewulf/vnfs/ssh/ssh_host_rsa OK
ssh_keys:     Checking for default DSA host key for nodes                    NO
ssh_keys:     Creating default node ssh_host_dsa_key:
ssh_keys:      + ssh-keygen -q -t dsa -f /etc/warewulf/vnfs/ssh/ssh_host_dsa OK
tftp:          + /sbin/chkconfig xinetd on                                   OK
tftp:          + /sbin/chkconfig tftp on                                     OK
tftp:          + /sbin/service xinetd restart                                OK
bootstrap:    Checking on a Warewulf bootstrap                               OK
```

After running **wwinit ALL** your system is ready to import a VNFS and start provisioning nodes!

If you don't wish to do a full system initialization (ALL), you can run/rerun any portion of the initialization separately. To see the available options, run **wwinit** with no arguments:

```
# wwinit
/usr/bin/wwinit [options] [initialization(s)]

OPTIONS:
    -d        Debug output
    -v        Verbose output
    -h        Usage summary

INITIALIZATIONS:
   * ALL
   * AUTH
   * DATASTORE
   * MASTER
   * PROVISION
   * TESTING
   * VNFS
   * authfiles
   * bootstrap
   * database
   * domain
   * hostfile
   * nfsd
   * ntpd
   * ssh_keys
   * tftp
   * wwsh

EXAMPLES:

 # wwinit ALL
 # wwinit TEST database
```

> _note: The initializations in all lowercase letters are the specific modules and in all capitol letters are sequences which include multiple modules._
