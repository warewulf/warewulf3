# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
# $Id$
#

package Warewulf::DataStore::SQL::SQLite;

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

Warewulf::DataStore::SQL::SQLite - SQLite Database interface to Warewulf

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::SQLite;

=head1 DESCRIPTION

    This class should not be instantiated directly.  The new() method in
    the Warewulf::DataStore::SQL class should be used to retrieve the
    appropriate SQL DataStore object.
    
    Note that since SQLite makes use of files in the filesystem, the
    following configuration keys are ignored:
    
      database server
      database port
      database user
      database password
    
    Unlike the MySQL and PostgreSQL drivers, the default binstore kind for
    this class is the 'filesystem' kind.

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

CREATE TABLE meta (
    id              INTEGER PRIMARY KEY NOT NULL,
    name            TEXT,
    value           TEXT
  );
CREATE INDEX meta_name_idx ON meta(name);
INSERT INTO meta (name, value) VALUES ('dbvers', '1');

CREATE TABLE datastore (
    id              INTEGER PRIMARY KEY NOT NULL,
    type            TEXT,
    timestamp       INTEGER NOT NULL DEFAULT 0,
    serialized      BLOB,
    data            BLOB
  );
CREATE INDEX datastore_type_idx ON datastore(type);
CREATE TRIGGER datastore_insert_timestamp
    AFTER INSERT ON datastore
    FOR EACH ROW BEGIN
        UPDATE datastore SET timestamp = strftime('%s', 'now') WHERE rowid = NEW.rowid;
    END;
CREATE TRIGGER datastore_update_timestamp
    AFTER UPDATE OF type,serialized,data ON datastore
    FOR EACH ROW BEGIN
        UPDATE datastore SET timestamp = strftime('%s', 'now') WHERE id = NEW.id;
    END;


CREATE TABLE lookup (
    id              INTEGER PRIMARY KEY NOT NULL,
    object_id       INTEGER NOT NULL,
    field           TEXT,
    value           TEXT,

    FOREIGN KEY(object_id) REFERENCES datastore(id) ON DELETE CASCADE
  );
CREATE INDEX lookup_object_id_idx ON lookup(object_id);
CREATE INDEX lookup_field_idx ON lookup(field);


CREATE TABLE binstore (
    id              INTEGER PRIMARY KEY NOT NULL,
    object_id       INTEGER NOT NULL,
    chunk           BLOB,

    FOREIGN KEY(object_id) REFERENCES datastore(id) ON DELETE CASCADE
  );
CREATE INDEX binstore_object_id_idx ON binstore(object_id);

END_OF_SQL
}


sub
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_port, $db_user, $db_pass, $is_root) = @_;

    #
    # If the $db_name is a relative path, make it relative to the statedir:
    #
    if ( substr($db_name, 0, 1) ne '/' ) {
        $db_name = Warewulf::ACVars->get("STATEDIR") . '/warewulf/' . $db_name;
    }
    &dprintf("Will use SQLite database at path %s\n", $db_name);

    #
    # If the path $db_name does not exist, then we'll need to initialize
    # the database, too:
    #
    my $needsInit = ( ! -f $db_name );

    my $dbh;
    
    #
    # Note that passing the read-only option to the connect() function
    # will only work in DBD::SQLite 1.42 and later.  Prior to that, the
    # default SQLite behavior is used -- try to open read-write first, and
    # if that fails open read-only.  Since we check to see if the database
    # file exists or not, we can avoid that default behavior when it doesn't
    # exist.  But be aware:  as long as the user has write access to the
    # database file, s/he does NOT need to be root to modify it through wwsh
    # commands, etc.
    #
    if ( $is_root ) {
        $dbh = DBI->connect_cached("DBI:SQLite:dbname=$db_name", undef, undef);
    }
    elsif ( ! $needsInit ) {
        $dbh = DBI->connect_cached("DBI:SQLite:dbname=$db_name", undef, undef, { sqlite_open_flags => SQLITE_OPEN_READONLY });
    }
    else {
        &eprint("Non-root user cannot initialize the SQLite datastore database.\n");
        &eprint("Please run 'wwinit database' as root before proceeding.\n");
    }
    if ( $dbh ) {
        $self->{'DATABASE_HAS_FOREIGN_KEYS'} = 1;
        if ( ! $dbh->do('PRAGMA foreign_keys = ON') ) {
            &wprint('Failed to enable foreign key support on $db_name');
            $self->{'DATABASE_HAS_FOREIGN_KEYS'} = 0;
        }
        if ( $needsInit && $is_root ) {
            my $saved_multi_stmt = $dbh->{'sqlite_allow_multiple_statements'};

            $dbh->{'sqlite_allow_multiple_statements'} = 1;
            if ( ! $dbh->do($self->database_schema_string()) ) {
                &eprint('Failed to create database schema in $db_name');
                $dbh->disconnect();
                $dbh = undef;
            } else {
                $dbh->{'sqlite_allow_multiple_statements'} = $saved_multi_stmt;
            }
        }
    }
    return $dbh;
}


sub
default_binstore_kind()
{
    return $Warewulf::DataStore::SQL::BaseClass::BINSTORE_KIND_FILESYSTEM;
}


sub
chunk_size()
{
    my $self = shift;
    my $chunk_size = $self->SUPER::chunk_size();
    
    if ( $self->{'BINSTORE_KIND'} eq $Warewulf::DataStore::SQL::BaseClass::BINSTORE_KIND_DATABASE ) {
        # See https://sqlite.org/limits.html#max_length
        return 1000000000 if ( $chunk_size > 1000000000 );
    }
    return $chunk_size;
}


sub
default_chunk_size_db_impl()
{
    # Default chunk size is 1 MB:
    return 1024 * 1024;
}


sub
has_object_id_foreign_key_support()
{
    return $self->{'DATABASE_HAS_FOREIGN_KEYS'};
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
            push(@string_query, 'lookup.value REGEXP '. $self->{'DBH'}->quote('^('. join('|', @regexp_opts) .'$)'));
        }

        if (@string_query) {
            push(@query_opts, '(' . join(' OR ', @string_query) . ')');
        }
    }

    my $sql_query = <<'END_OF_SQL';
        SELECT
            datastore.id AS id,
            datastore.type AS type,
            datastore.timestamp AS timestamp,
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
    my @query_opts;

    if ($type) {
        push(@query_opts, 'datastore.type = ?');
        push(@$paramsRef, $type);
    }
    if ($field) {
        push(@query_opts, 'lookup.field = ?');
        push(@$paramsRef, uc($field));
    }
    if (@strings) {
        my $optStr = ',?' x scalar(@strings);
        push(@query_opts, 'lookup.value IN (' . substr($optStr, 1) . ')');
        foreach my $s (@strings) {
            push(@$paramsRef, $s);
        }
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

