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
use Storable qw(freeze thaw);

# Declare the singleton
my $singleton;

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

    if (! $singleton) {
        # FIXME: ? Maybe ?
        # Always return undef if init() fails. Without this logic, only the
        # first call to new() would return undef, but after that all
        # subsequent calls would appear to work even if DB was not connected.
        # Maybe there is a better way of doing this?
        my $ret;
        my $tmp = {};
        bless($tmp, $class);
        $ret = $tmp->init();
        if ($ret) {
            $singleton = $tmp;
            return $ret;
        } else {
            return undef;
        }
    }

    return $singleton;
}




sub
init()
{
    my $self = shift;
 
    if ($self && exists($self->{"DBH"}) && $self->{"DBH"}) {
        &dprint("DB Singleton exists, not going to initialize\n");
    } else {
        my $config = Warewulf::Config->new("database.conf");
        my $config_root = Warewulf::Config->new("database-root.conf");
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

            if ($self->{"DBH"} = DBI->connect_cached("DBI:mysql:database=$db_name;host=$db_server", $db_user, $db_pass)) {
                &iprint("Successfully connected to database!\n");
                $self->{"DBH"}->{"mysql_auto_reconnect"} = 1;
            } else {
                &wprint("Could not connect to DB: $DBI::errstr!\n");
                return undef;
            }

        } else {
            &wprint("Could not connect to the database (undefined credentials)!\n");
            return undef;
        }
    }
    return $self;
}


=item chunk_size()

Return the proper chunk size.

=cut

sub
chunk_size()
{
    my $self = shift;
    my $max_allowed_packet;

    if (! $self->{"DBH"}) {
        $self->init();
    }
    (undef, $max_allowed_packet) =  $self->{"DBH"}->selectrow_array("show variables LIKE 'max_allowed_packet'");
    &dprint("max_allowed_packet: $max_allowed_packet\n");
    &dprint("Returning max_allowed_packet - 786432\n");

    return ($max_allowed_packet - 786432);
}


=item get_objects($type, $field, $val1, $val2, $val3);

=cut

sub
get_objects($$$@)
{
    my $self = shift;
    my $type = shift;
    my $field = shift;
    my @strings = @_;
    my $objectSet;
    my $sth;
    my $sql_query;
    my @query_opts;

    if (! $self->{"DBH"}) {
        $self->init();
    }
    $objectSet = Warewulf::ObjectSet->new();

    if ($type) {
        push(@query_opts, "datastore.type = ". $self->{"DBH"}->quote($type));
    }
    if ($field) {
        if (uc($field) eq "ID" or uc($field) eq "_ID") {
            push(@query_opts, "datastore.id IN (". join(",", map { $self->{"DBH"}->quote($_) } @strings). ")");
            @strings = ();
        } else {
            push(@query_opts, "(lookup.field = ". $self->{"DBH"}->quote(uc($field)) ." OR lookup.field = ". $self->{"DBH"}->quote(uc("_". $field)) .")");
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
                push(@like_opts, "lookup.value LIKE ". $self->{"DBH"}->quote($s));
            } else {
                push(@in_opts, $self->{"DBH"}->quote($s));
            }
        }
        if (@in_opts) {
            push(@string_query, "lookup.value IN (". join(",", @in_opts). ")");
        }
        if (@like_opts) {
            push(@string_query, join(" OR ", @like_opts));
        }
        if (@regexp_opts) {
            push(@string_query, "lookup.value REGEXP ". $self->{"DBH"}->quote("^(". join("|", @regexp_opts) ."\$)"));
        }

        if (@string_query) {
            push(@query_opts, "(" . join(" OR ", @string_query) . ")");
        }
    }

    $sql_query  = "SELECT ";
    $sql_query .= "datastore.id AS id, ";
    $sql_query .= "datastore.type AS type, ";
    $sql_query .= "UNIX_TIMESTAMP(datastore.timestamp) AS timestamp, ";
    $sql_query .= "datastore.serialized AS serialized ";
    $sql_query .= "FROM datastore ";
    $sql_query .= "LEFT JOIN lookup ON lookup.object_id = datastore.id ";
    if (@query_opts) {
        $sql_query .= "WHERE ". join(" AND ", @query_opts) ." ";
    }
    $sql_query .= "GROUP BY datastore.id";

    dprint("$sql_query\n");

    $sth = $self->{"DBH"}->prepare($sql_query);
    $sth->execute();

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

    return $objectSet;
}


=item get_lookups($type, $field, $val1, $val2, $val3);

=cut

sub
get_lookups($$$@)
{
    my $self = shift;
    my $type = shift;
    my $field = shift;
    my @strings = @_;
    my @query_opts;
    my @ret;
    my $sql_query;
    my $sth;

    if (! $self->{"DBH"}) {
        $self->init();
    }
    if ($type) {
        push(@query_opts, "datastore.type = ". $self->{"DBH"}->quote($type));
    }
    if ($field) {
        push(@query_opts, "lookup.field = ". $self->{"DBH"}->quote(uc($field)));
    }
    if (@strings) {
        push(@query_opts, "lookup.value IN (". join(",", map { $self->{"DBH"}->quote($_) } @strings). ")");
    }
    push(@query_opts, "lookup.field != 'ID'");

    $sql_query  = "SELECT ";
    $sql_query .= "lookup.value AS value ";
    $sql_query .= "FROM lookup ";
    $sql_query .= "LEFT JOIN datastore ON lookup.object_id = datastore.id ";
    if (@query_opts) {
        $sql_query .= "WHERE ". join(" AND ", @query_opts) ." ";
    }
    $sql_query .= "GROUP BY lookup.value";

    dprint("$sql_query\n\n");
    $sth = $self->{"DBH"}->prepare($sql_query);
    $sth->execute();

    while (my $h = $sth->fetchrow_hashref()) {
        if (exists($h->{"value"})) {
            push(@ret, $h->{"value"});
        }
    }

    return @ret;
}


=item persist($objectSet);

=cut

sub
persist($$)
{
    my ($self, @objects) = @_;
    my $event = Warewulf::EventHandler->new();
    my %events;
    my @objlist;

    if (! $self->{"DBH"}) {
        $self->init();
    }

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

            if (! $id) {
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
                if (!exists($self->{"STH_INSTYPE"})) {
                    $self->{"STH_INSTYPE"} = $self->{"DBH"}->prepare("INSERT INTO datastore (type) VALUES (?)");
                }
                $self->{"STH_INSTYPE"}->execute($type);
                if (!exists($self->{"STH_LASTID"})) {
                    $self->{"STH_LASTID"} = $self->{"DBH"}->prepare("SELECT LAST_INSERT_ID() AS id");
                }
                $id = $self->{"DBH"}->selectrow_array($self->{"STH_LASTID"});
                &dprint("Inserted a new object into the data store (ID: $id)\n");
                $o->set("_id", $id);
            }

            &dprint("Updating data store ID = $id\n");
            if (!exists($self->{"STH_SETOBJ"})) {
                $self->{"STH_SETOBJ"} = $self->{"DBH"}->prepare("UPDATE datastore SET serialized = ? WHERE id = ?");
            }
            $self->{"STH_SETOBJ"}->execute(Warewulf::DSO->serialize($o), $id);

            # Delete old lookups
            $self->{"DBH"}->do("DELETE FROM lookup WHERE object_id = ?", undef, $id);

            if ($o->can("lookups")) {
                my $sth;
                my @add_lookups;

                foreach my $l ($o->lookups()) {
                    my @lookups = $o->get($l);

                    if (scalar(@lookups)) {
                        foreach my $value (@lookups) {
                            push(@add_lookups, "(". $self->{"DBH"}->quote(uc($l))
                                 .",". $self->{"DBH"}->quote($value || "UNDEF")
                                 .",". $self->{"DBH"}->quote($id) .")");
                        }
                    } else {
                        push(@add_lookups, "(". $self->{"DBH"}->quote(uc($l))
                             .",'UNDEF',". $self->{"DBH"}->quote($id) .")");
                    }
                }
                &dprint("SQL: INSERT lookup (field, value, object_id) VALUES ". join(",", @add_lookups) ."\n");
                $sth = $self->{"DBH"}->prepare("INSERT lookup (field, value, object_id) VALUES ". join(",", @add_lookups));
                $sth->execute();
                # Consolidate all objects by type to run events on at once
                push(@{$events{"$type"}}, $o);
            } else {
                dprint("Not adding lookup entries\n");
            }

            $self->{"DBH"}->commit();

        }
    }

    # Run all events grouped together.
    foreach my $type (keys %events) {
        $event->handle("$type.modify", @{$events{"$type"}});
    }

    return scalar(@objlist);
}


=item del_object($objectSet);

=cut

sub
del_object($$)
{
    my ($self, $object) = @_;
    my $event = Warewulf::EventHandler->new();
    my %events;
    my @objlist;

    if (! $self->{"DBH"}) {
        $self->init();
    }
    if (ref($object) eq "Warewulf::ObjectSet") {
        @objlist = $object->get_list();
    } elsif (ref($object) =~ /^Warewulf::/) {
        @objlist = ($object);
    } else {
        &eprint("Invalid parameter to delete():  $object (". ref($object) .")\n");
        return undef;
    }
    foreach my $o (@objlist) {
        my $id = $o->get("_id");
        my $type = $o->type;

        if ($id) {
            dprint("Deleting object from the data store: ID=$id\n");

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
            $self->{"STH_RMLOOK"}->execute($id);
            $self->{"STH_RMBS"}->execute($id);
            $self->{"STH_RMDS"}->execute($id);

            $self->{"DBH"}->commit();

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

=item binstore($object_id);

Return a binstore object for the given object ID. The binstore object can have
data put or gotten (put_chunk or get_chunk methods respectively) from this
object.

=cut

sub
binstore()
{
    my ($self, $object_id) = @_;
    my $class = ref($self);
    my $dsh = {};

    $dsh->{"DBH"} = $self->{"DBH"};
    $dsh->{"OBJECT_ID"} = $object_id;
    $dsh->{"BINSTORE"} = 1;

    bless($dsh, $class);
    return $dsh;
}

=item put_chunk($buffer);

Put data into the binstore object one chunk at a time. Iterate through the
entire datastream until all data has been added.

=cut

sub
put_chunk()
{
    my ($self, $buffer) = @_;

    if (!exists($self->{"BINSTORE"})) {
        &eprint("Wrong object type\n");
        return;
    }

    if (!exists($self->{"OBJECT_ID"})) {
        &eprint("Can not store into binstore without an object ID\n");
        return;
    }

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

Get all of the data out of the binstore object one chunk at a time.

=cut

sub
get_chunk()
{
    my ($self) = @_;

    if (!exists($self->{"BINSTORE"})) {
        &eprint("Wrong object type\n");
        return;
    }

    if (!exists($self->{"OBJECT_ID"})) {
        &eprint("Can not store into binstore without an object ID\n");
        return;
    }

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

