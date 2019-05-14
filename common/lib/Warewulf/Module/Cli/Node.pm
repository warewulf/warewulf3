#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
package Warewulf::Module::Cli::Node;

use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Node;
use Warewulf::DSO::Node;
use Warewulf::Network;
use Getopt::Long;
use POSIX qw(uname);
use Text::ParseWords;

our @ISA = ('Warewulf::Module::Cli');

my $entity_type = "node";

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    $self->init();

    return $self;
}

sub
init()
{
    my ($self) = @_;

    $self->{"DB"} = Warewulf::DataStore->new();
}


sub
help()
{
    my $h;
    my $config_defaults = Warewulf::Config->new("defaults/node.conf");
    my $netdev = $config_defaults->get("netdev") || "UNDEF";
    my (undef, undef, undef, undef, $arch) = POSIX::uname();


    $h .= "USAGE:\n";
    $h .= "     node <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     The node command is used for viewing and manipulating node objects.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "         new             Create a new node configuration\n";
    $h .= "         set             Modify an existing node configuration\n";
    $h .= "         list            List a summary of nodes\n";
    $h .= "         print           Print the node configuration\n";
    $h .= "         delete          Remove a node configuration from the data store\n";
    $h .= "         clone           Clone a node configuration to another node\n";
    $h .= "         help            Show usage information\n";
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
    $h .= "     -l, --lookup        Identify nodes by specified property (default: \"name\")\n";
    $h .= "     -1                  With list command, output node name only\n";
    $h .= "     -g, --groups        Specify all groups to which this node belongs\n";
    $h .= "         --groupadd      Add node to specified group(s)\n";
    $h .= "         --groupdel      Remove node from specified group(s)\n";
    $h .= "     -D, --netdev        Specify network device to add or modify (defaults: $netdev)\n";
    $h .= "         --netdel        Remove specified netdev from node\n";
    $h .= "         --netrename     Rename a given network interface\n";
    $h .= "     -I, --ipaddr        Set IP address of given netdev\n";
    $h .= "     -M, --netmask       Set subnet mask of given netdev\n";
    $h .= "     -N, --network       Set network address of netdev\n";
    $h .= "     -G, --gateway       Set gateway of given netdev\n";
    $h .= "     -H, --hwaddr        Set hardware/MAC address\n";
    $h .= "     -b, --bonddevs      Set bonding slave devices\n";
    $h .= "     -B, --bondmode      Set bonding mode\n";
    $h .= "     -f, --fqdn          Set FQDN of given netdev\n";
    $h .= "     -m, --mtu           Set MTU of given netdev\n";
    $h .= "     -p, --hwprefix      Specify a prefix for hardware/MAC address of a given netdev\n";
    $h .= "     -c, --cluster       Specify cluster name for this node\n";
    $h .= "         --domain        Specify domain name for this node\n";
    $h .= "     -n, --name          Specify new name for this node\n";
    $h .= "     -a, --arch          Specify architecture for this node (defaults: $arch)\n";
    $h .= "     -e, --enabled       Set whether the node is enabled (defaults: True)\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "     Warewulf> node new n0000 --netdev=eth0 --hwaddr=xx:xx:xx:xx:xx:xx\n";
    $h .= "     Warewulf> node set n0000 -D eth0 -I 10.0.0.10 -G 10.0.0.1\n";
    $h .= "     Warewulf> node set n0000 --netdev=eth0 --netmask=255.255.255.0\n";
    $h .= "     Warewulf> node set --groupadd=mygroup,hello,bye --cluster=mycluster n0000\n";
    $h .= "     Warewulf> node set --groupdel=bye --set=vnfs=sl6.vnfs\n";
    $h .= "     Warewulf> node list xx:xx:xx:xx:xx:xx --lookup=hwaddr\n";
    $h .= "     Warewulf> node print --lookup=groups mygroup hello group123\n";
    $h .= "     Warewulf> node clone n0000 new0000\n";
    $h .= "     Warewulf> node set --enabled=false n0000\n";
    $h .= "     Warewulf> node set --arch=x86_64 n0000\n";
    $h .= "\n";

    return ($h);
}

sub
summary()
{
    my $output;

    $output .= "Node manipulation commands";

    return ($output);
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

    if (exists($ARGV[1]) and ($ARGV[1] eq "print" or $ARGV[1] eq "new" or $ARGV[1] eq "set" or $ARGV[1] eq "list" or $ARGV[1] eq "clone")) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    } else {
        @ret = ("print", "new", "set", "delete", "list", "clone");
    }

    @ARGV = ();

    return (@ret);
}

sub
exec()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $term = Warewulf::Term->new();
    my $config_defaults = Warewulf::Config->new("defaults/node.conf");
    my $opt_lookup = "name";
    my $opt_netdev = $config_defaults->get("netdev");
    my $opt_netrename;
    my @opt_hwaddrs;
    my @opt_bonddevs;
    my $opt_bondmode;
    my $opt_hwprefix;
    my $opt_ipaddr;
    my $opt_netmask;
    my $opt_network;
    my $opt_gateway;
    my $opt_devremove;
    my $opt_cluster;
    my $opt_name;
    my $opt_arch;
    my $opt_domain;
    my $opt_fqdn;
    my $opt_mtu;
    my $opt_enabled;
    my $opt_single;
    my @opt_print;
    my @opt_groups;
    my @opt_groupadd;
    my @opt_groupdel;
    my $return_count;
    my $objSet;
    my @changes;
    my $command;
    my $object_count = 0;
    my $persist_count = 0;

    my $orignode;
    my $newnode_name;

    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'g|groups=s'    => \@opt_groups,
        'groupadd=s'    => \@opt_groupadd,
        'groupdel=s'    => \@opt_groupdel,
        'D|netdev=s'    => \$opt_netdev,
        'netdel'        => \$opt_devremove,
        'netrename=s'   => \$opt_netrename,
        'H|hwaddr=s'    => \@opt_hwaddrs,
        'p|hwprefix=s'  => \$opt_hwprefix,
        'I|ipaddr=s'    => \$opt_ipaddr,
        'N|network=s'   => \$opt_network,
        'G|gateway=s'   => \$opt_gateway,
        'M|netmask=s'   => \$opt_netmask,
        'c|cluster=s'   => \$opt_cluster,
        'n|name=s'      => \$opt_name,
        'a|arch=s'      => \$opt_arch,
        'f|fqdn=s'      => \$opt_fqdn,
        'm|mtu=s'       => \$opt_mtu,
        'b|bonddevs=s'  => \@opt_bonddevs,
        'B|bondmode=s'  => \$opt_bondmode,
        'd|domain=s'    => \$opt_domain,
        'l|lookup=s'    => \$opt_lookup,
        'e|enabled=s'   => \$opt_enabled,
        '1'             => \$opt_single,
    );

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not available!\n");
        return undef;
    }

    if (! $command || $command eq "help") {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return undef;
    } elsif ($command eq "clone") {
        my $onode_name = shift(@ARGV);
        $newnode_name = shift(@ARGV);

        $orignode = $db->get_objects("node", "name", $onode_name)->get_object(0);

        if (!$orignode) {
            &eprint("Nodename '$onode_name' not found");
            return undef;
        }

    } elsif ($command eq "new") {
        $objSet = Warewulf::ObjectSet->new();
        foreach my $string (&expand_bracket(@ARGV)) {
            my $node;

            if ($string =~ /^([a-zA-Z0-9\-_]+)$/) {
                my $nodename = $1;
                $node = Warewulf::Node->new();
                $node->nodename($nodename);
                $objSet->add($node);
                $persist_count++;
                push(@changes, sprintf("%8s: %-20s = %s\n", "NEW", "NODE", $nodename));
            } else {
                &eprint("Nodename '$string' contains invalid characters\n");                
            }
        }
    } else {
        if ($opt_lookup eq "hwaddr") {
            $opt_lookup = "_hwaddr";
        } elsif ($opt_lookup eq "id") {
            $opt_lookup = "_id";
        }
        $objSet = $db->get_objects($opt_type || $entity_type, $opt_lookup, &expand_bracket(@ARGV));
    }

    if ($objSet) {
        $object_count = $objSet->count();
    }
    if ((! $objSet || ($object_count == 0)) && ($command ne "clone")) {
        &nprint("No nodes found\n");
        return undef;
    }

    if ($command eq "delete") {
        my @changes;

        if (! @ARGV) {
            &eprint("To make deletions, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        @changes = map { sprintf("%8s: %s %s", "DEL", "NODE", scalar $_->name()); } $objSet->get_list("fqdn", "domain", "cluster", "name");
        if ($self->confirm_changes($term, $object_count, "node(s)", @changes)) {
            $return_count = $db->del_object($objSet);
            &nprint("Deleted $return_count nodes.\n");
        }
    } elsif ($command eq "list") {
        if ( $opt_single ) {
            foreach my $o ($objSet->get_list("name")) {
                printf("%-32s\n", $o->nodename() || "UNDEF");
            }
        } else {
           &nprintf("%-19s %-19s %-19s %-19s\n",
                "NAME",
                "GROUPS",
                "IPADDR",
                "HWADDR"
            );
            &nprint("================================================================================\n");
            foreach my $o ($objSet->get_list("fqdn", "domain", "cluster", "name")) {
                printf("%-19s %-19s %-19s %-19s\n",
                    &ellipsis(19, ($o->name() || "UNDEF"), "end"),
                    &ellipsis(19, (join(",", $o->groups()) || "UNDEF")),
                    join(",", $o->ipaddr_list()),
                    join(",", $o->hwaddr_list())
                );
                $return_count++;
            }
        }
    } elsif ($command eq "print") {
        foreach my $o ($objSet->get_list("fqdn", "domain", "cluster", "name")) {
            my $nodename = $o->name() || "UNDEF";

            &nprintf("#### %s %s#\n", $nodename, "#" x (72 - length($nodename)));
            printf("%15s: %-16s = %s\n", $nodename, "ID", ($o->id() || "ERROR"));
            printf("%15s: %-16s = %s\n", $nodename, "NAME", join(",", $o->name()));
            printf("%15s: %-16s = %s\n", $nodename, "NODENAME", ($o->nodename() || "UNDEF"));
            printf("%15s: %-16s = %s\n", $nodename, "ARCH", ($o->arch() || "UNDEF"));
            printf("%15s: %-16s = %s\n", $nodename, "CLUSTER", ($o->cluster() || "UNDEF"));
            printf("%15s: %-16s = %s\n", $nodename, "DOMAIN", ($o->domain() || "UNDEF"));
            printf("%15s: %-16s = %s\n", $nodename, "GROUPS", join(",", $o->groups()) || "UNDEF");
            printf("%15s: %-16s = %s\n", $nodename, "ENABLED", ($o->enabled()) ? "TRUE" : "FALSE");
            foreach my $devname (sort($o->netdevs_list())) {
                printf("%15s: %-16s = %s\n", $nodename, "$devname.HWADDR", $o->hwaddr($devname) ? join(',', $o->hwaddr($devname)) : "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.HWPREFIX", $o->hwprefix($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.IPADDR", $o->ipaddr($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.NETMASK", $o->netmask($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.NETWORK", $o->network($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.GATEWAY", $o->gateway($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.MTU", $o->mtu($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.FQDN", $o->fqdn($devname) || "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.BONDDEVS", $o->bonddevs($devname) ? join(',', $o->bonddevs($devname)) : "UNDEF");
                printf("%15s: %-16s = %s\n", $nodename, "$devname.BONDMODE", $o->bondmode($devname) || "UNDEF");
            }
            $return_count++;
        }

    } elsif ($command eq "set" or $command eq "new") {
        &dprint("Entered 'set' codeblock\n");

        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        if ($opt_netdev) {
            if ($opt_netdev =~ /^([a-z0-9]+[0-9]+)$/) {
                $opt_netdev = $1;
            } else {
                &eprint("Option 'netdev' has invalid characters\n");
                return undef;
            }
        }

        if ($opt_devremove) {
            foreach my $o ($objSet->get_list()) {
                if (! $opt_netdev) {
                    my @devs = $o->netdevs_list();
                    if (scalar(@devs) == 1) {
                        $opt_netdev = shift(@devs);
                    }
                }
                if(defined $o->netdel($opt_netdev) ) {
                    $persist_count++;
                }
            }
            push(@changes, sprintf("%8s: %-20s\n", "DEL", $opt_netdev));
        } elsif ($opt_netrename) {
            foreach my $o ($objSet->get_list()) {
                if (! $opt_netdev) {
                    my @devs = $o->netdevs_list();
                    if (scalar(@devs) == 1) {
                        $opt_netdev = shift(@devs);
                    }
                }
                if(defined $o->netrename($opt_netdev, $opt_netrename) ) {
                    $persist_count++;
                }
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.NAME", $opt_netrename));

        } else {
            if (@opt_hwaddrs) {
                if ($objSet->count() == 1) {
                    @opt_hwaddrs = split(/,/, join(',', @opt_hwaddrs));
                    @opt_hwaddrs = map { lc $_ } @opt_hwaddrs;

                    if (grep { $_ !~ /^((?:[0-9a-f]{2}:){5,7}[0-9a-f]{2}|undef)$/ } @opt_hwaddrs) {
                        &eprint("Option 'hwaddrs' has invalid characters\n");
                    }
                    else {
                        my $show_changes;
                        foreach my $o ($objSet->get_list()) {
                            my $nodename = $o->name();
                            if (! $opt_netdev) {
                                my @devs = $o->netdevs_list();
                                if (scalar(@devs) == 1) {
                                    $opt_netdev = shift(@devs);
                                } else {
                                    &eprint("Option --hwaddr requires the --netdev option for: $nodename\n");
                                    return undef;
                                }
                            }
                            $o->hwaddr($opt_netdev, @opt_hwaddrs);
                            $persist_count++;
                            $show_changes = 1;
                        }
                        if ($show_changes) {
                            push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.HWADDR", join(',', @opt_hwaddrs)));
                        }
                    }
                } else {
                    &eprint("Can not set HWADDR on more then 1 node!\n");
                }
            }
            if ($opt_hwprefix) {
                $opt_hwprefix = lc($opt_hwprefix);
                if ($opt_hwprefix =~ /^((?:[0-9a-f]{2}:){11}[0-9a-f]{2})$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --hwprefix requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->hwprefix($opt_netdev, $1);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.HWPREFIX", $opt_hwprefix));
                    }
                } else {
                    &eprint("Option 'hwprefix' has invalid characters\n");
                }
            }
            if ($opt_ipaddr) {
                if ($opt_ipaddr =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
                    my $ip_serialized = Warewulf::Network->ip_serialize($1);
                    my $show_changes;
                    foreach my $o ($objSet->get_list("fqdn", "domain", "cluster", "name")) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --ipaddr requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->ipaddr($opt_netdev, Warewulf::Network->ip_unserialize($ip_serialized));
                        $ip_serialized++;
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.IPADDR", $opt_ipaddr));
                    }
                } else {
                    &eprint("Option 'ipaddr' has invalid characters\n");
                }
            }
            if ($opt_netmask) {
                if ($opt_netmask =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --netmask requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->netmask($opt_netdev, $1);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.NETMASK", $opt_netmask));
                    }
                } else {
                    &eprint("Option 'netmask' has invalid characters\n");
                }
            }
            if ($opt_network) {
                if ($opt_network =~ /^(\d+\.\d+\.\d+\.\d+)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --network requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->network($opt_netdev, $1);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.NETWORK", $opt_network));
                    }
                } else {
                    &eprint("Option 'network' has invalid characters\n");
                }
            }
            if ($opt_gateway) {
                if ($opt_gateway =~ /^(\d+\.\d+\.\d+\.\d+|UNDEF|undef)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --gateway requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->gateway($opt_netdev, $1);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.GATEWAY", $opt_gateway));
                    }
                } else {
                    &eprint("Option 'gateway' has invalid characters\n");
                }
            }
            if ($opt_fqdn) {
                if ($opt_fqdn =~ /^([a-zA-Z0-9\-_\.]+)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --fqdn requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->fqdn($opt_netdev, $opt_fqdn);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.FQDN", $opt_fqdn));
                    }
                } else {
                    &eprint("Option 'fqdn' has invalid characters\n");
                }
            }
            if ($opt_mtu) {
                if ($opt_mtu =~ /^([0-9]+)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --mtu requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->mtu($opt_netdev, $opt_mtu);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.MTU", $opt_mtu));
                    }
                } else {
                    &eprint("Option 'mtu' has invalid characters\n");
                }
            }
            if (@opt_bonddevs) {
                @opt_bonddevs = split(/,/, join(',', @opt_bonddevs));

                if (grep { $_ !~ /^([a-z0-9]+)$/ } @opt_bonddevs) {
                    &eprint("Option 'bonddevs' has invalid characters\n");
                }
                else {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --bonddevs requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->bonddevs($opt_netdev, @opt_bonddevs);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.BONDDEVS", join(',', @opt_bonddevs)));
                    }
                }
            }
            if ($opt_bondmode) {
                if ($opt_bondmode =~ /^(.+)$/) {
                    my $show_changes;
                    foreach my $o ($objSet->get_list()) {
                        my $nodename = $o->name();
                        if (! $opt_netdev) {
                            my @devs = $o->netdevs_list();
                            if (scalar(@devs) == 1) {
                                $opt_netdev = shift(@devs);
                            } else {
                                &eprint("Option --bondmode requires the --netdev option for: $nodename\n");
                                return undef;
                            }
                        }
                        $o->bondmode($opt_netdev, $1);
                        $persist_count++;
                        $show_changes = 1;
                    }
                    if ($show_changes) {
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "$opt_netdev.BONDMODE", $opt_bondmode));
                    }
                }
                else {
                    &eprint("Option 'bondmode' has invalid characters\n");
                }
            }
        }

        if ($opt_name) {
            if ($objSet->count() == 1) {
                if (uc($opt_name) eq "UNDEF") {
                    &eprint("You must define the name you wish to reference the node as!\n");
                } elsif ($opt_name =~ /^([a-zA-Z0-9\-_]+)$/) {
                    $opt_name = $1;
                    foreach my $obj ($objSet->get_list()) {
                        my $nodename = $obj->get("name") || "UNDEF";
                        $obj->nodename($opt_name);
                        &dprint("Setting new name for node $nodename: $opt_name\n");
                        $persist_count++;
                    }
                    push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "NAME", $opt_name));
                } else {
                    &eprint("Option 'name' has invalid characters\n");
                }
            } else {
                &eprint("Can not rename more then 1 node at a time!\n");
            }
        }

        if ($opt_arch) {
            if (uc($opt_arch) eq "UNDEF") {
                $opt_arch = undef;
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->arch($opt_arch);
                    &dprint("Undefining architecture for node $nodename: $opt_arch\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s\n", "UNDEF", "ARCH"));
            } elsif ($opt_arch =~ /^([a-zA-Z0-9_]+)$/) {
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->arch($opt_arch);
                    &dprint("Setting architecture for node $nodename: $opt_arch\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "ARCH", $opt_arch));
            } else {
                &eprint("Option 'arch' has invalid characters\n");
            }
        } else {
            foreach my $obj ($objSet->get_list()) {
                my $nodename = $obj->get("name") || "UNDEF";
                if (! $obj->arch()) {
                    my (undef, undef, undef, undef, $arch) = POSIX::uname();
                    $obj->arch($arch);
                    &dprint("Setting architecture for node $nodename to default: $arch\n");
                    $persist_count++;
                }
            }
        }

        if ($opt_cluster) {
            if (uc($opt_cluster) eq "UNDEF") {
                $opt_cluster = undef;
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->cluster($opt_cluster);
                    &dprint("Undefining cluster name for node $nodename\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s\n", "UNDEF", "CLUSTER"));
            } elsif ($opt_cluster =~ /^([a-zA-Z0-9\.\-_]+)$/) {
                $opt_cluster = $1;
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->cluster($opt_cluster);
                    &dprint("Setting cluster name for node $nodename: $opt_cluster\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "CLUSTER", $opt_cluster));
            } else {
                &eprint("Option 'cluster' has invalid characters\n");
            }
        }

        if ($opt_domain) {
            if (uc($opt_domain) eq "UNDEF") {
                $opt_domain = undef;
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->domain($opt_domain);
                    &dprint("Undefining domain name for node $nodename\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s\n", "UNDEF", "DOMAIN"));
            } elsif ($opt_domain =~ /^([a-zA-Z0-9\.\-_]+)$/) {
                $opt_domain = $1;
                foreach my $obj ($objSet->get_list()) {
                    my $nodename = $obj->get("name") || "UNDEF";
                    $obj->domain($opt_domain);
                    &dprint("Setting domain name for node $nodename: $opt_domain\n");
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "DOMAIN", $opt_domain));
            } else {
                &eprint("Option 'domain' has invalid characters\n");
            }
        }

        if (@opt_groups) {
            foreach my $obj ($objSet->get_list()) {
                my $nodename = $obj->get("name") || "UNDEF";

                $obj->groups(split(",", join(",", @opt_groups)));
                &dprint("Setting groups for node name: $nodename\n");
                $persist_count++;
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "GROUPS", join(",", @opt_groups)));
        }

        if (@opt_groupadd) {
            foreach my $obj ($objSet->get_list()) {
                my $nodename = $obj->get("name") || "UNDEF";

                $obj->groupadd(split(",", join(",", @opt_groupadd)));
                &dprint("Setting groups for node name: $nodename\n");
                $persist_count++;
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "ADD", "GROUPS", join(",", @opt_groupadd)));
        }

        if (@opt_groupdel) {
            foreach my $obj ($objSet->get_list()) {
                my $nodename = $obj->get("name") || "UNDEF";

                $obj->groupdel(split(",", join(",", @opt_groupdel)));
                &dprint("Setting groups for node name: $nodename\n");
                $persist_count++;
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "DEL", "GROUPS", join(",", @opt_groupdel)));
        }

        if (defined($opt_enabled)) {
            if ($opt_enabled =~ /^([0-1]|true|TRUE|True|false|FALSE|False|undef|UNDEF)$/) {
                if (uc($opt_enabled) eq "FALSE" || $opt_enabled eq "0") {
                    $opt_enabled = 0;
                    foreach my $obj ($objSet->get_list()) {
                        my $nodename = $obj->get("name") || "UNDEF";
                        $obj->enabled($opt_enabled);
                        &dprint("Disabing node $nodename\n");
                        $persist_count++;
                    }
                    push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "ENABLED", "FALSE"));
                } else {
                    $opt_enabled = 1;
                    foreach my $obj ($objSet->get_list()) {
                        my $nodename = $obj->get("name") || "UNDEF";
                        $obj->enabled($opt_enabled);
                        &dprint("Enabling node $nodename\n");
                        $persist_count++;
                    }
                    push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "ENABLED", "TRUE"));
                }
            } else {
                &eprint("Option 'enabled' has invalid characters\n");
            }
        }

        if ($persist_count > 0 or $command eq "new") {
            if ($term->interactive()) {
                my $node_count = $objSet->count();
                my $question;

                $question = sprintf("Are you sure you want to make the following %d change(s) to %d node(s):\n\n",
                                    $persist_count, $node_count);
                $question .= join('', @changes) . "\n";
                if (! $term->yesno($question)) {
                    &nprint("No update performed\n");
                    return undef;
                }
            }

            $return_count = $db->persist($objSet);

            &iprint("Updated $return_count objects\n");
        }

    } elsif ($command eq "help") {
        print $self->help();
    } elsif ($command eq "clone") {
        my $cloneSet = Warewulf::ObjectSet->new();

        if ($newnode_name =~ /^([a-zA-Z0-9\-_]+)$/) {
            my $nodename = $1;
            $node = $orignode->clone("name","$nodename");
            $node->genname();

            foreach my $dev (sort($node->netdevs_list())) {
                if($opt_devremove) {
                    &dprint("CLONE: Removing network device $dev\n");
                    $node->netdel($dev);
                } else {
                    &dprint("CLONE: Removing ipaddr/hwaddr for device $dev\n");
                    $node->ipaddr($dev, undef);
                    $node->hwaddr($dev, undef);
                }
            }

            $cloneSet->add($node);
            $persist_count++;
        } else {
            &eprint("Nodename '$newnode_name' contains invalid characters\n");
            return undef;
        }

        $db->persist($cloneSet);

        if ($term->interactive()) {
            my $question;

            $question = sprintf("Are you sure you want to clone node %s to %d node(s):\n\n",
                                $orignode->nodename(), $persist_count);
            if (! $term->yesno($question)) {
                &nprint("Clone not performed\n");
                $db->del_object($cloneSet);
                return undef;
            }
        }

    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
    }

    # We are done with ARGV, and it was internally modified, so lets reset
    @ARGV = ();

    return $return_count;
}


1;

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:

