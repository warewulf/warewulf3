#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 00-dependencies.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;

my @module_list = (
    "CGI",
    "DBI",
    "Digest::MD5",
    "Exporter",
    "File::Basename",
    "File::Path",
    "Getopt::Long",
    "IO::File",
    "IO::Handle",
    "IO::Pipe",
    "IO::Select",
    "Socket",
    "Storable",
    "Sys::Syslog",
    #"Term::ReadLine",
    "Text::ParseWords"
);

plan("tests" => scalar(@module_list));

foreach my $module (@module_list) {
    use_ok($module);
}
