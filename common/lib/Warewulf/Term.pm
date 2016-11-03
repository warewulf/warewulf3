# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Term.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Term;

use Warewulf::Object;
use Warewulf::Logger;
use File::Basename;
use File::Path;
use Term::ReadLine;

our @ISA = ('Warewulf::Object');
my $singleton;

=head1 NAME

Warewulf::Term - Warewulf terminal control object

=head1 SYNOPSIS

    use Warewulf::Term;

    my $term = Warewulf::Term->new();
    $term->history_load("/path/to/history")

=head1 DESCRIPTION

This object manages terminal interaction, command history, etc. using
the Term::ReadLine Perl module.

=head1 METHODS

=over 4

=item new()

Create and return a Term object instance.

=cut

sub
new($$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    if (! $singleton) {
        $singleton = {};
        bless($singleton, $class);
        $singleton->init();
    }

    return $singleton;
}

=item init(...)

Initialize a Term object.  All data currently stored in the object
will be cleared.

=cut

sub
init(@)
{
    my $self = shift;

    # Clear current data from object.
    %{$self} = ();

    if ( -t STDIN && -t STDOUT ) {
        $singleton->term(Term::ReadLine->new("Warewulf"));
        $singleton->attribs($singleton->{"TERM"}->Attribs);

        $singleton->term()->ornaments(0);
        $singleton->term()->MinLine(undef);

        $singleton->attribs()->{"completion_function"} = \&auto_complete;

        $singleton->interactive(1);
    } else {
        $singleton->interactive(0);
    }

    return $self;
}

=item history_load($filename)

Read and initilize terminal with previous history

=cut

sub
history_load()
{
    my ($self, $file) = @_;
    my $dir = dirname($file);

    if (! $self->term() or ! $self->interactive()) {
        return;
    }

    if ($self->term()->can("ReadHistory")) {
        if ($file) {
            if (! -d $dir) {
                mkpath($dir);
            }
            $self->term()->ReadHistory($file);
            $self->{"HISTFILE"} = $file;
        }
    }

    return;
}


=item history_save([$filename])

Save history to file. If a filename is passed, it will use that, otherwise it
will automatically save to the same file name that was used when initalized
with history_load().

=cut

sub
history_save()
{
    my ($self, $file) = @_;
    my $dir;

    if (! $self->term() or ! $self->interactive()) {
        return;
    }

    if ($self->term()->can("WriteHistory")) {
        if ($file) {
            $dir = dirname($file);
        }

        if ($self->term()) {
            $self->term()->StifleHistory(1000);

            if ($file) {
                if (! -d $dir) {
                    mkpath($dir);
                }
                $self->term()->WriteHistory($file);
            } elsif (exists($self->{"HISTFILE"})) {
                $self->term()->WriteHistory($self->{"HISTFILE"});
            }
        }
    }

    return;
}

=item history_add()

Add a string to the history

=cut

sub
history_add($)
{
    my ($self, $set) = @_;

    if (! $self->term() or ! $self->interactive()) {
        return;
    }

    if ($self->term()->can("AddHistory")) {
        if ($set) {
            $self->term()->AddHistory($set);
        }
    }

    return $set;
}

=item complete($keyword, $objecthandler)

Pass a keyword and an object handler to be called on tab completion

=cut

sub
complete()
{
    my ($self, $keyword, $object) = @_;

    &dprint("Adding keyword '$keyword' to complete\n");

    if ($keyword && $object) {
        push(@{$self->{"COMPLETE"}{"$keyword"}}, $object);
    }
}

=item interactive([$is_interactive])

Test to see if the terminal is interactive.  Pass a true or false
value to override the default behavior and make it so that it will
return true or false for subsequent calls (respectively).

=cut

sub interactive { return $_[0]->prop("interactive", 0, @_[1..$#_]); }

=item get_input($prompt, [ <list of completions> ])

Get input from the user. If the array of potential completions is
given, the first entry will be considered the default.

=cut

sub
get_input($)
{
    my ($self, $prompt, @completions) = @_;
    my $ret;

    if ($self->term() and $self->interactive()) {
        if (@completions) {
            @{$self->{"COMPLIST"}} = @completions;
        }
        $ret = $self->term()->readline($prompt);
        if (@completions) {
            delete($self->{"COMPLIST"});
        }

        if ($ret) {
            $ret =~ s/^\s*(.*?)\s*$/$1/;
        } elsif (scalar(@completions)) {
            $ret = $completions[0];
        }
    } elsif (scalar(@completions)) {
        $ret = $completions[0];
    }

    return $ret;
}

=item yesno([ $question, [ $default_yes, [ $default_notty ] ] ])

Ask the user a question and prompt for a yes/no response.  This is a
convenience/consistency wrapper around C<get_input()> above.  If
I<$question> is not supplied, only the prompt will be printed.
I<$default_yes> specifies whether the default response should be "yes"
or "no."  I<$default_notty> specifies the same for non-interactive
sessions (i.e., where STDIN is not a TTY, thus causing no prompt to be
displayed).

=cut

sub
yesno()
{
    my ($self, $question, $default_yes, $default_notty) = @_;

    if (!defined($default_yes)) {
        $default_yes = 0;
    }
    if (!defined($default_notty)) {
        $default_notty = 1;
    }
    if ($question) {
        chomp($question);
        &nprint($question ."\n");
    }
    if ($self->interactive()) {
        my $ret;

        if ($default_yes) {
            $ret = $self->get_input("Yes/No [yes]> ", "yes", "no");
        } else {
            $ret = $self->get_input("Yes/No [no]> ", "no", "yes");
        }
        $ret = lc($ret);
        if (($ret eq "yes") || ($ret eq 'y')) {
            return 1;
        } elsif (($ret eq "no") || ($ret eq 'n')) {
            return 0;
        } else {
            return (($default_yes) ? (1) : (0));
        }
    } else {
        return (($default_notty) ? (1) : (0));
    }
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

sub
auto_complete()
{
    my ($text, $line, $start) = @_;
    my $self = $singleton;
    my @ret;


    if (exists($self->{"COMPLIST"})) {
        @ret = @{$self->{"COMPLIST"}};
    } elsif ($line =~ /^\s*([^ ]+)\s+/) {
        my $keyword = $1;

        if (exists($self->{"COMPLETE"}{"$keyword"})) {
            foreach my $ref (@{$self->{"COMPLETE"}{"$keyword"}}) {
                push(@ret, $ref->complete("$line"));
            }
        }
    } elsif (exists($self->{"COMPLETE"})) {
        @ret = sort(keys(%{$self->{"COMPLETE"}}));
    }

    return @ret;
}

# Undocumented properties
sub term { return $_[0]->prop("term", 0, @_[1..$#_]); }
sub attribs { return $_[0]->prop("attribs", 0, @_[1..$#_]); }

## Initial tests
#my $obj = Warewulf::Term->new();
#
#$obj->history_add("Hello World");
#my $out = $obj->get_input("Hello World: ", ["yes", "no", "hello"]);
#
#print "->$out<-\n";
#

1;
