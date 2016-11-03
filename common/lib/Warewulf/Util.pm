# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Util.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Util;

use Exporter;
use File::Basename;
use Digest::MD5;

our @ISA = ('Exporter');

our @EXPORT = ('&rand_string', '&caller_fixed', '&get_backtrace',
    '&backtrace', '&croak', '&progname', '&homedir',
    '&expand_bracket', '&uid_test', '&ellipsis',
    '&digest_file_hex_md5', '&is_tainted', '&examine_object');

=head1 NAME

Warewulf::Util - Various helper functions

=head1 SYNOPSIS

    use Warewulf::Util;

=head1 DESCRIPTION

This module contains various utility functions used throughout the
Warewulf code.

=head1 FUNCTIONS

=over 4

=item rand_string(length)

Generate a random string of a given length

=cut

sub
rand_string($)
{
    my ($size) = @_;
    my @alphanumeric = ('a'..'z', 'A'..'Z', 0..9);

    if (defined($size) && (int($size) == $size)) {
        $size -= 1;;
    } else {
        $size = 7;
    }

    return join('', map { $alphanumeric[rand @alphanumeric] } 0..$size);
}

=item caller_fixed()

Fixed version of caller() that actually does the right thing.  Returns
the Nth stack frame, not counting itself.

=cut

sub
caller_fixed($)
{
    my $idx = shift || 0;
    my ($pkg, $file, $line, $subroutine);

    $idx++;
    (undef, undef, undef, $subroutine) = caller($idx);
    if (!defined($subroutine)) {
        $subroutine = "MAIN";
    }
    $subroutine =~ s/\w+:://g;
    if ($subroutine =~ /^\w+$/) {
        $subroutine .= "()";
    }
    ($pkg, $file, $line) = caller($idx - 1);
    if ($file && $file =~ /^.*\/([^\/]+)$/) {
        $file = $1;
    }
    return ($pkg || "", $file || "", $line || "", $subroutine);
}

=item get_backtrace()

Generate a stack trace in array form, one caller per line.

=cut

sub
get_backtrace()
{
    my $start = shift || 0;
    my (@trace, @tmp);

    $start++;
    for (my $i = $start; @tmp = &caller_fixed($i); $i++) {
        my ($file, $line, $subroutine);
        my $idx = $i - $start;

        (undef, $file, $line, $subroutine) = @tmp;
        if (($i > 512) || (! $file && ! $line && ($subroutine eq "MAIN()"))) {
            last;
        }
        push @trace, sprintf("%s\[%d\] $file:$line | $subroutine\n",  ' ' x $idx, $idx);
    }
    return ((wantarray()) ? (@trace) : (join('', @trace)));
}

=item backtrace()

Throw a backtrace at the current location in the code.

=cut

sub
backtrace()
{
    print STDERR "STACK TRACE:\n";
    print STDERR "------------\n";
    print STDERR &get_backtrace(1), "\n";
}

=item croak()

Die with a backtrace.

=cut

sub
croak()
{
    my ($file, $line, $subroutine, $i);
    my @tmp;

    print "Program has croaked!\n\n";

    &backtrace();

    exit(255);
}

=item progname()

Return the program name of this running instance

=cut

sub
progname()
{
    return basename($0);
}

=item homedir()

Returns the home directory of the current user (real UID) or "." on error.

=cut

sub
homedir()
{
    return (($ENV{'HOME'}) || ($ENV{'LOGDIR'}) || ((getpwuid($<))[7]) || (""));
}

=item expand_bracket($range1, $range2)

Input a string that contains a bracket range (e.g. [0-20]) and return a list
that has that expanded into a full array. For example, n00[0-19] will return
an array of 20 entries.  Only one range specifier is allowed per string.

=cut

sub
expand_bracket(@)
{
    my @ranges = @_;
    my @ret;

    foreach my $range (@ranges) {
        if ($range =~ /^\/.+\/$/) {
            push(@ret, $range);
        } elsif ($range =~ /^(.*)\[([\d\-\,]+)\](.*)$/) {
            my $prefix = $1;
            my $range = $2;
            my $suffix = $3;

            foreach my $r (split(",", $range)) {
                if ($r =~ /^(\d+)-(\d+)$/) {
                    my $start = $1;
                    my $end = $2;
                    my $len;

                    if ($end < $start) {
                        # The range counts down, so swap the endpoints.
                        ($start, $end) = ($end, $start);
                    }
                    $len = length($end);

                    for (my $i = $start; $i <= $end; $i++) {
                        push(@ret, sprintf("%s%0.${len}d%s", $prefix, $i, $suffix));
                    }
                } elsif ($r =~ /^(\d+)$/ ) {
                    my $num = $1;
                    my $len = length($num);

                    push(@ret, sprintf("%s%0.${len}d%s", $prefix, $num, $suffix));
                }
            }
        } else {
            push(@ret, $range);
        }

    }

    return @ret;
}

=item uid_test($uid)

Test to see if the current euid meets the passed uid: e.g. &uid_test(0) will
test for the root user (which is always UID zero on a Unix system).

=cut

sub
uid_test($)
{
    my ($uid) = @_;

    return ((defined($uid)) ? ($> == $uid) : (0));
}

=item ellipsis($length, $string, $location)

Trim a string to the desired length adding '...' to show that the original
string is longer than allowed. Location will define where to place the
'...' within the string. Options are start, middle, end (default: middle).

=cut

sub
ellipsis($$$)
{
    my ($length, $text, $location) = @_;
    my $actual_length = length($text);

    $location = lc($location || "middle");
    if (! $length || ! $text) {
        return undef;
    } elsif ($actual_length > $length) {
        if ($length <= 3) {
            return substr("...", 0, $length);
        }
        $length -= 3;
        if ($location eq "end") {
            return substr($text, 0, $length) . "...";
        } elsif ($location eq "start") {
            return "..." . substr($text, -$length);
        } else {
            my $leader_length = int($length / 2);
            my $tail_length = $length - $leader_length;

            # Anything else is assumed to mean "middle"
            return substr($text, 0, $leader_length) . "..." . substr($text, -$tail_length);
        }
    } else {
        return $text;
    }
    # NOTREACHED
    return undef;
}

=item digest_file_hex_md5($filename)

Return the MD5 checksum of the file specified in $filename

=cut

sub
digest_file_hex_md5($)
{
    my ($filename) = @_;
    local *DATA;

    if (open(DATA, $filename)) {
        binmode(DATA);
        return Digest::MD5->new()->addfile(*DATA)->hexdigest();
    } else {
        return undef;
    }
}

=item is_tainted($var)

Returns true/false depending on whether or not an item is tainted.

=cut

sub
is_tainted($) {
    # "Borrowed" from the perlsec man page.
    return ! eval { eval("#" . substr(join("", @_), 0, 0)); 1 };
}

=item examine_object($var, [$buffer, [$indent, [$indent_step]]])

Returns a string representation of a deep examination of the value of
a reference.  Useful for debugging complex data structures and
objects.  Results are appended to the contents of $buffer (default
"") and returned.  $indent is the numerical value for the initial
indent level (default 0).  $indent_step determines how many spaces to
indent each subsequent level (default 4).

=cut

sub
examine_object(@)
{
    my ($item, $buffer, $indent, $indent_step, $seen) = @_;
    my $tainted;

    # Set default parameters.
    if (!defined($buffer)) {
        $buffer = "";
    }
    if (!defined($indent)) {
        $indent = 0;
    }
    if (!defined($indent_step)) {
        $indent_step = 4;
    }
    if (!defined($seen)) {
        $seen = {};
    }
    if (&is_tainted($item)) {
        $tainted = ' *TAINTED*';
    } else {
        $tainted = '';
    }

    # Figure out what type it is first.
    if (!defined($item)) {
        $buffer .= "UNDEF";
    } elsif (ref($item)) {
        my $type = ref($item);

        if (exists($seen->{$item})) {
            # Use a hash table to avoid recursing the same reference
            # multiple times.  Avoids infinite recursion in
            # self-referential data structures.
            $buffer .= "SEEN $seen->{$item} REF $item$tainted";
            return $buffer;
        }
        if ($type eq "SCALAR") {
            $seen->{$item} = "SCALAR";
            $buffer .= "SCALAR REF $item$tainted {\n" . (' ' x ($indent + $indent_step));
            $buffer = &examine_object(${$item}, $buffer, $indent + $indent_step, $indent_step, $seen);
            $buffer .= "\n" . (' ' x $indent) . '}';
        } elsif (UNIVERSAL::isa($item, "ARRAY")) {
            $seen->{$item} = (($type eq "ARRAY") ? ("ARRAY") : ("OBJECT"));
            $buffer .= "$seen->{$item} REF $item$tainted {\n";
            for (my $i = 0; $i < scalar(@{$item}); $i++) {
                $buffer .= (' ' x ($indent + $indent_step)) . "$i:  ";
                $buffer = &examine_object($item->[$i], $buffer, $indent + $indent_step, $indent_step, $seen) . "\n";
            }
            $buffer .= (' ' x $indent) . '}';
        } elsif (UNIVERSAL::isa($item, "HASH")) {
            $seen->{$item} = (($type eq "HASH") ? ("HASH") : ("OBJECT"));
            $buffer .= "$seen->{$item} REF $item$tainted {\n";
            foreach my $key (sort(keys(%{$item}))) {
                $buffer .= (' ' x ($indent + $indent_step));
                $buffer = &examine_object($key, $buffer, $indent + $indent_step, $indent_step, $seen) . " => ";
                $buffer = &examine_object($item->{$key}, $buffer, $indent + $indent_step, $indent_step, $seen) . "\n";
            }
            $buffer .= (' ' x $indent) . '}';
        } elsif (UNIVERSAL::isa($item, "CODE")) {
            $seen->{$item} = (($type eq "CODE") ? ("CODE") : ("OBJECT"));
            $buffer .= "$seen->{$item} REF $item$tainted";
        } elsif (UNIVERSAL::isa($item, "REF")) {
            $seen->{$item} = (($type eq "REF") ? ("REF") : ("OBJECT"));
            $buffer .= "$seen->{$item} REF $item$tainted {\n" . (' ' x ($indent + $indent_step));
            $buffer = &examine_object(${$item}, $buffer, $indent + $indent_step, $indent_step, $seen);
            $buffer .= "\n" . (' ' x $indent) . '}';
        } elsif ($type eq "GLOB") {
            $seen->{$item} = $type;
            $buffer .= "GLOB REF $item$tainted";
        } elsif ($type eq "LVALUE") {
            $seen->{$item} = $type;
            $buffer .= "LVALUE REF $item$tainted";
        #} elsif ($type eq "Regexp") {
        } else {
            # Some unknown reference type.
            $seen->{$item} = "UNKNOWN";
            $buffer .= "UNKNOWN REF $item$tainted";
        }
    } elsif ($item =~ /^\d+$/) {
        $buffer .= "$item$tainted";
    } else {
        $buffer .= sprintf("\"%s\" (%d)%s", $item, length($item), $tainted);
    }
    return $buffer;
}

=back

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
