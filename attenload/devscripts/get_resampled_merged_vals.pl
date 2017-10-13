#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

use 5.10.1;
use warnings;
use strict;

if ($#ARGV < 1) {
 print STDERR "usage:
perl $0 _tmp_file _dav_file
\n";
 exit 1;
}

#~ $file = '_e_tmp';
my $file = $ARGV[0];
open(FL, $file);
my @tlines = <FL>;
close(FL);

#~ $file = '_e_dav';
$file = $ARGV[1];
open(FL, $file);
my @dlines = <FL>;
close(FL);

while ($tlines[0] =~ /^#|^\s*$/) { splice(@tlines, 0, 1); }
while ($dlines[0] =~ /^#|^\s*$/) { splice(@dlines, 0, 1); }

my (@tla, @tda);
foreach my $tl (@tlines) {
  chomp($tl); $tl =~ s/^\s+//; # ltrim/lstrip
  my @csvline = split(/\s+/, $tl);
  #print join('-',@csvline) . "  : " . scalar($#csvline). "\n";
  if (scalar(@csvline) == 3) { push(@tla, \@csvline); }
}
foreach my $dl (@dlines) {
  chomp($dl); $dl =~ s/^\s+//;
  my @csvline = split(/\s+/, $dl);
  # even if hacking like this an already aligned situation:
  # $csvline[0] = $csvline[0] + 1;
  # .. rowinddif is always 0 or neg (just values start getting errors too)
  if (scalar(@csvline) == 3) { push(@tda, \@csvline); }
}

#~ print "tla ". scalar(@tla) . " tda " . scalar(@tda) . "\n";

# >           [0] [1][2]       [0] [1][2]
# > tla[0]: 32336  8  i tda[0]: 0  57  i
# > tla[1]: 32337  7  i tda[1]: 4  55  i
# > tla[2]: 32338  6  i tda[2]: 8  57  i


my $offst = 0; my $rowinddif; my $ix;
my @outarrA=();

# dav has more elements - AND larger period!
# tmp is smaller, with (maybe) more frequent samples!
# since here it's integer index - only those at
# exact same position are of interest (for errorbars)!
# (amazingly - seems I can get ideal alignment!)

# since not both indexes are monotonic (32336,32337..) vs (0,4..) ;
# we cannot really get the $ix offset at start; we have 32336 -
# but we don't know where 32336 is in the (0,4..) array
# (could divide w/ four though? - but safer to go slower...)

my $start = 1;
foreach my $tl (@tla) {
  $ix = 0;
  while (($rowinddif = @{$tl}[0]-@{$tda[$offst+$ix]}[0]) > 0) {
    #print "$offst+$ix (".($offst+$ix)."): " . @{$tl}[0] . " vs ". @{$tda[$offst+$ix]}[0]. "; $rowinddif\n";
    $ix++;
  }
  my $valdif=@{$tl}[1]-@{$tda[$offst+$ix]}[1];
  my @tout = ($ix+$offst, @{$tl}[0],
@{$tl}[1], @{$tda[$offst+$ix]}[0], @{$tda[$offst+$ix]}[1], $rowinddif, $valdif);
  $offst += $ix - 1;
  push (@outarrA, \@tout);
  #~ print "AAA ".join('::', @tout);
  #~ print "\n";
}

# loop again through @outarrA, find minimum $rowinddif by abs value
# however, as written, rowinddif is always negative! So nvm abs here..
my @tmprid = ();
foreach my $row (@outarrA) {
  # unique only; next like continue - but also like break (with label)
  UNIQ: {
    foreach my $tr (@tmprid) {
      if ($tr == @{$row}[5]) {
        next UNIQ;
      }
    }
    push (@tmprid, @{$row}[5]);
  } # /UNIQ
}

# sort numerically ascending - by abs value
#~ print "tmprid: " .join(':', @tmprid). "\n";

my @sortrid = sort {abs($a) <=> abs($b)} @tmprid;
# then we're sure we have smallest, even if rowinddifs are negative
# ... and their sign is kept too (but could be a mess with mix
#     of positive and negative indices
my $rowinddifmin = $sortrid[0];
#~ print "rowinddifmin $rowinddifmin; " .join('::', @sortrid) . "\n";

# finally, create out array - only where row indiced are minimum:
my @outarr=();

foreach my $row (@outarrA) {
  if (@{$row}[5] == $rowinddifmin) {
    push (@outarr, $row);
  }
}

# and print it to stdout:
#~ print "CCC ".join('::', @outarr); # CCC ARRAY(0x9240a40)::ARRAY(0x96bc360):: ..

foreach my $row (@outarr) {
  #~ print "CCC ";
  print join(',', @{$row});
  print "\n";
}

