# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Config.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Config;

use Warewulf::ACVars;
use Warewulf::Util;
use Warewulf::Logger;
use Warewulf::Object;
use Text::ParseWords;

our @ISA = ('Warewulf::Object');

# Shared cache for configuration data.  All instances share the same
# cache.
my %cache;

=head1 NAME

Warewulf::Config - Object interface to configuration paramaters

=head1 SYNOPSIS

    use Warewulf::Config;

    my $obj = Warewulf::Config->new("something.conf");

    foreach my $entry ( $obj->get("config entry name") ) {
        print "->$entry<-\n";
    }

=head1 DESCRIPTION

The Warewulf::Config class facilitates the parsing of configuration
data and retrieving the results in an object-oriented manner.

=head1 METHODS

=over 4

=item new($config_name)

The new() constructor will create the object that references the
configuration store. You can pass a list of configuration files that
will be included in the object if desired. Each config will be
searched for first in the user's home/private directory and then in
the global locations.

=cut

sub
new()
{
    my ($proto, @args) = @_;
    my $class = ref($proto) || $proto;
    my $self;

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@args);
}

=item init([$filename, [$path, [...]]])

Initializes the Config object.  If parameters are supplied, the
specified config file will be parsed immediately.

=cut

sub
init()
{
    my ($self, @args) = @_;

    # Delete all information from the Config object.
    %{$self} = ();
    $self->set_path(
        &homedir() . "/.warewulf",
        Warewulf::ACVars->get("SYSCONFDIR") . "/warewulf"
    );
    if (scalar(@args)) {
        $self->load(@args);
    }
    return $self;
}

=item get_path()

Returns the list of directories to be searched for config files in
this Config instance.

=cut

sub
get_path()
{
    my ($self) = @_;

    return $self->get("__PATH");
}

=item set_path($path, [...])

Specifies one or more paths to be searched for config files.  To
append to the search path, the first argument to set_path() should be
the return value of get_path().

=cut

sub
set_path()
{
    my ($self, @args) = @_;

    return $self->set("__PATH", @args);
}

=item load($filename, [$filename2, [...]])

Loads the specified configuration file(s) into this Config object.
Any existing configuration data present in the object will be
PRESERVED.  (If this is not desired, call init() instead.)  The
default search path is ("~/.warewulf", "/etc/warewulf").  The correct
search path must be set before calling I<load()>.

=cut

sub
load()
{
    my ($self, @args) = @_;
    my $rc = 0;

    if (!scalar(@args)) {
        return undef;
    }

    foreach my $filename (@args) {
        $self->add("__FILENAME", $filename);
        if ($filename =~ /^(\/[a-zA-Z0-9\-_\/\.]+)$/ and -f $filename) {
            $self->set("__FILE", $filename);
            if (defined($self->parse())) {
                $rc++;
            }
        } else {
            foreach my $path ($self->get_path()) {
                &dprint("Searching for file:  $path/$filename\n");
                if (-r "$path/$filename") {
                    &dprint("Found file:  $path/$filename\n");
                    $self->set("__FILE", "$path/$filename");
                    if (defined($self->parse())) {
                        $rc++;
                        last;
                    }
                }
            }
        }
    }
    return $rc;
}

=item save([$filename])

Stores the current configuration data from this Config instance into the specified file ($filename) or the original file (if unspecified).  NOT YET IMPLEMENTED.

=cut

sub
save()
{
    &wprint("Warewulf::Config->save() not yet implemented.\n");
    return undef;
}

=back

=head1 FORMAT

The configuration file format utilizes key-value pairs separated by an
equal sign ('='). There maybe multiple key-value pairs as well as
comma-delimited value entries.

Line continuations are allowed as long as the previous line entry ends
with a backslash.

Example configuration directives:

    key = value_one value_two, "value two,a"
    key = 'value three' \
          value\ four

This will assign the following to the "key" variable:

    value_one
    value_two
    value two,a
    value three
    value four

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut

# Open and parse the config file, or used cached data if present.
# Returns 1 in the former case and 0 in the latter case. 
sub
parse()
{
    my ($self) = @_;
    my ($conffile, $last_key);
    local *FILE;

    # Check for filename
    $conffile = $self->get("__FILE");
    if (! $conffile) {
        &cprint("${self}->parse() called without validated filename!\n");
        return undef;
    }

    # Check for cached data.
    if (exists($cache{$conffile})) {
        # Use the cached hash reference to populate the object.
        &dprint("Cache data for $conffile exists.  Using it.\n");
        $self->set($cache{$conffile});
        return 0;
    }

    # Open and parse the config file.
    if (!open(FILE, $conffile)) {
        &wprint("Could not open file $conffile:  $!\n");
        return undef;
    }
    &dprint("Reading $conffile...\n");
    while (my $line = <FILE>) {
        my ($key, $op, $value);
        my @values;

        chomp($line);
        $line =~ s/(^\s*|\s+)#.*//;
        if ($line =~ /^\s*$/) {
            next;
        }

        # Key/Value pairs are separated by an equal sign ('=').
        # Whitespace surrounding the '=' is ignored.  Values are
        # separated by commas and/or whitespace.  ALL embedded
        # whitespace must be quoted, regardless of commas.  Any empty
        # values must also be quoted.  Leading whitespace continues
        # the previous line.
        if ($line =~ /^\s*([^+=]*[^+=\s])\s*(\+?=)\s*(.*)$/) {
            ($key, $op, $value) = ($1, $2, $3);
        } elsif ($line =~ /^\s+(\S.*)$/) {
            ($key, $op, $value) = ($last_key, "+=", $1);
        } else {
            dprint("Line $. unparseable:  \"$line\"\n");
            next;
        }
        if (length($value) == 0) {
            @values = ("");
        } else {
            @values = grep { defined($_) } &parse_line('\s*,\s*', 0, $value);
        }
        &dprintf("Parsing %s:$.:  \"%s\" %s \"%s\" (%d)\n", $conffile,
                 $key, $op, join("\" \"", @values), scalar(@values));
        if ($op eq "+=") {
            if (!exists($cache{$conffile}{$key}) && $self->get($key)) {
                push(@{$cache{$conffile}{$key}}, $self->get($key));
            }
            push(@{$cache{$conffile}{$key}}, @values);
        } else {
            @{$cache{$conffile}{$key}} = @values;
        }
        $last_key = $key;
    }
    close(FILE);

    # Populate the object from the newly-cached config file data.
    $self->set($cache{$conffile});
    #foreach my $key (keys(%{$cache{$conffile}})) {
    #    $self->set($key, @{$cache{$conffile}{$key}});
    #}

    return 1;
}



1;
