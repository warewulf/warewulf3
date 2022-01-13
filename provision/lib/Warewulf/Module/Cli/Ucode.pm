#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#



package Warewulf::Module::Cli::Ucode;

use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Provision::Ucode;
use Getopt::Long;


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

    $output .= "Manage CPU Microcode Initrd Generation";

    return($output);
}


sub
help()
{
    my ($self, $keyword) = @_;
    my $h;

    $h .= "USAGE:\n";
    $h .= "     ucode <command>\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "        Manage CPU Microcode Initrd Generation.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         update          Update the ucode initrd\n";
    $h .= "         help            Show usage information\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> ucode update\n";
    $h .= "\n";

    return($h);
}


sub
exec()
{
    my $self = shift;
    my $ucode = Warewulf::Provision::Ucode->new();

    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    $command = shift(@ARGV);

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return();
    } elsif ($command eq "update") {
        return($ucode->update());
    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
        return();
    }
}



1;






