# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: MySQL.pm 62 2010-11-11 16:01:03Z gmk $
#

package Warewulf::DataStore::SQL::BaseClass;

use Warewulf::Config;
use Warewulf::ACVars;
use Warewulf::Logger;
use Warewulf::DSO;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::EventHandler;
use DBI qw(:sql_types);
use Storable qw(freeze thaw);
use Fcntl;

=head1 NAME

Warewulf::DataStore::SQL::BaseClass - Common database implementation details

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::BaseClass;

=head1 DESCRIPTION

    This class should not be instantiated directly.  It is intended to be
    treated as an abstract implementation of the DB interface.  All concrete
    implementations (subclasses) have methods that MUST be overridden as
    well as methods that CAN be overridden -- see each method's own
    documentation below for details.  For methods that require validation
    in front of actual actions, the actions themselves are present in
    function(s) named with a "_impl" suffix; in such cases, the "_impl"
    function(s) should be overridden so that the validations are retained
    in the subclass.

    Each concrete implementation inherits the new() function, which will
    create a persistant singleton instance for the application runtime which
    will maintain a consistant database connection from the time that the object
    is constructed.

    Documentation for each function should be found in the top level
    Warewulf::DataStore documentation. Any implementation specific documentation
    can be found here.

    All SQL DataStore implementations accept the following configuration
    keys in database.conf:

      database server           hostname/IP address of the database server; can be
                                omitted for default to be used (e.g. local socket)

      database port             TCP/IP port number on which the database server
                                listens; can be omitted for default to be used

      database name             name of the database to which to connect

      database user             user identity to be used when connecting to the
                                database server

      database password         password to be used when connecting to the database
                                server

      database chunk size       break all binary objects into chunks of this size;
                                the value of this key should be a numerical value
                                with an optional unit: KB/MB/GB for base 2**10 units,
                                kB/mB/gB for base 10 units.  E.g. "4 KB" = 4096

      binstore chunk size       an alias for "database chunk size"

      binstore kind             where binary objects should be stored:
                                  database      as BLOBs in the database
                                  filesystem    as a file in a directory

      binstore fs path          for the filesystem binstore option, the directory
                                in which binary objects would be stored.  Defaults
                                to ${STATEDIR}/binstore.

      binstore fs create mode   for the filesystem binstore option, the permissions
                                mode (in octal) to apply to the copy-in file.  File
                                owner read+write bits are forced to be set, and the
                                value has is masked against 0666 to remove all special
                                and executable bits.

      binstore fs retry count   for the filesystem binstore option, the number of
                                times an extant copy-in file is allowed to exist before
                                the import operation fails.

      binstore fs retry period  for the filesystem binstore option, the number of
                                seconds between checking for existence of the copy-in
                                file (object id plus '.new' suffix).

    The database-root.conf file can contain override values for the "database user" and
    "database password" keys.

=cut

our $BINSTORE_KIND_DATABASE = 'database';
our $BINSTORE_KIND_FILESYSTEM = 'filesystem';


=item serialize($hashref)

Convert a Perl hash (object) into a serialized representation
we can add to a database table.

=cut

sub
serialize($)
{
    my ($self, $hashref) = @_;

    return freeze($hashref);
}

=item unserialize($serialized)

Attempt to reconstitute a Perl hash (object) from the serialized
form.

=cut

sub
unserialize($)
{
    my ($self, $serialized) = @_;

    return thaw($serialized);
}


=item new()

Return the singleton instance of the class.  Note that every
subclass will inherit this method and will stash the single
allocated instance in its own namespace, so no subclass should
need to override this implementation.

=cut

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $singletonName = $class . '::shared_instance';

    if (! $$singletonName) {
        my $instance = bless({}, $class);

        {
            my $config = Warewulf::Config->new('database.conf');
            my $config_root = Warewulf::Config->new('database-root.conf');

            $instance = $instance->init($config, $config_root);
            if ($instance) {
                $$singletonName = $instance;
            }
        }
    }
    return $$singletonName;
}


=item init()

Initialize this instance of the class using the database and
database_root configuration objects passed to us.

Any subclass that overrides this function should start by
chaining to this implementation, a'la

    my $self = shift;

    $self = $self->SUPER::init(@_);
    if ( $self ) {
          :
    }
    return $self;

=cut

sub
init()
{
    my ($self, $config, $config_root) = @_;

    # Only initialize once:
    if ($self && exists($self->{'DBH'}) && $self->{'DBH'}) {
        &dprint("DB Singleton exists, not going to initialize\n");
        return $self;
    }

    my $db_server = $config->get('database server');
    my $db_name = $config->get('database name');
    my $db_port = $config->get('database port');
    my $db_user = $config->get('database user');
    my $db_pass = $config->get('database password');
    my $is_root = 0;
    
    #
    # If we can read the root configuration file, then we
    # should use the user and password found therein
    #
    if ($config_root->get('database user')) {
        my $v;

        if ( ($v = $config_root->get('database user')) ) {
            $db_user = $v;
            $is_root = 1;
        }
        if ( ($v = $config_root->get('database password')) ) {
            $db_pass = $v;
        }
    }

    if ($db_name) {
        &dprintf("DATABASE NAME:      \n", $db_name);
        &dprintf("DATABASE SERVER:    \n", $db_server) if $db_server;
        &dprintf("DATABASE PORT:      \n", $db_port) if $db_port;
        &dprintf("DATABASE USER:      \n", $db_user) if $db_user;

        my $dbh = $self->open_database_handle_impl($db_name, $db_server, $db_port, $db_user, $db_pass, $is_root);
        if ( ! $dbh ) {
            return undef;
        }
        $self->{'DBH'} = $dbh;
        &iprint("Successfully connected to database!\n");

        # Check versions:
        my $dbvers = $self->version_of_database();

        if ( ! $dbvers ) {
            &wprint("Database contains no version meta data\n");
        }
        elsif ( $dbvers < $self->version_of_class() ) {
            &wprintf("Database version (%s) is older than the driver version (%s)\n", $dbvers, $self->version_of_class());
        }
        elsif ( $dbvers > $self->version_of_class() ) {
            &wprintf("Database version (%s) is newer than the driver version (%s)\n", $dbvers, $self->version_of_class());
        }

        # Was an explicit chunk size provided?
        my $chunk_size = $config->get('database chunk size') || $config->get('binstore chunk size');

        if ( $chunk_size ) {
            if ( $chunk_size =~ m/^\s*([+-]?\d+(\.\d*)?)\s*(([GgMmKk]?)([Bb]?))/ ) {
                my %prefixes = ( 'K'=>1024, 'k'=>1000, 'M'=>1024**2, 'm'=>1000**2,
                                 'G'=>1024**3, 'g' => 1000**3 );

                $chunk_size = 0 + $1;

                # Unit prefix:
                $chunk_size *= $prefixes{$4} if ( exists($prefixes{$4}) );

                # We refuse to do anything lower than 4 KB:
                if ( $chunk_size < 4 * 1024 ) {
                    &wprintf("database chunk size is less than 4 KB: %d\n", $chunk_size);
                    return undef;
                }
                $self->{'BINSTORE_CHUNK_SIZE'} = int($chunk_size);
                &dprintf("Explicit database chunk size of %d configured\n", $self->{'BINSTORE_CHUNK_SIZE'});
            } else {
                &wprintf("Database chunk size cannot be parsed: %s\n", $chunk_size);
                return undef;
            }
        }

        # What kind of binary storage is selected?
        my $binstore_kind = $config->get('binstore kind') || $self->default_binstore_kind();

        $binstore_kind = lc($binstore_kind);
        if ( $binstore_kind eq $BINSTORE_KIND_FILESYSTEM ) {
            #
            # Test the set the path to the binstore directory:
            #
            my $binstore_path = $config->get('binstore fs path') || 'binstore';
          
            #
            # A relative path is relative to the STATEDIR:
            #
            if ( substr($binstore_path, 0, 1) ne '/' ) {
                $binstore_path = Warewulf::ACVars->get("STATEDIR") . '/warewulf/' . $binstore_path;
            }

            if ( ! -e $binstore_path ) {
                &wprintf("Binstore path does not exist: %s\n", $binstore_path);
            }
            elsif ( ! -d $binstore_path ) {
                &eprintf("Binstore path is not a directory: %s\n", $binstore_path);
                return undef;
            }
            $self->{'BINSTORE_FS_PATH'} = $binstore_path;

            #
            # Set the retry count for opening a binstore file for write:
            #
            my $int_val = $config->get('binstore fs retry count');
            if ( ! $int_val ) {
                $int_val = 10;
            }
            elsif ( int($int_val) <= 0 ) {
                &wprintf("Invalid binstore fs retry count: %d\n", $int_val);
                $int_val = 10;
            }
            $self->{'BINSTORE_FS_RETRY_COUNT'} = int($int_val);

            #
            # Set the retry period for opening a binstore file for write:
            #
            $int_val = $config->get('binstore fs retry period');
            if ( ! $int_val ) {
                $int_val = 30;
            }
            elsif ( int($int_val) <= 0 ) {
                &wprintf("Invalid binstore fs retry period: %d\n", $int_val);
                $int_val = 30;
            }
            $self->{'BINSTORE_FS_RETRY_PERIOD'} = int($int_val);

            #
            # Set the creation mode for binstore files:
            #
            my $create_mode = $config->get('binstore fs create mode') || '0644';
            if ( ! $create_mode =~ /^[0-9]+$/ ) {
                &eprintf("Binstore file creation mode is invalid: %s\n", $create_mode);
                return undef;
            }
            # The mode MUST at least grant read-write to the user, and should
            # not have any special mode bits or execute bits:
            $create_mode = (oct($create_mode) | 0600) & 0666;
            $self->{'BINSTORE_FS_CREATE_MODE'} = $create_mode;
        }
        elsif ( $binstore_kind eq $BINSTORE_KIND_DATABASE ) {
            # Nothing to do here:
        }
        else {
            &wprintf("Invalid binstore kind: %s\n", $binstore_kind);
            return undef;
        }
        $self->{'BINSTORE_KIND'} = $binstore_kind;
    } else {
        &wprint("Could not connect to the database, no database name provided\n");
        return undef;
    }
    return $self;
}


=item DESTROY();

Object destructor; close any open files if we're a filesystem-based
binstore instance.

=cut

sub
DESTROY()
{
    my $self = shift;

    if ( $self->{'BINSTORE'} ) {
        if ( exists($self->{'OUT_FILEH'}) ) {
            close($self->{'OUT_FILEH'});
            # Rename to atomically replace:
            rename($self->{'OBJECT_PATH'} . '.new', $self->{'OBJECT_PATH'});
        }
        if ( exists($self->{'IN_FILEH'}) ) {
            close($self->{'IN_FILEH'});
        }
    }
}


=item version_of_class()

Return the version number of this class.  Can be checked
against the version_of_database() to determine if an upgrade
is necessary, for example.

Must be overridden by subclasses.

=cut

sub
version_of_class()
{
    &wprint("the SQL base class is not a concrete implementation\n");
    return undef;
}


=item version_of_database()

Return the version number found in the database.

=cut

sub
version_of_database()
{
    my $self = shift;

    if ( exists($self->{'DBH'}) ) {
        my $rows = $self->{'DBH'}->selectall_arrayref("SELECT value FROM meta WHERE name = 'dbvers'");
        my $vers = -1;

        foreach my $row (@$rows) {
            $row = int((@$row)[0]);
            $vers = $row if ( $row > $vers );
        }
        return $vers;
    }
    return undef;
}


=item database_schema_string()

Return a string containing the database schema.

Must be overridden by subclasses.

=cut

sub
database_schema_string()
{
    &wprint("the SQL base class is not a concrete implementation\n");
    return undef;
}


=item database_blob_type()

Return the SQL type used for BLOB data.

Subclasses can override.

=cut

sub
database_blob_type()
{
    return SQL_BLOB;
}


=item open_database_handle_impl

Open a connection to the database.

Must be overridden by subclasses.

=cut

sub
open_database_handle_impl()
{
    my ($self, $db_name, $db_server, $db_port, $db_user, $db_pass, $is_root) = @_;

    &wprint("the SQL base class is not a concrete implementation\n");
    return undef;
}


=item default_binstore_kind

Returns the default kind of binstore that's associated with this
datastore driver.  The default implementation is to use the
binstore inside the database.

Subclasses can override.

=cut

sub
default_binstore_kind()
{
    return $BINSTORE_KIND_DATABASE;
}


=item chunk_size()

Return the configured chunk size or the appropriate default.  This
function should not be overridden by subclasses, rather the
default_chunk_size_*_impl() functions should be.

=cut

sub
chunk_size()
{
    my $self = shift;

    return $self->{'BINSTORE_CHUNK_SIZE'} if ( exists($self->{'BINSTORE_CHUNK_SIZE'}) );
    return $self->default_chunk_size_db_impl() if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_DATABASE );
    return $self->default_chunk_size_fs_impl() if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_FILESYSTEM );
    return 4 * 1024;
}


=item default_chunk_size_db_impl()

Return the default chunk size for the binstore that lives inside
the database.

Subclasses can override.

=cut

sub
default_chunk_size_db_impl()
{
    return 1024 * 1024;
}


=item default_chunk_size_fs_impl()

Return the default chunk size for the binstore that exists as
files in a directory on the file system.

Subclasses can override.

=cut

sub
default_chunk_size_fs_impl()
{
    return 8 * 1024 * 1024;
}


=item has_object_id_foreign_key_support()

Returns non-zero if the database uses foreign key constraints on
object id columns of lookup and binstore tables.  By default we
assume no referential integrity on such columns.

Subclasses can override.

=cut

sub
has_object_id_foreign_key_support()
{
    return 0;
}


=item get_objects($type, $field, $val1, $val2, $val3);

Generalized fetch of objects from the database.  This function validates
the operation and calls-through to the class's SQL query-build implementation.
Any subclass that wishes to modify the behavior can just override
get_objects_build_query_impl() and will still retain the appropriate validation
before and after its action.

=cut

sub
get_objects($$$@)
{
    my $self = shift;
    my ($type, $field, @strings) = @_;

    if (! $self->{'DBH'}) {
        my $config = Warewulf::Config->new('database.conf');
        my $config_root = Warewulf::Config->new('database-root.conf');

        $self->init($config, $config_root);
    }

    my $objectSet = Warewulf::ObjectSet->new();
    my @params;
    my $sql_query = $self->get_objects_build_query_impl($type, $field, \@params, @strings);

    if ( $sql_query ) {
        &dprintf("get objects query: %s\n", $sql_query);

        my $sth = $self->{'DBH'}->prepare($sql_query);

        if ( $sth ) {
            if ( $sth->execute(@params) ) {
                while (my $h = $sth->fetchrow_hashref()) {
                    my $id = $h->{'id'};
                    my $type = $h->{'type'};
                    my $timestamp = $h->{'timestamp'};
                    my $o = Warewulf::DSO->unserialize($h->{'serialized'});
                    my $modname = ucfirst($type);
                    my $modfile = "Warewulf/$modname.pm";

                    if (exists($INC{"$modfile"})) {
                        if (ref($o) eq 'HASH') {
                            &iprint("Working around old datatype format for type: $type\n");
                            bless($o, "Warewulf::$modname");
                        }
                    } else {
                        &eprintf("Skipping data store object type '%s' (is Warewulf::%s loaded?)\n", $type, $modname);
                        next;
                    }
                    $o->set('_id', $id);
                    $o->set('_type', $type);
                    $o->set('_timestamp', $timestamp);
                    $objectSet->add($o);
                }
            } else {
                &wprintf("Unable to execute get objects query: %s\n", $sth->errstr);
                $objectSet = undef;
            }
            $sth->finish();
        } else {
            &wprintf("Unable to prepare get objects query: %s\n", $self->{'DBH'}->errstr);
            $objectSet = undef;
        }
    }

    return $objectSet;
}

=item get_objects_build_query_impl($type, $field, $params, $val1, $val2, $val3);

Build the object retrieval query, returning any arguments to DBI execute()
in the array referenced by the third argument (e.g. @$params).

Must be overridden by subclasses.

=cut

sub
get_objects_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;

    &wprint("the SQL base class is not a concrete implementation\n");
    return undef;
}


=item get_lookups($type, $field, $val1, $val2, $val3);

Generalized lookup of objects in the database.  This function validates
the operation and calls-through to the class's SQL query-build implementation.
Any subclass that wishes to modify the behavior can just override
get_lookups_build_query_impl() and will still retain the appropriate validation
before and after its action.

=cut

sub
get_lookups($$$@)
{
    my $self = shift;

    if (! $self->{'DBH'}) {
        my $config = Warewulf::Config->new('database.conf');
        my $config_root = Warewulf::Config->new('database-root.conf');

        $self->init($config, $config_root);
    }

    my ($type, $field, @strings) = @_;
    my @params;
    my @ret;
    my $sql_query = $self->get_lookups_build_query_impl($type, $field, \@params, @strings);

    if ( $sql_query ) {
        &dprintf("get lookups query: %s\n", $sql_query);

        my $sth = $self->{'DBH'}->prepare($sql_query);

        if ( $sth ) {
            if ( $sth->execute(@params) ) {
                while (my $h = $sth->fetchrow_hashref()) {
                    if (exists($h->{'value'})) {
                        push(@ret, $h->{'value'});
                    }
                }
            } else {
                &wprintf("Unable to execute get lookups query: %s\n", $sth->errstr);
                return undef;
            }
            $sth->finish();
        } else {
            &wprintf("Unable to prepare get lookups query: %s\n", $self->{'DBH'}->errstr);
            return undef;
        }
    }
    return @ret;
}

=item get_lookups_build_query_impl($type, $field, $params, $val1, $val2, $val3);

Build the key-value lookup query, returning any arguments to DBI execute()
in the array referenced by the third argument (e.g. @$params).

Must be overridden by subclasses.

=cut

sub
get_lookups_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;

    &wprint("the SQL base class is not a concrete implementation\n");
    return undef;
}


=item persist($objectSet);

Create/update one or more objects' representation in the database.  This function
validates the operation and calls-through to several helper functions that can be
overridden by subclasses:

    last_allocated_object_impl()

      Determine the integer id of the last item inserted into the datastore
      table.

    update_datastore_impl($id, $serialized_data)

      Set the serialized form of the object with the given object id (in the
      datastore table).  The default implementation uses pretty generic SQL, so
      it probably will not need to be overridden.

    set_lookups_build_query_impl($object, $params)

      Build the SQL query that inserts lookup key-value pairs into the
      database.  The default implementation uses pretty generic SQL, so
      it probably will not need to be overridden.

=cut

sub
persist($$)
{
    my $self = shift;

    if (! $self->{'DBH'}) {
        my $config = Warewulf::Config->new('database.conf');
        my $config_root = Warewulf::Config->new('database-root.conf');

        $self->init($config, $config_root);
    }

    my (@objects) = @_;
    my $event = Warewulf::EventHandler->new();
    my %update_events;
    my @objlist;
    my $objOkCount = 0;

    $event->eventloader();

    foreach my $object (@objects) {
        if (ref($object) eq 'Warewulf::ObjectSet') {
            @objlist = $object->get_list();
        } elsif (ref($object) =~ /^Warewulf::/) {
            @objlist = ($object);
        } else {
            &eprintf("Invalid object type to persist(): %s\n", ref($object));
            return undef;
        }
        foreach my $o (@objlist) {
            my $id = $o->get('_id');
            my $type;
            my $success = 1;

            if ($o->can('type')) {
                $type = $o->type();
            } else {
                &cprintf("Cannot determine object type!  Is the DSO interface loaded for object class '%s?'\n", ref($o));
                &cprintf("Sorry, this error is fatal.  Most likely a problem in %s.\n", $0);
                kill('ABRT', $$);
            }

            $self->{'DBH'}->begin_work();

            do {
                if (! $id ) {
                    &dprint("Persisting new object\n");

                    my $event_retval = $event->handle("$type.new", $o);
                    if (! $event_retval->is_ok()) {
                        my $nodename = $o->nodename() || 'UNDEF';
                        my $message = $event_retval->message();
                        &eprintf("Could not add node %s: %s\n", $nodename, ( $message ? $message : 'unknown error' ));
                        $success = 0;
                        last;
                    }

                    #
                    # New object, we need to assign an object id first:
                    #
                    if (!exists($self->{'STH_INSTYPE'})) {
                        my $sth = $self->{'DBH'}->prepare('INSERT INTO datastore (type) VALUES (?)');
                        if ( ! $sth ) {
                            &eprintf("Unable to prepare object allocation query: %s\n", $self->{'DBH'}->errstr);
                            return undef;
                        }
                        $self->{'STH_INSTYPE'} = $sth;
                    }
                    if ( $self->{'STH_INSTYPE'}->execute($type) ) {
                        $id = $self->last_allocated_object_impl();
                        if ( ! $id ) {
                            &eprintf("Could not determine id of last allocated object of type '%s'\n", $type);
                            $success = 0;
                            last;
                        }
                    } else {
                        &eprintf("Could not allocate new object of type '%s'\n", $type);
                        $success = 0;
                        last;
                    }
                    &dprintf("Inserted a new object into the data store (ID: %d)\n", $id);
                    $o->set('_id', $id);
                }

                &dprintf("Updating data store ID = %d\n", $id);
                if ( ! $self->update_datastore_impl($id, Warewulf::DSO->serialize($o)) ) {
                    &eprintf("Could not update object $id of type ''\n", $type);
                    $success = 0;
                    last;
                }

                # Delete old lookups; this SQL is pretty straightforward, so we won't
                # bother abstracting it:
                if ( ! $self->{'DBH'}->do('DELETE FROM lookup WHERE object_id = ?', undef, $id) ) {
                    &wprintf("Unable to remove existing lookup tuples: %s\n", $self->{'DBH'}->errstr);
                    $success = 0;
                    last;
                }
                if ($o->can('lookups')) {
                    my @params;
                    my $sql_query = $self->set_lookups_build_query_impl($o, \@params);

                    if ( $sql_query ) {
                        &dprintf("set lookups query: %s\n", $sql_query);

                        my $sth = $self->{'DBH'}->prepare($sql_query);

                        if ( $sth ) {
                            if ( scalar(@params) > 0 ) {

                                # Each element of @params is a reference to another
                                # array:
                                foreach my $param (@params) {
                                    if ( ! $sth->execute(@$param) ) {
                                        &wprintf("Unable to execute set lookup query: %s\n", $self->{'DBH'}->errstr);
                                        $success = 0;
                                        last;
                                    }
                                }
                                if ( ! $success ) {
                                    last;
                                }
                            }
                            elsif ( ! $sth->execute() ) {
                                &wprintf("Unable to execute set lookup query: %s\n", $self->{'DBH'}->errstr);
                                $success = 0;
                                last;
                            }
                            $sth->finish();

                            # Consolidate all objects by type to run update events on at once
                            push(@{$update_events{"$type"}}, $o);
                        } else {
                            &wprintf("Unable to prepare set lookup query: %s\n", $self->{'DBH'}->errstr);
                            $success = 0;
                            last;
                        }
                    }
                } else {
                    &dprint("Not adding lookup entries\n");
                }
            } while ( 0 );

            if ( $success ) {
                if ( $self->{'DBH'}->commit() ) {
                    &dprintf("Finished persisting object %d\n", $id);
                    $objOkCount++;
                } else {
                    &wprintf("Failed to persist object %d: %s\n", $id, $self->{'DBH'}->errstr);
                }
            } else {
                if ( $self->{'DBH'}->rollback() ) {
                    &dprintf("Discarded changes to object %d\n", $id);
                } else {
                    &wprintf("Failed to discard changes object %d: %s\n", $id, $self->{'DBH'}->errstr);
                    last;
                }
            }
        }
    }

    # Run all update events grouped together.
    foreach my $type (keys %update_events) {
        $event->handle("$type.modify", @{$update_events{"$type"}});
    }

    return $objOkCount;
}

=item last_allocated_object_impl()

Return the object_id of the last allocated object in the
datastore table.

Subclasses can override.

=cut

sub
last_allocated_object_impl()
{
    my $self = shift;

    return $self->{'DBH'}->last_insert_id(undef, undef, 'datastore', 'id');
}

=item update_datastore_impl($id, $serialized_data)

Update the datastore table, setting the serialized form of the object
with $id to $serialized_data.

Return undef on failure, a non-zero value of any kind otherwise.

Subclasses can override.

=cut

sub
update_datastore_impl()
{
    my $self = shift;
    my ($id, $serialized_data) = @_;

    if (!exists($self->{'STH_SETOBJ'})) {
        my $sth = $self->{'DBH'}->prepare('UPDATE datastore SET serialized = ? WHERE id = ?');
        if ( ! $sth ) {
            &eprintf("Unable to prepare serialized form update query: %s\n", $self->{'DBH'}->errstr);
            return undef;
        }
        $self->{'STH_SETOBJ'} = $sth;
    }
    do {
        last if ! $self->{'STH_SETOBJ'}->bind_param(1, $serialized_data, $self->database_blob_type());
        last if ! $self->{'STH_SETOBJ'}->bind_param(2, $id);
        last if ! $self->{'STH_SETOBJ'}->execute;
        return 1;
    } while ( 0 );
    &eprintf("Unable to execute serialized form update query: %s\n", $self->{'STH_SETOBJ'}->errstr);
    return undef;
}

=item set_lookups_build_query_impl($object, $paramsRef)

Build an SQL query that will insert the key-value pairs associated with
$object into the lookup table.

Returns the SQL query string.  For parametric variants, $paramsRef
is a reference to an array variable; each tuple to be inserted should
be pushed to @$paramsRef as a reference to an array containing the
values to insert (see this implementation).

Subclasses can override.

=cut

sub
set_lookups_build_query_impl()
{
    my $self = shift;
    my ($object, $paramsRef) = @_;

    my $sql_query = 'INSERT INTO lookup (field, value, object_id) VALUES (?, ?, ' . $object->get('_id') . ')';

    foreach my $l ($object->lookups()) {
        my @lookups = $object->get($l);

        if ( scalar(@lookups) ) {
            foreach my $value (@lookups) {
                my @keypair = ( $l, $value );
                push(@$paramsRef, \@keypair);
            }
        } else {
            my @keypair = ( $l, 'UNDEF');
            push(@$paramsRef, \@keypair);
        }
    }

    return $sql_query;
}


=item del_object($objectSet);

Remove an object or object set from the database.  This function validates
the operation and calls-through to the class's implementation.  Any subclass
that wishes to modify the behavior can just override del_object_impl() and
will still retain the appropriate validation before and after its action.

=cut

sub
del_object($$)
{
    my ($self, $object) = @_;
    my $event = Warewulf::EventHandler->new();
    my %events;
    my @objlist;

    if (! $self->{'DBH'}) {
        my $config = Warewulf::Config->new('database.conf');
        my $config_root = Warewulf::Config->new('database-root.conf');

        $self->init($config, $config_root);
    }
    if (ref($object) eq 'Warewulf::ObjectSet') {
        @objlist = $object->get_list();
    } elsif (ref($object) =~ /^Warewulf::/) {
        @objlist = ($object);
    } else {
        &eprintf("Invalid parameter to delete(): %s\n", ref($object));
        return undef;
    }

    # Remove each object:
    foreach my $o (@objlist) {
        my $id = $o->get('_id');
        my $type = $o->type;

        if ($id) {
            &dprintf("Deleting object from the data store: ID=%d\n", $id);

            $self->del_object_impl($o);

            # Consolidate all objects by type to run events on at once
            push(@{$events{"$type"}}, $o);
        }
    }

    # Run all events grouped together.
    foreach my $type (keys %events) {
        $event->handle("$type.delete", @{$events{"$type"}});
    }

    return scalar(@objlist);
}

=item del_object_impl($objectSet);

Function that actually removes a single object from the database.
This is very straightforward SQL, so it probably won't need to be
overridden by subclasses.

But, subclasses can override.

=cut

sub
del_object_impl($$)
{
    my ($self, $object) = @_;
    my $object_id = $object->get('_id');

    $self->{'DBH'}->begin_work();

    #
    # Scrub the lookup table:
    #
    if ( ! $self->has_object_id_foreign_key_support() ) {
        if (!exists($self->{'STH_RMLOOK'})) {
            my $sth = $self->{'DBH'}->prepare('DELETE FROM lookup WHERE object_id = ?');
            if ( ! $sth ) {
                &wprintf("Unable to prepare lookup removal query: %s\n", $self->{'DBH'}->errstr);
                goto EARLY_EXIT;
            }
            $self->{'STH_RMLOOK'} = $sth;
        }
        if ( ! $self->{'STH_RMLOOK'}->execute($object_id) ) {
            &wprintf("Unable to execute lookup removal query: %s\n", $self->{'DBH'}->errstr);
            goto EARLY_EXIT;
        }
    }

    #
    # Scrub the binstore:
    #
    if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_DATABASE && ! $self->del_object_binstore_db_impl($object_id) ) {
        goto EARLY_EXIT;
    }
    elsif ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_FILESYSTEM && ! $self->del_object_binstore_fs_impl($object_id) ) {
        goto EARLY_EXIT;
    }

    #
    # At last, remove the object from the datastore:
    #
    if (!exists($self->{'STH_RMDS'})) {
        my $sth = $self->{'DBH'}->prepare('DELETE FROM datastore WHERE id = ?');
        if ( ! $sth ) {
            &wprintf("Unable to prepare datastore removal query: %s\n", $self->{'DBH'}->errstr);
            goto EARLY_EXIT;
        }
        $self->{'STH_RMDS'} = $sth;
    }
    if ( ! $self->{'STH_RMDS'}->execute($object_id) ) {
        &wprintf("Unable to execute datastore removal query: %s\n", $self->{'STH_RMDS'}->errstr);
        goto EARLY_EXIT;
    }

    if ( ! $self->{'DBH'}->commit() ) {
        &wprintf("Unable to commit object removal: %s\n", $self->{'DBH'}->errstr);
    }

    return 1;

EARLY_EXIT:
    $self->{'DBH'}->rollback();
    return 0;
}


=item del_object_binstore_db_impl($id)

Function that removes an object's binstore data that's
stored inside the database.

=cut

sub
del_object_binstore_db_impl()
{
    my $self = shift;
    my ($object_id) = @_;

    if ( ! $self->has_object_id_foreign_key_support() ) {
        if (!exists($self->{'STH_RMBS'})) {
            my $sth = $self->{'DBH'}->prepare('DELETE FROM binstore WHERE object_id = ?');
            if ( ! $sth ) {
                &wprintf("Unable to prepare binstore removal query: %s\n", $self->{'DBH'}->errstr);
                return undef;
            }
            $self->{'STH_RMBS'} = $sth;
        }
        if ( ! $self->{'STH_RMBS'}->execute($object_id) ) {
            &wprintf("Unable to execute binstore removal query: %s\n", $self->{'DBH'}->errstr);
            return undef;
        }
    }
    return 1;
}


=item del_object_binstore_fs_impl($id)

Function that removes an object's binstore data that's
stored in a directory in the file system.

=cut

sub
del_object_binstore_fs_impl()
{
    my $self = shift;
    my ($object_id) = @_;

    # Delete the file from disk:
    my $path = $self->{'BINSTORE_PATH'} . '/' . $object_id;
    if ( -f $path ) {
        if ( ! unlink($path) ) {
            &wprintf("Unable to remove file from binstore: %s\n", $path);
            return undef;
        }
    }
    return 1;
}


=item binstore($object_id);

Return a binstore object for the given object ID. The binstore object can have
data put or gotten (put_chunk or get_chunk methods respectively) from this
object.

=cut

sub
binstore()
{
    my ($self, $object_id) = @_;

    if ( exists($self->{'DBH'}) ) {
        my $class = ref($self);
        my $dsh = {};

        $dsh->{'DBH'} = $self->{'DBH'};
        $dsh->{'OBJECT_ID'} = $object_id;
        $dsh->{'BINSTORE'} = 1;

        # Copy all DATABASE_ and BINSTORE_ keys into the binstore object:
        while ( my($key, $value) = each(%$self) ) {
            if ( $key =~ /^(BINSTORE|DATABASE)_/ ) {
                $dsh->{$key} = $value;
            }
        }

        # For filesystem binstore, stash the path to the object:
        if ( $self->{'BINSTORE_KIND'} eq $BINSTORE_KIND_FILESYSTEM ) {
            $dsh->{'OBJECT_PATH'} = $self->{'BINSTORE_FS_PATH'} . '/' . $object_id;
        }

        return bless($dsh, $class);
    }
    return undef;
}

=item put_chunk($buffer);

Put data into the binstore object one chunk at a time. Iterate through the
entire datastream until all data has been added.  This function validates
the operation and calls-through to the class's implementation.  Any subclass
that wishes to modify the behavior can just override put_chunk_impl() and
will still retain the appropriate validation ahead of its action.

=cut

sub
put_chunk()
{
    my ($self, $buffer) = @_;

    if (!exists($self->{'BINSTORE'})) {
        &eprint("Wrong object type\n");
        return 0;
    }

    if ( !exists($self->{'DBH'}) ) {
        &eprint("No database handle\n");
        return 0;
    }

    if (!exists($self->{'OBJECT_ID'})) {
        &eprint("Can not store into binstore without an object ID\n");
        return 0;
    }
    return $self->put_chunk_db_impl($buffer) if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_DATABASE );
    return $self->put_chunk_fs_impl($buffer) if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_FILESYSTEM );
    return undef;
}

=item put_chunk_db_impl($buffer);

Function that actually transfers a chunk of data to the binstore
that's inside the database.

Subclasses can override.

=cut

sub
put_chunk_db_impl()
{
    my ($self, $buffer) = @_;

    if (!exists($self->{'STH_PUT'})) {
        my $query = "INSERT INTO binstore (object_id, chunk) VALUES ($self->{OBJECT_ID},?)";

        my $sth = $self->{'DBH'}->prepare($query);
        if ( ! $sth ) {
            &wprintf("Unable to prepare binstore put chunk query: %s\n", $self->{'DBH'}->errstr);
            return undef;
        }
        &dprintf("SQL: %s\n", $query);
        if ( ! $self->{'DBH'}->do('DELETE FROM binstore WHERE object_id = ?', undef, $self->{'OBJECT_ID'}) ) {
            &wprintf("Unable to remove binstore chunks for object %d: %s\n", $self->{'OBJECT_ID'}, $self->{'DBH'}->errstr);
            return undef;
        }
        $self->{'STH_PUT'} = $sth;
    }
    if ( exists($self->{'STH_PUT'}) ) {
        if ( $self->{'STH_PUT'}->bind_param(1, $buffer, $self->database_blob_type()) ) {
            if ( $self->{'STH_PUT'}->execute() ) {
                return 1;
            }
        }
        &eprintf("put_chunk() failed with error:  %s\n", $self->{'STH_PUT'}->errstr());
    }
    return undef;
}


=item put_chunk_fs_impl($buffer);

Function that actually transfers a chunk of data to the binstore
held in a directory in the file system.

Subclasses can override.

=cut

sub
put_chunk_fs_impl()
{
    my ($self, $buffer) = @_;
    my ($rc, $path);

    if (!exists($self->{'OUT_FILEH'})) {
        if ( exists($self->{'OBJECT_PATH'}) ) {
            $path = $self->{'OBJECT_PATH'} . '.new';

            my $period = $self->{'BINSTORE_FS_RETRY_PERIOD'};
            my $retry = $self->{'BINSTORE_FS_RETRY_COUNT'};

            while ( -f $path && $retry-- ) {
                &wprintf("update of object %d (%s) already in progress, waiting %d seconds...\n", $object_id, $path, $period);
                sleep($period);
            }
            my $fh;
            if ( ! sysopen($fh, $path, O_WRONLY | O_CREAT | O_EXCL, $self->{'BINSTORE_FS_CREATE_MODE'}) ) {
                &eprintf("put_chunk() failed while opening file for write: %s\n", $path);
                return undef;
            }
            $self->{'OUT_FILEH'} = $fh;
            binmode $self->{'OUT_FILEH'};
            &dprintf("FILE OP: WRITE TO binstore(%d) => %s\n", $self->{'OBJECT_ID'}, $path);
        } else {
            &eprint("misconfigured binstore object -- no OBJECT_PATH defined\n");
            return undef;
        }
    }

    $rc = syswrite($self->{'OUT_FILEH'}, $buffer);
    if ( ! defined($rc) ) {
        &eprintf("put_chunk() failed while writing %s: %s\n", $path, $!);
        return undef;
    }
    return 1;
}


=item get_chunk();

Get all of the data out of the binstore object one chunk at a time.  This
function validates the operation and calls-through to the class's implementation.
Any subclass that wishes to modify the behavior can just override gett_chunk_impl()
and will still retain the appropriate validation ahead of its action.

=cut

sub
get_chunk()
{
    my ($self) = @_;

    if (!exists($self->{'BINSTORE'})) {
        &eprint("Wrong object type\n");
        return 0;
    }

    if ( !exists($self->{'DBH'}) ) {
        &eprint("No database handle\n");
        return 0;
    }

    if (!exists($self->{'OBJECT_ID'})) {
        &eprint("Can not store into binstore without an object ID\n");
        return 0;
    }
    return $self->get_chunk_db_impl($buffer) if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_DATABASE );
    return $self->get_chunk_fs_impl($buffer) if ( $self->{"BINSTORE_KIND"} eq $BINSTORE_KIND_FILESYSTEM );
    return undef;
}

=item get_chunk_db_impl();

Function that actually transfers a chunk of data from the binstore
that's inside the database.

Subclasses can override.

=cut

sub
get_chunk_db_impl()
{
    my ($self) = @_;

    if (!exists($self->{'STH_GET'})) {
        my $query = "SELECT chunk FROM binstore WHERE object_id = $self->{OBJECT_ID} ORDER BY id";
        &dprintf("SQL:  %s\n", $query);
        my $sth = $self->{'DBH'}->prepare($query);
        if ( ! $sth ) {
            &eprintf("get_chunk() failed with error:  %s\n", $self->{'DBH'}->errstr());
            return undef;
        }
        if ( ! $sth->execute() ) {
            &eprintf("get_chunk() failed with error:  %s\n", $self->{'STH_GET'}->errstr());
            $sth->finish();
            return undef;
        }
        $self->{'STH_GET'} = $sth;
    }
    my $chunk = $self->{'STH_GET'}->fetchrow_array();
    if ( ! $chunk ) {
        $self->{'STH_GET'}->finish();
        delete( $self->{'STH_GET'} );
    }
    return $chunk;
}

=item get_chunk_fs_impl();

Function that actually transfers a chunk of data from the binstore
held in a directory in the file system.

Subclasses can override.

=cut

sub
get_chunk_fs_impl()
{
    my ($self) = @_;
    my $byte_count = $self->chunk_size();
    my ($buffer, $rc);
    my $path;

    if (!exists($self->{'IN_FILEH'})) {
        if ( exists($self->{'OBJECT_PATH'}) ) {
            $path = $self->{'OBJECT_PATH'};
            my $fh;
            if ( ! -f $path || ! -r $path || ! open($fh, '<' . $path) ) {
                &eprintf("get_chunk() failed while opening file for read: %s\n", $path);
                return undef;
            }
            $self->{'IN_FILEH'} = $fh;
            binmode $self->{'IN_FILEH'};
            &dprintf("FILE OP: READ FROM binstore(%d) <= %s\n", $self->{'OBJECT_ID'}, $path);
        } else {
            &eprint("misconfigured binstore object -- no OBJECT_PATH defined\n");
            return undef;
        }
    }

    $rc = sysread($self->{'IN_FILEH'}, $buffer, $byte_count);
    if ( ! defined($rc) ) {
        &eprintf("get_chunk() failed while reading %s: %s\n", $path, $!);
        return undef;
    }
    return $buffer;
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

