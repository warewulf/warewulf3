
package Warewulf::Provision::Genders;

use Socket;
use Digest::MD5 qw(md5_hex);
use Warewulf::Logger;
use Warewulf::Provision::Dhcp;
use Warewulf::DataStore;
use Warewulf::Network;
use Warewulf::Node;
use Warewulf::SystemFactory;
use Warewulf::Util;
use Warewulf::File;
use Warewulf::DSO::File;

our @ISA = ('Warewulf::File');

=head1 NAME

Warewulf::Provision::Genders - Generate a basic pdsh genders file from the Warewulf
data store.

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::Genders;

    my $obj = Warewulf::Provision::Genders->new();
    my $string = $obj->generate();


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

    $self = {};

    bless($self, $class);

    return $self->init(@_);
}


sub
init()
{
    my $self = shift;

    return($self);
}


=item generate()

This will generate the content of the /etc/genders file.

=cut

sub
generate()
{
    my $self = shift;
    my $datastore = Warewulf::DataStore->new();
    my $netobj = Warewulf::Network->new();
    my $config = Warewulf::Config->new("provision.conf");

    my $genders_file = $config->get("genders file") ? $config->get("genders file") : "/etc/genders";

    my $delim = "### ALL ENTRIES BELOW THIS LINE WILL BE OVERWRITTEN BY WAREWULF ###";

    my $genders;

    open(GENDERS, $genders_file);
    while(my $line = <GENDERS>) {
        chomp($line);
        if ($line eq $delim) {
            last;
        }
        $genders .= $line ."\n";
    }
    close(GENDERS);

    chomp($genders);
    $genders .= "\n". $delim ."\n";
    $genders .= "#\n";
    $genders .= "# See provision.conf for configuration paramaters\n\n";

    foreach my $n ($datastore->get_objects("node")->get_list("groups", "cluster", "name")) {
        my $nodeid = $n->id();
        my $name = $n->name();
        my $nodename = $n->nodename();
        my @groups = $n->groups();

        if (! defined($nodename) or $nodename eq "DEFAULT") {
            next;
        }

        &dprint("Evaluating node: $nodename\n");
        $genders .= "\n# Node Entry for node: $name (ID=$nodeid)\n";

        if ($n->enabled()) {
            $genders .= $nodename . " " . join(',', @groups) . "\n";
        } else {
            $genders .= "# DISABLED " . $nodename . " " . join(',', @groups) . "\n";
        }
    }

    return($genders);
}


=item update_gendersfile($file, $contents)

Update the master's local genders file with the node contents.

=cut

sub
update_gendersfile()
{
    my ($self, $file, $contents) = @_;

    if (open(FH, "> $file")) {
        print FH $contents;
        close FH;
    } else {
        &wprint("Could not open $file: $!\n");
    }

}


=item update()

Update the master's /etc/genders file if configured to do so.

=cut

sub
update()
{
    my ($self) = @_;
    my $config = Warewulf::Config->new("provision.conf");
    my $genders_contents = $self->generate();

    if (! $config->get("generate genders") or $config->get("generate genders") eq "yes") {
        my $genders_file = $config->get("genders file") ? $config->get("genders file") : "/etc/genders";
        if ($genders_contents) {
            $self->update_gendersfile($genders_file, $genders_contents);
        }
    }
}


=back

=head1 SEE ALSO

Warewulf::Provision::Dhcp

=head1 COPYRIGHT

Copyright (c) 2001-2003 Gregory M. Kurtzer

Copyright (c) 2003-2011, The Regents of the University of California,
through Lawrence Berkeley National Laboratory (subject to receipt of any
required approvals from the U.S. Dept. of Energy).  All rights reserved.

=cut


1;
