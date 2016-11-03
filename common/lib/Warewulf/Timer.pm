# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: Timer.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::Timer;

use Storable ('dclone');
use Warewulf::Object;
use Warewulf::Logger;
use Warewulf::Util;
use Time::HiRes ("gettimeofday", "usleep");

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::Timer - Warewulf's generic object class and the ancestor of
all other classes.

=head1 SYNOPSIS

    use Warewulf::Timer;

    my $t = Warewulf::Timer;
    $t->start();
    sleep 1;
    print $t->elapsed("d") ."\n";
    sleep 2;
    print $t->elapsed() ."\n";


=head1 DESCRIPTION

C<Warewulf::Timer> is a simple Warewulf class to keep track of process time.

=head1 METHODS

=over 4

=item new()

Instantiate an object.  Any initializer accepted by the C<set()>
method may also be passed to C<new()>.

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


=item start()

Start, reset or continue timer.

=cut

sub
start(@)
{
    my $self = shift;

    # I don't think set() is honoring the float here... need to evaluate.
    # $self->set("starttime", gettimeofday());
    $self->{"STARTTIME"} = gettimeofday();

    return $self;
}


=item reset()

Reset the timer.

=cut

sub
reset(@)
{
    my $self = shift;

    $self->del("starttime");
    $self->del("stoptime");
    $self->del("elapsed");

    return $self;
}


=item elapsed($format)

Return how much time has elapsed in total using $format (default is ".2f").

=cut

sub
elapsed(@)
{
    my $self = shift;
    my $format = shift || ".2f";
    my $start = $self->get("starttime");
    my $ret_time = 0;

    if ( $start ) {
        $ret_time = gettimeofday() - $start;
    }

    return sprintf("%$format", $ret_time);
}


=item mark($format)

Return how much time has elapsed in since the last mark using $format (default is ".2f").

=cut

sub
mark(@)
{
    my $self = shift;
    my $format = shift || ".2f";
    my $mark = $self->get("marktime") || $self->get("starttime");
    my $current = gettimeofday();
    my $ret_time = 0;

    if ( $mark ) {
        $ret_time = $current - $mark;
    }

    $self->set("marktime", $current);

    return sprintf("%$format", $ret_time);
}



=back

=head1 SEE ALSO

Warewulf::Object

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2014, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut

1;
