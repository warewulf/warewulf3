# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: DSO.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::DSO;

use Warewulf::Object;
use Warewulf::DataStore;
use Storable qw(freeze thaw);


our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::DSO - Warewulf's DSO (Data Store Object) base class

=head1 SYNOPSIS

    use Warewulf::DSO;
    our @ISA = ('Warewulf::DSO');

=head1 DESCRIPTION

Objects which are to be persisted to (and subsequently pulled from)
the Warewulf Data Store should inherit from the Warewulf::DSO parent
class.  This class should never be directly instantiated.

=head1 METHODS

=over 4

=item new()

The new method is the constructor for this object.  It will create an
object instance and return it to the caller.

NOTE:  This method should only ever be called as SUPER::new() by a
derived class; there should never be a direct instance of this class.

=cut

sub
new($$)
{
    my ($proto, @args) = @_;
    my $class = ref($proto) || $proto;
    my $self;

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@args);
}


=item unserialize($seralized_object)

Unserialize the serialized data from an object. It makes sense to call this
method statically as Warewulf::DSO->unserialize($s) and have it return the
serialized object itself.

=cut

sub
unserialize($)
{
    my ($self, $serialized) = @_;

    return(thaw($serialized));
}


=item serialize()

Return a serialized string of the object. This is useful for persisting,
transferring, or copying. See unserialize() for additional information.

=cut

sub
serialize()
{
    my ($self, $object) = @_;

    if ($object) {
        return(freeze($object));
    } else {
        return(freeze($self));
    }
}


=item type()

Returns a string that defines this object type as it will be stored in
the data store.

=cut

sub
type($)
{
    my ($self) = @_;
    my $type = ref($self);

    $type =~ s/^.+:://;
    if ($type eq "DSO") {
        my $given_type = $self->get("type");

        if ($given_type) {
            return lc($given_type);
        } else {
            return "unknown";
        }
    }
    return lc($type);
}


=item lookups()

Return a list of lookup names for this DSO type.

=cut

sub
lookups($)
{
    return ("_ID", "NAME");
}


=item persist()

Persist this object into the data store

=cut

sub
persist($)
{
    my ($self) = @_;
    my $datastore = Warewulf::DataStore->new();

    $datastore->persist($self);
}


=item id()

Return the Database id for this object.

=cut

sub
id()
{
    my ($self) = @_;

    return ($self->get("_id") || "UNDEF");
}


=item timestamp()

Return the Database timestamp for this object.

=cut

sub
timestamp()
{
    my ($self) = @_;

    return ($self->get("_timestamp") || 0);
}


=back

=head1 SEE ALSO

Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
