#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 13-retval.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use Warewulf::RetVal;

my $modname = "Warewulf::RetVal";
my @methods = ("new", "init", "error", "msg", "message", "result",
               "results", "succeeded", "is_success", "is_ok",
               "failed", "is_failure","to_string", "debug_string");

plan("tests" => (
         + 12             # Instantiation, method, and initialization tests
         + 2              # String representation method tests
         + 4              # Static method tests
));

my ($obj1, $obj2, $obj3);

# Make sure we can create identical objects regardless of whether values
# are passed in via set(), init() directly, or the constructor.
$obj1 = new_ok($modname, [], "Instantiate RetVal 1 (no args)");
$obj1->init(1, "error", 777);
can_ok($obj1, @methods);

$obj2 = new_ok($modname, [], "Instantiate RetVal 2 (no args)");
$obj2->error(1);
$obj2->msg("error");
$obj2->results(777);

$obj3 = new_ok($modname, [ 1, "error", 777 ], "Instantiate RetVal 3 (with args)");

is($obj1->error(), 1, "RetVal error code matches supplied initializer");
is($obj1->message(), "error", "RetVal error message matches supplied initializer");
is($obj1->results(), 777, "RetVal result set matches supplied initializer");
is_deeply($obj1, $obj2, "RetVals 1 and 2 are identical");
is_deeply($obj2, $obj3, "RetVals 2 and 3 are identical");

$obj2->init();
isnt($obj2->error(), 1, "init() resets error code");
isnt($obj2->msg(), "error", "init() resets error message");
isnt($obj2->result(), 777, "init() resets result set");

undef $obj2;
undef $obj3;

#######################################
### String representation method tests
#######################################
is($obj1->to_string(), "Error 1:  error", "to_string() method returns proper result");
is($obj1->debug_string(), "{ $obj1:  ERROR 1, MESSAGE \"error\", 1 RESULTS }", "debug_string() method returns proper result");
undef $obj1;

#######################################
### Static method tests
#######################################
$obj1 = Warewulf::RetVal->ret_fail();
can_ok($obj1, @methods);
is($obj1->error(), -1, "RetVal default error code is -1");
is($obj1->msg(), "", "RetVal default error message is empty");
is(scalar($obj1->result()), 0, "RetVal defaults to empty result set");
