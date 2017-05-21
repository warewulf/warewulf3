#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 10-acvars.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use Warewulf::ACVars;

my @var_names = (
    "PROGNAME",
    "VERSION",
    "PREFIX",
    "STATEDIR",
    "SYSCONFDIR",
    "LIBDIR",
    "DATAROOTDIR",
    "DATADIR",
    "LIBEXECDIR",
    "PERLMODDIR"
);
my $acvars;
my (@a, @b);

plan("tests" => (
         + 2                                           # Object tests
         + 2                                           # Variable count tests
         + (scalar(@var_names) * (1 + (2 * (6 * 2))))  # Invocation/value tests
     ));

# Can we create a Warewulf::ACVars object?
$acvars = new_ok("Warewulf::ACVars");
can_ok($acvars, "new", "get", "vars");

# Make sure we account for all the variables that exist currently (we explicitly ignore GITVERSION).
cmp_ok(scalar(@var_names), '==', scalar($acvars->vars())-1,
       "All Warewulf::ACVars variable names accounted for");
# Make sure static and non-static calls both work (and match).
@a = $acvars->vars();
@b = Warewulf::ACVars::vars();
is_deeply(\@a, \@b, "Static and non-static invocations of vars() match");

# Make sure we get back the same value regardless of case
# and that it begins with a '/'.
foreach my $orig_var (@var_names) {
    my $actual;

    # This is our "authoritative value."  All other returns are compared against this.
    $actual = &Warewulf::ACVars::get($orig_var);

    # Try uppercase and lowercase both.  They should be identical.
    foreach my $var ($orig_var, lc($orig_var)) {
        my %schemes;

        # Try all the different ways we can obtain the value.
        %schemes = (
            "Function call on module" => 'Warewulf::ACVars::get("' . $var . '")',
            "Static method call" => 'Warewulf::ACVars->get("' . $var . '")',
            "Instance method call" => '$acvars->get("' . $var . '")',
            "Function call on module by name" => 'Warewulf::ACVars::' . $var . '()',
            "Static method call by name" => 'Warewulf::ACVars->' . $var . '()',
            "Instance method call by name" => '$acvars->' . $var . '()'
        );
        foreach my $test (sort(keys(%schemes))) {
            my $scheme = $schemes{$test};
            my $val;

            $val = eval "$scheme";
            ok(defined($val) && $val, "$var is returned ($test)");
            cmp_ok($val, 'eq', $actual, "$var values match ($test)");
        }
    }

    # Sanity checks on the actual values.  Only done once per variable name, not per scheme.
    if ($orig_var eq "PROGNAME") {
        my $len = length($actual);

        cmp_ok(substr($0, -$len, $len), 'eq', $actual, "PROGNAME matches \$0");
    } elsif ($orig_var eq "VERSION") {
        like($actual, qr/^[\d\.]+$/, "VERSION is a valid version number");
    } else {
        like($actual, qr/^\//, "$orig_var starts with '/'");
    }
}
