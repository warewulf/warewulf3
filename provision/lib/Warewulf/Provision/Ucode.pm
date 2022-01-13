
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
# Copyright (c) 2022 Benjamin S. Allen

package Warewulf::Provision::Ucode;

use Warewulf::ACVars;
use Warewulf::Config;
use Warewulf::File;
use Warewulf::Logger;
use Warewulf::Util;
use File::Basename;
use File::Path qw(make_path);
use File::Copy;

our @ISA = ('Warewulf::File');

=head1 NAME

Warewulf::Provision::Ucode - CPU Microcode integration

=head1 ABOUT


=head1 SYNOPSIS

    use Warewulf::Provision::Ucode;

    my $obj = Warewulf::Provision::Ucode->new();
    $obj->Update();

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
    my $self = {};

    bless($self, $class);

    return $self->init(@_);
}

sub
init()
{
    my $self = shift;


    return($self);
}


=item update()

Initgrate a CPU microcode initrd from the local system for loading via the kernel's microcode early load mechanism.

=cut

sub
update()
{
    my $self = shift;
    my $statedir = &Warewulf::ACVars::get("statedir");
    my $config = Warewulf::Config->new("provision.conf");
    my @ucode_paths_x86_64 = $config->get("ucode paths x86_64");
    if (! -d "$statedir/warewulf/bootstrap/x86_64") {
        &eprint("Cannot find $statedir/warewulf/bootstrap/x86_64 directory, not updating x86_64 CPU microcode initrd\n");
        return();
    } 
    &dprint("Checking paths @ucode_paths_x86_64\n");

    my $randstring = &rand_string("12");
    my $tmpdir = "/var/tmp/wwucode.$randstring";
    my $x86_tmpdir = "$tmpdir/kernel/x86/microcode";
    make_path("$x86_tmpdir");

    foreach my $path (@ucode_paths_x86_64) {
        if (-d "$path") {
            if (basename($path) eq "intel-ucode") {
                &dprint("Including $path in GenuineIntel.bin for ucode initrd\n");
                system("cat $path/* >> $x86_tmpdir/GenuineIntel.bin");
            } elsif (basename($path) eq "amd-ucode") {
                &dprint("Including $path in AuthenticAMD.bin for ucode initrd\n");
                system("cat $path/* >> $x86_tmpdir/AuthenticAMD.bin");
            } else {
                &wprint("Only know what todo with paths the end in intel-ucode and amd-ucode, skipping $path\n");
                next;
            }
        } else {
            &dprint("Cannot find directory $path, skipping\n");
            next;
        }
    }
    if (-f "$x86_tmpdir/GenuineIntel.bin" || -f "$x86_tmpdir/AuthenticAMD.bin") {
        &dprint("Creating x86_64 ucode initrd\n");
        system("(cd $tmpdir; find . | cpio -o --quiet -H newc) > $statedir/warewulf/bootstrap/x86_64/ucode.$randstring");
        chmod(0644, "$statedir/warewulf/bootstrap/x86_64/ucode.$randstring");
        move("$statedir/warewulf/bootstrap/x86_64/ucode.$randstring", "$statedir/warewulf/bootstrap/x86_64/ucode");
    } else {
        &wprint("Did not generate a GenuineIntel.bin or AuthenticAMD.bin, so skipping creation of new ucode initrd.\n");
    }

    system("rm -rf $tmpdir");
    return($self);
}
