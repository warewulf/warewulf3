# Warewulf Common

Driven by a modular interface as described by the [Architecture](../architecture.md) documentation Warewulf Common contains the core functionality of Warewulf. It provides the base libraries that are shared and utilized by the other Warewulf modules as well as the backend data store interface, event and trigger handlers and a basic command line interface.

## Data Store

The Warewulf backend is very modular and is built in such a way to support a wide range of technologies to store configurations. Warewulf is currently developed and distributed using MySQL as the backend data storage solution and it must be configured and initialized before using Warewulf.

Make sure that you have properly initialized Warewulf as defined by the [initialization and setup recipe](../recipes/setup/initialization.md).

Storage of data is in the form of objects and then the ability to link raw data to the objects. The object itself can be thought of as the metadata with an optional associated binary data (e.g. a VNFS image, or text file data).

## wwsh

Warewulf includes a primary command line interface called `wwsh` which can be used to interact with the components, modules, and functions. The functions that are available via this interface are dependent on what Warewulf components are installed. `wwsh` can be used as a command line interface or as an interactive shell.

Here are some examples of using the Warewulf shell with the `sudo` command

### Invoking the Warewulf shell interactively

```bash
$ sudo wwsh
Warewulf> help
Warewulf> quit
$
```

### Passing commands directly to the Warewulf shell

```bash
$ sudo wwsh help
```

### Redirecting predetermined commands into Warewulf

```bash
$ sudo wwsh < /path/to/file/with/warewulf/commands
$ cat /path/to/file/with/warewulf/commands | sudo wwsh
```

### Using Warewulf for intepreted scripts

```bash
#!/usr/bin/wwsh
help
quit
```

## Commands

Below are some pertinent command summaries.

#### Help

This provides a usage summary for all available commands.

#### Node

The node command is used for configuring node or systems within the Warewulf datastore. This is how you can add and configure base properties for a particular node entity. For example, you can define the node, what groups the node is part of, what cluster it is in, domain, and define its network devices (including HWADDR/MAC, IP address, FQDN, etc.).

#### File

The File command is used for adding and manipulating files within the Warewulf data store. Files can be used for a variety of things within Warewulf (such as being provisioned by the provision module). With this command you can configure both the file metadata as well as add or edit the associated raw data for the file.
