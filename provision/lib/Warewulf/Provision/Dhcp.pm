# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Dhcp.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Provision::Dhcp;

use Warewulf::Object;

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Dhcp - Warewulf's general DHCP object interface base class.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Dhcp;

    my $obj = Warewulf::Dhcp->new();


=head1 METHODS

=over 12

=cut

sub new() { undef };
sub init() { undef };

=item persist()

This will update the DHCP file.

=cut

sub persist() { undef };

=item restart()

This will start/restart the DHCP service.

=cut

sub restart() { undef };

=back

=head1 SEE ALSO

Warewulf::Object Warewulf::Provision::DhcpFactory

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
