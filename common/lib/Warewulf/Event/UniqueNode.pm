# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2012, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: NewObject.pm 579 2011-08-12 20:26:58Z gmk $
#

package Warewulf::Event::UniqueNode;

use Warewulf::Config;
use Warewulf::DataStore;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::RetVal;
use Warewulf::Logger;

my $event = Warewulf::EventHandler->new();
my $config = Warewulf::Config->new("defaults/node.conf");
my $run_hwaddr = $config->get("unique hwaddrs") || "yes";

sub
unique_node()
{
    my @objects = @_;
    my $db = Warewulf::DataStore->new();

    &iprint("Looking for duplicate node(s)\n");

    foreach my $obj (@objects) {
        my @hwaddrs = $obj->hwaddr_list();
        &dprint("Evaluating for duplicate HWADDR(s): @hwaddrs\n");

        if (scalar(@hwaddrs) > 0) {
            my $obj2 = $db->get_objects("node", "hwaddr", @hwaddrs)->get_object(0);
            if ($obj2) {
                my $nodename2 = $obj2->nodename() || "UNDEF";
                my $hwaddrs2 = join(",", $obj2->hwaddr_list());
                return &ret_failure(-1, "Existing HW address exists for $nodename2 ($hwaddrs2)");
            }
        }
    }
    return &ret_success();
}

if ($run_hwaddr eq "yes") {
    $event->register("node.new", \&unique_node);
}

1;
