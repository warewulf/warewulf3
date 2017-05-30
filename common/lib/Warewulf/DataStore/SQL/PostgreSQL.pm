# Copyright (c) 2017 Jeffrey T. Frey
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
#   CREATE TABLE meta (
#       id              BIGSERIAL PRIMARY KEY NOT NULL,
#       name            TEXT,
#       value           TEXT
#     );
#   CREATE INDEX meta_name_idx ON meta(name);
#   INSERT INTO meta (name, value) VALUES ('dbvers', '1');
#
#
#   CREATE TABLE datastore (
#       id              BIGSERIAL PRIMARY KEY NOT NULL,
#       type            TEXT,
#       timestamp       TIMESTAMP WITH TIME ZONE DEFAULT now(),
#       serialized      BYTEA,
#       data            BYTEA
#     );
#   CREATE INDEX datastore_type_idx ON datastore(type);
#   CREATE FUNCTION datastore_update_timestamp_trigger() RETURNS TRIGGER AS $$
#   BEGIN
#       IF OLD.id <> NEW.id THEN
#           RAISE EXCEPTION 'datastore.id is an immutable column (% != %)', OLD.id, NEW.id;
#       END IF;
#       IF OLD.type = NEW.type AND OLD.serialized = NEW.serialized AND OLD.data = NEW.data THEN
#           RETURN NULL;
#       END IF;
#       NEW.timestamp = now();
#       RETURN NEW;
#   END;
#   $$ LANGUAGE plpgsql;
#   CREATE TRIGGER datastore_update_timestamp
#       BEFORE UPDATE ON datastore
#       FOR EACH ROW EXECUTE PROCEDURE datastore_update_timestamp_trigger();
#
#
#   CREATE TABLE lookup (
#       id              BIGSERIAL PRIMARY KEY NOT NULL,
#       object_id       BIGINT NOT NULL
#                       REFERENCES datastore(id)
#                       ON DELETE CASCADE,
#       field           TEXT,
#       value           TEXT
#     );
#   CREATE INDEX lookup_object_id_idx ON lookup(object_id);
#   CREATE INDEX lookup_field_idx ON lookup(field);
#
#
#   CREATE TABLE binstore (
#       id              BIGSERIAL PRIMARY KEY NOT NULL,
#       object_id       BIGINT NOT NULL
#                       REFERENCES datastore(id)
#                       ON DELETE CASCADE,
#       chunk           BYTEA
#     );
#   CREATE INDEX binstore_object_id_idx ON binstore(object_id);
#
#
#
# $Id$
#

package Warewulf::DataStore::SQL::PostgreSQL;

use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::DSO;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::EventHandler;
use DBI;
use DBD::Pg;

use parent 'Warewulf::DataStore::SQL::BaseClass';

=head1 NAME

Warewulf::DataStore::SQL::PostgreSQL - PostgreSQL Database interface to Warewulf

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::PostgreSQL;

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
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_user, $db_pass) = @_;

    return DBI->connect_cached("DBI:Pg:database=$db_name;host=$db_server", $db_user, $db_pass);
}



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
            push(@string_query, 'lookup.value ~ '. $self->{"DBH"}->quote('^('. join('|', @regexp_opts) .'$)'));
        }

        if (@string_query) {
            push(@query_opts, '(' . join(' OR ', @string_query) . ')');
        }
    }

    $sql_query  = <<'END_OF_SQL';
        SELECT
            datastore.id AS id,
            datastore.type AS type,
            EXTRACT(EPOCH FROM datastore.timestamp) AS timestamp,
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


sub
get_lookups_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;
    
    my $sql_query = <<'END_OF_SQL';
        SELECT
            lookup.value AS value
          FROM lookup
          LEFT JOIN datastore ON lookup.object_id = datastore.id
          WHERE
            lookup.field != 'ID'
END_OF_SQL
    my @predicates;
    
    if ($type) {
        push(@$paramsRef, $type);
        push(@predicates, 'datastore.type = ?');
    }
    if ($field) {
        push(@$paramsRef, uc($field));
        push(@predicates, 'lookup.field = ?');
    }
    if (@strings) {
        foreach my $s (@strings) {
            push(@$paramsRef, $s);
        }
        push(@predicates, 'lookup.value IN (' . substr(',?' x scalar(@strings), 1) . ')');
    }

    if (@predicates) {
        $sql_query .= ' AND '. join(' AND ', @predicates);
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
    $self->{"STH_INSTYPE"}->execute($type);
    return $self->{"DBH"}->last_insert_id(undef, undef, 'datastore', 'id');
}


sub
update_datastore_impl()
{
    my $self = shift;
    my ($id, $serialized_data) = @_;
    
    if (!exists($self->{"STH_SETOBJ"})) {
        $self->{"STH_SETOBJ"} = $self->{"DBH"}->prepare("UPDATE datastore SET serialized = ? WHERE id = ?");
    }
    $self->{"STH_SETOBJ"}->bind_param(1, $serialized_data, { pg_type => DBD::Pg::PG_BYTEA });
    $self->{"STH_SETOBJ"}->bind_param(2, $id);
    my $rc = $self->{"STH_SETOBJ"}->execute();
    $self->{"STH_SETOBJ"}->finish();
    return $rc;
}


sub
put_chunk_impl()
{
    my ($self, $buffer) = @_;

    if (!exists($self->{"STH_PUT"})) {
        $self->{"STH_PUT"} = $self->{"DBH"}->prepare("INSERT INTO binstore (object_id, chunk) VALUES (?,?)");
        $self->{"DBH"}->do("DELETE FROM binstore WHERE object_id = ?", undef, $self->{"OBJECT_ID"});
        &dprint("SQL: INSERT INTO binstore (object_id, chunk) VALUES ($self->{OBJECT_ID},?)\n");
    }
    
    $self->{"STH_PUT"}->bind_param(1, $self->{"OBJECT_ID"});
    $self->{"STH_PUT"}->bind_param(2, $buffer, { pg_type => DBD::Pg::PG_BYTEA });
    my $rc = $self->{"STH_PUT"}->execute();
    $self->{"STH_PUT"}->finish();
    if ( ! $rc ) {
        &eprintf("put_chunk() failed with error:  %s\n", $self->{"STH_PUT"}->errstr());
        return 0;
    }
    return 1;
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

