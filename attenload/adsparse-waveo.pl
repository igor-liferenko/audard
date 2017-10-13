#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


use warnings;
use strict;

=cut note:
The USB sequence here is:
ccmd1 ; wrcmd2 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ;  # first, init data
ccmd1 ; wrcmd25 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ; # ch.1 samples
ccmd1 ; wrcmd26 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ; # ch.2 samples

the relevant data is the three times 37xr200 response (three frames),
which in total is 3*37*512 = 56832 bytes

frame headers:

 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f 10  1  2  3  4  5  6  7 # 0-based hex
 1  2  3  4  5  6  7  8  9 10  1  2  3  4  5  6  7  8  9 20  1  2  3  4 # 1-based dec
44 53 4f 50 50 56 32 30 00 00 48 58 01 05 00 00 00 00 00 00 01 00 00 01 # (first)
44 53 4f 50 50 56 32 30 00 00 48 58 01 05 00 00 00 05 00 00 00 00 03 84 # (second)
44 53 4f 50 50 56 32 30 00 00 48 58 01 05 00 00 00 06 00 00 00 00 08 ca # (third)
== == == == == == == == == == == == == == 00 00 00 -- 00 00 -- 00 -- --

first frame:

           0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f
00000000  44 53 4f 50 50 56 32 30  00 00 48 58 01 05 00 00
00000010  00 || 00 00 /1 00 | sz|  01 00 00 00 01 00 00 00
00000020  | vdiv1/f | | vdiv1/x |  | voff1/i | 00 00 00 00
00000030  |         | | vdiv2/f |  | vdiv2/x | | voff2/i |
00000040  |         | | tbase/f |  | tbase/x | | toffs/f |
00000050  | toffs/x | |         |  |         | |         |

|| - frame order index (01, 05, 06);
/1 = 01 for first in run else 00;
| sz| = number of samples/entries in this frame: 4 bytes int, big endian
  00 01 for first, else 0x0384 = 900 or 0x08ca = 2250 ...

vdiv1/f: V/DIV ch.1; fractional coefficient:    4 bytes float, little endian
vdiv1/x: V/DIV ch.1; exponent:                  4 bytes int, big endian {7[07000000] is V, 6[06000000] is mV; actually, little!}
voff1/i: ch.1 voltage offset/position; integer: 4 bytes int, little endian {val=x/25*VDIV1 ; is actually big!}
vdiv1/f: V/DIV ch.2; fractional coefficient:    4 bytes float, little endian
vdiv1/x: V/DIV ch.2; exponent:                  4 bytes int, big endian {7[07000000] is V, 6[06000000] is mV}
voff1/i: ch.2 voltage offset/position; integer: 4 bytes int, little endian {val=x/25*VDIV2}
tbase/f: sec/div timebase; fractional coeff:    4 bytes float, little endian
tbase/x: sec/div timebase; exponent:            4 bytes int, big endian {val=10^(3*x-12) ; is actually little!}
toffs/f: time offset/position; fractional coef: 4 bytes float, little endian
toffs/x: time offset/pos exponent:              4 bytes int, big endian {val=10^(3*x-12)}

=cut

use open IO => ':raw'; # no error
binmode(STDIN);
binmode(STDOUT);

# sudo perl -MCPAN -e shell ---> install Number::FormatEng
use Number::FormatEng qw(:all);


sub vdivunit {
  my $inval = $_[0];
  if ($inval == 6) {
    return "mV";
  } elsif ($inval == 7) {
    return "V";
  } else {
    return "?V";
  };
}

sub vdivexp {
  my $inval = $_[0];
  if ($inval == 6) {
    return -3;
  } elsif ($inval == 7) {
    return 0;
  };
}

sub println  { local $,="";   print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }
sub printlns { local $,=$/; print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }

#=======

if ($#ARGV != 0) {
 print STDERR "usage: perl adsparse-waveo.pl filename > out.txt\n";
 exit;
}

# read in entire file / slurp in one go
my $infilename = $ARGV[0];
open(my $fh,'<',$infilename) or carp $!;
binmode($fh);
my $indata;sysread($fh,$indata,-s $fh);
close($fh);

# convert string $indata to array/list, for easier indexing
# do NOT use split, not binary safe; use unpack instead
my @aindata = unpack('C*',$indata);


# look for the header signature
my $hdrlookfor = "\x44\x53\x4f\x50\x50\x56\x32\x30\x00\x00\x48\x58\x01\x05";
my @hdrinds = ();
my $pos = 0;
while ($pos>=0) {
  $pos = index($indata, $hdrlookfor, $pos); #print STDERR "$pos " . ($pos>=0) . "\n";
  if ($pos>=0) { push(@hdrinds, $pos++) };
}
if ($#hdrinds<0) {
  print STDERR "Header not found; exiting\n";
  exit -1;
} elsif ($#hdrinds != 2) {
  print STDERR "Need exactly 3 headers; found ".($#hdrinds+1)." instead; exiting\n";
  exit -1;
}
print STDERR "Found (".($#hdrinds+1).") headers at: ". join(', ', @hdrinds). "\n";


# extract data

my (@frOrderInds, @frFirstMarks, @frSizes) = ();
foreach my $hind (@hdrinds)
{
  push (@frOrderInds,  $aindata[$hind+0x11]);         # 0x11 = 17
  push (@frFirstMarks, $aindata[$hind+0x14]);         # 0x14 = 20
  # get sz - first, declare and init list with two elements
  my @atmpsize = (0) x 2;
  # Copy portions of one array to another
  @atmpsize[0..1] = @aindata[$hind+0x16..$hind+0x17]; # 0x16 = 22
  # Convert extracted bytes to integer
  my $tmpsize = unpack("n", pack("C2", @atmpsize));
  push (@frSizes, $tmpsize);
}
print STDERR  "frOrderInds:  ".join(';', @frOrderInds)."\n".
              "frFirstMarks: ".join(';', @frFirstMarks)."\n".
              "frSizes:      ".join(';', @frSizes)."\n";


# from first frame:

my $haddr1=$hdrinds[0];
my @atmp = (0) x 4;
my $tmp1;

# there is no pack types to choose endian with floats in Perl;
# so those must be handled manually (w/ reverse on packed data)
# note 00000084 = 132 default for voltage offset

my $vdiv1_f;
@atmp[0..3] = @aindata[$haddr1+0x20..$haddr1+0x23];
$vdiv1_f = unpack("f", reverse pack("C4", @atmp));

my $vdiv1_x;
@atmp[0..3] = @aindata[$haddr1+0x24..$haddr1+0x27];
$vdiv1_x = unpack("V", pack("C4", @atmp));

my ($voff1_i, $voff1_bs);
@atmp[0..3] = @aindata[$haddr1+0x28..$haddr1+0x2b];
$voff1_i = unpack("N", pack("C4", @atmp));
$voff1_bs = ((132-$voff1_i)/25)*$vdiv1_f;


my $vdiv2_f;
@atmp[0..3] = @aindata[$haddr1+0x34..$haddr1+0x37];
$vdiv2_f = unpack("f", reverse pack("C4", @atmp));

my $vdiv2_x;
@atmp[0..3] = @aindata[$haddr1+0x38..$haddr1+0x3b];
$vdiv2_x = unpack("V", pack("C4", @atmp));

my ($voff2_i, $voff2_bs);
@atmp[0..3] = @aindata[$haddr1+0x3c..$haddr1+0x3f];
$voff2_i = unpack("N", pack("C4", @atmp));
$voff2_bs = ((132-$voff2_i)/25)*$vdiv2_f;


my $tbase_f;
@atmp[0..3] = @aindata[$haddr1+0x44..$haddr1+0x47];
$tbase_f = unpack("f", reverse pack("C4", @atmp));

my $tbase_x;
@atmp[0..3] = @aindata[$haddr1+0x48..$haddr1+0x4b];
$tmp1 = unpack("V", pack("C4", @atmp));
$tbase_x = 3*$tmp1-12;


my $toffs_f;
@atmp[0..3] = @aindata[$haddr1+0x4c..$haddr1+0x4f];
$toffs_f = unpack("f", reverse pack("C4", @atmp));

my $toffs_x;
@atmp[0..3] = @aindata[$haddr1+0x50..$haddr1+0x53];
$tmp1 = unpack("V", pack("C4", @atmp));
$toffs_x = 3*$tmp1-12;

# format complete numbers
# note, caret in Perl is regex; use ** for exponentiation (2.5*10^-3 = 4294967268 !)

my $vdiv1 = $vdiv1_f * 10**(vdivexp($vdiv1_x));
print STDERR "Ch1 V/DIV  : " . format_eng($vdiv1) . " V ( " . format_pref($vdiv1) . "V )\n";

my $voff1 = $voff1_bs * 10**(vdivexp($vdiv1_x));
print STDERR "Ch1 Voffset: " . format_eng($voff1) . " V ( " . format_pref($voff1) . "V )\n";

my $vdiv2 = $vdiv2_f * 10**(vdivexp($vdiv2_x));
print STDERR "Ch2 V/DIV  : " . format_eng($vdiv2) . " V ( " . format_pref($vdiv2) . "V )\n";

my $voff2 = $voff2_bs * 20**(vdivexp($vdiv2_x));
print STDERR "Ch2 Voffset: " . format_eng($voff2) . " V ( " . format_pref($voff2) . "V )\n";

my $tbase = $tbase_f * 10**($tbase_x);
print STDERR "Timebase   : " . format_eng($tbase) . " s ( " . format_pref($tbase) . "s )\n";

my $toffs = $toffs_f * 10**($toffs_x);
print STDERR "Time offset: " . format_eng($toffs) . " s ( " . format_pref($toffs) . "s )\n";


# get channel data (second and third frame)

my @adatch1 = (0) x $frSizes[1];
my @adatch2 = (0) x $frSizes[2];

my $haddr2=$hdrinds[1]; # of second frame
@adatch1[0..$frSizes[1]-1] = @aindata[$haddr2+0x18..$haddr2+0x18+$frSizes[1]-1];

my $haddr3=$hdrinds[2]; # of third frame
@adatch2[0..$frSizes[2]-1] = @aindata[$haddr3+0x18..$haddr3+0x18+$frSizes[2]-1];


# output ".csv" (not really) "table"
# there are 32 **** - apparently measures
# encoding CRLF with \r, and the \n from the newline in the string
my $output = $frSizes[1] . "\r
320\r
1\r
2\r
" . join("\r\n", @adatch1) . "\r
" . sprintf("%9.5f", $tbase_f) . "\r
" . format_pref($toffs) . "s\r
" . format_pref($vdiv1) . "\r
" . sprintf("%02x", $voff1_i) . "\r
Auto\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
" . $frSizes[2] . "\r
320\r
1\r
2\r
" . join("\r\n", @adatch2) . "\r
" . sprintf("%9.5f", $tbase_f) . "\r
" . format_pref($toffs) . "s\r
" . format_pref($vdiv2) . "\r
" . sprintf("%02x", $voff2_i) . "\r
Auto\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
****\r
";

print $output;

