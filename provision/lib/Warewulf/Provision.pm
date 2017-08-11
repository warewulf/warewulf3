# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Provision;

use Warewulf::ACVars;
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

=item fs($path)

Set or return FS for disk provisioning
=cut

sub fs()
{
    my ($self, $path) = @_;
    my @data;
    my %valid_cmds = (
      "align-check" => 2,
      "help" => 1,
      "mklabel" => 1,
      "mktable" => 1,
      "mkpart"  => 3,
      "name" => 2,
      "print" => 1,
      "quit" => 0,
      "rescue" => 2,
      "rm" => 1,
      "select" => 1,
      "disk_set" => 2,
      "disk_toggle" => 1,
      "set" => 3,
      "toggle" => 2,
      "unit" => 1,
      "version" => 0,
      "mkfs" => 2,
      "fstab" => 6,
    );

    my $fs_cmds_dir = Warewulf::ACVars->get("SYSCONFDIR") . "/warewulf/filesystem/";
    
    if (defined($path)) {
        if ($path eq "UNDEF") {
            @data = undef;
            $self->del("fs");
        } elsif (open(FILE, $fs_cmds_dir . $path . ".cmds") || open(FILE, $fs_cmds_dir . $path) || open(FILE, $path)) {
            &dprint("   Opening file to import for FS: $path\n");
            while (my $line = <FILE>) {
                if ($line =~ /^$/ || $line =~ /^#.+/) {
                  next
                }
                chomp($line);
                my @split_line = split /\s+/, $line;
                if (defined $split_line[0] && exists $valid_cmds{$split_line[0]}) {
                  if ($#split_line + 1 > $valid_cmds{$split_line[0]}) {
                    if ($split_line[0] eq "fstab" && $split_line[4] =~ /,/) {
                      &dprint("    Transforming commas in fstab options to colons, line: $line\n");
                      $split_line[4] =~ tr/,/:/;
                      push @data, join(" ", @split_line);
                    } elsif ( $line =~ /,/ ) {
                      &eprint("Command cannot contain commas, ignoring: $line\n");
                      next
                    } else {
                      push @data, $line;
                    } 
                  } else {
                    &wprint("Command does not have at least $valid_cmds{$split_line[0]} arguments, line: $line\n");
                  }

                } else {
                  &wprint("Unknown command in line $line, cmd: $split_line[0]\n");
                }
            }
            close FILE;
            $self->set("fs", @data);
        } else {
            &eprint("Could not open filesystems configuration path \"$path\"\n");
        }
    }


    return $self->get("fs");
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
