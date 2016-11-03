# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2012, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DefaultNode.pm 1038 2012-08-02 21:18:25Z gmk $
#

package Warewulf::Event::DefaultNode;

use Warewulf::Config;
use Warewulf::DataStore;
use Warewulf::Node;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::RetVal;
use Warewulf::Logger;

my $event = Warewulf::EventHandler->new();

sub
default_node()
{
    my @objects = @_;
    my $db = Warewulf::DataStore->new();
    my $config = Warewulf::Config->new("defaults/node.conf");

    &iprint("Building default configuration for new node(s)\n");
    my @groups = $config->get("groups");
    my $cluster = $config->get("cluster");
    my $domain = $config->get("domain");
    my $netdev = $config->get("netdev");
    my $netmask = $config->get("netmask");
    my $network = $config->get("network");
    my $gateway = $config->get("gateway");

    foreach my $obj (@objects) {
        if (@groups) {
            if (! $obj->groups()) {
                $obj->groups(@groups);
            } else {
                $obj->groupadd(@groups);
            }
        }
        if ($cluster) {
            if (! $obj->cluster()) {
                $obj->cluster($cluster);
            }
        }
        if ($domain) {
            if (! $obj->domain()) {
                $obj->domain($domain);
            }
        }
        if ($netdev and $netmask) {
            if (! $obj->netmask($netdev)) {
                $obj->netmask($netdev, $netmask);
            }
        }
        if ($netdev and $network) {
            if (! $obj->network($netdev)) {
                $obj->network($netdev, $network);
            }
        }
        if ($netdev and $gateway) {
            if (! $obj->gateway($netdev)) {
                $obj->gateway($netdev, $gateway);
            }
        }
    }

    return &ret_success();
}


$event->register("node.new", \&default_node);

1;
