# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Bootstrap.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Event::Bootstrap;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::RetVal;

my $event = Warewulf::EventHandler->new();

sub
build_bootstrap()
{
    foreach my $obj (@_) {
        $obj->build_local_bootstrap();
    }
    return &ret_success();
}

sub
delete_bootstrap()
{
    foreach my $obj (@_) {
        $obj->delete_local_bootstrap();
    }
    return &ret_success();
}

$event->register("bootstrap.add", \&build_bootstrap);
$event->register("bootstrap.delete", \&delete_bootstrap);
$event->register("bootstrap.modify", \&build_bootstrap);


1;
