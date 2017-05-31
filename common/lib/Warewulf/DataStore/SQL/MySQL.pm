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

    This class should not be instantiated directly.  The new() method in
    the Warewulf::DataStore::SQL class should be used to retrieve the
    appropriate SQL DataStore object.
        
    In addition to the configuration keys described for the parent class
    (Warewulf::DataStore::SQL::BaseClass), the MySQL implementation accepts
    the following keys in database.conf:
    
      binstore chunk optimization     if no explicit "binstore chunk size" is provided,
                                      then an optimal chunk size should be calculated
                                      by querying the database under the following
                                      modes:
                                      
                                        network     the chunk size = the value of the
                                                    max_allowed_packet parameter for
                                                    this connection/database/server
                                        legacy      the chunk size is the value for
                                                    'network' mode minus 768 KB if the
                                                    value is greater than 768 KB; this
                                                    is the default (for backward
                                                    compatibility)
                                        storage     the chunk size is based on the
                                                    InnoDB page size

=cut

our $MYSQL_BINSTORE_OPT_MODE_LEGACY = 'legacy';
our $MYSQL_BINSTORE_OPT_MODE_NETWORK = 'network';
our $MYSQL_BINSTORE_OPT_MODE_STORAGE = 'storage';


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
        if ( ! exists($self->{"BINSTORE_CHUNK_SIZE"}) ) {
            my $opt_mode = $config->get("binstore chunk optimization") || $MYSQL_BINSTORE_OPT_MODE_LEGACY;
            
            $opt_mode = lc($opt_mode);
            if ( $opt_mode ne $MYSQL_BINSTORE_OPT_MODE_NETWORK
                 && $opt_mode ne $MYSQL_BINSTORE_OPT_MODE_STORAGE
                 && $opt_mode ne $MYSQL_BINSTORE_OPT_MODE_LEGACY )
            {
                &wprint("invalid binstore chunk optimization mode: $opt_mode\n");
                return undef;
            }
            $self->{"BINSTORE_CHUNK_OPT_MODE"} = $opt_mode;
        }
    }

    return $self;
}


sub
version_of_class()
{
    return 1;
}


sub
database_schema_string()
{
return <<'END_OF_SQL';

CREATE TABLE IF NOT EXISTS meta (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    name        VARCHAR(64),
    value       VARCHAR(256),
    
    PRIMARY KEY (id)
);
CREATE INDEX meta_name_idx ON meta(name);
INSERT INTO meta (name, value) VALUES ('dbvers', '1');

CREATE TABLE IF NOT EXISTS datastore (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    type        VARCHAR(64),
    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    serialized  BLOB,
    data        BLOB,
    
    PRIMARY KEY (id)
) ENGINE=INNODB;
CREATE INDEX datastore_type_idx ON datastore(type);

CREATE TABLE IF NOT EXISTS binstore (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    object_id   INT UNSIGNED,
    chunk       LONGBLOB,
    
    FOREIGN KEY (object_id) REFERENCES datastore (id),
    PRIMARY KEY (id)
) ENGINE=INNODB;
CREATE INDEX binstore_object_id_idx ON binstore(object_id);

CREATE TABLE IF NOT EXISTS lookup (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    object_id   INT UNSIGNED,
    field       VARCHAR(64) BINARY,
    value       VARCHAR(64) BINARY,
    
    FOREIGN KEY (object_id) REFERENCES datastore (id),
    UNIQUE KEY (object_id, field, value),
    PRIMARY KEY (id)
) ENGINE=INNODB;
CREATE INDEX lookup_object_id_idx ON lookup(object_id);
CREATE INDEX lookup_field_idx ON lookup(field);

END_OF_SQL
}


sub
default_chunk_size_db_impl()
{
    if ( ! exists($self->{"BINSTORE_CHUNK_CALCULATED"}) ) {
        my $chunk_size;
        
        if ( $self->{"BINSTORE_CHUNK_OPT_MODE"} eq $MYSQL_BINSTORE_OPT_MODE_NETWORK 
             || $self->{"BINSTORE_CHUNK_OPT_MODE"} eq $MYSQL_BINSTORE_OPT_MODE_LEGACY ) {
            # One choice -- albeit one that may not remain consistent during usage of the
            # database -- is to use the server's maximum _communications_ packet size.  Basically,
            # this will produce a chunk size that will be delivered in optimal fashion between
            # client and server.
            (undef, $chunk_size) =  $self->{"DBH"}->selectrow_array("show variables LIKE 'max_allowed_packet'");
            &dprint("max_allowed_packet: $chunk_size\n");
            if ( ($self->{"BINSTORE_CHUNK_OPT_MODE"} eq $MYSQL_BINSTORE_OPT_MODE_LEGACY) && ($chunk_size >= 1048576) ) {
                #
                # Dropping 768 KB off the max_allowed_packet size was a recommended behavior
                # but should probably make the storage less optimal.  We should only apply
                # the subtration when the max_allowed_packet size exceeds the 1 MB
                # threshold, too:
                #
                $chunk_size -= 768 * 1024;
            }
            $self->{"DATABASE_CHUNK_CALCULATED"} = $chunk_size;
        }
        elsif ( $self->{"BINSTORE_CHUNK_OPT_MODE"} eq $MYSQL_BINSTORE_OPT_MODE_STORAGE ) {
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
            $self->{"BINSTORE_CHUNK_CALCULATED"} = int( 972.8 * (($chunk_size / 6144.0) + (16.0 / 3.0)) );
        }
        else {
            $self->{"BINSTORE_CHUNK_CALCULATED"} = $self->PARENT::default_chunk_size_db_impl();
        }
        &dprint("Calculated chunk size = $self->{BINSTORE_CHUNK_CALCULATED}\n");
    }
    return $self->{"BINSTORE_CHUNK_CALCULATED"};
}


sub
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_port, $db_user, $db_pass) = @_;
    my $dbh;
    my $conn_str = "DBI:mysql:database=$db_name";
    
    if ( $db_server ) {
        $conn_str .= ";host=$db_server";
        if ( $db_port && $db_port > 0 ) {
            $conn_str .= ";port=$db_port";
        }
    }
    $dbh = DBI->connect_cached($conn_str, $db_user, $db_pass);
    if ( $dbh ) {
        $dbh->{"mysql_auto_reconnect"} = 1;
    }
    return $dbh;
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

Warewulf::ObjectSet Warewulf::DataStore Warewulf::DataStore::SQL::BaseClass

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

