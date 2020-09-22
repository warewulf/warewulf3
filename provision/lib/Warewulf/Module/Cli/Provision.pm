#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#




package Warewulf::Module::Cli::Provision;

use Getopt::Long;
use Text::ParseWords;
use Warewulf::DataStore;
use Warewulf::Logger;
use Warewulf::File;
use Warewulf::Module::Cli;
use Warewulf::Provision;
use Warewulf::Term;
use Warewulf::Util;

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
    return("provision");
}

sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     provision <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "    The provision command is used for setting node provisioning attributes.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         set             Modify an existing node configuration\n";
    $h .= "         list            List a summary of the node(s) provision configuration\n";
    $h .= "         print           Print the full node(s) provision configuration\n";
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
    $h .= "     -b, --bootstrap     Define the bootstrap image that this node should use\n";
    $h .= "     -V, --vnfs          Define the VNFS that this node should use\n";
    $h .= "         --validate      Enable checksum validation of VNFS on boot\n";
    $h .= "         --master        Specifically set the Warewulf master(s) for this node\n";
# TODO: Bootserver is not being used yet...
#    $h .= "         --bootserver    If you have multiple DHCP/TFTP servers, which should be\n";
#    $h .= "                         used to boot this node\n";
    $h .= "         --files         Define the files that should be provisioned to this node\n";
    $h .= "         --fileadd       Add a file to be provisioned to this node\n";
    $h .= "         --filedel       Remove a file to be provisioned to this node\n";
    $h .= "         --preshell      Start a shell on the node before provisioning (boolean)\n";
    $h .= "         --postshell     Start a shell on the node after provisioning (boolean)\n";
    $h .= "         --postreboot    Reboot after provisioning instead of switch_root into VNFS (boolean)\n";
    $h .= "         --postnetdown   Shutdown the network after provisioning (boolean)\n";
    $h .= "         --bootlocal     Boot the node from the local disk (\"exit\" or \"normal\")\n";
    $h .= "         --console       Set a specific console for the kernel command line\n";
    $h .= "         --kargs         Define the kernel arguments (assumes \"net.ifnames=0 biosdevname=0 quiet\" if UNDEF)\n";
    $h .= "         --pxeloader     Define a custom PXE loader image to use\n";
    $h .= "         --ipxeurl       Define a custom iPXE configuration URL to use\n";
    $h .= "         --selinux       Boot node with SELinux support? (valid options are: UNDEF,\n";
    $h .= "                         ENABLED, and ENFORCED)\n";
    $h .= "     -f, --filesystem    Specify a filesystem command file\n";
    $h .= "         --bootloader    Disk to install bootloader to (STATEFUL)\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> provision set n000[0-4] --bootstrap=2.6.30-12.x86_64\n";
    $h .= "     Warewulf> provision set n00[00-99] --fileadd=ifcfg-eth0\n";
    $h .= "     Warewulf> provision set -l=cluster mycluster --vnfs=rhel-6.0\n";
    $h .= "     Warewulf> provision set -l=group mygroup hello group123\n";
    $h .= "     Warewulf> provision set n00[0-4] --console=ttyS1,57600 --kargs=\"noacpi\"\n";
    $h .= "     Warewulf> provision list n00[00-99]\n";
    $h .= "\n";

    return($h);
}

sub
summary()
{
    my $output;

    $output .= "Node provision manipulation commands";

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

    if (exists($ARGV[1]) and ($ARGV[1] eq "print" or $ARGV[1] eq "set")) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    } else {
        @ret = ("list", "set", "print");
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
    my $config = Warewulf::Config->new("provision.conf");
    my $con_kargs = $config->get("default kargs") || "quiet";
    my $opt_lookup = "name";
    my $opt_bootstrap;
    my $opt_vnfs;
    my $opt_validate;
    my $opt_preshell;
    my $opt_postshell;
    my $opt_postreboot;
    my $opt_postnetdown;
    my $opt_bootlocal;
    my @opt_master;
    my @opt_bootserver;
    my @opt_files;
    my @opt_fileadd;
    my @opt_filedel;
    my $opt_kargs;
    my $opt_console;
    my $opt_pxeloader;
    my $opt_ipxeurl;
    my $opt_selinux;
    my $opt_bootloader;
    my $opt_diskformat;
    my $opt_diskpartition;
    my $opt_filesystem;
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
        'files=s'       => \@opt_files,
        'fileadd=s'     => \@opt_fileadd,
        'filedel=s'     => \@opt_filedel,
        'kargs=s'       => \$opt_kargs,
        'console=s'     => \$opt_console,
        'pxeloader=s'   => \$opt_pxeloader,
        'ipxeurl=s'     => \$opt_ipxeurl,
        'master=s'      => \@opt_master,
        'bootserver=s'  => \@opt_bootserver,
        'b|bootstrap=s' => \$opt_bootstrap,
        'V|vnfs=s'      => \$opt_vnfs,
        'validate=s'    => \$opt_validate,
        'preshell=s'    => \$opt_preshell,
        'postshell=s'   => \$opt_postshell,
        'postreboot=s'  => \$opt_postreboot,
        'postnetdown=s' => \$opt_postnetdown,
        'bootlocal=s'   => \$opt_bootlocal,
        'l|lookup=s'    => \$opt_lookup,
        'selinux=s'     => \$opt_selinux,
        'bootloader=s'  => \$opt_bootloader,
        'dformat=s'     => \$opt_diskformat,
        'dpartition=s'  => \$opt_diskpartition,
        'f|filesystem=s' => \$opt_filesystem,
    );

    $command = shift(@ARGV) || "help";

    if (! $db) {
        &eprint("Database object not avaialble!\n");
        return();
    }

    if ($command eq "help") {
        print $self->help();
        return();
    }

    $objSet = $db->get_objects("node", $opt_lookup, &expand_bracket(@ARGV));
    $object_count = $objSet->count();

    if ($object_count eq 0) {
        &nprint("No nodes found\n");
        return();
    }

    if ($command eq "set") {

        if (! @ARGV) {
            &eprint("To make changes, you must provide a list of nodes to operate on.\n");
            return undef;
        }

        if ($opt_bootstrap) {
            if (uc($opt_bootstrap) eq "UNDEF") {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->bootstrapid(undef);
                    &dprint("Deleting bootstrap for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "BOOTSTRAP"));
            } else {
                my $bootstrapObj = $db->get_objects("bootstrap", "name", $opt_bootstrap)->get_object(0);
                
                if ($bootstrapObj and my $bootstrapid = $bootstrapObj->get("_id")) {
                    
                    my $bootstrapArch = $bootstrapObj->arch();

                    foreach my $obj ($objSet->get_list()) {
                        my $name = $obj->name() || "UNDEF";
                        my $arch = $obj->arch();
                        if ($arch && $bootstrapArch && $arch ne $bootstrapArch) {
                          &eprint("Bootstrap ARCH ($bootstrapArch) does not match node ARCH ($arch), skipping!\n");
                          next;
                        }
                        $obj->bootstrapid($bootstrapid);
                        &dprint("Setting bootstrapid for node name: $name\n");
                        $persist_bool = 1;
                    }
                    push(@changes, sprintf("     SET: %-20s = %s\n", "BOOTSTRAP", $opt_bootstrap));
                } else {
                    &eprint("No bootstrap named: $opt_bootstrap\n");
                }
            }
        }

        if ($opt_vnfs) {
            if (uc($opt_vnfs) eq "UNDEF") {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->vnfsid(undef);
                    &dprint("Deleting vnfsid for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "VNFS"));
            } else {
                my $vnfsObj = $db->get_objects("vnfs", "name", $opt_vnfs)->get_object(0);
                if ($vnfsObj and my $vnfsid = $vnfsObj->get("_id")) {
                    my $vnfsArch = $vnfsObj->arch();
                    foreach my $obj ($objSet->get_list()) {
                        my $name = $obj->name() || "UNDEF";
                        my $arch = $obj->arch();
                        if ($arch && $vnfsArch && $arch ne $vnfsArch) {
                          &eprint("Vnfs ARCH ($vnfsArch) does not match node ARCH ($arch), skipping!\n");
                          next;
                        }
                        $obj->vnfsid($vnfsid);
                        &dprint("Setting vnfsid for node name: $name\n");
                        $persist_bool = 1;
                    }
                    push(@changes, sprintf("     SET: %-20s = %s\n", "VNFS", $opt_vnfs));
                } else {
                    &eprint("No VNFS named: $opt_vnfs\n");
                }
            }
        }

        if (defined($opt_validate)) {
            if (uc($opt_validate) eq "UNDEF" or
                uc($opt_validate) eq "FALSE" or
                uc($opt_validate) eq "NO" or
                uc($opt_validate) eq "N" or
                $opt_validate == 0
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->validate_vnfs(0);
                    &dprint("Disabling checksum validation for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "VALIDATE_VNFS"));
            } else {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->validate_vnfs(1);
                    &dprint("Enabling checksum validation for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "VALIDATE_VNFS", 1));
            }
        }

        if (defined($opt_preshell)) {
            if (uc($opt_preshell) eq "UNDEF" or
                uc($opt_preshell) eq "FALSE" or
                uc($opt_preshell) eq "NO" or
                uc($opt_preshell) eq "N" or
                $opt_preshell == 0
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->preshell(0);
                    &dprint("Disabling preshell for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "PRESHELL"));
            } else {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->preshell(1);
                    &dprint("Enabling preshell for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "PRESHELL", 1));
            }
        }

        if (defined($opt_postshell)) {
            if (uc($opt_postshell) eq "UNDEF" or
                uc($opt_postshell) eq "FALSE" or
                uc($opt_postshell) eq "NO" or
                uc($opt_postshell) eq "N" or
                $opt_postshell == 0
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postshell(0);
                    &dprint("Disabling postshell for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "POSTSHELL"));
            } else {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postshell(1);
                    &dprint("Enabling postshell for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "POSTSHELL", 1));
            }
        }

        if (defined($opt_postreboot)) {
            if (uc($opt_postreboot) eq "UNDEF" or
                uc($opt_postreboot) eq "FALSE" or
                uc($opt_postreboot) eq "NO" or
                uc($opt_postreboot) eq "N" or
                $opt_postreboot == 0
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postreboot(0);
                    &dprint("Disabling postreboot for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "POSTREBOOT"));
            } else {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postreboot(1);
                    &dprint("Enabling postreboot for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "POSTREBOOT", 1));
            }
        }

        if (defined($opt_postnetdown)) {
            if (uc($opt_postnetdown) eq "UNDEF" or
                uc($opt_postnetdown) eq "FALSE" or
                uc($opt_postnetdown) eq "NO" or
                uc($opt_postnetdown) eq "N" or
                $opt_postnetdown == 0
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postnetdown(0);
                    &dprint("Disabling postnetdown for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "POSTNETDOWN"));
            } else {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->postnetdown(1);
                    &dprint("Enabling postnetdown for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "POSTNETDOWN", 1));
            }
        }

        if (defined($opt_bootlocal)) {
            if (uc($opt_bootlocal) eq "UNDEF" or
                uc($opt_bootlocal) eq "FALSE" or
                uc($opt_bootlocal) eq "NO" or
                uc($opt_bootlocal) eq "N" or
                $opt_bootlocal eq "0"
            ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->bootlocal(0);
                    &dprint("Disabling bootlocal for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("   UNDEF: %-20s\n", "BOOTLOCAL"));
            } elsif (uc($opt_bootlocal) eq "EXIT" or
                     uc($opt_bootlocal) eq "NORMAL"
              ) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->bootlocal(uc($opt_bootlocal));
                    &dprint("Enabling bootlocal for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "BOOTLOCAL", uc($opt_bootlocal)));
            } else {
                &eprint("Invalid value specified, acceptable values are \"UNDEF\", \"NORMAL\", or \"EXIT\" for bootlocal!\n");
                return();
            }
        }

        if (@opt_master) {
            foreach my $obj ($objSet->get_list()) {
                my $nodename = $obj->get("name") || "UNDEF";

                $obj->master(split(",", join(",", @opt_master)));

                &dprint("Setting master for node name: $nodename\n");
                $persist_bool = 1;
            }
            push(@changes, sprintf("     SET: %-20s = %s\n", "MASTER", join(",", @opt_master)));
        }

        if (@opt_files) {
            my @file_ids;
            my @file_names;
            foreach my $filename (split(",", join(",", @opt_files))) {
                &dprint("Building file ID's for: $filename\n");
                my @objList = $db->get_objects("file", "name", $filename)->get_list();
                if (@objList) {
                    foreach my $fileObj ($db->get_objects("file", "name", $filename)->get_list()) {
                        if ($fileObj->id()) {
                            &dprint("Found ID for $filename: ". $fileObj->id() ."\n");
                            push(@file_names, $fileObj->name());
                            push(@file_ids, $fileObj->id());
                        } else {
                            &eprint("No file ID found for: $filename\n");
                        }
                    }
                } else {
                    &eprint("No file found for name: $filename\n");
                }
            }
            if (@file_ids) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->fileids(@file_ids);
                    &dprint("Setting file IDs for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     SET: %-20s = %s\n", "FILES", join(",", @file_names)));
            }
        }

        if (@opt_fileadd) {
            my @file_ids;
            my @file_names;
            foreach my $filename (split(",", join(",", @opt_fileadd))) {
                &dprint("Building file ID's for: $filename\n");
                my @objList = $db->get_objects("file", "name", $filename)->get_list();
                if (@objList) {
                    foreach my $fileObj ($db->get_objects("file", "name", $filename)->get_list()) {
                        if ($fileObj->id()) {
                            &dprint("Found ID for $filename: ". $fileObj->id() ."\n");
                            push(@file_names, $fileObj->name());
                            push(@file_ids, $fileObj->id());
                        } else {
                            &eprint("No file ID found for: $filename\n");
                        }
                    }
                } else {
                    &eprint("No file found for name: $filename\n");
                }
            }
            if (@file_ids) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->fileidadd(@file_ids);
                    &dprint("Adding file IDs for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     ADD: %-20s = %s\n", "FILES", join(",", @file_names)));
            }
        }

        if (@opt_filedel) {
            my @file_ids;
            my @file_names;
            foreach my $filename (split(",", join(",", @opt_filedel))) {
                &dprint("Building file ID's for: $filename\n");
                my @objList = $db->get_objects("file", "name", $filename)->get_list();
                if (@objList) {
                    foreach my $fileObj ($db->get_objects("file", "name", $filename)->get_list()) {
                        if ($fileObj->id()) {
                            &dprint("Found ID for $filename: ". $fileObj->id() ."\n");
                            push(@file_names, $fileObj->name());
                            push(@file_ids, $fileObj->id());
                        } else {
                            &eprint("No file ID found for: $filename\n");
                        }
                    }
                } else {
                    &eprint("No file found for name: $filename\n");
                }
            }
            if (@file_ids) {
                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->fileiddel(@file_ids);
                    &dprint("Setting file IDs for node name: $name\n");
                    $persist_bool = 1;
                }
                push(@changes, sprintf("     DEL: %-20s = %s\n", "FILES", join(",", @file_names)));
            }
        }

        if ($opt_kargs) {
            $opt_kargs =~ s/\"//g;
            my @kargs = split(/\s+/,$opt_kargs);
            foreach my $k (@kargs) {
                &dprint("Including kernel argument += $k\n");
            }

            foreach my $obj ($objSet->get_list()) {
                my $name = $obj->name() || "UNDEF";
                $obj->kargs(@kargs);
                &dprint("Setting kernel arguments for node name: $name\n");
                $persist_bool = 1;
            }
            if (uc($kargs[0]) eq "UNDEF") {
                push(@changes, sprintf("     DEL: %-20s = %s\n", "KARGS", "[ALL]"));
            } else {
                push(@changes, sprintf("     SET: %-20s = %s\n", "KARGS", '"' . join(" ",@kargs) . '"'));
            }
        }

        if ($opt_console) {
            if ($opt_console =~ /^((tty|lp)[A-Z]*[0-9]+(,[0-9]{4,6}([noe]([0-9]r?)?)?)?)/ || $opt_console =~ /^(UNDEF)$/) {
                $opt_console = $1;

                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->console($opt_console);
                    &dprint("Setting console argument for node name: $name\n");
                    $persist_bool = 1;
                }
                if (uc($opt_console) eq "UNDEF") {
                    push(@changes, sprintf("     DEL: %-20s\n", "CONSOLE"));
                } else {
                    push(@changes, sprintf("     SET: %-20s = %s\n", "CONSOLE", $opt_console));
                }
            } else {
                &eprint("Invalid console format!\n");
            }
        }

        if ($opt_pxeloader) {
            if ($opt_pxeloader =~ /^([a-zA-Z0-9\.\/\-_]+)/) {
                $opt_pxeloader = $1;

                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->pxeloader($opt_pxeloader);
                    &dprint("Setting pxeloader file to: $opt_pxeloader\n");
                    $persist_bool = 1;
                }
                if (uc($opt_pxeloader) eq "UNDEF") {
                    push(@changes, sprintf("     DEL: %-20s\n", "PXELOADER"));
                } else {
                    push(@changes, sprintf("     SET: %-20s = %s\n", "PXELOADER", $opt_pxeloader));
                }

            } else {
                &eprint("Invalid command for PXE loader file!\n");
            }
        }

        if ($opt_ipxeurl) {
            if ($opt_ipxeurl =~ /^([a-zA-Z0-9\.\/\-_\:%\{}\$]+)/) {
                $opt_ipxeurl = $1;

                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->ipxeurl($opt_ipxeurl);
                    &dprint("Setting iPXE URL to: $opt_ipxeurl\n");
                    $persist_bool = 1;
                }
                if (uc($opt_ipxeurl) eq "UNDEF") {
                    push(@changes, sprintf("     DEL: %-20s\n", "IPXEURL"));
                } else {
                    push(@changes, sprintf("     SET: %-20s = %s\n", "IPXEURL", $opt_ipxeurl));
                }

            } else {
                &eprint("Invalid command for iPXE URL!\n");
            }
        }

        if ($opt_selinux) {
            if ($opt_selinux =~ /^(disabled|enabled|enforced)$/i) {
                $opt_selinux = $1;

                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    $obj->selinux($opt_selinux);
                    &dprint("Setting selinux to: $opt_selinux\n");
                    $persist_bool = 1;
                }
                if (uc($opt_selinux) eq "UNDEF") {
                    push(@changes, sprintf("     DEL: %-20s\n", "SELINUX"));
                } else {
                    push(@changes, sprintf("     SET: %-20s = %s\n", "SELINUX", $opt_selinux));
                }

            } else {
                &eprint("Invalid option for SELinux support!\n");
            }
        }

        if ($opt_bootloader) {
            if ($opt_bootloader =~ /^([a-zA-Z0-9_\/]+)$/) {
                $opt_bootloader = $1;

                foreach my $obj ($objSet->get_list()) {
                    my $name = $obj->name() || "UNDEF";
                    &dprint("$name : Setting BOOTLOADER to: $opt_bootloader\n");
                    $obj->bootloader($opt_bootloader);
                    $persist_bool = 1;
                }
                if (uc($opt_bootloader) eq "UNDEF") {
                    push(@changes, sprintf("       DEL: %-20s\n", "BOOTLOADER"));
                } else {
                    push(@changes, sprintf("       SET: %-20s = %s\n", "BOOTLOADER", $opt_bootloader));
                }
            } else {
                &eprint("Invalid option for BOOTLOADER.\n");
            }
        }

        if ($opt_filesystem) {
            my @fsData;
            foreach my $obj ($objSet->get_list()) {
                my $name = $obj->name() || "UNDEF";
                &dprint("$name : Import FS commands file from:\n  $opt_filesystem\n");
                @fsData = $obj->fs($opt_filesystem);
                $persist_bool = 1;
            }

            if (uc($opt_filesystem) eq "UNDEF") {
                push(@changes, sprintf("       DEL: %-20s\n", "FS"));
            } else {
                push(@changes, sprintf("       SET: %-20s = %s\n", "FS", join(",", @fsData)));
            }
        }

        if ($persist_bool) {
            if ($command ne "new" and $term->interactive()) {
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
    } elsif ($command eq "status") {
        &wprint("Persisted status updates (and thus this command) have been deprecated for\n");
        &wprint("scalibility and minimizing DB hits. Each node now logs directly to it's\n");
        &wprint("master's syslog server if it is in listen mode.\n");

    } elsif ($command eq "print") {
        foreach my $o ($objSet->get_list("fqdn", "domain", "cluster", "name")) {
            my @files;
            my $fileObjSet;
            my $name = $o->name() || "UNDEF";
            my $vnfs = "UNDEF";
            my $bootstrap = "UNDEF";
            if ($o->fileids()) {
                $fileObjSet = $db->get_objects("file", "_id", $o->get("fileids"));
            }
            if ($fileObjSet) {
                foreach my $f ($fileObjSet->get_list("name")) {
                    push(@files, $f->name());
                }
            } else {
                push(@files, "UNDEF");
            }
            if (my $vnfsid = $o->vnfsid()) {
                my $vnfsObj = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);
                if ($vnfsObj) {
                    $vnfs = $vnfsObj->name();
                }
            }
            if (my $bootstrapid = $o->bootstrapid()) {
                my $bootstrapObj = $db->get_objects("bootstrap", "_id", $bootstrapid)->get_object(0);
                if ($bootstrapObj) {
                    $bootstrap = $bootstrapObj->name();
                }
            }

            my $kargs;
            if($o->kargs()) {
                $kargs = join(" ",$o->kargs());
            } else {
                $kargs = $con_kargs;
            }

            &nprintf("#### %s %s#\n", $name, "#" x (72 - length($name)));
            printf("%15s: %-16s = %s\n", $name, "MASTER", join(",", $o->master()) || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "BOOTSTRAP", $bootstrap);
            printf("%15s: %-16s = %s\n", $name, "VNFS", $vnfs);
            printf("%15s: %-16s = %s\n", $name, "VALIDATE", $o->validate_vnfs() ? "TRUE" : "FALSE");
            printf("%15s: %-16s = %s\n", $name, "FILES", join(",", @files));
            printf("%15s: %-16s = %s\n", $name, "PRESHELL", $o->preshell() ? "TRUE" : "FALSE");
            printf("%15s: %-16s = %s\n", $name, "POSTSHELL", $o->postshell() ? "TRUE" : "FALSE");
            printf("%15s: %-16s = %s\n", $name, "POSTNETDOWN", $o->postnetdown() ? "TRUE" : "FALSE");
            printf("%15s: %-16s = %s\n", $name, "POSTREBOOT", $o->postreboot() ? "TRUE" : "FALSE");
            printf("%15s: %-16s = %s\n", $name, "CONSOLE", $o->console() || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "PXELOADER", $o->pxeloader() || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "IPXEURL", $o->ipxeurl() || "UNDEF");
            printf("%15s: %-16s = %s\n", $name, "SELINUX", $o->selinux() || "UNDEF");
            printf("%15s: %-16s = \"%s\"\n", $name, "KARGS", $kargs);
            if ($o->get("fs")) {
                printf("%15s: %-16s = \"%s\"\n", $name, "FS", join(",", $o->get("fs")));
            }
            if ($o->get("bootloader")) {
                printf("%15s: %-16s = %s\n", $name, "BOOTLOADER", join(",", $o->get("bootloader")));
            }
            if (defined $o->bootlocal()) {
                if ($o->bootlocal() == -1) {
                    printf("%15s: %-16s = %s\n", $name, "BOOTLOCAL", "EXIT");
                } elsif ($o->bootlocal() == 0) {
                    printf("%15s: %-16s = %s\n", $name, "BOOTLOCAL", "NORMAL");
                }
            } else {
                printf("%15s: %-16s = %s\n", $name, "BOOTLOCAL", "FALSE");
            }
        }

    } elsif ($command eq "list") {
        &nprintf("%-19s %-15s %-21s %-21s\n", "NODE", "VNFS", "BOOTSTRAP", "FILES");
        &nprint("================================================================================\n");
        foreach my $o ($objSet->get_list("fqdn", "domain", "cluster", "name")) {
            my $fileObjSet;
            my @files;
            my $name = $o->name() || "UNDEF";
            my $vnfs = "UNDEF";
            my $bootstrap = "UNDEF";
            if (my @fileids = $o->fileids()) {
                $fileObjSet = $db->get_objects("file", "_id", @fileids);
            }
            if ($fileObjSet) {
                foreach my $f ($fileObjSet->get_list("name")) {
                    push(@files, $f->name());
                }
            } else {
                push(@files, "UNDEF");
            }
            if (my $vnfsid = $o->vnfsid()) {
                my $vnfsObj = $db->get_objects("vnfs", "_id", $vnfsid)->get_object(0);
                if ($vnfsObj) {
                    $vnfs = $vnfsObj->name();
                }
            }
            if (my $bootstrapid = $o->get("bootstrapid")) {
                my $bootstrapObj = $db->get_objects("bootstrap", "_id", $bootstrapid)->get_object(0);
                if ($bootstrapObj) {
                    $bootstrap = $bootstrapObj->name();
                }
            }
            printf("%-19s %-15s %-21s %-21s\n",
                &ellipsis(19, $name, "end"),
                &ellipsis(15, $vnfs, "end"),
                &ellipsis(21, $bootstrap, "end"),
                &ellipsis(21, join(",", @files), "end")
            );
        }
    } else {
        &eprint("Unknown command: $command\n\n");
        print $self->help();
    }

    # We are done with ARGV, and it was internally modified, so lets reset
    @ARGV = ();

    return($return_count);
}


1;
