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
use Warewulf::Logger;
use Warewulf::DSO;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::EventHandler;
use DBI;
use Storable qw(freeze thaw);

=head1 NAME

Warewulf::DataStore::SQL::BaseClass - Common database implementation details

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::BaseClass;

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
serialize($)
{
    my ($self, $hashref) = @_;

    return freeze($hashref);
}

sub
unserialize($)
{
    my ($self, $serialized) = @_;

    return thaw($serialized);
}


=item new()

=cut

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $singletonName = $class . '::singleton';

    if (! $$singletonName) {
        my $instance = bless({}, $class);

        {
            my $config = Warewulf::Config->new("database.conf");
            my $config_root = Warewulf::Config->new("database-root.conf");

            $instance = $instance->init($config, $config_root);
            if ($instance) {
                $$singletonName = $instance;
            }
        }
    }
    return $$singletonName;
}


=item init()

=cut

sub
init()
{
    my ($self, $config, $config_root) = @_;

    # Only initialize once:
    if ($self && exists($self->{"DBH"}) && $self->{"DBH"}) {
        &dprint("DB Singleton exists, not going to initialize\n");
        return $self;
    }

    my $db_server = $config->get("database server");
    my $db_name = $config->get("database name");
    my $db_user = $config->get("database user");
    my $db_pass = $config->get("database password");

    if ($config_root->get("database user")) {
        $db_user = $config_root->get("database user");
        $db_pass = $config_root->get("database password");
    }

    if ($db_name and $db_server and $db_user) {
        &dprint("DATABASE NAME:      $db_name\n");
        &dprint("DATABASE SERVER:    $db_server\n");
        &dprint("DATABASE USER:      $db_user\n");

        my $dbh = $self->open_database_handle_impl($db_name, $db_server, $db_user, $db_pass);
        if ( ! $dbh ) {
            return undef;
        }
        $self->{"DBH"} = $dbh;
        &iprint("Successfully connected to database!\n");

        # Was an explicit chunk size provided?
        my $chunk_size = $config->get("database chunk size");

        if ( $chunk_size ) {
            if ( $chunk_size =~ m/^\s*([+-]?\d+(\.\d*)?)\s*(([GgMmKk]?)([Bb]?))/ ) {
                my %prefixes = ( 'K'=>1024, 'k'=>1000, 'M'=>1024**2, 'm'=>1000**2,
                                 'G'=>1024**3, 'g' => 1000**3 );

                $chunk_size = 1.0 * $1;

                # Unit prefix:
                $chunk_size *= $prefixes{$4} if ( exists($prefixes{$4}) );

                # We refuse to do anything lower than 4 KB:
                if ( $chunk_size < 4 * 1024.0 ) {
                    &wprint("database chunk size is less than 4 KB: $chunk_size\n");
                    return undef;
                }
                $self->{"DATABASE_CHUNK_SIZE"} = int($chunk_size);
                &dprint("explicit database chunk size of $self->{DATABASE_CHUNK_SIZE} configured\n");
            } else {
                &wprint("database chunk size cannot be parsed: $chunk_size\n");
                return undef;
            }
        }
    } else {
        &wprint("Could not connect to the database (undefined credentials)!\n");
        return undef;
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

    &wprint("the SQL base class is not a concrete implementation");
    return undef;
}


=item chunk_size()

Return the configured chunk size _or_ 4 KB as the default.

=cut

sub
chunk_size()
{
    my $self = shift;

    if ( ! $self->{"DBH"} ) {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");

        $self->init($config, $config_root);
    }

    return $self->{"DATABASE_CHUNK_SIZE"} if ( exists($self->{"DATABASE_CHUNK_SIZE"}) );

    return undef;
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

    if (! $self->{"DBH"}) {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");

        $self->init($config, $config_root);
    }

    my $objectSet = Warewulf::ObjectSet->new();
    my @params;
    my $sql_query = $self->get_objects_build_query_impl($type, $field, \@params, @strings);

    if ( $sql_query ) {
        my $sth;

        dprint("$sql_query\n");

        $sth = $self->{"DBH"}->prepare($sql_query);
        if ( $sth->execute(@params) ) {
            while (my $h = $sth->fetchrow_hashref()) {
                my $id = $h->{"id"};
                my $type = $h->{"type"};
                my $timestamp = $h->{"timestamp"};
                my $o = Warewulf::DSO->unserialize($h->{"serialized"});
                my $modname = ucfirst($type);
                my $modfile = "Warewulf/$modname.pm";

                if (exists($INC{"$modfile"})) {
                    if (ref($o) eq "HASH") {
                        &iprint("Working around old datatype format for type: $type\n");
                        bless($o, "Warewulf::$modname");
                    }
                } else {
                    &eprint("Skipping data store object type '$type' (is Warewulf::$modname loaded?)\n");
                    next;
                }
                $o->set("_id", $id);
                $o->set("_type", $type);
                $o->set("_timestamp", $timestamp);
                $objectSet->add($o);
            }
        }
    }

    return $objectSet;
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

    &wprint("the SQL base class is not a concrete implementation");
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

    if (! $self->{"DBH"}) {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");

        $self->init($config, $config_root);
    }

    my ($type, $field, @strings) = @_;
    my @params;
    my @ret;
    my $sql_query = $self->get_lookups_build_query_impl($type, $field, \@params, @strings);

    if ( $sql_query ) {
        my $sth;

        dprint("$sql_query\n\n");
        $sth = $self->{"DBH"}->prepare($sql_query);
        $sth->execute(@params);

        while (my $h = $sth->fetchrow_hashref()) {
            if (exists($h->{"value"})) {
                push(@ret, $h->{"value"});
            }
        }
    }
    return @ret;
}

=item get_lookups_build_query_impl($type, $field, $params, $val1, $val2, $val3);

Build the key-value lookup query, returning any arguments to DBI execute()
in the array referenced by the third argument (e.g. @$params).

=cut

sub
get_lookups_build_query_impl()
{
    my $self = shift;
    my ($type, $field, $paramsRef, @strings) = @_;

    &wprint("the SQL base class is not a concrete implementation");
    return undef;
}


=item persist($objectSet);

Create/update one or more objects' representation in the database.  This function
validates the operation and calls-through to several helper functions that can be
overridden by subclasses:

    allocate_object_impl($type)
    
      Must be overridden by subclasses; insert a new row into the datastore
      table and return the object id associated with the new row.
    
    update_datastore_impl($id, $serialized_data)
    
      Set the serialized form of the object with the given object id (in the
      datastore table).  The default implementation uses pretty generic SQL, so
      it probably will not need to be overridden.
    
    lookups_build_query_impl($object, $params)
    
      Build the SQL query that inserts lookup key-value pairs into the
      database.  The default implementation uses pretty generic SQL, so
      it probably will not need to be overridden.

=cut

sub
persist($$)
{
    my $self = shift;

    if (! $self->{"DBH"}) {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");

        $self->init($config, $config_root);
    }

    my (@objects) = @_;
    my $event = Warewulf::EventHandler->new();
    my %events;
    my @objlist;

    $event->eventloader();

    foreach my $object (@objects) {
        if (ref($object) eq "Warewulf::ObjectSet") {
            @objlist = $object->get_list();
        } elsif (ref($object) =~ /^Warewulf::/) {
            @objlist = ($object);
        } else {
            &eprint("Invalid object type to persist():  $object\n");
            return undef;
        }
        foreach my $o (@objlist) {
            my $id = $o->get("_id");
            my $type;

            if ($o->can("type")) {
                $type = $o->type();
            } else {
                &cprint("Cannot determine object type!  Is the DSO interface loaded for object class \"". ref($o) ."?\"\n");
                &cprint("Sorry, this error is fatal.  Most likely a problem in $0.\n");
                kill("ABRT", $$);
            }

            $self->{"DBH"}->begin_work();

            if (! $id ) {
                &dprint("Persisting object as new\n");
                my $event_retval = $event->handle("$type.new", $o);
                if (! $event_retval->is_ok()) {
                    my $nodename = $o->nodename() || "UNDEF";
                    my $message = $event_retval->message();
                    &eprint("Could not add node $nodename\n");
                    if ($message) {
                        &eprint("$message\n");
                    }
                    next;
                }
                #
                # New object, we need to assign an object id first:
                #
                $id = $self->allocate_object_impl($type);
                if ( ! $id ) {
                    &eprint("Could not allocate new object of type '$type'\n");
                    next;
                }
                &dprint("Inserted a new object into the data store (ID: $id)\n");
                $o->set("_id", $id);
            }

            &dprint("Updating data store ID = $id\n");
            if ( ! $self->update_datastore_impl($id, Warewulf::DSO->serialize($o)) ) {
                    &eprint("Could not update object $id of type '$type'\n");
                    next;
            }

            # Delete old lookups; this SQL is pretty straightforward, so we won't
            # bother abstracting it:
            $self->{"DBH"}->do("DELETE FROM lookup WHERE object_id = ?", undef, $id);
            if ($o->can("lookups")) {
                my @params;
                my $sql_query = $self->lookups_build_query_impl($o, \@params);

                if ( $sql_query ) {
                    my $sth;

                    dprint("$sql_query\n\n");
                    if ( @params && scalar(@params) > 0 ) {
                        $sth = $self->{"DBH"}->prepare($sql_query);

                        # Each element of @params is a reference to another
                        # array:
                        foreach my $param (@params) {
                            $sth->execute(@$param);
                        }
                    } else {
                        $sth = $self->{"DBH"}->prepare($sql_query);
                        $sth->execute();
                    }
                    # Consolidate all objects by type to run events on at once
                    push(@{$events{"$type"}}, $o);
                }
            } else {
                dprint("Not adding lookup entries\n");
            }
            $self->{"DBH"}->commit();
        }
    }
}

=item allocate_object_impl($type)

Insert a new row in the datastore table and return its integer object id.
Return undef on error.

=cut

sub
allocate_object_impl()
{
    my $self = shift;
    my ($type) = @_;

    &wprint("the SQL base class is not a concrete implementation");
    return undef;
}

=item update_datastore_impl($id, $serialized_data)

Update the datastore table, setting the serialized form of the object
with $id to $serialized_data.

Return undef on failure, a non-zero value of any kind otherwise.

=cut

sub
update_datastore_impl()
{
    my $self = shift;
    my ($id, $serialized_data) = @_;

    if (!exists($self->{"STH_SETOBJ"})) {
        $self->{"STH_SETOBJ"} = $self->{"DBH"}->prepare("UPDATE datastore SET serialized = ? WHERE id = ?");
    }
    return $self->{"STH_SETOBJ"}->execute($serialized_data, $id);
}

=item lookups_build_query_impl($object, $paramsRef)

Build an SQL query that will insert the key-value pairs associated with
$object into the lookup table.

Returns the SQL query string.  For parametric variants, $paramsRef
is a reference to an array variable; each tuple to be inserted should
be pushed to @$paramsRef as a reference to an array containing the
values to insert (see this implementation).

=cut

sub
lookups_build_query_impl()
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

    if (! $self->{"DBH"}) {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");

        $self->init($config, $config_root);
    }
    if (ref($object) eq "Warewulf::ObjectSet") {
        @objlist = $object->get_list();
    } elsif (ref($object) =~ /^Warewulf::/) {
        @objlist = ($object);
    } else {
        &eprint("Invalid parameter to delete():  $object (". ref($object) .")\n");
        return undef;
    }

    # Remove each object:
    foreach my $o (@objlist) {
        my $id = $o->get("_id");
        my $type = $o->type;

        if ($id) {
            dprint("Deleting object from the data store: ID=$id\n");

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
overridden by subclasses (well, those doing strictly SQL, anyway).

=cut

sub
del_object_impl($$)
{
    my ($self, $object) = @_;

    $self->{"DBH"}->begin_work();

    if (!exists($self->{"STH_RMLOOK"})) {
        $self->{"STH_RMLOOK"} = $self->{"DBH"}->prepare("DELETE FROM lookup WHERE object_id = ?");
    }
    if (!exists($self->{"STH_RMBS"})) {
        $self->{"STH_RMBS"} = $self->{"DBH"}->prepare("DELETE FROM binstore WHERE object_id = ?");
    }
    if (!exists($self->{"STH_RMDS"})) {
        $self->{"STH_RMDS"} = $self->{"DBH"}->prepare("DELETE FROM datastore WHERE id = ?");
    }
    $self->{"STH_RMLOOK"}->execute($object->get("_id"));
    $self->{"STH_RMBS"}->execute($object->get("_id"));
    $self->{"STH_RMDS"}->execute($object->get("_id"));

    $self->{"DBH"}->commit();
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

    if ( exists($self->{"DBH"}) ) {
        my $class = ref($self);
        my $dsh = {};

        $dsh->{"DBH"} = $self->{"DBH"};
        $dsh->{"OBJECT_ID"} = $object_id;
        $dsh->{"BINSTORE"} = 1;

        # Copy any explicit chunk size into the binstore child instance:
        $dsh->{"DATABASE_CHUNK_SIZE"} = $self->{"DATABASE_CHUNK_SIZE"} if ( exists($self->{"DATABASE_CHUNK_SIZE"}) );

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

    if (!exists($self->{"BINSTORE"})) {
        &eprint("Wrong object type\n");
        return 0;
    }

    if ( !exists($self->{"DBH"}) ) {
        &eprint("No database handle\n");
        return 0;
    }

    if (!exists($self->{"OBJECT_ID"})) {
        &eprint("Can not store into binstore without an object ID\n");
        return 0;
    }

    return $self->put_chunk_impl($buffer);
}

=item put_chunk_impl($buffer);

Function that actually transfers a chunk of data to the binstore.

=cut

sub
put_chunk_impl()
{
    my ($self, $buffer) = @_;

    if (!exists($self->{"STH_PUT"})) {
        $self->{"STH_PUT"} = $self->{"DBH"}->prepare("INSERT INTO binstore (object_id, chunk) VALUES (?,?)");
        $self->{"DBH"}->do("DELETE FROM binstore WHERE object_id = ?", undef, $self->{"OBJECT_ID"});
        &dprint("SQL: INSERT INTO binstore (object_id, chunk) VALUES ($self->{OBJECT_ID},?)\n");
    }

    if (! $self->{"STH_PUT"}->execute($self->{"OBJECT_ID"}, $buffer)) {
        &eprintf("put_chunk() failed with error:  %s\n", $self->{"STH_PUT"}->errstr());
        return 0;
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

    if (!exists($self->{"BINSTORE"})) {
        &eprint("Wrong object type\n");
        return 0;
    }

    if ( !exists($self->{"DBH"}) ) {
        &eprint("No database handle\n");
        return 0;
    }

    if (!exists($self->{"OBJECT_ID"})) {
        &eprint("Can not store into binstore without an object ID\n");
        return 0;
    }

    return $self->get_chunk_impl();
}

=item get_chunk_impl();

Function that actually transfers a chunk of data from the binstore.

=cut

sub
get_chunk_impl()
{
    my ($self) = @_;

    if (!exists($self->{"STH_GET"})) {
        my $query = "SELECT chunk FROM binstore WHERE object_id = $self->{OBJECT_ID} ORDER BY id";
        &dprint("SQL:  $query\n");
        $self->{"STH_GET"} = $self->{"DBH"}->prepare($query);
        $self->{"STH_GET"}->execute();
    }
    return $self->{"STH_GET"}->fetchrow_array();
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

