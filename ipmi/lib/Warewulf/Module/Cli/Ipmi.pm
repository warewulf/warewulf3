#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#




package Warewulf::Module::Cli::Ipmi;

use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::ParallelCmd;
use Warewulf::Ipmi;
use Warewulf::Network;
use Getopt::Long;
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
keyword()
{
    return("ipmi");
}

sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     ipmi <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "    The ipmi command is used for setting node ipmi configuration attributes.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         set             Modify an existing node configuration\n";
    $h .= "         list            List a summary of the node(s) ipmi configuration\n";
    $h .= "         print           Print the full node(s) ipmi configuration\n";
    $h .= "         poweron         Power on the list of nodes\n";
    $h .= "         poweroff        Power off the list of nodes\n";
    $h .= "         powercycle      Power cycle the list of nodes\n";
    $h .= "         powerstatus     Print the power status of the nodes\n";
    $h .= "         ident           Set chassis identify light to on for the nodes\n";
    $h .= "         noident         Set chassis identify light to off for the nodes\n";
    $h .= "         printsel        Print system event log for the nodes\n";
    $h .= "         clearsel        Clear system event log for the nodes\n";
    $h .= "         printsdr        Print sensor data records for the nodes\n";
    $h .= "         console         Start a serial-over-lan console session.\n";
    $h .= "                         NOTE: Requires that a serial console be defined\n";
    $h .= "                         in kernel arguments, i.e. console=ttyS0,57600\n";
    $h .= "\n";
    $h .= "         forcepxe        Force next boot from PXE\n";
    $h .= "         forcedisk       Force next boot from first Hard Drive\n";
    $h .= "         forcecdrom      Force next boot from CD-ROM\n";
    $h .= "         forcebios       Force next boot into BIOS\n";
    $h .= "\n";
    $h .= "         help            Show usage information\n";
    $h .= "\n";
    $h .= "TARGETS:\n";
    $h .= "\n";
    $h .= "     The target is the specification for the node you wish to act on. All targets\n";
    $h .= "     can be bracket expanded as follows:\n";
    $h .= "\n";
    $h .= "         n00[0-99]       inclusively all nodes from n0000 to n0099\n";
    $h .= "         n00[00,10-99]   n0000 and inclusively all nodes from n0010 to n0099\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "\n";
    $h .= "     -l, --lookup        How should we reference this node? (default is name)\n";
    $h .= "         --ipaddr        The IPMI accessible IP address for this node. If multiple\n";
    $h .= "                         nodes are given, this IP address will be incremented for\n";
    $h .= "                         each node given\n";
    $h .= "         --vlan          The VLAN ID defined for this node (1-4096 or 'off')\n";
    $h .= "         --netmask       The netmask defined for this node\n";
    $h .= "         --uid           The IPMI ID to use for the user on this node\n";
    $h .= "         --lanchannel    The IPMI LAN CHANNEL for this node\n";
    $h .= "         --username      Define the IPMI username for this node\n";
    $h .= "         --password      Define the IPMI password for this node\n";
    $h .= "         --proto         Define the IPMI protocol for this node (defaults to lan)\n";
    $h .= "         --target        Define the IPMI target (for multi-node chassis)\n";
    $h .= "         --autoconfig    Automatically try and configure this node's IPMI settings\n";
    $h .= "                         on boot (boolean 1/0) - note: if no password is set for the\n";
    $h .= "                         node, one will be randomly generated\n";
    $h .= "     -d, --delay         Delay/pad the IPMI commands (very useful for throttling boots)\n";
    $h .= "     -f, --fanout        Change the fanout for parallel IPMI commands (default: 8)\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> ipmi set n000[0-4] --ipaddr=10.100.0.1 --netmask=255.255.255.0\n";
    $h .= "\n";

    return($h);
}

sub
summary()
{
    my $output;

    $output .= "Node IPMI configuration";

    return($output);
}


sub
complete()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $opt_lookup = "name";
    my @ret;

    if (! $db) {
        return();
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

    if (exists($ARGV[1])) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    } else {
        @ret = ("list", "set", "print", "help", "poweron", "poweroff", "console", 
            "powercycle", "ident", "noident", "printsel", "clearsel", "printsdr",
            "forcepxe", "forcedisk", "forcecdrom", "forcebios");
    }

    @ARGV = ();

    return(@ret);
}

sub
exec()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $term = Warewulf::Term->new();
    my $opt_lookup = "name";
    my $opt_fanout = 8;
    my $opt_padding;
    my $opt_ipaddr;
    my $opt_vlanid;
    my $opt_netmask;
    my $opt_uid;
    my $opt_lanchannel;
    my $opt_username;
    my $opt_password;
    my $opt_proto;
    my $opt_autoconfig;
    my $opt_noautoconfig;
    my $return_count;
    my $objSet;
    my @changes;
    my $command;
    my $persist_bool;
    my $object_count;

    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'ipaddr=s'      => \$opt_ipaddr,
        'vlan=s'        => \$opt_vlanid,
        'netmask=s'     => \$opt_netmask,
        'uid=s'         => \$opt_uid,
        'lanchannel=s'  => \$opt_lanchannel,
        'username=s'    => \$opt_username,
        'password=s'    => \$opt_password,
        'proto=s'       => \$opt_proto,
        'autoconfig=s'  => \$opt_autoconfig,
        'noautoconfig'  => \$opt_noautoconfig,
        'l|lookup=s'    => \$opt_lookup,
        'd|delay=s'     => \$opt_padding,
        'p|padding=s'   => \$opt_padding,
        'f|fanout=s'    => \$opt_fanout,
       'target=s'      => \$opt_target,
    );

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not avaialble!\n");
        return();
    }

    $objSet = $db->get_objects("node", $opt_lookup, &expand_bracket(@ARGV));
    $object_count = $objSet->count();

    if ($object_count eq 0) {
        &nprint("No nodes found\n");
        return();
    }


    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
    } elsif ($command eq "set") {
        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        if ($opt_ipaddr) {
            if (uc($opt_ipaddr) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_ipaddr(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_IPADDR"));
                $persist_bool = 1;
            } else {
                my $ip_serialized = Warewulf::Network->ip_serialize($opt_ipaddr);
                foreach my $o (sort {$a->name() cmp $b->name()} $objSet->get_list()) {
                    $o->ipmi_ipaddr(Warewulf::Network->ip_unserialize($ip_serialized));
                    $ip_serialized++;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_IPADDR", $opt_ipaddr));
                $persist_bool = 1;
            }
        }
        if ($opt_vlanid) {
            if (uc($opt_vlanid) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_vlanid(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_VLANID"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_vlanid($opt_vlanid);
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_VLANID", $opt_vlanid));
                $persist_bool = 1;
            }
        }
        if ($opt_netmask) {
            if (uc($opt_netmask) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_netmask(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_NETMASK"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_netmask($opt_netmask);
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_NETMASK", $opt_netmask));
                $persist_bool = 1;
            }
        }
        if ($opt_uid) {
            if (uc($opt_uid) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_uid(undef);
                }
                push(@changes, sprintf("    UNDEF: %-20s\n", "IPMI_UID"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_uid($opt_uid);
                }
                push(@changes, sprintf("     SET: %-20s\n", "IPMI_UID", $opt_uid));
                $persist_bool = 1;
            }
        }
        if ($opt_lanchannel) {
            if (uc($opt_lanchannel) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_lanchannel(undef);
                }
                push(@changes, sprintf("    UNDEF: %-20s\n", "IPMI_LANCHANNEL"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_lanchannel($opt_lanchannel);
                }
                push(@changes, sprintf("     SET: %-20s\n", "IPMI_LANCHANNEL", $opt_lanchannel));
                $persist_bool = 1;
            }
        }
        if ($opt_username) {
            if (uc($opt_username) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_username(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_USERNAME"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_username($opt_username);
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_USERNAME", $opt_username));
                $persist_bool = 1;
            }
        }
        if ($opt_password) {
            if (uc($opt_password) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_password(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_PASSWORD"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_password($opt_password);
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_PASSWORD", $opt_password));
                $persist_bool = 1;
            }
        }
        if ($opt_proto) {
            my $new_proto;
            foreach my $o ($objSet->get_list()) {
                $new_proto = $o->ipmi_proto(lc($opt_proto));
            }
            if ($opt_proto eq $new_proto) {
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_PROTO", $opt_proto));
                $persist_bool = 1;
            } else {
                print "IPMI protocol $opt_proto is not supported.\n";
            }
        }
        if ($opt_target) {
            if (uc($opt_target) eq "UNDEF") {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_target(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_TARGET"));
                $persist_bool = 1;
            } else {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_target($opt_target);
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "IPMI_TARGET", $opt_target));
                $persist_bool = 1;
            }
        }
        if (defined($opt_autoconfig)) {
            my $set_username;
            my $set_password;
            if ( uc($opt_autoconfig) eq "UNDEF" or $opt_autoconfig == 0 ) {
                foreach my $o ($objSet->get_list()) {
                    $o->ipmi_autoconfig(undef);
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_AUTOCONFIGURE"));
                $persist_bool = 1;
            } else {
                my $ipmi_persist_bool;
                foreach my $o ($objSet->get_list()) {
                    if ($o->ipmi_ipaddr() and $o->ipmi_netmask()) {
                        if (! $o->ipmi_username()) {
                            $o->ipmi_username("wwipmi");
                            $set_username = 1;
                        }
                        if (! $o->ipmi_password()) {
                            $o->ipmi_password(&rand_string(8));
                            $set_password = 1;
                        }
                        $o->ipmi_autoconfig(1);
                        $ipmi_persist_bool = 1;
                    } else {
                        &eprint("The IPMI network is not properly configured for this node!\n");
                        &nprint("You can set the network using the wwsh command:\n\n");
                        &nprint("    ipmi set --ipaddr=x.x.x.x --netmask=x.x.x.x [node]\n\n");
                    }
                }
                if ($ipmi_persist_bool) {
                    push(@changes, sprintf("     SET: %-20s\n", "AUTOCONFIG"));
                    if ($set_username) {
                        push(@changes, sprintf("     SET: %-20s = %s\n", "USERNAME", "wwipmi"));
                    }
                    if ($set_password) {
                        push(@changes, sprintf("     SET: %-20s = %s\n", "PASSWORD", "?"x8));
                    }
                    $persist_bool = 1;
                }
            }
        }
        if ($opt_noautoconfig) {
            foreach my $o ($objSet->get_list()) {
                $o->ipmi_autoconfig(0);
            }
            push(@changes, sprintf("   UNDEF: %-20s\n", "IPMI_AUTOCONFIGURE"));
            $persist_bool = 1;
        }

        if ($persist_bool) {
            if ($term->interactive()) {
                print "Are you sure you want to make the following changes to ". $object_count ." node(s):\n\n";
                foreach my $change (@changes) {
                    print $change;
                }
                print "\n";
                my $yesno = lc($term->get_input("Yes/No> ", "no", "yes"));
                if ($yesno ne "y" and $yesno ne "yes") {
                    &nprint("No update performed\n");
                    return();
                }
            }

            $return_count = $db->persist($objSet);

            &iprint("Updated $return_count objects\n");
        }

    } elsif ($command eq "poweron") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("poweron");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "poweroff") {
        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("poweroff");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "powercycle") {
        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("powercycle");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "powerstatus") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("powerstatus");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "ident") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("ident");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "noident") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("noident");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "printsel") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("printsel");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "clearsel") {
        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("clearsel");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "printsdr") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("printsdr");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "forcepxe") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("forcepxe");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "forcedisk") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("forcedisk");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "forcecdrom") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("forcecdrom");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "forcebios") {

        my $parallel = Warewulf::ParallelCmd->new();
        $parallel->ktime(15);
        $parallel->pad($opt_padding);
        $parallel->fanout($opt_fanout);
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name();
            my $cmd = $o->ipmi_command("forcebios");
            if ($cmd) {
                $parallel->queue($cmd, "$name: ", "%-20s %s\n");
            }
        }
        $parallel->run();
    } elsif ($command eq "console") {
        if ($objSet->count() > 1) {
            print "You can only launch a serial-over-lan console for one node at a time!\n";
        } else {
            $o = $objSet->get_object(0);
            print "WARNING! Starting an IPMI SOL console for " . $o->name() ."!\n";
            print "Execution will return to Warewulf after you exit the console.\n";
            sleep(1);
            system($o->ipmi_command("console"));
        }
    } elsif ($command eq "print") {
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name() || "UNDEF";
            
            &nprintf("#### %s %s#\n", $name, "#" x (72 - length($name)));
            printf("%15s: %-16s = %s\n", $name, "IPMI_IPADDR", $o->get("ipmi_ipaddr") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_VLANID", $o->get("ipmi_vlanid") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_NETMASK", $o->get("ipmi_netmask") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_UID", $o->get("ipmi_uid") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_LANCHANNEL", $o->get("ipmi_lanchannel") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_USERNAME", $o->get("ipmi_username") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_PASSWORD", $o->get("ipmi_password") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_AUTOCONFIG", $o->get("ipmi_autoconfig") || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_PROTO", $o->ipmi_proto() || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPMI_TARGET", $o->ipmi_target() || "UNDEF");
        }

    } elsif ($command eq "list") {
        &nprintf("%-19s %-4s    %-14s %-14s\n", "NAME", "AUTO", "IPMI_IPADDR", "IPMI_NETMASK");
        &nprint("================================================================================\n");
        foreach my $o ($objSet->get_list()) {
            my $name = $o->name() || "UNDEF";

            printf("%-19s %-4s    %-14s %-14s\n",
                &ellipsis(19, $name, "end"),
                ($o->get("ipmi_autoconfig") ? "yes" : "no"),
                $o->get("ipmi_ipaddr") || "UNDEF",
                $o->get("ipmi_netmask") || "UNDEF"
            );
        }
    } elsif ($command eq "help") {
        print $self->help();

    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
    }

    # We are done with ARGV, and it was internally modified, so lets reset
    @ARGV = ();

    return($return_count);
}


1;
