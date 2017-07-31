## Runtime Services

During the bootstrap process, Warewulf will create a `/warewulf` directory on the node and install some tools for updating the node configuration during the run.

### wwgetfiles

Running `wwgetfiles` on a live node will download the files specified in a node's FILEIDs variable and place them in the filesystem, just as during the file provisioning step of the bootstrap. A good use of file provisioning is for managing configuration files such as `/etc/hosts` or a cluster scheduler configuration, and running wwgetfiles on a live node will keep this in sync with the source on the master.

The runtime services installation installs a cron job in `/etc/cron.d` which runs wwgetfiles every 5 minutes.

### wwgetscript

`wwgetscript` downloads and runs a script from the master. The first argument to the script should be either "pre", "post" or "runtime". "pre" and "post" are run directly before and after provisioning.

To set the pre, post or runtime scripts, set the node's "prescript", "postscript", or "runtimescript" variable to the name of a file object in the Warewulf datastore. This file object has to have its format set to "shell" rather than the default "data". (If you import a .sh file using wwsh file import, this should be set correctly already.)

The runtime services installation installs a cron job in `/etc/cron.d` which runs `wwgetscript runtime` every five minutes.

### wwgetvnfs

`wwgetvnfs` is installed, but is **extremely dangerous**. Running this script will overwrite the node's existing filesystem with the assigned VNFS capsule on the master. In practice it is much safer to re-provision the node with a reboot, but this could be used to sync a live filesystem with an original or changed VNFS.

### Disabling runtime services

To disable the installation of runtime services on a node, set `wwsh object modify -s NORUNTIMESERVICES=1` on the node object. (Or set it to anything, really: the bootstrap script just checks if the variable exists.) To re-enable it, unset that variable on the node object, `wwsh object modify -D NORUNTIMESERVICES`.
