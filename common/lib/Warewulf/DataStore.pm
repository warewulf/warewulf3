# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DataStore.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::DataStore;

use Warewulf::Util;
use Warewulf::Logger;
use Warewulf::Config;
use Warewulf::DataStore::SQL;
use DBI;

=head1 NAME

Warewulf::DataStore - Interface to backend data store

=head1 SYNOPSIS

    use Warewulf::DataStore;
    use Warewulf::Node;
    use Warewulf::DSO::node;

    print "Creating DataStore interface object\n";
    my $ds = Warewulf::DataStore->new();
    my $node = Warewulf::Node->new();

    print "Setting some stuff\n";
    $node->set("name", "gmk00");

    print "Persisting object\n";
    $ds->persist($node);

    print "Getting stuff\n";
    my $objectSet = $ds->get_objects("node", "name", "gmk00");
    foreach my $o ($objectSet->get_list()) {
        print "name: ". $o->get("name") ."\n";
    }

=head1 DESCRIPTION

Warewulf uses an abstract data store to persist and retrieve the
objects it uses to represent the various components of the systems it
manages.  This class represents an instance of that data store, and
its methods are used to store and retrieve objects as well as specify
how those objects may be identified uniquely within the data store.

=head1 METHODS

=over 4

=item new()

Create the object that will act as the interface to the data store.
The specific data store implementation to be used is determined by
configuration ("database type" in C<database.conf>).

=cut

sub
new($$)
{
    my $proto = shift;
    my $config = Warewulf::Config->new("database.conf");
    my $ds_engine = $config->get("database type") || "sql";

    if ($ds_engine eq "sql") {
        return(Warewulf::DataStore::SQL->new(@_));
    } else {
        &eprint("Could not load DS type \"$ds_engine\"\n");
        exit 1;
    }

    return();
}


=item get_objects($type, $field, $match_string_1, [...])

Return a Warewulf::ObjectSet that includes all of the matched Warewulf::Object
instances for the given criteria.

=cut

sub
get_objects()
{
    return undef;
}

=item del_object($objectSet);

Delete objects within a Warewulf::ObjectSet.

=cut

sub
del_object($$)
{
    return undef;
}



=item persist($object)

Persist an Object (or group of Objects in an ObjectSet) to the
DataStore. By default, if they exist, certain fields within each
Object will automatically generate lookup entries as well.

=cut

sub
persist($)
{
    return undef;
}


=item get_lookups($type, $field, $val1, $val2, $val3);

=cut

sub
get_lookups($$$@)
{   
    return undef;
}


=item binstore($object_id);

Return a binstore object for the given object ID. The binstore object can have
data put or gotten (put_chunk or get_chunk methods respectively) from this
object.

=cut

sub
binstore()
{   
    return undef;
}


=item put_chunk($buffer);

Put data into the binstore object one chunk at a time. Iterate through the
entire datastream until all data has been added. Make sure you don't try to
put a chunk bigger then the chunk_size() for this particular database.

=cut

sub
put_chunk()
{   
    return undef;
}


=item get_chunk();

Get all of the data out of the binstore object one chunk at a time.

=cut

sub
get_chunk()
{
    return undef;
}



=item chunk_size()

Return the proper chunk size. (default it 1m)

=cut

sub
chunk_size()
{   
    return(1024*1024*1024);
}




=back

=head1 SEE ALSO

Warewulf::Object, Warewulf::ObjectSet

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

