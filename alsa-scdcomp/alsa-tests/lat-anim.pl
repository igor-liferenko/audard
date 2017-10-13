#!/usr/bin/env perl
################################################################################
# lat-anim.pl                                                                  #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

=note: generates pdf frames out of a latency test log capture (.csv and logs)
sudo perl -MCPAN -e shell
cpan[1]> install Number::FormatEng
=cut

package lat_anim_pl;

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error
use utf8; # does not enable Unicode output - it enables you to type Unicode in your program.

use Getopt::Long;
Getopt::Long::Configure(qw{no_auto_abbrev no_ignore_case_always});
use Data::Dumper; # for debug
use Number::FormatEng qw(format_eng);
#~ use Parallel::ForkManager;
use HTTP::Date; # date calculations

binmode(STDOUT, ":raw");
binmode(STDIN, ":raw");

$SIG{'INT'} = sub {print "Caught Ctrl-C - Exit!\n"; exit 1;};

sub usage()
{

print STDOUT << "EOF";
  lat-anim - render lat logs animation

  usage: ${0} [-h] -i inputdir
  -h            this help and exit
  -i inputdir:  input directory with log capture

  To re-render a portion of a complete log:
  -s/--startframe=N   number of start frame
  -e/--endframe=N     number of end frame
  (if these are not specified, complete log is rendered)
  These options also imply:
  -n/--noclean        do not remove render frames subdir

EOF

exit 0;
};


# get original number of cmdline arguments (length)
my $arg_num = scalar @ARGV;
my $firstopt = $ARGV[0];

# get option arguments (will modify ARGV)
my %cmdopts=();
my $noclean = 0;
GetOptions( "h"=>\$cmdopts{h},
            "i=s"=> \$cmdopts{i},
            "startframe|s=i"=> \$cmdopts{s},
            "endframe|e=i"=> \$cmdopts{e},
            "noclean|n"=> \$noclean,
          ) or die($!);
usage() if defined $cmdopts{h};
usage() if not( defined($cmdopts{i}) );

my $indir = $cmdopts{i};
if (not(-d $indir)) {
  print "Directory $indir not found; exiting.\n";
  exit 1;
}

# there should be only one .csv file; get it:
my @csvfiles = glob ($indir."/*.csv");
#~ print Dumper( @csvfiles );

if ( scalar(@csvfiles) != 1 ) {
  print "Cannot find exactly one .csv file in $indir; exiting\n";
  exit 1;
}

my $csvfile = $csvfiles[0];
$csvfile =~ s/^$indir\///;
my ($fbase) = $csvfile =~ m/trace-(.+).csv/;
print "Found $csvfile in $indir\n";



# start and end times; duration;
my $tstart = 0.0;
my $awcmd = "awk -F, 'BEGIN{td=0;} NR!=1 {ot=\$1+\$6;if(ot>td){td=ot;}} END{print (int(ot*10000)+1)/10000}' " . "$indir/$csvfile";
my $tend = `$awcmd`;
#~ print $tend-$tstart+0.1, " $tend\n";
my $tdur = $tend - $tstart;

# anhr: animation (half) range in seconds
my $anhr="300e-6";

# animation timestep:
my $antstep=(1.0/44100)/2;
printf ("Time: start: %.7f, end %.7f, duration %.7f, step %.7f\n",$tstart,$tend,$tdur,$antstep);
printf ("(Time: start: %s, end %s, duration %s, step %s)\n",format_eng($tstart),format_eng($tend),format_eng($tdur),format_eng($antstep));


# number of animation frames
my $numaf = int($tdur/$antstep);
# now that number of animation frames is known,
# check for start/end options:
my $startfr = 0;
my $endfr = $numaf;
if ( (defined $cmdopts{s}) or (defined $cmdopts{e}) ) {
  $noclean = 1;
  if (defined $cmdopts{s}) { $startfr = $cmdopts{s}; };
  if (defined $cmdopts{e}) { $endfr = $cmdopts{e}; };
}

my $JobStartTime = time();

print("Rendering $startfr to $endfr (of $numaf) frames; job started ".time2str($JobStartTime)."\n\n");

my $AFSDIR="anfr"; # animation frames subdirectory
# remove directory silently and recreate it (unless $noclean is set)
my $result;
if (not($noclean)) {
  $result = system("rm -rf $indir/$AFSDIR");
  mkdir("$indir/$AFSDIR");
}


# image prefix: to render png8: frames, in case we're using them in video?
my $impref="png8:";

# parallel processors? Hard to manage the counts with ForkManager.. drop ForkManager for now;
# however, can use $n_processes as number of processors for manual forking+taskset!
# use `nproc` command to get number of processors on this machine
my $n_processes = int(`nproc`); #2;
print("Found $n_processes processors\n");
#~ my $pm = Parallel::ForkManager->new( $n_processes );

print("NOTE: noclean for `anfr` subdir is ($noclean); continue [Enter/Ctrl-C]?\n");
my $userinput = <STDIN>;

my $iframe = 0;
my $curtime = 0.0;
my $gcmd = "";
my $fmark = "";
my $acpu = 0; # taskset -c $acpu command..


=cut old (non-parallel) code
# NB: do NOT pass ,"'dir=\"$...\";'", as argument to system!
# single quotes inside double quotes will choke it!
# simply remove the inner single quotes, as they're not needed in system([list]) call!
sub doAFrame() {
  $fmark = sprintf("%05d", $iframe);
  $acpu = ($acpu)?0:1;
  #~ $gcmd = "taskset -c $acpu gnuplot -e 'dir=\"$indir\";fname=\"$csvfile\";fnext=\"$fmark\";anct=$curtime;anhr=$anhr;' traceFGLatLogGraph.gp";
  print "($numaf)/ ";
  #~ system("taskset", "-c", "$acpu", "gnuplot", "-e", " dir=\"$indir\";fname=\"$csvfile\";fnext=\"$fmark\";anct=$curtime;anhr=$anhr;", "traceFGLatLogGraph.gp");
  #~ system("taskset", "-c", "$acpu", "mv", "$indir/*$fmark.pdf", "$indir/$AFSDIR/");
  #~ system("taskset", "-c", "$acpu", "convert", "-density", "250", "$indir/$AFSDIR/${csvfile}_$fmark.pdf", "-rotate", "90", "${impref}$indir/$AFSDIR/${csvfile}_$fmark.png");
  system("taskset", "-c", "$acpu", "bash", "-c",
  "gnuplot -e 'dir=\"$indir\";fname=\"$csvfile\";fnext=\"$fmark\";anct=$curtime;anhr=$anhr;' traceFGLatLogGraph.gp && mv $indir/*$fmark.pdf $indir/$AFSDIR/ && convert -density 250 $indir/$AFSDIR/${csvfile}_$fmark.pdf -rotate 90 ${impref}$indir/$AFSDIR/${csvfile}_$fmark.png");

}

while ($iframe < $numaf) {

  if (($iframe >= $startfr) and ($iframe <= $endfr)) {

    #~ $pm->start and next;

    doAFrame();

    #~ $pm->finish;

  } elsif ($iframe > $endfr) { last; };
  #~ $pm->wait_all_children;
  $iframe++;
  $curtime += sprintf("%.6f",$antstep); # autocast to float
}

#~ $pm->wait_all_children;
=cut

# for easier readability, store command strings in Perl sub;
# so we can have "lazy" string evaluation;
# (and we don't have to use the whole exec "taskset", "-c", $acpu, "bash", "-c", "gnuplot -e 'dir=\"$indir\";fname=\"$csvfile\";fnext=\"$fmark\";anct=$curtime;anhr=$anhr;' traceFGLatLogGraph.gp && mv $indir/*$fmark.pdf $indir/$AFSDIR/ && convert -density 250 $indir/$AFSDIR/${csvfile}_$fmark.pdf -rotate 90 ${impref}$indir/$AFSDIR/${csvfile}_$fmark.png" )
# note that after that, we can only concat with reference:
# eg.: print " AA " . &$a . " BB " ; print " AA " . $a->() . " BB " ;
# also, all variables used inside, need to declared beforehand!

# to avoid a command; simply insert echo -n as its contents

$gcmd = sub { "gnuplot -e 'dir=\"$indir\";fname=\"$csvfile\";fnext=\"$fmark\";anct=$curtime;anhr=$anhr;' traceFGLatLogGraph.gp" };
#~ $gcmd = sub { "echo -n ." };

my $mcmd = sub { "mv $indir/*$fmark.pdf $indir/$AFSDIR/" };
#~ my $mcmd = sub { "echo -n" };


#~ my $ccmd = sub { "convert -density 250 $indir/$AFSDIR/${csvfile}_$fmark.pdf -rotate 90 ${impref}$indir/$AFSDIR/${csvfile}_$fmark.png" };

# must supersample to achieve PDF antialias with ImageMagick `convert`
# also, here the image is padded in 800x600
my $ccmd = sub { "convert -rotate 90 -density 250 -resize 800x -gravity center -background black -extent 800x600 $indir/$AFSDIR/${csvfile}_$fmark.pdf ${impref}$indir/$AFSDIR/${csvfile}_$fmark.png" };


my $cmdpipeline = "";

my @pids;

while ($iframe < $numaf) {

  for my $ifr ($iframe++, $iframe++) {
    if ($ifr > 0) { $curtime += sprintf("%.6f",$antstep); }; # autocast to float;
    if (($ifr >= $startfr) and ($ifr <= $endfr)) {
      my $pid = fork();
      if ($pid == -1) {
         die;
      } elsif ($pid == 0) { #child execs
        $acpu = $ifr % $n_processes;
        $fmark = sprintf("%05d", $ifr);
        $cmdpipeline = $gcmd->() . " && " . $mcmd->() . " && " . $ccmd->();
        exec "taskset", "-c", $acpu, "bash", "-c", "$cmdpipeline" or die;
      }
      push @pids, $pid; #parent stores children's pids
      my $size = @pids;
      if ($size == $n_processes) {
        waitpid $pids[0], 0;  # wait for first element to finish
        splice @pids, 0, 1;   # remove first element
      }
    }
  } # //for

} # //while

# wait for all hanging children to complete:
while (wait() != -1) {}

my $JobEndTime = time();
my $JobDelta = $JobEndTime-$JobStartTime;
my $JobMins = $JobDelta/60;

print "Job took $JobDelta seconds ($JobMins mins). Finished on ".time2str($JobEndTime).".\n";




# .gif may be too big (~15MB for 590 frames):
# convert -verbose -resize 800x -delay 10 -loop 0 $indir/$AFSDIR/*.png lattest.gif


# ffmpeg -f image2 -i captlat-2013-08-20-09-33-12/anfr/trace-hda-intel.csv_%05d.png -s 800x600 lattest.mpg
# 3,1M	lattest.mpg

#ffmpeg -i captlat-2013-08-20-09-33-12/anfr/trace-hda-intel.csv_%05d.png -vcodec huffyuv -pix_fmt rgb24 lattest.avi
# 252M	lattest.avi (could be bad for vlc)

#ffmpeg -i captlat-2013-08-20-09-33-12/anfr/trace-hda-intel.csv_%05d.png -vcodec mjpeg lattest.avi
# 18M	lattest.avi # artefacts

#ffmpeg -i captlat-2013-08-20-09-33-12/anfr/trace-hda-intel.csv_%05d.png -vcodec ffvhuff lattest.avi
# 192M	lattest.avi - no artefacts - can play rate 2.0 in vlc on my machine; also 3.0 but hiccups on mouse move

# vlc --repeat --rate 4.0 lattest.mpg


