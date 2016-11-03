# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id$
#

package Warewulf::System::Suse;

use Warewulf::System;
use Warewulf::Logger;

our @ISA = ('Warewulf::System');

=head1 NAME

Warewulf::System::Suse - Warewulf's general object instance object interface.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::System::Suse;

    my $obj = Warewulf::System::Suse->new();


=head1 METHODS

=over 12

=cut

=item new()

The new constructor will create the object that references configuration the
stores.

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


=item service($name, $command)

Run a command on a service script (e.g. /etc/init.d/service restart).

=cut

sub
service($$$)
{
    my ($self, $service, $command) = @_;

    &dprint("Running service command: $service, $command\n");

    if ( -x "/bin/systemctl" ) {
        system("/bin/systemctl $command $service.service");
    } elsif (-x "/etc/init.d/$service") {
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
    if ($self->{"OUTPUT"}) {
        chomp($self->{"OUTPUT"});
        if (close SERVICE) {
            &dprint("Service command ran successfully\n");
            return(1);
        } else {
            &dprint("Error running: /usr/bin/systemctl $command $service\n");
        }
    }
    return(1);
}

=item chkconfig($name, $command)

Enable a service script to be enabled or disabled at boot (e.g.
/sbin/chkconfig service on).

=cut

sub
chkconfig($$$)
{
    my ($self, $service, $command) = @_;

    if ( -x "/bin/systemctl" ) {
        system("/bin/systemctl enable $service.service");
    } elsif (-x "/sbin/chkconfig") {
        open(CHKCONFIG, "/sbin/chkconfig $service $command 2>&1|");
        while(<CHKCONFIG>) {
            $self->{"OUTPUT"} .= $_;
        }
        if (defined($self->{"OUTPUT"})) {
            chomp($self->{"OUTPUT"});
        }
        if (close CHKCONFIG) {
            &dprint("Chkconfig command ran successfully\n");
            return(1);
        } else {
            &dprint("Error running: /sbin/chkconfig $service $command\n");
        }
    }
    return(1);
}


=item output()

return the output cache on a command

=cut

sub
output($)
{
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

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:

