#!/usr/bin/env perl
################################################################################
# comparecsv.pl                                                                #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# comparecsv.pl - output side by side data from two csv files, individual offsets
#
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

package comparecsv_pl;

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error
use utf8; # does not enable Unicode output - it enables you to type Unicode in your program.

use Getopt::Long;
use Data::Dumper; # for debug

binmode(STDOUT, ":raw");
binmode(STDIN, ":raw");

$SIG{'INT'} = sub {print "Caught Ctrl-C - Exit!\n"; exit 1;};

my @infiles;
my @offsets;
my $lenlines;
GetOptions(
#            "i|infile=s@"=> \$infiles, # but @$infiles call!
#            "o|offset=s@"=> \$offsets, # but @$offsets call!
            "i|infile=s"=> \@infiles,
            "o|offset=s"=> \@offsets,
            "l|lenlines=i"=> \$lenlines,
          ) or die($!);

my $infsize = scalar @infiles; # size
my $offsize = scalar @offsets; # size

if ($infsize != 2) {
  die("Error - need exactly two files");
}

for my $if (@infiles) {
  if (not(-f $if)) {
    die("Error - file $if doesn't exist");
  }
}

# assume first line if offsets are not present:
while ($offsize < $infsize) {
  push @offsets, 1;
  $offsize = scalar @offsets;
}

$lenlines = int($lenlines);
print("Comparing $lenlines lines of:\n");
for (my $ix=0; $ix < $infsize; $ix++) {
  printf("Input file %s offset %d\n", $infiles[$ix], $offsets[$ix]);
}
print("\n");

my @filesnips;
my ($tline, $ptline);

for (my $ix=0; $ix < $infsize; $ix++) {
  my $if = $infiles[$ix];
  $filesnips[$ix] = ();
  $tline=0; $ptline = 0;
  open (MYFILE, $if);
  while (<MYFILE>) {
    if (($tline >= $offsets[$ix]) and ($ptline < $lenlines)) {
      chomp;
      push @{$filesnips[$ix]}, $_;
      $ptline++;
    }
    $tline++;
  }
}
close(MYFILE);

# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr,13_rdly,14_strm

# determine string lengths "per cpu" and for left vs. right for string padding/alignment
my (@inLmax, $outLmax) = ((0,0),0);
my (@inRmax, $outRmax) = ((0,0),0);
my @Tmax = (0,0);
# which field is timestamp
my $tst = 0; # 0; 1;


for (my $il=0; $il < $lenlines; $il++) {
  my @l0 = split(',', $filesnips[0][$il]);
  my @l1 = split(',', $filesnips[1][$il]);
  my $l0cpu = $l0[2];
  my $l1cpu = $l1[2];
  my $l0str = " ($l0cpu${l0[3]}) ${l0[7]}";
  my $l1str = " ($l1cpu${l1[3]}) ${l1[7]}";
  my $t0str = "${l0[$tst]}";
  my $t1str = "${l1[$tst]}";

  if ( length($l0str) > $inLmax[$l0cpu]) { $inLmax[$l0cpu] = length($l0str); };
  if ( length($l1str) > $inRmax[$l1cpu]) { $inRmax[$l1cpu] = length($l1str); };
  if ( length($t0str) > $Tmax[0] ) { $Tmax[0] = length($t0str); };
  if ( length($t1str) > $Tmax[1] ) { $Tmax[1] = length($t1str); };
}

$outLmax = $inLmax[0] + $inLmax[1] + $Tmax[0];
$outRmax = $inRmax[0] + $inRmax[1] + $Tmax[1];

open(LMYFILE, ">", "_L.txt");
open(RMYFILE, ">", "_R.txt");

for (my $il=0; $il < $lenlines; $il++) {
  my @l0 = split(',', $filesnips[0][$il]);
  my @l1 = split(',', $filesnips[1][$il]);
  my $l0cpu = int($l0[2]);
  my $l1cpu = int($l1[2]);
  my $l0str = "${l0[$tst]}" . " "x($inLmax[0]*$l0cpu) . " ($l0cpu${l0[3]}) ${l0[7]}";
  my $l1str = "${l1[$tst]}" . " "x($inRmax[0]*$l1cpu) . " ($l1cpu${l1[3]}) ${l1[7]}";
  #printf("%-60s(%d) | %-60s(%d)\n", $l0str, length($l0str), $l1str, length($l1str));
  printf("%-${outLmax}s | %-${outRmax}s\n", $l0str, $l1str);
  print LMYFILE " "x($inLmax[0]*$l0cpu) . "${l0[7]}\n"; # "$l0str\n";
  print RMYFILE " "x($inRmax[0]*$l1cpu) . "${l1[7]}\n"; # "$l1str\n";
}

close(LMYFILE);
close(RMYFILE);

