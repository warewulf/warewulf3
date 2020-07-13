# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#

package Warewulf::Bootstrap;

use Warewulf::ACVars;
use Warewulf::Config;
use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::DataStore;
use Warewulf::Util;
use File::Basename;
use File::Path qw(make_path);
use Digest::MD5 qw(md5_hex);
use POSIX qw(uname);


our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Bootstrap - Warewulf's general object instance object interface.

=head1 ABOUT

This is the primary Warewulf interface for dealing with files within the
Warewulf DataStore.

=head1 SYNOPSIS

    use Warewulf::Bootstrap;

    my $obj = Warewulf::Bootstrap->new();

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

Set or return the name of this object.

=cut

sub
name()
{
    my $self = shift;

    return $self->prop("name", qr/^([a-zA-Z0-9_\.\-]+)$/, @_);
}


=item checksum($string)

Get the checksum of this vnfs.

=cut

sub
checksum()
{
    my $self = shift;

    return $self->prop("checksum", qr/^([a-zA-Z0-9]+)$/, @_);
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


=item arch($string)

Set or return the architecture of the raw file stored within the data store.

=cut

sub
arch()
{
    my $self = shift;

    return $self->prop("arch", qr/^([a-zA-Z0-9_]+)$/, @_);
}

=item bootstrap_import($file)

Import a bootstrap image at the defined path into the data store directly.
This will interact directly with the DataStore because large file imports
may exhaust memory.

Note: This will also update the object metadata for this file.

=cut

sub
bootstrap_import()
{
    my ($self, $path) = @_;
    my (undef, undef, undef, undef, $machine) = POSIX::uname();

    my $id = $self->id();

    if (! $id) {
        &eprint("This object has no ID!\n");
        return();
    }

    if (! $self->arch()) {
        &dprint("This object has no arch, defaulting to current system's arch");
        $self->arch($machine);
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
                    my $was_stored = 1;
                    while(my $length = sysread(FILE, $buffer, $db->chunk_size())) {
                        &dprint("Chunked $length bytes of $path\n");
                        if ( ! $binstore->put_chunk($buffer) ) {
                            $was_stored = 0;
                            last;
                        }
                        $import_size += $length;
                    }
                    close FILE;

                    if ($was_stored && $import_size) {
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



=item bootstrap_export($path)

Export the bootstrap from the data store to a location on the file system.

=cut

sub
bootstrap_export()
{
    my ($self, $file) = @_;

    if ($file) {
        my $db = Warewulf::DataStore->new();
        if (! -f $file) {
            my $dirname = dirname($file);

            if (! -d $dirname) {
                mkpath($dirname);
                make_path($dirname, {
                    chmod => 0755,
                });
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


=item delete_local_bootstrap()

Remove a bootable bootstrap image from the local file system.

=cut

sub
delete_local_bootstrap()
{
    my ($self) = @_;

    if ($self) {
        my $bootstrap_name = $self->get("name") || "UNDEF";
        my $bootstrap_id = $self->get("_id");
        my $arch = $self->get("arch");

        &dprint("Going to delete bootstrap: $bootstrap_name\n");

        if ($bootstrap_id =~ /^([0-9]+)$/ && $arch) {
            my $bootstrap_id = $1;
            my $statedir = &Warewulf::ACVars::get("statedir");
            my $bootstrapdir = "$statedir/warewulf/bootstrap/$arch/$bootstrap_id/";

            &nprint("Deleting local bootable bootstrap files: $bootstrap_name\n");

            if (-f "$bootstrapdir/initfs.gz") {
                if (unlink("$bootstrapdir/initfs.gz")) {
                    &dprint("Removed file: $bootstrapdir/initfs.gz\n");
                } else {
                    &eprint("Could not remove file: $bootstrapdir/initfs.gz\n");
                }
            }
            if (-f "$bootstrapdir/kernel") {
                if (unlink("$bootstrapdir/kernel")) {
                    &dprint("Removed file: $bootstrapdir/kernel\n");
                } else {
                    &eprint("Could not remove file: $bootstrapdir/kernel\n");
                }
            }
            if (-f "$bootstrapdir/cookie") {
                if (unlink("$bootstrapdir/cookie")) {
                    &dprint("Removed file: $bootstrapdir/cookie\n");
                } else {
                    &eprint("Could not remove file: $bootstrapdir/cookie\n");
                }
            }
            if (-d "$bootstrapdir") {
                if (rmdir("$bootstrapdir")) {
                    &dprint("Removed directory: $bootstrapdir\n");
                } else {
                    &eprint("Could not remove directory: $bootstrapdir\n");
                }
            }

        }
    } else {
        &dprint("delete_local_bootstrap() called without an object!\n");
    }
}


=item build_local_bootstrap()

Write the bootstrap image to the $statedir/warewulf directory. This does more then just pull
it out of the data store and dump it to a file. It also merges it with the
appropriate Warewulf initrd userspace components for the provision master in
question.

=cut

sub
build_local_bootstrap()
{
    my ($self) = @_;

    if ($self) {
        my $bootstrap_name = $self->name();
        my $bootstrap_id = $self->id();
        my $arch = $self->arch();
        if (! $arch) {
            (undef, undef, undef, undef, $arch) = POSIX::uname();
            &dprint("No architecture specified for bootstrap $bootstrap_name, default to local system");
        }

        if (!$bootstrap_name) {
            &dprint("Skipping build_bootstrap() as the name is undefined\n");
            return();
        }

        if (! $self->checksum()) {
            &dprint("build_local_bootstrap() returning with nothing to do.\n");
            return();
        }

        if ($bootstrap_id =~ /^([0-9]+)$/) {
            my $bootstrap_id = $1;
            my $ds = Warewulf::DataStore->new();
            my $statedir = &Warewulf::ACVars::get("statedir");
            my $initramfsdir = $statedir . "/warewulf/initramfs/$arch";
            my $randstring = &rand_string("12");
            my $tmpdir = "/var/tmp/wwinitrd.$randstring";
            my $binstore = $ds->binstore($bootstrap_id);
            my $bootstrapdir = "$statedir/warewulf/bootstrap/$arch/$bootstrap_id/";
            my $initramfs = "$initramfsdir/initfs";

            &nprint("Integrating the Warewulf bootstrap: $bootstrap_name\n");

            if (! -d "$initramfsdir") {
                &wprint("Could not locate the initramfs directory for bootstrap's architecture at $initramfsdir, cannot integrate this bootstrap on this host...\n");
                return();
            }

            if (-f "$bootstrapdir/cookie") {
                open(COOKIE, "$bootstrapdir/cookie");
                chomp (my $cookie = <COOKIE>);
                close COOKIE;
                if ($cookie eq $self->checksum()) {
# Lets not return yet, because we don't have a way to force it yet...
#                    return;
                }
            }

            mkpath($tmpdir);
            make_path($bootstrapdir, {
                chmod => 0755,
            });
            chdir($tmpdir);

            &dprint("Opening gunzip/cpio pipe\n");
            open(CPIO, "| gunzip | cpio -id --quiet");
            while(my $buffer = $binstore->get_chunk()) {
                &dprint("Chunking into gunzip/cpio pipe\n");
                print CPIO $buffer;
            }
            close CPIO;

            &dprint("Including capabiltiies into bootstrap\n");
            foreach my $path (glob($initramfsdir . "/capabilities/*")) {
                if ($path =~ /^([a-zA-Z0-9\.\_\-\/]+)$/) {
                    my $file = $1;
                    my $module = basename($file);
                    &nprint("Including capability: $module\n");
                    system("cd $tmpdir/initramfs; cpio -i -u --quiet < $file");
                }
            }
            if (-f "$initramfsdir/base") {
                system("cd $tmpdir/initramfs; cpio -i -u --quiet < $initramfsdir/base");
            } else {
                &eprint("Could not locate the Warewulf bootstrap 'base' capability\n");
                return();
            }


            system("cd $tmpdir/initramfs; find . | cpio -o --quiet -H newc -F $bootstrapdir/initfs");
            &nprint("Compressing the initramfs\n");
            system("gzip -f -9 $bootstrapdir/initfs");
            chmod(0644, "$bootstrapdir/initfs.gz");
            &nprint("Locating the kernel object\n");
            system("cp $tmpdir/kernel $bootstrapdir/kernel");
            chmod(0644, "$bootstrapdir/kernel");
            system("rm -rf $tmpdir");
            open(COOKIE, "> $bootstrapdir/cookie");
            chmod(0644, "$bootstrapdir/cookie");
            print COOKIE $self->checksum();
            close COOKIE;
            &nprint("Bootstrap image '$bootstrap_name' is ready\n");
        } else {
            &dprint("Bootstrap ID is invalid\n");
        }
    } else {
        &dprint("Bootstrap object is undefined\n");
    }

}


=item canonicalize()
Check and update the object if necessary. Returns the number of changes made.
=cut

sub
canonicalize()
{
    my ($self) = @_;
    my (undef, undef, undef, undef, $arch) = POSIX::uname();
    my $changed = 0;

    if (! $self->arch()) {
        &iprint("This bootstrap has no arch define, defaulting to current system's arch");
        $self->arch($arch);
        $changed++;
    }
    return($changed);
}


=back

=head1 SEE ALSO

Warewulf::Object Warewulf::DSO::Bootstrap

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
