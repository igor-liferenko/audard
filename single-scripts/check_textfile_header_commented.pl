#!/usr/bin/env perl

# copyleft sdaau, 2013
# check_textfile_header_commented.pl
#  run through a list of files, and comment
#  the given range of lines (if not commented already)
# call with:
# perl check_textfile_header_commented.pl -l 1:10 -c '#' myfile*.txt

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

#use Switch; # switch/case
# say goes to stdout:
use feature qw/say switch state/;

#~ use Getopt::Std;
# "declare the perl command line flags/options we want to allow"
#~ getopts( "hj:ln:s:", \%options ) or usage();
#~ usage() if $opt{h};
# see: http://www.softpanorama.org/Scripting/Perlorama/Modules/getopt_long.shtml
use Getopt::Long;

# for in-place edit of files:
# "a regular text file as a Perl array.  Each element in the array corresponds to a" line
use Tie::File;

binmode(STDIN);   # just in case
binmode(STDOUT);   # just in case

sub usage()
{
print STDOUT << "EOF";
  usage: perl ${0} -l 'line_start:line_end' -c 'comment_char' [-u] myfile*.txt
  -h        this help and exit
  -l        which lines to process, in format line_start:line_end
            e.g.:    -l 1:10           (1-based; as in `less -N`)
  -c        the comment character/string (including possible space)
            e.g.:    -c '# '
  -u      uncomment instead of commenting
  myfile*   list of files to process
EOF
exit 0;
};

# get original number of cmdline arguments (length)
my $arg_num = scalar @ARGV;

# get option arguments (will modify ARGV)
# (don't use defaults - check if cmdline args/options valid)
my %cmdopts= (); # ('l' => "1:10", 'c' => "#"); # ();

GetOptions(
    "h"=>\$cmdopts{h},
    "u"=>\$cmdopts{u},
    "l=s"=> \$cmdopts{l},
    "c=s"=> \$cmdopts{c}
);
usage() if defined $cmdopts{h};

# get number of cmdline arguments after GetOptions
# these will be our filenames
my $files_num = scalar @ARGV;

if (not($files_num)) { say "Need at least one file to process"; usage(); }

my ($ls,$le) = (-1)x2; # easier to handle if we init them at first
if (defined($cmdopts{l})) {
  ($ls,$le) = split( /:/, $cmdopts{l} );
  # if split goes bad here, $ls,$le can go back to undef!
  if (not(defined($ls))) { $ls=-1; }
  if (not(defined($le))) { $le=-1; }
}
my $linerange_ok = ( defined($cmdopts{l}) and ( $ls > 0 ) and ( $le > 0 ) );
if (not($linerange_ok)) { say "Need a valid range of lines to process"; usage(); }
if (not(defined($cmdopts{c}))) { say "Need a comment character/string"; usage(); }

my $cchr = $cmdopts{c}; # shorthand for comment character
my $do_uncomment = defined($cmdopts{u}); # more readable

my $acts = "comment";
if ($do_uncomment) { $acts = "uncomment"; }


say "";
say "Checking and ${acts}ing range of ".($le-$ls+1)." lines: from $ls to $le\n";

for my $file (@ARGV) {
  say $file;
  # instead of opening a file - tie it, for in-place edit
  tie my @flarray, 'Tie::File', $file or die "Cannot open $file";
  my ($cmn,$ucn) = (0)x2; # number of originally commented or uncommented lines
  for ( my $il1 = $ls; $il1 <= $le; $il1++ ) {
    my $il = $il1 - 1; # switch to 0-based index

    my ($comment_this_line, $uncomment_this_line) = (0)x2;
    if ($flarray[$il] =~ m/^$cchr/) {
      $cmn++; $uncomment_this_line = 1;
    } else { $ucn++; $comment_this_line = 1; };

    if (not($do_uncomment)) { # then comment :) :
      # explicit, for all:
      $comment_this_line = 1;

      if ($comment_this_line) {
        $flarray[$il] =~ s/^(.*)/$cchr$1/;
      }
    } else { # here is $do_uncomment:
      # explicit, for all:
      $uncomment_this_line = 1;

      if ($uncomment_this_line) {
        $flarray[$il] =~ s/^$cchr(.*)/$1/;
      }
    }
  } # end for
  # done with lines - untie (and save the file)
  untie @flarray;            # all finished
  say "  Originally: uncommented: $ucn; commented $cmn lines .. ${acts}ed all.\n";
}

