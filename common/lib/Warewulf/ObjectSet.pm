# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: ObjectSet.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::ObjectSet;

use Warewulf::Object;
use Warewulf::Logger;

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::ObjectSet - Warewulf's object set interface.

=head1 SYNOPSIS

    use Warewulf::ObjectSet;

    my $obj = Warewulf::ObjectSet->new();

=head1 DESCRIPTION

An ObjectSet is a convenient, object-oriented container for holding an
arbitrary collection of Objects.  Its most common/notable use is in
the DataStore:  return values for queries to the DataStore will be in
the form of ObjectSets.

=head1 METHODS

=over 4

=item new()

Create and return a new ObjectSet instance.

=cut

sub
new($$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self;

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@_);
}

=item init()

Initialize an C<ObjectSet>.

=cut

sub
init(@)
{
    my ($self, @items) = @_;

    ### NOTE:  Do NOT call SUPER::init() here!
    @{$self->{"ARRAY"}} = @items;
    return $self;
}

=item add($obj)

The add method will add an object to the ObjectSet.

=cut

sub
add($$)
{
    my ($self, $obj) = @_;
    my @index;

    if (defined($obj)) {
        # Maintain ordered list of objects in set.
        push(@{$self->{"ARRAY"}}, $obj);
    }
}

=item del($obj)
=item del($key, $value)

Deletes an item from the ObjectSet, either by direct reference ($obj)
or by the value ($value) of an indexed key ($key).  The second form is
essentially equivalent to calling find($key, $value) and invoking
del() on the resulting object(s).  Returns the removed object(s).

=cut

sub
del()
{
    my ($self, $key, $value) = @_;
    my (@objs);

    if (defined($key) && defined($value)) {
        # Find all objects in set (probably just 1) that have this key/value pair.
        @objs = $self->find($key, $value);
    } elsif (defined($key) && ref($key)) {
        if (ref($key) eq "ARRAY") {
            # Array reference to a list of objects.  Delete them all.
            @objs = @{$key};
        } else {
            # Just one object.  Delete it.
            @objs = ($key);
        }
    } else {
        # Error in parameters.
        return undef;
    }

    # In most cases, @objs will only contain a single object.  However, nothing guarantees
    # that the indexes of an ObjectSet will be unique; in fact, it's designed to handle
    # indexing on anything, even non-unique keys.  So any number of objects could match.
    foreach my $obj (@objs) {
        # Remove the object from the set.
        @{$self->{"ARRAY"}} = grep { $_ ne $obj } @{$self->{"ARRAY"}};
    }
    return ((wantarray()) ? (@objs) : ($objs[0]));
}

=item find($index, $string)

Return the relevant object(s) by searching for the given indexed key
criteria.  For this to work, the object set must have index fields
defined.  Caution, due to how the indexing is done (hash references),
this method will not return objects in the same order as they were
added!

The return value will be either a list or a scalar depending on how
you request the data.

=cut

sub
find($$$)
{
    my ($self, $key, $val) = @_;
    my @ret;

    if (! $key || ! $val) {
        return undef;
    }

    foreach my $obj (@{$self->{"ARRAY"}}) {
        if ($obj->get($key) && uc($obj->get($key)) eq uc($val)) {
            push(@ret, $obj);
        }
    }

    return (wantarray() ? @ret : $ret[0]);
}

=item get_object($index)

Return the single Object at the given array index

=cut

sub
get_object($)
{
    my ($self, $index) = @_;

    if (exists($self->{"ARRAY"}[$index])) {
        return ($self->{"ARRAY"}[$index]);
    } else {
        return;
    }
}

=item get_list_entries($index)

Return an array of list entries found in the current set.

=cut

sub
get_list_entries($$)
{
    my ($self, $key) = @_;
    my @ret;

#    foreach my $obj (sort {$a->get("name") cmp $b->get("name")} @{$self->{"ARRAY"}}) {
    foreach my $obj (@{$self->{"ARRAY"}}) {
        my $value = $obj->get($key);

        if ($value) {
            push(@ret, $value);
        }
    }

    if (@ret) {
        return (@ret);
    } else {
        return;
    }
}

# This is a private method for sorting objects for get_list()
sub _objectsortby()
{
    foreach my $s (@_) {
        my $testa = $a->get($s);
        my $testb = $b->get($s);
        if ($testa and $testb) {
            if ($testa gt $testb) {
                return 1;
            } elsif ($testa lt $testb) {
                return -1;
            }
        }
    }
    return 0;
}

=item get_list()

Return an array of all objects in this ObjectSet.

=cut

sub
get_list()
{
    my $self = shift;

    if (exists($self->{"ARRAY"})) {
        if (wantarray()) {
            return sort _objectsortby @{$self->{"ARRAY"}};
        } else {
            my $aref;

            @{$aref} = @{$self->{"ARRAY"}};
            return $aref;
        }
    } else {
        return undef;
    }
}

=item count()

Return the number of entities in the ObjectSet.

=cut

sub
count()
{
    my ($self) = @_;
    my $count;

    if (exists($self->{"ARRAY"})) {
        $count = scalar(@{$self->{"ARRAY"}}) || 0;
    } else {
        $count = 0;
    }
    &dprint("Found $count objects in ObjectSet $self\n");
    return $count;
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
