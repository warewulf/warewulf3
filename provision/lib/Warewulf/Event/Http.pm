# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2021, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#

package Warewulf::Event::Http;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Provision::HttpFactory;
use Warewulf::RetVal;


my $event = Warewulf::EventHandler->new();


sub
update_http()
{

    my $http = Warewulf::Provision::HttpFactory->new();
    $http->persist();

    return &ret_success();
}



$event->register("node.add", \&update_http);
$event->register("node.delete", \&update_http);
$event->register("node.modify", \&update_http);

1;
