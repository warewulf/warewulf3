# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Trigger.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Module::Trigger;

use Warewulf::Logger;
use Warewulf::Module;

our @ISA = ('Warewulf::Module');


=head1 NAME

Warewulf::Module::Trigger - 

=head1 SYNOPSIS

    use Warewulf::Module::Trigger;

=head1 DESCRIPTION

    Mooooo

=head1 METHODS

=over 4

=item object_add($obj)

What happens when an object is added to the database

=cut

sub object_add() {};



=item object_del($obj)

What happens when an object is deleted from the database

=cut

sub object_del() {};



=item object_persist($obj/$objSet)

What happens when an object is persisted to the data store

=cut

sub object_persist() {};



=head1 SEE ALSO

Warewulf, Warewulf::Module

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
