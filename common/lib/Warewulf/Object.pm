# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Object.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Object;

use Storable ('dclone');
use Warewulf::Logger;
use Warewulf::Util;

our @ISA = ();

=head1 NAME

Warewulf::Object - Warewulf's generic object class and the ancestor of
all other classes.

=head1 SYNOPSIS

    use Warewulf::Object;

    my $obj = Warewulf::Object->new();

    $obj->set("name", "Bob");
    $obj->set("type" => "person", "active" => 1);
    $display = $obj->to_string();
    $dbg = $obj->debug_string();

=head1 DESCRIPTION

C<Warewulf::Object> is the base class from which all other Warewulf
objects are derived.  It provides a simple constructor, an
initializer, get/set methods, string conversion, and a hash
conversion function.

=head1 METHODS

=over 4

=item new()

Instantiate an object.  Any initializer accepted by the C<set()>
method may also be passed to C<new()>.

=cut

sub
new($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self->init(@_);
}

=item init(...)

Initialize an object.  All data currently stored in the object will be
cleared.  Any initializer accepted by the C<set()> method may also be
passed to C<init()>.

=cut

sub
init(@)
{
    my $self = shift;

    # Clear current data from object.
    %{$self} = ();

    # Check for new initializer.
    if (scalar(@_)) {
        $self->set(@_);
    }

    return $self;
}

=item get(I<key>)

Return the value of the specified member variable I<key>.  Returns
C<undef> if I<key> is not a member variable of the object.  No
distinction is made between "member is not present" and "member is
present but undefined."

=cut

sub
get($)
{
    my ($self, $key) = @_;

    $key = uc($key);
    if (exists($self->{$key})) {
        if (ref($self->{$key}) eq "ARRAY") {
            return ((wantarray()) ? (@{$self->{$key}}) : ($self->{$key}[0]));
        } else {
            return $self->{$key};
        }
    } else {
        my @ret = ();

        return ((wantarray()) ? (@ret) : (undef));
    }
}


=item set(I<key>, I<value>, ...)

=item set(I<key>, I<arrayref>)

=item set(I<arrayref>)

=item set(I<hashref>)

Set member variable(s) from a key/value pair, a hash, an array, or a
hash/array reference.  Returns the last value set or C<undef> if
invoked improperly.

=cut

sub
set($$)
{
    my $self = shift;
    my $key = shift;
    my @vals = @_;

    # If we don't even have a key, we have nothing to do.
    if (!defined($key)) {
        return undef;
    }

    # If the key is a reference, move it to @vals.  Otherwise, uppercase it.
    if (ref($key)) {
        @vals = ($key);
        $key = undef;
    } else {
        $key = uc($key);
    }

    # If we only got 1 value, it better be a reference.
    if ((! $key) && (scalar(@vals) == 1) && (ref($vals[0]))) {
        my $hashref = $vals[0];

        if (ref($hashref) eq "HASH") {
            # Hashref.  Populate our data from referenced hash and return.
            # FIXME:  We're dereferencing top-level references we can
            # handle, but there's still a risk here.  Is there a "deep
            # copy" mechanism we can use here instead?  Do we need to
            # write one?  We also don't handle objects, but we could
            # theoretically handle Warewulf::Objects....
            # If we don't do this, all objects populated with a
            # particular hashref will have all the same values for
            # their keys...by reference!  Change one object, change
            # them all!  Probably not a good thing.  :-)
            #
            # NOTE:  set() will *merge* the hashref into the existing
            # object data.  If you want to clear out the object first,
            # call init(<hashref>) instead of set(<hashref>)!
            foreach my $key (keys(%{$hashref})) {
                my $val = $hashref->{$key};

                $key = uc($key);
                if (ref($val)) {
                    if (ref($val) eq "SCALAR") {
                        $self->set($key, ${$val});
                        next;
                    } elsif (ref($val) eq "ARRAY") {
                        $self->set($key, @{$val});
                        next;
                    } elsif (ref($val) eq "HASH") {
                        %{$self->{$key}} = %{$val};
                        next;
                    }
                }
                $self->{$key} = $val;
            }
            return $hashref;
        } elsif (ref($hashref) eq "ARRAY") {
            # Arrayref.  Dereference it and process as normal.
            @vals = @{$hashref};
            if (!defined($key)) {
                # Key was in the referenced array.
                $key = uc(shift @vals);
            }
        } else {
            # Any other type of reference is a no-no.
            return undef;
        }
    }

    if (!scalar(@vals)) {
        # We still can't set anything if we have no values.
        return undef;
    } elsif (scalar(@vals) == 1) {
        if (!defined($vals[0])) {
            # Undef.  Remove member.
            delete $self->{$key};
            return undef;
        } else {
            # Just one value.  Set the member directly.
            $self->{$key} = $vals[0];
            return $vals[0];
        }
    } else {
        # Multiple values.  Populate an array(ref).
        delete $self->{$key};
        return $self->add($key, @vals);
    }
}

=item add(I<key>, I<value>, ...)

Add an item to an existing member.  Convert to array if needed.

=cut

sub
add()
{
    my $self = shift;
    my $key = shift;
    my @vals = @_;

    if (!defined($key)) {
        my @empty;

        return ((wantarray()) ? (@empty) : (undef));
    }
    $key = uc($key);
    if (exists($self->{$key})) {
        if (ref($self->{$key}) ne "ARRAY") {
            $self->{$key} = [ $self->{$key} ];
        }
    } else {
        $self->{$key} = [];
    }
    foreach my $newval (@vals) {
        if (defined($newval)) {
            # NOTE:  This prevents undef from being a value in this array
            if (!scalar(grep { $_ eq $newval } @{$self->{$key}})) {
                push @{$self->{$key}}, $newval;
            }
        }
    }
    return @{$self->{$key}};
}

=item del(I<key>, [ I<value>, ... ])

Delete one or more items from an array member.  If no values are passed,
delete the member entirely.  Returns the new list of values.

=cut

sub
del()
{
    my $self = shift;
    my $key = shift;
    my @vals = @_;
    my @empty = ();

    if (!defined($key)) {
        # Bad/missing key is an error.
        return ((wantarray()) ? (@empty) : (undef));
    }
    $key = uc($key);

    if (!exists($self->{$key})) {
        # Nothing there to begin with.
        return @empty;
    } elsif (!ref($self->{$key}) || (ref($self->{$key}) ne "ARRAY")) {
        # Anything with which add() or del() is used must be an array.
        $self->{$key} = [ $self->{$key} ];
    }

    if (!scalar(@vals)) {
        # Delete the key entirely.
        delete $self->{$key};
        return @empty;
    }

    # Remove each element in @vals from the array.
    for (my $i = 0; $i < scalar(@{$self->{$key}}); $i++) {
        if (scalar(grep { $self->{$key}[$i] eq $_ } @vals)) {
            # The current value matches and must be removed.
            splice @{$self->{$key}}, $i, 1;
            $i--;
        }
    }

    # If the array is now empty, remove the key.
    if (!scalar(@{$self->{$key}})) {
        delete $self->{$key};
        return @empty;
    }
    return @{$self->{$key}};
}

=item prop(I<key>, [ I<validator>, I<value> ])

Wrapper for object properties (member variables that have matching
combined getter/setter methods).  The I<key> is the member name.
I<value> is the new value to assign.  If I<value> is missing, the
current value of the I<key> property is returned.  (This is consistent
with the behavior of the C<get()> method.)  If I<value> is present but
undefined, the I<key> member will be deleted.  (This is consistent
with the behavior of the C<set()> and C<del()> methods.)

The optional validator is a reference to a regular expression
(supplied via qr/.../) or a coderef.  I<value> must match the regex
(or the coderef must return a defined value); otherwise, the set
operation is aborted.  If a regex is used, the first parenthesized
subgroup must refer to the final value for the member (for untainting
purposes).  If a coderef is used, the return value of the subroutine
must be the validated value or undef (if the value is invalid).

C<prop()> returns the current (possibly new) value of the member in
all cases.

Generally speaking, this method should be used to create the combined
getter/setter method like so:

    sub
    membervar
    {
        my $self = shift;

        return $self->prop("membervar", qr/^(\w+)$/, @_);
    }

This allows for the C<membervar()> method to be used like so:

    $membervar = $obj->membervar();   # get()
    $obj->membervar($new_value);      # set()
    $obj->membervar(undef);           # del()

If no validator is required, pass a false value (e.g., 0 or undef) as
the validator parameter.

A single-line property method is also possible, though slightly less
readable:

    sub membervar {return $_[0]->prop("membervar", qr/^(\w+)$/, @_[1..$#_]);}

=cut

sub
prop()
{
    my ($self, $key, $validator, $val) = @_;

    if ((scalar(@_) <= 1) || !defined($key)) {
        return undef;
    }
    if (scalar(@_) > 3) {
        my $name;

        $name = $self->get("name") || ref($self) || "??UNKNOWN??";
        if ($validator) {
            if (ref($validator) eq "Regexp") {
                my $match = $validator;

                $validator = sub {
                    if ($_[0] =~ $match) {
                        return $1;
                    } else {
                        &eprint("Invalid value for ${name}->$key:  \"$_[0]\"\n");
                        return undef;
                    }
                };
            } elsif (ref($validator) ne "CODE") {
                $validator = sub { return $_[0]; };
            }
        } else {
            $validator = sub { return $_[0]; };
        }
        if (defined($val)) {
            $val = &{$validator}($val);
            if (defined($val)) {
                &dprint("Object $name set $key = '$val'\n");
                $self->set($key, $val);
            } else {
                &dprint("Object $name set $key = '$_[2]' REFUSED\n");
            }
        } else {
            &dprint("Object $name delete $key\n");
            $self->set($key, undef);
        }
    }
    return $self->get($key);
}

=item prop_boolean(I<key>, I<default>[ I<value> ])

Wrapper for C<prop()> to simplify and standardize the creation and
implementation of boolean (true/false) properties for objects.  True
values include C<1>, C<true>, C<yes>, and C<on>.  False values are
C<0>, C<false>, C<no>, and C<off>.  The actual value of the member
property will be either C<1> or C<0> when queried.

=cut

sub
prop_boolean()
{
    my $ret = $_[0]->prop($_[1], sub {
                                     if ($_[0] =~ /^(1|true|on|yes)$/i) {
                                         return 1;
                                     } elsif ($_[0] =~ /^(0|false|off|no)$/i) {
                                         return 0;
                                     } else {
                                         &eprint("Invalid boolean value:  \"$_[0]\"\n");
                                         return undef;
                                     }
                                 }, @_[3..$#_]);
    return ((defined($ret)) ? ($ret) : ($_[2]));
}

=item get_hash()

Return a hash (or hashref) containing all member variables and their
values.  This is particularly useful for converting an object into its
constituent components; e.g., to be stored in a database.

=cut

sub
get_hash()
{
    my $self = shift;
    my $hashref;

    %{$hashref} = %{$self};

    return ((wantarray()) ? (%{$hashref}) : ($hashref));
}

=item to_string()

Return the canonical string representation of the object.  For a
generic object, this is simply the type and pointer value.  Child
classes should override this method intelligently.

=cut

sub
to_string()
{
    my $self = shift;

    return "{ $self }";
}

=item debug_string()

Return debugging output for the object's contents.  For a generic
object, this is the type/pointer value and the member
variables/values.  Child classes should override this method
intelligently.

=cut

sub
debug_string()
{
    my $self = shift;

    return sprintf("{ $self:  %s }", join(", ", map { "\"$_\" => \"$self->{$_}\"" } sort(keys(%{$self}))));
}

=item canonicalize()

Check and update the object format if necessary. Should return the number of
changes that were made to the object.

=cut

sub
canonicalize()
{
    return(0);
}

=item clone([ I<set_arg1>, ...])

Create an exact, but clean, duplicate of an object.  All subobjects
are cloned as well; referenced variables are dereferenced and
duplicated to the extent possible; everything else is copied directly.

Any arguments supplied to this method (e.g., I<set_arg1>...) will be
passed directly to the newly-created object's C<set()> method after
cloning.  This allows the caller to immediately differentiate the
clone if desired.

=cut

sub
clone()
{
    my ($self, @set_args) = @_;
    my $newobj;

    # Uses Perl's deep-clone function (Storable::dclone()).
    $newobj = dclone($self);
    if (scalar(@set_args)) {
        $newobj->set(@set_args);
    }
    return $newobj;
}

=back

=head1 SEE ALSO

Warewulf::ObjectSet

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut

1;
