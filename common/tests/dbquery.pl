#!/usr/bin/perl


use Warewulf::Object;
use Warewulf::ObjectSet;
use Warewulf::DB;
use Warewulf::DBQuery;
use Warewulf::Logger;

&set_log_level("DEBUG");


my $action = shift(@ARGV);
my $table = shift(@ARGV);

if (! $action or ! $table) {
    die("USAGE: $0 (get/set/insert) (table) [match options]\n");
}


my $query = Warewulf::DBQuery->new($action);
$query->table($table);
while(@ARGV) {
    my $command = shift;
    if ($command eq "match") {
        my $column = shift(@ARGV);
        my $operator = shift(@ARGV);
        my $value = shift(@ARGV);
        $query->match($column, $operator, $value);
    } elsif ($command eq "set") {
        my $column = shift(@ARGV);
        my $value = shift(@ARGV);
        $query->set($column, $value);
    }
}

my $db = Warewulf::DB->new("localhost", "warewulf", "root", "");
my $set = Warewulf::ObjectSet->new($db->query($query));

foreach my $o ($set->get_list()) {
    my @strings;
    my $h = $o->get_hash();

#    print $o->get("name") .": ";
    foreach my $key (sort keys %{$h}) {
            printf ("%s: %20s: %s\n", $o->get("name"), $key, $h->{"$key"});
    }
#    print join(", ", @strings) ."\n";
}

