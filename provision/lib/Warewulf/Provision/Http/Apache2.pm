# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2021, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#

package Warewulf::Provision::Http::Apache2;

use Warewulf::ACVars;
use Warewulf::Logger;
use Warewulf::Provision;
use Warewulf::Provision::Http;
use Warewulf::DataStore;
use Warewulf::Network;
use Warewulf::SystemFactory;
use Warewulf::Util;
use Socket;
use File::Basename;
use Data::Dumper;

our @ISA = ('Warewulf::Provision::Http');

=head1 NAME

Warewulf::Provision::Http::Apache2 - Warewulf's Apache2 HTTP server interface.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::Http::Apache2;

    my $obj = Warewulf::Provision::Http::Apache2->new();


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
    my $config = Warewulf::Config->new("provision.conf");

    my @files = ('/etc/httpd/conf.d/warewulf-generated.conf');

    if (my $file = $config->get("httpd config file")) {
        &dprint("Using the httpd configuration file as defined by provision.conf\n");
        if ($file =~ /^([a-zA-Z0-9_\-\.\/]+)$/) {
            $self->set("FILE", $1);
        } else {
            &eprint("Illegal characters in path: $file\n");
        }

    } elsif (! $self->get("FILE")) {
        # See if we can find the directory to create the file in
        foreach my $file (@files) {
            if ($file =~ /^([a-zA-Z0-9_\-\.\/]+)$/) {
                my $file_clean = $1;
                if (-d dirname($file_clean)) {
                    $self->set("FILE", $file_clean);
                    &dprint("Using HTTPD configuration file: $file_clean\n");
                }
            } else {
                &eprint("Illegal characters in path: $file\n");
            }
        }
    }

    return($self);
}


=item reload()

Restart the HTTPD service

=cut

sub
reload()
{

    my $system = Warewulf::SystemFactory->new();

    if (! $system->service("httpd", "reload")) {
        &eprint($system->output() ."\n");
    }

}

=item persist()

This will update the HTTPD file.

=cut

sub
persist()
{
    my $self = shift;
    my $datastore = Warewulf::DataStore->new();
    my $netobj = Warewulf::Network->new();
    my $statedir = &Warewulf::ACVars::get("statedir");
    my $config = Warewulf::Config->new("provision.conf");
    my $devname = $config->get("network device");
    my $ipaddr = $config->get("ip address") // $netobj->ipaddr($devname);
    my $netmask = $config->get("ip netmask") // $netobj->netmask($devname);
    my $network = $config->get("ip network") // $netobj->network($devname);
    my $dhcp_net = $config->get("dhcp network") || "direct";
    my $httpd_contents;
    my %seen;
    my %vnfs;
    my %bootstrap;

    if (! $self->get("FILE")) {
        &dprint("No configuration file present, so no HTTP configuration to persist\n");
        return(1);
    }

    if (! &uid_test(0)) {
        &iprint("Not updating HTTP configuration: user not root\n");
        return(1);
    }
    if (! $ipaddr) {
        &wprint("Could not obtain IP address of this system!\n");
        &wprint("Check provision.conf 'network device'\n");
        &eprint("Not building HTTPD configuration\n");
        return(1);
    }
    if (! $netmask) {
        &wprint("Could not obtain the netmask of this system!\n");
        &eprint("Not building HTTPD configuration\n");
        return(1);
    }
    if (! $network) {
        &wprint("Could not obtain the base network of this system!\n");
        &eprint("Not building HTTPD configuration\n");
        return(1);
    }

    &dprint("Iterating through nodes\n");

    foreach my $n ($datastore->get_objects("node")->get_list("fqdn", "domain", "cluster", "name")) {
        my $hostname = $n->nodename() || "undef";
        my $nodename = $n->name() || "undef";
        my $vnfs_id = $n->vnfsid();
        my $bootstrap_id = $n->bootstrapid();
        my $db_id = $n->id();

        if (! $n->enabled()) {
            &dprint("Node $hostname disabled. Skipping.\n");
            next;
        }
        if (! $vnfs_id) {
            &dprint("No VNFS associated with this node object: $hostname/$nodename:$n. Skipping.\n");
            next;
        }
        if (! $bootstrap_id) {
            &dprint("No BOOTSTRAP associated with this node object: $hostname/$nodename:$n. Skipping.\n");
            next;
        }
        if (! $db_id) {
            &eprint("No DB ID associated with this node object: $hostname/$nodename:$n\n");
            next;
        }

        &dprint("Evaluating node: $nodename (object ID: $db_id)\n");
        $nodename =~ s/\./_/g;
        my @bootservers = $n->get("bootserver");
        if (! @bootservers or scalar(grep { $_ eq $ipaddr} @bootservers)) {
            my $domainname = $n->domain();
            my $master_ipv4_addr;
            my $domain;

            if ($n->get("master")) {
                my $master_ipv4_bin = $n->get("master");
                $master_ipv4_addr = $netobj->ip_unserialize($master_ipv4_bin);
            } else {
                $master_ipv4_addr = $ipaddr;
            }

            foreach my $devname ($n->netdevs_list()) {
                my $node_ipaddr = $n->ipaddr($devname);
                my $node_netmask = $n->netmask($devname) || $netmask;
                my $node_gateway = $n->gateway($devname);

                my $node_testnetwork = $netobj->calc_network($node_ipaddr, $node_netmask);

                if (! $node_ipaddr) {
                    &iprint("Skipping HTTP config for $nodename-$devname (no defined IPADDR)\n");
                    next;
                }

                if (($dhcp_net eq "direct") and ($node_testnetwork ne $network)) {
                    &iprint("Skipping HTTP config for $nodename-$devname (on a different network)\n");
                    next;
                }

                if (exists($seen{"IPADDR"}) and exists($seen{"IPADDR"}{"$node_ipaddr"})) {
                    my $redundant_node = $seen{"IPADDR"}{"$node_ipaddr"};
                    &iprint("Skipping HTTP config for $nodename-$devname (IPADDR $node_ipaddr already seen in $redundant_node)\n");
                    next;
                }

                if ($nodename and $node_ipaddr) {
                    &dprint("Adding a entry for: $nodename-$devname for VNFS ID $vnfs_id with IP $node_ipaddr\n");
                    push @{ $vnfs{"$vnfs_id"} }, "$node_ipaddr";
                    &dprint("Adding a entry for: $nodename-$devname for BOOTSTRAP ID $bootstrap_id with IP $node_ipaddr\n");
                    push @{ $bootstrap{"$bootstrap_id"} }, "$node_ipaddr";
                    $seen{"NODESTRING"}{"$nodename-$devname"} = "$nodename-$devname";
                    $seen{"IPADDR"}{"$node_ipaddr"} = "$nodename-$devname";

                } else {
                    &dprint("Skipping node $nodename-$devname: insufficient information\n");
                }
            }
        }
    }

    &dprint("Creating HTTPD configuration file header\n");
    $httpd_contents .= "# HTTPD Configuration written by Warewulf. Do not edit this file.\n";
    $httpd_contents .= "\n";

    foreach my $vnfs_id (keys %vnfs) {
        my $vnfs_obj = $datastore->get_objects("vnfs", "_id", $vnfs_id)->get_object(0);
        if ($vnfs_obj) {
            my $vnfs_name = $vnfs_obj->name();
            $httpd_contents .= "# VNFS $vnfs_name, ID: $vnfs_id\n";
            $httpd_contents .= "<Directory /var/tmp/warewulf_cache/$vnfs_name>\n";
            $httpd_contents .= "    AllowOverride None\n";
            $httpd_contents .= "    AuthMerging And\n";
            $httpd_contents .= "    <RequireAny>\n";
            foreach (@{$vnfs{$vnfs_id}}) {
                &dprint("Adding \"Require ip $_\" for $vnfs_name\n");
                $httpd_contents .= "        Require ip $_\n";
            }
            $httpd_contents .= "    </RequireAny>\n";
            $httpd_contents .= "</Directory>\n";
            $httpd_contents .= "\n";
        }
    }

    foreach my $bootstrap_id (keys %bootstrap) {
        my $bootstrap_obj = $datastore->get_objects("bootstrap", "_id", $bootstrap_id)->get_object(0);
        if ($bootstrap_obj) {
            my $bootstrap_name = $bootstrap_obj->name();
            my $bootstrap_arch = $bootstrap_obj->arch();
            $httpd_contents .= "# BOOTSTRAP $bootstrap_name, ID: $bootstrap_id\n";
            $httpd_contents .= "<Directory $statedir/warewulf/bootstrap/$bootstrap_arch/$bootstrap_id>\n";
            $httpd_contents .= "    AllowOverride None\n";
            $httpd_contents .= "    AuthMerging And\n";
            $httpd_contents .= "    <RequireAny>\n";
            foreach (@{$bootstrap{$bootstrap_id}}) {
                &dprint("Adding \"Require ip $_\" for $bootstrap_name\n");
                $httpd_contents .= "        Require ip $_\n";
            }
            $httpd_contents .= "    </RequireAny>\n";
            $httpd_contents .= "</Directory>\n";
            $httpd_contents .= "\n";
        } else {
            &dprint("Could not find Bootstrap object for ID $bootstrap_id\n");
        }
    }

    if ( keys %vnfs > 0 || keys %bootstrap > 0) {
        my ($digest1, $digest2);
        my $system = Warewulf::SystemFactory->new();

        if ($self->get("FILE") and -f $self->get("FILE")) {
            $digest1 = digest_file_hex_md5($self->{"FILE"});
        }
        &iprint("Writing HTTPD configuration\n");
        &dprint("Opening file ". $self->get("FILE") ." for writing\n");
        if (! open(FILE, ">". $self->get("FILE"))) {
            &eprint("Could not open ". $self->get("FILE") ." for writing: $!\n");
            return();
        }

        print FILE $httpd_contents;

        close FILE;
        $digest2 = digest_file_hex_md5($self->get("FILE"));
        if (! $digest1 or $digest1 ne $digest2) {
            &dprint("Reloading HTTPD service\n");
            if (! $system->service("httpd", "reload")) {
                my $output = $system->output();
                if ( $output ) {
                    &eprint("$output\n");
                } else {
                    &eprint("There was an error reloading the HTTPD server\n");
                }
            }
        } else {
            &dprint("Not reloading HTTPD service\n");
        }
    } else {
        &iprint("Not updating HTTPD configuration, no assigned VNFS found\n");
    }

    return();
}

=back

=head1 SEE ALSO

Warewulf::Provision::Http

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
