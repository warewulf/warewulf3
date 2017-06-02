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
    my $config = Warewulf::Config->new('database.conf');
    my $db_engine = $config->get('database driver') || 'mysql';
    my $plugin_path;
    my $plugin_class;

    if ( substr($db_engine, 0, 1) eq '/' ) {
        if ( ! -f $db_engine ) {
            &eprintf("No database driver at path %s\n", $db_engine);
        }
        elsif ( $db_engine =~ /([^\/]+)\.pm$/ ) {
            $plugin_path = $db_engine;
            $plugin_class = 'Warewulf::DataStore::SQL::' . $1;
            &dprintf("Database driver from module path: %s in %s\n", $plugin_class, $plugin_path);
        }
        else {
            &eprintf("Uninterpretable Perl module path: %s\n", $db_engine);
        }
    }
    else {
        # Search the SQL/ subdirectory for the matching module:
        my @path = bsd_glob(dirname(__FILE__) . '/SQL/' . $db_engine . '*.pm', GLOB_NOCASE);

        if ( scalar(@path) > 0 ) {
            if ( scalar(@path) == 1 ) {
                if ( $path[0] =~ /^((\/.*)\.pm)$/ ) {
                    $plugin_path = $1;
                    $plugin_class = 'Warewulf::DataStore::SQL::' . basename($2);
                    &dprintf("Database driver from module name: %s in %s\n", $plugin_class, $plugin_path);
                }
                else {
                    &eprintf("Uninterpretable Perl module path: %s\n", $path[0]);
                }
            }
            else {
                &eprintf("Multiple matches for driver '%s' ???\n", $db_engine);
            }
        }
        else {
            &eprintf("No database driver: %s\n", $db_engine);
        }
    }
    if ( $plugin_path && $plugin_class ) {
        require $plugin_path;
        return ($plugin_class)->new(@_);
    }
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

