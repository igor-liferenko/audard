use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

use feature qw/say switch state/;
use Term::ReadKey;


say "\n", "Enter one-line note for this capture (or just [ENTER] for empty note): ";
#~ print "/proc/$$/fd/0\n";
# http://stackoverflow.com/questions/11198603/inject-keystroke-to-different-process-using-bash
# http://rosettacode.org/wiki/Simulate_input/Keyboard
#~ system("sleep 0.5; echo a > /proc/$$/fd/0"); # /dev/tty");
# "Modification of a read-only value attempted",
# if no \$char variable in # ioctl(\$fh, \$TIOCSTI, \$char);'");!
#~ system("sleep 0.5; perl -e '\$TIOCSTI = 0x5412; \$tty = \"/dev/pts/1\"; open(\$fh, \">\", \$tty); ioctl(\$fh, \$TIOCSTI, \"VV\");'");
# (also for \$tty = \"/proc/$$/fd/0\";)
my $ic = 1;
$ic++;
$ic++;
my $ics = sprintf("%05d", $ic);
system("sleep 0.1; perl -e '\$TIOCSTI = 0x5412;
\$tty = \"/dev/tty\";
\$char = \"ADS$ics\";
\@c=split(\"\",\$char);
open(\$fh, \">\", \$tty);
foreach \$a ( \@c ) {
  ioctl(\$fh, \$TIOCSTI, \$a);
  # select(undef,undef,undef,0.1); # just pauses
}'");
my $notetext = <>; # keep the newline, do not chomp $fn_sfx;
print "notetext $notetext"

