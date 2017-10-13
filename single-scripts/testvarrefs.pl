
$apple='apple';
$banana='banana';
$orange='orange';
my @fruit = ($apple, $banana, $orange);

# apple - banana - orange - 3
print $apple ." - ". $banana ." - ". $orange ." - ". @fruit . "\n";

#
print \$apple ." - ". \$banana ." - ". \$orange ." - ". \@fruit . "\n";

my @tfruit = (\$apple, \$banana, \$orange);

print \@tfruit, " - ",  @tfruit, "\n";

my $tref = \@tfruit;
my $stref = "". $tref;

print "tref: $tref ; stref: $stref\n";

print @fruit[0], " | ", $fruit[0], " | ", @$fruit[0], "\n";
print @tfruit[0], " | ", $tfruit[0], " | ", @$tfruit[0], "\n";

my @tback = @$tref;

print  "t1 ", @tback[0], " | ", $tback[0], " | ", @$tback[0], "\n";
print  "t2 ", ${@tback[0]}, " | ", ${$tback[0]}, " | ", ${@$tback[0]}, "\n";
print  "t3 ", ${@$tref[0]}, " | ",  "\n";

my @stback = @$stref;

print  "t1 ", @stback[0], " | ", $stback[0], " | ", @$stback[0], "\n";

my $tstref = eval($stref);

print "tstref: $tstref ; stref: $stref\n";

# http://stackoverflow.com/a/1671495/277826
use B; # core module providing introspection facilities
# extract the hex address
my ($addr) = $stref =~ /.*(0x\w+)/;
# fake up a B object of the correct class for this type of reference
# and convert it back to a real reference
print "\n$addr\n";
my $real_ref = bless(\(0+hex $addr), "B::AV")->object_2svref;

print "real_ref: $real_ref\n";

my @trback = @$real_ref;

# SCALAR(0x9cedfb0) | SCALAR(0x9cedfb0) |
print  "tr ", @trback[0], " | ", $trback[0], " | ", @$trback[0], "\n";
# apple | apple |
print  "tr2 ", ${@trback[0]}, " | ", ${$trback[0]}, " | ", ${@$trback[0]}, "\n";



__END__






------------


#~ use B; # core module providing introspection facilities
#~ use warnings;
#~ use strict;
#~ use Image::Magick;
#~ use Tk;
#~ use MIME::Base64;
#~ use B;
#~ use Carp;
#~ use Fcntl ':flock';
#~ use Data::Printer;
#~ use Class::Inspector;
#~ use IPC::Shareable;

#~ open my $self, '<', $0 or die "Couldn't open self: $!";
#~ # flock $self, LOCK_EX | LOCK_NB or croak "This script is already running";
#~ flock $self, LOCK_EX | LOCK_NB or die; #$amMaster = 0; #reloadImage();



----------

p($sharevar1);
p($sharevar2);



#~ $sharevar1 = "b";
#~ $sharevar1 = "AOE" . \$sharevar2;
#~ my $laddr = "AOE" . \$sharevar2;
my $laddr = "AOE" . \$sharevar3;
$sharevar1 = substr $laddr, 5, 10; # 2,7: Can't use string ("ESCALAR") as a SCALAR ref; 5,10 "ALAR(0x90e" - no problem?!

$sharevar1 = lc $laddr; # lowercase

# extract the hex address
my ($addr) = $laddr =~ /.*(0x\w+)/;
# fake up a B object of the correct class for this type of reference
# and convert it back to a real reference
print "\n addr $addr\n";
my $tsharevar1 = bless(\(0+hex $addr), "B::AV")->object_2svref;

p($tsharevar1);

$sharevar2 = 20;


------------


use warnings;
use strict;
use IPC::Shareable;
use Data::Printer;

IPC::Shareable->clean_up;


my $sharevar1 = "a";
my $sharevar2;


print "A: $sharevar1 $sharevar2\n";
p($sharevar1);
p($sharevar2);


my $glue1 = 'glu1';
my $glue2 = 'glu2';

my %options = (
  create    => 1, #'yes',
  exclusive => 0,
  mode      => 0644, #0644,
  destroy   => 1, # 'yes',
);

my $sharevar_handle1 = tie $sharevar1, 'IPC::Shareable', $glue1 , \%options ; #

print "B1: $sharevar1 $sharevar2 - $sharevar_handle1\n";
p($sharevar_handle1);

my $sharevar_handle2 = tie $sharevar2, 'IPC::Shareable', $glue2 , \%options ; #

print "B2: $sharevar1 $sharevar2 - $sharevar_handle2\n";
p($sharevar_handle2);

p($sharevar1);
p($sharevar2);


#~ $sharevar1 = "b";
#~ $sharevar1 = substr "AOE" . \$sharevar2, 2, 7; # Can't use string ("ESCALAR") as a SCALAR ref
#~ $sharevar1 = substr "AOE" . \$sharevar2, 5, 10; # "ALAR(0x878", passes OK

$sharevar1 = lc \$sharevar2; # _data   \ "scalar(0x9e65f88)",
#~ $sharevar1 = \$sharevar2; # _data   \ undef (tied to IPC::Shareable) (tied to IPC::Shareable),
#~ $sharevar1 = uc $sharevar1; # _data   \ "SCALAR(0X839EF88)", Can't use string ("SCALAR(0X839EF88)") as a SCALAR ref
p($sharevar_handle1);
$sharevar2 = 20;

print "C: ";
print "- $sharevar1 $sharevar2\n";
p($sharevar1);
p($sharevar2);

