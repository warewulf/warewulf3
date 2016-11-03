#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 12-logger.t 1654 2014-04-18 21:59:17Z macabral $
#

use Test::More;
use IO::File;
use Warewulf::Logger (':DEFAULT', '$WWLOG_CRITICAL', '$WWLOG_ERROR', '$WWLOG_WARNING',
                      '$WWLOG_NOTICE', '$WWLOG_INFO', '$WWLOG_DEBUG',
                      '&lprint', '&lprintf');

my $modname = "Warewulf::Logger";
my @funcnames = ('get_log_level', 'set_log_level', 'cprint',
                 'cprintf', 'eprint', 'eprintf', 'wprint',
                 'wprintf', 'nprint', 'nprintf', 'iprint',
                 'iprintf', 'dprint', 'dprintf', 'lprint',
                 'lprintf');
my @ll_test_sets = (
    {
        "in"   => "CRITICAL",
        "out"  => $WWLOG_CRITICAL
    },
    {
        "in"   => "error",
        "out"  => $WWLOG_ERROR
    },
    {
        "in"   => "Warning",
        "out"  => $WWLOG_WARNING
    },
    {
        "in"   => "nOtIcE",
        "out"  => $WWLOG_NOTICE
    },
    {
        "in"   => "info",
        "out"  => $WWLOG_INFO
    },
    {
        "in"   => "debug",
        "out"  => $WWLOG_DEBUG
    },
    {
        "in"   => "ALL",
        "out"  => $WWLOG_CRITICAL
    },
    {
        "in"   => -1,
        "out"  => undef
    },
    {
        "in"   => $WWLOG_CRITICAL,
        "out"  => $WWLOG_CRITICAL
    },
    {
        "in"   => $WWLOG_ERROR,
        "out"  => $WWLOG_ERROR
    },
    {
        "in"   => $WWLOG_WARNING,
        "out"  => $WWLOG_WARNING
    },
    {
        "in"   => $WWLOG_NOTICE,
        "out"  => $WWLOG_NOTICE
    },
    {
        "in"   => $WWLOG_INFO,
        "out"  => $WWLOG_INFO
    },
    {
        "in"   => $WWLOG_DEBUG,
        "out"  => $WWLOG_DEBUG
    },
    {
        "in"   => 999,
        "out"  => undef
    },
    {
        "in"   => "",
        "out"  => undef
    },
    {
        "in"   => "moo",
        "out"  => undef
    },
);
my $ll_test_set_count = scalar(@ll_test_sets);

plan("tests" => (
         + 1                           # Inheritance tests
         + scalar(@funcnames)          # Function presence tests
         + 2 * $ll_test_set_count      # Log level set/get tests
         + 8 + 12 + (1 * 12 + 3)       # Logging and log target tests
));

# Make sure we inherit from Exporter
isa_ok($modname, "Exporter");

# Make sure we can call each function we're expecting.
foreach my $func (@funcnames) {
    can_ok($modname, $func);
}

#######################################
### Log level set/get tests
#######################################
my $last_ll;
foreach my $ll_test (@ll_test_sets) {
    my ($ll_in, $ll_out) = @{$ll_test}{("in", "out")};
    my $result = &set_log_level($ll_in);

    if (defined($ll_out)) {
        cmp_ok($result, '==', $ll_out, "set_log_level($ll_in) returns $ll_out");
    } else {
        ok(!defined($result), "set_log_level($ll_in) returns undef");
    }
    if (defined($result)) {
        $last_ll = $result;
    } else {
        $ll_out = $last_ll;
    }
    is(&get_log_level(), $ll_out, "get_log_level() returns $ll_out");
}
&set_log_level("normal");

#######################################
### Logging and log target tests
#######################################
my $target_scalar;
my @target_array;
my @target_coderef_array;
my $target_coderef = sub { push(@target_coderef_array, $_[0]); };
my $target_obj = IO::File->new(">/dev/null");

# Set up our logging targets.
cmp_ok(&clear_log_target("all"), '==', 6, "&clear_log_target(all) clears all 6 targets");
ok(!defined(&add_log_target("", "none")), "Invalid levels list returns undef");
cmp_ok(&add_log_target(\$target_scalar, "all"), '==', 6, "Set scalar reference target on all 6 levels");
cmp_ok(&add_log_target(\@target_array, "all"), '==', 6, "Set array reference target on all 6 levels");
cmp_ok(&add_log_target($target_coderef, "all"), '==', 6, "Set coderef reference target on all 6 levels");
cmp_ok(&add_log_target($target_obj, "critical", "error", "warning"), '==', 3, "Set IO::File object target on 3 levels");
cmp_ok(&add_log_target("syslog:test:user", "debug"), '==', 1, "Set syslog target on debug level only");
cmp_ok(&add_log_target("/dev/null", "info"), '==', 1, "Set filename target on info level only");

# Generate some output.
cmp_ok(&cprint("Testing cprint()\n"), '==', 4, "cprint() sends to 4 targets");
cmp_ok(&cprintf("Testing %s()\n", "cprintf"), '==', 4, "cprintf() sends to 4 targets");
cmp_ok(&eprint("Testing eprint()\n"), '==', 4, "eprint() sends to 4 targets");
cmp_ok(&eprintf("Testing %s()\n", "eprintf"), '==', 4, "eprintf() sends to 4 targets");
cmp_ok(&wprint("Testing wprint()\n"), '==', 4, "wprint() sends to 4 targets");
cmp_ok(&wprintf("Testing %s()\n", "wprintf"), '==', 4, "wprintf() sends to 4 targets");
cmp_ok(&nprint("Testing nprint()\n"), '==', 3, "nprint() sends to 3 targets");
cmp_ok(&nprintf("Testing %s()\n", "nprintf"), '==', 3, "nprintf() sends to 3 targets");
cmp_ok(&iprint("Testing iprint()\n"), '==', 4, "iprint() sends to 4 targets");
cmp_ok(&iprintf("Testing %s()\n", "iprintf"), '==', 4, "iprintf() sends to 4 targets");
cmp_ok(&dprint("Testing dprint()\n"), '==', 4, "dprint() sends to 4 targets");
cmp_ok(&dprintf("Testing %s()\n", "dprintf"), '==', 4, "dprintf() sends to 4 targets");

# Now let's make sure at least our references contain consistent data.
cmp_ok(scalar(@target_array), '==', 2 * 6, "Array target has correct number of output lines");
for (my $i = 0; $i < scalar(@target_array); $i++) {
    like($target_array[$i], qr/Testing .printf?\(\)$/, "Array target output line $i matches expected format");
}
is_deeply(\@target_coderef_array, \@target_array, "Array and code reference targets' contents match");
is($target_scalar, join('', @target_array), "Array and scalar reference targets' contents match");
