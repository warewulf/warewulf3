# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
# edited for debian flavors Tim Copeland
# $Id: Deb.pm 2012-2-23 tac $
#

package Warewulf::System::Deb;

use Warewulf::System;
use Warewulf::Logger;

our @ISA = ('Warewulf::System');

=head1 NAME

Warewulf::Deb - Warewulf's general object instance object interface.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::System::Deb;

    my $obj = Warewulf::System::Deb->new();


=head1 METHODS

=over 12

=cut

=item new()

The new constructor will create the object that references configuration the
stores.

=cut

sub new($$) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self;
}


=item service($name, $command)

Run a command on a service script (e.g. /etc/init.d/service restart).
Future versions may also support upstart.

=cut

sub service($$$) {
    my ($self, $service, $command) = @_;

 	# determine which distro we are working with
	# set distro specific init.d service commands

	if ( ! -f "/etc/redhat-release" ) {
		if ( "$service" eq "dhcpd" ) {
			$service = 'isc-dhcp-server';
		}
	}

    &dprint("Running service command: $service, $command\n");

    if (-x "/etc/init.d/$service") {
        $self->{"OUTPUT"} = ();
        open(SERVICE, "/etc/init.d/$service $command 2>&1|");
        while(<SERVICE>) {
            $self->{"OUTPUT"} .= $_;
        }
        chomp($self->{"OUTPUT"});
        if (close SERVICE) {
            &dprint("Service command ran successfully\n");
            return(1);
        } else {
            &dprint("Error running: /etc/init.d/$service $command\n");
        }
    }
    return();
}


=item chkconfig($name, $command)

Enable a service script to be enabled or disabled at boot (e.g.
/sbin/chkconfig service on).
This may be depicated in favor of upstart in the future.

=cut

sub chkconfig($$$) {
    my ($self, $service, $command) = @_;

 	# determine which distro we are working with
	# set distro specific init.d service commands

	if ( ! -f "/etc/redhat-release" ) {
		if ( "$service" eq "dhcpd" ) {
			$service = 'isc-dhcp-server';
			$command = 'defaults';
		}
	}

    if (-x "/usr/sbin/update-rc.d") {
        open(CHKCONFIG, "/usr/sbin/update-rc.d $service $command 2>&1|");
        while(<CHKCONFIG>) {
            $self->{"OUTPUT"} .= $_;
        }
        if (defined($self->{"OUTPUT"})) {
            chomp($self->{"OUTPUT"});
        }
        if (close CHKCONFIG) {
            &dprint("update-rc.d command ran successfully\n");
            return(1);
        }
		else {
            &dprint("Error running: /usr/sbin/update-rc.d $service $command\n");
        }
    }
    return();
}


=item output()

return the output cache on a command

=cut

sub output($) {
    my $self = shift;

    return(defined($self->{"OUTPUT"}) ? $self->{"OUTPUT"} : "");
}



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
