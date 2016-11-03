#!/usr/bin/perl
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


use CGI;
use Digest::MD5 ('md5_hex');
use File::Path;
use Apache2::SubProcess ();
use IO::Select;
use Warewulf::DataStore;
use Warewulf::Logger;
use Warewulf::Daemon;
use Warewulf::Node;
use Warewulf::File;
use Warewulf::DSO::File;
use Warewulf::Util;

# For taint checks
delete @ENV{("IFS", "CDPATH", "ENV", "BASH_ENV")};
$ENV{"PATH"} = "/bin:/usr/bin:/sbin:/usr/sbin";
foreach my $shell ("/bin/bash", "/usr/bin/ksh", "/bin/ksh", "/bin/sh", "/sbin/sh") {
    if (-f $shell) {
        $ENV{"SHELL"} = $shell;
        last;
    }
}

&set_log_level("WARNING");

my $r = shift;
my $q = CGI->new();
my $db = Warewulf::DataStore->new();

my $tmpdir = "/tmp/warewulf";
my $hwaddr = $q->param('hwaddr');
my $fileid = $q->param('fileid');
my $timestamp = $q->param('timestamp');
my $node;

if (! -d $tmpdir) {
    mkpath($tmpdir);
    chmod(0750, $tmpdir);
}

if ($hwaddr =~ /^([a-zA-Z0-9:]+)$/) {
    $hwaddr = $1;

    my $oSet = $db->get_objects("node", "_hwaddr", $hwaddr);
    foreach my $tnode ($oSet->get_list()) {
        if (! $tnode->enabled()) {
            next;
        }
        $node = $tnode;
    }

    if ($node) {
        my $nodeName = $node->name();

        if (! $fileid) {
            my @files = $node->get("fileids");

            print $q->header("text/plain");
            if (scalar(@files)) {
                my $objSet = $db->get_objects("file", "_id", @files);
                my %metadata;

                foreach my $obj ($objSet->get_list()) {
                    if (ref($obj) ne "Warewulf::File") {
                        my $fileid = $obj->id();
                        &wprint("ObjectID ($fileid) is not of type 'Warewulf::File' (metadata request by: $nodeName/$hwaddr)\n");
                        next;
                    }

                    if (ref($obj) eq "Warewulf::File") {
                        my $obj_timestamp = $obj->timestamp() || 0;

                        if ($timestamp and $timestamp >= $obj_timestamp) {
                            next;
                        }

                        my $obj_ftype = $obj->filetypestring();
                        $metadata{$obj_timestamp} .= sprintf("%s %s %s %s %s%04o %s %s\n",
                            $obj->id() || "NULL",
                            $obj->name() || "NULL",
                            $obj->uid() || "0",
                            $obj->gid() || "0",
                            (($obj_ftype eq '-') ? (' ') : ($obj_ftype)),
                            $obj->mode() || "0000",
                            $obj_timestamp,
                            $obj->path() || "NULL"
                        );
                    }
                }
                foreach my $t (sort {$a <=> $b} keys %metadata) {
                    print $metadata{$t};
                }
            }
        } elsif ($fileid =~ /^([0-9]+)$/ ) {
            $fileid = $1;
            my $read_buffer;
            my $send_buffer;

            my $fileObj = $db->get_objects("file", "_id", $fileid)->get_object(0);;

            if ($fileObj) {
                if (ref($fileObj) eq "Warewulf::File") {
                    my $fileID = $fileObj->id();
                    my $cachedir = "$tmpdir/files/$fileID/";
                    my $cachefile = "$cachedir/". $fileObj->checksum();

                    # Initially cache the file if it doesn't already exist locally
                    if (! -f $cachefile) {
                        if (! -d $cachedir) {
                            mkpath($cachedir);
                        }
                        $fileObj->file_export($cachefile);
                    }

                    # Make sure checksum exists before going forward. Otherwise we will remove cached
                    # file below, and send an internal error to the client.
                    if (&digest_file_hex_md5($cachefile) eq $fileObj->checksum()) {

                        if (open(CACHE, $cachefile)) {
                            while(my $line = <CACHE>) {
                                $read_buffer .= $line;
                            }
                            close CACHE;
                        }

                        # Search for all matching variable entries.
                        foreach my $wwstring ($read_buffer =~ m/\%\{[^\}]+\}(?:\[\d+\])?/g) {
                            # Check for format, and seperate into a seperate wwvar string
                            if ($wwstring =~ /^\%\{(.+?)\}(\[(\d+)\])?$/) {
                                my $wwvar = $1;
                                my $wwarrayindex = $3;
                                # Set the current object that we are looking at. This is
                                # important as we iterate through multiple levels.
                                my $curObj = $node;
                                my @keys = split(/::/, $wwvar);
                                while(my $key = shift(@keys)) {
                                    my $val = $curObj->get($key);
                                    if (ref($val) eq "Warewulf::ObjectSet") {
                                        my $find = shift(@keys);
                                        my $o = $val->find("name", $find);
                                        if ($o) {
                                            $curObj = $o;
                                        } else {
                                            &dprint("Could not find object: $find\n");
                                        }

                                    } elsif (ref($val) eq "ARRAY") {
                                        my $v;
                                        if ($wwarrayindex) {
                                            $v = $val->[$wwarrayindex];
                                        } else {
                                            $v = $val->[0];
                                        }
                                        $read_buffer =~ s/\Q$wwstring\E/$v/g;
                                    } elsif ($val) {
                                        $read_buffer =~ s/\Q$wwstring\E/$val/g;
                                    } else {
                                        $read_buffer =~ s/\Q$wwstring\E//g;
                                    }
                                }
                            }
                        }

                        if ($fileObj->interpreter()) {
                            my $interpreter = $fileObj->interpreter();
                            my ($in_fh, $out_fh, $err_fh);
                            my $err_str = "";

                                sub read_data {
                                    my ($fh) = @_;
                                    my $data;
                                    $data = join('', <$fh>);
                                    return ((defined($data)) ? ($data) : (""));
                                }

                                ($in_fh, $out_fh, $err_fh) = $r->spawn_proc_prog($interpreter);
                                print $in_fh $read_buffer;
                                close $in_fh;
                                $send_buffer = read_data($out_fh);
                                $err_str = read_data($err_fh);
                            if ($err_str) {
                                &eprint("FileID ($fileid) interpreter '$interpreter':  $err_str\n");
                            }
                        } elsif ($read_buffer) {
                            $send_buffer = $read_buffer;
                        }

                        if ($send_buffer) {
                            $q->print("Content-Type: application/octet-stream\r\n");
                            $q->print("Content-Disposition: attachment\r\n");
                            $q->print("\r\n");

                            print $send_buffer;
                        }
                    } else {
                        &eprint("FileID ($fileid) cached file checksum does not match bin store, unlinking...\n");
                        $q->print("Content-Type: application/octet-stream\r\n");
                        $q->print("Status: 500\r\n");
                        $q->print("\r\n");
                        unlink($cachefile);
                    }
                } else {
                    &wprint("ObjectID ($fileid) is not of type 'Warewulf::File' (requested by: $nodeName/$hwaddr)\n");
                    $q->print("Content-Type: application/octet-stream\r\n");
                    $q->print("Status: 400\r\n");
                    $q->print("\r\n");
                }
            } else {
                &wprint("FILEID ($fileid) does not exist (requested by: $nodeName/$hwaddr)\n");
                $q->print("Content-Type: application/octet-stream\r\n");
                $q->print("Status: 400\r\n");
                $q->print("\r\n");
            }
        } else {
            # A file ID was given, but its an invalid ID. This needs to error out client so that
            # the client doesn't overwrite the target file.
            &wprint("FILEID ($fileid) contains invalid characters (requested by: $nodeName/$hwaddr)\n");
            $q->print("Content-Type: application/octet-stream\r\n");
            $q->print("Status: 404\r\n");
            $q->print("\r\n");
        }
    } else {
        &wprint("HWADDR ($hwaddr) is undefined\n");
        $q->print("Content-Type: application/octet-stream\r\n");
        $q->print("Status: 404\r\n");
        $q->print("\r\n");
    }
} else {
    &wprint("HWADDR ($hwaddr) contains invalid characters\n");
    $q->print("Content-Type: application/octet-stream\r\n");
    $q->print("Status: 404\r\n");
    $q->print("\r\n");
}
