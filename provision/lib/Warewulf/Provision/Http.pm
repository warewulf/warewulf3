# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2021, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#

package Warewulf::Provision::Http;

use Warewulf::Object;

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Http - Warewulf's general HTTP object interface base class.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Http;

    my $obj = Warewulf::Http->new();


=head1 METHODS

=over 12

=cut

sub new() { undef };
sub init() { undef };

=item persist()

This will update the HTTP file.

=cut

sub persist() { undef };

=item reload()

This will reload the HTTP service.

=cut

sub reload() { undef };

=back

=head1 SEE ALSO

Warewulf::Object Warewulf::Provision::HttpFactory

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2021, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
