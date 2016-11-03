#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


package Warewulf::Module::Cli::Exit;

use Warewulf::Logger;
use Warewulf::EventHandler;
use Warewulf::Term;

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
summary()
{
    my $output;

    $output .= "Exit/leave the Warewulf shell";

    return($output);
}


sub
exec()
{
    my $self = shift;
    my $event_handler = Warewulf::EventHandler->new();
    my $term = Warewulf::Term->new();

    $event_handler->eventloader();
    $event_handler->handle("WWSH.END");
    $term->history_save();

    exit;
}


1;
