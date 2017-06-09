# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Provision;

use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Node;

our @ISA = ('Warewulf::Object');

push(@Warewulf::Node::ISA, 'Warewulf::Provision');

=head1 NAME

Warewulf::Provision - Provision object class for Warewulf

=head1 ABOUT

Object class for extending the Node objects for provisioning.

=head1 SYNOPSIS

    use Warewulf::Node;
    use Warewulf::Provision;

    my $obj = Warewulf::Node->new();

=head1 METHODS

=over 12

=cut



=item bootstrapid($string)

Set or return the bootstrap ID for this node

=cut

sub
bootstrapid()
{
    my $self = shift;

    return $self->prop("bootstrapid", qr/^([0-9]+)$/, @_);
}

=item bootstrap()

Return the name of the Warewulf Bootstrap this node is configured to use

=cut

sub
bootstrap()
{
    my $self = shift;
    my $db = Warewulf::DataStore->new();

    my $bsid = $self->bootstrapid();
    my $bs = $db->get_objects("bootstrap", "_id", $bsid)->get_object(0);

    # Can't do $bs->name() || "UNDEF" ... because if it fails on pulling an
    # object, then the name() sub doesn't exist.
    if ($bs) {
        return $bs->name();
    } else {
        return "UNDEF";
    }
}

=item vnfsid($string)

Set or return the VNFS ID for this node

=cut

sub
vnfsid()
{
    my $self = shift;

    return $self->prop("vnfsid", qr/^([0-9]+)$/, @_);
}

=item vnfs()

Return the name of the VNFS this node is configured to use

=cut

sub
vnfs()
{
    my $self = shift;
    my $db = Warewulf::DataStore->new();

    my $vnfsid = $self->vnfsid();
    my $vnfs = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);

    # Can't do $vnfs->name() || "UNDEF" ... because if it fails on pulling an
    # object, then the name() sub doesn't exist.
    if ($vnfs) {
        return $vnfs->name();
    } else {
        return "UNDEF";
    }
}


=item fileids(@fileids)

Set or return the list of file ID's to be provisioned for this node

=cut

sub
fileids()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (scalar(@_) > 1) {
        my $name = $self->get("name");
        my @new;

        foreach my $string (@strings) {
            if ($string =~ /^([0-9]+)$/) {
                &dprint("Object $name set $key += '$1'\n");
                push(@new, $1);
            } else {
                &eprint("Invalid characters to set $key += '$string'\n");
            }
            $self->set($key, @new);
        }
    }
    return($self->get($key));
}

=item console($string)

Set or return the console string to use for the kernel command line

=cut

sub
console()
{
    my $self = shift;

    return $self->prop("console", qr/^([a-zA-Z0-9\,]+)$/, @_);
}

=item kargs()

Set or return the list of kernel arguments. If an array element
includes whitespace (i.e. it includes multiple kernel arguments),
split it and store it as separate array elements.

=cut

sub 
kargs()
{
    my ($self, @strings) = @_;
    my $key = "kargs";
    my $conf = Warewulf::Config->new("provision.conf");
    my $default = $conf->get("default kargs");
    my @return;

    if (scalar(@_) > 1) {
        my $name = $self->get("name");
        my @new;

        if (!defined($strings[0]) || (uc($strings[0]) eq "UNDEF")) {
            $self->del($key);
            return $self->get($key);
        } else {
            foreach my $string (@strings) {
                my @kargs = split(/\s+/, $string); # pre-emptively split
                foreach my $karg (@kargs) {
                    &dprint("Object $name set $key += ' $karg'\n");
                    push(@new, $karg);
                }
            }
            $self->set($key, @new);
        }
    }

    @return = $self->get($key);

    if (@return) {
        return(@return);
    }

    return $default;
}


=item pxelinux()

Set or return the PXELinux file to use for this node.

=cut

sub 
pxelinux()
{
    my $self = shift;
    my $val = shift;
    my $name = $self->get("name");

    if (!defined($val) || us($val) eq "UNDEF") {
        &dprint("Object $name del PXELINUX\n");
        $self->del("pxelinux");
    } else {
        return $self->prop("pxelinux", qr/^([a-zA-Z0-9\.\/\-]+)$/, $val);
    }
}

=item fileidadd(@fileids)

Add a file ID or list of file IDs to the current object.

=cut

sub
fileidadd()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (@strings) {
        my $name = $self->get("name");
        foreach my $string (@strings) {
            if ($string =~ /^([0-9]+)$/) {
                &dprint("Object $name set $key += '$1'\n");
                $self->add($key, $1);
            } else {
                &eprint("Invalid characters to set $key += '$string'\n");
            }
        }
    }
    return $self->get($key);
}


=item fileiddel(@fileids)

Delete a file ID or list of file IDs to the current object.

=cut

sub
fileiddel()
{
    my ($self, @strings) = @_;
    my $key = "fileids";

    if (@strings) {
        my $name = $self->get("name");

        $self->del($key, @strings);
        &dprint("Object $name del $key -= @strings\n");
    }

    return $self->get($key);
}


=item master(@strings)

Set or return the master of this object.

=cut

sub
master()
{
    my ($self, @strings) = @_;
    my $key = "master";
    my @masters;

    my $name = $self->get("name");
    if (scalar(@_) > 1) {
        if (!defined($strings[0]) || (uc($strings[0]) eq "UNDEF")) {
            &dprint("Object $name del $key\n");
            $self->del($key);
        } else {
            foreach my $string (@strings) {
                if ($string =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
                    push(@masters, $1);
                } else {
                    &eprint("Invalid characters to set $key = '$string'\n");
                }
            }
            &dprint("Object $name set $key = @masters\n");
            $self->set($key, @masters);
        }
    }
    return $self->get($key);
}


=item postnetdown($bool)

Shutdown the network after provisioning

=cut

sub
postnetdown()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("postnetdown", 1);
        } else {
            $self->del("postnetdown");
        }
    }

    return $self->get("postnetdown");
}


=item preshell($bool)

Set or return the preshell boolean

=cut

sub
preshell()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("preshell", 1);
        } else {
            $self->del("preshell");
        }
    }

    return $self->get("preshell");
}


=item postshell($bool)

Set or return the postshell boolean

=cut

sub
postshell()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("postshell", 1);
        } else {
            $self->del("postshell");
        }
    }

    return $self->get("postshell");
}


=item postreboot($bool)

Set or return the postreboot boolean

=cut

sub
postreboot()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("postreboot", 1);
        } else {
            $self->del("postreboot");
        }
    }

    return $self->get("postreboot");
}


=item validate_vnfs($bool)

Set or return the validate_vnfs boolean

=cut

sub
validate_vnfs()
{
    my ($self, $bool) = @_;

    if (defined($bool)) {
        if ($bool) {
            $self->set("validate_vnfs", 1);
        } else {
            $self->del("validate_vnfs");
        }
    }

    return $self->get("validate_vnfs");
}


=item selinux($value)

Set or return SELinux support

DISABLED    No SELinux support (default)
ENABLED     Enable but don't enforce
ENFORCED    Enable and enforce.

note: to enable or enforce you will need to have a valid policy file
created in the booting VNFS at /etc/selinux/targeted/policy/policy.24.

=cut

sub
selinux()
{
    my ($self, $value) = @_;
    my $newval;

    if ( defined($value) ) {
        if ( uc($value) eq "DISABLED" ) {
            $self->del("selinux");
        } elsif ( uc($value) eq "ENABLED" ) {
            $self->set("selinux", 0);
        } elsif ( uc($value) eq "ENFORCED" ) {
            $self->set("selinux", 1);
        } else {
            &eprint("Can not set SELINUX value to: $value\n");
        }
    }

    $newval = $self->get("selinux");
    if ( ! defined($newval) ) {
        return "DISABLED" ;
    } elsif ( $newval == 0 ) {
        return "ENABLED" ;
    } elsif ( $newval == 1 ) {
        return "ENFORCED" ;
    } else {
        &eprint("Unknown value of SELinux ($newval), deleting...\n");
        $self->del("selinux");
        return "DISABLED";
    }

}


=item bootlocal($value)

Set or return bootlocal:

NORMAL - LOCALBOOT type  0 (zero) : Perform a normal local boot.
EXIT   - LOCALBOOT type -1 (minus one) : Cause the boot loader to report 
         failure to the BIOS, which, on recent BIOSes, should mean that the 
         next boot device in the boot sequence should be activated. 
=cut

sub
bootlocal()
{
    my ($self, $value) = @_;

    if (defined($value)) {
        if ($value eq "NORMAL") {
            $self->set("bootlocal", 0);
        } elsif ($value eq "EXIT") {
            $self->set("bootlocal", -1);
        } else {
            $self->del("bootlocal");
        }
    }

    return $self->get("bootlocal");
}

=item bootloader($value)

Set or return bootloader:

$value - The disk to install the bootloader onto. i.e. sda, sdb, etc...
=cut

sub bootloader()
{
    my $self = shift;
    my @val = @_;

    if ($_[0] eq "UNDEF") {
        @val = undef;
    }

    return $self->prop("bootloader", qr/^([a-zA-Z0-9_\/]+)$/, @val);
}

=item diskformat($value)

Set or return diskformat:

$value = The comma seperated list of partations to format. i.e. sda1,sda2
=cut

sub diskformat()
{
    my $self = shift;
    my @val = @_;

    if ($_[0] eq "UNDEF") {
        @val = undef;
    }

    return $self->prop("diskformat", qr/^([a-zA-Z0-9_,]+)$/, @val);
}

=item diskpartition($value)

Set or return diskpartition:

$value - The disk to partition during bootstrap
=cut

sub diskpartition()
{
    my $self = shift;
    my @val = @_;

    if ($_[0] eq "UNDEF") {
        @val = undef;
    }

    return $self->prop("diskpartition", qr/^([a-zA-Z0-9_]+)$/, @val);
}

=item filesystems($value)

Set or return FILESYSTEMS for disk provisioning
=cut

sub filesystems()
{
    my ($self, $value) = @_;

    # A better way??
    if (defined($value)) {
        $self->set("filesystems", $value);
    }

    return $self->get("filesystems");
}

=back

=head1 SEE ALSO

Warewulf::Object Warewulf::DSO::Node

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
