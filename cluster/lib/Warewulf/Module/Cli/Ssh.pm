#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#


package Warewulf::Module::Cli::Ssh;

use Getopt::Long;
use Warewulf::Config;
use Warewulf::DataStore;
use Warewulf::Logger;
use Warewulf::Network;
use Warewulf::Node;
use Warewulf::ParallelCmd;
use Warewulf::Util;

our @ISA = ('Warewulf::Module::Cli');


sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub
exec()
{
    my $self = shift;
    my $pcmd = Warewulf::ParallelCmd->new();
    my $db = Warewulf::DataStore->new();
    my $netobj = Warewulf::Network->new();
    my $config = Warewulf::Config->new("provision.conf");
    my $devname = $config->get("network device");
    my $netmask = $netobj->netmask($devname);
    my $network = $netobj->network($devname);
    my $opt_lookup = "name";
    my $opt_allnodes;
    my $user = "";
    my $address;
    my $objSet;
    my $searchstring;
    my @search;
    my $command;


    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'l|lookup=s'    => \$opt_lookup,
        'a|allnodes'    => \$opt_allnodes,
    );

    if (scalar(@ARGV) == 0) {
        $self->help();
        return;
    }

    if ($opt_allnodes) {
        $objSet = $db->get_objects("node", $opt_lookup);
    } else {
        $searchstring = shift(@ARGV);
        if ($searchstring =~ /^([^\@]+\@)(.+)$/) {
            $user = $1;
            $searchstring = $2;
        }
#TODO: Split searchstring up by commas without interfering with bracketed commas.
#      for example: n000[0,1,2,3],test0000 should just split up n000[0,1,2,3] and 
#      test0000
        if ($searchstring) {
            $objSet = $db->get_objects("node", $opt_lookup, &expand_bracket($searchstring));
        }
    }
    $command = join(" ", @ARGV);


    if (! $objSet or $objSet->count() == 0) {
        &nprint("No nodes found\n");
        return undef;
    }

    if (! $command) {
        &nprint("No command given\n");
        return undef;
    }

    foreach my $nobj ($objSet->get_list()) {
        my $node_name = $nobj->name();
        my $node_ipaddr;
        my $node_fqdn;
        my @net_devs = $nobj->netdevs_list();

        if (scalar(@net_devs) == 1) {
            $node_ipaddr = $nobj->ipaddr($dev);
        } else {
            foreach my $dev ($nobj->netdevs_list()) {
                my $test_network = $nobj->network($dev);
                my $test_ipaddr = $nobj->ipaddr($dev);
                my $test_netmask = $nobj->netmask($dev) || $netmask;

                &dprint("Evaluating $node_name:$dev\n");
                if (! $test_ipaddr or ! $test_netmask) {
                    &dprint("Skipping $node_name:$dev (test_ipaddr or test_network undefined)\n");
                    next;
                }
                if (! $test_network) {
                    $test_network = Warewulf::Network->calc_network($test_ipaddr, $test_netmask);
                }
                &dprint("Network config: $node_name:$dev=$test_ipaddr/$test_netmask/$test_network\n");
                if ($test_network eq $network) {
                    if ($test_ipaddr = $nobj->ipaddr($dev)) {
                        $node_ipaddr = $nobj->ipaddr($dev);
                        &dprint("Contacting $node_name via $node_ipaddr\n");
                        last;
                    }
                }
                $node_fqdn = $nobj->fqdn($dev);
            }
        }
        if ($node_ipaddr) {
            $address = $node_ipaddr;
        } elsif ($node_fqdn) {
            $address = $node_fqdn;
        } elsif ($node_name) {
            $address = $node_name;
        }

        if ($address) {
            $pcmd->queue("/usr/bin/ssh -q -o BatchMode=yes $user$address $command\n", "$node_name: ");
        } else {
            &eprint("Can not determine address to: $node_name\n");
        }
    }
    $pcmd->run();

    @ARGV = ();
}


sub
complete()
{
    my $self = shift;
    my $opt_lookup = "name";
    my $db = $self->{"DB"};
    my @ret;

    if (! $db) {
        return;
    }

    @ARGV = ();

    foreach (&quotewords('\s+', 0, @_)) {
        if (defined($_)) {
            push(@ARGV, $_);
        }
    }

    Getopt::Long::Configure ("bundling", "passthrough");

    GetOptions(
        'l|lookup=s'    => \$opt_lookup,
    );
   
    if (! exists($ARGV[1])) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    }

    @ARGV = ();

    return (@ret);
}

sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     ssh [nodes/targets] [command]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     Run ssh connections to node(s) in parallel by either node names, group\n";
    $h .= "     or any other known lookup.\n";
    $h .= "\n";
    $h .= "TARGETS:\n";
    $h .= "     The target(s) specify which node(s) will be affected by the chosen\n";
    $h .= "     action(s).  By default, node(s) will be identified by their name(s).\n";
    $h .= "     Use the --lookup option to specify another property (e.g., \"hwaddr\"\n";
    $h .= "     or \"groups\").\n";
    $h .= "\n";
    $h .= "     All targets can be bracket expanded as follows:\n";
    $h .= "\n";
    $h .= "         n00[0-99]       All nodes from n0000 through n0099 (inclusive)\n";
    $h .= "         n00[00,10-99]   n0000 and all nodes from n0010 through n0099\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "\n";
    $h .= "     -l, --lookup        Identify nodes by specified property (default: \"name\")\n";
    $h .= "     -a, --allnodes      Send command to all configured nodes\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> ssh n00[00-49] hostname\n";
    $h .= "     Warewulf> ssh -l groups compute,interactive hostname\n";
    $h .= "\n";

    return($h);
}



sub
summary()
{
    my $output;

    $output .= "Spawn parallel ssh connections to nodes.";

    return($output);
}


1;
