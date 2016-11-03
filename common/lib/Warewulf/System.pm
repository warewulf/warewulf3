# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: System.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::System;

use Warewulf::Object;

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::System - Warewulf's System (Data Store Object) base class

=head1 SYNOPSIS

    use Warewulf::System;

    my $obj = Warewulf::System->new();

=head1 METHODS

=over 4

=item new()

Create and return a new System object instance.

=cut

sub new($$) { return undef; };

=item service($name, $command)

Run a command on a service script (e.g. /etc/init.d/service restart).

=cut

sub service($$) { return undef; };

=item chkconfig($name, $command)

Enable a service script to be enabled or disabled at boot (e.g.
/sbin/chkconfig service on).

=cut

sub chkconfig($$) { return undef; };

=item output()

Return the output cache on a command

=cut

sub output($$) { return undef; };

=back

=head1 SEE ALSO

Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
