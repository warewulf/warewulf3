#!/usr/bin/perl -Tw
#
# Copyright (c) 2001-2003 Gregory M. Kurtzer
#
# Copyright (c) 2003-2011, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
#
#
# $Id: 01-modules.t 1799 2014-10-09 19:02:33Z jms $
#

use Test::More;

# Generate the list below with this command:
#    find ./lib -name '*.pm' -print | sed 's/^\.\/lib\///;s/\//::/g;s/\.pm$/",/;s/^/    "/' | sort
my @module_list = (
    "Warewulf::ACVars",
    "Warewulf::Config",
    "Warewulf::Daemon",
    "Warewulf::DataStore",
    "Warewulf::DataStore::SQL",
    "Warewulf::DataStore::SQL::MySQL",
    "Warewulf::DSO",
    "Warewulf::DSO::Config",
    "Warewulf::DSO::File",
    "Warewulf::DSO::Master",
    "Warewulf::DSO::Node",
    "Warewulf::Event",
    "Warewulf::EventHandler",
    "Warewulf::Event::NewObject",
    "Warewulf::Logger",
    "Warewulf::Module",
    "Warewulf::Module::Cli",
    "Warewulf::Module::Cli::Events",
    "Warewulf::Module::Cli::File",
    "Warewulf::Module::Cli::Help",
    "Warewulf::Module::Cli::Node",
    "Warewulf::Module::Cli::Object",
    "Warewulf::Module::Cli::Quit",
    "Warewulf::Module::Cli::Output",
    "Warewulf::ModuleLoader",
    "Warewulf::Module::Trigger",
    "Warewulf::Network",
    "Warewulf::Node",
    "Warewulf::Object",
    "Warewulf::ObjectSet",
    "Warewulf::ParallelCmd",
    "Warewulf::System",
    "Warewulf::SystemFactory",
    "Warewulf::System::Rhel",
    "Warewulf::Term",
    "Warewulf::Util",
);

plan("tests" => scalar(@module_list));

foreach my $module (@module_list) {
    # Some of these modules conflict, so we must suppress
    # the usual warnings about subroutines being redefined.
    local $SIG{"__WARN__"} = sub { 1; };

    use_ok($module);
}
