# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Pxe.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Provision::Pxe;

use Warewulf::ACVars;
use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::Object;
use Warewulf::Network;
use Warewulf::DataStore;
use Warewulf::Provision::Tftp;
use File::Basename;
use File::Path qw(make_path);
use POSIX qw(uname);

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Provision::Pxe - Pxe integration

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::Pxe;

    my $obj = Warewulf::Provision::Pxe->new();
    $obj->update($NodeObj);

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

    return $self->init(@_);
}

sub
init()
{
    my $self = shift;


    return($self);
}


=item setup()

Setup the basic pxe environment.

=cut

sub
setup()
{
    my $self = shift;
    my $datadir = &Warewulf::ACVars::get("datadir");
    my $tftpdir = Warewulf::Provision::Tftp->new()->tftpdir();
    my @x86_tftpfiles = ("bin-i386-pcbios/undionly.kpxe", "bin-x86_64-efi/snp.efi", "bin-i386-efi/snp.efi");
    my @aarch64_tftpfiles = ("bin-arm64-efi/snp.efi");
    my (undef, undef, undef, undef, $arch) = POSIX::uname();

    if ($tftpdir) {
        foreach my $f (@x86_tftpfiles) {
            if (! -f "$tftpdir/warewulf/ipxe/$f") {
                if (-f "$datadir/warewulf/ipxe/$f") {
                    &iprint("Copying $f to the tftp root\n");
                    my $dirname = dirname("$tftpdir/warewulf/ipxe/$f");
                    make_path($dirname, {
                        chmod => 0755,
                    });
                    system("cp $datadir/warewulf/ipxe/$f $tftpdir/warewulf/ipxe/$f");
                    chmod(0644, "$tftpdir/warewulf/ipxe/$f");
                } elsif ($arch eq "x86_64") {
                    &eprint("Could not locate Warewulf's internal $datadir/warewulf/ipxe/$f! Things might be broken!\n");
                }
            }
        }
        foreach my $f (@aarch64_tftpfiles) {
            if (! -f "$tftpdir/warewulf/ipxe/$f") {
                if (-f "$datadir/warewulf/ipxe/$f") {
                    &iprint("Copying $f to the tftp root\n");
                    my $dirname = dirname("$tftpdir/warewulf/ipxe/$f");
                    make_path($dirname, {
                        chmod => 0755,
                    });
                    system("cp $datadir/warewulf/ipxe/$f $tftpdir/warewulf/ipxe/$f");
                    chmod(0644, "$tftpdir/warewulf/ipxe/$f");
                } elsif ($arch eq "aarch64") {
                    &eprint("Could not locate Warewulf's internal $datadir/warewulf/ipxe/$f! Things might be broken!\n");
                }
            }
        }
    } else {
        &wprint("Not integrating with TFTP, no TFTP root directory was found.\n");
    }

    return($self);
}

=item update(@nodeobjects)

Update or create (if not already present) a pxe config for the passed
node object

=cut

sub
update()
{
    my ($self, @nodeobjs) = @_;
    my $statedir = &Warewulf::ACVars::get("statedir");
    my $netobj = Warewulf::Network->new();
    my $db = Warewulf::DataStore->new();
    my $config = Warewulf::Config->new("provision.conf");
    my $devname = $config->get("network device");
    my $master_ipaddr = $config->get("ip address") // $netobj->ipaddr($devname);
    my $master_network = $config->get("ip network") // $netobj->network($devname);
    my $master_netmask = $config->get("ip netmask") // $netobj->netmask($devname);
    my $dhcp_net = $config->get("dhcp network") || "direct";

    if (! $master_ipaddr) {
        &wprint("Could not generate PXE configurations, check 'network device' or 'ip address/netmask/network' configuration!\n");
        return undef;
    }

    &dprint("Updating PXE configuration files now\n");

    if (! "$statedir/warewulf") {
        &dprint("Not updating Pxe because state directory $statedir/warewulf was found!\n");
        return();
    }

    if (! -d "$statedir/warewulf/ipxe/cfg") {
        &iprint("Creating ipxe configuration directory: $statedir/warewulf/ipxe/cfg");
        make_path("$statedir/warewulf/ipxe/cfg", {
            chmod => 0755,
        });
    }

    foreach my $nodeobj (@nodeobjs) {
        my $hostname = $nodeobj->name() || "localhost.localdomain";
        my $nodename = $nodeobj->nodename() || "undef";
        my $bootstrapid = $nodeobj->get("bootstrapid");
        my $db_id = $nodeobj->id();
        my $console = $nodeobj->console();
        my @kargs = $nodeobj->kargs();
        my $bootlocal = $nodeobj->bootlocal();
        my @masters = $nodeobj->get("master");
        my $bootstrapname;
        my $arch = $nodeobj->arch();
        if (! $arch) {
            (undef, undef, undef, undef, $arch) = POSIX::uname();
            &dprint("No arch defined for node $nodename, using local system: $arch");
        }

        if (! $db_id) {
            &eprint("No DB ID associated with this node object object: $hostname/$nodename:$n\n");
            next;
        }

        if (! $nodeobj->enabled()) {
            &dprint("Node $nodename disabled. Skipping.\n");
            next;
        }

        &dprint("Evaluating node: $nodename (object ID: $db_id)\n");

        if ($bootstrapid) {
            my $bootstrapObj = $db->get_objects("bootstrap", "_id", $bootstrapid)->get_object(0);
            if (! $bootstrapObj) {
                &dprint("Bootstrap defined for $nodename, but bootstrap doesn't exit, skipping...\n");
                next;
            }
            my $bootstrapName = $bootstrapObj->get("name");
            my $bootstrapArch;

            if ($bootstrapObj) {
                $bootstrapArch = $bootstrapObj->get("arch");
            }

            if ($bootstrapObj && ! $bootstrapArch) {
                &dprint("Bootstrap architecture not set for $bootstrapName, defaulting to local system...\n");
                (undef, undef, undef, undef, $bootstrapArch) = POSIX::uname();
            }

            if ($bootstrapObj && $bootstrapArch && $bootstrapArch ne $arch) {
                &wprint("Defined bootstrap architecture ($bootstrapArch) does not match architecture for $nodename ($arch), skipping...\n");
                next;
            } elsif ($bootstrapObj) {
                $bootstrapname = $bootstrapObj->name();
            } else {
                &wprint("Defined bootstrap is not valid for node $nodename, skipping...\n");
                next;
            }
        } else {
            &dprint("No bootstrap defined for node $nodename, skipping...\n");
            next;
        }


        foreach my $devname (sort($nodeobj->netdevs_list())) {
            my @hwaddrs = $nodeobj->hwaddr($devname);
            my @bonddevs = $nodeobj->bonddevs($devname);
            my $bondmode = $nodeobj->bondmode($devname);
            my $node_ipaddr = $nodeobj->ipaddr($devname);
            my $node_netmask = $nodeobj->netmask($devname) || $master_netmask;
            my $node_gateway = $nodeobj->gateway($devname);
            my $mtu = $nodeobj->mtu($devname);
            my $node_testnetwork = $netobj->calc_network($node_ipaddr, $node_netmask);

            if (! $devname) {
                &iprint("Skipping PXE config for unknown device name: $nodename\n");
                next;
            }

            if (! @hwaddrs) {
                &iprint("Skipping PXE config for $nodename-$devname (No hwaddr defined)\n");
                next;
            }

            if (($dhcp_net eq "direct") and $node_ipaddr and $node_testnetwork ne $master_network) {
                &iprint("Skipping PXE config for $nodename-$devname (on a different network)\n");
                next;
            }

            foreach my $hwaddr (@hwaddrs)
            {
                &dprint("Creating a pxe config for node '$nodename-$devname/$hwaddr'\n");

                if ($hwaddr =~ /^([:[:xdigit:]]+)$/) {
                    $hwaddr = $1;
                    &iprint("Building iPXE configuration for: $nodename/$hwaddr\n");
                    my $config = $hwaddr;

                    if (! $bootstrapid) {
                        &iprint("Skipping $nodename-$devname-$hwaddr: No bootstrap defined\n");
                        if (-f "$statedir/warewulf/ipxe/cfg/$config") {
                            # If we know gotten this far, but not going to write a config, we
                            # can remove it.
                            unlink("$statedir/warewulf/ipxe/cfg/$config");
                        }
                        next;
                    }

                    &dprint("Creating iPXE config at: $statedir/warewulf/ipxe/cfg/$config\n");
                    if (!open(IPXE, "> $statedir/warewulf/ipxe/cfg/$config")) {
                        &eprint("Could not open iPXE config: $!\n");
                        next;
                    }
                    
                    print IPXE "#!ipxe\n";
                    print IPXE "# Configuration for Warewulf node: $hostname\n";
                    print IPXE "# Warewulf data store ID: $db_id\n";
                    if (defined($bootlocal) && $bootlocal eq -1) {
                        print IPXE "echo Set to bootlocal (exit), exiting iPXE to continue boot order\n";
                        print IPXE "exit 1\n";
                    } elsif (defined($bootlocal) && $bootlocal eq 0)  {
                        print IPXE "echo Set to bootlocal (normal), booting local disk\n";
                        print IPXE "sanboot --no-describe --drive 0x80\n";
                    } else {
                        print IPXE "echo Now booting $hostname with Warewulf bootstrap ($bootstrapname)\n";
                        print IPXE "set base http://$master_ipaddr/WW/bootstrap\n";
                        print IPXE "initrd \${base}/$arch/$bootstrapid/initfs.gz\n";
                        print IPXE "kernel \${base}/$arch/$bootstrapid/kernel ro initrd=initfs.gz wwhostname=$hostname ";
                        print IPXE join(" ", @kargs) . " ";
                        if ($console) {
                            print IPXE "console=tty0 console=$console ";
                        }
                        if (scalar(@masters) > 0) {
                            my $master = join(",", @masters);
                            print IPXE "wwmaster=$master ";
                        } else {
                            print IPXE "wwmaster=$master_ipaddr ";
                        }
                        if ($devname and $node_ipaddr and $node_netmask) {
                            print IPXE "wwipaddr=$node_ipaddr wwnetmask=$node_netmask wwnetdev=$devname wwhwaddr=$hwaddr ";
                        } else {
                            &dprint("$hostname: Skipping static network definition because configuration not complete\n");
                        }
                        if (@bonddevs) {
                            print IPXE "wwbonddevs=".join(',', @bonddevs)." ";
                        } else {
                            &dprint("$hostname: Skipping network bonding devices definition because configuration not complete\n");
                        }
                        if ($bondmode) {
                            print IPXE "wwbondmode=$bondmode ";
                        } else {
                            &dprint("$hostname: Skipping network bonding mode definition because configuration not complete\n");
                        }
                        if ($node_gateway) {
                            print IPXE "wwgateway=$node_gateway ";
                        } else {
                            &dprint("$hostname: Skipping static gateway configuration as it is unconfigured\n");
                        }
                        if ($mtu) {
                            print IPXE "wwmtu=$mtu";
                        } else {
                            &dprint("$hostname: Skipping static MTU configuration as it is unconfigured\n");
                        }
                        print IPXE "\nboot\n";
                    }
                    if (! close IPXE) {
                        &eprint("Could not write iPXE configuration file: $!\n");
                    }
		    chmod(0644, "$statedir/warewulf/ipxe/cfg/$config");
                } else {
                    &eprint("Node: $nodename-$devname: Bad characters in hwaddr: '$hwaddr'\n");
                }
            }
        }
    }
    return(1);
}


=item delete(@nodeobjects)

Delete a PXE configuration for the passed node object.

=cut

sub
delete()
{
    my ($self, @nodeobjs) = @_;
    my $statedir = &Warewulf::ACVars::get("statedir");

    if (! "$statedir/warewulf") {
        &dprint("Not updating Pxe because state directory $statedir/warewulf was found!\n");
        return();
    }

    foreach my $nodeobj (@nodeobjs) {
        my $nodename = $nodeobj->get("name") || "undefined";
        my @hwaddrs = $nodeobj->get("_hwaddr");

        &dprint("Deleting PXE entries for node: $nodename\n");

        foreach my $netdev ($nodeobj->get("netdevs")) {
            my @netdev_hwaddrs = $netdev->get("hwaddr");

            foreach my $hwaddr (@netdev_hwaddrs) {
                if (defined $hwaddr && !grep { lc($_) eq lc($hwaddr) } @hwaddrs) {
                    push @hwaddrs, $hwaddr;
                }
            }
        }
        foreach my $hwaddr (@hwaddrs) {
            if ($hwaddr =~ /^([:[:xdigit:]]+)$/) {
                my $config = $1;

                &iprint("Deleting PXE configuration for $nodename/$config\n");
                if (-f "$statedir/warewulf/ipxe/cfg/$config") {
                    unlink("$statedir/warewulf/ipxe/cfg/$config");
                }
                if (! chmod 0644, "$statedir/warewulf/ipxe/cfg/$config") {
                    &eprint("Could not chmod Pxelinux configuration file: $!\n");
                }
            } else {
                &eprint("Bad characters in hwaddr: $hwaddr\n");
            }
        }
    }
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
