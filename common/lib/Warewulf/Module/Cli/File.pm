#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#

package Warewulf::Module::Cli::File;

use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::File;
use Warewulf::DSO::File;
use Getopt::Long;
use File::Basename;
use File::Path;
use Text::ParseWords;
use Digest::MD5 qw(md5_hex);
use POSIX;

our @ISA = ('Warewulf::Module::Cli');

my $entity_type = "file";

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self->init();
}

sub
init()
{
    my ($self) = @_;

    return $self;
}

sub
help()
{
    my $h;

    $h .= "USAGE:\n";
    $h .= "     file <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     The file command is used for manipulating file objects.  It allows you to\n";
    $h .= "     import, export, create, and modify files within the Warewulf data store.\n";
    $h .= "     File objects may be used to supply files to nodes at provision time,\n";
    $h .= "     dynamically create files or scripts based on Warewulf data and more.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "     import             Import a file into a file object\n";
    $h .= "     export             Export file object(s)\n";
    $h .= "     edit               Edit the file in the data store directly\n";
    $h .= "     new                Create a new file in the data store\n";
    $h .= "     set                Set file attributes/metadata\n";
    $h .= "     show               Show the contents of a file\n";
    $h .= "     list               List a summary of imported file(s)\n";
    $h .= "     print              Print all file attributes\n";
    $h .= "     (re)sync           Sync the data of a file object with its source(s)\n";
    $h .= "     delete             Remove a node configuration from the data store\n";
    $h .= "     help               Show usage information\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "     -l, --lookup       Identify files by specified property (default: \"name\")\n";
    $h .= "     -p, --program      What external program should be used (edit/show)\n";
    $h .= "     -D, --path         Set destination (i.e., output) path for this file\n";
    $h .= "     -o, --origin       Set origin (i.e., input) path for this file\n";
    $h .= "     -m, --mode         Set permission attribute for this file\n";
    $h .= "     -u, --uid          Set the UID for this file\n";
    $h .= "     -g, --gid          Set the GID for this file\n";
    $h .= "     -n, --name         Set the reference name for this file (not path!)\n";
    $h .= "         --interpreter  Set the interpreter name to parse this file\n";
    $h .= "\n";
    $h .= "NOTE:  Use \"UNDEF\" to erase the current contents of a given field.\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "     Warewulf> file import /path/to/file/to/import --name=hosts-file\n";
    $h .= "     Warewulf> file import /path/to/file/to/import/with/given-name\n";
    $h .= "     Warewulf> file edit given-name\n";
    $h .= "     Warewulf> file set given-name --origin=UNDEF --mode=0700\n";
    $h .= "     Warewulf> file set hosts-file --path=/etc/hosts --mode=0644 --uid=0\n";
    $h .= "     Warewulf> file list\n";
    $h .= "     Warewulf> file delete name123 given-name\n";
    $h .= "\n";

    return $h;
}


sub
summary()
{
    my $output;

    $output .= "Manage files within the Warewulf data store";

    return $output;
}


sub
complete()
{
    my $self = shift;
    my $db = Warewulf::DataStore->new();
    my @ret;


    @ARGV = ();

    foreach (&quotewords('\s+', 0, @_)) {
        if (defined($_)) {
            push(@ARGV, $_);
        }
    }

    if (exists($ARGV[1]) and ($ARGV[1] eq "print" or $ARGV[1] eq "new" or $ARGV[1] eq "set" or $ARGV[1] eq "list" or $ARGV[1] eq "edit" or $ARGV[1] eq "delete" or $ARGV[1] eq "show")) {
        @ret = $db->get_lookups($entity_type, "name");
    } else {
        @ret = ("print", "edit", "new", "set", "delete", "list", "show");
    }

    @ARGV = ();

    return @ret;
}

sub
format()
{
    my $data = shift;

    if ($data and length($data) > 0) {
        my ($interpreter) = split(/\n/, $data);

        if ($interpreter =~ /^#!\/.+\/perl\s*/) {
            return("perl");
        } elsif ($interpreter =~ /^#!\/.+\/sh\s*/) {
            return("shell");
        } elsif ($interpreter =~ /^#!\/.+\/bash\s*/) {
            return("bash");
        } elsif ($interpreter =~ /^#!\/.+\/python\s*/) {
            return("python");
        } elsif ($interpreter =~ /^#!\/.+\/t?csh\s*/) {
            return("csh");
        } else {
            return("data");
        }
    }

    return;
}

sub
exec()
{
    my $self = shift;
    my $db = Warewulf::DataStore->new();
    my $term = Warewulf::Term->new();
    my $command;
    my $opt_lookup = "name";
    my $opt_name;
    my $opt_program;
    my $opt_path;
    my $opt_mode;
    my $opt_uid;
    my $opt_gid;
    my $opt_interpreter;
    my @opt_origin;

    @ARGV = ();
    push(@ARGV, @_);

    Getopt::Long::Configure ("bundling", "nopassthrough");

    GetOptions(
        'n|name=s'      => \$opt_name,
        'p|program=s'   => \$opt_program,
        'l|lookup=s'    => \$opt_lookup,
        'o|origin=s'    => \@opt_origin,
        'source=s'      => \@opt_origin,
        'path=s'        => \$opt_path,
        'D|dest=s'      => \$opt_path,
        'm|mode=s'      => \$opt_mode,
        'u|uid=s'       => \$opt_uid,
        'g|gid=s'       => \$opt_gid,
        'interpreter=s' => \$opt_interpreter,
    );
    if (! $opt_program) {
        if (exists($ENV{"EDITOR"})) {
            $opt_program = $ENV{"EDITOR"};
        }
    }
    if ($opt_program) {
        if ($opt_program =~ /^\"?([[:print:]]+)\"?$/) {
            $opt_program = $1;
        } else {
            &eprint("Invalid program name.  Using built-in default.\n");
            undef $opt_program;
        }
    }

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not available!\n");
        return undef;
    }

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return undef;
    } elsif ($command eq "help") {
        print $self->help();
        return 1;
    }

    # Import and export commands are done separately because they take a
    # slightly different argument syntax.
    if ($command eq "export") {
        if (scalar(@ARGV) >= 2) {
            my $path = pop(@ARGV);
            my $objSet = $db->get_objects("file", $opt_lookup, &expand_bracket(@ARGV));
            my $ocount = $objSet->count();
            my $fname = "";

            if ($ocount == 0) {
                &nprint("File(s) not found\n");
                return undef;
            }

            if (! -d $path) {
                if ($ocount == 1) {
                    $path = dirname($path);
                    $fname = basename($path);
                    if (! -d $path) {
                        &eprint("Destination directory \"$path\" does not exist.\n");
                        return undef;
                    }
                } else {
                    &eprint("Exporting multiple files, and destination \"$path\" is not a directory.\n");
                    return undef;
                }
            }

            foreach my $obj ($objSet->get_list()) {
                my $name = $obj->name();
                my $target = "$path/" . (($fname) ? ($fname) : ($name));

                if (-f $target) {
                    if (! $term->yesno("Overwrite $target?")) {
                        &nprint("Not exporting \"$name\"\n");
                        next;
                    }
                }
                &iprint("Exporting file object \"$name\" to \"$target\"\n");
                $obj->file_export($target);
            }
        } else {
            &eprint("USAGE: file export [file object names...] [destination]\n");
        }

    } elsif ($command eq "import") {
        if (!scalar(@ARGV) && scalar(@opt_origin)) {
            push(@ARGV, @opt_origin);
        }
        if (!scalar(@ARGV)) {
            &eprint("No files found to import.  Nothing to do!\n");
            return undef;
        }
        foreach my $path (@ARGV) {
            my @statinfo;

            @statinfo = lstat($path);
            if (-e _) {
                my ($mode, $uid, $gid) = @statinfo[(2, 4, 5)];
                my $name = (($opt_name) ? ($opt_name) : (basename($path)));
                my $objSet;
                my $obj;

                $objSet = $db->get_objects("file", $opt_lookup, $name);

                if ($objSet->count() > 0) {
                    my $oname;

                    $obj = $objSet->get_object(0);
                    $oname = $obj->name() || "UNDEF";
                    if (! $term->yesno("Overwrite existing file object \"$oname\" in the data store?")) {
                        &nprint("Not importing \"$name\"\n");
                        return undef;
                    }
                } else {
                    &dprint("Creating a new Warewulf file object\n");
                    $obj = Warewulf::File->new();
                    $obj->name($name);
                    &dprint("Persisting the new Warewulf file object with name: $name\n");
                    $db->persist($obj);
                }
                $obj->file_import($path);
                $obj->mode((defined($opt_mode)) ? (oct($opt_mode)) : ($mode));
                $obj->uid((defined($opt_uid)) ? ($opt_uid) : ($uid));
                $obj->gid((defined($opt_gid)) ? ($opt_gid) : ($gid));
                $obj->path((defined($opt_path)) ? ($opt_path) : ($path));
                $obj->origin((scalar(@opt_origin) ? (split(",", join(",", @opt_origin))) : ($path)));
                $db->persist($obj);
            } else {
                &eprintf("\"$path\" not found -- %s\n", "$!" || "not a regular file");
            }
        }
    } else {
        my $objSet;

        if ($command eq "new") {
            $objSet = Warewulf::ObjectSet->new();
            foreach my $string (&expand_bracket(@ARGV)) {
                my $obj;

                $obj = Warewulf::File->new();
                $obj->name($string);
                $objSet->add($obj);
                $persist_count++;
                push(@changes, sprintf("%8s: %-20s = %s\n", "NEW", "FILE", $string));
            }
            $db->persist($objSet);
        } else {
            $objSet = $db->get_objects($opt_type || $entity_type, $opt_lookup, &expand_bracket(@ARGV));
        }

        if ($objSet->count() == 0) {
            &nprint("No objects found\n");
            return undef;
        }

        if ($command eq "delete") {
            my $object_count = $objSet->count();

            if (! @ARGV) {
                &eprint("To make deletions, you must provide a list of files to operate on.\n");
                return undef;
            }

            if ($term->interactive()) {
                foreach my $o ($objSet->get_list()) {
                    printf("%8s: %-20s = %s\n", "DEL", "FILE", $o->name());
                }
                print "\n";
                if (!$term->yesno("Are you sure you want to delete $object_count files(s):\n\n")) {
                    &nprint("No update performed\n");
                    return undef;
                }
            }
            $db->del_object($objSet);

        } elsif ($command eq "edit") {
            my $program = $opt_program || "/bin/vi";

            if ($objSet->count() == 0) {
                my $rand = &rand_string("16");
                my $tmpfile = "/tmp/wwsh.$rand";
                my $name;

                if ($opt_name) {
                    $name = $opt_name;
                } else {
                    $name = shift(@ARGV);
                }
                &dprint("Creating a new Warewulf file object\n");
                $obj = Warewulf::File->new();
                $obj->name($name);
                &dprint("Persisting the new Warewulf file object with name: $name\n");
                $db->persist($obj);
                $objSet->add($obj);
            }

            if ($objSet->count() == 1) {
                my $obj = $objSet->get_object(0);
                my $rand = &rand_string("16");
                my $tmpfile = "/tmp/wwsh.$rand";
                my ($old_csum, $new_csum);

                $obj->file_export($tmpfile);
                $old_csum = $obj->checksum();
                &dprint("Running command: $program $tmpfile\n");
                if (system($program, $tmpfile) == 0) {
                    $new_csum = digest_file_hex_md5($tmpfile);
                    if ($old_csum ne $new_csum) {
                        $obj->file_import($tmpfile);
                        unlink($tmpfile);
                    } else {
                        &nprint("File unchanged.  Not updating data store.\n");
                    }
                } else {
                    &iprint("Command \"$program\" failed.  Not updating data store.\n");
                }
            } else {
                &eprint("Edit only one file object at a time.\n");
            }

        } elsif ($command eq "set" or $command eq "new") {
            my $persist_count = 0;
            my @changes;
            my @objlist;

            if (! @ARGV) {
                &eprint("To make changes, you must provide a list of files to operate on.\n");
                return undef;
            }

            $object_count = $objSet->count();
            @objlist = $objSet->get_list();

            ### Set each member if supplied.

            # Interpreter
            $self->set_file_member("interpreter", qr/^([a-zA-Z0-9\-_\/\.]+|UNDEF)$/,
                                   $opt_interpreter, \$persist_count, \@changes,
                                   \@objlist);
            # Path
            $self->set_file_member("path", qr/^([a-zA-Z0-9\-_\/\.]+|UNDEF)$/, $opt_path,
                                   \$persist_count, \@changes, \@objlist);
            # Mode
            $self->set_file_member("mode", qr/^(\d+|UNDEF)$/, $opt_mode,
                                   \$persist_count, \@changes, \@objlist,
                                   "must be in octal format (e.g., 0644)");
            # UID
            $self->set_file_member("uid", qr/^(\d+|UNDEF)$/, $opt_uid, \$persist_count,
                                   \@changes, \@objlist, "must be in numeric format");
            # GID
            $self->set_file_member("gid", qr/^(\d+|UNDEF)$/, $opt_gid, \$persist_count,
                                   \@changes, \@objlist, "must be in numeric format");
            # Origin(s)
            $self->set_file_member("origin", qr/^([a-zA-Z0-9\-_\.\/,\s\|\;]+|UNDEF)$/,
                                   ((scalar(@opt_origin)) ? (join(',', @opt_origin)) : (undef)),
                                   \$persist_count, \@changes, \@objlist);
            if ($opt_name) {
                $self->set_file_member("name", qr/^([a-zA-Z0-9\-_\.\ ]+|UNDEF)$/, $opt_name,
                                   \$persist_count, \@changes, \@objlist);
            }

            # Then persist.
            if ($persist_count > 0) {
                if ($self->confirm_changes($term, $objSet->count(), "file(s)", @changes)) {
                    $return_count = $db->persist($objSet);
                    &iprint("Updated $return_count object(s).\n");
                }
            }

        } elsif ($command eq "show") {
            foreach my $obj ($objSet->get_list()) {
                my $rand = &rand_string("16");
                my $tmpfile = "/tmp/wwsh.$rand";

                $obj->file_export($tmpfile);

                if (system("/bin/cat", $tmpfile) == 0) {
                    unlink($tmpfile);
                } else {
                    &eprint("Unable to cat $tmpfile\n");
                }

            }

        } elsif ($command eq "sync" or $command eq "resync") {
            foreach my $obj ($objSet->get_list("name")) {
                my $orig = $obj->origin() || "UNDEF";

                if (scalar(@ARGV) && ($orig eq "UNDEF") && ($obj->name() ne "dynamic_hosts")) {
                    &nprintf("%-16s :: No ORIGIN defined\n", $obj->name());
                }
                $obj->sync();
            }
        } elsif ($command eq "list" or $command eq "ls") {
            #&nprint("NAME               FORMAT       SIZE(K)  FILE PATH\n");
            #&nprint("================================================================================\n");
            &iprintf("%-16s  %10s %s %-16s %9s %s\n",
                     "NAME", "PERMS", "O", "USER GROUP", "SIZE", "DEST");
            foreach my $obj ($objSet->get_list("name")) {
                my $perms = "-";
                my $user_group = getpwuid($obj->uid() || 0) . ' ' . getgrgid($obj->gid() || 0);
                my @o = $obj->origin();

                printf("%-24s: %10s %-3d %-16s %9d %s\n",
                       $obj->name(),
                       $obj->modestring(),
                       scalar(@o),
                       $user_group,
                       $obj->size() || 0,
                       $obj->path() || "",
                    );
            }
        } elsif ($command eq "print") {
            foreach my $obj ($objSet->get_list("name")) {
                my $name = $obj->get("name") || "UNDEF";
                &nprintf("#### %s %s#\n", $name, '#' x (72 - length($name)));
                printf("%-16s: %-16s = %s\n", $name, "ID", ($obj->id() || "ERROR"));
                printf("%-16s: %-16s = %s\n", $name, "NAME", ($obj->name() || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "PATH", ($obj->path() || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "ORIGIN", (join(",", ($obj->origin())) || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "FORMAT", ($obj->format() || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "CHECKSUM", ($obj->checksum() || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "INTERPRETER", ($obj->interpreter() || "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "SIZE", ($obj->size() || "0"));
                printf("%-16s: %-16s = %s\n", $name, "MODE", ($obj->mode() ? sprintf("%04o", $obj->mode()) : "UNDEF"));
                printf("%-16s: %-16s = %s\n", $name, "UID", $obj->uid());
                printf("%-16s: %-16s = %s\n", $name, "GID", $obj->gid());
            }
        } else {
            &eprint("Invalid command: $command\n");
        }
    }

    return 1;
}


# Internal method
sub
set_file_member()
{
    my ($self, $field, $match, $val, $chgcnt, $chglist, $objlist, $errmsg) = @_;
    my $count = 0;

    if (!defined($val) || !scalar(@{$objlist})) {
        return 0;
    } elsif ($val =~ $match) {
        $val = $1;

        if ($val eq "UNDEF") {
            $val = undef;
        } elsif ($field eq "origin") {
            my @tmp = split(',', $val);
            $val = \@tmp;
        } elsif ($field eq "mode") {
            $val = oct($val);
        }
        foreach my $obj (@{$objlist}) {
            my $cref;

            $cref = $obj->can($field);
            if ($cref && (ref($cref) eq "CODE")) {
                $cref->($obj, (defined($val) && ref($val) eq "ARRAY") ? (@{$val}) : ($val));
                ${$chgcnt}++;
                $count++;
            } else {
                &eprint("Invalid object $obj has no $field method ($cref)\n");
            }
        }
        if ($count) {
            if (defined($val)) {
                if (ref($val) eq "ARRAY") {
                    $val = join(',', @{$val});
                } elsif ($field eq "mode") {
                    $val = sprintf("%04o", $val);
                }
                push @{$chglist}, sprintf("%8s: %-20s = %s\n", "SET", uc($field), $val);
            } else {
                push @{$chglist}, sprintf("%8s: %-20s\n", "UNDEF", uc($field));
            }
            return 1;
        } else {
            &wprint("No objects changed.\n");
        }
    } else {
        my $tc_field;

        if (($field eq "uid") || ($field eq "gid")) {
            # Don't title-case acronyms.
            $tc_field = uc($field);
        } else {
            $tc_field = ucfirst($field);
        }
        &eprintf("$tc_field %s.\n", (($errmsg) ? ($errmsg) : ("contains illegal characters")));
        return undef;
    }
}

1;

# vim:filetype=perl:syntax=perl:expandtab:ts=4:sw=4:
