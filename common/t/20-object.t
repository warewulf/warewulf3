#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 20-object.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use Warewulf::Object;

my $modname = "Warewulf::Object";
my @methods = ("new", "init", "get", "set", "add", "del", "prop",
               "get_hash", "to_string", "debug_string");

plan("tests" => (
         + 8              # Instantiation, method, and initialization tests
         + 2              # String representation method tests
         + 1              # get_hash() method tests
         + 29             # get()/set() method tests
         + 5+5+3+3+7+7+3  # add()/del() method tests
         + 3+2+2+2        # prop() wrapper method tests
         + 4+4+3          # clone() method tests
));

my ($obj1, $obj2, $obj3);

# Make sure we can create identical objects regardless of whether values
# are passed in via set(), init() directly, or the constructor.
$obj1 = new_ok($modname, [], "Instantiate Object 1 (no args)");
$obj1->init("name" => "me");
can_ok($obj1, @methods);

$obj2 = new_ok($modname, [], "Instantiate Object 2 (no args)");
$obj2->set("name", "me");

$obj3 = new_ok($modname, [ "name" => "me" ], "Instantiate Object 3 (with args)");

is($obj1->get("name"), "me", "Object member matches supplied initializer");
is_deeply($obj1, $obj2, "Objects 1 and 2 are identical");
is_deeply($obj2, $obj3, "Objects 2 and 3 are identical");

$obj2->init();
isnt($obj2->get("name"), "me", "init() resets all object members");

undef $obj2;
undef $obj3;

#######################################
### String representation method tests
#######################################
is($obj1->to_string(), "{ $obj1 }", "to_string() method returns proper result");
is($obj1->debug_string(), "{ $obj1:  \"NAME\" => \"me\" }", "debug_string() method returns proper result");

#######################################
### get_hash() method tests
#######################################
my $href;
$href = $obj1->get_hash();
is_deeply($href, { "NAME" => "me" }, "get_hash() returns correct data");

#######################################
### get()/set() method tests
#######################################
my $test_scalar = "test";
my @test_array = ("interfaces", "eth0", "eth1", "eth2", "eth3");
my %test_hash = ( "NAME" => "Bob", "ADDRESS" => "Elsewhere", "PHONE" => "1-800-222-3334" );
my %test_complex = (
    "name" => "n0000",
    "groups" => [ "group1", "group2", "group3" ],
    "devices" => {
        "eth0" => "10.0.0.0",
        "eth1" => "10.1.0.0",
        "eth2" => "10.2.0.0"
    }
);
my @tmp = @test_array;
my $fh;

# Simple sanity checks
ok(!defined($obj1->set()), "set() with no key returns undef");
ok(!defined($obj1->set("name")), "set() with only a key returns undef");

# set() with a hash reference
is($obj1->set(\%test_hash), \%test_hash, "set() with a hashref succeeds and returns the hashref");
is($obj1->get("name"), "Bob", "get() returns correct member value for \"name\"");
is($obj1->get("address"), "Elsewhere", "get() returns correct member value for \"address\"");
is($obj1->get("phone"), "1-800-222-3334", "get() returns correct member value for \"phone\"");
is_deeply(scalar($obj1->get_hash()), \%test_hash, "get_hash() returns accurate representation of object");

# set() with an array (key and values)
shift @tmp;
$obj1->init();
is($obj1->set(@test_array), 4, "set() with an array returns the number of items set");
is(scalar($obj1->get("interfaces")), $tmp[0], "scalar(get()) returns the first element");

# set() with an array reference
$obj1->init();
is($obj1->set(\@test_array), 4, "set() with an array reference works just like an array");
isnt($obj1->get("interfaces"), \@test_array, "get() does NOT return the original array reference");
is(scalar($obj1->get("interfaces")), $tmp[0], "scalar(get()) returns the first element");

# set() with a complex, hashref-based data structure
is($obj1->init(\%test_complex), $obj1, "init() with complex hashref returns the object");
is($obj1->get("name"), $test_complex{"name"}, "Complex object set test -- scalar value");
@tmp = $obj1->get("groups");
is_deeply(\@tmp, $test_complex{"groups"}, "Complex object set test -- array");
$test_complex{"groups"}[0] = "replaced";
@tmp = $obj1->get("groups");
isnt($tmp[0], "replaced", "Complex object set test -- arrayref set by value, not by reference");
$test_complex{"groups"}[0] = $tmp[0];
isnt(scalar($obj1->get("devices")), $test_complex{"devices"}, "Complex object set test -- hashref set by value");
is_deeply(scalar($obj1->get("devices")), $test_complex{"devices"}, "Complex object set test -- hash");

# Any other reference should be an error
ok(!defined($obj1->set(sub { 1 })), "obj->set(<coderef>) returns undef");
open($fh, '+>', undef);
ok(!defined($obj1->set($fh)), "obj->set(<globref>) returns undef");
close($fh);
ok(!defined($obj1->set(\$test_scalar)), "obj->set(<scalarref>) returns undef");

# Checks for invalid input
ok(!defined($obj1->set("devices", undef)), "obj->set(\"key\", undef) returns undef");
ok(!defined($obj1->get("devices")), "obj->set(\"key\", undef) removes the member variable");
is($obj1->get("name"), $test_complex{"name"}, "obj->set(\"key\", undef) leaves other members intact");
@tmp = $obj1->get("groups");
is_deeply(\@tmp, $test_complex{"groups"}, "obj->set(\"key\", undef) leaves other members intact");

# Make sure simple key/value pairs work correctly.
is($obj1->set("name", "n0001"), "n0001", "obj->set(\"key\", \"value\") returns \"value\"");
is($obj1->get("name"), "n0001", "obj->set(\"key\", \"value\") changes member \"key\" to \"value\"");

# Append an item by setting the value to the previous value plus the new one.
push(@{$test_complex{"groups"}}, $test_scalar);
is(scalar($obj1->set("groups", $obj1->get("groups"), $test_scalar)), scalar(@{$test_complex{"groups"}}),
   "Object member list append using set/get returns new value count");
@tmp = $obj1->get("groups");
is_deeply(\@tmp, $test_complex{"groups"}, "Object member list append using set/get works");

#######################################
### add()/del() method tests
#######################################
my @test_list = (0, 1, 2, 3, 4);

$obj1->init();
is(scalar($obj1->add("stuff", @test_list)), scalar(@test_list), "obj->add(\"key\", <list>) returns correctly");
@tmp = $obj1->get("stuff");
is_deeply(\@tmp, \@test_list, "obj->add(\"key\", <list>) works correctly");
is(scalar($obj1->del("stuff", @test_list)), 0, "obj->del(\"key\", <list>) purges the object member completely");
ok(!defined($obj1->get("stuff")), "obj->del(\"key\", <list>) works correctly");
is_deeply($obj1, {}, "Object is fully purged");

is(scalar($obj1->add("stuff", $test_list[$#test_list])), 1, "obj->add(\"key\", <item>) returns correctly");
@tmp = $obj1->get("stuff");
is_deeply(\@tmp, [ $test_list[$#test_list] ], "obj->add() creates an array, even for a single item");
is(scalar($obj1->del("stuff", $test_list[$#test_list])), 0, "obj->del(\"key\", <item>) purges the object member completely");
ok(!defined($obj1->get("stuff")), "obj->del(\"key\", <item>) works correctly");
is_deeply($obj1, {}, "Object is fully purged");

$obj1->init("stuff", @test_list);
is(scalar($obj1->del("stuff", reverse(@test_list))), 0, "obj->del(\"key\", <reversed list>) purges the object member completely");
ok(!defined($obj1->get("stuff")), "obj->del(\"key\", <list>) works correctly");
is_deeply($obj1, {}, "Object is fully purged");

$obj1->init("stuff", sort { rand(2) - 1; } @test_list);
is(scalar($obj1->del("stuff", sort { rand(2) - 1; } @test_list)), 0,
   "obj->del(\"key\", <randomized list>) purges the object member completely");
ok(!defined($obj1->get("stuff")), "obj->del(\"key\", <list>) works correctly");
is_deeply($obj1, {}, "Object is fully purged");

$obj1->init();
ok(!defined(scalar($obj1->add())), "obj->add() returns undef");
ok(!defined(scalar($obj1->del())), "obj->del() returns undef");
is(scalar($obj1->add("stuff")), 0, "obj->add(\"key\") creates an empty member variable");
@tmp = $obj1->get("stuff");
is(scalar(@tmp), 0, "obj->add(\"key\") works correctly");
is_deeply(\@tmp, [], "obj->add(\"key\") created the empty member variable");
is(scalar($obj1->del("stuff")), 0, "obj->del(\"key\") has removed the empty member variable");
is(scalar($obj1->del("moo")), 0, "obj->del(\"bad key\") returns empty list");

$obj1->init("stuff" => 1);
is(scalar($obj1->add("stuff", 2, 3, 4)), 4, "obj->add(\"oldkey\", <list>) properly converts a single-value member to a list");
@tmp = $obj1->get("stuff");
is_deeply(\@tmp, [ 1, 2, 3, 4 ], "obj->add(\"oldkey\", <list>) appends new values correctly");
is(scalar($obj1->add("stuff", 3, 4, 1, 2)), 4, "obj->add(\"oldkey\", <dupes>) properly ignores duplicate values");
@tmp = $obj1->get("stuff");
is_deeply(\@tmp, [ 1, 2, 3, 4 ], "obj->add(\"oldkey\", <dupes>) does not change the member variable");
is(scalar($obj1->add("stuff", @test_list)), scalar(@test_list), "obj->add(\"oldkey\", <some dupes>) filters duplicates");
@tmp = $obj1->get("stuff");
is_deeply(scalar(@tmp), scalar(@test_list), "obj->add(\"oldkey\", <some dupes>) merges correctly");
is(scalar($obj1->del("stuff", $test_list[$#test_list])), $#test_list,
   "obj->del(\"key\", <item>) removes an item and leaves the rest");

$obj1->init("stuff" => 5);
is_deeply($obj1->get("stuff"), 5, "Before obj->del(), we have a scalar");
is(scalar($obj1->del("stuff", 2)), 1, "obj->del(\"key\", <nonexistent item>) still has a single value");
@tmp = $obj1->get("stuff");
is_deeply(\@tmp, [ 5 ], "But now it's an array");

#######################################
### prop() wrapper method tests
#######################################
sub name { return $_[0]->prop("name", qr/^(\w+)$/, @_[1..$#_]); }
sub id { return $_[0]->prop("id", 0, @_[1..$#_]); }
sub
base
{
    # This example is more complex, so we'll make it more readable.
    my ($self, @vals) = @_;
    my $vsub = sub {
        my $a = $_[0];

        # Only accept even numbers.
        if ($a != int($a)) {
            return undef;
        } elsif ($a % 2 == 0) {
            return $a;
        } else {
            return undef;
        }
    };

    return $self->prop("base", $vsub, @vals);
}

$obj1->init();
name($obj1, "test");  # Simulate $obj1->name("test")
id($obj1, 1);         # Simulate $obj1->id(1)
base($obj1, 2);       # Simulate $obj1->base(2)

is(name($obj1), "test", "obj->prop() works for get/set with regexp match");
is(id($obj1), 1, "obj->prop() works for get/set without regexp match");
is(base($obj1), 2, "obj->prop() works for get/set with coderef validator");

is(name($obj1, "\t\t\t\t"), "test", "obj->prop() returns original value if new value fails regexp match");
is(base($obj1, 3), 2, "obj->prop() returns original value if new value fails coderef validator");

id($obj1);
is(id($obj1), 1, "obj->prop() doesn't delete value if undef isn't explicitly passed");
id($obj1, undef);
ok(!defined(id($obj1)), "obj->prop() deletes value if undef is explicitly passed");

is(name($obj1, "newname"), "newname", "obj->prop() can reset existing member value");
name($obj1, undef);
ok(!defined(name($obj1)), "obj->prop() deletes value for member with validator");
undef $obj1;

#######################################
### clone() tests
#######################################
my ($href1, $href2);

$obj1 = new_ok($modname, [], "Instantiate new object for cloning");
$obj1->init({"name" => "cloned", "properties" => [ 1, 2, 3, 4 ]});
$obj3 = new_ok($modname, [{ "name" => "child", "properties" => [ 5, 6, 7, 8 ] }], "Instantiate child object");
$obj1->set("child", $obj3);
$obj2 = $obj1->clone();
isnt($obj2, $obj1, "Cloned object does not refer to the original object");
is($obj2->get("name"), $obj1->get("name"), "Names are the same");

$href1 = $obj1->get_hash();
$href2 = $obj2->get_hash();
is_deeply($href1, $href2, "Object contents are identical");
isnt($href1->{"PROPERTIES"}, $href2->{"PROPERTIES"}, "References differ for \"PROPERTIES\" member");
isnt($href1->{"CHILD"}, $href2->{"CHILD"}, "References to \"CHILD\" subobjects differ");
isnt($href1->{"CHILD"}{"PROPERTIES"}, $href2->{"CHILD"}{"PROPERTIES"}, "Child object references to \"PROPERTIES\" members differ");

undef $obj2;
$obj2 = $obj1->clone("name", "clone");
isnt($obj2, $obj1, "Cloned object does not refer to the original object");
isnt($obj2->get("name"), $obj1->get("name"), "Names are no longer the same");
is($obj2->get("name"), "clone", "New name took effect");
