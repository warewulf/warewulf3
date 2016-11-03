#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 21-config.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use Warewulf::Object;
use Warewulf::Config;

my $cfgpath = "./t";
my $cfgfile = "21-config_test_file.conf";
my $cfgfile2 = "21-config_test_file2.conf";
my %vals = (
    "simple" => "test",
    "some key" => "some value",
    "other.key" => "other.value",
    "test list" => [ "val1", "val2", "value 3", "value four,", "val5", "val6" ],
    "continuation" => [ "first line", "second line" ],
    "list" => [ "one", "two", "three", "four", "five" ],
    "empty value" => "",
    "another blank" => "",
    "yet another blank" => "",
    "multifile key" => [ "file1", "file2" ],
    "second multifile key" => [ "file1", "file2" ]
);
my @t;

plan("tests" => (
         + 1                                # Inheritance tests
         + 6                                # Sanity checks for test config files
         + 5                                # One file at a time tests
         + 3                                # File list tests
         + 8                                # Multipass tests
         + 3 * (2 * scalar(keys(%vals)))    # Value tests (3 objects * 2 tests/key * N keys)
));

# This is useful for using the test suite to double as a debugging tool.
#use Warewulf::Logger;
#&set_log_level("debug");

# Make sure we inherit from Warewulf::Object
isa_ok("Warewulf::Config", "Warewulf::Object");

# Make sure we have our test config file and can read it.
ok(-e "$cfgpath/$cfgfile", "Test config file $cfgfile exists");
ok(-e "$cfgpath/$cfgfile2", "Test config file $cfgfile2 exists");
ok(-r "$cfgpath/$cfgfile", "Test config file $cfgfile is readable");
ok(-r "$cfgpath/$cfgfile2", "Test config file $cfgfile2 is readable");
ok(-s "$cfgpath/$cfgfile", "Test config file $cfgfile is not empty");
ok(-s "$cfgpath/$cfgfile2", "Test config file $cfgfile2 is not empty");

# Make sure we can create an instance with no arguments, then set the path,
# then load the config file.
$t[0] = new_ok("Warewulf::Config", [], "Test Config Object (files)");
can_ok($t[0], "init", "get_path", "set_path", "load", "save");
is($t[0]->set_path($cfgpath), $cfgpath, "Able to set config file search path to $cfgpath");
is($t[0]->load($cfgfile), 1, "Able to load test config file $cfgfile");
is($t[0]->load($cfgfile2), 1, "Able to load test config file $cfgfile2");

# Make sure we can create an instance and load it in one step.
$t[1] = new_ok("Warewulf::Config", [], "Test Config Object (list)");
$t[1]->set_path($cfgpath);
can_ok($t[1], "init", "get_path", "set_path", "load", "save");
is($t[1]->load($cfgfile, $cfgfile2), 2, "Able to load both test config files at once");

# Make sure we can load multiple times and get the same data.
$t[2] = new_ok("Warewulf::Config", [], "Test Config Object (multipass)");
$t[2]->set_path($cfgpath);
can_ok($t[2], "init", "get_path", "set_path", "load", "save");
is($t[2]->load($cfgfile, $cfgfile2), 2, "Load configs (pass 1)");
is($t[2]->load($cfgfile, $cfgfile2), 2, "Load configs (pass 2)");
is($t[2]->load($cfgfile, $cfgfile2), 2, "Load configs (pass 3)");
is($t[2]->load($cfgfile2), 1, "Load 2nd config only (pass 1)");
is($t[2]->load($cfgfile2), 1, "Load 2nd config only (pass 2)");
is($t[2]->load($cfgfile2), 1, "Load 2nd config only (pass 3)");

# Uncomment the below when debugging.
#use Warewulf::Util;
#diag(&examine_object(\@t, "\@t:  "));

# For each object, verify the config data we got.
for (my $i = 0; $i < scalar(@t); $i++) {
    my $t = $t[$i];

    foreach my $key (keys(%vals)) {
        my @t_val;

        @t_val = $t->get($key);
        cmp_ok(scalar(@t_val), '==', ((ref($vals{$key})) ? (scalar(@{$vals{$key}})) : (1)),
               "Actual value count matches expected value count");
        is_deeply(((scalar(@t_val) == 1) ? (\$t_val[0]) : (\@t_val)),
                  ((ref($vals{$key})) ? ($vals{$key}) : (\$vals{$key})),
                  "Test config data $i, key \"$key\"");
    }
}
