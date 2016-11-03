# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
#########################
# Copyright (c) 2013, Intel(R) Corporation
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
#
#    * Redistributions of source code must retain the above copyright notice, 
#      this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright 
#      notice, this list of conditions and the following disclaimer in the 
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of Intel(R) Corporation nor the names of its 
#      contributors may be used to endorse or promote products derived from 
#      this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#
#########################
# $Id: Network.pm 1918 2015-06-17 21:37:03Z gmk $
#

package Warewulf::Network;

use Warewulf::Logger;
use Warewulf::Object;
use File::Basename;
use Socket;

# Suppress a stupid warning from ioctl.ph
local $SIG{__WARN__} = sub { 1; };
require 'sys/ioctl.ph';
$SIG{__WARN__} = __DEFAULT__;

our @ISA = ('Warewulf::Object');


=head1 NAME

Warewulf::Network - Various network-related helper functions

=head1 SYNOPSIS

    use Warewulf::Network;

=head1 DESCRIPTION

The Warewulf::Network object provides some network-related helper
functions.

=head1 METHODS

=over 4

=item new()

Creates and returns a new Network object.

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

=item ipaddr($device);

Return the IPv4 address of the given device name

=cut

sub
ipaddr()
{
    my ($self, $device) = @_;

    if ($device) {
        &dprint("Retrieving IP address for: $device\n");
        if ($device =~ /^([a-zA-Z0-9\:\.]+)$/) {
            my $device_clean = $1;
            my ($socket, $buf);
            my @address;

            if (!socket($socket, PF_INET, SOCK_STREAM, (getprotobyname('tcp'))[2])) {
                &eprint("unable to create a socket:  $!\n");
                return undef;
            }
            $buf = pack('a256', $device_clean);
            if (ioctl($socket, SIOCGIFADDR(), $buf) && (@address = unpack('x20 C4', $buf))) {
                my $addr = join('.', @address);
                &dprint("Discovered IP address for $device: $addr\n");
                return $addr;
            } else {
                &eprint("Could not discover IP address on $device: ioctl call failed!\n");
            }
        } else {
            &dprint("Illegal characters used in network device name\n");
        }
    } else {
        &wprint("Called ipaddr() on device object without a device name\n");
    }
    return undef;
}


=item netmask($device)

Return the IPv4 netmask of the given device name

=cut

sub
netmask()
{
    my ($self, $device) = @_;

    if ($device) {
        &dprint("Retrieving Netmask address for: $device\n");
        if ($device =~ /^([a-zA-Z0-9\:\.]+)$/) {
            my $device_clean = $1;
            my ($socket, $buf);
            my @address;

            if (!socket($socket, PF_INET, SOCK_STREAM, (getprotobyname('tcp'))[2])) {
                &eprint("unable to create a socket:  $!\n");
                return undef;
            }
            $buf = pack('a256', $device_clean);
            if (ioctl($socket, SIOCGIFNETMASK(), $buf) && (@address = unpack('x20 C4', $buf))) {
                my $addr = join('.', @address);
                &dprint("Discovered Netmask for $device: $addr\n");
                return $addr;
            } else {
                &eprint("Could not discover netmask on $device: ioctl call failed!\n");
            }
        } else {
            &dprint("Illegal characters used in network device name\n");
        }
    } else {
        &wprint("Called netmask() on device object without a device name\n");
    }

    return undef;
}


=item network($device)

Return the IPv4 network of the given device name

=cut

sub
network()
{
    my ($self, $device) = @_;

    if ($device) {
        &dprint("Retrieving Network address for: $device\n");
        if ($device =~ /^([a-zA-Z0-9\:\.]+)$/) {
            my $device_clean = $1;
            my $ipaddr = $self->ipaddr($device);
            my $netmask = $self->netmask($device);
            if ($ipaddr and $netmask) {
                my $network = $self->calc_network($ipaddr, $netmask);
                if ($network) {
                    &dprint("Discovered Network for $device: $network\n");
                    return $network;
                } else {
                    &eprint("Error calculating network for $device_clean\n");
                }
            } else {
                &eprint("Could not properly identify ipaddr/netmask for $device!\n");
            }
        }
    }
    return undef;
}

=item calc_prefix($device)

Return the CIDR Notation prefix of the Netmask for $device

=cut

sub
calc_prefix()
{
    my ($self, $device) = @_;
    my ($nm, $mask, $mask_bin);
    my ($bits, $mask_ok) = (0, 1);
    my @digits;

    $nm = $self->netmask($device);
    if (! $nm) {
        &eprint("Invalid netmask recieved\n");
        return undef;
    }

    $mask = inet_aton($nm);
    if (!defined($mask)) {
        &eprint("Invalid netmask:  $nm\n");
        return undef;
    }

    # convert the mask to binary
    $mask_bin = unpack("B*", $mask);
    @digits = split(//, $mask_bin);

    # Count the number of 1s
    # If there is a 0 in between the 1s, mark it as invalid
    $bits = 0;
    foreach my $bit (reverse(@digits)) {
        $bits += $bit;
        if ($bits && !$bit) {
            &eprint("Invalid netmask for CIDR format:  $nm\n");
            return undef;
        }
    }
    return $bits;
}

=item calc_network($ipaddr, $netmask)

Return the IPv4 network for agiven IPv4 address and netmask

=cut

sub
calc_network()
{
    my ($self, $ipaddr, $netmask) = @_;
    my ($ip_bits, $nm_bits, $ip_bin, $nm_bin, $net_bin);

    if ($ipaddr && $netmask) {
        $ip_bits = inet_aton($ipaddr);
        $nm_bits = inet_aton($netmask);
        if (!defined($ip_bits) || !defined($nm_bits)) {
            &eprint("Invalid network address:  $ipaddr/$netmask\n");
            return undef;
        }
        $ip_bin = unpack("N", $ip_bits);
        $nm_bin = unpack("N", $nm_bits);
        $net_bin = $ip_bin & $nm_bin;

        return inet_ntoa(pack("N", $net_bin));
    }

    return undef;
}

=item list_devices()

Return a list of all supported network devices

=cut

sub
list_devices()
{
    my ($self) = @_;
    my @ret;

    foreach my $devpath (glob("/sys/class/net/*")) {
        push(@ret, basename($devpath));
    }

    return @ret;
}

=item list_ipaddrs()

Return a list of all configured IP addresses on the system's network devices

=cut

sub
list_ipaddrs()
{
    my ($self) = @_;
    my @ret;

    foreach my $dev ($self->list_devices()) {
        my $ipaddr = $self->ipaddr($dev);

        if ($ipaddr) {
            push(@ret, $ipaddr);
        }
    }

    return @ret;
}

=item ip_serialize($ipaddress)

Convert a given IPv4 address to a serial numeric integer.

=cut

sub
ip_serialize()
{
    my ($self, $string) = @_;
    my $ip;

    if (defined($string)) {
        if ($string =~ /^(\d+)$/) {
            return $1;
        }
        $ip = inet_aton($string);
        if (defined($ip)) {
            return unpack("N", $ip);
        }
    }
    return undef;
}

=item ip_unserialize($integer)

Convert a given serialized numeric integer into a properly formatted IPv4 address.

=cut

sub
ip_unserialize()
{
    my ($self, $string) = @_;

    if (defined($string)) {
        if ($string =~ /^(\d+)$/) {
            return inet_ntoa(pack("N", $1));
        }
        if (defined(inet_aton($string))) {
            return $string;
        }
    }
    return undef;
}

=back

=head1 SEE ALSO

Warewulf

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
