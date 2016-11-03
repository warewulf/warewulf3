# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DynamicHosts.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Event::DynamicHosts;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Provision::HostsFile;
use Warewulf::RetVal;


my $event = Warewulf::EventHandler->new();
my $obj = Warewulf::Provision::HostsFile->new();


sub
update_hosts()
{
    $obj->update(@_);

    return &ret_success();
}

# Update dynamic_hosts when a node is modified
$event->register("node.add", \&update_hosts);
$event->register("node.delete", \&update_hosts);
$event->register("node.modify", \&update_hosts);

# Allow for explicit trigger of this event
$event->register("file::dynamic_hosts.sync", \&update_hosts);
1;
