#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

package get_failed_csv;

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::FormatEng

=cut

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

=head1 note:

Get a list of _proper_ .csv files on command lines;
go through them, extract header, and replace lines
so as to make headers to be "failed", and then save
in caller directory ...

Also copies corresponding .note, .ADS and .CSV

example call:

perl get_failed_csv.pl ../run_01b/{20130103-183626,20130103-191619,20130103-221051}.csv

to add unfailed for testing:
(nano to change first word after):
cp ../run_01b/20130103-201643.{csv,note} . && nano 20130103-201643.note

=cut


use feature qw/say switch state/;
use File::Basename;
use Cwd qw/chdir abs_path getcwd/;
my $script_fullpath = abs_path(__FILE__);
my $EXECDIR = dirname($script_fullpath);
my $CALLDIR = getcwd;
my $PS="/"; # path separator
$EXECDIR .= $PS;
$CALLDIR .= $PS;

binmode(STDIN);
binmode(STDOUT);

# include attenScopeIncludes
# now this is in devscripts,
# so add parent (via dirname) of $EXECDIR;
# actually cannot use $EXECDIR - it is not known at compile time
use lib dirname(dirname(abs_path(__FILE__)));
use attenScopeIncludes;
# declare from attenScopeIncludes
our $adsFactor;

use Number::FormatEng qw(:all);
use File::Copy qw(copy);

sub usage()
{
print STDOUT << "EOF";
  usage: perl ${0} ../path_to_proper/*.csv
  *.csv     list of .csv files to process

  (take care: input files should be in
  different path from this dir; because
  output files will be saved with
  the same name in this directory!)
EOF
exit 0;
};


#======= "main"

# get number of cmdline arguments
# these will be our filenames
my $files_num = scalar @ARGV;
if (not($files_num)) { say "Need at least one .note file to process"; usage(); }


# start loop
FILELOOP: for my $infilestr (@ARGV) {
  say "Processing $infilestr";

  my $infiledir = dirname($infilestr);
  my @entrylines = ();

  if (not($infilestr =~ m/\.csv/)) {
    say "No .csv in filename = not a .csv file; skipping";
    next; # skip rest of loop
  }

  my $fbase = basename($infilestr);
  $fbase =~ s/\.csv//;
  my $linecount = 1;
  my $tdiv = "";
  my $rt_period = "";
  my $rt_freq = "";
  my $trange = "";

  open my $file, '<', "$infilestr";

  while ($linecount <= 26) {
    my $line = <$file>;
    chomp($line);

    if ($linecount == 1) {
      if (not($line =~ m/\.csv \[generated/)) {
        say "Not an attenload .csv file; skipping";
        next FILELOOP; # skip rest of file loop
      }
    }

    if ($linecount == 7) {
      my @parts = split(/ /, $line);
      $tdiv = $parts[5];
    }
    if ($linecount == 8) {
      my @parts = split(/ /, $line);
      $trange = $parts[6];
      chop($trange); # remove last char ('s') from '4.5us'
      $trange = unformat_pref($trange);
    }
    if ($linecount == 9) {
      my @parts = split(/ /, $line);
      $rt_freq = $parts[7];
    }
    if ($linecount == 10) {
      my @parts = split(/ /, $line);
      chop($parts[3]); # remove last char ('s') from '4ns'
      $rt_period = unformat_pref($parts[3]);
      $line =~ s/range: (.*)s/range: 0s/;
    }
    if ($linecount == 12) {
      $line =~ s/range: (.*)s/range: 0s/;
    }
    if ($linecount == 13) {
      $line = "# Sampling interval (screen_range/num_samples)   : -1 s ( -1s )";
    }
    if ($linecount == 14) {
      $line = "#  {eqv.freq: -1Hz }";
    }
    if ($linecount == 15) {
      $line = "# Time Ranges 0 <= $trange: assume portion +keep;";
    }
    if ($linecount == 16) {
      $line = "#  { final timestep: ".format_eng($rt_period)." / ".format_pref($rt_period)." {eqv.freq: ".format_pref($rt_freq)."Hz range 0s }}";
    }
    if ($linecount == 17) {
      $line = "# Oversample factor: -".$rt_period." ( -0.000000 0 -".$rt_period." )";
    }
    if ($linecount == 21) {
      $line = "# Real volt ranges: ch1 (0,0) ; ch2 (0,0)";
    }
    if ($linecount == 23) {
      $line = "# Number of samples in data: 0 (ch1: 0 ; ch2: 0)";
    }

    push (@entrylines, $line);
    $linecount++;
  } # end while ($linecount

  close $file;

  my $ofn = "$fbase.csv";
  my $ofh;
  my $outstr = join("\n", @entrylines);

  open($ofh,'>',"$ofn") or die "Cannot open $ofn ($!)";
  print { $ofh } $outstr;
  close($ofh);
  say "Saved $ofn";

  # check for .note, .ADS, .CSV
  my $notefile;
  ($notefile = $infilestr) =~ s/\.csv/\.note/;
  $ofn = "$fbase.note";
  copy( $notefile, $ofn ) or die "Could not copy $notefile ... ($!)";
  say "Copied $ofn";

  open $file, '<', "$notefile" or die "Could not open $notefile ... ($!)";
  my $firstLine = <$file>;
  close $file;

  my ($firstword, $rest) = split /\s+/, $firstLine, 2;
  say "  $notefile: $firstword";
  $ofn = "$firstword.CSV";
  copy( "$infiledir$PS$ofn", $ofn ) or die "Could not copy $infiledir$PS$ofn ... ($!)";
  say "Copied $ofn";

  $ofn = "$firstword.DAV";
  copy( "$infiledir$PS$ofn", $ofn ) or die "Could not copy $infiledir$PS$ofn ... ($!)";
  say "Copied $ofn";

  $ofn = "$fbase.bmp";
  copy( "$infiledir$PS$ofn", $ofn ) or die "Could not copy $infiledir$PS$ofn ... ($!)";
  say "Copied $ofn";

  # there may be a gnuplot hanging,
  # copy that as well
  $ofn = "$fbase.gnuplot";
  copy( "$infiledir$PS$ofn", $ofn ) or die "Could not copy $infiledir$PS$ofn ... ($!)";
  say "Copied $ofn";

  say ""; # empty line

} # end FILELOOP for







