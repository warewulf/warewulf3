# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: SQL.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::DataStore::SQL;

use Warewulf::Util;
use Warewulf::Logger;
use Warewulf::Config;
use DBI;
use File::Basename;
use File::Glob qw(:glob bsd_glob);


=head1 NAME

Warewulf::DataStore::SQL - Database interface

=head1 ABOUT

The Warewulf::DataStore::SQL interface simplies typically used DB calls.

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL;

=item new()

Create the object.

=cut

sub
new($$)
{
    my $proto = shift;
    my $config = Warewulf::Config->new("database.conf");
    my $db_engine = $config->get("database driver") || "mysql";
    
    # What directory holds this module?
    my @path = bsd_glob(dirname(__FILE__) . '/SQL/' . $db_engine . '*.pm', GLOB_NOCASE);
    
    if ( scalar(@path) > 0 ) {
        if ( scalar(@path) == 1 ) {
            if ( $path[0] =~ /(([^.]+)\.pm)/ ) {
                my $path = $1;
                my $class = 'Warewulf::DataStore::SQL::' . basename($2);
                
                require $path;
                return ($class)->new(@_);
            }
        } else {
            &eprint("Multiple matches for driver '$db_engine' ???\n");
            exit 1;
        }
    }
    &eprint("Could not load DB type: $db_engine\n");
    exit 1;
}

=back

=head1 SEE ALSO

Warewulf::DataStore

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

