#!/usr/bin/env perl

# perl gendata.pl > bin.dat

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

binmode(STDIN);
binmode(STDOUT);

my $signatur = "SIGN";
my @signature = unpack('C*', $signatur);

my (@ch1, @ch2) = ()x2;

# generate 100 samples of sinusoid

for ( my $ix = 0; $ix < 100; $ix++ ) {
  my $val1 = 1 + sin($ix*2*3.14/100); # range: 0-2
  my $val2 = 1 + cos($ix*2*3.14/100); # range: 0-2
  my $ch1val = int($val1*32);
  my $ch2val = int($val2*32+64);
  push(@ch1, $ch1val);
  push(@ch2, $ch2val);
  #print STDERR "val[$ix]: $ch1val, $ch2val\n";
}

# generate 30 samples random

my @end = ();
for ( my $ix = 0; $ix < 30; $ix++ ) {
  my $val = int(128*rand() + 32);
  push(@end, $val);
  #~ print STDERR "val[$ix]: $val\n";
}

# concatenate arrays:
my @output = (@signature,@ch1,@ch2,@end);
my $sizarr = scalar(@output);
#~ print STDERR " ".." ";

# print output - uint8: "C"
my $outstr = pack("C*", @output);
my $lenstr = length($outstr);
#~ print STDERR "output size: $sizarr; output length: $lenstr\n";
print $outstr;

# end