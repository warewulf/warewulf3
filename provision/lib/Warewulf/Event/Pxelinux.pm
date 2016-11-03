# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Pxelinux.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Event::Pxelinux;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Provision::Pxelinux;
use Warewulf::RetVal;


my $event = Warewulf::EventHandler->new();
my $pxe = Warewulf::Provision::Pxelinux->new();


sub
update_pxe()
{
    $pxe->update(@_);

    return &ret_success();
}

sub
delete_pxe()
{
    $pxe->delete(@_);

    return &ret_success();
}

sub
setup_pxe()
{
    $pxe->setup(@_);

    return &ret_success();
}


$event->register("node.add", \&update_pxe);
$event->register("node.delete", \&delete_pxe);
$event->register("node.modify", \&update_pxe);
$event->register("wwsh.start", \&setup_pxe);

1;
