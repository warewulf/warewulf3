# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: ParallelCmd.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::ParallelCmd;

use IO::Select;
use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::Logger;

our @ISA = ('Warewulf::Object');

=head1 NAME

Warewulf::ParallelCmd - A parallel command implementation library for Warewulf.

=head1 SYNOPSIS

    use Warewulf::ParallelCmd;

    my $o = Warewulf::ParallelCmd->new();
    $o->fanout(4);
    $o->wtime(8);
    $o->ktime(10);
    $o->queue("ping -c 20 www.yahoo.com");
    for (my $i=1; $i<= 4; $i++) {
        $o->queue("sleep 5");
    }
    $o->queue("ping -c 20 www.google.com");
    $o->run();

=head1 DESCRIPTION

An object oriented framework to run parallel commands

=head1 METHODS

=over 4

=item new()

The new method is the constructor for this object.  It will create an
object instance and return it to the caller.

=cut

sub
new($$)
{
    my ($proto, @args) = @_;
    my $class = ref($proto) || $proto;
    my $self;

    $self = $class->SUPER::new();
    bless($self, $class);

    return $self;
}

sub
init()
{
    my ($self) = @_;
    my $select = IO::Select->new();
    my $queueset = Warewulf::ObjectSet->new();

    $self->set("select", $select);
    $self->set("queueset", $queueset);
    $self->set("fanout", 32);

    return($self);
}

=item queue($command, $output_prefix, $format)

Add a command to the queue to run in parallel. Optionally you can define a
prefix to be appended to all command output and a format string to define the
specific output format (e.g. "%-20s %s").

=cut

sub
queue($$$$)
{
    my ($self, $command, $prefix, $format) = @_;
    my $obj = Warewulf::Object->new();
    my $queueset = $self->get("queueset");

    if ($command =~ /^(.*)$/) {
        &dprint("Adding command to queue: $1\n");
        $obj->set("command", $1);
        $obj->set("prefix", $prefix);
        $obj->set("format", $format);
        $queueset->add($obj);
    } else {
        &eprint("Illegal characters in command: $command\n");
        return undef;
    }

    return 1;
}

=item fanout()

Number of processes to spawn in parallel. (default=32)

=cut

sub
fanout($$)
{
    my $self = shift;

    return $self->prop("fanout", qr/^([0-9]+)$/, @_);
}


=item wtime()

How many seconds to wait before throwing a warning to the user that a command is
still running. If undefined, no warning will be given.

=cut

sub
wtime($$)
{
    my $self = shift;

    return $self->prop("wtime", qr/^([0-9]+)$/, @_);
}


=item ktime()

How many seconds to wait before killing the processes. If undefined, the
process will wait indefinitely.

=cut

sub
ktime($$)
{
    my $self = shift;

    return $self->prop("ktime", qr/^([0-9]+)$/, @_);
}

=item pad()

How many seconds to wait before spawning the next command.

=cut

sub
pad($$)
{
    my $self = shift;

    return $self->prop("pad", qr/^([0-9]+)$/, @_) || 0;
}


=item pcount()

How many processes are running

=cut

sub
pcount($$)
{
    my ($self, $increment) = @_;

    if ($increment and $increment =~ /^\+([0-9]+)$/) {
        $self->set("pcount", ($self->get("pcount") || 0) + $1);
    } elsif ($increment and $increment =~ /^\-([0-9]+)$/) {
        $self->set("pcount", ($self->get("pcount") || 0) - $1);
    }

    return $self->get("pcount") || 0;
}


=item run()

Run the queued commands

=cut

sub
run($)
{
    my ($self) = @_;
    my $select = $self->get("select");
    my $queueset = $self->get("queueset");
    my $fanout = $self->fanout();
    my @queueobjects = $queueset->get_list();
    my $time = time;
    my $timer = 1;

    # Spawning the initial fanout within the queue
    while ($self->pcount() < $fanout && @queueobjects) {
        $self->forkobj(shift(@queueobjects));
    }

    while ($self->pcount() > 0) {
        my $timeleft = $timer+$time - time;
        &dprint("can_read($timeleft) engaged\n");
        my @ready = $select->can_read($timeleft);
        $time = time;
        if (scalar(@ready)) {
            &dprint("got FH activity\n");
            foreach my $fh (@ready) {
                my $buffer;
                my $length;

                do {
                    my $tmp;
                    $length = $fh->sysread($tmp, 1024) || 0;
                    $buffer .= $tmp;
                } while ( $length == 1024 );

                if ($buffer) {
                    my $fileno = $fh->fileno();
                    my $obj = $queueset->find("fileno", $fileno);
                    if ($obj) {
                        my $prefix = $obj->get("prefix");
                        my $format = $obj->get("format");
                        foreach my $line (split(/\n/, $buffer)) {
                            if ($prefix and $format) {
                                printf($format, $prefix, $line);
                            } elsif ($prefix) {
                                print "$prefix$line\n";
                            } else {
                                print "$line\n";
                            }
                        }
                    }

                } else {
                    $self->closefh($fh);
                }
            }
        }

        &dprint("Invoking the timer\n");
        $self->timer();

        while ($self->pcount() < $fanout && @queueobjects) {
            &dprint("Forking another command\n");
            $self->forkobj(shift(@queueobjects));
        }

        &dprint("Finished main loop\n");
    }
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

sub
forkobj($)
{
    my ($self, $obj) = @_;
    my $select = $self->get("select");
    my $command = $obj->get("command");
    my $pad = $self->pad();
    my $fh;
    my $pid;

#TODO: At some point capture STDERR seperately and print properly
    &dprint("Spawning command: $command\n");
    $pid = open($fh, '-|');  # Fork off child process securely.
    if (!defined($pid)) {
        # Disaster
        &wprint("Unable to spawn command ($command):  $!\n");
        return 0;
    } elsif ($pid) {
        # Parent
        $select->add($fh);

        &dprint("Created fileno: ". $fh->fileno() ."\n");

        $obj->set("fh", $fh);
        $obj->set("fileno", $fh->fileno());
        $obj->set("starttime", time());
        $obj->set("pid", $pid);
        $self->pcount("+1");
        $self->set("lasttime", time());
        return 1;
    } else {
        if ($pad) {
            &dprint("Padding/sleeping by: $pad\n");
            sleep $pad;
        }
        # Child
        # Securely pass $command intact to shell
        close(STDERR);
        open(STDERR, ">&STDOUT");
        exec("/bin/sh", "-c", $command);
        die("Unable to execute $command -- $!");
    }
}

sub
closefh($)
{
    my ($self, $fh) = @_;
    my $queueset = $self->get("queueset");
    my $select = $self->get("select");
    my $fileno = $fh->fileno();

    &dprint("Closing fileno: $fileno\n");

    my $obj = $queueset->find("fileno", $fileno);
    if ($obj) {
        &dprint("closing out fileno: $fileno\n");

        $select->remove($fh);
        $fh->close();
        $obj->set("done", "1");
        $obj->del("fileno");
        $self->pcount("-1");
    } else {
        &wprint("Could not resolve fileno: $fileno\n");
    }
}

sub
timer($)
{
    my ($self) = @_;
    my $queueset = $self->get("queueset");
    my $curtime = time();
    my $wtime = $self->wtime();
    my $ktime = $self->ktime();

    foreach my $obj ($queueset->get_list()) {
        my $starttime = $obj->get("starttime");
        my $fileno = $obj->get("fileno");
        my $command = $obj->get("command");
        my $warning = $obj->get("warning");
        my $pid = $obj->get("pid");
        if (! $obj->get("done") and $fileno ) {
            if (! $warning and $wtime and $curtime > ($starttime + $wtime)) {
                my $prefix = $obj->get("prefix");
                if ($prefix) {
                    &wprint("$prefix Process $pid still running ($command)\n");
                } else {
                    &wprint("Process $pid still running ($command)\n");
                }
                $obj->set("warning", 1);
            } elsif ($ktime and $curtime > ($starttime + $ktime)) {
                my $prefix = $obj->get("prefix");
                my $fh = $obj->get("fh");
                if ($prefix) {
                    &wprint("$prefix Killing process $pid ($command)\n");
                } else {
                    &wprint("Killing process $pid ($command)\n");
                }
                kill("TERM", $pid);
                kill("INT", $pid);
                kill("KILL", $pid);
                $self->closefh($fh);
            }
        }
    }
}

1;
