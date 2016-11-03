# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2012, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: EventHandler.pm 1654 2014-04-18 21:59:17Z macabral $
#

package Warewulf::EventHandler;

use File::Basename;
use Warewulf::Logger;
use Warewulf::RetVal;
use Warewulf::Util;

my %events;
my $disable = 0;
my $events_loaded = 0;

=head1 NAME

Warewulf::EventHandler - Event loader/handler

=head1 SYNOPSIS

    use Warewulf::EventHandler;

    my $obj = Warewulf::EventHandler->new();

    sub
    event_callback
    {
        my ($self, @arguments) = @_;

        print STDERR "Arguments: @arguments\n";
    }

    # Register event handler
    $obj->register("error.print", \&event_callback);

    # Trigger event
    $obj->eventloader();
    $obj->handle("error.print", "arg1", "arg2");

=head1 DESCRIPTION

This object loads all available events and is subsequently used to
trigger event handlers when events occur.

=head1 METHODS

=over 4

=item new()

Create and return an EventHandler object.

=cut

sub
new($)
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    bless($self, $class);

    &dprint("Created new EventHandler object\n");

    return $self;
}

=item eventloader()

Loads all the event objects (modules).

=cut

sub
eventloader()
{
    my $self = shift;

    if ($events_loaded) {
        &dprint("Events already loaded, skipping...\n");
    } else {
        $events_loaded = 1;
        foreach my $path (@INC) {
            if ($path =~/^(\/[a-zA-Z0-9_\-\/\.]+)$/) {
                &dprint("Module load path: $path\n");
                foreach my $file (glob("$path/Warewulf/Event/*.pm")) {
                    &dprint("Found $file\n");
                    if ($file =~ /^([a-zA-Z0-9_\-\/\.]+)$/) {
                        my $file_clean = $1;
                        my ($name, $tmp, $keyword);

                        $name = "Warewulf::Event::" . basename($file_clean);
                        $name =~ s/\.pm$//;

                        &iprint("Loading event handler: $name\n");
                        eval {
                            no warnings;
                            local $SIG{__WARN__} = sub { 1; };
                            require $file_clean;
                        };
                        if ($@) {
                            &wprint("Caught error on module load: $@\n");
                        }
                    }
                }
            }
        }
    }
}


=item register($trigger_name, $func_ref)

Subscribe an event callback by its trigger name

=cut

sub
register()
{
    my ($self, $event, $func_ref) = @_;
    my $event_name = uc($event);

    &dprint("Registering event '$event' for " . ref($self) . "\n");
    push(@{$events{"$event_name"}}, $func_ref);
    return scalar(@{$events{"$event_name"}});
}


=item disable()

Disable all events

=cut

sub
disable()
{
    my ($self) = @_;

    $disable = 1;

}


=item enable()

Enable all events (this is the default, so it toggles back on after
disable() has been called).

=cut

sub
enable()
{
    my ($self) = @_;

    $disable = 0;

}


=item handle($trigger_name, @argument_list)

Run all of the events that have registered the defined trigger name

=cut

sub
handle()
{
    my ($self, $event, @arguments) = @_;
    my $event_name = uc($event);
    my $event_count = 0;
    my $ret_true = undef();

    if ($disable) {
        &iprint("Event handler is disabled, not running any events for: $event_name\n");
    } else {
        if (exists($events{"$event_name"})) {
            &dprint("Handling events for '$event_name'\n");
            foreach my $func (@{$events{"$event_name"}}) {
                my $retval = &$func(@arguments);
                if (! &retvalid($retval)) {
                    &eprint("Event did not return a valid Warewulf::RetVal object!\n");
                    next;
                }
                if ($retval->is_ok()) {
                    &dprint("Event returned success\n");
                    $event_count++;
                } else {
                    return($retval);
                }
            }
        } else {
            &dprint("No events registered for: $event_name\n");
        }
        if ($event_name =~ /^([^\.]+)\.([^\.]+)$/) {
            my ($type, $action) = ($1, $2);

            if (exists($events{"$type.*"})) {
                &dprint("Handling events for '$type.*'\n");
                foreach my $func (@{$events{"$type.*"}}) {
                    my $retval = &$func(@arguments);
                    if (! &retvalid($retval)) {
                        &eprint("Event did not return a valid Warewulf::RetVal object!\n");
                        next;
                    }
                    if ($retval->is_ok()) {
                        &dprint("Event returned success\n");
                        $event_count++;
                    } else {
                        return($retval);
                    }
                }
            } else {
                &dprint("No events registered for: $type.*\n");
            }
            if (exists($events{"*.$action"})) {
                &dprint("Handling events for '*.$action'\n");
                foreach my $func (@{$events{"*.$action"}}) {
                    my $retval = &$func(@arguments);
                    if (! &retvalid($retval)) {
                        &eprint("Event did not return a valid Warewulf::RetVal object!\n");
                        next;
                    }
                    if ($retval->is_ok()) {
                        &dprint("Event returned success\n");
                        $event_count++;
                    } else {
                        return($retval);
                    }
                }
            } else {
                &dprint("No events registered for: *.$action\n");
            }
        } else {
            &dprint("event_name couldn't be parsed for type.action\n");
        }
    }

    return &ret_success();
}

=back

=head1 API RECOMMENDATION

There is nothing limiting this API to what is defined here but this is
a sane starting point as to what events should be used.

Event string        Argument list

node.boot           ObjectSet
node.down           ObjectSet
node.add            ObjectSet
node.modify         ObjectSet
node.ready          ObjectSet
node.error          ObjectSet
node.warning        ObjectSet
program.start
program.exit
program.error
[appname].start
[appname].exit
[appname].error

=head1 SEE ALSO

Warewulf::Event

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;

