# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: MySQL.pm 62 2010-11-11 16:01:03Z gmk $
#

package Warewulf::DataStore::SQL::MySQL;

use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::DSO;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::EventHandler;
use DBI;

# We subclass the SQL base class:
use parent 'Warewulf::DataStore::SQL::BaseClass';

=head1 NAME

Warewulf::DataStore::SQL::MySQL - MySQL Database interface to Warewulf

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::MySQL;

=head1 DESCRIPTION

    This class should not be instantiated directly.  It is intended to be
    treated as an opaque implementation of the DB interface.

    This class creates a persistant singleton for the application runtime
    which will maintain a consistant database connection from the time that
    the object is constructed.

    Documentation for each function should be found in the top level
    Warewulf::DataStore documentation. Any implementation specific documentation
    can be found here.

=cut


sub
init()
{
    my $self = shift;
    my ($config, $config_root) = @_;

    # Only initialize once:
    if ($self && exists($self->{"DBH"}) && $self->{"DBH"}) {
        &dprint("DB Singleton exists, not going to initialize\n");
        return $self;
    }

    $self = $self->SUPER::init(@_);
    if ( $self ) {
        if ( ! exists($self->{"DATABASE_CHUNK_SIZE"}) ) {
            #
            # If no explicit chunk size was provided, then we check to see
            # if an optimization mode was provided.  Valid modes are
            #
            #   storage       chunk size based on innodb page size
            #   network       chunk size based on max_allowed_packet
            #
            # with 'network' being the default.
            #
            my $opt_mode = $config->get("database chunk optimization");
            my $chunk_size;

            if ( ! $opt_mode || $opt_mode eq 'network' ) {
                # Another choice -- albeit one that may not remain consistent during usage of the
                # database -- is to use the server's maximum _communications_ packet size.  Basically,
                # this will produce a chunk size that will be delivered in optimal fashion between
                # client and server.
                #
                # Dropping 768 KB off the max_allowed_packet size was a recommended behavior
                # but should probably make the behavior less optimal.
                (undef, $chunk_size) =  $self->{"DBH"}->selectrow_array("show variables LIKE 'max_allowed_packet'");
                &dprint("max_allowed_packet: $chunk_size\n");
                #&dprint("Returning max_allowed_packet - 786432\n");
                #if ( $chunk_size > 786432 ) {
                #    $chunk_size -= 786432;
                #}
                $self->{"DATABASE_CHUNK_SIZE"} = $chunk_size;
            }
            elsif ( $opt_mode eq 'storage' ) {
                # The InnoDB engine documentation states:
                #
                #   The maximum row length is slightly less than half a database page for 4KB,
                #   8KB, 16KB, and 32KB innodb_page_size settings. For example, the maximum row
                #   length is slightly less than 8KB for the default 16KB InnoDB page size. For
                #   64KB pages, the maximum row length is slightly less than 16KB.
                #
                # So knowing the value of innodb_page_size, a storage-optimized choice of chunk
                # size might be calculated as:
                #
                #    max_row_size < (innodb_page_size / 6) + 16/3
                #
                # With each row having two integer object ids (8 bytes) and a long blob (L + 4
                # bytes), we could say the following equation satisfies that inequality:
                #
                #    chunk_size = floor((1024 B / KB) * 0.95 * ((innodb_page_size / 6 KB) + 16/3))
                #
                (undef, $chunk_size) =  $self->{"DBH"}->selectrow_array("show variables LIKE 'innodb_page_size'");
                &dprint("innodb_page_size: $chunk_size KB\n");
                $self->{"DATABASE_CHUNK_SIZE"} = int( 972.8 * (($chunk_size / 6144.0) + (16.0 / 3.0)) );
            }
            else {
                &wprint("invalid database chunk optimization mode: $opt_mode\n");
                return undef;
            }
        }
    }

    return $self;
}


=item open_database_handle_impl

Open a connection to the database; this should be overridden by each
subclass.

=cut

sub
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_user, $db_pass) = @_;
    my $dbh;

    $dbh = DBI->connect_cached("DBI:mysql:database=$db_name;host=$db_server", $db_user, $db_pass);
    if ( $dbh ) {
        $dbh->{"mysql_auto_reconnect"} = 1;
    }
    return $dbh;
}


=item get_objects_build_query_impl($type, $field, $params, $val1, $val2, $val3);

Build the object retrieval query, returning any arguments to DBI execute()
in the array referenced by the third argument (e.g. @$params).

=cut

sub
get_objects_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;

    my @query_opts;

    if ($type) {
        push(@query_opts, 'datastore.type = '. $self->{"DBH"}->quote($type));
    }
    if ($field) {
        if (uc($field) eq "ID" or uc($field) eq "_ID") {
            push(@query_opts, 'datastore.id IN ('. join(',', map { $self->{"DBH"}->quote($_) } @strings). ')');
            @strings = ();
        } else {
            push(@query_opts, '(lookup.field = '. $self->{"DBH"}->quote(uc($field)) .' OR lookup.field = '. $self->{"DBH"}->quote(uc('_'. $field)) .')');
        }
    }

    if (@strings) {
        my @in_opts;
        my @like_opts;
        my @regexp_opts;
        my @string_query;
        foreach my $s (@strings) {
            if ( $s =~ /^\/(.+)\/$/ ) {
                push(@regexp_opts, $1);
            } elsif ($s =~ /[\*\?]/) {
                $s =~ s/\*/\%/g;
                $s =~ s/\?/\_/g;
                push(@like_opts, 'lookup.value LIKE '. $self->{"DBH"}->quote($s));
            } else {
                push(@in_opts, $self->{"DBH"}->quote($s));
            }
        }
        if (@in_opts) {
            push(@string_query, 'lookup.value IN ('. join(',', @in_opts). ')');
        }
        if (@like_opts) {
            push(@string_query, join(" OR ", @like_opts));
        }
        if (@regexp_opts) {
            push(@string_query, 'lookup.value REGEXP '. $self->{"DBH"}->quote('^('. join('|', @regexp_opts) .'$)'));
        }

        if (@string_query) {
            push(@query_opts, '(' . join(' OR ', @string_query) . ')');
        }
    }

    my $sql_query = <<'END_OF_SQL';
        SELECT
            datastore.id AS id,
            datastore.type AS type,
            UNIX_TIMESTAMP(datastore.timestamp) AS timestamp,
            datastore.serialized AS serialized
          FROM datastore
          LEFT JOIN lookup ON lookup.object_id = datastore.id
END_OF_SQL
    if (@query_opts) {
        $sql_query .= ' WHERE '. join(' AND ', @query_opts);
    }
    $sql_query .= ' GROUP BY datastore.id';

    return $sql_query;
}


=item get_lookups_build_query_impl($type, $field, $val1, $val2, $val3);

Build the MySQL query for key-value lookups.

=cut

sub
get_lookups_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;
    my @query_opts;

    if ($type) {
        push(@query_opts, 'datastore.type = '. $self->{"DBH"}->quote($type));
    }
    if ($field) {
        push(@query_opts, 'lookup.field = '. $self->{"DBH"}->quote(uc($field)));
    }
    if (@strings) {
        push(@query_opts, 'lookup.value IN ('. join(',', map { $self->{"DBH"}->quote($_) } @strings). ')');
    }
    push(@query_opts, "lookup.field != 'ID'");

    my $sql_query = <<'END_OF_SQL';
        SELECT
            lookup.value AS value
          FROM lookup
          LEFT JOIN datastore ON lookup.object_id = datastore.id
END_OF_SQL
    if (@query_opts) {
        $sql_query .= ' WHERE '. join(' AND ', @query_opts);
    }
    $sql_query .= ' GROUP BY lookup.value';

    return $sql_query;
}


sub
allocate_object_impl()
{
    my $self = shift;
    my ($type) = @_;

    if (!exists($self->{"STH_INSTYPE"})) {
        $self->{"STH_INSTYPE"} = $self->{"DBH"}->prepare("INSERT INTO datastore (type) VALUES (?)");
    }
    if ( $self->{"STH_INSTYPE"}->execute($type) ) {
        if (!exists($self->{"STH_LASTID"})) {
            $self->{"STH_LASTID"} = $self->{"DBH"}->prepare("SELECT LAST_INSERT_ID() AS id");
        }
        return $self->{"DBH"}->selectrow_array($self->{"STH_LASTID"});
    }
    return undef;
}


=back

=head1 SEE ALSO

Warewulf::ObjectSet Warewulf::DataStore

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

