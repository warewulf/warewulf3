# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::File;

use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use Warewulf::EventHandler;
use File::Basename;
use File::Path;
use Digest::MD5;
use Fcntl ':mode';

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::File - Warewulf's general object instance object interface.

=head1 ABOUT

This is the primary Warewulf interface for dealing with files within the
Warewulf DataStore.

=head1 SYNOPSIS

    use Warewulf::File;

    my $obj = Warewulf::File->new();

=head1 METHODS

=over 12

=cut

=item new()

The new constructor will create the object that references configuration the
stores.

=cut

sub
new($$)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = ();

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self->init(@_);
}


=item name($string)

Set or return the name of this object. The string "UNDEF" will delete this
key from the object.

=cut

sub
name()
{
    my $self = shift;
    
    return $self->prop("name", qr/^([[:print:]]+)$/, @_);
}


=item mode($bits)

Set the numeric permission "mode" of this file (e.g. 0644).

=cut

sub
mode()
{
    my $self = shift;
    #my $validator = sub {
    #    if ($_[0] =~ /^(\d+)$/) {
    #        return S_IMODE($1);
    #    } else {
    #        return 0;
    #    };

    #return $self->prop("mode", $validator, @_);

    # The below basically does the same thing as the above, just faster.
    return $self->prop("mode", sub { return (keys %{ +{S_IMODE($_[0]),1} })[0] || 0; }, @_) || 0640;
}


=item modestring()

Returns the file permissions in string form.

=cut

sub
modestring()
{
    my $self = shift;
    my $mode = $self->mode() || 0;
    my $str = "";

    $str .= (($mode & S_IRUSR) ? ('r') : ('-'));
    $str .= (($mode & S_IWUSR) ? ('w') : ('-'));
    if ($mode & S_ISUID) {
        $str .= (($mode & S_IXUSR) ? ('s') : ('S'));
    } else {
        $str .= (($mode & S_IXUSR) ? ('x') : ('-'));
    }
    $str .= (($mode & S_IRGRP) ? ('r') : ('-'));
    $str .= (($mode & S_IWGRP) ? ('w') : ('-'));
    if ($mode & S_ISGID) {
        $str .= (($mode & S_IXGRP) ? ('s') : ('S'));
    } else {
        $str .= (($mode & S_IXGRP) ? ('x') : ('-'));
    }
    $str .= (($mode & S_IROTH) ? ('r') : ('-'));
    $str .= (($mode & S_IWOTH) ? ('w') : ('-'));
    if ($mode & S_ISVTX) {
        $str .= (($mode & S_IXOTH) ? ('t') : ('T'));
    } else {
        $str .= (($mode & S_IXOTH) ? ('x') : ('-'));
    }
    return $str;
}


=item filetype($bits)

Set the numeric file type of this file (e.g. 020000).

=cut

sub
filetype()
{
    my $self = shift;
    #my $validator = sub {
    #    if ($_[0] =~ /^(\d+)$/) {
    #        return S_IFMT($1);
    #    } else {
    #        return 0;
    #    };

    #return $self->prop("filetype", $validator, @_);

    # The below basically does the same thing as the above, just faster.
    return $self->prop("filetype", sub { return (keys %{ +{S_IFMT($_[0]),1} })[0] || S_IFREG; }, @_) || S_IFREG;
}


=item filetypestring()

Return the file type in string form

=cut

sub
filetypestring()
{
    my $self = shift;
    my $ftype = $self->filetype();

    if (S_ISDIR($ftype)) {
        return 'd';
    } elsif (S_ISLNK($ftype)) {
        return 'l';
    } elsif (S_ISBLK($ftype)) {
        return 'b';
    } elsif (S_ISCHR($ftype)) {
        return 'c';
    } elsif (S_ISFIFO($ftype)) {
        return 'p';
    } elsif (S_ISSOCK($ftype)) {
        return 's';
    } else {
        return '-';
    }
}


=item checksum($string)

Set or get the checksum of this file.

=cut

sub
checksum()
{
    my $self = shift;

    if (!scalar(@_) && !defined($self->get("checksum"))) {
        @_ = (Digest::MD5->new()->hexdigest());
    }
    return $self->prop("checksum", qr/^([a-z0-9]+)$/, @_);
}


=item uid($string)

Set or return the UID of this file.

=cut

sub
uid()
{
    my $self = shift;
    
    return $self->prop("uid", qr/^(\d+)$/, @_) || 0;
}


=item gid($string)

Set or return the GID of this file.

=cut

sub
gid()
{
    my $self = shift;
    
    return $self->prop("gid", qr/^(\d+)$/, @_) || 0;
}


=item size($string)

Set or return the size of the raw file stored within the data store.

=cut

sub
size()
{
    my $self = shift;
    
    return $self->prop("size", qr/^(\d+)$/, @_);
}



=item path($string)

Set or return the file system path of this file.

=cut

sub
path()
{
    my $self = shift;
    
    return $self->prop("path", qr/^(\/.+)$/, @_);
}


=item format($string)

Set or return the format of this file.

=cut

sub
format()
{
    my $self = shift;
    
    return $self->prop("format", qr/^([a-z]+)$/, @_);
}


=item interpreter($string)

Set or return the interpreter needed to parse this file

=cut

sub
interpreter()
{
    my $self = shift;
    
    return $self->prop("interpreter", qr/^(\/.+)$/, @_);
}



=item origin(@strings)

Set or return the origin(s) of this object. "UNDEF" will delete all data.

=cut

sub
origin()
{
    my ($self, @strings) = @_;
    my $key = "origin";

    if (@strings) {
        my $name = $self->get("name");
        if (defined($strings[0])) {
            my @neworigins;
            foreach my $string (@strings) {
                if ($string =~ /^(.+)$/) {
                    &dprint("Object $name set $key += '$1'\n");
                    push(@neworigins, $1);
                } else {
                    &eprint("Invalid characters to set $key = '$string'\n");
                }
            }
            $self->set($key, @neworigins);
        } else {
            $self->del($key);
            &dprint("Object $name del $key\n");
        }
    }

    return $self->get($key);
}


=item sync()

Resync any file objects to their origin on the local file system. This will
persist immediately to the DataStore.

Note: This will also update some metadata for this file.

=cut

sub
sync()
{
    my ($self) = @_;
    my $name = $self->name();
    my ($event, $event_name);

    if ($self->origin()) {
        my $db = Warewulf::DataStore->new();
        my $binstore = $db->binstore($self->id());
        my ($total_len, $cur_len, $start, $data) = (0, 0, 0, "");
        my $digest;

        &dprint("Syncing file object: $name\n");
        foreach my $origin ($self->origin()) {
            my $filetype = $self->filetype();
            my @statinfo = ((S_ISLNK($filetype)) ? (lstat($origin)) : (stat($origin)));

            if (S_ISREG($filetype)) {

                if ($origin =~ /^.+\|\s*$/) {
                    if (open(PIPE, $origin)) {
                        &dprint("   running code pipe as origin: $origin\n");
                        while (my $line = <PIPE>) {
                            $data .= $line;
                        }
                        if (! close PIPE) {
                            &eprint("Error running code pipe for file objct \"$name\"\n");
                        }
                    } else {
                        &wprint("Could not open origin path \"$origin\" for file object \"$name\" -- $!\n");
                    }
                } elsif (-f _) {
                    if (open(FILE, $origin)) {
                        &dprint("   Including file to sync: $origin\n");
                        while (my $line = <FILE>) {
                            $data .= $line;
                        }
                        close FILE;
                    } else {
                        &wprint("Could not open origin path \"$origin\" for file object \"$name\" -- $!\n");
                    }
                } else {
                    &wprint("Origin path \"$origin\" for file object \"$name\" does not exist is not a regular file; skipping.\n");
                }
            } elsif (S_ISLNK($filetype)) {
                if (-l _) {
                    $data = readlink($origin);
                } else {
                    $data = $origin;
                }
            } elsif (S_ISBLK($filetype) && -b _) {
                $data = $statinfo[6];
            } elsif (S_ISCHR($filetype) && -c _) {
                $data = $statinfo[6];
            }
        }

        &dprint("Persisting file object \"$name\"\n");
        $total_len = length($data);
        $digest = Digest::MD5->new()->add($data);
        
        my $was_stored = 1;
        
        while ($total_len > $cur_len) {
            my $buffer = substr($data, $start, $db->chunk_size());

            if ( ! $binstore->put_chunk($buffer) ) {
                $was_stored = 0;
                last;
            }
            $start += $db->chunk_size();
            $cur_len += length($buffer);
            &dprint("Chunked $cur_len of $total_len\n");
        }
        if ( $was_stored ) {
            $self->checksum($digest->hexdigest());
            $self->size($total_len);
            $db->persist($self);
        } else {
            &eprint("Failure:  only wrote $cur_len of $total_len bytes to binstore\n");
        }
    } else {
        &dprint("Skipping file object \"$name\" as it has no origin paths set\n");
    }

    # Trigger file::$name.sync event for special behaviors
    # (i.e. warewulf-provision's dynamic_hosts)
    $event = Warewulf::EventHandler->new();
    $event_name = "file::$name.sync";
    $event->handle($event_name, ());
    &dprint("Triggered event $event_name\n");
}


=item file_import($file)

Import a file at the defined path into the data store directly. This will
interact directly with the DataStore because large file imports may
exhaust memory.

Note: This will also update the object metadata for this file.

=cut

sub
file_import()
{
    my ($self, $path) = @_;
    my $id = $self->id();
    my @statinfo;
    my $db = Warewulf::DataStore->new();
    my $binstore = $db->binstore($id);
    my ($import_size, $format) = (0, "");
    my ($buffer, $digest);
    local *FILE;
    my $was_stored = 1;

    if (! $id) {
        &eprint("This object has no ID!\n");
        return undef;
    } elsif (! $path) {
        return undef;
    }

    if ($path =~ /^(\/.+)$/) {
        $path = $1;
    } else {
        &eprint("Import filename contains illegal characters.\n");
        return undef;
    }

    @statinfo = lstat($path);
    $digest = Digest::MD5->new();
    if (! -e _) {
        &eprint("File not found: $path\n");
        return undef;
    } elsif (-f _) {
        my $length;
        
        if (!open(FILE, $path)) {
            &eprint("Could not open import file \"$path\" for reading:  $!\n");
            return undef;
        }
        while ($length = sysread(FILE, $buffer, $db->chunk_size())) {
            if ($import_size == 0) {
                if ($buffer =~ /^#!\/bin\/sh/) {
                    $format = "shell";
                } elsif ($buffer =~ /^#!\/bin\/bash/) {
                    $format = "bash";
                } elsif ($buffer =~ /^#!\/[a-zA-Z0-9\/_\.]+\/perl/) {
                    $format = "perl";
                } elsif ($buffer =~ /^#!\/[a-zA-Z0-9\/_\.]+\/python/) {
                    $format = "python";
                } else {
                    $format = "data";
                }
            }
            &dprint("Chunked $length bytes of $path\n");
            if ( ! $binstore->put_chunk($buffer) ) {
                $was_stored = 0;
                last;
            }
            $digest->add($buffer);
            $import_size += $length;
        }
        if (!$was_stored || (!defined($length) && (! $import_size))) {
            &eprint("Unable to import $path:  $!\n");
            return undef;
        }
        close FILE;
    } elsif (-l _) {
        my $target = readlink($path);

        $format = "link";
        &dprint("Importing symlink:  $path -> $target\n");
        if ( $binstore->put_chunk($target) ) {
            $digest->add($target);
            $import_size += length($target);
        } else {
            $was_stored = 0;
        }
    } elsif (-b _ || -c _) {
        my ($major, $minor) = ($statinfo[6] >> 8, $statinfo[6] & 0xff);

        $format = "block";
        &dprintf("Importing %s special device $path:  0x%02x (%d), 0x%02x (%d)\n",
                 ((-b _) ? ("block") : ("character")), $major, $major, $minor, $minor);
        if ( $binstore->put_chunk($statinfo[6]) ) {
            $digest->add($statinfo[6]);
            $import_size += length($statinfo[6]);
        } else {
            $was_stored = 0;
        }
    } elsif (-d _) {
        my $target = $path;

        $format = "directory";
        &dprint("Importing directory: $path\n");
        if ( $binstore->put_chunk($target) ) {
            $digest->add($target);
            $import_size += length($target);
        } else {
            $was_stored = 0;
        }
    } else {
        &dprintf("Importing %s $path\n",
                 ((S_ISFIFO($statinfo[2]))
                  ? ("FIFO (named pipe)")
                  : ((S_ISSOCK($statinfo[2]))
                     ? ("UNIX socket")
                     : ("<unknown type>"))));
    }
    if ( $was_stored ) {
        $self->mode($statinfo[2]);
        $self->filetype($statinfo[2]);
        $self->size($import_size);
        $self->checksum($digest->hexdigest());
        $self->format($format);
        if ( ! $db->persist($self) ) {
            &eprint("Unable to persist $path\n");
            return undef;
        }
    }
    return $import_size;
}


=item file_export($path)

Export the data from a File object to a location on the filesystem.

=cut

sub
file_export()
{
    my ($self, $path) = @_;
    my $db = Warewulf::DataStore->new();
    my $binstore = $db->binstore($self->id());
    local *FILE;

    if (! $path) {
        &eprint("Cannot export file to empty path.\n");
        return undef;
    }
    if ($path =~ /^(\/.+)$/) {
        $path = $1;
        if (! -f $path) {
            mkpath(dirname($path), 0, 0750);
        }

        if (!open(FILE, '>' . $path)) {
            &eprint("Could not open file $path for writing:  $!\n");
            return undef;
        }
        while (my $buffer = $binstore->get_chunk()) {
             if (!defined(syswrite(FILE, $buffer))) {
                &eprint("Error writing data to file $path:  $!\n");
                close(FILE);
                return undef;
            }
        }
        if (!close(FILE)) {
            &eprint("Error closing file $path after write:  $!\n");
            return undef;
        }
        chmod((0400 || $self->mode()), $path);
        return 0;
    } else {
        &eprint("Export location must be absolute path.\n");
        return undef;
    }
}


=item canonicalize()

Check and update the object if necessary. Returns the number of changes made.

=cut

sub
canonicalize()
{
    my ($self) = @_;
    my $changes = 0;

    if (!exists($self->{"filetype"})) {
        $self->filetype(S_IFREG);
        $changes++;
    }
    return $changes;
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
