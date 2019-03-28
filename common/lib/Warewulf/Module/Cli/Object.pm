#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#




package Warewulf::Module::Cli::Object;

use Warewulf::Logger;
use Warewulf::Module::Cli;
use Warewulf::Term;
use Warewulf::DataStore;
use Warewulf::Util;
use Getopt::Long;
use Text::ParseWords;
use JSON::PP;

our @ISA = ('Warewulf::Module::Cli');

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
    $h .= "     object <command> [options] [targets]\n";
    $h .= "\n";
    $h .= "SUMMARY:\n";
    $h .= "     The object command provides an interface for generically manipulating all\n";
    $h .= "     object types within the Warewulf data store.\n";
    $h .= "\n";
    $h .= "COMMANDS:\n";
    $h .= "     modify          Add, delete, and/or set object member variables\n";
    $h .= "     print           Display object(s) and their members\n";
    $h .= "     delete          Completely remove object(s) from the data store\n";
    $h .= "     dump            Recursively dump objects in internal format\n";
    $h .= "     jsondump        Recursively dump objects in json format\n";
    $h .= "     canonicalize    Check and update objects to current standard format\n";
    $h .= "     help            Show usage information\n";
    $h .= "\n";
    $h .= "OPTIONS:\n";
    $h .= "     -l, --lookup    Identify objects by specified property (default: \"name\")\n";
    $h .= "     -t, --type      Only operate on objects of the specified type\n";
    $h .= "     -p, --print     Specify which fields are printed (\":all\" for all)\n";
    $h .= "     -s, --set       Set a member variable (or \"field\")\n";
    $h .= "     -a, --add       Add value(s) to specified member array variable\n";
    $h .= "     -D, --del       Delete value(s) from specified member variable\n";
    $h .= "\n";
    $h .= "EXAMPLES:\n";
    $h .= "     Warewulf> object print -p :all\n";
    $h .= "     Warewulf> object print -p _id,name,_type\n";
    $h .= "\n";
    $h .= "WARNING:  This command is VERY POWERFUL.  It is primarily intended for\n";
    $h .= "developers and power users.  Please use CAREFULLY, if at all.  Data\n";
    $h .= "stores which are corrupted by misuse of this command may not be\n";
    $h .= "recoverable.  USE AT YOUR OWN RISK!\n";
    $h .= "\n";

    return ($h);
}


sub
summary()
{
    my $output;

    $output .= "Generically manipulate all Warewulf data store entries";

    return ($output);
}


sub
complete()
{
    my $self = shift;
    my $opt_lookup = "name";
    my $db = $self->{"DB"};
    my $opt_type;
    my @ret = ("print", "modify", "dump", "help", "delete", "canonicalize");

    if (! $db) {
        return ();
    }

    @ARGV = grep { defined($_) } &quotewords('\s+', 0, @_);

    Getopt::Long::Configure ("bundling", "passthrough");

    GetOptions(
        'l|lookup=s'    => \$opt_lookup,
        't|type=s'      => \$opt_type,
    );

    if (exists($ARGV[1])) {
        if (($ARGV[1] eq "print") || ($ARGV[1] eq "modify") || ($ARGV[1] eq "delete") || ($ARGV[1] eq "canonicalize")) {
            @ret = $db->get_lookups(undef, "name");
        } elsif (($ARGV[1] eq "dump") || ($ARGV[1] eq "jsondump") || ($ARGV[1] eq "help")) {
            @ret = ();
        }
    }
    return @ret;
}




sub
exec()
{
    my $self = shift;
    my $db = $self->{"DB"};
    my $term = Warewulf::Term->new();
    my $command;
    my $opt_lookup = "name";
    my $opt_new;
    my $opt_type;
    my @opt_dump;
    my @opt_set;
    my @opt_add;
    my @opt_del;
    my $opt_obj_delete;
    my $opt_help;
    my @opt_print;
    my $return_count;
    my $objectSet;
    my @objList;
    my @changes;

    @ARGV = &quotewords('\s+', 1, @_);

    Getopt::Long::Configure("bundling", "nopassthrough");
    GetOptions(
        't|type=s'        => \$opt_type,
        'p|print=s'       => \@opt_print,
        's|set=s'         => \@opt_set,
        'a|add=s'         => \@opt_add,
        'D|delete|del=s'  => \@opt_del,
        'l|lookup=s'      => \$opt_lookup,
        'h|help'          => \$opt_help
    );

    $command = shift(@ARGV);

    if (! $db) {
        &eprint("Database object not available!\n");
        return;
    }

    if (! $command) {
        &eprint("You must provide a command!\n\n");
        print $self->help();
        return 0;
    } elsif ($opt_help || $command eq "help") {
        print $self->help();
        return 0;
    }

    if (scalar(@opt_set) || scalar(@opt_add) || scalar(@opt_del)) {
        my %modifiers;
        my @mod_print;

        @opt_print = ("name");
        foreach my $setstring (@opt_set, @opt_add, @opt_del) {
            if ($setstring =~ /^([^=]+)/) {
                my $field = lc($1);

                if (!exists($modifiers{$field})) {
                    push(@mod_print, $field);
                    $modifiers{$field} = 1;
                }
            }
        }
        push(@opt_print, grep { $_ ne "name" } @mod_print);
    } elsif (scalar(@opt_print)) {
        @opt_print = split(",", join(",", @opt_print));
    } else {
        @opt_print = ("name", "_type");
    }

    $objectSet = $db->get_objects($opt_type, $opt_lookup, &expand_bracket(@ARGV));
    if ($objectSet->count() == 0) {
        &wprint("No matching objects found.\n");
        return 0;
    }
    @objList = $objectSet->get_list();

    if ($command eq "dump") {
        for (my $i = 0; $i < $objectSet->count(); $i++) {
            my $o = $objectSet->get_object($i);

            &nprint(&examine_object($o, "Object #$i:  "), "\n\n");
        }
        return 1;
    }

    if ($command eq "jsondump") {
        my $json = JSON::PP->new->allow_nonref;
        $json->convert_blessed(1);
        my @jsondata;
        for (my $i = 0; $i < $objectSet->count(); $i++) {
            my $o = $objectSet->get_object($i);
            push @jsondata, {%$o};
        }
        &nprint($json->encode(\@jsondata),"\n");
        return 1;
    }

    if ($command eq "canonicalize") {
        my $obj_count = $objectSet->count();
        my $count = 0;
        foreach my $o (@objList) {
            # Eventually we should walk @ISA for the object class in question
            $count += $o->canonicalize();
        }
        &nprint("There were $count changes made to $obj_count objects\n");
        if ($count > 0) {
            $db->persist(@objList);
        }
        return 1;
    }
    if ($command eq "modify") {
        foreach my $chg (@opt_set) {
            my ($var, $val) = split('=', $chg, 2);
            my @vals;

            if (! $var || !index('=', $chg)) {
                &eprint("Set directive \"$chg\" must be in the form \"name=[value]\".\n");
                next;
            } elsif (substr($var, 0, 1) eq '_') {
                &eprint("Will not modify private object member \"$var\".\n");
                next;
            }
            @vals = &quotewords(',', 0, $val);
            $val = sprintf("\"%s\"", join("\", \"", @vals));
            foreach my $obj (@objList) {
                push(@changes, sprintf("%8s: %-20s = %s -> %s\n", "SET", $var,
                                       $obj->get($var) || "UNDEF", $val || "UNDEF"));
                $obj->set($var, ((scalar(@vals)) ? (@vals) : (undef)));
            }
        }
        foreach my $chg (@opt_add) {
            my ($var, $val) = split('=', $chg, 2);
            my @vals;

            if (! $var || ! $val) {
                &eprint("Add directive \"$chg\" must be in the form \"name=value\".\n");
                next;
            } elsif (substr($var, 0, 1) eq '_') {
                &eprint("Will not modify private object member \"$var\".\n");
                next;
            }
            @vals = &quotewords(',', 0, $val);
            $val = sprintf("\"%s\"", join("\", \"", @vals));
            foreach my $obj (@objList) {
                $obj->add($var, @vals);
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "ADD", $var, $val));
        }
        foreach my $chg (@opt_del) {
            my ($var, $val) = split('=', $chg, 2);
            my @vals;

            if (! $var) {
                &eprint("Delete directive \"$chg\" must contain a member name.\n");
                next;
            } elsif (substr($var, 0, 1) eq '_') {
                &eprint("Will not modify private object member \"$var\".\n");
                next;
            }
            if (scalar($val)) {
                $val = sprintf("\"%s\"", join("\", \"", &quotewords(',', 0, $val)));
            } else {
                $val = "[ALL]";
            }
            foreach my $obj (@objList) {
                $obj->del($var, @vals);
            }
            push(@changes, sprintf("%8s: %-20s = %s\n", "DEL", $var, $val));
        }
    }

    if (scalar(@opt_print)) {
        if ((scalar(@opt_print) > 1) && ($opt_print[0] ne ":all")) {
            my $string = sprintf("%-26s " x scalar(@opt_print), map {uc($_);} @opt_print);

            &nprint("$string\n", "=" x length($string), "\n");
        }

        foreach my $o ($objectSet->get_list()) {
            if ($opt_print[0] eq ":all") {
                my %objhash = $o->get_hash();
                my $id = (($o->can("id")) ? ($o->id()) : ($o->get("_id")));
                my $type = (($o->can("type")) ? ($o->type()) : ($o->get("_type"))) || "";
                my $name = (($o->can("name")) ? ($o->name()) : ($o->get("name")));

                if (!defined($name)) {
                    $name = "UNDEF";
                } elsif (ref($name) eq "ARRAY") {
                    $name = $name->[0];
                }
                if ($type) {
                    $name = "$type $name";
                }
                &nprintf("#### %s %s#\n", $name, "#" x (72 - length($name)));
                foreach my $h (&sort_members(keys(%objhash))) {
                    my $val;

                    if (ref($objhash{$h}) eq "ARRAY") {
                        $val = join(',', sort(@{$objhash{$h}}));
                    } elsif (ref($objhash{$h}) =~ /^Warewulf::(.*)$/) {
                        my $subtype = $1;
                        my $subobj = $objhash{$h};

                        if ($subtype eq "ObjectSet") {
                            printf("%8s: %-10s = %s\n", $id, $h, $subtype);
                            foreach my $so ($subobj->get_list()) {
                                my %sohash = $so->get_hash();
                                my $soid = (($so->can("id")) ? ($so->id()) : ($so->get("_id")));
                                my $soname = (($so->can("name")) ? ($so->name()) : ($so->get("name")));

                                if (!defined($soid)) {
                                    $soid = -1;
                                }
                                if (!defined($soname)) {
                                    $soname = (($soid > 0) ? ($soid) : ("???"));
                                }
                                foreach my $soh (&sort_members(keys(%sohash))) {
                                    $soh = uc($soh);
                                    printf("%12s%-25s = %s\n", "", "$h.$soname.$soh", $sohash{$soh});
                                }
                            }
                            next;
                        }
                        $val = "Subobject ";
                        if ($subobj->can("name")) {
                            $val .= ($subobj->name() || "[unnamed]") . " ($subtype)";
                        } elsif ($subobj->can("get")) {
                            $val .= ($subobj->get("name") || "[unnamed]") . " ($subtype)";
                        } else {
                            $val .= "$subtype";
                        }
                    } else {
                        $val = $objhash{$h};
                    }
                    if ($h =~ /^_/) {
                        &iprintf("%8s: %-10s = %s\n", $id, $h, $val);
                    } else {
                        printf("%8s: %-10s = %s\n", $id, $h, $val);
                    }
                }
            } else {
                my @values;

                foreach my $field (@opt_print) {
                    my ($cref, $val);
                    my @vals;

                    $cref = $o->can($field);
                    if (ref($cref) eq "CODE") {
                        @vals = $cref->($o);
                    } else {
                        @vals = $o->get($field);
                    }

                    if (scalar(@vals) > 1) {
                        $val = \@vals;
                    } else {
                        $val = $vals[0];
                    }

                    if (!defined($val)) {
                        $val = "UNDEF";
                    } elsif (ref($val) eq "ARRAY") {
                        $val = ((scalar(@{$val})) ? (join(',', sort(@{$val}))) : ("UNDEF"));
                    } elsif (ref($val) =~ /^Warewulf::(.*)$/) {
                        my $subtype = $1;
                        my $subobj = $objhash{$h};

                        if ($subobj->can("name")) {
                            $val = $subobj->name() || $subtype;
                        } elsif ($subobj->can("get")) {
                            $val = $subobj->get("name") || $subtype;
                        } else {
                            $val = $subtype;
                        }
                    }
                    push @values, ((defined($val)) ? ($val) : ("UNDEF"));
                }
                if (scalar(@values)) {
                    printf("%-26s " x (scalar(@values)) ."\n", @values);
                } else {
                    printf("No values to print!\n");
                    return 0;
                }
            }
        }
    }

    if ($command eq "delete") {
        print "\n";
        if ($term->yesno(sprintf("About to delete the above %d objects.\n", $objectSet->count()))) {
            $return_count = $db->del_object($objectSet);
            &nprint("Deleted $return_count object(s).\n");
        } else {
            &nprint("No objects deleted.\n");
            return 0;
        }
    } elsif ($command eq "modify") {
        print "\n";
        if ($self->confirm_changes($term, scalar(@objList), "object(s)", @changes)) {
            $return_count = $db->persist($objectSet);
            &iprint("Updated $return_count object(s).\n");
        }
    }

    # We are done with ARGV, and it was internally modified, so let's reset
    @ARGV = ();

    return $return_count;
}

sub
sort_members()
{
    return sort {
        my ($va, $vb) = (0, 0);

        if ($a eq "_ID") {
            $va = -2;
        } elsif ($a eq "NAME") {
            $va = -1;
        } else {
            $va = 0;
        }
        if ($b eq "_ID") {
            $vb = -2;
        } elsif ($b eq "NAME") {
            $vb = -1;
        } else {
            $vb = 0;
        }
        if ($va || $vb) {
            return ($va <=> $vb);
        } else {
            return ($a cmp $b);
        }
    } @_;
}

1;
