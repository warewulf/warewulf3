#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#




package Warewulf::Module::Cli::Bootstrap;

use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::Bootstrap;
use Warewulf::DSO::Bootstrap;
use Getopt::Long;
use File::Basename;
use File::Path;
use POSIX qw(uname);
use Text::ParseWords;

our @ISA = ('Warewulf::Module::Cli');

my $entity_type = "bootstrap";

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

    $h .= "USAGE:\n";
    $h .= "     bootstrap <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     This interface allows you to manage your bootstrap images within the Warewulf\n";
    $h .= "     data store.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "\n";
    $h .= "         import          Import a bootstrap image into Warewulf\n";
    $h .= "         export          Export a bootstrap image to the local file system\n";
    $h .= "         delete          Delete a bootstrap image from Warewulf\n";
    $h .= "         list            Show all of the currently imported bootstrap images\n";
    $h .= "         set             Set bootstrap attributes\n";
    $h .= "         (re)build       Build (or rebuild) the tftp bootable image(s) on this host\n";
    $h .= "         help            Show usage information\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "\n";
    $h .= "     -n, --name      Name of bootstrap, defaults to the file name on import\n";
    $h .= "     -a, --arch      Architecture of bootstrap, defaults to the current machine on import\n";
    $h .= "     -1              With list command, output bootstrap name only\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "\n";
    $h .= "     Warewulf> bootstrap import /path/to/name.wwbs --name=bootstrap --arch=x86_64\n";
    $h .= "     Warewulf> bootstrap export bootstrap1 bootstrap2 /tmp/exported_bootstrap/\n";
    $h .= "     Warewulf> bootstrap list\n";
    $h .= "     Warewulf> bootstrap set --arch=x86_64 name\n";
    $h .= "\n";

    return $h;
}



sub
summary()
{
    my $output;

    $output .= "Manage your bootstrap images";

    return $output;
}


sub
complete()
{
    my $self = shift;
    my $opt_lookup = "name";
    my $db = $self->{"DB"};
    my @ret;

    if (! $db) {
        return undef;
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

    if (exists($ARGV[1]) and ($ARGV[1] eq "list" or $ARGV[1] eq "export" or $ARGV[1] eq "delete")) {
        @ret = $db->get_lookups($entity_type, $opt_lookup);
    } else {
        @ret = ("list", "import", "export", "delete");
    }

    @ARGV = ();

    return @ret;

}

sub
exec()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $term = Warewulf::Term->new();
    my $opt_lookup = "name";
    my $opt_name;
    my $opt_single;
    my $command;
    my $return_count = 0;


    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'n|name=s'      => \$opt_name,
        'l|lookup=s'    => \$opt_lookup,
        'a|arch=s'      => \$opt_arch,
        '1'             => \$opt_single,
    );

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not avaialble!\n");
        return undef;
    }

    if ($command) {
        if ($command eq "help") {
            print $self->help();
            return 1;
        } elsif ($command eq "export") {
            if (scalar(@ARGV) eq 2) {
                my $bootstrap = shift(@ARGV);
                my $bootstrap_path = shift(@ARGV);

                if ($bootstrap_path =~ /^([a-zA-Z0-9_\-\.\/]+)\/?$/) {
                    $bootstrap_path = $1;
                    my $bootstrap_object = $db->get_objects("bootstrap", $opt_lookup, $bootstrap)->get_object(0);
                    my $bootstrap_name = $bootstrap_object->name();

                    if (-d $bootstrap_path) {
                        $bootstrap_path = "$bootstrap_path/$bootstrap_name.wwbs";
                    } else {
                        my $dirname = dirname($bootstrap_path);
                        if (! -d $dirname) {
                            &eprint("Parent directory $dirname does not exist!\n");
                            return undef;
                        }
                    }

                    if (-f $bootstrap_path) {
                        if ($term->interactive()) {
                            &wprint("Do you wish to overwrite this file: $bootstrap_path?\n");
                            my $yesno = lc($term->get_input("Yes/No> ", "no", "yes"));
                            if ($yesno ne "y" and $yesno ne "yes") {
                                &nprint("Not exporting '$bootstrap_name'\n");
                                return undef;
                            }
                        }
                    }

                    $bootstrap_object->bootstrap_export($bootstrap_path);

                    $return_count ++;

                } else {
                    &eprint("Destination path contains illegal characters: $bootstrap_path\n");
                    return undef;
                }
            } else {
                &eprint("USAGE: bootstrap export [bootstrap name] [destination]\n");
                return undef;
            }
        } elsif ($command eq "import") {
            if (scalar(@ARGV) >= 1) {
                foreach my $path (@ARGV) {
                    if ($path =~ /^([a-zA-Z0-9\-_\.\/]+)$/) {
                        $path = $1;
                        if (-f $path) {
                            my $name;
                            my $arch;
                            my $objSet;
                            my $obj;
                            if ($opt_name) {
                                $name = $opt_name;
                            } else {
                                $name = basename($path);
                                $name =~ s/\.wwbs$//;
                            }
                            if ($opt_arch) {
                                $arch = $opt_arch;
                            } else {
                                &dprint("Architecture not specified, defaulting the local system architecture\n");
                                (undef, undef, undef, undef, $arch) = POSIX::uname();
                            }
                            $objSet = $db->get_objects("bootstrap", $opt_lookup, $name);

                            if ($objSet->count() > 0) {
                                $obj = $objSet->get_object(0);
                                if ($term->interactive()) {
                                    my $name = $obj->name() || "UNDEF";
                                    &wprint("Do you wish to overwrite '$name' in the Warewulf data store?\n");
                                    my $yesno = lc($term->get_input("Yes/No> ", "no", "yes"));
                                    if ($yesno ne "y" and $yesno ne "yes") {
                                        &nprint("Not exporting '$name'\n");
                                        return undef;
                                    }
                                }
                            } else {
                                &dprint("Creating a new Warewulf bootstrap object\n");
                                $obj = Warewulf::Bootstrap->new();
                                $obj->name($name);
                                $obj->arch($arch);
                                &dprint("Persisting the new Warewulf bootstrap object with name: $name\n");
                                $db->persist($obj);
                            }

                            $obj->bootstrap_import($path);

                            $return_count++;

                        } else {
                            &eprint("Bootstrap not Found: $path\n");
                            return undef;
                        }
                    } else {
                        &eprint("Bootstrap contains illegal characters: $path\n");
                        return undef;
                    }
                }
            } else {
                &eprint("USAGE: bootstrap import [bootstrap path]\n");
                return undef;
            }
        } elsif ($command eq "set") {
            my $persist_count = 0;
            my @changes;

            if (! @ARGV) {
                &eprint("To make changes, you must provide a list of bootstrap to operate on.\n");
                return undef;
            }
            my $bootstrap = shift(@ARGV);

            my $objSet = $db->get_objects("bootstrap", $opt_lookup, $bootstrap);

            if ($opt_name) {
                if ($objSet->count() == 1) {
                    if (uc($opt_name) eq "UNDEF") {
                        &eprint("You must define the name you wish to reference the bootstrap as!\n");
                    } elsif ($opt_name =~ /^([a-zA-Z0-9_\.\-]+)$/) {
                        $opt_name = $1;
                        foreach my $obj ($objSet->get_list()) {
                            my $bootstrapName = $obj->get("name") || "UNDEF";
                            $obj->name($opt_name);
                            &dprint("Setting new name for bootstrap $bootstrapName: $opt_name\n");
                            $persist_count++;
                        }
                        push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "NAME", $opt_name));
                    } else {
                        &eprint("Option 'name' has invalid characters\n");
                        return();
                    }
                } else {
                    &eprint("Can not rename more then 1 bootstrap at a time!\n");
                    return();
                }
            }

            if ($opt_arch) {
               foreach my $o ($objSet->get_list()) {
                    $o->arch($opt_arch);
                    $persist_count++;
                }
                push(@changes, sprintf("%8s: %-20s = %s\n", "SET", "ARCH", $opt_arch));
            }
            if ($term->interactive()) {
                if (! $self->confirm_changes($term, $objSet->count(), "Bootstrap(s)", @changes)) {
                    return undef;
                }
            }

            my $return_count = $db->persist($objSet);
            &iprint("Updated $return_count object(s).\n");

        } else {
            $objSet = $db->get_objects($opt_type || $entity_type, $opt_lookup, &expand_bracket(@ARGV));
            if ($objSet->count() == 0) {
                &wprint("No bootstrap images found\n");
                return undef;
            }

            if ($command eq "delete") {
                my $object_count = $objSet->count();

                if (! @ARGV) {
                    &eprint("To make deletions, you must provide a list of bootstraps to operate on.\n");
                    return undef;
                }

                if ($term->interactive()) {
                    print "Are you sure you want to delete $object_count bootstrap(s):\n\n";
                    foreach my $o ($objSet->get_list()) {
                        printf("     DEL: %-20s = %s\n", "BOOTSTRAP", $o->name());
                    }
                    print "\n";
                    my $yesno = lc($term->get_input("Yes/No> ", "no", "yes"));
                    if ($yesno ne "y" and $yesno ne "yes") {
                        &nprint("No update performed\n");
                        return undef;
                    }
                }
                $return_count = $db->del_object($objSet);
            } elsif ($command eq "list" or $command eq "print") {
                if ($opt_single) {
                    foreach my $obj ($objSet->get_list("name")) {
                        printf("%-32s\n", $obj->name() || "UNDEF");
                    }
                } else {
                    &nprint("BOOTSTRAP NAME            SIZE (M)      ARCH\n");
                    foreach my $obj ($objSet->get_list("name")) {
                        printf("%-25s %-13.1f %s\n",
                            $obj->name() || "UNDEF",
                            $obj->size() ? $obj->size()/(1024*1024) : "0",
                            $obj->arch() || "UNDEF",
                        );
                        $return_count ++;
                    }
                }
            } elsif ($command eq "rebuild" or $command eq "build") {
                foreach my $o ($objSet->get_list("name")) {
                    &dprint("Calling build_local_bootstrap()\n");
                    $o->build_local_bootstrap();
                    $return_count ++;
                }
            } else {
                &eprint("Invalid command: $command\n");
                return undef;
            }
        }
    } else {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return undef;

    }

    # We are done with ARGV, and it was internally modified, so lets reset
    @ARGV = ();

    return $return_count;
}


1;
