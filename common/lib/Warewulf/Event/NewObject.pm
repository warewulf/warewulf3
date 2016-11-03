# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: NewObject.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Event::NewObject;

use Warewulf::Config;
use Warewulf::DataStore;
use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::RetVal;
use Warewulf::Logger;

my $event = Warewulf::EventHandler->new();

sub
default_config()
{
    my @objects = @_;
    my $db = Warewulf::DataStore->new();

    &iprint("Building default configuration for new object(s)\n");

    foreach my $obj (@objects) {
        my $type = $obj->type();
        my $def_object = $db->get_objects($type, "name", "DEFAULT")->get_object(0);
        if ($def_object) {
            my %hash = $def_object->get_hash();
            foreach my $key (keys %hash) {
                if (! $obj->get($key)) {
                    $obj->set($key, $hash{"$key"});
                }
            }
        }

        # Generate the names on node objects
        if ($type eq "node") {
            $obj->genname();
        }
    }
    return &ret_success();
}


$event->register("*.new", \&default_config);

1;

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
