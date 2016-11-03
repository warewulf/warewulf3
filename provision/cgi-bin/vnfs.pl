#!/usr/bin/perl
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


use CGI;
use Warewulf::Util;
use Warewulf::DataStore;
use Warewulf::Logger;
use Warewulf::Daemon;
use Warewulf::Node;
use Warewulf::Vnfs;
use Warewulf::Provision;
use File::Path;
use File::Basename;
use Fcntl qw(:flock);

&set_log_level("WARNING");

my $q = CGI->new();
my $db = Warewulf::DataStore->new();

my $vnfs_cachedir = "/var/tmp/warewulf_cache/";

sub
lock
{
    my $lfh = shift;

    # Non-Blocking Lock - Fail if lock cannot be obtained
    my $ret = flock($lfh, LOCK_EX|LOCK_NB);

    return $ret;
}

sub
unlock
{
    my $ufh = shift;
    my $ret = flock($ufh, LOCK_UN);

    return $ret;
}

if ($q->param('hwaddr')) {
    my $hwaddr = $q->param('hwaddr');
    my $node;
    if ($hwaddr =~ /^([a-zA-Z0-9:]+)$/) {
        my $hwaddr = $1;
        my $nodeSet = $db->get_objects("node", "_hwaddr", $hwaddr);

        foreach my $tnode ($nodeSet->get_list()) {
            if (! $tnode->enabled()) {
                next;
            }
            $node = $tnode;
        }

        if ($node) {
            my ($node_name) = $node->name();
            my ($vnfsid) = $node->vnfsid();
            if ($vnfsid) {
                my $obj = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);
                if ($obj) {
                    my $vnfs_name = $obj->name();
                    my $vnfs_checksum = $obj->checksum();
                    my ($vnfs_nocache) = $obj->get("nocache");
                    my $use_cache;
                    my $cache_in_progress;

                    #&nprint("Sending VNFS '$vnfs_name' to node '$node_name'\n");

                    if (! $vnfs_nocache) {
                        if (-f "$vnfs_cachedir/$vnfs_name/image.$vnfs_checksum") {
                            &dprint("Found VNFS cache\n");
                            $use_cache = 1;
                        } else {
                            &dprint("Building VNFS cache\n");
                            my $rand = &rand_string(8);
                            my $cache_fh;

                            if (! -d "$vnfs_cachedir/$vnfs_name") {
                                mkpath("$vnfs_cachedir/$vnfs_name");
                            }

                            my $lock_file = "$vnfs_cachedir/$vnfs_name/warewulf.cache.lock";
                            my $lock_fh;

                            if (! open($lock_fh, '>', $lock_file) || ! &lock($lock_fh)) {
                                $cache_in_progress = 1;
                                &eprint("Can't open VNFS cache. Locked by another request.\n");
                            } else {
                                &dprint("VNFS cache lock obtained.\n");

                                open($cache_fh, "> $vnfs_cachedir/$vnfs_name/image.$vnfs_checksum.$rand");
                                my $binstore = $db->binstore($obj->get("_id"));

                                while(my $buffer = $binstore->get_chunk()) {
                                    print $cache_fh $buffer;
                                }
                                if (close($cache_fh)) {
                                    rename("$vnfs_cachedir/$vnfs_name/image.$vnfs_checksum.$rand", "$vnfs_cachedir/$vnfs_name/image.$vnfs_checksum");
                                    foreach my $image (glob("$vnfs_cachedir/$vnfs_name/image.*")) {
                                        if ($image =~ /^([a-zA-Z0-9\/\-\._]+?\/image\.[a-zA-Z0-9]+)$/) {
                                            $image = $1;
                                            my $basename = basename($image);
                                            if ($basename ne "image.$vnfs_checksum") {
                                                &wprint("Clearing old vnfs cache: $image\n");
                                                unlink($image);
                                            }
                                        }
                                    }
                                    $use_cache = 1;
                                }
                                &unlock($fh);
                                close($lock_fh) && unlink($lock_file);
                            }
                        }
                    }

                    if ($use_cache) {
                        &dprint("Sending cached VNFS\n");
                        print $q->redirect("/WW/vnfs_cache/$vnfs_name/image.$vnfs_checksum");

                    } elsif(! $cache_in_progress) {
                        &dprint("Sending VNFS from the data store\n");
                        $q->header(-type=>'application/octet-stream',
                                     -status=>'200',
                                     -attachment=>'vnfs.img');
                        if (my $size = $obj->size()) {
                            $q->header(-Content_length=>$size);
                        }
                        my $binstore = $db->binstore($obj->get("_id"));
                        while(my $buffer = $binstore->get_chunk()) {
                            $q->print($buffer);
                        }
                    } else {
                      &eprint("VNFS is being cached via a different request, try again.\n");
                      $q->header( -status => '503 Service Unavailable' );
                    }

                } else {
                    &eprint("VNFS request for an unknown VNFS (VNFSID: $vnfsid)\n");
                    $q->header( -status => '404 Not Found' );
                }
            } else {
                &eprint("$node_name has no VNFS set\n");
                $q->header( -status => '404 Not Found' );
            }
        } else {
            &eprint("VNFS request for an unknown node (HWADDR: $hwaddr)\n");
            $q->header( -status => '404 Not Found' );
        }
    } else {
        &eprint("VNFS request for a bad hwaddr\n");
        $q->header( -status => '404 Not Found' );
    }
} else {
    &eprint("VNFS request without a hwaddr\n");
    $q->header( -status => '404 Not Found' );
}

# vim: filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
