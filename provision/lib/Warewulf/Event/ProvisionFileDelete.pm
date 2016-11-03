# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2013, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: ProvisionFileDelete.pm 1038 2012-08-02 21:18:25Z gmk $
#

package Warewulf::Event::ProvisionFileDelete;

use Warewulf::DataStore;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Node;
use Warewulf::Provision;
use Warewulf::RetVal;

my $event = Warewulf::EventHandler->new();

sub
deletefile()
{
    my @objects = @_;
    my $db = Warewulf::DataStore->new();
    my $nodeObjs = $db->get_objects("node");
    my @fileids;

    foreach my $o (@objects) {
        my $id = $o->id();
        my $name = $o->name();
        &dprint("Adding file '$name' ($id) to delete array\n");
        push(@fileids, $id);
    }

    foreach my $o ($nodeObjs->get_list()) {
        my $name = $o->name();
        &iprint("Deleting file id(s) '@fileids' from node file provision array\n");
        $o->fileiddel(@fileids);
    }

    $db->persist($nodeObjs->get_list());

    return &ret_success();
}


$event->register("file.delete", \&deletefile);

1;
