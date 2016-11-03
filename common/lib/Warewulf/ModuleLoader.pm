# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: ModuleLoader.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::ModuleLoader;

use Warewulf::Util;
use Warewulf::Logger;
use File::Basename;


=head1 NAME

Warewulf::ModuleLoader - Dynamically load modules by type

=head1 SYNOPSIS

    use Warewulf::ModuleLoader;

    my $obj = Warewulf::ModuleLoader->new($type);

=head1 DESCRIPTION

This object is responsible for dynamically loading a particular type
of Warewulf modules (given by the parameter to the new() constructor).

=head1 METHODS

=over 4

=item new($type)

Creates the ModuleLoader object, loads all modules of type $type, and
returns the resultant object.  The type will be something like "Cli"
and represents a subdirectory of a Warewulf module tree.

=cut

sub
new($)
{
    my $proto = shift;
    my $type = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %loaded;

    bless($self, $class);

    if (exists($ENV{"WWMODPATH"})) {
        if ($ENV{"WWMODPATH"} =~ /^([a-zA-Z0-9_\-\/\.]+)$/) {
            push(@INC, $1);
            &dprint("WWMODPATH:  Adding $1 to \@INC\n");
        } else {
            &eprint("WWMODPATH is tainted!\n");
        }
    }

    if (!exists($self->{"MODULES"})) {
        foreach my $path (@INC) {
            if ($path =~/^(\/[a-zA-Z0-9_\-\/\.]+)$/) {
                &dprint("Module load path:  $path\n");
                foreach my $file (glob("$path/Warewulf/Module/$type/*.pm")) {
                    if ($file =~ /^([a-zA-Z0-9_\-\/\.]+)$/) {
                        my $file_clean = $1;
                        my ($name, $tmp, $keyword);

                        $name = "Warewulf::Module::${type}::" . basename($file_clean);
                        $name =~ s/\.pm$//;

                        if (!exists($loaded{"$name"})) {
                            &dprint("Module load file:  $file_clean\n");
                            eval {
                                require $file_clean;
                            };
                            if ($@) {
                                &wprint("Caught error on module load:  $@\n");
                            }

                            $tmp = eval "$name->new()";
                            if ($tmp) {
                                push(@{$self->{"MODULES"}}, $tmp);
                                &dprint("Module load success:  Added module $name\n");
                                $loaded{"$name"} = $file;
                            } else {
                                &wprint("Module load error:  Could not invoke $name->new():  $@\n");
                            }
                        } else {
                            &dprint("Module $name ($loaded{$name}) already loaded\n");
                        }
                    } else {
                        &wprint("Module has invalid characters '$file'\n");
                    }
                }
            } else {
                &eprint("\@INC path '$path' is invalid!\n");
            }
        }
    }

    return $self;
}

=item list([$keyword])

Returns a list of references to loaded modules which own the keyword
$keyword.  If $keyword is omitted, returns all modules loaded.

=cut

sub
list($$)
{
    my ($self, $keyword) = @_;
    my @ret;

    if ($keyword) {
        &dprint("ModuleLoader::list():  Looking for keyword \"$keyword\"\n");
        if (exists($self->{"MODULES"})) {
            foreach my $obj (@{$self->{"MODULES"}}) {
                if ($obj->keyword() eq $keyword) {
                    &dprint("Found object $obj\n");
                    push(@ret, $obj);
                }
            }
        }
    } else {
        &dprint("Returning all modules\n");
        if (exists($self->{"MODULES"})) {
            @ret = @{$self->{"MODULES"}};
        }
    }

    return @ret;
}

=back

=head1 SEE ALSO

Warewulf::Module

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

