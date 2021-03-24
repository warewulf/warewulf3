#!/usr/bin/perl
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


use CGI;
use Sys::Syslog;
use Warewulf::DataStore;
use Warewulf::Node;
use Warewulf::Logger;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::Vnfs;
use Warewulf::Provision;

&set_log_level("WARNING");

my $db = Warewulf::DataStore->new();
my $q = CGI->new();
my $hwaddr = $q->param('hwaddr');
my $remote_addr = $q->remote_addr();

print $q->header();

if (! $db) {
    warn("wwprovision: Apache Could not connect to data store!\n");
    openlog("wwprovision", "ndelay,pid", LOG_LOCAL0);
    syslog("ERR", "Could not connect to data store!");
    closelog;
    exit;
}

if ($hwaddr =~ /^([a-zA-Z0-9:]+)$/) {
    my $hwaddr = $1;
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

    my %nhash;

    if (! $node) {
        &eprint("Nodeconfig for HWADDR ($hwaddr) does not exist\n");
        $q->header( -status => '404 Not Found' );
        exit;
    }

    if (! $ipaddr) {
        &eprint("Nodeconfig request for HWADDR ($hwaddr) from an unauthorized IP ($remote_addr)\n");
        $q->header( -status => '403 Forbidden' );
        exit;
    }

    %nhash = $node->get_hash();
    foreach my $key (keys %nhash) {
        my $uc_key = uc($key);
        my $val;

        # Sanitize $uc_key to only contain characters which are valid
        # in the name of a shell variable for bash and POSIX sh.
        $uc_key =~ s/\W//g;

        # For arrays, print the first element.  Otherwise, print the value.
        if (ref($nhash{"$key"}) eq "ARRAY") {
            $val = join(",", @{$nhash{$key}});
        } elsif (ref(\$nhash{"$key"}) eq "SCALAR") {
            $val = $nhash{$key};
        } elsif (ref($nhash{"$key"}) eq "Warewulf::ObjectSet") {
            my @names;
            foreach my $o ($nhash{"$key"}->get_list()) {
                my $n = $o->get("name");
                if (defined($n)) {
                    push(@names, $n);
                }
            }
            $val = join(",", @names);
        } else {
            $val = "";
        }
        print "WW$uc_key=\"$val\"\nexport WW$uc_key\n";

        # This section is for derived keys which should not overlap with object
        # member names, thus should have the prefix "WW__"
        if ($uc_key eq "NETDEVS") {
            my $val;
            if (ref($nhash{"$key"}) eq "Warewulf::ObjectSet") {
                my @entries;
                foreach my $o ($nhash{"$key"}->get_list()) {
                    if ($o->get("name") and $o->get("ipaddr")) {
                        push(@entries, $o->get("name") ."=". $o->get("ipaddr"));
                    }
                }
                $val = join(",", @entries);
                print "WW__NETDEVLIST=\"$val\"\nexport WW__NETDEVLIST\n";
            }
        }


    }
    my ($vnfsid) = $node->vnfsid();
    if ($vnfsid) {
        my $vnfs_obj = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);
        if ($vnfs_obj) {
            my $vnfs_name = $vnfs_obj->name();
            print "WWVNFS_NAME=\"$vnfs_name\"\nexport WWVNFS_NAME\n";
            my $vnfs_checksum = $vnfs_obj->checksum();
            print "WWVNFS_CHECKSUM=\"$vnfs_checksum\"\nexport WWVNFS_CHECKSUM\n";
        }
    }
} else {
        &eprint("Nodeconfig request for an invalid HWADDR\n");
        $q->header( -status => '400 Bad Request' );
}

