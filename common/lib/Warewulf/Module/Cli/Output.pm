#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


package Warewulf::Module::Cli::Output;

use Warewulf::Logger;

our @ISA = ('Warewulf::Module::Cli');


sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub
exec()
{
    my ($self, $command) = @_;

    if ($command) {
        if ($command eq "help") {
            print $self->help();
            return 1;
        }

        if (uc($command) eq "NORMAL") {
            &set_log_level("NOTICE");
        } elsif (uc($command) eq "QUIET") {
            &set_log_level("WARNING");
        } elsif (uc($command) eq "VERBOSE") {
            &set_log_level("INFO");
        } elsif (uc($command) eq "DEBUG") {
            &set_log_level("DEBUG");
        } elsif ($command) {
            &eprint("Unknown output level: $command\n");
            return undef;
        }
    }

    if (&get_log_level() eq $Warewulf::Logger::WWLOG_CRITICAL) {
        &nprint("Current output level: CRITICAL\n");
    } elsif (&get_log_level() eq $Warewulf::Logger::WWLOG_ERROR) {
        &nprint("Current output level: ERROR\n");
    } elsif (&get_log_level() eq $Warewulf::Logger::WWLOG_WARNING) {
        &nprint("Current output level: WARNING\n");
    } elsif (&get_log_level() eq $Warewulf::Logger::WWLOG_NOTICE) {
        &nprint("Current output level: NORMAL\n");
    } elsif (&get_log_level() eq $Warewulf::Logger::WWLOG_INFO) {
        &nprint("Current output level: VERBOSE\n");
    } elsif (&get_log_level() eq $Warewulf::Logger::WWLOG_DEBUG) {
        &nprint("Current output level: DEBUG\n");
    } else {
        &iprint("Resetting output level: NORMAL\n");
        &set_log_level("NOTICE");
    }

    return 1;
}


sub
complete()
{
    my ($self) = @_;

    return("normal", "quiet", "verbose", "debug");
}


sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     output [command]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "    This command sets the desired command output verbosity level.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         normal          The standard (and default) output level intended for\n";
    $h .= "                         normal usage\n";
    $h .= "         quiet           Only print warning, error, or critical messages.\n";
    $h .= "         verbose         Increase verbosity over the normal output level\n";
    $h .= "         debug           Show debugging messages (very verbose)\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> output verbose\n";
    $h .= "     Warewulf> output normal\n";
    $h .= "\n";

    return($h);
}



sub
summary()
{
    my $output;

    $output .= "Set the output verbosity level";

    return($output);
}


1;
