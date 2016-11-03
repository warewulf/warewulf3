#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#



package Warewulf::Module::Cli::Dhcp;

use Warewulf::Logger;
use Warewulf::Provision::DhcpFactory;

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

    $output .= "Manage DHCP service and configuration";

    return($output);
}



sub
help()
{
    my ($self, $keyword) = @_;
    my $h;

    $h .= "USAGE:\n";
    $h .= "     dhcp <command>\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "        The DHCP command configures/reconfigures the DHCP service.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         update          Update the DHCP configuration, and restart the service\n";
    $h .= "         restart         Restart the DHCP service\n";
    $h .= "         help            Show usage information\n";
    $h .= "\n";

    return($h);
}


sub
exec()
{
    my ($self, $command, @args) = @_;
    my $dhcp = Warewulf::Provision::DhcpFactory->new();

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
    } elsif ($command eq "update") {
        &nprint("Rebuilding the DHCP configuration\n");
        $dhcp->persist();
        &nprint("Done.\n");
    } elsif ($command eq "restart") {
        &nprint("Restarting the DHCP service\n");
        $dhcp->restart();
        &nprint("Done.\n");
    } elsif ($command eq "help") {
        print $self->help();
    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
    }

}



1;






