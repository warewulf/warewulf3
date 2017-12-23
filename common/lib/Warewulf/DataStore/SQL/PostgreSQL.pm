# Copyright (c) 2017 Jeffrey T. Frey
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
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

    This class should not be instantiated directly.  The new() method in
    the Warewulf::DataStore::SQL class should be used to retrieve the
    appropriate SQL DataStore object.
    
    This subclass responds to no additional configuration keys.

=cut


sub
version_of_class()
{
    return 1;
}


sub
database_schema_string()
{
    return <<'END_OF_SQL';

-- Ensure the plpgsql language exists; we need to use a procedural
-- trigger to keep the timestamp column up-to-date on SQL UPDATE
-- queries.
CREATE OR REPLACE LANGUAGE plpgsql;

CREATE TABLE meta (
    id              BIGSERIAL PRIMARY KEY NOT NULL,
    name            TEXT,
    value           TEXT
  );
CREATE INDEX meta_name_idx ON meta(name);
INSERT INTO meta (name, value) VALUES ('dbvers', '1');


CREATE TABLE datastore (
    id              BIGSERIAL PRIMARY KEY NOT NULL,
    type            TEXT,
    timestamp       TIMESTAMP WITH TIME ZONE DEFAULT now(),
    serialized      BYTEA,
    data            BYTEA
  );
CREATE INDEX datastore_type_idx ON datastore(type);
CREATE FUNCTION datastore_update_timestamp_trigger() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.id <> NEW.id THEN
        RAISE EXCEPTION 'datastore.id is an immutable column (% != %)', OLD.id, NEW.id;
    END IF;
    IF OLD.type = NEW.type AND OLD.serialized = NEW.serialized AND OLD.data = NEW.data THEN
        RETURN NULL;
    END IF;
    NEW.timestamp = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER datastore_update_timestamp
    BEFORE UPDATE ON datastore
    FOR EACH ROW EXECUTE PROCEDURE datastore_update_timestamp_trigger();


CREATE TABLE lookup (
    id              BIGSERIAL PRIMARY KEY NOT NULL,
    object_id       BIGINT NOT NULL
                    REFERENCES datastore(id)
                    ON DELETE CASCADE,
    field           TEXT,
    value           TEXT
  );
CREATE INDEX lookup_object_id_idx ON lookup(object_id);
CREATE INDEX lookup_field_idx ON lookup(field);


CREATE TABLE binstore (
    id              BIGSERIAL PRIMARY KEY NOT NULL,
    object_id       BIGINT NOT NULL
                    REFERENCES datastore(id)
                    ON DELETE CASCADE,
    chunk           BYTEA
  );
CREATE INDEX binstore_object_id_idx ON binstore(object_id);

END_OF_SQL
}


sub
database_blob_type()
{
    return { pg_type => DBD::Pg::PG_BYTEA };
}


sub
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_port, $db_user, $db_pass, $is_root) = @_;
    my $conn_str = "DBI:Pg:database=$db_name";
    
    if ( $db_server ) {
        $conn_str .= ";host=$db_server";
        if ( $db_port && $db_port > 0 ) {
            $conn_str .= ";port=$db_port";
        }
    }
    return DBI->connect_cached($conn_str, $db_user, $db_pass);
}


sub
has_object_id_foreign_key_support()
{
    return 1;
}


sub
get_objects_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;

    my @query_opts;

    if ($type) {
        push(@query_opts, 'datastore.type = '. $self->{'DBH'}->quote($type));
    }
    if ($field) {
        if (uc($field) eq 'ID' or uc($field) eq '_ID') {
            push(@query_opts, 'datastore.id IN ('. join(',', map { $self->{'DBH'}->quote($_) } @strings). ')');
            @strings = ();
        } else {
            push(@query_opts, '(lookup.field = '. $self->{'DBH'}->quote(uc($field)) .' OR lookup.field = '. $self->{'DBH'}->quote(uc('_'. $field)) .')');
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
                push(@like_opts, 'lookup.value LIKE '. $self->{'DBH'}->quote($s));
            } else {
                push(@in_opts, $self->{'DBH'}->quote($s));
            }
        }
        if (@in_opts) {
            push(@string_query, 'lookup.value IN ('. join(',', @in_opts). ')');
        }
        if (@like_opts) {
            push(@string_query, join(' OR ', @like_opts));
        }
        if (@regexp_opts) {
            push(@string_query, 'lookup.value ~ '. $self->{'DBH'}->quote('^('. join('|', @regexp_opts) .'$)'));
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


=back

=head1 SEE ALSO

Warewulf::ObjectSet Warewulf::DataStore Warewulf::DataStore::SQL::BaseClass

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

