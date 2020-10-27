# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Node.pm 689 2011-12-20 00:34:04Z mej $
#

package Warewulf::Ipmi;

use Warewulf::ACVars;
use Warewulf::Object;
use Warewulf::Node;
use Warewulf::Network;
use Warewulf::Logger;
use Warewulf::Util;

our @ISA = ('Warewulf::Object');

push(@Warewulf::Node::ISA, 'Warewulf::Ipmi');

=head1 NAME

Warewulf::Ipmi - IPMI extentions to the Warewulf::Node object type.

=head1 ABOUT

Warewulf object types that need to be persisted via the DataStore need to have
various extentions so they can be persisted. This module enhances the object
capabilities.

=head1 SYNOPSIS

    use Warewulf::Node;
    use Warewulf::DSO::Node;

    my $obj = Warewulf::Node->new();

    $obj->ipmi_ipaddr("10.1.1.1");
    my $address = $obj->ipmi_addr();


=head1 METHODS

=over 12

=cut

=item ipmi_ipaddr($string)

Set or return the IPMI IPv4 address of this object.

=cut

sub
ipmi_ipaddr()
{
    my $self = shift;

    return $self->prop("ipmi_ipaddr", qr/^((\d{1,3}\.){3}\d+)$/, @_);
}


=item ipmi_vlanid($string)

Set or return the IPMI VLAN ID of this object.
VLAN ID can be 1-4096 or "off". "off" disables VLAN tagging.

=cut

sub
ipmi_vlanid()
{
    my ($self, $value) = @_; 

    if ($value) {
        if ( $value eq "off" or ( $value =~ /^\d+$/ && int($value) >= 1 && int($value) <= 4096 ) ) {
            $self->set("ipmi_vlanid", $value);
        } else {
            &eprint("VLAN ID must be set to 1-4096 or 'off'\n");
        }
    } 
    return($self->get("ipmi_vlanid") || "UNDEF");
}

=item ipmi_netmask($string)

Set or return the IPMI IPv4 netmask of this object.

=cut

sub
ipmi_netmask()
{
    my $self = shift;

    return $self->prop("ipmi_netmask", qr/^((\d{1,3}\.){3}\d+)$/, @_);
}


=item ipmi_username($string)

Set or return the IPMI username of this object.

=cut

sub
ipmi_username()
{
    my $self = shift;

    return $self->prop("ipmi_username", qr/^([a-zA-Z0-9]+)$/, @_);
}


=item ipmi_password($string)

Set or return the IPMI password of this object.

=cut

sub
ipmi_password()
{
    my $self = shift;

    return $self->prop("ipmi_password", qr/^([a-zA-Z0-9]+)$/, @_);
}

=item ipmi_uid($string)

Set or return the IPMI UID of this object.

=cut

sub
ipmi_uid()
{
    my $self = shift;

    return $self->prop("ipmi_uid", qr/^([0-9]+)$/, @_);
}

sub
ipmi_lanchannel()
{
    my $self = shift;

    return $self->prop("ipmi_lanchannel", qr/^([0-9]+)$/, @_);
}

=item ipmi_proto($string)

Set or return the IPMI interface protocol of this object. Supported protocols
are:

      lanplus (default)
      lan
      open
      free
      imb
      bmc
      lipmi

=cut

sub
ipmi_proto()
{
    my ($self, $value) = @_; 

    if ($value) {
        if ( $value eq "lan" or
                $value eq "lanplus" or
                $value eq "open" or
                $value eq "free" or
                $value eq "ibm" or
                $value eq "bmc" or
                $value eq "lipmi") {
            $self->set("ipmi_proto", $value);
        }
    }

    return($self->get("ipmi_proto") || "lanplus");
}


=item ipmi_autoconfig($bool)

Automatically configure the node's IPMI interface for network access
during provision time. This will require the following IPMI paramaters to
be set:

    ipmi_ipaddr
    ipmi_netmask
    ipmi_username
    ipmi_password

note: This will take a boolean true (!=0) or false (0).

=cut

sub
ipmi_autoconfig()
{
    my ($self, @value) = @_; 
    my $key = "ipmi_autoconfig";

    if (exists($value[0])) {
        if (! $value[0]) {
            $self->del($key);
        } else {
            if ($self->ipmi_ipaddr() and $self->ipmi_netmask() and $self->ipmi_username() and $self->ipmi_password()) {
                $self->set($key, "1");
            } else {
                &eprint("Could not set ipmi_autoconfig() because requirements not met\n");
            }
        }
    }
    return $self->get($key);
}

=item ipmi_target($string)

Set IPMI target (-t <target>).  This paramter is usually used by IPMI
chassis that control multiple systems.  In most implementations this option
is not necessary.  Target should be in hex form (e.g. 0x04), or 'UNDEF' to
disable.

=cut

sub
ipmi_target()
{
    $self = shift;

    return $self->prop("ipmi_target", qr/^(0x[0-9a-fA-F][0-9a-fA-F])$/, @_);
}


=item ipmi_command($action)

Return the IPMI shell command for a given action as follows:

    poweron     Turn the node on
    poweroff    Turn the node off
    powercycle  Cycle the power on the node
    powerstatus Check power status
    ident       Set chassis identify light to forced on
    noident     Set chassis identify light to off
    printsel    Print System Event Log
    clearsel    Clear System Event Log
    printsdr    Print sensor data records
    console     Start an IPMI serial-over-lan console

Commands for changing boot device on next boot:

    forcepxe    Force boot from PXE
    forcedisk   Force boot from first Hard Disk
    forcecdrom  Force boot from CD-ROM
    forcebios   Force boot into BIOS

=cut

sub
ipmi_command()
{
    my ($self, $action) = @_;
    my $ipaddr = $self->ipmi_ipaddr();
    my $username = $self->ipmi_username();
    my $password = $self->ipmi_password();
    my $proto = $self->ipmi_proto();
    my $target = $self->ipmi_target() || "UNDEF";
    my $name = $self->name() || "UNDEF";
    my $libexecdir = Warewulf::ACVars->libexecdir();
    my $ret;

    if ( -e "$libexecdir/warewulf/ipmitool" ) {
        $ret = "$libexecdir/warewulf/ipmitool ";
    } else {
        $ret = "ipmitool ";
    }
    if ($ipaddr and $username and $password and $proto) {
        $ret .= "-I $proto -U $username -P $password -H $ipaddr ";
        if ($target ne "UNDEF") {
            $ret .= "-t $target ";
        }
        if ($action eq "poweron" ) {
            $ret .= "chassis power on";
        } elsif ( $action eq "poweroff" ) {
            $ret .= "chassis power off";
        } elsif ( $action eq "powercycle" ) {
            $ret .= "chassis power cycle";
        } elsif ( $action eq "powerstatus" ) {
            $ret .= "chassis power status";
        } elsif ( $action eq "ident" ) {
            $ret .= "chassis identify force";
        } elsif ( $action eq "noident" ) {
            $ret .= "chassis identify 0";
        } elsif ( $action eq "printsel" ) {
            $ret .= "sel elist";
        } elsif ( $action eq "clearsel" ) {
            $ret .= "sel clear";
        } elsif ( $action eq "printsdr" ) {
            $ret .= "sdr elist";
        } elsif ( $action eq "console" ) {
            $ret .= "-e ^ sol activate";
        } elsif ( $action eq "forcepxe" ) {
            $ret .= "chassis bootdev pxe";
        } elsif ( $action eq "forcedisk" ) {
            $ret .= "chassis bootdev disk";
        } elsif ( $action eq "forcecdrom" ) {
            $ret .= "chassis bootdev cdrom";
        } elsif ( $action eq "forcebios" ) {
            $ret .= "chassis bootdev bios";
        } else {
            &eprint("Unsupported IPMI action: $action\n");
            return();
        }
    } else {
        &eprint("Could not build IPMI command for $name, unconfigured requirement(s)\n");
        &wprint("IPADDR: ". ($ipaddr || "UNDEF") ."\n");
        &wprint("USERNAME: ". ($username || "UNDEF") ."\n");
        &wprint("PASSWORD: ". ($password || "UNDEF") ."\n");
        &wprint("PROTO: ". ($proto || "UNDEF") ."\n");
        return()
    }

    return($ret);
}


=back

=head1 SEE ALSO

Warewulf::DSO, Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
