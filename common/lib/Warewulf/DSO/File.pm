# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: File.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::DSO::File;

use Warewulf::DSO;
use Warewulf::File;

our @ISA = ('Warewulf::DSO');

push(@Warewulf::File::ISA, 'Warewulf::DSO::File');


=head1 NAME

Warewulf::File - Warewulf's general object instance object interface.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::File;
    use Warewulf::DSO::File;

    my $obj = Warewulf::File->new();

    my $type = $obj->type();
    my @lookups = $obj->lookups();

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

    return "file";
}


sub
lookups($)
{
    my $self = shift;

    return ("_ID", "NAME", "LANG", "PATH", "FORMAT");
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
