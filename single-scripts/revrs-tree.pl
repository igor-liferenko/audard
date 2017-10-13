#!/usr/bin/env perl
################################################################################
# revrs-tree.pl                                                                #
#                                                                              #
# Copyleft 2014, sdaau <sd[at]imi.aau.dk>                                      #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information look up GPL v3 or later                 #
################################################################################
# Wed Jul 16 03:34:51 CEST 2014 ; This is perl, v5.10.1 (*) built for i686-linux-gnu-thread-multi
use 5.010;
use warnings;
use strict;
select STDERR; $| = 1; # make unbuffered
select STDOUT; $| = 1; # make unbuffered
use utf8; # tell Perl that your script is written in UTF-8
# NO: else it won't react on regex: /^[└├│]/ !! (else it reacts);
# but then, for some reason, it won't react to qr/[│├]/?
# enable, but also use this:
binmode(STDOUT, ":utf8");
binmode(STDIN, ":utf8");
#~ use open IO  => ':raw'; # nope
use open qw(:std :utf8); # will make utf8 regex work with diamond <>, if the above are also :utf8
use File::Spec;
use Getopt::Long;
use Data::Dumper;

my $getdir = "";
my $zerofill;
my $rndbfill;
my $optresult = GetOptions (
  "getdir=s"   => \$getdir,      # string
  "zerofill"   => \$zerofill,    # flag; fill ifles with zeroes 0x00
  "rndbfill"   => \$rndbfill,    # flag; fill files with urandom bytes
);  # flag

#print(Dumper(\@ARGV)); # empty if GetOptions processed; else filename

# if $getdir is set, simply call `tree` with our options,
# and output to stdout
if (length($getdir)) {
  print( `tree --dirsfirst -spugD "$getdir"` );
  exit;
}

# http://unix.stackexchange.com/q/9509/#comment233251_9518
sub convPermsStringToOctal{
  chomp(my $ins=shift);
  my $k=0;
  for(my $i=0;$i<=8;$i++) {
    #$k+= ( (substr($ins, $i, 1) =~ /[rwx]/ )*(2**(8-$i)) ); # orig line
    my $tmps = ( substr($ins, $i, 1) =~ /[rwx]/ );
    #print("$k $i $ins $tmps \n");
    $k+= ( $tmps*(2**(8-$i)) );
  };
  if ($k) { sprintf("%0o", $k); } else { "??" ; };
};

# if $getdir is not set, process any file via <>;
#  and output `bash` commands!
my $amReadingFile = (defined($ARGV[0])) ? $ARGV[0] : "stdin" ;
print STDERR "
* Will now read tree text from $amReadingFile - and
*  generate `bash` script commands to stdout...
* (note that `tree` truncates uid/gids; double-check
*  the resulting script before executing it!)

";
# for the `tree` output above:
#  first line is the root;
#  other lines are ok as long as they start w/ └,├, or │; (or have ─)
# $. is line counter; $_ is line content
my $inRootDir;
my $reValidLine = qr/^[├│└]/;
my $reSplitLine = qr/(.*)\s\[(.*)\]\s*(.*)/;
my $reDat = qr/\s+/;
my $reNestCount = qr/[├│└]/; # cannot add /g here (not allowed); must below
my $reEmptyLine = qr/^\s*$/;
my $reColon = qr/:/;
my @subdirstack = ();
my @subdirtouchings = ();
my $lastLineValid = 0;
while(<>) {
  #print "$_"; # dbg
  if ($. == 1) { # first line
    chomp($_);
    $inRootDir = $_;
    # remove trailing slash, if there (and it is):
    $inRootDir = $1 if($inRootDir=~/(.*)\/$/);
    print("#!/usr/bin/env bash\n".
          "set -x;\n".
          "RTD=\"$inRootDir\";\n".
          "read -p \"WARNING! will output in '\$RTD' directory!\nPress [Enter] key to start output...\";\n".
          'if [ ! -d "$RTD" ] ; then mkdir "$RTD" ; fi ;'."\n\n"
    );
    $lastLineValid =1;
  } else { # all other lines
    chomp($_);
    if ($_ =~ $reValidLine) { # regex match: line is valid if starting w/ these chars
      my @lparts = split($reSplitLine, $_);
      @lparts = grep { not /$reEmptyLine/ } @lparts; # filter out empty string elements
      my $treeNestStr = $lparts[0];
      my $basename = $lparts[2];
      my $datStr = $lparts[1];
      my @datparts = split($reDat, $datStr);
      my $typeperm = $datparts[0];
      my $type = substr($typeperm, 0, 1); # 'd' dir, '-' file, 'l' symlink
      my $perms = substr($typeperm, 1);
      my $permsocts = convPermsStringToOctal($perms);
      my $uids = $datparts[1];
      my $gids = $datparts[2];
      my $sizebytes = $datparts[3];
      my $month = $datparts[4];
      my $day = $datparts[5];
      # if this is current year, this shows hh:mm - else shows yyyy
      my $yearhour = $datparts[6];
      my $year = (localtime)[5] + 1900; # initialize with current year
      my $hourmins = "0:00";
      if ($yearhour =~ $reColon) {
        $hourmins = $yearhour;
      } else {
        $year = $yearhour;
      }
      # note: we don't have info about hour/min/sec, so we set to 0!!
      my $touchtimestr = "$month $day $year $hourmins:00";
      my @counta = ($treeNestStr =~ /$reNestCount/g);
      my $nestCount = scalar(@counta);
      my $startstacklen = scalar(@subdirstack);
      my $diffNestStack = $nestCount - $startstacklen;
      #print(" >> $type ($nestCount-$startstacklen=$diffNestStack); $perms ; $uids ; $gids ; $sizebytes ; $day-$month-$year\n" ); # . Dumper(\@datparts)
      if ($type eq "d") { # is a directory - manage @subdirstack
        # count number of occurent indent characters - via regex
        if ($nestCount > $startstacklen) {
          if ($nestCount == $startstacklen + 1) {
            push(@subdirstack, $basename);
          } else {
            die("not sure how to handle subdir level increase more than 1; exiting.");
          }
        } elsif ($nestCount == $startstacklen) {
          # since the counts are the same, and 'd' appeared here;
          # then here we must replace the last element..
          my $lastElemRemoved = pop(@subdirstack);
          push(@subdirstack, $basename);
        } else {
          # $nestCount < $startstacklen ;  that means
          # $diffNestStack = $nestCount - $startstacklen is negative!
          # remove abs($diffNestStack) + 1 items, then add current
          for(my $ix=0;$ix<abs($diffNestStack)+1;$ix++) {
            pop(@subdirstack);
          }
          push(@subdirstack, $basename);
        }
        #print(" >> $nestCount ($diffNestStack) $permsocts; ".join("::",@subdirstack)."\n");
        # for folders, have `touch` last (and therefore, with sudo)?
        # NOPE; it is because we put files in the dir; timestamp changes!
        # so best: collect an array of `touch` dir commands;
        # and at end, re-dump them!
        my $fulldirname = File::Spec->catdir('$RTD', @subdirstack);
        # we have to expand $TDIR/fulldirname in dirtouchcmd, though:
        my $dirtouchcommand = "sudo touch -d '$touchtimestr' \"$fulldirname\"; ";
        push(@subdirtouchings, $dirtouchcommand);
        print("\nTDIR=\"$fulldirname\";\n".
              'mkdir "$TDIR"; ' .
              'sudo chown '."$uids:$gids".' "$TDIR"; ' .
              'sudo chmod '.$permsocts.' "$TDIR"; ' .
              "sudo touch -d '$touchtimestr'".' "$TDIR"; ' .
        "\n\n");
      } elsif ($type eq "-") { # is a file $rndbfill
        # check if we're on proper level; it is when $diffNestStack=1
        # should it happen to be $diffNestStack=0, then we should pop one
        # from @subdirstack; also take into account multiple descends!
        if ($diffNestStack<1) {
          for(my $ix=0;$ix<abs($diffNestStack)+1;$ix++) {
            pop(@subdirstack);
          }
        }
        my $fullfilepath = File::Spec->catfile(('$RTD', @subdirstack), $basename);
        my $genfilecmds="";
        if ($zerofill) {
          $genfilecmds="cat /dev/zero | head --bytes $sizebytes > ".' "$TFIL";'."\n";
        } elsif ($rndbfill) {
          $genfilecmds="cat /dev/urandom | head --bytes $sizebytes > ".' "$TFIL";'."\n";
        }
        print("TFIL=\"$fullfilepath\";\n". $genfilecmds.
              "touch -d '$touchtimestr'".' "$TFIL"; ' .
              'sudo chown '."$uids:$gids".' "$TFIL"; ' .
              'sudo chmod '.$permsocts.' "$TFIL"; ' .
        "\n");
      }
      $lastLineValid=$.;
    } else { # no match, invalid line - exit immediately
      if ($lastLineValid > 0) {
        print("\n". join("\n", @subdirtouchings) . "\n\n");
        print STDERR "\nNo more valid lines after line $lastLineValid; exiting.\n";
        exit;
      }
    }
  }
}