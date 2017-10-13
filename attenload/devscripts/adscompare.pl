#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

package adscompare_pl;

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::FormatEng
cpan[2]> install List::Util
cpan[3]> install Term::ANSIColor
cpan[4]> install Term::Cap
cpan[5]> install IO::Handle

=cut

=head1 README:

call:
perl adscompare.pl [attengrab].csv [ADS0000x].CSV [ADS0000x].DAV | less -r

adscompare.pl compares data saved in a .DAV file, .CSV file
and .csv file, for a single oscilloscope capture - and
outputs a rather long table (pipe it to `less -r`! The
terminal needs at least 140 characters width to properly
show the table)
* Compares ch1 only graphically (from a capture containing
both channels)
* Needs to be copied (or possibly [not sure] symlinked)
to main `attenload` directory (where `attenScopeIncludes.pm`
resides)
* Also uses `get_resampled_merged_vals.pl` - which also needs
to be symlinked in main `attenload` directory
* [attengrab].png needs to be in same dir as [attengrab].csv;
 ImageMagick `convert` is used for its use in `gnuplot`
* outputs are files `adscompare.gnuplot` and `adscompare.png`

for more README - see below, at end of script


# for proper:
# all arrays should be in indexed mode
# (ignore .CSV timestamps - could be wrong!)
# move all arrays to middle; then they aligh at:
# (osf - 4; oversample factor [dtf])
## DAV:   osf*[n] (reference)
## TMP/csv:   [n] + 18*[n]
## CSV:   osf*[n] + 19*[n]
# then look for time domain (but .csv should be checked raw here)
# for checking, bitmap should be aligned to grid

=cut


use 5.10.1;
use warnings; # FATAL => 'all';
use strict;
use open IO => ':raw'; # no error


=head1 signals stuff
sub WARN_handler { my($signal) = @_; print("WARN: $signal"); }
sub DIE_handler { my($signal) = @_; print("DIE: $signal"); }

# check signals:
# perl -e 'for (keys %SIG) {print "key $_ ; val " . $SIG{$_} . "\n"; }'
# __WARN__, __DIE__ - Win/Linux
# __ABRT__, __BREAK__ etc are Windows only;
# also 'TRAP', not __TRAP__;
# __DIE__ catches "Can't use an undefined value as an ARRAY reference"
$SIG{__WARN__} = \&WARN_handler;
$SIG{__DIE__}  = \&DIE_handler; # this - not 'DIE_handler';
#~ $SIG{'TRAP'}  = \&DIE_handler;

# $SIG{__WARN__} = $SIG{INT}; # break with Ctrl-C on warning (for perl -d) # breaks the debugger itself too: maybe too strong, maybe error instead of warn
# [http://www.perlmonks.org/?node_id=640915 break on warning in debugger]
# "some trickery and get the warning to kick the debugger into single-step mode"?
#~ $SIG{__WARN__} = sub { $DB::single = 1 };

http://stackoverflow.com/questions/14755634/create-raise-a-sigint-ctrl-c-from-perl-script-and-cause-debugger-entry-in-st
=cut

$SIG{__DIE__} = sub { my($signal) = @_; say "DIEhandler: $signal"; $DB::single = 1; };
$SIG{__WARN__} = sub { my($signal) = @_; say "WARNhandler: $signal"; $DB::single = 1; };



# say goes to stdout:
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
binmode(DATA);

use Number::FormatEng qw(:all);

# these for bold/underline
use Term::Cap;
use POSIX;    # note, here: Subroutine adscompare_pl::getcwd redefined
# for color
use Term::ANSIColor qw(:constants);

# for min/max of arrays (lists)
use List::Util qw/max min/;
use IO::Handle qw( );  # For flush

# include attenScopeIncludes
#~ use lib dirname (abs_path(__FILE__));
# now adscompare is in devscripts,
# so add parent (via dirname) of $EXECDIR;
# actually cannot use $EXECDIR - it is not known at compile time
use lib dirname(dirname(abs_path(__FILE__)));
use attenScopeIncludes;
# $adsFactor (voltage) found by bruteforce (see comments at end)
# but should be built in .CSV and .csv!
# was 0.78125; now 1/0.78125 = 1.28
# declare from attenScopeIncludes
our $adsFactor;
our $scope_hdivs; # 18
our $scope_vdivs; # 8
our %timediv_move_map;

$| = 1; # $|++; # set flushing of output buffers ALREADY HERE;



#======= "main"

if ($#ARGV < 2) {
 print STDERR "usage:
perl adscompare.pl [attengrab].csv [ADS0000x].CSV [ADS0000x].DAV
\n";
 exit 1;
}

# should we printout table to stdout? 0/1
my $print_table_stdout = 1;
my $dry_run = 0;

my $termios = new POSIX::Termios; $termios->getattr;
my $ospeed = $termios->getospeed;
my $t = Tgetent Term::Cap { TERM => undef, OSPEED => $ospeed };
my ($norm, $bold, $under) = map { $t->Tputs($_,1) } qw/me md us/;


my $atgcsvfile = $ARGV[0];
my $adsCSVfile = $ARGV[1];
my $adsdavfile = $ARGV[2];

(my $atgpngfile = $atgcsvfile) =~ s/\.csv/.png/;


# [ADS0000x].DAV (bin)
# read in entire file / slurp in one go
say "\nProcessing $adsdavfile";

my ($fh, $indavdata);
open($fh,'<',$adsdavfile) or die "Cannot open $adsdavfile ($!)";
binmode($fh);
sysread($fh,$indavdata,-s $fh);
close($fh);

# convert string $indata to array/list, for easier indexing
# full size here - even if we'll use only one channel
# do NOT use split, not binary safe; use unpack instead
my @tadavdata = unpack('C*',$indavdata);
# how many bytes in @adavdata (length)?
my $tadavsize = scalar (@tadavdata);

say "$adsdavfile: $tadavsize bytes (expecting 0x4000 = 16384 samples (per ch))";
# extract 1st channel
my @adavdata;
my $dsz = 0x4000;
@adavdata[0..$dsz-1] = @tadavdata[0..$dsz-1];
# extract 2nd channel - we use both from same array
@adavdata[$dsz..2*$dsz-1] = @tadavdata[$dsz..2*$dsz-1];



# loop through .csv files, construct arrays
# skip lines starting with # (treat as comment)
# (note: substr goes to end of string iff third arg is omitted!)


# loop through [ADS0000x].CSV file
# read in entire file, parse lines and collect data

say "\nProcessing $adsCSVfile";

my @adsCSVdata;
my ($adsCSVreclen, $adsCSVdatlen, $dopack) = (0)x3;
my ($adssampintch1, $adssampintch2,$adssampint) = (0)x3;
my ($adsvuch1, $adsvuch2) = (0)x2; # "Vertical Units" (V)
my ($adsvscch1, $adsvscch2) = (0)x2; # "Vertical Scale" (1)
my ($adsvoffch1, $adsvoffch2) = (0)x2; # "Vertical Offset" (1)
my ($adshu, $adshs, $adstrange) = (0)x3; # "Horizontal Units" (s), "Horizontal Scale" (0.0050000000), time range
my (@adsch1vals,@adsch2vals,@adstimevals);
my $rest;
my $Ctf;

&process_adsCSV();


# find min/max = sort numerically ascending
my @sortch1 = sort {$a <=> $b} @adsch1vals;
my @sortch2 = sort {$a <=> $b} @adsch2vals;
my @sortch3 = sort {$a <=> $b} @adstimevals;
my ($adsmin1, $adsmax1) = ($sortch1[0],$sortch1[-1]);
my ($adsmin2, $adsmax2) = ($sortch2[0],$sortch2[-1]);
my ($adsmint, $adsmaxt) = ($sortch3[0],$sortch3[-1]);

if ($adssampintch1 >= $adssampintch2) { $adssampint = $adssampintch1; }
else { $adssampint = $adssampintch2; }
$adstrange = ($adsmaxt-$adsmint)+$adssampint;


say "$adsCSVfile: Record Length=", $adsCSVreclen, "; csv length:", $adsCSVdatlen;
say " Sampl.int. (period) ch1:",$adssampintch1," ch2:",$adssampintch2;
say " minmax 1:[$adsmin1,$adsmax1] 2:[$adsmin2,$adsmax2] ";
say "  t:[$adsmint,$adsmaxt] ($adstrange)";
say " Vertical Units: $adsvuch1 $adsvuch2 ; Vert.Scale: $adsvscch1 $adsvscch2 ; Vert. Offset: $adsvoffch1 $adsvoffch2";
say " Horizontal Units: $adshu; Horizontal Scale (timebase): $adshs";



# loop through [attengrab].csv file
# (contains also .TMP uint8 values)
# read in entire file, parse lines and collect data

say "\nProcessing $atgcsvfile";

my @atgcsvdata;
$dopack = 0;
my ($atgreclen1, $atgreclen2) = (0)x2;
my ($atgcsvreclen, $atgcsvdatlen) = (0)x2;
my ($atgsampint) = (0)x1;
my ($rtsamprate) = (0)x1;
my ($atgcsvfinalts) = (0)x1;  # use this instead of $atgsampint
my ($atgvuch1, $atgvuch2) = (0)x2; # "Vertical Units" (V) V/DIV
my ($atgvscch1, $atgvscch2) = (0)x2; # "Vertical Scale" (1) V/DIV
my ($atgvoffch1, $atgvoffch2) = (0)x2; # "Vertical Offset" (1)
my ($atghu, $atghs, $atgtrange, $atgtoffs) = (0)x4; # "Horizontal Units" (s), "Horizontal Scale" (0.0050000000), time range, time offset
my (@atgch1valsi,@atgch2valsi);
my (@atgch1valsr,@atgch2valsr,@atgtimevals);
my $osf;

&process_atgcsv();


# sort numerically ascending
@sortch1 = sort {$a <=> $b} @atgch1valsi;
@sortch2 = sort {$a <=> $b} @atgch2valsi;
my ($atgmin1i, $atgmax1i) = ($sortch1[0],$sortch1[-1]);
my ($atgmin2i, $atgmax2i) = ($sortch2[0],$sortch2[-1]);
@sortch1 = sort {$a <=> $b} @atgch1valsr;
@sortch2 = sort {$a <=> $b} @atgch2valsr;
@sortch3 = sort {$a <=> $b} @atgtimevals;
my ($atgmin1r, $atgmax1r) = ($sortch1[0],$sortch1[-1]);
my ($atgmin2r, $atgmax2r) = ($sortch2[0],$sortch2[-1]);
my ($atgmin2rt, $atgmax2rt) = ($sortch3[0],$sortch3[-1]);

$atgtrange = ($atgmax2rt-$atgmin2rt)+$atgcsvfinalts;

say "$atgcsvfile: Record Length=$atgcsvreclen ($atgreclen1;$atgreclen2); csv length:", $atgcsvdatlen;
say " Sampl.int. (scope_hdivs/len) ",$atgsampint, " ; final timestep: ", $atgcsvfinalts;
say " minmaxi 1:[$atgmin1i,$atgmax1i] 2:[$atgmin2i,$atgmax2i] ";
say " mrnmaxr 1:[$atgmin1r,$atgmax1r] 2:[$atgmin2r,$atgmax2r]";
say "  t:[$atgmin2rt,$atgmax2rt] ($atgtrange)";
say "  t offset: $atgtoffs";
say " Vertical Units: $atgvuch1 $atgvuch2 ; Vert.Scale: $atgvscch1 $atgvscch2 ; Vert. Offset: $atgvoffch1 $atgvoffch2";
say " Horizontal Units: $atghu; Horizontal Scale (timebase): $atghs";
say " RealTime (Acq Menu) Sample Rate: $rtsamprate";

$Ctf = $atgtrange/$adstrange;
say "";
say "Timerange factor: $atgtrange/$adstrange = ", $Ctf;
say "   Length factor: $atgcsvdatlen/$adsCSVdatlen = ", $atgcsvdatlen/$adsCSVdatlen;


# since there is oversampling, should calculate the proper
# time ranges (index domain per smallest timestep)
# for .CSV, best to not care about real time values (could be
# wrong) anyways - just go by index; it's real voltage
# value can be scaled back to int too
# so compare in the integer domain (mainly) in table..
# skip values that don't exist - and include all scaling
# formulas here..

# it seems we can only know oversampling factor (osf) if
# we have succesful read from attenload (so we have its
# length=num_samples); then, it can be found via:
# * Length factor: TMP[.csv]/.CSV: 900/225 = 4
# * RealTime period (table for TDIV)/chosen period (TMP[.csv]: scope_xrange/num_samples): 4ns / 1ns
# also for CSV, scope_xrange/num_samples = 900e-9/225 = 4e-09 (real period == realtime period)
# (only TMP/.csv oversamples, anyways!)
# (read osf from .csv file)

# NOTE: there are actually three ranges depending on T/DIV setting:
# oversample, exact sample and undersample
# must handle appropriately..

# these also bruteforce (to align to DAV):
# but actually .TMP/.csv is fine - the others need aligning
# (ofsset fine 18 maybe because there are 18 TDIVs, somehow??)
# so was: my $Dmove=-18;           # my $Cmove=19+$Dmove+2;
# but for one range, Dmove getting -18 - for another, -3*osf-18!
# and that also messes Cmove! so make Cmove independent of Dmove?

# also: when we have T/div 250ns/div; we have: .csv/.CSV: 2250/2250 4n[250M]/2n[500M]
# so same size arrays - but still oversampling!
# in this case, it seems that the last portion of .CSV is actually filled
# with repetition of the last sample (so, invalid!)
# that .CSV: start -0.00000225000; last valid  0.00005825000; last 0.00011020000
# 0.00011020000-0.00005825000 = 5.195e-05; 0.00005825000--0.00000225000 = 6.05e-05
# so not even symmetric!

# now also there could be undersampling! so must define undersample factor;
# oversample factor is applied to DAV/CSV - undersample to .csv
# (but there is no undersampling, actually - see below)..
my $usforig = 1;
if ($osf < 1) {
  $usforig = 1.0/$osf; # this first
  $osf = "1.00";
}
# attempt to do usf 5.00000039000001 -> 5?
#~ my $usf = int(sprintf("%f", $usforig));
# nope, that seems to result with more errors?
# seems better just to add int to csvi function (add int there everywhere)
# AH - actually, there seems to be no $usf? since in
# those ranges, the full 16000 of .csv are returned..
# so just keep $osf set to 1 if it is less..
# and $usf just for text printout (else remove it from calc)
my $usf = $usforig;

# since I cannot find a good formula for Cmove/Dmove
# will tune them manually - and enter them in %timediv_move_map
# as strings/formulas - so can use $osf and such in them
# here $tbase = $atghs or $adshs
# ALSO - add +0 to $atghs to enforce it's treatment as number,
# else it is not recognized as a key for the dict!
my $Dmove = eval ( $timediv_move_map{$atghs+0}[0] ); # Dmove .. '-2*$osf-31'
my $Cmove = eval ( $timediv_move_map{$atghs+0}[1] ); # Cmove .. '1*$osf-12'
# cmove (needed only for full size (16000) .csv?)
my $cmove = eval ( $timediv_move_map{$atghs+0}[2] ); # cmove == tfoi

my $toffssmp= int($atgtoffs/$atgcsvfinalts+0.5); # quick round()-ing

# as in attengrab-repair.pl:
# must also handle per-channel delay for .csv - via argument
# turns out, .CSV also needs per-channel delay - via argument
sub DAVi { return int(($_[0]-($dsz/2))*$osf+$toffssmp+$Dmove); }
sub CSVi { return int(($_[0]-($adsCSVdatlen/2))*$osf+$toffssmp+$Cmove+$_[1]); }
sub csvi { return int(($_[0]-($atgcsvdatlen/2))+$toffssmp+$cmove+$_[1]); }

sub iDAVi { return ($_[0]-$toffssmp-$Dmove)/$osf+($dsz/2); }
sub iCSVi { return ($_[0]-$toffssmp-$Cmove-$_[1])/$osf+($adsCSVdatlen/2); }
sub icsvi { return (($_[0]-$toffssmp-$cmove-$_[1])+($atgcsvdatlen/2)); }

# get_uint8_val(x) = floor(50*x+53) # no 255, no 127?
# get_real_val(x) = x*1/51+(-53/50) # better with 51
# 1/50 = 0.02; 1/51 = 0.0196078
# 8*VDIV/256 = 8*500e-3/256 = 0.015625; *adsfact: 0.015625*1.28 = 0.02;
# '(5-128)*0.02' = -2.46+1.5  = -0.96
#~ $voff1_ic = 132-$voff1_i;
#~ $voff1_bs = ((132-$voff1_i)/25)*$vdiv1_f;
#~ my $ch1Vcoeff = $adsFactor*$totalch1Vspan/(2**8);
#~ my $aval1 = ($adatch1[$i]-128-$voff1_ic)*$ch1Vcoeff;

sub get_realval_ch1 { return ($_[0]-128)*$adsFactor*8*$atgvscch1/256 - $atgvoffch1; }
sub get_realval_ch2 { return ($_[0]-128)*$adsFactor*8*$atgvscch2/256 - $atgvoffch2; }
sub get_uint8val_ch1 { return ($_[0]+ $atgvoffch1)*256/($adsFactor*8*$atgvscch1) + 128; }
sub get_uint8val_ch2 { return ($_[0]+ $atgvoffch2)*256/($adsFactor*8*$atgvscch2) + 128; }

sub get_signed_hex {
  my $tout = sprintf("% d", $_[0]);
  $tout =~ s/(.)(.*)/"$1".sprintf("%02X",$2)/e;
  return $tout;
}

# apparently, offsetting ch2 .csv (and .CSV?) is needed too:
my $csvi_offs_ch2  = eval ( $timediv_move_map{$atghs+0}[3] ); #-($osf-1);


# modified range indexes (modrgi)
# modrgimin/max - must do per channel as well, for correct table printout

my @modrgimin1 = ( DAVi(0),
                  CSVi(0,0),
                  csvi(0,0) );
my @modrgimax1 = ( DAVi($dsz-1),             # by last index
                  CSVi($adsCSVdatlen-1,0),
                  csvi($atgcsvdatlen-1,0) );
my @modrgimin2 = ( DAVi(0+$dsz),
                  CSVi(0,$csvi_offs_ch2),
                  csvi(0,$csvi_offs_ch2) );
my @modrgimax2 = ( DAVi($dsz-1+$dsz),             # by last index
                  CSVi($adsCSVdatlen-1,$csvi_offs_ch2),
                  csvi($atgcsvdatlen-1,$csvi_offs_ch2) );

say "";
say "Oversampling factor: $osf (u: $usf)";
say "Dmove $Dmove, Cmove $Cmove, cmove $cmove";
say "Transforming time index domains (for [smallest] period $atgcsvfinalts):";
say sprintf("(time offset %s = in samples: %d)", $atgtoffs,$toffssmp);
say sprintf(" .DAV: [%d,%d] ->(c|*%d)-> [%d,%d] ->(%d+%d)-> [%d,%d]",
0, $dsz-1,
$osf,
-($dsz/2)*$osf, ($dsz/2-1)*$osf,
$toffssmp, $Dmove,
#$modrgimin[0], $modrgimax[0]
min($modrgimin1[0],$modrgimin2[0]), max($modrgimax1[0],$modrgimax2[0])
);
say sprintf(" .CSV: [%d,%d] ->(c|*%d)-> [%d,%d] ->(%d+%d)-> [%d,%d]",
0, $adsCSVdatlen-1,
$osf,
-($adsCSVdatlen/2)*$osf, ($adsCSVdatlen/2-1)*$osf,
$toffssmp, $Cmove,
#$modrgimin[1], $modrgimax[1]
min($modrgimin1[1],$modrgimin2[1]), max($modrgimax1[1],$modrgimax2[1])
);
say sprintf(" .csv: [%d,%d] ->(c|)-> [%d,%d] ->(%d+%d)-> [%d,%d]",
0, $atgcsvdatlen-1,
-($atgcsvdatlen/2), ($atgcsvdatlen/2-1),
$toffssmp, $cmove,
#$modrgimin[2], $modrgimax[2]
min($modrgimin1[2],$modrgimin2[2]), max($modrgimax1[2],$modrgimax2[2])
);

# find absolute smallest and largest index for iterating
# sort numerically ascending
# (simply reusing sortch here..)
#@sortch1 = sort {$a <=> $b} @modrgimin1;
#@sortch2 = sort {$a <=> $b} @modrgimax1;
#my ($itmin,$itmax)=($sortch1[0],$sortch2[-1]);
#my ($trunc_min,$trunc_max)=($sortch1[1],$sortch2[1]);
# actually, since we want overlap;
# we just want to see where .csv ends
# no need for complicating trunc_
@sortch1 = sort {$a <=> $b} @modrgimin1;
@sortch2 = sort {$a <=> $b} @modrgimin2;
my $itmin = min($sortch1[0], $sortch2[0]);
#~ my $trunc_min = min(
  #~ min($modrgimin1[1],$modrgimin2[1]) ,
  #~ min($modrgimin1[2],$modrgimin2[2])
  #~ );
my $trunc_min = min(
  $modrgimin1[2],$modrgimin2[2]
  );
@sortch1 = sort {$a <=> $b} @modrgimax1;
@sortch2 = sort {$a <=> $b} @modrgimax2;
my $itmax = max($sortch1[-1], $sortch2[-1]);
#~ my $trunc_max = max(
  #~ max($modrgimax1[1],$modrgimax2[1]) ,
  #~ max($modrgimax1[2],$modrgimax2[2])
  #~ );
my $trunc_max = max(
  $modrgimax1[2],$modrgimax2[2]
  );

say " (Full) Iteration indexes: [$itmin:$itmax]";
my $xhrg = 20; # half x range (in [smallest: $ix] samples) to be seen (for zoom&printout)


# NOTE: when oversample is 80, the
# (Full) Iteration indexes: [$itmin:$itmax]
# can go all the way up to 16000*80 = 1.28e+06 !!
# this makes code extremely slow,
# and we anyways need only to compare..
# so use "Partial printout" range instead!
# BUT... the actual partial: [$trunc_min-$xhrg:$trunc_max-$xhrg]
# (not anymore: makes some indexes (may) dissapear; so try *2:
# ... bad index calc)
my $printmin = $trunc_min-$xhrg;
my $printmax = $trunc_max+$xhrg;
$itmin = $printmin;
$itmax = $printmax;

say "\nPartial process [or printout]: ( ", $printmin, " <= ix <= ", $printmax, " )\n";

if ($print_table_stdout) {
say sprintf(
"%6s(%7s)".
"|${bold}%2s${bold}:%2s${bold}_%2s${norm}(%3s_%3s/%3s)".
"|${bold}%2s${bold}:%2s${bold}_%2s${norm}(%3s_%3s/%3s)".
" .. {".
"%6s_%6s:|%6s_%6s|%6s_%6s".
" }"
,
  "indx","rtime",
  #~ "D1","C1","c1", "ecD","eCD","eCc",
  "D1","C1","c1", "cD1","CD1","Cc1",
  #~ "D2","C2","c2", "ecD","eCD","eCc",
  "D2","C2","c2", "cD2","CD2","Cc2",
  "rtC","rtc","rvC1","rvc1","rvC2","rvc2"
);
}


# prep output;
# do not interpolate for finding errors
# try to write the floating values as formatted strings


STDOUT->autoflush(1);
my @outa = ();
my @abserr = (0)x6;
my @err = (0)x6;

if (not($dry_run)) {
  &loop_computeError_or_printstdout();
}

# this just to print out dict lines (if needed):
## say "__ $atghs  ,  [$adsCSVdatlen, $atgcsvdatlen, $osf],  ";

say "Sum of (abs.) errors:";
say sprintf(" Ch1: csv to DAV: (%d) %d; CSV to DAV: (%d) %d; CSV to csv: (%d) %d",
  $abserr[0], $err[0], $abserr[1], $err[1], $abserr[2],  $err[2] );
say sprintf(" Ch2: csv to DAV: (%d) %d; CSV to DAV: (%d) %d; CSV to csv: (%d) %d",
  $abserr[3], $err[3], $abserr[4], $err[4], $abserr[5],  $err[5] );

STDOUT->flush();


# now we have @outa - can query for minmax ranges for gnuplot

# search by index (of $atgcsvfinalts, centered) - return voltages
my ($xrg01ymin, $xrg01ymax) = get_overall_yval_minmax_ch1($trunc_min-$xhrg, $trunc_max+$xhrg);

# search by index (of $atgcsvfinalts, centered) - return uint8
my ($y31min, $y31max) = get_overall_yvali_minmax_ch1((-$atgcsvdatlen/2)+$toffssmp+$cmove-$xhrg, (-$atgcsvdatlen/2)+$toffssmp+$cmove+$xhrg);
my ($y32min, $y32max) = get_overall_yvali_minmax_ch1($toffssmp+$cmove-$xhrg, $toffssmp+$cmove+$xhrg);
my ($y33min, $y33max) = get_overall_yvali_minmax_ch1((-$atgcsvdatlen/2)+$atgcsvdatlen-1+$toffssmp+$cmove-$xhrg, (-$atgcsvdatlen/2)+$atgcsvdatlen-1+$toffssmp+$cmove+$xhrg);

# search by index (of $atgcsvfinalts, centered) - return voltages
# (here by index - in gnuplot below it's by real timestamp)
# NOTE: in row 5, we're most interested in seeing how
# .CSV aligns with .csv
# so find where they overlap - otherwise keep xhrg range
my $acsvL = (-$atgcsvdatlen/2)+$toffssmp+$cmove;
my $acsvR = ($atgcsvdatlen/2-1)+$toffssmp+$cmove;
my $CSVL = (-$adsCSVdatlen/2)*$osf+$toffssmp+$Cmove ;
my $CSVR = ($adsCSVdatlen/2-1)*$osf+$toffssmp+$Cmove ;
# choose left edge
my $difL = $CSVL-$acsvL ; # (CSVL < aco)
#~ my $EdgL = ($difL < 0) ? $CSVL : $acsvL ;
my $EdgL = ($difL < 0) ? $acsvL : $CSVL ;
# chose right edge
my $difR = $CSVR - $acsvR ; # (CSVR > acsvR)
#~ my $EdgR = ($difR > 0) ? $CSVR : $acsvR ;
my $EdgR = ($difR > 0) ? $acsvR : $CSVR ;
# choose left/right ranges
#~ my $xhrgtL = (abs($xhrg) > abs($difL)) ? $xhrg : $difL ;
my $xhrgtL = $xhrg ;
my $xmid = $EdgL+($EdgR-$EdgL)/2 ;
#~ my $xhrgtR = (abs($xhrg) > abs($difR)) ? $xhrg : $difR ;
my $xhrgtR = $xhrg ;

my ($y51min, $y51max) = get_overall_yval_minmax_ch1($EdgL-$xhrgtL, $EdgL+$xhrgtL);
my ($y52min, $y52max) = get_overall_yval_minmax_ch1($xmid-$xhrg, $xmid+$xhrg);
my ($y53min, $y53max) = get_overall_yval_minmax_ch1($EdgR-$xhrgtR, $EdgR+$xhrgtR);


# generate gnuplot file for finding/visualising alignment delays
my $ofngps = "adscompare.gnuplot";
my $ofhgps;
my $gpstr = join('', <DATA>);
# expand variables
$gpstr =~ s/(\${\w+})/${1}/eeg;
open($ofhgps,'>',"$ofngps") or die "Cannot open $ofngps ($!)";
print { $ofhgps } $gpstr;
close($ofhgps);
say "Saved $ofngps";

if (not($dry_run)) {
print "Running gnuplot $ofngps .. ";
STDOUT->flush(); # no effect here (in less)
#~ my $gpstatus = system("gnuplot", "$ofngps");
#~ if (($gpstatus >>=8) != 0) {
    #~ die "Failed to run gnuplot!";
#~ }
# capture output with backticks:
  my $gpret = `gnuplot "$ofngps" 2>&1`;
  say "Gnuplot returned: $gpret" . ( ($gpret eq "") ? "(OK)" : "" ) ;
}


## END MAIN ################################

sub loop_computeError_or_printstdout {

for (my $ix = $itmin; $ix <= $itmax; $ix++) {
  my @to = ();
  my @fto = (); # string format
  my ($fDs, $fDe, $fC1s, $fC1e, $fC2s, $fC2e) = ("")x6;
  my $tind; # temporary index calc storage (to go a bit faster ?!)

  push(@to, $ix);
  push(@to, format_pref(sprintf("%.2e",$ix*$atgcsvfinalts))); # real ts
  $fto[0] = sprintf("%+5d", $to[0]);
  $fto[1] = sprintf("%7s", $to[1]);

  my @tt = ('', '', ''); # 2,3,4
  @fto[2..4] = @tt[0..2];

  $tind = iDAVi($ix);
  if (($tind >= 0) and ($tind < $dsz)) {
    if ($tind==int($tind)) {
      $tt[0] = $tind;
      $tt[1] = $adavdata[$tind];
      $tt[2] = $adavdata[$tind+$dsz];

      $fto[2] = sprintf("% 6d", $tt[0]);
      $fto[3] = sprintf("%02X", $tt[1]);
      $fto[4] = sprintf("%02X", $tt[2]);
      ($fDs, $fDe) = (BLUE . ON_WHITE, RESET); # CLEAR, RESET synonyms
    }
  }
  push(@to, @tt); # simply appends @tt elements to @to!

  @tt = ('', '', '', '', '', '', '', '', '', ''); #5,6,7,8,9,10,11,12,13,14
  @fto[5..14] = @tt[0..9];

  $tind = iCSVi($ix,0);
  if (($tind >= 0) and ($tind < $adsCSVdatlen)) {
    if ($tind==int($tind)) {
      $tt[0] = $tind;
      my @adsCSVline = @{$adsCSVdata[$tind]};
      $tt[1] = get_uint8val_ch1($adsCSVline[1]);
      #~ $tt[2] = get_uint8val_ch2($adsCSVline[2]);
      $tt[3] = $tt[1]-$adavdata[int(iDAVi($ix))];         # int error ch1 (CSV to DAV)
      #~ $tt[4] = $tt[2]-$adavdata[int(iDAVi($ix))+$dsz];    # int error ch2 (CSV to DAV)
      # here we already check above, if iCSVi is correct;
      # however, we must also check if icsvi is correct - here
      # we might get an index out of bounds for $atgcsvdata!
      if ( icsvi($ix,0) <  $atgcsvdatlen ) {
        $tt[5] = $tt[1]-@{$atgcsvdata[int(icsvi($ix,0))]}[1]; # int error ch1 (CSV to csv)
      } else {
        $tt[5] = 0 ; # since we're out of bounds
      }
      # now that we're moving, val could be null - check ; now separate
      #~ if (@{$atgcsvdata[int(icsvi($ix,$csvi_offs_ch2))]}[2]) {
        #~ $tt[6] = $tt[2]-@{$atgcsvdata[int(icsvi($ix,$csvi_offs_ch2))]}[2]; # int error ch2 (CSV to csv)
      #~ }
      $tt[7] = format_pref( $adsCSVline[0] ); # orig real ts & vals
      $tt[8] = format_pref( $adsCSVline[1] ); #
      #~ $tt[9] = format_pref( $adsCSVline[2] ); #

      $fto[5] = sprintf("% 6d", $tt[0]);
      $fto[6] = sprintf("%02X", $tt[1]);
      #~ $fto[7] = sprintf("%02X", $tt[2]);
      $fto[8] = get_signed_hex($tt[3]);
      #~ $fto[9] = get_signed_hex($tt[4]);
      $fto[10] = get_signed_hex($tt[5]);
      #~ $fto[11] = get_signed_hex($tt[6]);
      $fto[12] = $tt[7];
      $fto[13] = $tt[8];
      #~ $fto[14] = $tt[9];
      ($fC1s, $fC1e) = (RED . ON_WHITE, RESET);
      #~ ($fC2s, $fC2e) = (RED . ON_WHITE, RESET);

      # accumulate only in these moments
      #~ $abserr[0] += $tt[3]; # int error ch1 (csv to DAV)
      $abserr[1] += abs($tt[3]); # int error ch1 (CSV to DAV)
      $abserr[2] += abs($tt[5]); # int error ch1 (CSV to csv)
      $err[1] += $tt[3];
      $err[2] += $tt[5];
      #~ $abserr[3] += $tt[4]; # int error ch2 (csv to DAV)
      #~ $abserr[4] += $tt[4]; # int error ch2 (CSV to DAV)
      #~ $abserr[5] += $tt[6]; # int error ch2 (CSV to csv)
    }
  }

  $tind = iCSVi($ix,$csvi_offs_ch2);
  if (($tind >= 0) and ($tind < $adsCSVdatlen)) {
    if ($tind==int($tind)) {
      $tt[0] = $tind;
      my @adsCSVline = @{$adsCSVdata[$tind]};
      #~ $tt[1] = get_uint8val_ch1($adsCSVline[1]);
      $tt[2] = get_uint8val_ch2($adsCSVline[2]);
      #~ $tt[3] = $tt[1]-$adavdata[int(iDAVi($ix))];         # int error ch1 (CSV to DAV)
      $tt[4] = $tt[2]-$adavdata[int(iDAVi($ix))+$dsz];    # int error ch2 (CSV to DAV)
      #~ $tt[5] = $tt[1]-@{$atgcsvdata[int(icsvi($ix,0))]}[1]; # int error ch1 (CSV to csv)
      # here we already check above, if iCSVi is correct;
      # however, we must also check if icsvi is correct - here
      # we might get an index out of bounds for $atgcsvdata!
      if ( icsvi($ix,$csvi_offs_ch2) <  $atgcsvdatlen ) {
        $tt[6] = $tt[2]-@{$atgcsvdata[int(icsvi($ix,$csvi_offs_ch2))]}[2]; # int error ch2 (CSV to csv)
      } else {
        $tt[6] = 0 ; # since we're out of bounds
      }
      $tt[7] = format_pref( $adsCSVline[0] ); # orig real ts & vals
      #~ $tt[8] = format_pref( $adsCSVline[1] ); #
      $tt[9] = format_pref( $adsCSVline[2] ); #

      $fto[5] = sprintf("% 6d", $tt[0]);
      #~ $fto[6] = sprintf("%02X", $tt[1]);
      $fto[7] = sprintf("%02X", $tt[2]);
      #~ $fto[8] = get_signed_hex($tt[3]);
      $fto[9] = get_signed_hex($tt[4]);
      #~ $fto[10] = get_signed_hex($tt[5]);
      $fto[11] = get_signed_hex($tt[6]);
      $fto[12] = $tt[7];
      #~ $fto[13] = $tt[8];
      $fto[14] = $tt[9];
      #~ ($fC1s, $fC1e) = (RED . ON_WHITE, RESET);
      ($fC2s, $fC2e) = (RED . ON_WHITE, RESET);

      # accumulate only in these moments
      #~ $abserr[0] += $tt[3]; # int error ch1 (csv to DAV)
      #~ $abserr[1] += $tt[3]; # int error ch1 (CSV to DAV)
      #~ $abserr[2] += $tt[5]; # int error ch1 (CSV to csv)
      #~ $abserr[3] += $tt[4]; # int error ch2 (csv to DAV)
      $abserr[4] += abs($tt[4]); # int error ch2 (CSV to DAV)
      $abserr[5] += abs($tt[6]); # int error ch2 (CSV to csv)
      $err[4] += $tt[4];
      $err[5] += $tt[6];
    }
  }
  push(@to, @tt);

  @tt = ('', '', '', '', '', '', '', ''); # 15,16,17,18,19,20,21,22
  @fto[15..22] = @tt[0..7];
  # ch1, ch2 separate - to handle delay

  $tind = icsvi($ix,0);
  if (($tind >= 0) and ($tind < $atgcsvdatlen)) {
    if ($tind==int($tind)) { # always should be int here, but anyways
      $tt[0] = $tind;
      my @atgcsvline = @{$atgcsvdata[$tind]};
      $tt[1] = $atgcsvline[1];
      #~ $tt[2] = $atgcsvline[2];
      $tt[3] = $tt[1]-$adavdata[int(iDAVi($ix))];         # int error ch1 (csv to DAV)
      #~ $tt[4] = $tt[2]-$adavdata[int(iDAVi($ix))+$dsz];    # int error ch2 (csv to DAV)
      $tt[5] = format_pref( $atgcsvline[3] ); # orig real ts & vals
      $tt[6] = format_pref( $atgcsvline[4] ); #
      #~ $tt[7] = format_pref( $atgcsvline[5] ); #

      $fto[15] = sprintf("% 6d", $tt[0]);
      $fto[16] = sprintf("%02X", $tt[1]);
      #~ $fto[17] = sprintf("%02X", $tt[2]);
      $fto[18] = get_signed_hex($tt[3]);
      #~ $fto[19] = get_signed_hex($tt[4]);
      $fto[20] = $tt[5];
      $fto[21] = $tt[6];
      #~ $fto[22] = $tt[7];

      if (not($fDs eq '')) { # ($indicD) { # accumulate only in these moments
        $abserr[0] += abs($tt[3]); # int error ch1 (csv to DAV)
        $err[0] += $tt[3];
        #~ $abserr[3] += $tt[4]; # int error ch2 (csv to DAV)
      }

    }
  }

  $tind = icsvi($ix,$csvi_offs_ch2);
  if (($tind >= 0) and ($tind < $atgcsvdatlen)) {
    if ($tind==int($tind)) { # always should be int here, but anyways
      $tt[0] = $tind;
      my @atgcsvline = @{$atgcsvdata[$tind]};
      #~ $tt[1] = $atgcsvline[1];
      $tt[2] = $atgcsvline[2];
      #~ $tt[3] = $tt[1]-$adavdata[int(iDAVi($ix))];         # int error ch1 (csv to DAV)
      $tt[4] = $tt[2]-$adavdata[int(iDAVi($ix))+$dsz];    # int error ch2 (csv to DAV)
      $tt[5] = format_pref( $atgcsvline[3] ); # orig real ts & vals
      #~ $tt[6] = format_pref( $atgcsvline[4] ); #
      $tt[7] = format_pref( $atgcsvline[5] ); #

      $fto[15] = sprintf("% 6d", $tt[0]);
      #~ $fto[16] = sprintf("%02X", $tt[1]);
      $fto[17] = sprintf("%02X", $tt[2]);
      #~ $fto[18] = get_signed_hex($tt[3]);
      $fto[19] = get_signed_hex($tt[4]);
      $fto[20] = $tt[5];
      #~ $fto[21] = $tt[6];
      $fto[22] = $tt[7];

      if (not($fDs eq '')) { # ($indicD) { # accumulate only in these moments
        #~ $abserr[0] += $tt[3]; # int error ch1 (csv to DAV)
        $abserr[3] += abs($tt[4]); # int error ch2 (csv to DAV)
        $err[3] += $tt[4];
      }
    } # $csvi_offs_ch2
  }
  push(@to, @tt);

  # we still have $sortch1[1] (next smallest, $sortch2 next largest), $xhrg
  # use it to modify what we printout
  # (now have to take both channels in account - via printmin/max (above))
  if (($ix >= $printmin) and ($ix <= $printmax)) {
    #~ say join(", ", @to);
    my ($fcs, $fce) = ($fC1s.$fC2s , $fC1e.$fC2e);
    if ($print_table_stdout) {
    say sprintf(
"${fDs}%6s(%7s)${fDe}".
"|${bold}${fDs}%2s${fDe}${bold}:${fC1s}%2s${fC1e}${bold}_%2s${norm}(%3s_%3s/%3s)".
"|${bold}${fDs}%2s${fDe}${bold}:${fC2s}%2s${fC2e}${bold}_%2s${norm}(%3s_%3s/%3s)".
" .. {".
"${fcs}%6s${fce}_%6s:|${fC1s}%6s${fC1e}_%6s|${fC2s}%6s${fC2e}_%6s".
" }"
,
      $fto[0],$fto[1],
      $fto[3],$fto[6],$fto[16], $fto[8],$fto[18],$fto[10],
      $fto[4],$fto[7],$fto[17], $fto[9],$fto[19],$fto[11],

      $fto[12],$fto[20], $fto[13],$fto[21] , $fto[14],$fto[22]
    );
  } # endif $print_table_stdout
  STDOUT->flush();
  }
  push(@outa, \@to); # must push ARRAY ref here, for 2D index!
} # end for

} # end sub



sub get_overall_yval_minmax_ch1 {
  # search by index (of $atgcsvfinalts, centered) - return voltages
  my $ixmin = $_[0];
  my $ixmax = $_[1];
  # careful - set mins to big ones initially
  my ($cmin,$cmax,$Cmin,$Cmax,$Dmin,$Dmax,$omin,$omax) = (1e6,-1e6)x4;
  for (my $ix = $ixmin; $ix <= $ixmax; $ix++) { #
    my ($io, @trow);
    my ($cval_ch1,$Cval_ch1,$Dval_ch1) = (undef)x3;
    eval {
    # @outa goes from $itmin (negative) to $itmax (positive)
    $io = $ix - $itmin;
    # check index - may get out of bounds here!
    if ($io < scalar(@outa)) {
      # for trow, look up $fto indexes
      @trow = @{$outa[$io]};
      # get orig values - unformat_pref if needed
      if ($trow[21]) { # if not empty
        $cval_ch1 = unformat_pref($trow[21]);
      }
      if ($trow[13]) { $Cval_ch1 = unformat_pref($trow[13]); }
      if ($trow[3]) { $Dval_ch1 = get_realval_ch1($trow[3]); }

      if (defined($cval_ch1)) { if ($cval_ch1<$cmin) { $cmin = $cval_ch1; } }
      if (defined($cval_ch1)) { if ($cval_ch1>$cmax) { $cmax = $cval_ch1; } }
      if (defined($Cval_ch1)) { if ($Cval_ch1<$Cmin) { $Cmin = $Cval_ch1; } }
      if (defined($Cval_ch1)) { if ($Cval_ch1>$Cmax) { $Cmax = $Cval_ch1; } }
      if (defined($Dval_ch1)) { if ($Dval_ch1<$Dmin) { $Dmin = $Dval_ch1; } }
      if (defined($Dval_ch1)) { if ($Dval_ch1>$Dmax) { $Dmax = $Dval_ch1; } }
    } # if ($io < scalar(@outa))
  }; # eval
  warn $@ if $@;
  } # for
  $omin = min( ($cmin,$Cmin,$Dmin) );
  $omax = max( ($cmax,$Cmax,$Dmax) );
  return ($omin, $omax);
}

sub get_overall_yvali_minmax_ch1 {
  # search by index (of $atgcsvfinalts, centered) - return uint8
  my $ixmin = $_[0];
  my $ixmax = $_[1];
  # careful - set mins to big ones initially
  my ($cmin,$cmax,$Cmin,$Cmax,$Dmin,$Dmax,$omin,$omax) = (1e6,-1e6)x4;
  for (my $ix = $ixmin; $ix <= $ixmax; $ix++) { #
    # @outa goes from $itmin (negative) to $itmax (positive)
    my $io = $ix - $itmin;
    # check index - may get out of bounds here!
    if ($io < scalar(@outa)) {
      # for trow, look up $fto indexes
      my @trow = @{$outa[$io]};
      # get orig values - unformat_pref if needed
      my ($cval_ch1,$Cval_ch1,$Dval_ch1) = (undef)x3;
      if ($trow[16]) { # if not empty
        $cval_ch1 = $trow[16];
      }
      if ($trow[13]) { $Cval_ch1 = get_uint8val_ch1(unformat_pref($trow[13])); }
      if ($trow[3]) { $Dval_ch1 = $trow[3]; }

      if (defined($cval_ch1)) { if ($cval_ch1<$cmin) { $cmin = $cval_ch1; } }
      if (defined($cval_ch1)) { if ($cval_ch1>$cmax) { $cmax = $cval_ch1; } }
      if (defined($Cval_ch1)) { if ($Cval_ch1<$Cmin) { $Cmin = $Cval_ch1; } }
      if (defined($Cval_ch1)) { if ($Cval_ch1>$Cmax) { $Cmax = $Cval_ch1; } }
      if (defined($Dval_ch1)) { if ($Dval_ch1<$Dmin) { $Dmin = $Dval_ch1; } }
      if (defined($Dval_ch1)) { if ($Dval_ch1>$Dmax) { $Dmax = $Dval_ch1; } }
    } # if ($io < scalar(@outa))
  } # for
  $omin = min( ($cmin,$Cmin,$Dmin) );
  $omax = max( ($cmax,$Cmax,$Dmax) );
  return ($omin, $omax);
}


sub process_adsCSV{

open($fh,'<',$adsCSVfile) or die "Cannot open $adsCSVfile ($!)";
binmode($fh);
#my @csvlines = <$fh>;

while (<$fh>) {
  if ($dopack) {
    # skip any potential commented lines (#) remaining
    next if ($_ =~ "^#");
    chomp($_);
    $_ =~ s/^\s+//; #ltrim
    $_ =~ s/\s+$//; #rtrim
    my @csvline = split(",", $_);
    push(@adsCSVdata, \@csvline); # must push ARRAY ref here, for 2D index!
    push(@adstimevals, $csvline[0]);
    push(@adsch1vals, $csvline[1]);
    push(@adsch2vals, $csvline[2]);
    $adsCSVdatlen++;
  } else {
    if ($_ =~ /Record Length/) {
      # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
      ($rest, $adsCSVreclen) = split /,/, $_, 2;
      chomp($adsCSVreclen);
    }
    if ($_ =~ /Sample Interval/) {
      # NOTE: Sample interval refers to time domain; NOT voltage!
      # (sampling period)
      my $siboth="";
      ($rest, $siboth) = split /,/, $_, 2;
      chomp($siboth);
      my ($s1h, $s2h) = split / /, $siboth, 2;
      $adssampintch1 = substr($s1h,index($s1h,":")+1);
      $adssampintch2 = substr($s2h,index($s2h,":")+1);
    }
    if ($_ =~ /Vertical Units/) {
      # NOTE: Voltage
      my $vuboth="";
      ($rest, $vuboth) = split /,/, $_, 2;
      chomp($vuboth);
      $vuboth =~ s/,,//g; # remove ,,
      my ($vu1h, $vu2h) = split / /, $vuboth, 2;
      $adsvuch1 = substr($vu1h,index($vu1h,":")+1);
      $adsvuch2 = substr($vu2h,index($vu2h,":")+1);
    }
    if ($_ =~ /Vertical Scale/) {
      # NOTE: Voltage
      my $vscboth="";
      ($rest, $vscboth) = split /,/, $_, 2;
      chomp($vscboth);
      $vscboth =~ s/,,//g; # remove ,,
      my ($vsc1h, $vsc2h) = split / /, $vscboth, 2;
      $adsvscch1 = substr($vsc1h,index($vsc1h,":")+1);
      $adsvscch2 = substr($vsc2h,index($vsc2h,":")+1);
    }
    if ($_ =~ /Vertical Offset/) {
      # NOTE: Voltage
      my $vofboth="";
      ($rest, $vofboth) = split /,/, $_, 2;
      chomp($vofboth);
      $vofboth =~ s/,,//g; # remove ,,
      my ($vof1h, $vof2h) = split / /, $vofboth, 2;
      $adsvoffch1 = substr($vof1h,index($vof1h,":")+1);
      $adsvoffch2 = substr($vof2h,index($vof2h,":")+1);
    }
    if ($_ =~ /Horizontal Units/) {
      # NOTE: time
      ($rest, $adshu) = split /,/, $_, 2;
      chomp($adshu);
      $adshu =~ s/,,//g; # remove ,,
    }
    if ($_ =~ /Horizontal Scale/) {
      # NOTE: time; == timebase
      ($rest, $adshs) = split /,/, $_, 2;
      chomp($adshs);
      $adshs =~ s/,,//g; # remove ,,
    }
    if ($_ =~ /Second,Volt,Volt/) {
      $dopack = 1;
    }
  }
}
close($fh);
}


sub process_atgcsv {

open($fh,'<',$atgcsvfile) or die "Cannot open $atgcsvfile ($!)";
binmode($fh);

while (<$fh>) {
  if ($dopack) {
    # skip any potential commented lines (#) remaining
    next if ($_ =~ "^#");
    chomp($_);
    $_ =~ s/^\s+//; #ltrim
    $_ =~ s/\s+$//; #rtrim
    my @csvline = split(",", $_);
    push(@atgcsvdata, \@csvline); # must push ARRAY ref here, for 2D index!
    push(@atgtimevals, $csvline[3]);
    push(@atgch1valsi, $csvline[1]);
    push(@atgch2valsi, $csvline[2]);
    push(@atgch1valsr, $csvline[4]);
    push(@atgch2valsr, $csvline[5]);
    $atgcsvdatlen++;
  } else {
    if ($_ =~ /Number of samples in data/) {
      # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
      chomp($_);
      my @resp = split / /, $_;   #say "resp:", join("--",@resp);
      $atgreclen1 = $resp[8];
      # digits only; return match with () capture:
      $atgreclen2 = ($resp[11] =~ m/(\d+)/)[0];
      if ($atgreclen2 > $atgreclen1) { $atgcsvreclen = $atgreclen2; }
      else { $atgcsvreclen = $atgreclen1; }
    }
    if ($_ =~ /Sampling interval \(screen_range\/num_samples\)/) {
      # NOTE: Sample interval refers to time domain; NOT voltage!
      # (sampling period)
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling interval \(screen_range\/num_samples\)   : //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgsampint = $resp[0];
    }
    if ($_ =~ /Sampling rate \(scope Acquire menu,2CH RealTime\):/) {
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling rate \(scope Acquire menu,2CH RealTime\): //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $rtsamprate = $resp[0];
    }
    if ($_ =~ /final timestep:/) {
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/#  { final timestep: //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgcsvfinalts = $resp[0];
    }
    if ($_ =~ /Oversample factor:/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $osf = $resp[3];
    }
    if ($_ =~ /Time offset:/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgtoffs = $resp[3];
    }
    if ($_ =~ /Timebase/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atghs = $resp[5];
      $atghu = $resp[6];
    }
    if ($_ =~ /Ch1 V\/DIV/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch1 = $resp[5];
      $atgvuch1 = $resp[6];
    }
    if ($_ =~ /Ch2 V\/DIV/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch2 = $resp[5];
      $atgvuch2 = $resp[6];
    }
    # $atgvoffch1 $atgvoffch2
    if ($_ =~ /Ch1 Voffset/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvoffch1 = $resp[3];
    }
    if ($_ =~ /Ch2 Voffset/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvoffch2 = $resp[3];
    }
    if ($_ =~ /------------------------/) {
      # there are two of these, but are commented
      # so should be skipped by the engine
      $dopack = 1;
    }
  }
}
close($fh);
}


## END ALL  ################################


# just archiving here:

sub old_failed_compare_function {

  # sample delay between csv and CSV required to make them align in gnuplot:
  # set it here after finding it via gnuplot script (generated next):
  my $sdelayCSVcsv = 8156;


  # sample delays to test alignment
  # consider we loop through DAV, starting at 0
  # so sample delays should be positive (>=0)
  # (also, look for 0.000e\+00, align that to check if timestamps are OK)

  my $sdelayDAVcsv = 40; # csv can be aligned to DAV via searching for unique hex combos (7F 7E) in table
  my $sdelayDAVCSV = $sdelayCSVcsv+$sdelayDAVcsv-5625; #8156 from gnuplot test + 40 from previous -5625 via searching for unique real combos (4.250e-01  0.000e\+00); match all three at total 2571 delay

  # at that alignment, ts: -2.250e-03 <> 1.012e-03; '(1.012e-3)-(-2.250e-3)' = 0.003262 ... direct in here: 0.0032624 (mostly, also 0.00326240016 or 0.00326240013 or 0.00326240025); 0.0032624/0.0000004 = 8156; so that is like the gnuplot delay (to have the real timestamps match)
  # so, need to add this value to have .csv real timestamp (start from 0.0) match the .CSV timestamp (start from -x)
  my $adjcsvtrval = -$sdelayCSVcsv*$atgsampint;

  say "";
  say "Using sample delay DAV(16384)->CSV($adsCSVdatlen): $sdelayDAVCSV";
  say "                   DAV(16384)->csv($atgcsvdatlen): $sdelayDAVcsv";

  say "";
  say "Dumping data:";

  say "";
  say "\
  |DAV            |CSV                                              |csv                                                          ";
  #|    0: 7F 80   |          :                             /        |          :                             /       (          /)";



  # * 2*4 =  8 divs vertically (voltage)
  # adsparse -> atg
  my $totalch1Vspan =  8*$atgvscch1; #$vdiv1;
  my $totalch2Vspan =  8*$atgvscch2;
  my $ch1Vcoeff = $totalch1Vspan/(2**8);
  my $ch2Vcoeff = $totalch2Vspan/(2**8);
  # my $aval1 = ($adatch1[$i]-128-$voff1_ic)*$ch1Vcoeff;
  # $adatch1[$i] = ($aval1/$ch1Vcoeff)+128+$voff1_ic

  my ($davval1, $davval2) = (0)x2;
  my ($adsindex, $atgindex) = (0)x2;
  my (@adsCSVline, @atgcsvline);
  my ($abserrCSV1, $abserrCSV2) = (0)x2;
  my ($abserrcsv1, $abserrcsv2) = (0)x2;

  for ( my $i = 0; $i < 0x4000; $i++ ) {
    $davval1 = $adavdata[$i];
    $davval2 = $adavdata[$i+0x4000];

    $adsindex = $i-$sdelayDAVCSV;
    $atgindex = $i-$sdelayDAVcsv;

    my $ostr;
    my ($adstr, $atgtr, $adjatgtr, $adjatsadsdelta) = (0)x4;
    my ($adstrs, $atgtrs, $adjatgtrs, $adjatsadsdeltas) = ("")x4;
    my ($adsch1r, $adsch2r) = (0)x2;
    my ($adsch1str, $adsch2str) = ("")x2;
    my ($adsival1s, $adsival2s) = ("")x2;
    my ($atgch1r, $atgch2r) = (0)x2;
    my ($atgch1str, $atgch2str) = ("")x2;
    my ($atgch1i, $atgch2i) = (0)x2;
    my ($atgch1sti, $atgch2sti) = ("")x2;
    my ($diffCSVdav1i, $diffCSVdav2i) = (0)x2;
    my ($diffCSVdav1is, $diffCSVdav2is) = ("")x2;
    my ($diffcsvdav1i, $diffcsvdav2i) = (0)x2;
    my ($diffcsvdav1is, $diffcsvdav2is) = ("")x2;

    my $inadsdata = (($adsindex>=0) and ($adsindex<$adsCSVdatlen));
    if ( $inadsdata ) {
      @adsCSVline = @{$adsCSVdata[$adsindex]}; # say "ads: ", join("--",@adsCSVline);

      $adstr = $adsCSVline[0];
      # scientific notation, space for +- , and fixed number of exponent digits
      $adstrs = sprintf "% .3e", $adstr;
      $adstrs =~ s/(e[+-])(.*)/"$1".sprintf("%02d",$2)/e;
      # scaled with ads factor:
      $adsch1r = $adsCSVline[1]*$adsFactor;
      $adsch2r = $adsCSVline[2]*$adsFactor;
      $adsch1str = sprintf "% .3e", $adsch1r;
      $adsch2str = sprintf "% .3e", $adsch2r;

      # calc derived integers; since here we've scaled
      #  with $adsFactor; can now use the scalefactor from
      #  adsparse-wave:
      my $adsival1 = ($adsch1r/$ch1Vcoeff)+128; #+$voff1_ic
      my $adsival2 = ($adsch2r/$ch1Vcoeff)+128; #+$voff1_ic
      $adsival1s = sprintf "%2X", $adsival1;
      $adsival2s = sprintf "%2X", $adsival2;

      # diff from .DAV values
      $diffCSVdav1i = $adsival1-$davval1;
      $diffCSVdav2i = $adsival2-$davval2;
      $abserrCSV1 += abs($diffCSVdav1i);
      $abserrCSV2 += abs($diffCSVdav2i);
      # for "signed" hex:
      $diffCSVdav1is = sprintf "% d", $diffCSVdav1i;
      $diffCSVdav2is = sprintf "% d", $diffCSVdav2i;
      $diffCSVdav1is =~ s/(.)(.*)/"$1".sprintf("% X",$2)/e;
      $diffCSVdav2is =~ s/(.)(.*)/"$1".sprintf("% X",$2)/e;
    }

    my $inatgdata = (($atgindex>=0) and ($atgindex<$atgcsvdatlen));
    if ( $inatgdata ) {
      @atgcsvline = @{$atgcsvdata[$atgindex]};

      $atgtr = $atgcsvline[3];
      $atgtrs = sprintf "% .3e", $atgtr;
      $atgtrs =~ s/(e[+-])(.*)/"$1".sprintf("%02d",$2)/e;

      $atgch1r = $atgcsvline[4];
      $atgch2r = $atgcsvline[5];
      $atgch1str = sprintf "% .3e", $atgch1r;
      $atgch2str = sprintf "% .3e", $atgch2r;
      $atgch1i = $atgcsvline[1];
      $atgch2i = $atgcsvline[2];
      $atgch1sti = sprintf "%2X", $atgch1i;
      $atgch1sti = sprintf "%2X", $atgch1i;
      $atgch2sti = sprintf "%2X", $atgch2i;

      # calc adjusted real timestamp
      $adjatgtr = $atgtr + $adjcsvtrval;
      $adjatgtrs = sprintf "% .3e", $adjatgtr;
      $adjatgtrs =~ s/(e[+-])(.*)/"$1".sprintf("%02d",$2)/e;

      # diff from .DAV values
      $diffcsvdav1i = $atgch1i-$davval1;
      $diffcsvdav2i = $atgch2i-$davval2;
      $abserrcsv1 += abs($diffcsvdav1i);
      $abserrcsv2 += abs($diffcsvdav2i);
      # for "signed" hex:
      $diffcsvdav1is = sprintf "% d", $diffcsvdav1i;
      $diffcsvdav2is = sprintf "% d", $diffcsvdav2i;
      $diffcsvdav1is =~ s/(.)(.*)/"$1".sprintf("% X",$2)/e;
      $diffcsvdav2is =~ s/(.)(.*)/"$1".sprintf("% X",$2)/e;
    }
    if ($inadsdata and $inatgdata) {
      $adjatsadsdelta = $adjatgtr-$adstr;
      $adjatsadsdeltas = sprintf "% g", $adjatsadsdelta;
    }

    # output table string
    $ostr = sprintf("|%5d: ${under}%2X %2X${norm}   |%10s: ${bold}%10s %10s${norm}  %2s %2s/%3s%3s  |%10s: ${bold}%10s %10s${norm}  ${under}%2s %2s${norm}/%3s%3s (%10s/%s)",
      $i,                 # index of ADS' .DAV data (-16383)
      $davval1,           # .DAV ch1 value (hex, read)
      $davval2,           # .DAV ch1 value (hex, read)
      $adstrs,            # timestamp (real, read) from ADS' .CSV
      $adsch1str,         # ADS' .CSV ch1 value (real, read)
      $adsch2str,         # ADS' .CSV ch2 value (real, read)
      $adsival1s,         # ADS' .CSV ch1 value (hex, computed)
      $adsival2s,         # ADS' .CSV ch2 value (hex, computed)
      $diffCSVdav1is,     # difference of ADS' .CSV and .DAV ch1 value ("signed" hex)
      $diffCSVdav2is,     # difference of ADS' .CSV and .DAV ch2 value ("signed" hex)
      $atgtrs,            # timestamp (real, read) from attengrab's .csv
      $atgch1str,         #  .csv ch1 value (real, read)
      $atgch2str,         #  .csv ch2 value (real, read)
      $atgch1sti,         #  .csv ch1 value (hex, read)
      $atgch2sti,         #  .csv ch2 value (hex, read)
      $diffcsvdav1is,     # difference of .csv and .DAV ch1 value ("signed" hex)
      $diffcsvdav2is,     # difference of .csv and .DAV ch2 value ("signed" hex)
      $adjatgtrs,         # adjusted timestamp (real, computed) from attengrab's .csv (to match ADS' .CSV one)
      $adjatsadsdeltas    # difference of .csv adjusted timestamp and .CSV timestamp
    );

    say $ostr;
  }

  say "Abs. error sum CSV(computed hex)/DAV: ch1: $abserrCSV1, ch2: $abserrCSV2";
  say "Abs. error sum csv(captured hex)/DAV: ch1: $abserrcsv1, ch2: $abserrcsv2";

} # end sub


=head1 README:

adscompare.pl compares data saved in a .DAV file, .CSV file
and .csv file, for a single oscilloscope capture - and
outputs a rather long table (pipe it to `less -r`! The
terminal needs at least 140 characters width to properly
show the table)

On an Atten ADS1202CL+, one cannot obtain a capture
through the PC USB connection (as with `attenload`) if:
* The scope is in Auto, and one presses Single to "freeze"
a capture
* Scope is in Single, no triggers are running, and one
presses Force to force a trigger and "freeze" a capture
* Scope is in normal, no triggers are running, and the
screen shows the last capture when a trigger ran

In these cases, it is only possible to save captures from
the scope itself on a USB flash key/thumbdrive:

* Click on Save/Recall
* Click Type (Menu1) to choose Setups (.SET), Waveforms
(.DAV, binary), Picture (.BMP) or CSV (.CSV, ASCII)
** Here for CSV can chose Data Depth: "Displayed" or
"Maximum", and ParaSave: On/Off
* Click Save (Menu5)
** Note the Save (Menu5) will not be enabled unless USB
thumbdrive is plugged in scope
** There is no 'unmount' - it seems it is safe to plug and
unplug the USB thumbdrive at any time
* In Save All Screen:
** Change Modify (Menu1) from Directory to File
** Choose directory with rotary knob, press the knob to
enter it
** Click on New File (Menu2) - screen changes
** Scope will automatically name files ADS0000x, and
automatically increment counter, for .DAV, .CSV, .BMP or
.SET files respectively - else names can be edited with
rotary knob (note 8 character filename limit; FAT16)
** Click Confirm to perform the save to USB thumbdrive.
** One is moved back to Save All screen now, click Next Page
(Menu5)
** Click Return (Menu4) to exit Save All screen back to
default scope screen


If a scope capture is made by setting the scope to Single,
and having it triggered by an actual signal input (CH1,
CH2 or EXT), only then it is possible to transfer the
waveform data of that "frozen" capture via USB to the PC
(to `attenload` or EasyScope).

In that case, one can also have the same capture obtained
both via PC USB connection (via attenload), and saves on
USB thumbdrive. adscompare.pl is meant to align and
compare the data saved from such a case: a single capture
saved in three files:

* .csv, saved by `attengrab.pl` from PC USB connection
* .DAV (binary), saved by scope on USB thumbdrive
* .CSV (ASCII), saved by scope on USB thumbdrive

Note that even if we're talking of the one and the same
signal capture, these files may contain different number
of samples:

* .DAV seems to always carry 0x4000 (16384) samples per
channel (can be opened in Audacity as data)
* USB packet to PC may specify 16000 samples for
`attengrab.pl`'s .csv (and EasyScope)
** for high speeds, this can be 900
* .CSV file may have 16384 samples if Data Depth Maximum,
or 11250 samples if Data Depth Displayed
** for high speeds, this can be 16384 samples if Data
Depth Maximum, or 225 samples if Data Depth Displayed
(the 225 would be aligned approx in the middle of 16384)

Additionally, data formats are different:

* `attengrab.pl`'s .csv file has 3 columns of unsigned
integer data, and 3 columns of real data
** the real timestamp goes from 0 to N_csv*sample_period
** number of floating point decimal characters is not
limited
* scope's .CSV file has 3 columns of real data
** the real timestamp goes from -(N_CSV/2)*sample_period to
((N_CSV/2)-1)*sample_period
** The real voltage values are scaled by 0.78125
** number of floating point decimal characters is limited
to 5
* scope's .DAV file has 0x4000 (16384) unsigned bytes per
channel (one after another) and possibly measurement data
at end

This makes comparison between the data difficult, which is
what adscompare.pl is used for. Note that it relies partly
on determining a "sample delay" by using `gnuplot`; this
script also creates the gnuplot script,
adscompare.gnuplot. Thus, a complete workflow would be:

# get into /some_directory
# ln -s attengrab.pl there, and ln -s adscompare.pl there
# freeze a capture on scope (with signal trigger)
# use `attengrab.pl` to get a .csv file (among others)
# on scope, save .DAV and .CSV file of same capture on USB
thumbdrive
# move USB thumbdrive from scope to PC
# copy .DAV and .CSV captures to same directory (maybe a
subfolder, too)

# say, at this point you have:
# /some_directory/attengrab.pl
# /some_directory/adscompare.pl
# /some_directory/20130019-090802.csv
# /some_directory/scope/ADS00001.CSV
# /some_directory/scope/ADS00001.DAV

# then, run the following:

perl adscompare.pl 20130019-090802.csv scope/ADS00001.CSV scope/ADS00001.DAV | less -r

# From within `less` you can scroll down to see the table;
# you can also search for data (by pressing '/').
# now exit `less` by pressing 'q'
# run gnuplot, and load the generated `adscompare.gnuplot`
script in its terminal:

$ gnuplot

	G N U P L O T
....
Terminal type set to 'wxt'
gnuplot> load './adscompare.gnuplot'


# you should now have a window, where you can zoom (click
'h' for help, 'u' to unzoom)
# change the values in the .gnuplot script in a text editor,
and run the "load.." command again to refresh display until
the waveforms align; make a note of the right sample delay
number
# go back to this script (adscompare.pl), and change the
"my $sdelayCSVcsv = 8156;" line with the right sample
delay number
# run adscompare.pl again:

perl adscompare.pl 20130019-090802.csv scope/ADS00001.CSV scope/ADS00001.DAV | less -r

Scroll through the table, look for unique hex (e.g. 7E 7F)
or real values, adjust the variables $sdelayDAVcsv and
$sdelayDAVCSV as necesarry, exit `less`, and rerun the
script until alignment.

Note, after the  table, absolute sum of differences per
channel is output:

Abs. error sum CSV(computed hex)/DAV: ch1: 1.4210854715202e-14, ch2: 816
Abs. error sum csv(captured hex)/DAV: ch1: 0, ch2: 0

This means that there are errors in computing an unsigned
byte value from the real value in .CSV file (due to
truncation of digits), in comparison to the unsigned byte
value saved in the .DAV file. However, the .csv file in
that alignment has 0 errors - which means no difference
from the corresponding data in DAV file.

Due to this truncation of decimal digits in the .CSV file,
there will always be errors in recovering the original
unsigned byte values from its real values; both the
voltage values will show errors from the corresponding
real values in .csv - and the real timestamps as well
(even after adjustment). Thus, the .csv/DAV absolute
error sum is pretty much the only metric telling us these
datasets are aligned; for the rest, we simply have to
manually try to minimize the error by adjusting the
$sdelay.. variables.

Since the datasets are of uneven length, the script loops
through the dataset expected to be the longest, which is
.DAV with 16384 entries - and then places the .CSV and
.csv in table according to $sdelay.. variables. So, the
table of all three aligned datasets may look like:

|DAV            |CSV                                              |csv
|    0: 7F 80   |          :                             /        |          :                             /       (          /)
...
|   40: 7F 80   |          :                             /        | 0.000e+00: -6.250e-03  0.000e+00  7F 80/  0  0 (-3.262e-03/)
|   41: 7E 80   |          :                             /        | 4.000e-07: -1.250e-02  0.000e+00  7E 80/  0  0 (-3.262e-03/)
...
| 2570: 7F 80   |          :                             /        | 1.012e-03: -6.250e-03  0.000e+00  7F 80/  0  0 (-2.250e-03/)
| 2571: 80 80   |-2.250e-03:  0.000e+00  0.000e+00  80 80/  0  0  | 1.012e-03:  0.000e+00  0.000e+00  80 80/  0  0 (-2.250e-03/ 1.6e-10)
....
|13820: 79 80   | 2.250e-03: -4.375e-02  0.000e+00  79 80/  0  0  | 5.512e-03: -4.375e-02  0.000e+00  79 80/  0  0 ( 2.250e-03/-1.6e-10)
|13821: 79 80   |          :                             /        | 5.512e-03: -4.375e-02  0.000e+00  79 80/  0  0 ( 2.250e-03/)
...
|16039: 7C 80   |          :                             /        | 6.400e-03: -2.500e-02  0.000e+00  7C 80/  0  0 ( 3.137e-03/)
|16040: 7D 80   |          :                             /        |          :                             /       (          /)

That is: .DAV starts at 0; .csv starts at 40; .CSV starts
at 2571, .CSV ends at 13820, .csv ends at 16039 (and .DAV
ends at 16383), in respect to index of .DAV file. See
"# output table string" in code, for the meaning
of the fields of the generated table.


=cut




=dev note

Note that:
* Scope ADS1202CL+ saves on USB for .CSV:
** data depth Displayed, gets 11250 samples
** data depth Maximum, gets 16384 samples
* DAV saved on scope gets 0x4000 = 16384 samples
* EasyScope Refresh retrieval
** with "Get all data" gets 16000 samples
** without "Get all data" gets 11250 samples
* (the binary packet EasyScope is used for this data, data length encoded in packet)

From matching files:

# Ch1 V/DIV  : 200e-3 V ( 200mV )
# Ch1 Voffset: 0 V ( 0V ) [0]
# Ch2 V/DIV  : 1 V ( 1V )
# Ch2 Voffset: 0 V ( 0V ) [0]
$ perl /csvinfo.pl 20130018-130026_b.csv
Parsing 20130018-130026_b.csv ...
Numrows: 16000; anumcols: 6; numcols: 6
Col 0: min 0, max 15999
Col 1: min 8, max 254
Col 2: min 126, max 129
Col 3: min 0, max 0.00089994375
Col 4: min -750e-3, max 787.5e-3
Col 5: min -62.5e-3, max 31.25e-3

(note: 8 volt divs * scale / 2^8:
8*1/2^8 = 0.03125 = 31.25e-3
8*0.2/2^8 = 0.00625 = 6.25e-3; 787.5e-3/6.25e-3 = 126 (254-126 = 128)
)

#Vertical Units,CH1:V CH2:V,,
#Vertical Scale,CH1:0.20 CH2:1.00,,
$ perl /csvinfo.pl scope/ADS00003.CSV
Parsing scope/ADS00003.CSV ...
Numrows: 11250; anumcols: 3; numcols: 3
Col 0: min -0.00045000000, max  0.00044992000
Col 1: min -0.96000, max 1.00800
Col 2: min -0.08000, max 0.04000

...

(
787.5e-3/1.00800 = 0.78125
31.25e-3/0.04000 = 0.78125
-750e-3/-0.96000 = 0.78125
-62.5e-3/-0.08000 = 0.78125
1/0.78125 = 1.28
10/8 = 1.25

----
max rtime1 0.00089994375/2 = 0.000449972 = 4.49972e-3
max rtime2 0.00044992000
0.00089994375-0.00044992000 = 0.000450024
-min rtime2
0.00089994375-0.00045000000 = 0.000449944
... but not same number of samples!
'(0.00089994375-0)/16000'                = 5.62465e-08 # Timebase   : 50e-6; Horizontal Scale,0.0000500000
'(0.00044992000-(-0.00045000000))/11250' = 7.99929e-08 # sample interval 0.0000000800000
'(16000*8e-8)/2' = 0.00064 (> 0.00045!)
'(0.00064-(-0.00064))/16000' = 8e-08
1/8e-8 = 1.25e+07 = 12.5 MHz (or Acquisition/Sampling: 12.50MSa; changes depending on time/DIV)

transition 0 time ADS00003.CSV
-0.00000008000,0.44800,0.00
 0.00000000000,0.55200,0.00
 0.00000008000,0.63200,0.00
0.00045000000/0.0000000800000 = 5625
0.00044992000/0.0000000800000 = 5624
11250/2 = 5625; so goes from -(N/2) to ((N/2)-1)
for .csv:
16000/2 = 8000; so goes from -8000 to 7999;
-8000*8e-8 = -0.00064; 7999*8e-8 = 0.00063992

Note: when scope CSV is data depth Maximum, then getting 16384 rows!

by comparing what is on the bitmap with 8 divs, and the gnuplot of above csv, looks like attenload (20130018-130026_b.csv) is more accurate than the .CSV from the scope-save-to-flash. (maybe in .CSV +/- 1 can be seen as edge of screen?)

plot zerolineR(x) with lines notitle ls 5,\
'20130018-130026_b.csv' using (($1*8e-8)-0.00064):5 with lines,\
'./scope/ADS00003.CSV' using 1:($2*0.78125) with lines

Seems we can simply multiply scope's real values by 0.78125 to make them match to attenloads
)

scope/ADS00001.CSV: Record Length=11250; Sampl.int. (period) ch1:0.0000004000000
  t:[-0.00225000016,0.00224960016] (0.00450000032)
20130019-090802.csv: Record Length=16000; Sampl.int. (period) 400e-9
  t:[0,0.0063996] (0.0064)

from other matching files, got ideal alignment manually in gnuplot on:

plot zerolineR(x) with lines notitle ls 5,\
'20130018-201056.csv' using (($1-8156)*0.0000004):5 with lines,\
'./scope/ADS00001.CSV' using 1:($2*0.78125) with lines

for the alignment in gnuplot:
why 8156 for 11250? 16384/2 = 8192, not that..
why 8152 for 16384 csv, then? 8152*2 = 16304?
strange numbers, but can be made to match - so it's solved with time axis, apparently

can see that 11250@(0.00450000032) is a *portion* (non-resampled, apparently) of 16000@(0.0064)
0.0045/11250 = 4e-07; 0.0064/16000 = 4e-07            # so if this equal to decl (thus)
range via DIV: 18*250e-6 = 0.0045; <= (0.0045,0.0064) # and range via DIV is "<="
, then a portion and non-resampled

# problem - now its resampled:

(note, example before this was completely messed up; unless one waits single, then triggers for Stop, then waits - one cannot be sure same data has been obtained!)

for another capture, got:
scope/ADS00003.CSV: Record Length=225;  Sampl.int. (period) ch1:0.0000000005000
 t:[-0.00000044400,0.00000134800] (1.7925e-06)
20130020-013902.csv: Record Length=900; Sampl.int. (period) 500e-12 (via table, match)
 t:[0,4.495e-07] (4.5e-07)

So, it aligns with:
'20130020-013902.csv' using (($1-225)*2000e-12):($5) with lines,\
'scope/ADS00003.CSV' using 1:($2*0.78125) with lines

... and can see that covers 225@(1.7925e-06) covers *the same* (not a portion, then) as 900:(4.5e-07), except *resampled*!

1.7925e-06/225 = 7.96667e-09 ; 4.5e-07/900 = 0.5e-9 # if this unequal, then a resample?
... strangely, I align with 2e-9? (1/2e-9 = 5e+08 = 500M, but s/rate for 2ch 50ns timebase is 250M)
'sqrt(7.96667e-09*0.5e-9)' = 1.99583e-09 ~= 2e-9? 1.99583e-09 works well as timestep scaler... - but 2e-9 works even better - can even see points of resample matching!

range via DIV: 18*50e-9 = 9e-07 > (4.5e-07, 1.7925e-06)
- and yet, the same is 900:(4.5e-07); div by 2? (and even less with 225@(1.7925e-06)?

maybe:
range_csv = len * declared_samplintv;
range_div = 18*time_div;
if range_div>range_csv {
  # 2e-09 =      '1/((18*50e-9/(900*0.5e-9))*250e6)'
  new_samplintv = 1/((range_div/range_csv)*decl_samplrate);
}
new_range_csv = len * new_samplintv; # this would now hopefully match range_CSV!

# actually, ADS is more correct, with the 1/1.28 factor - mod adsparse-wave for that...

Got a match to scope BMP with .CSV (but not .csv) with this:
'20130020-013902.csv' using ($4):($5) with lines,\
'scope/ADS00003.CSV' using ($1*0.5-25e-9):($2) with lines

so ADS .CSV has (possibly) incorrect timing, but correct voltage..
* it declares interval 5e-10; but diff between it's samples position is 8e-09
* have to mult. that 8e-09*0.5, so 4e-09, to get it totally right as in scope BMP in gnuplot - yet for that data I get: 4ns (Acquire menu); 500ps and 1ns .. seems Ack menu is right then? Nope, since then scope .CSV still needs to be shorter...

now this aligns both - and with scope view...

---- some later, gnuplot comments:

tdiv = 50e-9
tdivp = 18*tdiv/acsz
tdivf = 1/tdivp
sampintp = 500e-12
sampintf = 1/sampintp
sratacqf = 250e6
sratacqp = 1/sratacqf
# if I can obtain _tmp -> .csv; then I have acsz, can find resample factor
#  for comparing with .DAV
# but if I don't obtain it (failure) - no acsz;
# will have to know the resample factors apriori ->
#  have to do a complete run with compares of all T/DIVs on scope!
# TMP (-> csv) matches DAV (*4t / tmp oversamples DAV)
# .CSV (*0.5t) doesn't match DAV (or TMP (->csv))
# if same domain, then:
# 18*50e-9 = 900e-09 = 225*tx = 900*ty;
# tx = 900e-09/225 = 4e-09; (.CSV) # also real sample rate 250 MHz!
# ty = 900e-09/900 = 1e-09; (.csv) # no access to it if _tmp/.csv fails
# ergo oversampling 4e-09/1e-09 = 4
# but they're not exactly so - both .csv and CSV are somewhat shorter than what should be on scope!
# acsv as time doesn't multiply to match scope - so it's OK!

# '225*(1/0.5)' = 450 = 900/2 = 450
# DAV: 16384 @4ns (RT:250M); TMP/.csv: 900 @1ns (tdiv:1G);
# 500p (sampl. intv. CSV) / 1ns (tdiv:1G) = 0.5 (or also ctfact, via ranges)
# CSV: 225 @ 8e-09 (from values in file) but *0.5 =@4ns;
# 900*1 = 900 ; 225*4 = 900



=cut


__DATA__
# test alignment of .CSV (scope to USB flash thumbdrive) and .csv (via scope to USB attenload on PC)
# ONLY CH1

# old `if` syntax
if ((GPVAL_VERSION <= 4.2) \
&&  (!strstrt(GPVAL_COMPILE_OPTIONS,"+IMAGE"))) \
  print ">>> Skipping demo <<<\n" ; \
  print "This copy of gnuplot was built without support for plotting images" ; \
  exit ;


# change `is_interactive` to 0.
# to output .png images; else 1 will
# open gnuplot in interactive mode, (just gnuplot in terminal)
# and there can issue `load adscompare.gnuplot`
is_interactive = 0    # 0 or 1

myfont=""
# no nice numbers for 0.9 (as with 1/1.25 = 0.8): 1/0.925 = 1/1.08108 = 0.925001
# go anyways arbitrary
htscale=1.06
# new `if` syntax
if (is_interactive == 1) {
  set terminal x11 # press h with window focus to get help
  #~ reset
  #~ clear
} else {
  # size tuned to 1672,1555 (1.07524) for five rows, so bmp is exact;
  #set terminal png truecolor size 2000,1860     # 2000/1.07524 = 1860.05
  # we need some space on top; 1/1.06 = 0.943396; so
  #  scale: height*1.06; and make plot take bottom 0.943396 for no change
  set terminal png truecolor size 2000,floor(1860*htscale+0.5)     # 1860.05*1.06 = 1971.65

  set termoption enhanced
  myfont="LMSansDemiCond10-Regular"   # LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"
  # cannot do concatenation direct in termoption line, so in separate string
  myfontb="".myfont.", 14"
  set termoption font myfontb
  set output "adscompare.png"
}

set datafile separator ","

zerolineR(x)=0
zeroline(x)=128

# line color - specified by linestyles
set style line 1 linetype 1 linecolor rgb "black"
set style line 2 linetype 1 linecolor rgb "gray"
set style line 3 linetype -1 linecolor rgb "black" # -1: thick
set style line 4 linetype -1 linecolor rgb "gray"

set style line 10 linetype 1 linecolor rgb "red"
set style line 11 linetype 1 linecolor rgb "green"
set style line 12 linetype 1 linecolor rgb "blue"
set style line 13 linetype 1 linecolor rgb "orange"
set style line 14 linetype 1 linecolor rgb "aquamarine"

set style line 20 linetype 1 lw 2 pointsize 2 linecolor rgb "red"
set style line 21 linetype 1 lw 2 pointsize 2 linecolor rgb "green"
set style line 22 linetype 1 lw 2 pointsize 2 linecolor rgb "blue"
set style line 25 linetype 1 lw 2 pointsize 2 linecolor rgb "magenta"


# VARIABLES ########### ########### ###########

# scope screen(shot) properties
tdiv = ${atghs}          # T/DIV (50e-9)
toffs = ${atgtoffs}        # time offset (scope) (200e-9)
vdiv1 = ${atgvscch1}        # V/DIV CH1 (500e-3)
voffs1 = ${atgvoffch1}         # volt offset CH1 (-1.5)
sampintp = ${adssampint}    # (500e-12)
sampintf = 1/sampintp
sratacqf = ${rtsamprate}      # (250e6)
sratacqp = 1/sratacqf
osf = ${osf}    # oversample factor (multiplies .CSV and .DAV time domain)
osfstr = '${osf}' # preserve osf as string as well
adsFactor = ${adsFactor}

# (edges of current capture and divisions)
scope_hdiv=${scope_hdivs}
scope_vdiv=${scope_vdivs}
scope_trange = scope_hdiv*tdiv        # (900e-9)
scope_left=toffs-(scope_trange/2)     # (-250e-9)
scope_right=toffs+(scope_trange/2)    # (650e-9)
scope_bottom=-voffs1-(scope_vdiv*vdiv1/2) # -500e-3
scope_top=-voffs1+(scope_vdiv*vdiv1/2)    # 3.5

# only ch1:
totalch1Vspan=scope_vdiv*vdiv1
ch1Vcoeff = adsFactor*totalch1Vspan/(2**8)

CSV_fn  = '${adsCSVfile}' # 'scope/ADS00003.CSV' # USB Thumbdrive
Csz=${adsCSVdatlen}             # .CSV size (225)
Cmove=${Cmove}                  # finetune .CSV
#Ctf=0.5             # .CSV timestamp factor (multiplies x position (real))
# don't bother with Ctf; CSV real timestamps can
# be wrong; place CSV_fn via indexes instead
# actually, calculate Ctf in Perl script, to display in graph
Ctf=${Ctf}

acsv_fn = '${atgcsvfile}' # '20130020-013902.csv' # from attenload tmp_wav
acsz=${atgcsvdatlen}         # tmp_wav/.csv size (900)
# here scope_trange could be 18*1, with acsz 16000;
# if as integer, 18/16000 would be 0 - enforce floating point
# above enforcing scope_trange to float doesn't work,
# must again here:
tdivp = 1.0*scope_trange/acsz   # sampling rate, based on scope range and numsamples in tmp (1ns)
tdivf = 1/tdivp             # freq based on that sampling rate
fts=${atgcsvfinalts}        # final timestep
cmove=${cmove}              # cmove == tfoi

DAV_fn = '${adsdavfile}' # 'scope/ADS00003.DAV'
dsz=${dsz}                    # DAV size (16384)16384/2
Dmove=${Dmove}                # 18 samples (smallest timestamp)

# use `convert` to extract only screenshot
#  from merged `attengrab` image:
# old: 480x234+10+10 # now: 480x234+95+128
BMP_fn = '<convert -crop 480x234+95+128 "${atgpngfile}" bmp:-'
# dimensions of scope screenshot bitmap
bmp_w=480
bmp_h=234


# no specific tabular formatting of text in gnuplot;
# so we try with plain string (here in monospaced font)..
note_fstr = "\
| (from where)           | (period [s])            | (freq [Hz]=[Sa/S])|\n\
|T/DIV        %10s | %-15s %7s | (1/*): %10s |     oversample factor: %d \n\
|-Sample interval (CSV)  |              %10s | (1/*): %10s |     final timestep: %s \n\
|-RT sample rate (menu)  | (1/*):       %10s |        %10s |"

note_txt = sprintf(note_fstr, \
  gprintf("%.s%c",tdiv), sprintf("18*TDIV/%d:",acsz), gprintf("%.1s%c",tdivp), gprintf("%.1s%c",tdivf), osf, \
  gprintf("%.1s%c",sampintp), gprintf("%.1s%c",sampintf), gprintf("%.1s%c",fts), \
  gprintf("%.1s%c",sratacqp), gprintf("%.1s%c",sratacqf) \
)


xhrg = ${xhrg} # half x range (in samples) to be seen

get_ypadi(yL, yH) = (floor(0.4*(yH-yL)/2.) > 0) ? floor(0.4*(yH-yL)/2.) : 1
# yL, yH could be equal here - handle:
get_ypadRe(yL, yH) = (abs(0.4*(yH-yL)/2.) > 0) ? abs(0.4*(yH-yL)/2.) : ch1Vcoeff


# row 3 (and 5) zoom stuff

x31min=floor(-acsz/2.+cmove)+toffs/fts-xhrg
x31max=floor(-acsz/2.+cmove)+toffs/fts+xhrg
x32min=0+cmove+toffs/fts-xhrg
x32max=0+cmove+toffs/fts+xhrg
x33min=floor(-acsz/2.+cmove)+acsz-1+toffs/fts-xhrg
x33max=floor(-acsz/2.+cmove)+acsz-1+toffs/fts+xhrg

# y values from Perl:
y31min=${y31min}
y31max=${y31max}
y32min=${y32min}
y32max=${y32max}
y33min=${y33min}
y33max=${y33max}

# row 4 stuff

acsvL = (-acsz/2.+cmove)*fts+toffs
acsvR = (acsz/2.-1+cmove)*fts+toffs
CSVL = (-Csz/2.)*osf*fts+toffs+Cmove*fts
CSVR = (Csz/2.-1)*osf*fts+toffs+Cmove*fts

x41min=(-dsz/2.)*osf*fts+toffs+Dmove*fts      # dto          # (-dsz/2)*drtf+dto
x41max=(dsz/2.-1)*osf*fts+toffs+Dmove*fts     # dto+dsz*drtf  # (dsz/2)*drtf+dto

indic4md = toffs+Dmove*fts                    # ((dsz/2)*drtf)+dto # middle of DAV


# row 5 stuff
# NOTE: in row 5, we're most interested in seeing how
# .CSV aligns with .csv
# so find where they overlap - otherwise keep xhrg range

# choose left edge
difL = CSVL-acsvL # (CSVL < aco)
#~ EdgL = (difL < 0) ? CSVL : acsvL
EdgL = (difL < 0) ? acsvL : CSVL
# chose right edge
difR = CSVR - acsvR # (CSVR > acsvR)
#~ EdgR = (difR > 0) ? CSVR : acsvR
EdgR = (difR > 0) ? acsvR : CSVR
# choose left/right ranges
# need to multiply xhrg by the smallest timestep (the one for .csv - fts):
xhrgt=xhrg*fts;
#~ xhrgtL = (abs(xhrgt) > abs(difL)) ? xhrgt : difL
xhrgtL = xhrgt
xmid = EdgL+(EdgR-EdgL)/2
#~ xhrgtR = (abs(xhrgt) > abs(difR)) ? xhrgt : difR
xhrgtR = xhrgt

x51min=EdgL-xhrgtL
x51max=EdgL+xhrgtL
x52min=xmid-xhrgt
x52max=xmid+xhrgt
x53min=EdgR-xhrgtR
x53max=EdgR+xhrgtR

# y values from Perl:
y51min=${y51min}
y51max=${y51max}
y52min=${y52min}
y52max=${y52max}
y53min=${y53min}
y53max=${y53max}




set size 1,1 # 1,0.8 seems to have no effect, even if it goes before set term size - in multiplot no effect either!
set origin 0,0
sch=1./htscale # scale height; was 1.0
scoy=1.0-sch # scale offset y (no need - from bottom)
#
# MULTIPLOT ########### ########### ###########

set multiplot layout 2,1 rowsfirst scale 1.0,1.0 title "Scope 2ch capture compare (CH1):"
set tmargin 2      # top margin - space for title
mrows = 5          # multiplot rows
plot_h = sch/mrows # plot height
plot_sw = (1.0/3)   # plot small width (/3)
plot_hw = (1.0/2)   # plot half width (/2)


# same as formulae in adscompare.pl:

# enforce floating point calc by appending decimal point ".":
# for small T/div, needs (x-128+32)???????
get_realval_ch1(x) = (x-128)*adsFactor*8.*vdiv1/256. - voffs1

# NOTE: plot1Cu MUST be forced to floating point ... also:
# ... in fact, I should NOT integerize here; direct with floats:
plot1au = "(($0-acsz/2.)*fts+toffs+cmove*fts):($5)"
plot1Cu = "(($0-Csz/2.)*osf*fts+toffs+Cmove*fts):($2)"
plot1Du = "(($0-dsz/2.)*osf*fts+toffs+Dmove*fts):(get_realval_ch1($1))"

plot2au = "(($0+floor(-acsz/2.))+toffs/fts+cmove):2"            # nowork: # $0-int(acsz/2.) # ($0-floor(acsz/2.)
plot2Du = "(($0+floor(-dsz/2.))*osf+toffs/fts+Dmove):1"

plot3au = plot2au
plot3Du = plot2Du

plot4au = plot1au   # "($4+aco):($5)"
plot4Cu = plot1Cu   # "($1*Ctf):($2)"
plot4Du = plot1Du   # "($0*drtf+dto):(($1*dvf)+dvo)" # "(($0-dsz/2)*drtf+dto):(($1*dvf)+dvo)"


# do not use enhanced strings;
# because _ in filename renders as subscript!
set key noenhanced



# ROW 1 ###########

myrow = 1

## bitmap alone

set xrange [0:bmp_w]
set yrange [0:bmp_h]
set xtics auto
set ytics auto
set border
unset grid
unset offsets
unset label # delete all labels

set size plot_sw,plot_h
set origin 0,(mrows-myrow)*plot_h

# set aspect radio to entire bmp size
# 480x234: 234/480 = 0.4875
set size ratio 0.4875

plot BMP_fn binary array=(bmp_w,bmp_h) skip=54 format='%uchar' with rgbimage t '';


## data alone

# "No attempt to control aspect ratio"
set size noratio

# want to show $trunc_min - $trunc_max;
# and the range inside as rectangle;
# that rectangle should be gridded -
# but this grid will fit there too

#set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1
#set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back
set xtics rotate by -45 offset 2.5,-1.25 right format "%.1s%c" font myfont.',10'

set xrange [(${trunc_min}-xhrg)*fts:(${trunc_max}+xhrg)*fts]
# for proper ranging, get extreme y-values in this range from Perl
ttymin=${xrg01ymin}
ttymax=${xrg01ymax}
tymin=(ttymin < scope_bottom) ? ttymin : scope_bottom
tymax=(ttymax > scope_top) ? ttymax : scope_top
set yrange [tymin-abs(tymin*0.1):tymax+abs(tymax*0.1)]

set object 1 rectangle from scope_left,scope_bottom to scope_right,scope_top back
set object 1 rectangle fillcolor rgb "yellow"
set object 1 rectangle fillstyle transparent solid 0.20 border linecolor rgb "gray" linewidth 2

midx_scope = scope_left + (scope_right-scope_left)/2
midy_scope = scope_top + (scope_bottom-scope_top)/2
set arrow from midx_scope,graph 0 to midx_scope,graph 1 nohead front
# for midy, one must specify "first" coord system (else it's off)
set arrow from graph 0,first midy_scope to graph 1,first midy_scope nohead front
set arrow from 0,graph 0 to 0,graph 1 ls 1 nohead front

_titl1= '.csv'
_titl2= '.CSV'
_titl3= '.DAV'


_plot_str = "zerolineR(x) with lines notitle ls 1,\
acsv_fn \
  using ".plot1au." with impulses ls 11 \
  title _titl1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot1Du." with linespoints ls 12 \
  title _titl3, \
CSV_fn \
  using ".plot1Cu." with impulses ls 10 \
  title _titl2"

set size plot_sw,plot_h # *0.88
set origin 1*plot_sw,(mrows-myrow)*plot_h   #+(1-0.9)/2+0.015)*plot_h

eval("plot " . _plot_str)


## bitmap and data overlay

set autoscale
unset xtics
unset ytics
unset border
unset arrow # delete all arrows
unset object # (hopefully) delete objects?

set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1
set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back linecolor rgb "magenta"
set xtics rotate by -45 offset 2.5,-1.25 right format "%.1s%c" font myfont.',10'

# alpha bmp transparency [0:255]
bmp_alpha = 150

# bmp_w=480 bmp_h=234 ; inside 451x201+15+14
# on plot: scope_left:scope_right and scope_bottom:scope_top!
# (so toffset is built in!)

bdx = scope_trange/(451.0-1)  # [s/pixel] /451: 1.99557e-09 vs 2.000e-9 manually
bdy = totalch1Vspan/(201.0-1) # [V/pixel] /201: 0.0199005 vs 0.02005 manually
bofx = -((scope_trange/2.0)-toffs+(15.0+0)*bdx) #-15.0*bdx # -2.8e-7
bofy = -((totalch1Vspan/2.0)+voffs1+(14.0+5)*bdy) #-14.0*bdy # -0.88

# NOTE: plot 'with boxes' style centers the box around index;
# while 'with impulses' is impulse exactly at index (so, at box center);
# that is why in overlay (with boxes), the alignment looks
# slightly different than when observed 'with impulses'
# now again changed plot string - transparent bitmap:
_plot_str = "zerolineR(x) with lines notitle ls 1,\
acsv_fn \
  using ".plot1au." with boxes fillstyle transparent solid 0.10 noborder linestyle 11\
  title _titl1,\
CSV_fn \
  using ".plot1Cu." with boxes fs transparent solid 0.10 noborder ls 10\
  title _titl2,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot1Du." with boxes fs transparent solid 0.10 noborder ls 12\
  title _titl3,\
BMP_fn \
  binary array=(bmp_w,bmp_h) skip=54 format='%uchar' \
  dx=bdx dy=bdy origin=(bofx,bofy) \
  using 1:2:3:(bmp_alpha) \
  with rgbalpha t ''"

set size plot_sw,plot_h
set origin 2*plot_sw,(mrows-myrow)*plot_h

# seems actual plot in screenshot bitmap (480 × 234)
#  is at: 451x201+15+14; aspect ratio 201/451 = 0.445676
set size ratio 0.445676

eval("plot " . _plot_str)


# ROW 2 ###########
# show plot of entire .DAV, with tmp_ superimposed

# "No attempt to control aspect ratio"
set size noratio

set autoscale # xrange, yrange
unset xtics # resets the font back
set xtics auto format "% g"
set ytics auto
set border
unset grid

_lsT=11
_lsD=12
_titl1= '('.acsz .') ' .acsv_fn .' (atl/EasyScope USB PC)'
# note - as long as osf is an int, can concatenate directly:
# _titl2= '('.dsz .' [*'.osf .']) ' .DAV_fn .' (USB Thumbdrive scope)'
# but once it becomes a float "1.0", then we must use sprintf,
# and that will lose the decimal (either too many %f, or too little %g)
# so preserve also the string printout from perl in osfstr for here!
_titl2= '('.dsz .' [*'.osfstr .']) ' .DAV_fn .' (USB Thumbdrive scope)'


set label 1 "uint8 data" at graph 0.01,graph 0.95 front
# left edge of .csv snippet:
set arrow from int(-acsz/2.+toffs/fts),graph 0 to int(-acsz/2.+toffs/fts),graph 1 ls 11 nohead
set label 2 "".int(-acsz/2.+toffs/fts) at int(-acsz/2.+toffs/fts),graph 0.9 right textcolor ls 11 front
# right edge of .csv snippet:
set arrow from int(-acsz/2.)+acsz-1+toffs/fts,graph 0 to int(-acsz/2.)+acsz-1+toffs/fts,graph 1 ls 11 nohead
# middle of .DAV array (force rounding with floor):
set arrow from floor(toffs/fts+0.5)+Dmove,graph 0 to floor(toffs/fts+0.5)+Dmove,graph 1 ls 12 nohead
# if we plot zeroline(x) as first, (_plot_str = "zeroline(x) title '' ls 1,)
# then it is in background! (leave it,however, so it shows on next row, where we unset this arrow)
# set as arrow so we can draw it in front; but also
# must specify "first" coord system (else it's off)
set arrow 10 from graph 0,first zeroline(0) to graph 1,first zeroline(1) ls 1 nohead front


_plot_str = "zeroline(x) title '' ls 1,\
acsv_fn \
  using ".plot2au." with linespoints ls _lsT \
  title ''._titl1\
  , \
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot2Du." with linespoints ls _lsD \
  title ''._titl2\
  , \
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot2Du." with impulses ls _lsD \
  title '' \
  , \
acsv_fn \
  using ".plot2au." with impulses ls _lsT \
  title ''"

myrow = 2

set size 1.0,plot_h
set origin 0.0,(mrows-myrow)*plot_h

eval("plot " . _plot_str)

# capture - needed for resample errorbars later
set table "_e_tmp"
_plot_str = "acsv_fn \
  using ".plot2au." with linespoints ls _lsT \
  title ''._titl1"
eval("plot " . _plot_str)
set table "_e_dav"
_plot_str = "DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot2Du." with linespoints ls _lsD \
  title ''._titl2"
eval("plot " . _plot_str)
unset table
PERL_resamp = "<perl get_resampled_merged_vals.pl _e_tmp _e_dav"



# ROW 3 ###########

# unset zeroline arrow
unset arrow 10

# for next rows, we need the impulses laid out the other way:
# (easier to see resampling that way)
# also adding errorbars - retrieved via perl script
# (similar parsing in gnuplot would be very tedious)

_plot_str3 = "zeroline(x) title '' ls 1, \
acsv_fn \
  using ".plot3au." with linespoints ls _lsT \
  title ''._titl1\
  , \
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot3Du." with linespoints ls _lsD \
  title ''._titl2\
  , \
acsv_fn \
  using ".plot3au." with impulses ls _lsT \
  title ''\
  , \
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot3Du." with impulses ls _lsD \
  title ''";

_plot_str = _plot_str3 . ",\
PERL_resamp \
  using 2:3:3:($5) with errorbars ls 25 \
  title 'error(.csv,.DAV)'";


# show snippet of start of overlap of DAV and tmp_
#  for xrange, we are in domain of tmp_ since we scaled DAV
#  so we can specify few enough to be visible
#  for yrange, we'd have to iterate in gnuplot - messy;
#  so set that range from script

_titl1 = _titl2 = ''
_lsT=21 ; _lsD=22   # thicker lines in here

myrow = 3

set size plot_sw,plot_h
set origin 0.0,(mrows-myrow)*plot_h
set xrange [x31min:x31max]
ypad = get_ypadi(y31min,y31max)
set yrange [y31min-ypad:y31max+ypad]
eval("plot " . _plot_str)

# show snippet in middle of overlap of DAV and tmp_

set size plot_sw,plot_h
set origin 1*plot_sw,(mrows-myrow)*plot_h
set xrange [x32min:x32max]
ypad = get_ypadi(y32min,y32max)
set yrange [y32min-ypad:y32max+ypad]
eval("plot " . _plot_str)

# show snippet of end of overlap of DAV and tmp_

set size plot_sw,plot_h
set origin 2*plot_sw,(mrows-myrow)*plot_h
set xrange [x33min:x33max]
#~ set autoscale y
ypad = get_ypadi(y33min,y33max)
set yrange [y33min-ypad:y33max+ypad]
eval("plot " . _plot_str)


# now that we're done with plots, remove
# temporary files for get_resampled_merged_vals.pl
# with system shell command:
! rm _e_tmp _e_dav


# ROW 4 ###########
# show plot of entire .DAV (in real domain), with .csv/.CSV superimposed

set autoscale # xrange, yrange
set xrange [x41min:x41max]
set xtics auto
set ytics auto
set border
unset grid

_lsC=10
_lsT=11
_lsD=12
_titl1= '('.acsz .') ' .acsv_fn .' (atl/EasyScope USB PC)'
# note: we still iterate .CSV via index here; Ctf is calculated from Perl
_titl2= sprintf("(%d) [*%.2g] %s (USB Thumbdrive scope)", Csz, Ctf, CSV_fn)
_titl3= sprintf("(%d) [*%.2g] %s (USB Thumbdrive scope)", dsz, osf, DAV_fn)


set label 1 "real data" at graph 0.01,graph 0.95 front
set arrow from acsvL,graph 0 to acsvL,graph 1 ls _lsT nohead
set arrow from acsvR,graph 0 to acsvR,graph 1 ls _lsT nohead
set label 2 sprintf("%.3g",acsvL) at acsvL,graph 0.93 right textcolor ls _lsT front
set arrow from CSVL,graph 0 to CSVL,graph 1 ls _lsC nohead
set arrow from CSVR,graph 0 to CSVR,graph 1 ls _lsC nohead
set label 3 sprintf("%.3g",CSVL) at CSVL,graph 0.88 right textcolor ls _lsC front
set arrow from indic4md,graph 0 to indic4md,graph 1 ls 12 nohead front
# if we plot zerolineR(x) as first, (_plot_str = "zerolineR(x) title '' ls 1,)
# then it is in background! (leave it,however, so it shows on next row, where we unset this arrow)
# set as arrow so we can draw it in front; but also
# must specify "first" coord system (else it's off)
set arrow 10 from graph 0,first zerolineR(0) to graph 1,first zerolineR(1) ls 1 nohead front

_plot_str = "zerolineR(x) title '' ls 1,\
acsv_fn \
  using ".plot4au." with linespoints ls _lsT \
  title _titl1,\
acsv_fn \
  using ".plot4au." with impulses ls _lsT \
  title '',\
CSV_fn \
  using ".plot4Cu."  with linespoints ls _lsC \
  title _titl2,\
CSV_fn \
  using ".plot4Cu." with impulses ls _lsC \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ".plot4Du." with linespoints ls _lsD \
  title _titl3"


myrow = 4

set size 1.0,plot_h
set origin 0.0,(mrows-myrow)*plot_h
eval("plot " . _plot_str)



# ROW 5 ###########

# unset zeroline arrow
unset arrow 10

# show snippet of start of overlap of DAV and tmp_
#  for xrange, we are in domain of tmp_ since we scaled DAV
#  so we can specify few enough to be visible
#  for yrange, we'd have to iterate in gnuplot - messy;
#  so set that range from script


_titl1 = _titl2 = _titl3 = ''
_lsC=20 ; _lsT=21 ; _lsD=22   # thicker lines in here

# again this?
# better to set this to %.2e, as %g can
# sometimes let up to 5 decimals to appear
set xtics auto format "%.2e" #"%g"

myrow = 5

set size plot_sw,plot_h
set origin 0.0,(mrows-myrow)*plot_h
set xrange [x51min:x51max]
ypad = get_ypadRe(y51min,y51max)
set yrange [y51min-ypad:y51max+ypad]
eval("plot " . _plot_str)

# show snippet in middle of overlap of DAV and tmp_

set size plot_sw,plot_h
set origin 1*plot_sw,(mrows-myrow)*plot_h
set xrange [x52min:x52max]
ypad = get_ypadRe(y52min,y52max)
set yrange [y52min-ypad:y52max+ypad]
eval("plot " . _plot_str)

# show snippet of end of overlap of DAV and tmp_

# last plot - also the info table:
set label note_txt at screen 0.35,screen 0.975 left font "Latin Modern Mono Light Cond,11" front

set size plot_sw,plot_h
set origin 2*plot_sw,(mrows-myrow)*plot_h
set xrange [x53min:x53max]
# here y53min could be == y53max, so ypad must handle that
ypad = get_ypadRe(y53min,y53max)
set yrange [y53min-ypad:y53max+ypad]
eval("plot " . _plot_str)


unset multiplot
# MULTIPLOT END ####### ####### #######

# note - no spaces at set label coords!
# screen coords are shown in x window - label uses those by default
# set label NEEDS to go before plot - else it needs twice 'load' to be placed proper!

# transparency - only for bitmap (and fills - but not strokes); in the test image:
# set terminal png transparent truecolor ; set output './_t.png'; plot 100.*(.4+sin(x/5.)/(x/5.)) lw 5 title 'solid line', './_TEST.bmp' binary array=(480,234) skip=54 format="%uchar" using 1:2:3:(220) with rgbalpha
# the image is above the line; if it is fed alpha via :(220) then constant alpha - else w/ :(2.*column(0)) it is gradient.
# The line below is NOT gradient - but if the image is black bckg, when it becomes more opaque, it then covers (and kills) the color of the line, so it looks like line has gradient - but it doesn't
# so transparency for now via boxes

# `set label` needs to be set before a plot command
# set label at end, because there's unsetting (and such) of labels
# but it needs to be before the last plot command (row 5)

# NOTE: "gprintf() accepts only a single variable to be formatted."!
# ... and no %d in gprintf!

# for some reason, the shorthand set xtics font ',6'
#  does not work here - name must be explicitly set!
# "%s" adds unneeded zeroes too - %.0s suppresses totally
#~ set offset graph 0.20, graph 0.20 # padding of whole plot? nope, jus content

# was:
# plot1au = "($4+aco):($5)"
# plot1Cu = "($1*ctf):($2)"
# plot1Du = "($0*drtf+dto):(($1*dvf)+dvo)" # "(($0-dsz/2)*drtf+dto):(($1*dvf)+dvo)"
# drtf=osf*tdivp; osf=4

# must be border, linecolor, linewidth (in that order)
# but on its own line: "Unrecognized or duplicate option"
#~ set object 1 rectangle border linecolor rgb "gray" linewidth 2
# so must be on same line with fillstyle

# old bitmap data overlay:
#~ > # array=480x234 cannot bmp_wxbmp_h (syntactically one variable!)
#~ > plot BMP_fn binary array=(bmp_w,bmp_h) skip=54 format='%uchar' with rgbimage t '';
#~ >
#~ > unset border
#~ > set xrange [scope_left:scope_right]
#~ > set yrange [scope_bottom:scope_top]
#~ >
#~ > # scale factors
#~ > ssx=0.944
#~ > ssy=0.86
#~ >
#~ > # overlay:
#~ > set size ssx*plot_sw,ssy*plot_h
#~ > set origin (2+0.0015)*plot_sw,(mrows-myrow+0.078)*plot_h

# NOTE: plot1Cu MUST be forced to floating point op via
#  decimal point (2.) - else wrong placement! also:
#print floor(225/2), floor(225/2.), int(225/2), int(225/2.) #112 112 112 112
#print floor(-225/2), floor(-225/2.), int(-225/2), int(-225/2.) #-112 -113 -112 -112
#plot 1 can be left with real values - but better integerize for self-check
# move the - inside the floor, as the sizes are always positive
#print floor(-Csz/2.)*osf*fts+toffs+Cmove*fts # -2.49e-07;
#print (-Csz/2.)*osf*fts+toffs+Cmove*fts # -2.47e-07 # only this is right
#print int (-Csz/2.)*osf*fts+toffs+Cmove*fts # -2.45e-07
#print (-Csz/2.), floor(-Csz/2.)  # -112.5, -113
# ... so, in fact, I should NOT integerize here? direct with floats:

# left edge of .csv snippet:
# (note: int(-250.0)=-249?? floor(-250.0)=-250! and now floor(-250.0)=-251??? floor(-250.00000001)=-251, that's why)
# print floor(-acsz/2.0+toffs/fts), floor(-acsz/2+toffs/fts), (floor(-acsz/2)+toffs/fts), (floor(-acsz/2.)+toffs/fts) # -251 -251 -250.0 -250.0
# print int(-acsz/2.0+toffs/fts), int(-acsz/2+toffs/fts), (int(-acsz/2)+toffs/fts), (int(-acsz/2.)+toffs/fts) # -250 -250 -250.0 -250.0
# for .DAV: int(toffs/fts)+Dmove misses:
#print int(toffs/fts)+Dmove, (toffs/fts)+Dmove, floor(toffs/fts)+Dmove, int(toffs/fts +Dmove), floor(toffs/fts +Dmove), floor(toffs/fts +Dmove+0.5) , floor(toffs/fts+0.5) +Dmove  # 181 182.0 181 181 181 182 182
# for .DAV - force rounding with floor
