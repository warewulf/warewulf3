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
use Warewulf::DataStore::SQL::MySQL;
use DBI;


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

    if ($db_engine eq "mysql") {
        return(Warewulf::DataStore::SQL::MySQL->new(@_));
    } else {
        &eprint("Could not load DB type: $db_engine\n");
        exit 1;
    }

    return();
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

