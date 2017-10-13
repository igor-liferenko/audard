#!/usr/bin/env perl
# call with:
# cat whatever | cratelimit.pl -r=100


use strict;
use Switch; # switch/case

#~ use Getopt::Std;
# "declare the perl command line flags/options we want to allow"
#~ getopts( "hj:ln:s:", \%options ) or usage();
#~ usage() if $opt{h};

use Getopt::Long;

use Time::HiRes;

# use FileHandle; # no dice
# use IO::Handle '_IOFBF'; # `FBF' means `Fully Buffered';
# http://perl.plover.com/FAQs/Buffering.html
# "Perl's sysread and syswrite operators. These don't use buffering at all."
# http://lists.freebsd.org/pipermail/freebsd-questions/2005-August/095047.html
# "use sysread() and syswrite() for unbuffered read/write"

binmode(STDIN);   # just in case
binmode(STDOUT);   # just in case



sub usage()
{

print STDOUT << "EOF";
  usage: ${0} [-h] -b rate
  -h        this help and exit
  -b rate:  rate to limit, in bytes/sec (max 1e6)
            (use either space or = to specify: -b X or -b=X)

EOF

exit 0;
};

#~ my $fh = FileHandle->new;
#~ $fh->setvbuf(STDIN, _IOFBF, 1); # Bareword "STDIN" not allowed while "strict subs" in use

# get original number of cmdline arguments (length)
my $arg_num = scalar @ARGV;
my $firstopt = @ARGV[0];

# get option arguments (will modify ARGV)
my %cmdopts=();
GetOptions( "h"=>\$cmdopts{h},
            "r=i"=> \$cmdopts{r});
usage() if defined $cmdopts{h};

my $bpsrate = 0;

if ($cmdopts{r}) {
  $bpsrate = $cmdopts{r};
  if (int($bpsrate) > 1e6) { $bpsrate = 1e6; }
  if (int($bpsrate) < 0) { $bpsrate = 1; }
  print "Found rate: $cmdopts{r} - setting to $bpsrate\n";
} else {
  $bpsrate = 1000;
  print "No rate found. Setting to default $bpsrate\n";
};

my $period_s = 1/$bpsrate;
my $period_us = $period_s*1e6;
print "Per-character period in microseconds is: $period_us (".int($period_us).")\n";

#~ exit 0;

my $string;

# may complain with pipes: "stty: standard input: Invalid argument"
system "stty -echo -icanon";

# sysread for unbuffered - but terminal could still be buffered
#~ while ( my $string = <STDIN> ) {
while (sysread STDIN, $string, 1) {
  #~ my $olen = length($string); # now definitely always one
  #~ print $olen;

  # since here can only be 1 char, do not check if length:
  syswrite STDOUT, $string, 1; # "$olen", 1;

  Time::HiRes::usleep (int($period_us)); # better without int?!
} # end while loop


