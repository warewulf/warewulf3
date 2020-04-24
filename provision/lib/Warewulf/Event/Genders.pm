
package Warewulf::Event::Genders;

use Warewulf::Event;
use Warewulf::EventHandler;
use Warewulf::Logger;
use Warewulf::Provision::Genders;
use Warewulf::RetVal;


my $event = Warewulf::EventHandler->new();
my $obj = Warewulf::Provision::Genders->new();


sub
update_genders()
{
    $obj->update(@_);

    return &ret_success();
}


$event->register("node.add", \&update_genders);
$event->register("node.delete", \&update_genders);
$event->register("node.modify", \&update_genders);

1;
