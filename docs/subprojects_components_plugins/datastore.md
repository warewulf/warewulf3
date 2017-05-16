# The Warewulf Data Store

From the Warewulf perspective, all components within an infrastructure configuration are objects. Nodes, files, VNFS images, bootstraps, etc.. are all objects to which you can assign key/value pairs, as well as other sub objects. The Warewulf Data Store is an architecture to persist and retrieve these objects easily and efficiently. The back end storage of these objects is abstracted out and modular. Thus it can support a wide range of technologies.

Presently, MySQL is used as the default back end data store implementation because it is widely known, reasonably fast, and utilizes a server/client architecture which easily supports multiple Warewulf servers and sub-masters.

## Data Store Configuration

The configuration file for the datastore (assuming a standard build) would be located at `/etc/warewulf/database.conf` and (as of version 3.4) `/etc/warewulf/database-root.conf`.

### database.conf

In this file you will define the database type and driver as well as the default user access privileges.

```
# Database configuration
database type       = sql
database driver     = mysql

# Database access
database server     = localhost
database name       = warewulf
database user       = root
database password   = changeme
```

### database-root.conf

As of Version 3.4, you should use this file to define the user that has full privileges to the Warewulf database/tables and the `database.conf` file above should be used for non-privileged access to the datastore (e.g. a differentiation between user read only access, and root level changes).

## Initialization

Warewulf will automatically try and setup the back end database which includes setting up the tables and non-privleged read only access as defined in the non -root configuration file.
