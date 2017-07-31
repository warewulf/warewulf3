# Provisioning Systems With Multiple Provisioners (Submasters)

## Allowing multiple hosts to reach SQL

By default MySQL does not permit any remote access to the databases. You must configure your database to allow it by specifying a username, password and hostname as follows:

```
$ mysql -u root -p warewulf
mysql> GRANT ALL PRIVILEGES ON warewulf.* TO [username]@[hostname] IDENTIFIED BY '[password]' WITH GRANT OPTION;
mysql> FLUSH PRIVILEGES;
mysql> exit;
```

## Configuration of the Submaster

You will then need to install the provision-server components on a system that has network connectivity to reach the database server as follows:

```
$ sudo yum install warewulf-provision-server
```

Then edit the Warewulf submaster's **/etc/warewulf/database.conf** so it can properly make a database configuration.
