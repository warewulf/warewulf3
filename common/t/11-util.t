#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 11-util.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use File::Basename;
use Warewulf::Util;

my $modname = "Warewulf::Util";
my @funcnames = ('rand_string', 'caller_fixed', 'get_backtrace',
                 'backtrace', 'croak', 'progname', 'homedir',
                 'expand_bracket', 'uid_test', 'ellipsis',
                 'digest_file_hex_md5', 'is_tainted', 'examine_object');
my $rs_test_length_max = 128;
my $rs_test_rand_count = 1000;
my $rs_test_rand_length = 32;
my $bt_test_sub_count = 16;
my @eb_test_sets = (
    {
        "in"  => [ "n0[00-00]0", "n00[01-03]", "n[0004-0005]" ],
        "out" => [ "n0000", "n0001", "n0002", "n0003", "n0004", "n0005" ]
    },
    {
        "in"  => [ "n[0-0009]" ],
        "out" => [ "n0000", "n0001", "n0002", "n0003", "n0004", "n0005", "n0006", "n0007", "n0008", "n0009" ]
    },
    {
        "in"  => [ "[0-3]node" ],
        "out" => [ "0node", "1node", "2node", "3node" ]
    },
    {
        "in"  => [ "node[8-4].test" ],
        "out" => [ "node4.test", "node5.test", "node6.test", "node7.test", "node8.test" ]
    },
    {
        "in"  => [ "" ],
        "out" => [ "" ]
    },
    {
        "in"  => [ ],
        "out" => [ ]
    }
);
my $eb_test_set_count = scalar(@eb_test_sets);
my @el_test_sets = (
    {
        "desc" => "arg check - \$length == 0",
        "in"   => [ 0, "lkjsdfliuaslienksdif", "middle" ],
        "out"  => undef
    },
    {
        "desc" => "arg check - \$text == \"\"",
        "in"   => [ 255, "" ],
        "out"  => undef
    },
    {
        "desc" => "arg check - Location \"START\" (value and case)",
        "in"   => [ 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "START" ],
        "out"  => "...UVWXYZ"
    },
    {
        "desc" => "arg check - Location \"middle\" (value and case)",
        "in"   => [ 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "MiDDLe" ],
        "out"  => "ABC...XYZ"
    },
    {
        "desc" => "arg check - Location \"end\" (value and case)",
        "in"   => [ 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "eND" ],
        "out"  => "ABCDEF..."
    },
    {
        "desc" => "arg check - Invalid location",
        "in"   => [ 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "moo" ],
        "out"  => "ABC...XYZ"
    },
    {
        "desc" => "arg check - Missing location",
        "in"   => [ 9, "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ],
        "out"  => "ABC...XYZ"
    },
    {
        "desc" => "logic check - Length limit <= 3 but actual length > limit",
        "in"   => [ 2, "abcd" ],
        "out"  => ".."
    },
    {
        "desc" => "logic check - Very small length limit, short string, start",
        "in"   => [ 4, "abcde", "start" ],
        "out"  => "...e"
    },
    {
        "desc" => "logic check - Very small length limit, short string, middle",
        "in"   => [ 4, "abcde", "middle" ],
        "out"  => "...e"
    },
    {
        "desc" => "logic check - Very small length limit, short string, end",
        "in"   => [ 4, "abcde", "end" ],
        "out"  => "a..."
    },
    {
        "desc" => "",
        "in"   => [ 255, "short string" ],
        "out"  => "short string"
    },
);
my $el_test_set_count = scalar(@el_test_sets);
my %md5_test_files = (
    "11-util-md5_test_1.txt" => "52a766d0c00aafba64fe02552e1cea46",
    "11-util-md5_test_2.txt" => "630e7135b2206004676e82584c59af45"
);
my $md5_test_count = scalar(keys(%md5_test_files));

plan("tests" => (
         + 1                                              # Inheritance tests
         + scalar(@funcnames)                             # Function presence tests
         + $rs_test_length_max + 1                        # Random string length tests
         + $rs_test_rand_count                            # Random string uniqueness tests
         + 1 + 5 * ($bt_test_sub_count + 1)               # Stack trace tests
         + 1                                              # progname() test
         + 3                                              # homedir() tests
         + $eb_test_set_count                             # expand_bracket() tests
         + 5                                              # uid_test() tests
         + $el_test_set_count                             # ellipsis() tests
         + 1 + 1 * $md5_test_count                        # digest_file_hex_md5() tests
         ### Not tested:  croak(), is_tainted(), examine_object()
));

# This is useful for using the test suite to double as a debugging tool.
#use Warewulf::Logger;
#&set_log_level("debug");

# Make sure we inherit from Exporter
isa_ok($modname, "Exporter");

# Make sure we can call each function we're expecting.
foreach my $func (@funcnames) {
    can_ok($modname, $func);
}

#######################################
### rand_string() tests
#######################################
my %randstrings;

# Generate random strings of particular lengths and make
# sure we get back what we asked for.
foreach my $strlen (0..$rs_test_length_max) {
    my $rs = &rand_string($strlen);
    cmp_ok(length($rs), '==', $strlen, "Generate random string of length $strlen");
}

# Generate lots of random strings of a particular sufficient
# length and verify that none of them repeat.
foreach my $i (0..($rs_test_rand_count-1)) {
    my $rs = &rand_string($rs_test_rand_length);

    ok(!exists($randstrings{$rs}), "Generate $rs_test_rand_count unique random strings");
    $randstrings{$rs} = 1;
}
%randstrings = ();  # Free memory


#######################################
### caller_fixed() tests
#######################################
my @bt_test_subs;
# The variable below gives us a fixed base line number so that the tests
# below can use an offset from this line rather than hard-coded line numbers.
my $bt_l = __LINE__;

# Create a series of anonymous subroutines.  Each one will call
# the next higher one until we get to the top.  The top-level
# subroutine will check the stack all the way down to the bottom
# to make sure everything matches up with what we expect.
for (my $i = 0; $i < $bt_test_sub_count; $i++) {
    $bt_test_subs[$i] = sub {
        my ($depth) = @_;
        if (++$depth < $bt_test_sub_count) {
            &{$bt_test_subs[$depth]}($depth);   # *01* &caller_fixed(1..count-1) point here ($bt_l + 10).
        } else {
            foreach my $frame (0..$depth) {
                my @my_caller = &caller_fixed($frame);  # *02* &caller_fixed(0) points here ($bt_l + 13).
                is($my_caller[0], __PACKAGE__, "&caller_fixed() returns correct package name (frame $frame)");
                is($my_caller[1], basename(__FILE__), "&caller_fixed() returns correct file name (frame $frame)");
                if ($frame == $depth) {
                    # The line number in this test must point to marker *04* below.
                    is($my_caller[2], $bt_l + 39, "&caller_fixed() returns correct line number (frame $frame)");
                    is($my_caller[3], "MAIN()", "&caller_fixed() returns correct subroutine name (frame $frame)");
                } else {
                    # The line number in this test must point to markers *01* and *02*, respectively, above.
                    is($my_caller[2], $bt_l + (($frame) ? (10) : (13)), "&caller_fixed() returns correct line number (frame $frame)");
                    is($my_caller[3], "__ANON__()", "&caller_fixed() returns correct subroutine name (frame $frame)");
                }
            }
            # Test &get_backtrace() while we're at it.
            my @bt = &get_backtrace();  # *03* The backtrace will point here ($bt_l + 27).
            cmp_ok(scalar(@bt), '==', $bt_test_sub_count + 1, "Backtrace gives proper depth");
            foreach my $frame (0..$bt_test_sub_count) {
                my $file = basename(__FILE__);
                my ($m1, $m3, $m4) = ($bt_l + 10, $bt_l + 27, $bt_l + 39);
                # The line numbers in the test below must point to markers *01*, *03*, and *04*
                like($bt[$frame], qr/^[ ]{$frame}\[$frame\] $file:($m1|$m3|$m4) \| (MAIN|__ANON__)\(\)$/,
                     "Backtrace has correct format");
            }
        }
    };
}
&{$bt_test_subs[0]}(0);  # *04* &caller_fixed($bt_test_sub_count) points here ($bt_l + 39).
@bt_test_subs = ();  # Free memory

#######################################
### progname() test
#######################################
is(progname(), basename($0), "progname() returns the correct value");

#######################################
### homedir() tests
#######################################
my %save_env = %ENV;

if (! $ENV{"HOME"}) {
    $ENV{"HOME"} = "/";
}
if (! $ENV{"LOGDIR"}) {
    $ENV{"LOGDIR"} = $ENV{"HOME"};
}
is(&homedir(), $ENV{"HOME"}, "homedir() returns \$HOME ($ENV{HOME})");
delete $ENV{"HOME"};
is(&homedir(), $ENV{"LOGDIR"}, "homedir() returns \$LOGDIR ($ENV{LOGDIR})");
delete $ENV{"LOGDIR"};
is(&homedir(), (((getpwuid($<))[7]) || ""), "homedir() returns passwd data");
%ENV = %save_env;

#######################################
### expand_bracket() tests
#######################################
for (my $i = 0; $i < scalar(@eb_test_sets); $i++) {
    my ($eb_in, $eb_out) = (@{$eb_test_sets[$i]}{("in", "out")});
    my @eb_nodeset = &expand_bracket(@{$eb_in});
    is_deeply(\@eb_nodeset, $eb_out, "Bracket expression(s) properly expanded, set $i");
}

#######################################
### uid_test() tests
#######################################
ok(&uid_test($>), "&uid_test(EUID) is true");
ok(!&uid_test($> + 1), "&uid_test(EUID+1) is false");
ok((($> != 0) xor &uid_test(0)), "&uid_test(0) provides accurate result");
ok((($< != $>) xor &uid_test($<)), "&uid_test() tests EUID ($>) not RUID ($<)");
cmp_ok(&uid_test(), '==', 0, "&uid_test() (with no argument) returns false");

#######################################
### ellipsis() tests
#######################################
foreach my $el_test (@el_test_sets) {
    my ($el_desc, $el_in, $el_out) = @{$el_test}{("desc", "in", "out")};
    my $result = &ellipsis(@{$el_in});
    is($result, $el_out, "ellipsis() $el_desc");
}

#######################################
### digest_file_hex_md5() tests
#######################################
ok(!defined(&digest_file_hex_md5("random name")), "Unreadable/invalid file returns undef");
foreach my $md5_file (keys(%md5_test_files)) {
    my $fn = $md5_file;

    if (! -e $fn) {
        $fn = "t/$fn";
    }
    is(&digest_file_hex_md5($fn), $md5_test_files{$md5_file}, "Test file $fn hashes correctly");
}
