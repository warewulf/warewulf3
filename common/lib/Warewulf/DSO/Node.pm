# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Node.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::DSO::Node;

use Warewulf::DSO;
use Warewulf::Node;

our @ISA = ('Warewulf::DSO');

push(@Warewulf::Node::ISA, 'Warewulf::DSO::Node');

=head1 NAME

Warewulf::DSO::Node - DSO extentions to the Warewulf::Node object type.

=head1 ABOUT

Warewulf object types that need to be persisted via the DataStore need to have
various extentions so they can be persisted. This module enhances the object
capabilities.

=head1 SYNOPSIS

    use Warewulf::Node;
    use Warewulf::DSO::Node;

    my $obj = Warewulf::Node->new();

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

    return("node");
}


sub
lookups($)
{
    my $self = shift;

    return("_ID", "_HWADDR", "_IPADDR", "NAME", "CLUSTER", "GROUPS", "MASTER", "FILEIDS");
}



=back

=head1 SEE ALSO

Warewulf::DSO, Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
