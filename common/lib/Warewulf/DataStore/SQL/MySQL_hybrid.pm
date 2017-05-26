# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id$
#

package Warewulf::DataStore::SQL::MySQL_hybrid;

use Warewulf::Config;
use Warewulf::Logger;
use Warewulf::DSO;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::EventHandler;

# We're subclassing the MySQL class:
use parent 'Warewulf::DataStore::SQL::MySQL';

=head1 NAME

Warewulf::DataStore::SQL::MySQL_hybrid - MySQL Database (file-based binstore) interface to Warewulf

=head1 SYNOPSIS

    use Warewulf::DataStore::SQL::MySQL_hybrid;

=head1 DESCRIPTION

    This class should not be instantiated directly.  It is intended to be
    treated as an opaque implementation of the DB interface.

    This class creates a persistant singleton for the application runtime
    which will maintain a consistant database connection from the time that
    the object is constructed.
    
    Documentation for each function should be found in the top level
    Warewulf::DataStore documentation. Any implementation specific documentation
    can be found here.

=cut


sub
init()
{
    my $self = shift;
    
    $self = $self->SUPER::init(@_);
    if ( defined($self) ) {
        my $config = Warewulf::Config->new("database.conf");
        my $bin_dir = $config->get("binstore path");
        
        # Validate the binstore path:
        if ( ! $bin_dir ) {
            $bin_dir = '/var/lib/warewulf/binstore';
        }
        if ( ! -d $bin_dir ) {
            &wprint("binstore path does not exist: $bin_dir\n");
            return undef;
        }
        $self->{"BINSTORE_PATH"} = $bin_dir;
        
        # If no explicit chunk size was provided, default to 8 MB:
        if ( ! exists($self->{"DATABASE_CHUNK_SIZE"}) ) {
            $self->{"DATABASE_CHUNK_SIZE"} = 8 * 1024 * 1024;
        }
    }
    
    return $self;
}

sub
del_object_impl($$)
{
    my ($self, $object) = @_;
    
    $self->SUPER::del_object_impl($object);
    
     # Delete the file from disk:
    my($path) = $self->{"BINSTORE_PATH"} . '/' . $object->get('_id');
    if ( -f $path ) {
        if ( ! unlink($path) ) {
            &wprint("Unable to remove file from binstore: $path\n");
        }
    }
}

=item binstore($object_id);

Return a binstore object for the given object ID. The binstore object can have
data put or gotten (put_chunk or get_chunk methods respectively) from this
object.

=cut

sub
binstore()
{
    my ($self, $object_id) = @_;
    my $class = ref($self);
    my $dsh = $self->SUPER::binstore($object_id);
    
    $dsh->{"BINSTORE_PATH"} = $self->{"BINSTORE_PATH"};
    $dsh->{"OBJECT_PATH"} = $self->{"BINSTORE_PATH"} . '/' . $object_id;
    
    my $period = 0;
    while ( -f $dsh->{"OBJECT_PATH"} . '.new' ) {
        $period += 10;
        &wprintf("update of object $object_id (" . $dsh->{"OBJECT_PATH"} . ".new) already in progress, waiting " . $period . " seconds...\n");
        sleep($period);
    }
    
    return bless($dsh, $class);
}


=item DESTROY();

Object destructor; close any open files.

=cut

sub
DESTROY()
{
    my $self = shift;
    
    if ( exists($self->{"OUT_FILEH"}) ) {
        close($self->{"OUT_FILEH"});
        # Rename to atomically replace:
        rename($self->{"OBJECT_PATH"} . '.new', $self->{"OBJECT_PATH"});
    }
    if ( exists($self->{"IN_FILEH"}) ) {
        close($self->{"IN_FILEH"});
    }
}


=item put_chunk_impl($buffer);

Put data into the binstore object one chunk at a time. Iterate through the
entire datastream until all data has been added.

=cut

sub
put_chunk_impl()
{
    my ($self, $buffer) = @_;
    my ($rc, $path);
    
    if (!exists($self->{"OUT_FILEH"})) {
        $path = $self->{"OBJECT_PATH"} . '.new';
        if ( ! open($self->{"OUT_FILEH"}, '>' . $path) ) {
            &eprintf("put_chunk() failed while opening file for write: $path\n");
            return 0;
        }
        binmode $self->{"OUT_FILEH"};
        &dprint("FILE OP: WRITE TO binstore($self->{OBJECT_ID}) => $path\n");
    }

    $rc = syswrite($self->{"OUT_FILEH"}, $buffer);
    if ( ! defined($rc) ) {
        &eprintf("put_chunk() failed while writing $path ($!)\n");
        return 0;
    }
    return 1;
}


=item get_chunk_impl();

Get all of the data out of the binstore object one chunk at a time.

=cut

sub
get_chunk_impl()
{
    my ($self) = @_;
    my ($byte_count) = $self->chunk_size();
    my ($buffer, $rc);

    if (!exists($self->{"IN_FILEH"})) {
        if ( ! -f $self->{"OBJECT_PATH"} || ! -r $self->{"OBJECT_PATH"} || ! open($self->{"IN_FILEH"}, '<' . $self->{"OBJECT_PATH"}) ) {
            &eprintf("put_chunk() failed while opening file for read: $self->{OBJECT_PATH}\n");
            return 0;
        }
        binmode $self->{"IN_FILEH"};
        &dprint("FILE OP: READ FROM binstore($self->{OBJECT_ID}) <= $self->{OBJECT_PATH}\n");
    }

    $rc = sysread($self->{"IN_FILEH"}, $buffer, $byte_count);
    if ( ! defined($rc) ) {
        &eprintf("get_chunk() failed while reading: $!\n");
        return 0;
    }
    return $buffer;
}



=back

=head1 SEE ALSO

Warewulf::ObjectSet Warewulf::DataStore

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

