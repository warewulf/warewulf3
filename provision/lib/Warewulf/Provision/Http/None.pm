# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2021, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


package Warewulf::Provision::Http::None;

use Warewulf::Logger;
use Warewulf::Provision::Dhcp;
use Warewulf::DataStore;
use Warewulf::Network;
use Socket;

our @ISA = ('Warewulf::Provision::Http');

=head1 NAME

Warewulf::Provision::Http::None - Warewulf's NULL server interface. Use this
if one is going to be managing their HTTP server by hand themselves and
Warewulf should do nothing.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::Http::None;

    my $obj = Warewulf::Provision::Http::None->new();


=head1 METHODS

=over 12

=cut

=item new()

New object constructor

=cut

sub
new($$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self;
}


=back

=head1 SEE ALSO

Warewulf::Provision::Http

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2021, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
