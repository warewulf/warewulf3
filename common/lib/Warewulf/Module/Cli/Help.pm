

package Warewulf::Module::Cli::Help;

use Warewulf::Logger;
use Warewulf::ModuleLoader;

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
complete()
{
    my $modules = Warewulf::ModuleLoader->new("Cli");
    my @ret;

    foreach my $mod ($modules->list()) {
        push(@ret, $mod->keyword());
    }

    return(@ret);
}

sub
exec()
{
    my ($self, $target) = @_;
    my $modules = Warewulf::ModuleLoader->new("Cli");
    my %keywords;
    my $summary;

    if ($target) {
        my %usage;
        my $printed;
        my $options_printed;
        my $examples_printed;
        &dprint("Gathering help topics for: $target\n");
        foreach my $mod (sort $modules->list($target)) {
            my $ref = ref($mod);
            &dprint("Calling on module: $mod->help()\n");
            if ($mod->can("help")) {
                &iprint("$ref:\n");
                my $help = $mod->help();
                chomp($help);
                &dprint("Calling $mod->help()\n");
                print $help ."\n\n";
                $printed = 1;
            }
        }
        if (! $printed) {
            &eprint("This module has no help methods defined.\n");
            return undef;
        }
    } else {
        my $last_keyword = "";
        print "Warewulf command line shell interface\n";
        print "\n";
        print "Welcome to the Warewulf shell interface. This application allows you\n";
        print "to interact with the Warewulf backend database and modules via a\n";
        print "single interface.\n";
        print "\n";

        foreach my $mod (sort $modules->list()) {
            if ($mod->can("summary")) {
                if ($mod->summary()) {
                    my $keyword = $mod->keyword();
                    if ($keyword eq $last_keyword) {
                        printf "  %-17s", "";
                    } else {
                        printf "  %-17s", $mod->keyword();
                        $last_keyword = $keyword;
                    }
                    print $mod->summary();
                }
                print "\n";
            }
        }
        print "\n";
    }

    return 1;
}


1;
