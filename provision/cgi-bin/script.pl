#!/usr/bin/perl
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


use CGI;
use Warewulf::DataStore;
use Warewulf::Node;
use Warewulf::File;
use Warewulf::Daemon;
use Warewulf::Logger;

&set_log_level("WARNING");

my $q = CGI->new();
my $db = Warewulf::DataStore->new();

print $q->header();

my $hwaddr = $q->param('hwaddr');
my $type = $q->param('type');
my $remote_addr = $q->remote_addr();


if ($type =~ /^([a-zA-Z0-9\-\._]+)$/) {
    my $scriptname = $1 . "script";
    if ($hwaddr =~ /^([a-zA-Z0-9:]+)$/) {
        $hwaddr = $1;
        
        my $node; 
        my $ipaddr;

        my $nodeSet = $db->get_objects("node", "_hwaddr", $hwaddr);
        foreach my $tnode ($nodeSet->get_list()) {
            if (! $tnode->enabled()) {
                next;
            }
            foreach my $tipaddr ($tnode->ipaddr_list()) {
                if ($tipaddr eq $remote_addr) {
                    $ipaddr = $tipaddr;
                    last;
                }
            }
            $node = $tnode;
        }

        if ($node && $ipaddr) {
            foreach my $script ($node->get("$scriptname")) {
                if (! $script) {
                    next;
                }
                my $obj = $db->get_objects("file", "name", $script)->get_object(0);
                if ($obj->get("format") eq "shell") {
                    my $binstore = $db->binstore($obj->get("_id"));
                    while(my $buffer = $binstore->get_chunk()) {
                        print $buffer;
                    }
                }
            }
        } elsif ($node && !$ipaddr) {
            &eprint("Script request for HWADDR ($hwaddr) from an unauthorized IP ($remote_addr)\n");
            $q->header( -status => '401 Unauthorized' );
        } else {
            &eprint("Script request for HWADDR ($hwaddr) that does not exist\n");
            $q->header( -status => '404 Not Found' );
        }
    } else {
        &eprint("Script request for an invalid HWADDR\n");
        $q->header( -status => '400 Bad Request' );
    }
} else {
    &eprint("Script request for an invalid TYPE\n");
    $q->header( -status => '400 Bad Request' );
}