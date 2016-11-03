# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Provision::DhcpFactory.pm 168 2011-01-04 01:26:47Z gmk $
#

package Warewulf::Provision::DhcpFactory;

use Warewulf::Util;
use Warewulf::Logger;
use Warewulf::Config;
use File::Basename;
use DBI;


=head1 NAME

Warewulf::Provision::DhcpFactory - DHCP interface

=head1 ABOUT

The Warewulf::Provision::DhcpFactory interface simplies typically used DB calls and operates on
Warewulf::Objects and Warewulf::ObjectSets for simplistically integrating
with native Warewulf code.

=head1 SYNOPSIS

    use Warewulf::Provision::DhcpFactory;

    my $db = Warewulf::Provision::DhcpFactory->new($type);

=item new($type)

Create the object of given type. If no type is passed it will read from the 
configuration file 'provision.conf' and use the paramater 'dhcp server' as
the type.

=cut

sub
new($$)
{
    my $proto = shift;
    my $type = shift;
    my $mod_name;
    my $mod_base = "Warewulf::Provision::Dhcp::";

    if (! $type) {
        &dprint("Checking what DHCP implementation to use\n");
        my $config = Warewulf::Config->new("provision.conf");
        $type = $config->get("dhcp server") || "isc";
    }

    if ($type =~ /^([a-zA-Z0-9\-_\.]+)$/) {
        my $mod_name = ucfirst(lc($1));
        foreach my $path (@INC) {
            if ($path =~/^(\/[a-zA-Z0-9_\-\/\.]+)$/) {
                &dprint("Searching for library at: $path/Warewulf/Provision/Dhcp/$mod_name.pm\n");
                if (-f "$path/Warewulf/Provision/Dhcp/$mod_name.pm") {
                    my $file = "$path/Warewulf/Provision/Dhcp/$mod_name.pm";
                    if ($file =~ /^([a-zA-Z0-9_\-\/\.]+)$/) {
                        my $file_clean = $1;
                        my ($name, $tmp, $keyword);

                        $name = "Warewulf::Provision::Dhcp::". basename($file_clean);
                        $name =~ s/\.pm$//;

                        &dprint("Module load file: $file_clean\n");
                        eval {
                            local $SIG{"__WARN__"} = sub { 1; };
                            require $file_clean;
                        };
                        if ($@) {
                            &wprint("Caught error on module load: $@\n");
                            &wprint("$@\n");
                        } else {
                            &dprint("Module $name loaded successful\n");
                        }

                        $tmp = eval "$name->new()";
                        if ($tmp) {
                            push(@{$self->{"MODULES"}}, $tmp);
                            &dprint("Module load success: Added module $name\n");
                            return($tmp);
                        } else {
                            &wprint("Module load error: Could not invoke $name->new(): $@\n");
                        }
                    } else {
                        &wprint("Module has invalid characters '$file'\n");
                    }
                }
            }
        }
    } else {
        &eprint("DHCP server name contains illegal characters.\n");
    }

    return();
}

=head1 SEE ALSO

Warewulf::Provision::Dhcp

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

