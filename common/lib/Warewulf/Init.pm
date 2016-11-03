# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2016, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Config.pm 577 2011-08-11 23:41:04Z mej $
#

package Warewulf::Init;

=head1 NAME

Warewulf::Init - Warewulf base initialization and sanitization

=head1 SYNOPSIS

    use Warewulf::Init;

=head1 DESCRIPTION

This module simply runs any early Warewulf initialization and sanitization
functions when the module loads.

=cut


delete($ENV{"BASH_ENV"});


=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
