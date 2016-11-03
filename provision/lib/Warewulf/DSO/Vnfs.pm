# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2012, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Vnfs.pm 689 2011-12-20 00:34:04Z gmk $
#

package Warewulf::DSO::Vnfs;

use Warewulf::DSO;
use Warewulf::Vnfs;

our @ISA = ('Warewulf::DSO');

push(@Warewulf::Vnfs::ISA, 'Warewulf::DSO::Vnfs');

=head1 NAME

Warewulf::DSO::Vnfs - DSO extentions to the Warewulf::Vnfs object type.

=head1 ABOUT

Warewulf object types that need to be persisted via the DataStore need to have
various extentions so they can be persisted. This module enhances the object
capabilities.

=head1 SYNOPSIS

    use Warewulf::Vnfs;
    use Warewulf::DSO::Vnfs;

    my $obj = Warewulf::Vnfs->new();

    my $type = $obj->type();
    my @lookups = $obj->lookups();

    my $s = $obj->serialize();

    my $objCopy = Warewulf::DSO->unserialize($s);


=head1 METHODS

=over 12

=cut

=item type()

Return a string that defines this object type as it will be stored in the
data store.

=cut

sub
type($)
{
    my $self = shift;

    return("vnfs");
}


sub
lookups($)
{
    my $self = shift;

    return("_ID", "NAME");
}



=back

=head1 SEE ALSO

Warewulf::DSO, Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2012, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
