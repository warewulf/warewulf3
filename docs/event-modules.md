## An tutorial/example of writing an event module for Warewulf

### The module itself

The below example is used to generate a node list file automatically within Warewulf, but can be co-opted to do anything you wish. The file is broken into functional components with descriptions of each component provided. To reassemble, simply copy and paste all of the code sections into a single file and put it into the Warewulf/Event/ perl library directory.

#### Preamble and includes

```
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2013, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
#

package Warewulf::Event::Nodelist;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::RetVal;
use Warewulf::DataStore;
use Warewulf::Node;
use File::Path;

my $event = Warewulf::EventHandler->new();
my $nodelist = "/etc/nodelist";
```

Like all Perl modules, the above is necessary for creating a package class, and including the libraries necessary for this code to function properly. Then we define our globals and construct the _$event_ object now (later it will allow us to assign subroutines to events).

#### What we want to do

```
sub
update_nodelist()
{
    my $datastore = Warewulf::DataStore->new();
    my $nodeSet = $datastore->get_objects("node");

    if (open(NODELIST, "> $nodelist")) {
        foreach my $n ($nodeSet->get_list()) {
            print NODELIST $n->name() ."\n";
        }

        if (close(NODELIST)) {
            return &ret_success();
        } else {
            &eprint("Could not write file: $nodelist\n");
            return &ret_failure();
        }
    } else {
        &eprint("Could not open file for writing: $nodelist\n");
        return &ret_failure();
    }
}
```

This function does the primary work of looking at what is in the datastore, and writing the needed components out to the nodelist. Notice where the above actions:

*   The _$datastore_ object is constructed
*   The _$nodeSet_ is built from the data store object
*   _$nodeSet_ is a Warewulf object set (Warewulf::ObjectSet)
*   Using the _get_list()_ method on the object set allows you iterate through the objects contained within it
*   We are able to call the _name()_ method on each object found
*   We return from the event using Warewulf's internal return object class as it gives much more possibilities then simply returning with an reconstructed, ad-hoc array.

All documentation for the above mentioned classes (e.g. Warewulf::DataStore, Warewulf::ObjectSet, Warewulf::Object, Warewulf::Node and Warewulf::RetVal) can be found by using the command _perldoc [CLASS]_.

#### Register what we want to do with when to do it

```
$event->register("node.delete", \&update_nodelist);
$event->register("node.modify", \&update_nodelist);

1;
```

Lastly, we register the _node.delete_ and _node.modify_ events with the function we created that updates the nodelist.

Notice that we did not use the _node.new_ event. This is because the use of the _node.new_ event is used before the object is persisted to the datastore. We could have made this event much more complicated and more efficient by engaging different functions for creating, modifying, and deleting nodes, but outside the scope of this tutorial.

The last line of a Perl module should always be "1;" to indicate the module has been successfully loaded in its entirety.

### Activating the Warewulf event module

To use your Warewulf event module, simply locate your Warewulf vendor perl library directory, and drop it in the Event/ directory (e.g. on RHEL6 it is in /usr/share/perl5/vendor_perl/Warewulf/Event/).

### Things to note!

When the event handler calls the defined subroutines it will pass a list of objects that triggered the events to the called function when its run.

The event will be run by whatever user is running the command calling the event! Thus, if you are using this with a web front-end, then the user calling this event will be the web server user (e.g. Apache), and it might not have access to write the file in question. Because Warewulf has many potential interfaces, you must be aware of who is running/calling your module and maybe even add some logic to test for that!
