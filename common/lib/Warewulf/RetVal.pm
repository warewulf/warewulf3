# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: RetVal.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::RetVal;

use Exporter;

our @ISA = ('Exporter');

our @EXPORT = ('retvalid', 'retvalize', 'ret_ok', 'ret_success',
               'ret_err', 'ret_msg', 'ret_err_msg', 'ret_fail',
               'ret_failure', 'ret_libc', 'ret_err_libc');
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = (':all' => [ @EXPORT_OK ], ':clean' => [ ]);

my $last_retval;

=head1 NAME

Warewulf::RetVal - A mechanism for returning results/exceptions
from functions in a flexible, extensible manner.

=head1 SYNOPSIS

    use Warewulf::RetVal;

    # Return failure, error 4, with message.
    return ret_fail(4, "Failed to open file");

    # Return successfully.
    return ret_ok();

    # Return successfully with a result.
    return ret_ok($retval);

    # Or, do it the long way.
    return Warewulf::RetVal->new(0, "", $retval1, $retval2, $retval3);

    # Other valid examples
    return Warewulf::RetVal::ret_success();
    return Warewulf::RetVal->ret_success(@list);
    return Warewulf::RetVal::ret_err(EPERM);
    return Warewulf::RetVal::ret_msg("Unable to open $filename -- $msg");

    # Value of last RetVal object created is attainable statically.
    my $lrv = Warewulf::RetVal->lastrv();

    # You can use it like this, too.
    if (! $obj->some_func($param)->is_ok()) {
        &eprint("Something failed (%d):  %s\n",
                Warewulf::RetVal->lastrv()->error(),
                Warewulf::RetVal->lastrv()->msg());
        return 0;
    }

    # Check to see if we got a RetVal back!
    if (!retvalid($obj->some_func())) {
        die("some_func() method returned invalid value!");
    }

    # Guarantee we have a RetVal for paranoia.
    if (retvalize(other_func())->is_ok()) {
        next;
    }


=head1 DESCRIPTION

C<Warewulf::RetVal> provides a consistent, coherent mechanism for
functions and object methods throughout the Warewulf code to return
success or failure by utilizing a numeric error code, an error message
string, and/or one or more arbitrary results.

The default exports contain some shortcuts for speeding up common
returns.  These are the C<ret_*()> functions.  To avoid importing
these, use the C<:clean> import tag when C<use>-ing this module.  If
you do this, you may still invoke the C<ret_*()> functions as static
methods of C<Warewulf::RetVal>.

=head1 METHODS

=over 4

=item new()

Create and return an instance of a C<RetVal> object.  Any parameters
are automatically passed on to the C<init()> method.

=cut

sub
new()
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    return $self->init(@_);
}

=item init([I<error>, [ I<message>, [ I<result>, [ ... ] ] ] ])

Initialize an C<RetVal> object.  All parameters are optional, but to
pass an error message requires an error code, and to pass results
requires both a code and a message.

=cut

sub
init()
{
    my $self = shift;
    my ($err, $msg, @results) = @_;

    @{$self}{("ERROR", "MESSAGE")} = (($err || 0), ($msg || ""));
    if (scalar(@results)) {
        @{$self->{"RESULTS"}} = @results;
    } else {
        @{$self->{"RESULTS"}} = ();
    }

    $last_retval = $self;
    return $self;
}

=item error([ I<code> ])

Gets or sets the numeric error code for a C<RetVal> object.  Zero
indicates success (but should be tested via the C<succeeded()> method
instead).

=cut

sub
error()
{
    my ($self, $code) = @_;

    if (defined($code)) {
        $self->{"ERROR"} = $code;
    }
    return $self->{"ERROR"};
}

=item message([ I<string> ])

=item msg([ I<string> ])

Gets or sets the error message string for a C<RetVal> object.  The
empty string indicates success (but should be tested via the
C<succeeded()> method instead).

C<msg()> is an alias for C<message()>.

=cut

sub msg() {return message(@_);}
sub
message()
{
    my ($self, $msg) = @_;

    if (defined($msg)) {
        $self->{"MESSAGE"} = $msg;
    }
    return $self->{"MESSAGE"};
}

=item results([ I<result>, [ ... ] ])

=item result([ I<result>, [ ... ] ])

Gets or sets the result set for a C<RetVal> object.  This
corresponds to the traditional notion of a function's return value.
The C<results()> method tries to be smart about what it returns.  If
there are multiple results stored in the object, it returns just like
an array would: the items in a list context and the count in a scalar
context.  If there is only 1 result, it returns that result
regardless.

C<result()> (singular) is an alias for C<results()> (plural).

=cut

sub result() {return results(@_);}
sub
results($)
{
    my ($self, @results) = @_;

    if (scalar(@results)) {
        @{$self->{"RESULTS"}} = @results;
    }
    if (scalar(@{$self->{"RESULTS"}}) == 1) {
        return $self->{"RESULTS"}[0];
    } else {
        return ((wantarray()) ? (@{$self->{"RESULTS"}}) : (scalar(@{$self->{"RESULTS"}})));
    }
}

=item succeeded()

=item is_success()

=item is_ok()

These boolean functions return true if the C<RetVal> represents a
successful return and false otherwise.

=cut

sub succeeded()  {return ($_[0]{"ERROR"} == 0);}
sub is_success() {return ($_[0]{"ERROR"} == 0);}
sub is_ok()      {return ($_[0]{"ERROR"} == 0);}

=item failed()

=item is_failure()

These boolean functions return true if the C<RetVal> represents a
failure and false otherwise.

=cut

sub failed()     {return ($_[0]{"ERROR"} != 0);}
sub is_failure() {return ($_[0]{"ERROR"} != 0);}

=item to_string()

Return the canonical string representation of the C<RetVal> object.
Includes the error code and message, or "OK" if the error code is
zero.

=cut

sub
to_string($)
{
    my $self = shift;

    return (($self->{"ERROR"}) ? ("Error $self->{ERROR}:  $self->{MESSAGE}") : ("OK"));
}

=item debug_string()

Return debugging output for the C<RetVal> object's contents.

=cut

sub
debug_string($)
{
    my $self = shift;

    return sprintf("{ $self:  ERROR %d, MESSAGE \"%s\", %d RESULTS }",
                   $self->{"ERROR"}, $self->{"MESSAGE"},
                   scalar(@{$self->{"RESULTS"}}));
}

=back

=head1 SHORTCUTS

Obviously a system like this which is not a part of the language
itself can become unwieldy.  To help alleviate this, several
"shortcuts" are exported by default.  These shortcuts are functions
which will return C<RetVal> objects initialized in common ways.
They may be called as functions or static methods.

To suppress the import of these shortcut function names into your
program or module namespace, use the C<:clean> tag when importing the
C<RetVal> module.

=head2 Return Value Wrappers

When using C<RetVal> objects robustly, one will want to verify that
functions or methods are actually returning valid C<RetVal> objects
before invoking methods on them.  One may also want to guarantee the
return of a C<RetVal> object in all cases.  These two shortcuts do
that.

=over 4

=item retvalid(I<funcreturn>)

Returns I<funcreturn> if it is a valid C<RetVal> object or false (in
the Perl sense; i.e., 0) otherwise.

B<NOTE>:  ONLY call this as a function, not a method!

=cut

sub
retvalid($)
{
    my ($self) = @_;

    if (!defined($self) || !ref($self) || !UNIVERSAL::isa($self, "Warewulf::RetVal")) {
        return 0;
    }
    return $self;
}

=item retvalize(I<funcreturn>)

If I<funcreturn> is a valid C<RetVal> object, it is returned.

Otherwise, one is created with an error I<code> of C<0xbadc0de> and
"C<retvalize>" as its C<message>.  Its C<results> member is populated
with the original value(s) returned (i.e., I<funcreturn>), if any.
This new C<RetVal> object is then returned.

In other words, this function will guarantee that a valid C<RetVal>
object is returned, even if the original function returned something
else.

B<NOTE>:  ONLY call this as a function, not a method!

=cut

sub
retvalize($)
{
    if (retvalid($_[0])) {
        return $_[0];
    }
    return Warewulf::RetVal->new(0xbadc0de, "retvalize", @_);
}

=back

=head2 Successful Return

A successful return is represented by a C<RetVal> object whose
C<error> member is zero.  (The C<message> member is typically empty as
well, but that is not required.  The error code is authoritative.)

The shortcuts below create and return an instance of a C<RetVal>
object which a zero error code, an empty message, and any supplied
results.

=over 4

=item ret_ok([ I<result>, [ ... ] ])

=item ret_success([ I<result>, [ ... ] ])

Both are equivalent to C<Warewulf::RetVal::new(0, "", [ I<result>, [ ... ] ])>

=cut

sub ret_ok()      {return ret_success(@_);}
sub ret_success() {
    my (@results) = @_;

    if (scalar(@_)
        && (($_[0] eq "Warewulf::RetVal")
            || (ref($_[0]) eq "Warewulf::RetVal"))) {
        shift @results;
    }
    return Warewulf::RetVal->new(0, "", @results);
}

=back

=head2 Failure Return

To return failure, the function should return a C<RetVal> object
whose C<error> member is non-zero.  Use of an error message is also
recommended but not strictly required.  The default error code is -1.

Typically, returning failure does not involve any valid results.
However, nothing in the C<RetVal> implementation precludes their
use, and all shortcuts accept optional results in addition to the
error code and/or message.

=over 4

=item ret_err([ I<code> ])

Equivalent to C<Warewulf::RetVal::new(I<code>)>.  I<code> is -1
if not specified.  The C<message> member of the C<RetVal> object
created is set to the empty string.

=cut

sub
ret_err()
{
    my ($code, @results) = @_;

    return Warewulf::RetVal->new(($code || -1), "", @results);
}

=item ret_msg(I<message>)

Equivalent to C<Warewulf::RetVal::new(-1, I<message>)>.

=cut

sub
ret_msg()
{
    my ($msg, @results) = @_;

    if (defined($msg)
        && (ref($msg) || ($msg eq "Warewulf::RetVal"))) {
        $msg = $results[0];
        shift @results;
    }
    return Warewulf::RetVal->new(-1, ($msg || ""), @results);
}

=item ret_err_msg([ I<code>, [ I<message> ] ])

=item ret_fail([ I<code>, [ I<message> ] ])

=item ret_failure([ I<code>, [ I<message> ] ])

All are equivalent to C<Warewulf::RetVal::new(I<code>,
I<message>)> with the default values for I<code> and I<message> being
-1 and the empty string, respectively.

=cut

sub ret_fail()    {return ret_err_msg(@_);}
sub ret_failure() {return ret_err_msg(@_);}
sub
ret_err_msg()
{
    my ($code, $msg, @results) = @_;

    if (defined($code)
        && (ref($code) || ($code eq "Warewulf::RetVal"))) {
        $code = $msg;
        $msg = $results[0];
        shift @results;
    }
    return Warewulf::RetVal->new(((defined($code)) ? ($code) : (-1)),
                                 ($msg || ""), @results);
}

=back

=head2 Errno-Based Returns

The C<RetVal> object has a convenience mechanism for wrapping
libc-generated error returns.  It relies on the value of C<$!>, so it
B<must> be instantiated B<immediately> after the failed system call to
be valid.

=over 4

=item ret_libc()

=item ret_err_libc()

These functions return C<RetVal> instances with their C<error>
and C<message> members set according to the value of C<$!>.  They are
technically equivalent, but C<ret_libc()> implies an unconditional
return of the libc success/failure state, while C<ret_err_libc()>
should only be used after determining that a failure has occurred.

=cut

sub ret_err_libc() {return ret_libc(@_);}
sub
ret_libc()
{
    my $code = 1 + $! - 1;
    my $msg = $!;

    if (scalar(@_)
        && ((ref($_[0]) eq "Warewulf::RetVal")
            || ($_[0] eq "Warewulf::RetVal"))) {
        shift;
    }
    return Warewulf::RetVal->new($code, $msg, @_);
}

=back

=head2 Last RetVal Created

The last C<RetVal> object which was created or initialized is stored
in a shared member variable.  It can be obtained at any time by
invoking the static method C<lastrv()>.

=over 4

=item lastrv()

Returns the last C<RetVal> object created or initialized (via C<new()>
or C<init()>).  NOTE: This is NOT thread-safe and should not be
expected to work predictably in multithreaded programs.  Also, don't
call it before any C<RetVal> objects have been created.  That would be
bad.

=cut

sub
lastrv()
{
    return $last_retval;
}

=back

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
