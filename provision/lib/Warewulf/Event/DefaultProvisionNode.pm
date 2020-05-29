# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2012, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DefaultProvisionNode.pm 1038 2012-08-02 21:18:25Z gmk $
#

package Warewulf::Event::DefaultProvisionNode;

use Warewulf::Config;
use Warewulf::DataStore;
use Warewulf::DSO::Bootstrap;
use Warewulf::DSO::Vnfs;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Node;
use Warewulf::Provision;
use Warewulf::RetVal;

my $event = Warewulf::EventHandler->new();

sub
default_provision_node()
{
    my @objects = @_;
    my $db = Warewulf::DataStore->new();
    my $config = Warewulf::Config->new("defaults/provision.conf");

    &iprint("Building default configuration for new provision node(s)\n");
    my @files = $config->get("files");
    my $bootstrap = $config->get("bootstrap");
    my $vnfs = $config->get("vnfs");

    my @fileids;
    my $bootstrapid;
    my $vnfsid;

    if (@files) {
        foreach my $obj ($db->get_objects("file", "name", @files)->get_list()) {
            push(@fileids, $obj->id());
        }
    }

    if ($bootstrap) {
        my $obj = $db->get_objects("bootstrap", "name", $bootstrap)->get_object(0);
        if ($obj) {
            $bootstrapid = $obj->id();
        }
    }

    if ($vnfs) {
        my $obj = $db->get_objects("vnfs", "name", $vnfs)->get_object(0);
        if ($obj) {
            $vnfsid = $obj->id();
        }
    }

    foreach my $obj (@objects) {
        if (@fileids) {
            if (! $obj->fileids()) {
                $obj->fileids(@fileids);
            } else {
                # Remove any files referenced in defaults/provision.conf first
                # incase we're a cloned node
                $obj->fileiddel(@fileids);
                $obj->fileidadd(@fileids);
            }
        }
        if ($bootstrapid) {
            if (! $obj->bootstrapid()) {
                $obj->bootstrapid($bootstrapid);
            }
        }
        if ($vnfsid) {
            if (! $obj->vnfsid()) {
                $obj->vnfsid($vnfsid);
            }
        }
    }

    return &ret_success();
}


$event->register("node.new", \&default_provision_node);

1;
