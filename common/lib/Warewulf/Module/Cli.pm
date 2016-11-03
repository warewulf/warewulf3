# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Cli.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Module::Cli;

use Warewulf::Logger;
use Warewulf::Module;

our @ISA = ('Warewulf::Module');


=head1 NAME

Warewulf::Module::Cli - 

=head1 SYNOPSIS

    use Warewulf::Module::Cli;

=head1 DESCRIPTION

    Mooooo

=head1 METHODS

=over 4

=item options()

Define the command line options of this module interface.

=cut

#sub options() { };


=item description()

Verbose description of the module

=cut

#sub description() { };


=item summary()

A very short summary describing this module

=cut

#sub summary() { };


=item examples()

Return an array of usage examples

=cut

#sub examples() { };


=item command()

What happens when this module gets called by a command

=cut

sub exec() {};


=item complete()

What to do when this module gets called for autocompletion

=cut

sub complete() {};


=item confirm_changes(I<term>, I<obj_count>, I<type>, I<change>, [...])

Confirm a set of changes to objects in the data store.  I<obj_count>
is the number of objects affected by the changes.  I<type> is the type
of objects being changed.  The remaining parameters should consist of
text strings which describe the changes about to be made.  The return
value will be true if the user confirmed the changes or false if the
user requested to discard the changes.

The default response is "no" if standard input is a tty and "yes"
otherwise.

=cut

sub
confirm_changes(@)
{
    my ($self, $term, $obj_count, $type, @changes) = @_;

    if (! $type) {
        $type = "object(s)";
    }
    printf("About to apply %d action(s) to $obj_count $type:\n\n", scalar(@changes));
    foreach my $change (@changes) {
        chomp $change;
        print $change ."\n";
    }
    if ($term->yesno("\nProceed?\n")) {
        return 1;
    } else {
        &nprint("Action(s) discarded.\n");
        return 0;
    }
}


=head1 SEE ALSO

Warewulf, Warewulf::Module

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
