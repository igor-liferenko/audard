#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


package adsparse_bitmap_pl;

=head1 Requirements:

none

=cut

use 5.10.1;
use warnings;
use strict;

=cut note:
The USB sequence here is:
ccmd1 ; bpcmd2 ; ccmd3 / r200; bpcmd4 / r200;
bpcmd5; bpcmd6 ; ccmd3 / r200; bpcmd8 / 8xr200;
bpcmd5; bpcmd61; ccmd3 / r200; bpcmd8 / 8xr200;
... up to i=0x53 bpcmd6i;; .. until (and) i=0x54

the relevant data is the three times 0x55 times 8xr200 response (85 frames),
which in total is 85*8*512 = 348160 bytes ... // 8*512 = 4096

// len (0 .. 0x54) = 0x55
// 0x55 = 85 ; 0x200 = 512; 85*8*512 = -h 348160 = 0x55000; 348160/3 = 116053
// bmp: 480*234 = 112320 pixels; 480*234*3 = 336960

so this is the signature - 28 bytes when it appears:
 0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f 10 11 12 13 14 15 16 17 18 19 1a 1b
 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
---
44 53 4f 50 50 56 32 30 00 00 0f b0 01 0c 00 00 00 00 00 00 00 00 0f a0 ff fc a2 51
44 53 4f 50 50 56 32 30 00 00 0f b0 01 0c 00 00 00 00 00 01 00 00 0f a0 ff fc 47 89
44 53 4f 50 50 56 32 30 00 00 0f b0 01 0c 00 00 00 00 00 02 00 00 0f a0 ff fc 58 ab

To generate binary, erase the 28 byte signature - but also:
before a transition to new large 8*512 packet (44 53 4f...),
there are 4*16+4 = 68 bytes of zeroes that should be removed!

so from 0-index 28, to 0-index [4095-68 =] 4027 ; len = 4027-28+1 = 4000 = 0x0fa0

# erase the 68 bytes zeroes and 28 byte signature (ASCII - does match all but first):
$str =~ s/((00 ){68}(44 53 4f 50 50 56 32 30 00 00 0f b0 01 0c 00 00 00 00 00 .. 00 00 0f a0 ff .. .. .. ))//sg;

# erase the first header signature:
sed -i 's/44 53 4f 50 50 56 32 30 00 00 0f b0 01 0c 00 00 00 00 00 .. 00 00 0f a0 ff .. .. .. //g'

=cut

use open IO => ':raw'; # no error

binmode(STDIN);
binmode(STDOUT);


# Note: say - Just like print, but implicitly appends a newline (v >= 5.10)
# ... but this println I made auto to STDERR, so keeping it:
sub println  { local $,="";   print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }
sub printlns { local $,=$/; print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }


#======= "main"

if ($#ARGV < 0) {
 print STDERR "usage:
perl adsparse-bitmap.pl bindat_file [out_filename_base]

  Without `out_filename_base`, parsed bitmap data goes to STDOUT:
  1) perl adsparse-bitmap.pl bindat.dat myCapture01
  2) perl adsparse-bitmap.pl bindat.dat 1>stdout.bmp\n";
 exit 1;
}

# read in entire file / slurp in one go
my $infilename = $ARGV[0];
open(my $fh,'<',$infilename) or die "Cannot open $infilename ($!)";
binmode($fh);
my $indata;sysread($fh,$indata,-s $fh);
close($fh);

my $ofnb;   # output filename base
my $ofh;    # output file handle
my $ofnbmp; # output filename for the .csv
# check for second argument - otherwise work with STDOUT as main output:
if ((!defined $ARGV[1]) || ($ARGV[1] eq "")) {
  $ofnb = "stdout";
  $ofh = \*STDOUT;
  $ofnbmp = "stdout.(bmp)"; # since we cannot know name in this case
  println "Writing to STDOUT";
} else {
  $ofnb = $ARGV[1];
  $ofnbmp = "$ofnb.bmp";
  open($ofh,'>',$ofnbmp) or die "Cannot open $ofnbmp ($!)";
  println "Writing to $ofnb.bmp";
}


# convert string $indata to array/list, for easier indexing
# do NOT use split, not binary safe; use unpack instead
my @aindata = unpack('C*',$indata);


# look for the header signature
my $hdrlookfor = "\x44\x53\x4f\x50\x50\x56\x32\x30\x00\x00\x0f\xb0\x01\x0c";
my @hdrinds = ();
my $pos = 0;
while ($pos>=0) {
  $pos = index($indata, $hdrlookfor, $pos); #print STDERR "$pos " . ($pos>=0) . "\n";
  if ($pos>=0) { push(@hdrinds, $pos++) };
}

if ($#hdrinds<0) {
  print STDERR "Header not found; exiting\n";
  exit -1;
}

print STDERR __FILE__.": Found (".($#hdrinds+1).") headers " . "\n";


# extract data - loop through headers, extract, concatenate

my @bmpDatParts = ();
foreach my $hind (@hdrinds)
{
  my @thisExtractDat;
  @thisExtractDat[0 .. 3999] = @aindata[$hind+28 .. $hind+4027];
  # `join` is seemingly binary safe? NO, must use pack here; chars are part of array!
  push (@bmpDatParts,  pack("C*", @thisExtractDat));
}

# but - once we have binary strings as parts of array (not characters);
# then `join` is apparently safe:
my $totalBmpDatOutput = join("", @bmpDatParts);

# cut only 337014 bytes - as in original bmps
my $bmpDatOutput = substr($totalBmpDatOutput, 0, 337014);

print { $ofh } $bmpDatOutput;
println "Saved $ofnbmp";


println "All done; exiting.";

exit 0; # should be by default - but keeping it anyways..

