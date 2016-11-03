# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Vnfs;

use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use File::Basename;
use File::Path;
use Digest::MD5 qw(md5_hex);



our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Vnfs - Warewulf's general object instance object interface.

=head1 ABOUT

This is the primary Warewulf interface for dealing with files within the
Warewulf DataStore.

=head1 SYNOPSIS

    use Warewulf::Vnfs;

    my $obj = Warewulf::Vnfs->new();

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

Get or set the name of this vnfs object.

=cut

sub
name()
{
    my $self = shift;

    return $self->prop("name", qr/^([a-zA-Z0-9_\.\-]+)$/, @_);
}


=item checksum($string)

Get or set the checksum of this vnfs.

=cut

sub
checksum()
{
    my $self = shift;

    return $self->prop("checksum", qr/^([a-zA-Z0-9]+)$/, @_);
}


=item chroot($string)

Get or set the chroot location of this vnfs.

=cut

sub
chroot()
{
    my $self = shift;

    return $self->prop("chroot", qr/^([a-zA-Z0-9\/\.\-_]+)$/, @_);
}



=item size($string)

Set or return the size of the raw file stored within the data store.

=cut

sub
size()
{
    my $self = shift;

    return $self->prop("size", qr/^([0-9]+)$/, @_);
}




=item vnfs_import($file)

Import a VNFS image at the defined path into the data store directly. This
will interact directly with the DataStore because large file imports may
exhaust memory.

Note: This will also update the object metadata for this file.

=cut

sub
vnfs_import()
{
    my ($self, $path) = @_;

    my $id = $self->id();

    if (! $id) {
        &eprint("This object has no ID!\n");
        return();
    }

    if ($path) {
        if ($path =~ /^([a-zA-Z0-9_\-\.\/]+)$/) {
            if (-f $path) {
                my $db = Warewulf::DataStore->new();
                my $binstore = $db->binstore($id);
                my $import_size = 0;
                my $buffer;
                my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($path);

                if (open(FILE, $path)) {
                    while(my $length = sysread(FILE, $buffer, $db->chunk_size())) {
                        &dprint("Chunked $length bytes of $path\n");
                        $binstore->put_chunk($buffer);
                        $import_size += $length;
                    }
                    close FILE;

                    if ($import_size) {
                        $self->size($import_size);
                        $self->checksum(digest_file_hex_md5($path));
                        $db->persist($self);
                    } else {
                        &eprint("Could not import file!\n");
                    }
                } else {
                    &eprint("Could not open file: $!\n");
                }
            } else {
                &eprint("File not found: $path\n");
            }
        } else {
            &eprint("Invalid characters in file name: $path\n");
        }
    }
}



=item vnfs_export($path)

Export the VNFS from the data store to a location on the file system.

=cut

sub
vnfs_export()
{
    my ($self, $file) = @_;

    if ($file and $file =~ /^([a-zA-Z0-9\._\-\/]+)$/) {
        $file = $1;
        my $db = Warewulf::DataStore->new();
        if (! -f $file) {
            my $dirname = dirname($file);

            if (! -d $dirname) {
                mkpath($dirname);
            }
        }

        my $binstore = $db->binstore($self->id());
        if (open(FILE, "> $file")) {
            while(my $buffer = $binstore->get_chunk()) {
                print FILE $buffer;
            }
            close FILE;
        } else {
            &eprint("Could not open file for writing: $!\n");
        }
    }
}



=back

=head1 SEE ALSO

Warewulf::Object Warewulf::DSO::Vnfs

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
