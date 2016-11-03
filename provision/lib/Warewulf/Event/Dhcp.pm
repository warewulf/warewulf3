# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Dhcp.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Event::Dhcp;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Provision::DhcpFactory;
use Warewulf::RetVal;


my $event = Warewulf::EventHandler->new();


sub
update_dhcp()
{
    my $dhcp = Warewulf::Provision::DhcpFactory->new();
    $dhcp->persist();

    return &ret_success();
}



$event->register("node.add", \&update_dhcp);
$event->register("node.delete", \&update_dhcp);
$event->register("node.modify", \&update_dhcp);

1;
