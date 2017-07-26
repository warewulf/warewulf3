# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Pxelinux.pm 50 2010-11-02 01:15:57Z gmk $
#

package Warewulf::Provision::Pxelinux;

use Warewulf::ACVars;
use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::Object;
use Warewulf::Network;
use Warewulf::DataStore;
use Warewulf::Provision::Tftp;
use File::Basename;
use File::Path;
use POSIX qw(uname);

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Pxelinux - Pxelinux integration

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Pxelinux;

    my $obj = Warewulf::Pxelinux->new();
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

Setup the basic pxelinux environment (e.g. pxelinux.0).

=cut

sub
setup()
{
    my $self = shift;
    my $datadir = &Warewulf::ACVars::get("datadir");
    my $tftpdir = Warewulf::Provision::Tftp->new()->tftpdir();
    my @tftpfiles = ("bin/undionly.kpxe", "bin-x86_64-efi/ipxe.efi", "bin-i386-efi/ipxe.efi");

    if ($tftpdir) {
        foreach my $f (@tftpfiles) {
            if (! -f "$tftpdir/warewulf/ipxe/$f") {
                if (-f "$datadir/warewulf/ipxe/$f") {
                    &iprint("Copying $f to the tftp root\n");
                    my $dirname = dirname("$tftpdir/warewulf/ipxe/$f");
                    mkpath($dirname);
                    system("cp $datadir/warewulf/ipxe/$f $tftpdir/warewulf/ipxe/$f");
                } else {
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

Update or create (if not already present) a pxelinux config for the passed
node object

=cut

sub
update()
{
    my ($self, @nodeobjs) = @_;
    my $tftproot = Warewulf::Provision::Tftp->new()->tftpdir();
    my $netobj = Warewulf::Network->new();
    my $db = Warewulf::DataStore->new();
    my $config = Warewulf::Config->new("provision.conf");
    my $devname = $config->get("network device");
    my $master_ipaddr = $netobj->ipaddr($devname);
    my $master_network = $netobj->network($devname);
    my $master_netmask = $netobj->netmask($devname);

    if (! $master_ipaddr) {
        &wprint("Could not generate PXE configurations, check 'network device' configuration!\n");
        return undef;
    }

    &dprint("Updating PXE configuration files now\n");

    if (! $tftproot) {
        &dprint("Not updating Pxelinux because no TFTP root directory was found!\n");
        return();
    }

    if (! -d "$tftproot/warewulf/ipxe/cfg") {
        &iprint("Creating ipxe configuration directory: $tftproot/warewulf/ipxe/cfg");
        mkpath("$tftproot/warewulf/ipxe/cfg");
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
            &dprint("No arch defined for node $nodename, using local system: $arch");
            (undef, undef, undef, undef, $arch) = POSIX::uname();
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
            my $hwaddr = $nodeobj->hwaddr($devname);
            my $node_ipaddr = $nodeobj->ipaddr($devname);
            my $node_netmask = $nodeobj->netmask($devname) || $master_netmask;
            my $node_gateway = $nodeobj->gateway($devname);
            my $mtu = $nodeobj->mtu($devname);
            my $node_testnetwork = $netobj->calc_network($node_ipaddr, $node_netmask);
            my $hwprefix = "01";

            if (! $devname) {
                &iprint("Skipping PXE config for unknown device name: $nodename\n");
                next;
            }

            if (! $hwaddr) {
                &iprint("Skipping PXE config for $nodename-$devname (No hwaddr defined)\n");
                next;
            }

            if ($node_ipaddr and $node_testnetwork ne $master_network) {
                &iprint("Skipping PXE config for $nodename-$devname (on a different network)\n");
                next;
            }

            if ($hwaddr =~ /(([0-9a-f]{2}:){7}[0-9a-f]{2})$/) {
                $hwprefix = "20";
            }

            &dprint("Creating a pxelinux config for node '$nodename-$devname/$hwaddr'\n");

            if ($hwaddr =~ /^([0-9a-zA-Z:]+)$/) {
                $hwaddr = $1;
                &iprint("Building iPXE configuration for: $nodename/$hwaddr\n");
                my $config = $hwaddr;

                if (! $bootstrapid) {
                    &iprint("Skipping $nodename-$devname-$hwaddr: No bootstrap defined\n");
                    if (-f "$tftproot/warewulf/ipxe/cfg/$config") {
                        # If we know gotten this far, but not going to write a config, we
                        # can remove it.
                        unlink("$tftproot/warewulf/ipxe/cfg/$config");
                    }
                    next;
                }

                &dprint("Creating iPXE config at: $tftproot/warewulf/ipxe/cfg/$config\n");
                if (!open(IPXE, "> $tftproot/warewulf/ipxe/cfg/$config")) {
                    &eprint("Could not open iPXE config: $!\n");
                    next;
                }
                print IPXE "#!ipxe\n";
                print IPXE "# Configuration for Warewulf node: $hostname\n";
                print IPXE "# Warewulf data store ID: $db_id\n";
                if (defined($bootlocal) && $bootlocal eq -1) {
                    print IPXE "echo Set to bootlocal (exit), exiting iPXE to continue boot order\n";
                    print IPXE "exit\n";
                } elsif (defined($bootlocal) && $bootlocal eq 0)  {
                    print IPXE "echo Set to bootlocal (normal), booting local disk\n";
                    print IPXE "sanboot --no-describe --drive 0x80\n";
                } else {

                    print IPXE "echo Now booting $hostname with Warewulf bootstrap ($bootstrapname)\n";
                    print IPXE "set base http://$master_ipaddr/WW/boot/warewulf\n";
                    print IPXE "initrd \${base}/bootstrap/$arch/$bootstrapid/initfs.gz\n";
                    print IPXE "kernel \${base}/bootstrap/$arch/$bootstrapid/kernel ro initrd=initfs.gz wwhostname=$hostname ";
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
            } else {
                &eprint("Node: $nodename-$devname: Bad characters in hwaddr: '$hwaddr'\n");
            }
        }
    }
}


=item delete(@nodeobjects)

Delete a pxelinux configuration for the passed node object.

=cut

sub
delete()
{
    my ($self, @nodeobjs) = @_;
    my $tftproot = Warewulf::Provision::Tftp->new()->tftpdir();

    if (! $tftproot) {
        &dprint("Not updating PXELinux because no TFTP root directory was found!\n");
        return();
    }

    foreach my $nodeobj (@nodeobjs) {
        my $nodename = $nodeobj->get("name") || "undefined";
        my @hwaddrs = $nodeobj->get("_hwaddr");

        &dprint("Deleting PXELinux entries for node: $nodename\n");

        foreach my $netdev ($nodeobj->get("netdevs")) {
            if (defined($netdev->get("hwaddr"))) {
                my $hwaddr = lc($netdev->get("hwaddr"));

                if (defined($hwaddr) && !scalar(grep { lc($_) eq $hwaddr } @hwaddrs)) {
                    push @hwaddrs, $hwaddr;
                }
            }
        }
        foreach my $hwaddr (@hwaddrs) {
            if ($hwaddr =~ /^([:[:xdigit:]]+)$/) {
                my $config;

                $hwaddr = $1;
                &iprint("Deleting PXELinux configuration for $nodename/$hwaddr\n");
                $hwaddr =~ s/:/-/g;
                $config = "01-$hwaddr";
                if (-f "$tftproot/warewulf/pxelinux.cfg/$config") {
                    unlink("$tftproot/warewulf/pxelinux.cfg/$config");
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
