# User Management for Provisioned Nodes

Managing users on the nodes requires generally 2 stages. The first is making sure the users home directory and environment is present on the nodes. The second is getting the users credentials and user information to the nodes.

## User's environments

This requires the home directory of the user(s) in question to be shared to the nodes. NFS is a typical solution for this, but because there are so many methods and variables for doing this we will make the assumption you have already done this in a manner that works for your environment.

Once the user's home directory is present on the nodes, enabling passwordless ssh is as easy as generating a ssh keypair without a passphrase, and copying the public key to authorized_keys for each user as follows:

```
$ ssh-keygen
$ cat ~/.ssh/*.pub >> ~/.ssh/authorized_keys
```

## User credentials [¶](#Usercredentials "Link to this section")

Managing users with the _File_ Warewulf interface can be done as follows:

```
$ sudo su -
# wwsh file import /etc/passwd
# wwsh file import /etc/group
# wwsh provision set --fileadd passwd,group
```

This will cause all nodes to have these two files provisioned when the boot, and updated within 5 minutes.

Whenever updates are made to the password file (e.g. a user is added) to update the files within Warewulf, you must run:

```
$ sudo wwsh file sync
```
