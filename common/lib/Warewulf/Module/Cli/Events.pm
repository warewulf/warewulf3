#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


package Warewulf::Module::Cli::Events;

use Warewulf::Logger;
use Warewulf::EventHandler;

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
    my $events = Warewulf::EventHandler->new();

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
    } elsif (uc($command) eq "ENABLE") {
        &nprint("Enabling the Warewulf Event Handler\n");
        $events->enable();
    } elsif (uc($command) eq "DISABLE") {
        &nprint("Disabling the Warewulf Event Handler\n");
        $events->disable();
    } elsif ($command eq "help") {
        print $self->help();
    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
        return undef;
    }

    return 1;
}


sub
complete()
{
    my ($self) = @_;

    return("enable", "disable");
}


sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     events [command]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     Control how/if events are handled.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "     enable          Enable all events for this shell (default)\n";
    $h .= "     disable         Disable the event handler\n";
    $h .= "     help            Show usage information\n";
    $h .= "\n";

    return($h);
}

sub
summary()
{
    my $output;

    $output .= "Control how events are handled";

    return($output);
}


1;
