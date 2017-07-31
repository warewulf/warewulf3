# Documentation

Documentation is always a work in progress... Please report errors via [GitHub issues](https://github.com/warewulf/warewulf3/issues).

## Contributing

To contribute to the Warewulf wiki pages, create issues, or contribute to the source tree visit GitHub. You can ask one of the contributors for repo access on our [mailing list](https://groups.google.com/a/lbl.gov/forum/#!forum/warewulf). You can get access to our [Slack](warewulf.slack.com) instance by asking on the mailing list.

> _note: Any new branches or changes to the given structure must be vetted and approved by a primary developer._

* * *

## General Warewulf Overview

* [About Warewulf](about.md)
* [Terminology and reference](terminology.md)
* [Warewulf architecture](architecture.md)

## Warewulf Subprojects, Components, and Plugins

* [Warewulf Common](subprojects_components_plugins/common.md)
    * [The Warewulf Datastore](subprojects_components_plugins/datastore.md)
* [System/Node Provisioning](subprojects_components_plugins/provision.md)
    * [How to provision specific files](subprojects_components_plugins/provision-files.md)
    * [Runtime scripts that are provisioned automatically](subprojects_components_plugins/provision-scripts.md)
* [VNFS (Virtual Node File System) Management](subprojects_components_plugins/vnfs.md)
* <a class="missing wiki">IBCheck?</a> -- Swiss army knife for Infiniband (IB) troubleshooting
* <a class="missing wiki">Ipmi Integration?</a>
* <a class="missing wiki">Scalable System Monitoring?</a>

## Recipes

Warewulf recipes are designed to be brief command based walk throughs of what you would need to type or do to reach a particular endpoint. If you need details of what you are doing, why you are doing it, or how something works, this is not the place! Contributions should be in the form of specific command examples such that somebody can for the most part copy/paste the content to obtain the desired results with only brief explanations (if any).

### Setup

* [Installing Warewulf fresh](recipes/setup/installation.md)
* [Upgrading Warewulf on your system](recipes/setup/upgrading.md)
* [Warewulf Initialization](recipes/setup/initialization.md)
* [Tab completion in wwsh](recipes/setup/readline.md)

### Stateless Provisioning

* [Stateless provisioning for Red Hat and compatibles](recipes/provisioning/rhel.md)
* [Stateless provisioning for Debian Linux](recipes/provisioning/debian.md)
* <a class="missing wiki">Stateless provisioning for Ubuntu Linux?</a>
* <a class="missing wiki">Stateless provisioning for OpenSuSE Linux?</a>

### Building a Beowulf style cluster

* <a class="missing wiki">Single Master Beowulf?</a>
* <a class="missing wiki">Multiple Master Beowulf?</a>

### General

* [Adding Infiniband support to the VNFS](recipes/infiniband.md)
* [User management for provisioned nodes](recipes/users.md)
* [Provisioning nodes with multiple submasters](recipes/submaster-provisioning.md)
* [Stateful provisioning](recipes/stateful-provisioning.md)
* <a class="missing wiki">IPMI configuration?</a>
* [Warewulf for PERCEUS Users](recipes/perceus-migration.md) - A quick-reference guide to commonly-used PERCEUS commands and their Warewulf equivalents

## Development

* A tutorial on writing [Warewulf Event Modules](event-modules.md).
* [Mezzanine](mezzanine.md) is used to build Warewulf from source and create binary RPMS. _(this is only needed if you're building Warewulf from source)_
* [Information for contributors (help with development, testing, documentation, admin, etc.)](contributing.md)
* [Building and installing from Source tarballs](recipes/setup/installation-by-source.md)
* [Building and installing from SCM repository (Subversion)](recipes/setup/installation-using-subversion.md)

## Media

* [<span class="icon"> </span>SuperComputing 2011 Warewulf Handout](http://warewulf.lbl.gov/downloads/media/SC11-Warewulf-Handout.pdf)
