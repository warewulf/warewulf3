# Warewulf Architecture

Warewulf has been engineered from the ground up using a full OO (Object Oriented) programming methodology and was built with extensibility, flexibility and scalability in mind. Because of this Warewulf can have various or custom front end interfaces, back end database solutions, modules and event handlers for doing particular things. Thus Warewulf is separated into functional components called Warewulf modules or sub-projects each is based on what a particular feature or enhancement that they provide or offer.

## License

With the goal of Warewulf being collaboration a very open and non-restrictive license was chosen. More open then the well known GPL (General Public License) Warewulf is released under the DOE-BSD open source license which in a nutshell is a BSD license with a clause added for contributions that come with an unspecified license being the same as Warewulf. The reasoning for this is to encourage all of the contributions to also be as accessible to the user community as the original licensing intent (but not force it).

## Interface(s)

Warewulf includes a primary command line interface called `wwsh` which can be used to interact with the components, modules, and functions. The functions that are available via this interface are dependent on what Warewulf components are installed. `wwsh` can be used as a command line interface or as an interactive shell. Warewulf is modular so other interfaces can be built using all of the same backend libraries. We encourage site specific or commercial vendor value adding branded interfaces to be created.

## Common core with a modular backend

Warewulf is designed with a common set of core functionality in the form of the primary interface, shared libraries, data/object storage, and an event handler such that the environment is extensible and modular to make integration of specific features easy and stackable. For example, once you have defined a given set of nodes within the Warewulf common interface installing the provisioning modules allows you to provision those nodes using the same information which already exists in the Warewulf data store. Monitoring uses the same common set of functionality, as does power management, and event notification.

You can install or create whatever functionality you require for your infrastructure! For instance, Warewulf does not require you install the provisioning components to utilize the power management, monitoring, or scheduling interfaces. But because each Warewulf module is utilizing the same backend datastore there are no redundant configurations, and each module can interact and even communicate with each other.

## Object Architecture

Within Warewulf everything is made up of objects, and each object can have its own attributes, paramaters, and configuration API. For example, nodes within Warewulf (systems) are objects where some configuration paramaters would be the node's name, network devices, what groups that node should be part of, etc.. If you have the provision module also installed, this same object may have additional configuration paramaters such as the VNFS (Virtual Node File System) that will be provisioned to this node, or what kernel/bootstrap image it will get on boot. VNFS images are also objects within the datastore that contains both metadata (configuration information) as well as binary information (the VNFS image itself).

To Warewulf, everything is an object and as a result everything is treated exactly the same to the backend datastore. This means that it is very extensible and easy to deal with once the API is understood.

Objects that are persisted to the datastore can be retrieved via "lookups" (many of the wwsh commands implement this via the --lookup=... argument). By default objects are looked up via their "name", but this can be changed for some objects for example when trying to address all nodes within a particular group (`--lookup=groups [groupnames...]`) or cluster name, or by IP address.

## Datastore

Warewulf implements an abstracted data store facility which builds and persists configuration targets (also known as "objects"). Nodes, files, VNFS, etc... are all "objects" within this model. The datastore interface to Warewulf has been purposefully abstracted away from the underlying technology (even though at present only the MySQL interface exists). This is to support different back end technologies as Warewulf grows in usage and requirements. For example, one site might only want a local file based datastore while others that are going for maximum scalability would prefer a distributed NOSQL based database.
