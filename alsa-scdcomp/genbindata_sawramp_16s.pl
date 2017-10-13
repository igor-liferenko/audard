#!/usr/bin/env perl
################################################################################
# genbindata_sawramp_16s.pl                                                    #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# call with:
# perl genbindata_sawramp_16s.pl > out16s.dat

# http://stackoverflow.com/questions/14472419/plotting-1d-binary-array-uint8-with-multiple-records-in-gnuplot
# http://stackoverflow.com/questions/5826701/plot-audio-data-in-gnuplot/17584953


=sec
perl pack specifiers:

b  A bit string (ascending bit order inside each byte, like vec()).
B  A bit string (descending bit order inside each byte).
c  A signed char (8-bit) value.
C  An unsigned char (octet) value.
s  A signed short (16-bit) value.
S  An unsigned short value.
>   Force big-endian byte-order on the type.
    (The "big end" touches the construct.)
<   Force little-endian byte-order on the type.
    (The "little end" touches the construct.)

# these don't allow endian operators <>:
n  An unsigned short (16-bit) in "network" (big-endian) order.
N  An unsigned long (32-bit) in "network" (big-endian) order.
v  An unsigned short (16-bit) in "VAX" (little-endian) order.
V  An unsigned long (32-bit) in "VAX" (little-endian) order.

NB: zero-padding a bit string is usually
applied to the output string (or use Bit::Vector)
http://stackoverflow.com/a/14290651/277826
else cC,sS specify number of bits explicitly
for unpack bit-string conversion

# one-liner tests:

perl -e 'print unpack("B*", pack("c", 1)) . "\n"'
# 00000001
perl -e 'print unpack("b*", pack("c", 1)) . "\n"'
# 10000000
perl -e 'print unpack("B*", pack("C", 1)) . "\n"'
# 00000001
perl -e 'print unpack("b*", pack("C", 1)) . "\n"'
# 10000000

perl -e 'print unpack("b*", pack("s", 1)) . "\n"'
# 1000000000000000
perl -e 'print unpack("B*", pack("s", 1)) . "\n"'
# 0000000100000000

perl -e 'print unpack("B*", pack("s<", 1)) . "\n"'
# 0000000100000000
perl -e 'print unpack("B*", pack("s>", 1)) . "\n"'
# 0000000000000001


perl -e 'print unpack("B*", pack("s", 1)) . "\n"'
# 0000000100000000
perl -e 'print unpack("B*", pack("s", 2)) . "\n"'
# 0000001000000000
perl -e 'print unpack("B*", pack("s", -1)) . "\n"'
# 1111111111111111      # same with S
perl -e 'print unpack("B*", pack("s", -2)) . "\n"'
# 1111111011111111      # same with S

# 2^16/2 = 32768; big endian below - easier to read:

perl -e 'print unpack("B*", pack("s>", 2**16/2)) . "\n"'
# 1000000000000000  # outval
perl -e 'print unpack("B*", pack("s>", 2**16/2+1)) . "\n"'
# 1000000000000001  # outval
perl -e 'print unpack("B*", pack("s>", 2**16/2-1)) . "\n"'
# 0111111111111111
perl -e 'print unpack("B*", pack("s>", -2**16/2)) . "\n"'
# 1000000000000000
perl -e 'print unpack("B*", pack("s>", -2**16/2+1)) . "\n"'
# 1000000000000001
perl -e 'print unpack("B*", pack("s>", -2**16/2-1)) . "\n"'
# 0111111111111111  # outval

# thus, limits:

perl -e 'print unpack("B*", pack("s>", -2**16/2)) . "\n"'
# 1000000000000000
perl -e 'print unpack("B*", pack("s>", -2)) . "\n"'
# 1111111111111110
perl -e 'print unpack("B*", pack("s>", -1)) . "\n"'
# 1111111111111111
perl -e 'print unpack("B*", pack("s>", 0)) . "\n"'
# 0000000000000000
perl -e 'print unpack("B*", pack("s>", 1)) . "\n"'
# 0000000000000001
perl -e 'print unpack("B*", pack("s>", 2)) . "\n"'
# 0000000000000010
perl -e 'print unpack("B*", pack("s>", 2**16/2-1)) . "\n"'
# 0111111111111111

# with array:
perl -e 'print unpack("B*", pack("s>*", (1,2) )) . "\n"'
# 00000000000000010000000000000010

=cut

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw';

binmode(STDIN);
binmode(STDOUT);

my (@ch1, @ch2) = ()x2;
# interleaved channels
my @intlch;

# generate all 16-bit values [-32768:32767] as a ramp/saw
for ( my $ix = -2**16/2; $ix < 2**16/2; $ix++ ) {
  # 1 channel: orig val -- 2 channel: invert val
  my $ch1val = int($ix);
  my $ch2val = int(-1*$ix-1);
  push(@ch1, $ch1val);
  push(@ch2, $ch2val);
  push(@intlch, $ch1val);
  push(@intlch, $ch2val);
  #print STDERR "val[$ix]: $ch1val, $ch2val\n";
}


# concatenate arrays (we have just @intlch, anyway):
my @output = (@intlch);
my $sizarr = scalar(@output);
#~ print STDERR " ".." ";

# print output - uint8: "C" ("C*"); we need:
# S16_LE: signed 16-bit little endian: "s<"

my $outstr = pack("s<*", @output);
my $lenstr = length($outstr);
#~ print STDERR "output size: $sizarr; output length: $lenstr\n";
print $outstr;

# end
