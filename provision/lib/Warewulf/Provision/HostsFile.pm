# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: HostsFile.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Provision::HostsFile;

use Socket;
use Digest::MD5 qw(md5_hex);
use Warewulf::Logger;
use Warewulf::Provision::Dhcp;
use Warewulf::DataStore;
use Warewulf::Network;
use Warewulf::Node;
use Warewulf::SystemFactory;
use Warewulf::Util;
use Warewulf::File;
use Warewulf::DSO::File;

our @ISA = ('Warewulf::File');

=head1 NAME

Warewulf::Provision::HostsFile - Generate a basic hosts file from the Warewulf
data store.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::HostsFile;

    my $obj = Warewulf::Provision::HostsFile->new();
    my $string = $obj->generate();


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
    my $self = ();

    $self = {};

    bless($self, $class);

    return $self->init(@_);
}


sub
init()
{
    my $self = shift;

    return($self);
}


=item generate()

This will generate the content of the /etc/hosts file.

=cut

sub
generate()
{
    my $self = shift;
    my $datastore = Warewulf::DataStore->new();
    my $netobj = Warewulf::Network->new();
    my $config = Warewulf::Config->new("provision.conf");

    my $netdev = $config->get("network device");
    my $defdomain = $config->get("use localdomain") || "yes";
    my $master_ipaddr = $config->get("ip address") // $netobj->ipaddr($netdev);
    my $master_network = $config->get("ip network") // $netobj->network($netdev);
    my $master_netmask = $config->get("ip netmask") // $netobj->netmask($netdev);

    if (! $master_ipaddr or ! $master_netmask or ! $master_network) {
        &wprint("Could not generate hostfile, check 'network device' or 'ip address/netmask/network' configuration!\n");
        return undef;
    }

    my $delim = "### ALL ENTRIES BELOW THIS LINE WILL BE OVERWRITTEN BY WAREWULF ###";

    my $hosts;

    open(HOSTS, "/etc/hosts");
    while(my $line = <HOSTS>) {
        chomp($line);
        if ($line eq $delim) {
            last;
        }
        $hosts .= $line ."\n";
    }
    close(HOSTS);

    chomp($hosts);
    $hosts .= "\n". $delim ."\n";
    $hosts .= "#\n";
    $hosts .= "# See provision.conf for configuration paramaters\n\n";

    foreach my $n ($datastore->get_objects("node")->get_list("fqdn", "domain", "cluster", "name")) {
        my $nodeid = $n->id();
        my $name = $n->name();
        my $nodename = $n->nodename();
        my $devcount = scalar $n->netdevs_list();
        my $default_name;

        if (! defined($nodename) or $nodename eq "DEFAULT") {
            next;
        }

        if (! $n->domain() and ! $n->cluster() and $defdomain eq "yes") {
            $n->domain("localdomain");
        }

        &dprint("Evaluating node: $nodename\n");
        $hosts .= "\n# Node Entry for node: $name (ID=$nodeid)\n";

        foreach my $devname ($n->netdevs_list()) {
            my $node_ipaddr = $n->ipaddr($devname);
            my $node_netmask = $n->netmask($devname) || $master_netmask;
            my $node_fqdn = $n->fqdn($devname);
            my $node_testnetwork;
            my @name_entries;

            if (! $node_ipaddr) {
                &dprint("Skipping $devname as it has no defined IPADDR\n");
                next;
            }

            $node_testnetwork = $netobj->calc_network($node_ipaddr, $node_netmask);

            if ($node_fqdn) {
                push(@name_entries, $node_fqdn);
            }

            &dprint("Checking to see if node is on same network as master: $node_testnetwork ?= $master_network\n");
            if ($devcount == 1 or (($node_testnetwork eq $master_network) and ! defined($default_name))) {
                &dprint("Using $nodename-$devname as default\n");
                $default_name = 1;
                $n->nodename($nodename);
                push(@name_entries, reverse $n->name());
            }

            # Renaming the node to include the device name... This will not be
            # persisted, so this is just temporary.
            $n->nodename($nodename ."-". $devname);
            push(@name_entries, reverse $n->name());

            if ($node_ipaddr and @name_entries) {
                $hosts .= sprintf("%-23s %s\n", $node_ipaddr, join(" ", @name_entries));
            } else {
                &iprint("Not writing a host entry for $nodename-$devname ($node_ipaddr)\n");
            }

        }
    }

    return($hosts);
}


=item update_datastore($hosts_contents)

Update the Warewulf data store with the current hosts file.

=cut

sub
update_datastore()
{
    my ($self, $hosts) = @_;
    my $binstore;
    my $name = "dynamic_hosts";
    my $datastore = Warewulf::DataStore->new();

    my $config = Warewulf::Config->new("provision.conf");
    my $hostfile = $config->get("hostfile") ? $config->get("hostfile") : "/etc/hosts";
    my @statinfo = lstat($hostfile);

    &dprint("Updating data store\n");

    my $len = length($hosts);

    &dprint("Getting file object for '$name'\n");
    my $fileobj = $datastore->get_objects("file", "name", $name)->get_object(0);

    if (! $fileobj) {
        $fileobj = Warewulf::File->new("file");
        $fileobj->set("name", $name);
    }

    $fileobj->checksum(md5_hex($hosts));
    $fileobj->path("/etc/hosts");
    $fileobj->format("data");
    $fileobj->filetype($statinfo[2]);
    $fileobj->size($len);
    $fileobj->uid("0");
    $fileobj->gid("0");
    $fileobj->mode(oct("0644"));

    $datastore->persist($fileobj);

    $binstore = $datastore->binstore($fileobj->id());

    my $read_length = 0;
    while($read_length != $len) {
        my $buffer = substr($hosts, $read_length, $datastore->chunk_size());
        if ( ! $binstore->put_chunk($buffer) ) {
            &eprint("Incomplete hosts file written to binstore\n");
            last;
        }
        $read_length += length($buffer);
    }

}


=item local_hostfile($hostfile, $hostcontents)

Update the master's local hostfile with the node contents.

=cut

sub
update_hostfile()
{
    my ($self, $hostfile, $hosts) = @_;

    if (open(HOSTS, "> $hostfile")) {
        print HOSTS $hosts;
        close HOSTS;
    } else {
        &wprint("Could not open $hostfile: $!\n");
    }

}


=item update()

Update the hosts dynamic_hosts file and master's /etc/hosts file if
configured to do so.

=cut

sub
update()
{
    my ($self) = @_;
    my $config = Warewulf::Config->new("provision.conf");
    my $hosts_contents = $self->generate();
    my $update_hostfile = $config->get("update hostfile") || "no";

    if (! $config->get("generate dynamic_hosts") or $config->get("generate dynamic_hosts") eq "yes") {
        if ($hosts_contents) {
            $self->update_datastore($hosts_contents);
        }
    }
    if ($update_hostfile eq "yes") {
        my $hostfile = $config->get("hostfile") ? $config->get("hostfile") : "/etc/hosts";
        if ($hosts_contents) {
            $self->update_hostfile($hostfile, $hosts_contents);
        }
    }
}


=back

=head1 SEE ALSO

Warewulf::Provision::Dhcp

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
