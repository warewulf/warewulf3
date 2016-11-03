# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Module.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Module;

use Warewulf::Object;

our @ISA = ('Warewulf::Object');


=head1 NAME

Warewulf::Module - Warewulf module base class

=head1 SYNOPSIS

    use Warewulf::Module;

=head1 DESCRIPTION

    This class acts as a base (parent) class for all other module
    classes.  All modules should derive (directly or indirectly) from
    Warewulf::Module.

=head1 METHODS

=over 4

=item new()

Creates and returns a new Module object.

=cut

sub
new()
{
    my ($proto, @args) = @_;
    my $class = ref($proto) || $proto;
    my $self;

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@args);
}

=item init()

(Re-)initialize an object.  Called automatically by new().

=cut

sub
init()
{
    my ($self, @args) = @_;

    return $self;
}

=item keyword()

Returns the keyword for which this module will be responsible.

=cut

sub
keyword()
{
    my $self = shift;
    my $keyword = ref($self);

    $keyword =~ s/^.+:://;
    return lc($keyword);
}

=back

=head1 SEE ALSO

Warewulf::Module::Cli, Warewulf::Module::Trigger

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
