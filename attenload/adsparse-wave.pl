#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


package adsparse_wave_pl;

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::FormatEng

=cut

use 5.10.1;
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
00000010  00 || 00 /s /1 /2 | sz|  01 00 00 00 01 00 00 00
00000020  | vdiv1/f | | vdiv1/x |  | voff1/i | 00 00 00 00
00000030  |         | | vdiv2/f |  | vdiv2/x | | voff2/i |
00000040  |         | | tbase/f |  | tbase/x | | toffs/f |
00000050  | toffs/x | | trigstt |  |         | |         |

|| - frame order index (00, 05, 06);
/1 = 01 for first in run else 00? no - $rsbstate - in first frame,
      where it is "run/stop" state (01=green(run);02=red(stop))
| sz| = number of samples/entries in this frame: 4 bytes int, big endian
      00/1 01 for first, else 0x0384 = 900 or 0x08ca = 2250 ...
      0x16 (first frame only) - Single button state (00 off, 01 on(green))
/s - ? in first frame only?, seems to be zero all the time?
/2 = ? 00

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
trigstt: trigger status/state                   4 bytes int

=cut


use open IO => ':raw'; # no error

binmode(STDIN);
binmode(STDOUT);
binmode(DATA);

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

# Note: say - Just like print, but implicitly appends a newline (v >= 5.10)
# ... but this println I made auto to STDERR, so keeping it:
sub println  { local $,="";   print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }
sub printlns { local $,=$/; print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }

use File::Basename;
use Cwd qw(abs_path);
use lib dirname (abs_path(__FILE__));
# include attenScopeIncludes
use attenScopeIncludes;
# declare from attenScopeIncludes
our $adsFactor;
our %timediv_srate_map;
our %timediv_sint_map;
our $scope_hdivs; # 18
our $scope_vdivs; # 8
our %timediv_move_map;
our @tdiva;
# for .ssf (device settings) parsing:
our (@ssf_trigsrca , @ssf_trigtypa , @ssf_probestga , @ssf_probestia , @ssf_trigedgeslopa , @ssf_couplinga , @ssf_chvdiva , @ssf_trigmodea , @ssf_trigcpla , @ssf_trigpulsewhena , @ssf_trigvidpola , @ssf_trigvidsynca , @ssf_filtypa , @ssf_trigvidstda , @ssf_trigslopeverta , @ssf_trigslopewhena , @ssf_trigslopetimea);
my ($ssf_triglevel_f , $ssf_triglevel_i , $ssf_trigsource , $ssf_trigtype , $ssf_trigedgeslope , $ssf_trigmode1 , $ssf_trigmode2 , $ssf_trigcouple , $ssf_trig_holdoff_i , $ssf_trig_holdoff , $ssf_trigpulsewhen , $ssf_trigvidpol1 , $ssf_trigvidpol2 , $ssf_trigvidsync , $ssf_trigvidstd , $ssf_trigslopevert , $ssf_trigslopewhen , $ssf_trigslopetime_f , $ssf_trigslopetime_x , $ssf_trigslopetime , $ssf_trigfact , $ssf_triglevel);
my ($ssf_ch1probe , $ssf_ch2probe , $ssf_ch1coupling , $ssf_ch2coupling , $ssf_ch1bwlimit , $ssf_ch2bwlimit , $ssf_ch1vdiv , $ssf_ch2vdiv , $ssf_ch1invert , $ssf_ch2invert , $ssf_ch1filter , $ssf_ch2filter , $ssf_ch1filtertype , $ssf_ch2filtertype , $ssf_vdiv1_f , $ssf_vdiv1 , $ssf_vdiv2_f , $ssf_vdiv2 , $ssf_tdiv_1 , $ssf_tdiv_2 , $ssf_toffs_f , $ssf_l1 , $ssf_l2 , $ssf_l3 , $ssf_l4 , $ssf_l5 , $ssf_l6 , $ssf_l7);



#======= "main"

if ($#ARGV < 0) {
 print STDERR "usage:
perl adsparse-wave.pl bindat_file [out_filename_base]

  Without `out_filename_base`, parsed wave data goes to STDOUT:
  1) perl adsparse-wave.pl bindat.dat myCapture01
  2) perl adsparse-wave.pl bindat.dat 1>stdout.csv\n";
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
my $ofncsv; # output filename for the .csv
# check for second argument - otherwise work with STDOUT as main output:
if ((!defined $ARGV[1]) || ($ARGV[1] eq "")) {
  $ofnb = "stdout";
  $ofh = \*STDOUT;
  $ofncsv = "stdout.(csv)"; # since we cannot know name in this case
  println "Writing to STDOUT";
} else {
  $ofnb = $ARGV[1];
  $ofncsv = "$ofnb.csv";
  open($ofh,'>',$ofncsv) or die "Cannot open $ofnb.csv ($!)";
  println "Writing to $ofnb.csv";
}


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
print STDERR __FILE__.": Found (".($#hdrinds+1).") headers at: ". join(', ', @hdrinds). "\n";


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


my $numsamples = -1;
if ($frSizes[1] >= $frSizes[2]) { $numsamples = $frSizes[1]; }
else { $numsamples = $frSizes[2]; }

print STDERR  "frOrderInds:  ".join(';', @frOrderInds)."\n".
              "frFirstMarks: ".join(';', @frFirstMarks)."\n".
              "frSizes:      ".join(';', @frSizes)."\n";

# from first frame:

my $haddr1=$hdrinds[0];
my @atmp = (0) x 4;
my $tmp1;

my @sbstates = ("Off", "On[G]");
my @rsbstates = ("", "Run[G]", "Stop[R]");

my $rsbstate = $frFirstMarks[0]; # 0x14
my $sbstate = $aindata[$haddr1+0x16]; # "single" button state

# "acquire state" seems to be "Pre" (1) only after changing mode
# after mode is changed (single -> auto, auto -> normal),
# for a while it is (1) "Pre", but after data acquired it is (0) post;
# and seems to remain zero, until next change of mode
# "acquire state" == "trig mode change" == "data not ready" state?
# usually waiting for Mode submenu on scope to dissapear
# ... (and/or roll button to turn off), is usually enough to have
# ... the scope in TrigModeSettled
my $trigmodechg = $aindata[$haddr1+0x15]; # "acquire" state?
my @trigmodes = ("TrigModeSettled", "TrigModeChanged");
my $tst2 = $aindata[$haddr1+0x13]; # seems to be zero all the time?
my $tst3 = $aindata[$haddr1+0x17]; # seems to be 1 all the time?

println "\ttst2: $tst2 (" ."". ")" if ($tst2 != 0);
println "\ttst3: $tst3 (" ."". ")" if ($tst3 != 1);


# trigstates also is 1:Auto when scan (xcept scan is time/div >= 100ms)
# trigstates is 1:auto or 3: trig'd even if on Armed ("the scope is acquiting pre-trigger data. All triggers are ignored in this case"
# Also Ready: "pre trigger data acquired, ready to accept a trigger"; returns Auto for ready (in auto)
my @trigstates = ("Stop", "Auto", "Ready", "Trig'd");

my $trigstt;
@atmp[0..3] = @aindata[$haddr1+0x54..$haddr1+0x57];
$trigstt = unpack("V", pack("C4", @atmp));


# there is no pack types to choose endian with floats in Perl;
# so those must be handled manually (w/ reverse on packed data)
# note 0x00000084 = 132 is default value for voltage offset

my $vdiv1_f;
@atmp[0..3] = @aindata[$haddr1+0x20..$haddr1+0x23];
$vdiv1_f = unpack("f", reverse pack("C4", @atmp));

my $vdiv1_x;
@atmp[0..3] = @aindata[$haddr1+0x24..$haddr1+0x27];
$vdiv1_x = unpack("V", pack("C4", @atmp));

my ($voff1_i, $voff1_bs, $voff1_ic);
@atmp[0..3] = @aindata[$haddr1+0x28..$haddr1+0x2b];
$voff1_i = unpack("N", pack("C4", @atmp));
$voff1_ic = 132-$voff1_i;
$voff1_bs = ((132-$voff1_i)/25)*$vdiv1_f;


my $vdiv2_f;
@atmp[0..3] = @aindata[$haddr1+0x34..$haddr1+0x37];
$vdiv2_f = unpack("f", reverse pack("C4", @atmp));

my $vdiv2_x;
@atmp[0..3] = @aindata[$haddr1+0x38..$haddr1+0x3b];
$vdiv2_x = unpack("V", pack("C4", @atmp));

my ($voff2_i, $voff2_bs, $voff2_ic);
@atmp[0..3] = @aindata[$haddr1+0x3c..$haddr1+0x3f];
$voff2_i = unpack("N", pack("C4", @atmp));
$voff2_ic = 132-$voff2_i;
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
my $vdiv1str = "Ch1 V/DIV  : " . format_eng($vdiv1) . " V ( " . format_pref($vdiv1) . "V )";
println $vdiv1str;

my $voff1 = $voff1_bs * 10**(vdivexp($vdiv1_x));
my $voff1str = "Ch1 Voffset: " . format_eng($voff1) . " V ( " . format_pref($voff1) . "V ) [" . $voff1_ic . "]";
println $voff1str;

my $vdiv2 = $vdiv2_f * 10**(vdivexp($vdiv2_x));
my $vdiv2str = "Ch2 V/DIV  : " . format_eng($vdiv2) . " V ( " . format_pref($vdiv2) . "V )";
println $vdiv2str;

my $voff2 = $voff2_bs * 10**(vdivexp($vdiv2_x));
my $voff2str = "Ch2 Voffset: " . format_eng($voff2) . " V ( " . format_pref($voff2) . "V ) [" . $voff2_ic . "]";
println $voff2str;

# note: adsparse-wave $tbase calc'ed, in attengrab-repair it is read!
# p sprintf("%.50f", $tbase):
# -repair is same as p sprintf("%.50f", 250e-9);
# 0.00000025000000000000004162658715986533586317364097 # adsparse-wave
# 0.00000024999999999999998868702795647156467140348468 # attengrab-repair
#  .1234567890123456789012 # 22 decimals precision
# sprintf("%.22f", $tbase): 0.0000002500000000000000
# p sprintf("%.50f", sprintf("%.22f", $tbase)+0); is same for both (same as -repair) - so, handle!
# (that also forces $tprd_range_tbase = sprintf("%.22f", for correct results!)
my $tbase = $tbase_f * 10**($tbase_x);
$tbase = sprintf("%.22f", $tbase)+0;

my $range_tbase = $scope_hdivs*$tbase;
my $tbasestr = "Timebase (time/DIV)  : " . format_eng($tbase) . " s ( " . format_pref($tbase) . "s )\n#  { screen range $scope_hdivs*(t/DIV)= ". format_pref($range_tbase) . "s }";
println $tbasestr;

# here can get sampling rate - from table (written from scope menu for a given TIME/DIV)
my $srate = $timediv_srate_map{$tbase};
my $tprd_srate = 1/$srate;
my $range_srate = $numsamples*$tprd_srate;
my $sratestr = "Sampling rate (scope Acquire menu,2CH RealTime): " . format_eng($srate) . " Hz [Sa/s] ( " . format_pref($srate) . "Hz )\n#  {eqv.period: ".format_pref($tprd_srate)."s range: ".format_pref($range_srate)."s }";
println $sratestr;

# sampling period == sampling interval
#~ my $sperd = 1/$srate;
# ... nope, have to read specific values for samp.int.,
# ... cause sometimes it matches that formula - but sometimes doesn't
#  as they are written by scope in .CSV for a given TIME/DIV
# so again from a (different) table:
my $sperd = $timediv_sint_map{$tbase};
my $fsam_sperd = 1/$sperd;
my $range_sperd = $numsamples*$sperd;
my $sperdstr = "Sampling interval (scope USB FlashDrive .CSV)  : " . format_eng($sperd) . " s ( " . format_pref($sperd) . "s )\n#  {eqv.freq: ".format_pref($fsam_sperd)."Hz range: ".format_pref($range_sperd)."s }";
println $sperdstr;

my ($tprd_range_tbase,$srate_range_tbase) = (-1)x2;
if ($numsamples > 0) {
  $tprd_range_tbase = $range_tbase/$numsamples;
  $tprd_range_tbase = sprintf("%.22f", $tprd_range_tbase)+0;
  $srate_range_tbase = 1/$tprd_range_tbase;
}
my $tprdrangestr = "Sampling interval (screen_range/num_samples)   : " . format_eng($tprd_range_tbase) . " s ( " . format_pref($tprd_range_tbase) . "s )\n#  {eqv.freq: ".format_pref($srate_range_tbase)."Hz }";
println $tprdrangestr ;

# check ranges
my $final_timestep;
my $checkrangestr = "Time Ranges";
if ($range_srate > $range_tbase) { #($range_tbase > $range_sperd) { # range_div>range_csv {
  # 2e-09 =      '1/((18*50e-9/(900*0.5e-9))*250e6)'
  #new_samplintv = ((range_div/range_csv)*decl_samplrate);
  #~ $checkrangestr .= " ".format_pref($range_tbase)."s > ".format_pref($range_sperd)."s: assume resample +recalc;";
  $checkrangestr .= " ".format_pref($range_srate)."s > ".format_pref($range_tbase)."s: assume resample +recalc;";
  #~ $final_timestep = $tprd_srate; # get from Acquire menu RealTime samplrate (4ns)
  #~ $final_timestep = ($range_tbase/$range_sperd)*$tprd_range_tbase; # (2ns) nope? well, with this becomes equal to .CSV capture, but .CSV capture may still need less (1ns) to match actual scope display; so:
  $final_timestep = $tprd_range_tbase;
} else { # <=
  $checkrangestr .= " $range_srate <= $range_tbase: assume portion +keep;";
  $final_timestep = $tprd_srate; # $sperd;
}

# oversample factor: real rate period/chosen xrange period
#say "tbase factor " . sprintf("%.50f", $tbase) ."  " . sprintf("%.50f", $tprd_srate) ."  " . sprintf("%.50f", $tprd_range_tbase);
my $origosf = $tprd_srate/$tprd_range_tbase;
my $osf;

=head1 At this point,
if the scope is at TDIV of 2.5us/DIV or bigger,
then attenload returns 16000 samples for tmp_wav (and thus csv).

In that case, there is no oversampling - one needs to
take just a snippet from the entire tmp_wav array to
show the scope image. At the same time, $osf becomes
a floating point decimal number - previously it is an integer.

In this region, up to and including TDIV of 50 ms/DIV:
* $tprd_srate == sampling interval from scope thumbdrive .CSV:
* $osf (as a fraction) > 1

At and above TDIV of 100 ms/DIV:
* $tprd_srate < sampling interval from scope thumbdrive .CSV
* $osf (as a fraction) < 1

So, handle that case.. - and that case has extra offset ($tfoi) as well...

# NOTE osf fractional part: here I could get:
# print $origosf: 2 ; print int($origosf): 1 ??!
# p sprintf("%f", $origosf): 2.000000 ????
# print sprintf("%e", $origosf): 2.000000e+00; same for "%.4e"??!
# BUT: print sprintf("%.20e", $origosf): 1.99999999999999955591e+00 !!
# see http://perldoc.perl.org/functions/int.html:
# thus use classic rounding (int of +0.5), instead of int($origosf)
# with just int; $origosfractional: 1
# after int + 0.5: $origosfractional: -4.44089209850063e-16 (but we check >0, so OK? well, it screws some other values :( )
# so go with int(sprintf("%f",$origosf)) - seems to work..

# NOTE tfoi: out here, now we have to do some extra delays
# for tdiv 2.5us; fts=10e-9; toffs=17.5e-6/10e-9 = 1750, having some -164.. (1750/164 = 10.6707) 1750/10.66 = 164.165
# the delays seem to hold for the range where ($origosfractional > 0) and $origosf >= 1

but there is yet another range of operation:
where ($origosfractional > 0) and 0 < $origosf < 1,
which starts at TDIV of 100ms/div and above.
Here, for the first time: $tprd_srate < sampling interval from scope thumbdrive .CSV ($sperd)
I may have:
$tprd_srate 40u $sperd 200.0u $fts 112.5u; but fts is too tight in comparison to bitmap.. so set $fts here to $sperd? $osf would then indeed be <0 ... (undersampled)
(Actually, all those $origosf are 0.355555555555556!)
so then we'd have 40/200 = 0.2 as osf (it turns out 0.199999984370001 - and it looks OK).. 100/400 = 0.25 etc.

Actually, even if the $tfoi calculation works -
now that we've added %timediv_move_map to attenScopeIncludes.pm,
we might as well use that to get $tfoi ($cmove == $tfoi)

# (but there is no undersampling, actually - see adscompare.pl)..

=cut

my $tfoi = 0;

# check osf fractional part
my $origosfractional = $origosf - int(sprintf("%f",$origosf));
my $smallosf = "--";
if ($origosfractional > 0) {
  if ($origosf >= 1) {
    # set $osf to 1.0
    $osf = "1.0"; # as string, so we can see it's modded in printout
    $final_timestep = $tprd_srate;
    #~ $tfoi = -164;
  } else { # $origosf < 1
    $final_timestep = $sperd;
    #$osf = $tprd_srate/$sperd;
    #~ $tfoi = -164;
    $smallosf = $tprd_srate/$sperd;
    $osf = "1.00"; # as string, so we can see it's modded in printout
  }
} else { # integer - no change
  $osf = $origosf;
}

# we don't need $osf for $cmove/$tfoi - but nonetheless,
# put the command here - after $osf is known:
$tfoi = eval ( $timediv_move_map{$tbase+0}[2] ); # $tbase == $atghs

# tested with "%.50f", looks OK
my $osfstr = "Oversample factor: " . $osf ." ( $smallosf ". sprintf("%.6f", $origosf) ." ". int($origosf) ." ". $origosfractional ." )";
println $osfstr;



my $range_final = $numsamples*$final_timestep;
my $srate_final = 1/$final_timestep;
$checkrangestr .= "\n#  { final timestep: ".format_eng($final_timestep)." / ".format_pref($final_timestep)."s {eqv.freq: ".format_pref($srate_final)."Hz range ".format_pref($range_final)."s }}";
println $checkrangestr;


my $toffs = $toffs_f * 10**($toffs_x);
my $toffsstr = "Time offset: " . format_eng($toffs) . " s ( " . format_pref($toffs) . "s )";
println $toffsstr;

my $btnsstr = "Single Btn: $sbstate (" . $sbstates[$sbstate]  . "); Run/Stop Btn: $rsbstate (" . $rsbstates[$rsbstate] . ")";
println $btnsstr ;

my $trigstr = "Trigger: status= $trigstt (" . $trigstates[$trigstt] . "); mode change= $trigmodechg (" . $trigmodes[$trigmodechg] . ")";
println $trigstr ;

# before parsing channel data, do a check
# and exit with error (1) if sizes are zero!
my $retval = 0;
if (($frSizes[1] < 1) or ($frSizes[2] < 1)) {
  println "NO DATA received!! completing and exiting w/ error...";
  $retval = 1; # exit 1;
}

# get channel data (second and third frame)

my @adatch1 = (0) x $frSizes[1];
my @adatch2 = (0) x $frSizes[2];

my $haddr2=$hdrinds[1]; # of second frame
@adatch1[0..$frSizes[1]-1] = @aindata[$haddr2+0x18..$haddr2+0x18+$frSizes[1]-1];

my $haddr3=$hdrinds[2]; # of third frame
@adatch2[0..$frSizes[2]-1] = @aindata[$haddr3+0x18..$haddr3+0x18+$frSizes[2]-1];


# note: scope screen has
# * 2*9 = 18 divs horizontally (time)
# * 2*4 =  8 divs vertically (voltage)
# calculate total spans
my $totaltimespan = $scope_hdivs*$tbase;
my $totalch1Vspan =  $scope_vdivs*$vdiv1;
my $totalch2Vspan =  $scope_vdivs*$vdiv2;

# get voltage coefficient, knowing that
# ... scope samples with 8-bit resolution
# apparently also with $adsFactor?
my $ch1Vcoeff = $adsFactor*$totalch1Vspan/(2**8);
my $ch2Vcoeff = $adsFactor*$totalch2Vspan/(2**8);

my $rvstepstr = "Real voltsteps: ch1 ". format_eng($ch1Vcoeff) ." ; ch2 ". format_eng($ch2Vcoeff) ."";
println $rvstepstr ;

# generate table string (assuming sizes of adatch1
# ...  and ch2 are the same - which they should be)
# note also that 128 represents the 0, apparently
my $frDatSize = $frSizes[1];
my $outdat = "";
my ($amxp1,$amxn1,$amxp2,$amxn2); # max positive and negative
$amxp1 = $amxn1 = $amxp2 = $amxn2 = 0;

# no need to set at one:
# my $timecoeff = 1; # to avoid div. by zero errors in case of fail
# ... since timecoeff actually is sampling period ($sperd):
# ... now that is in $final_timestep
my $timecoeff = $final_timestep;

if ($retval == 0) { # only if proper data

  # this timecoeff is, actually, wrong:
  # $timecoeff = $totaltimespan/$frDatSize;
  # timecoeff is actually sampling period (via .CSV file from scope)
  # ... now it is $final_timestep

  for ( my $i = 0; $i < $frSizes[1]; $i++ ) {
    # remember both "zero" (128) and "byte" offset here before scaling:
    my $aval1 = ($adatch1[$i]-128-$voff1_ic)*$ch1Vcoeff;
    my $aval2 = ($adatch2[$i]-128-$voff2_ic)*$ch2Vcoeff;
    $amxp1 = $aval1 if ($aval1 > $amxp1);
    $amxn1 = $aval1 if ($aval1 < $amxn1);
    $amxp2 = $aval2 if ($aval2 > $amxp2);
    $amxn2 = $aval2 if ($aval2 < $amxn2);
    $outdat .=  $i .",". $adatch1[$i] .",". $adatch2[$i] .",".
                $i*$timecoeff .",". format_eng($aval1) .",". format_eng($aval2) ."\n";
  }
}
my $rangestr = "Real volt ranges: ch1 (". format_eng($amxn1) .",". format_eng($amxp1) .") ; ch2 (". format_eng($amxn2) .",". format_eng($amxp2) .")";
println $rangestr;

# expecting that attengrab.pl will get .ssf before it gets the wave data
# so if matching .ssf file found, parse it - and insert the strings!
my $ssf_string = "";
my $scope_triglevel = 0;
my $scope_trigholdo = 0;
my $ofnssf = "$ofnb.ssf";
if (-f $ofnssf) {
  &parse_ssf();
  $ssf_string = "#ssf $ssf_l1\n#ssf $ssf_l2\n#ssf $ssf_l3\n#ssf $ssf_l4\n#ssf $ssf_l5\n#ssf $ssf_l6\n#ssf $ssf_l7\n";
  $scope_triglevel = format_eng(sprintf("%.6e",$ssf_triglevel));
  $scope_trigholdo = format_eng(sprintf("%.6e",$ssf_trig_holdoff));
}

# output .csv table, plottable in gnuplot

my $output = "# $ofncsv [generated by ".__FILE__."]
# scope data:
# $vdiv1str
# $voff1str
# $vdiv2str
# $voff2str
# $tbasestr
# $sratestr
# $sperdstr
# $tprdrangestr
# $checkrangestr
# $osfstr
# $toffsstr
# $btnsstr
# $trigstr
# $rangestr
# $rvstepstr
# Number of samples in data: $numsamples (ch1: $frSizes[1] ; ch2: $frSizes[2])
$ssf_string# ------------------------
# (sample index), (ch1 raw uint), (ch2 raw uint), (time [s]), (ch1 [V]), (ch2 [V])
# ------------------------
$outdat";

print { $ofh } $output;
close($ofh);
println "Saved $ofncsv";

# if we came this far, let's also generate gnuplot script file

# read data section, only to __END__ token
my $gpstr;
while (<DATA>) {
  last if ($_ =~ /^__END__/);
  $gpstr .= $_;
}

# prepare vars that may be needed for expansion:
# output filename for gnuplot script (def before expansion)
my $ofngps = "$ofnb.gnuplot";
# $toffs real - need an int, too
my $toffs_i = int($toffs/$timecoeff);

# extra range for integer axis
my $ifrDatHalf = int($frDatSize/2);
my $iax2min = -$ifrDatHalf;
my $iax2max = $ifrDatHalf-1;

# script filename (but still path leaks in gnuplot file? basename)
my $scrfn = __FILE__;

# expand Perl variables in the DATA section template via regex
# protect them as ${} when concatenating ${a}_b
$gpstr =~ s/(\${\w+})/${1}/eeg;
# since now we use $0 for column reference - then
# do not expand normal - only expand ${}
#~ $gpstr =~ s/(\$\w+)/$1/eeg;
die if $@;                  # needed on /ee, not /e

my $ofhgps;
open($ofhgps,'>',"$ofngps") or die "Cannot open $ofngps ($!)";

print { $ofhgps } $gpstr;
close($ofhgps);
println "Saved $ofngps";

=cut just a test call to gnuplot:
# test call to gnuplot here;
# it will generate warnings (and empty png) for stdout, but will not fail:
print "Calling gnuplot $ofngps ... ";
my $gpstatus = system("gnuplot", "$ofngps");
if (($gpstatus >>=8) != 0) {
    die "Failed to run gnuplot!";
}
=cut


println "All done; exiting.";

exit $retval; # should be by default - but keeping it anyways..

## END MAIN ######################################


sub parse_ssf {

  # read in entire file / slurp in one go
  #~ my $infilename = $ofnssf;
  open(my $fh,'<',$ofnssf) or die "Cannot open $ofnssf ($!)";
  binmode($fh);
  my $indata;sysread($fh,$indata,-s $fh);
  close($fh);
  # convert string $indata to array/list, for easier indexing
  # do NOT use split, not binary safe; use unpack instead
  my @ssfExtractDat = unpack('C*',$indata);

  my @atmp = ();

  @atmp[0..3] = @ssfExtractDat[0x10..0x13];
  $ssf_triglevel_f = unpack("f", pack("C4", @atmp));
  @atmp[0..3] = @ssfExtractDat[0x34..0x37];
  $ssf_triglevel_i = unpack("l", pack("C4", @atmp));
  $ssf_trigsource = $ssfExtractDat[0x1b6];
  $ssf_trigtype = $ssfExtractDat[0x22b];
  # stays on updown if type pulse
  $ssf_trigedgeslope = $ssfExtractDat[0x1b7];

  $ssf_ch1probe = $ssfExtractDat[0x19a];
  $ssf_ch2probe = $ssfExtractDat[0x19f];
  $ssf_trigfact = 0;
  if ($ssf_trigsource == 0) {
    $ssf_trigfact = $ssf_ch1probe;
  } elsif ($ssf_trigsource == 1) {
    $ssf_trigfact = $ssf_ch2probe;
  } elsif ($ssf_trigsource == 2) { # EXT
    $ssf_trigfact = 0; # that is, $ssf_probestia[0] = 1; ok for EXT
  } elsif ($ssf_trigsource == 2) { # EXT/5
    $ssf_trigfact = 1; # that is, $ssf_probestia[1] = 5; ok for EXT
  } # and none for AC line
  $ssf_triglevel = $ssf_triglevel_f*1e-3*$ssf_probestia[ $ssf_trigfact ];

  $ssf_ch1coupling = $ssfExtractDat[0x197];
  $ssf_ch2coupling = $ssfExtractDat[0x19c];
  $ssf_ch1bwlimit = $ssfExtractDat[0x198];
  $ssf_ch2bwlimit = $ssfExtractDat[0x19d];
  $ssf_ch1vdiv = $ssfExtractDat[0x199];
  $ssf_ch2vdiv = $ssfExtractDat[0x19e];
  $ssf_ch1invert = $ssfExtractDat[0x1a1];
  $ssf_ch2invert = $ssfExtractDat[0x1a6];
  $ssf_ch1filter = $ssfExtractDat[0x278];
  $ssf_ch2filter = $ssfExtractDat[0x27d];
  $ssf_ch1filtertype = $ssfExtractDat[0x279];
  $ssf_ch2filtertype = $ssfExtractDat[0x27e];
  @atmp[0..3] = @ssfExtractDat[0x08..0x0b];
  $ssf_vdiv1_f = unpack("f", pack("C4", @atmp));
  $ssf_vdiv1 = $ssf_vdiv1_f*1e-3*$ssf_probestia[$ssf_ch1probe];
  @atmp[0..3] = @ssfExtractDat[0x0c..0x0f];
  $ssf_vdiv2_f = unpack("f", pack("C4", @atmp));
  $ssf_vdiv2 = $ssf_vdiv2_f*1e-3*$ssf_probestia[$ssf_ch2probe];
  $ssf_tdiv_1 = $ssfExtractDat[0x44];
  $ssf_tdiv_2 = $ssfExtractDat[0x134];
  @atmp[0..3] = @ssfExtractDat[0x1c..0x1f];
  $ssf_toffs_f = unpack("f", pack("C4", @atmp));
  $ssf_trigmode1 = $ssfExtractDat[0x1b8];
  $ssf_trigmode2 = $ssfExtractDat[0x229];
  $ssf_trigcouple = $ssfExtractDat[0x1b9];
  @atmp[0..3] = @ssfExtractDat[0xcc..0xcf];
  $ssf_trig_holdoff_i = unpack("l", pack("C4", @atmp));
  $ssf_trig_holdoff = $ssf_trig_holdoff_i*10e-9;
  $ssf_trigpulsewhen = $ssfExtractDat[0x225];
  $ssf_trigvidpol1 = $ssfExtractDat[0x1bc];
  $ssf_trigvidpol2 = $ssfExtractDat[0x202];
  $ssf_trigvidsync = $ssfExtractDat[0x1bd];
  $ssf_trigvidstd = $ssfExtractDat[0x32d];
  $ssf_trigslopevert = $ssfExtractDat[0x319];
  # apparently, the vertical levels (set with the rotary knob)
  # are not saved in .ssf file
  $ssf_trigslopewhen = $ssfExtractDat[0x315];
  @atmp[0..3] = @ssfExtractDat[0xd0..0xd3];
  $ssf_trigslopetime_f = unpack("f", pack("C4", @atmp));
  $ssf_trigslopetime_x = $ssfExtractDat[0xd4];
  $ssf_trigslopetime = $ssf_trigslopetime_f*$ssf_trigslopetimea[$ssf_trigslopetime_x];
  # Upp_Limit and Low_limit of ch1/ch2 filter type is apparently
  # not saved in .ssf!


  $ssf_l1 = sprintf(
    "V/DIV1 %sV V/DIV2 %sV T/DIV1 %ss T/DIV2 %ss Toffs %ss",
    format_pref($ssf_vdiv1), format_pref($ssf_vdiv2),
    format_pref($tdiva[$ssf_tdiv_1]),format_pref($tdiva[$ssf_tdiv_2]),
    format_pref(sprintf("%.6e",$ssf_toffs_f*1e-6))
  );

  $ssf_l2 = sprintf(
    "CH1: probe %d:%s couple %d:%s BWL %d INV %d Filt %d FiltType %d:%s",
    $ssf_ch1probe,$ssf_probestga[$ssf_ch1probe], $ssf_ch1coupling, $ssf_couplinga[$ssf_ch1coupling],
    $ssf_ch1bwlimit, $ssf_ch1invert, $ssf_ch1filter,
    $ssf_ch1filtertype, $ssf_filtypa[$ssf_ch1filtertype]
  );

  $ssf_l3 = sprintf(
    "CH2: probe %d:%s couple %d:%s BWL %d INV %d Filt %d FiltType %d:%s",
    $ssf_ch2probe,$ssf_probestga[$ssf_ch2probe], $ssf_ch2coupling, $ssf_couplinga[$ssf_ch2coupling],
    $ssf_ch2bwlimit, $ssf_ch2invert, $ssf_ch2filter,
    $ssf_ch2filtertype, $ssf_filtypa[$ssf_ch2filtertype]
  );

  $ssf_l4 = sprintf(
    "Trigger: level %sV mode %d:%s SRC %d:%s Type %d:%s Couple %d:%s Holdoff %ss",
    format_pref(sprintf("%.6e",$ssf_triglevel)),
    $ssf_trigmode1, $ssf_trigmodea[$ssf_trigmode1],
    $ssf_trigsource, $ssf_trigsrca[$ssf_trigsource], $ssf_trigtype, $ssf_trigtypa[$ssf_trigtype],
    $ssf_trigcouple, $ssf_trigcpla[$ssf_trigcouple], format_pref($ssf_trig_holdoff)
  );
  $ssf_l5 = sprintf(
    "         EdgeSlope %d:%s PulseWhen %d:%s",
    $ssf_trigedgeslope, $ssf_trigedgeslopa[$ssf_trigedgeslope],
    $ssf_trigpulsewhen, $ssf_trigpulsewhena[$ssf_trigpulsewhen],
  );
  $ssf_l6 = sprintf(
    "         VidPol: %d:%s VidSync: %d:%s VidStd %d:%s",
    $ssf_trigvidpol1, $ssf_trigvidpola[$ssf_trigvidpol1],
    $ssf_trigvidsync, $ssf_trigvidsynca[$ssf_trigvidsync],
    $ssf_trigvidstd, $ssf_trigvidstda[$ssf_trigvidstd]
  );
  $ssf_l7 = sprintf(
    "         SlopeVertical %d:%s SlopeWhen: %d:%s SlopeTime: %ss",
    $ssf_trigslopevert, $ssf_trigslopeverta[$ssf_trigslopevert],
    $ssf_trigslopewhen, $ssf_trigslopewhena[$ssf_trigslopewhen],
    format_pref(sprintf("%.2e",$ssf_trigslopetime))
  );

} # end sub




# the DATA section is the gnuplot script for the data:
__DATA__

# ${ofngps} [generated by ${scrfn}]
# single gnuplot file, with two potentially independent scripts
# generates three plots: one based on integer, other based on real (SI) values
# and one bitmap overlay - and then montages them using ImageMagick

# attengrab .csv can just be centered (over t)
# -> the x=0 (t=0) will correspond to scope center
# (but .DAV/.CSV will also need extra sample alignment)

# in Linux, to see available fonts, do:
# fc-list --verbose | grep 'fullname:' | less
# the two fonts used here:
# LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"; and Helvetica
# Helvetica doesn't even get reported on my system:
# $ fc-list --verbose | grep 'fullname:' | grep -i 'Helvetica\|Demi Cond'
#	fullname: "LM Sans Demi Cond 10 Regular"(s) "LMSansDemiCond10-Regular"(s)


print "Gnuplotting..."

## "master settings" (shared between both parts of script)

# line color - specified by linestyles
set style line 1 linetype 1 linecolor rgb "red"
set style line 2 linetype 1 linecolor rgb "green"
set style line 3 linetype 1 linecolor rgb "orange"
set style line 4 linetype 1 linecolor rgb "aquamarine"
set style line 5 linetype -1 linecolor rgb "black"
set style line 6 linetype -1 linecolor rgb "gray"
set style line 7 linetype 1 linecolor rgb "blue"


# VARIABLES ########### ########### ###########

fnbase="${ofnb}"
fn_bmp = fnbase . ".bmp"
fn_pngr = fnbase . "_r.png"
fn_pngi = fnbase . "_i.png"
fn_pngov = fnbase . "_ov.png"
fn_pngt = fnbase . "_tmp.png"
fn_pngo = fnbase . ".png"

# scope screen(shot) properties
tdiv = ${tbase}          # T/DIV (50e-9)
toffs = ${toffs}        # time offset (scope) (200e-9)
vdiv1 = ${vdiv1}        # V/DIV CH1 (500e-3)
vdiv2 = ${vdiv2}         # V/DIV CH2 (50e-3)
voffs1 = ${voff1}         # volt offset CH1 (-1.5)
voffs2 = ${voff2}       # volt offset CH2 (100e-3)
sampintp  = ${sperd}    # (500e-12)
sampintf  = 1/sampintp
sratacqf  = ${srate}      # (250e6)
sratacqp  = 1/sratacqf
#osf = ${osf}    # oversample factor (multiplies .CSV and .DAV time domain) # unused here
adsFactor = ${adsFactor}

# (edges of current capture and divisions)
scope_hdiv=${scope_hdivs}
scope_vdiv=${scope_vdivs}
# enforce floating point (see below)
scope_trange = scope_hdiv*tdiv*1.0    # (900e-9)
scope_left=toffs-(scope_trange/2)     # (-250e-9)
scope_right=toffs+(scope_trange/2)    # (650e-9)
scope_bottom=-voffs1-(scope_vdiv*vdiv1/2) # -500e-3
scope_top=-voffs1+(scope_vdiv*vdiv1/2)    # 3.5

totalch1Vspan=scope_vdiv*vdiv1
totalch2Vspan=scope_vdiv*vdiv2
ch1Vcoeff = adsFactor*totalch1Vspan/(2**8)
ch2Vcoeff = adsFactor*totalch2Vspan/(2**8)

voffs1int = voffs1/ch1Vcoeff  # ${voff1_ic}
voffs2int = voffs2/ch2Vcoeff  # ${voff2_ic}

acsv_fn = fnbase . '.csv' # '20130020-013902.csv' # from attenload tmp_wav
acsz=${frDatSize}         # tmp_wav/.csv size (900)
fts=${final_timestep}         # final timestep (sampling period)
# here scope_trange could be 18*1, with acsz 16000;
# if as integer, 18/16000 would be 0 - enforce floating point
# above enforcing scope_trange to float doesn't work,
# must again here:
tdivp = 1.0*scope_trange/acsz   # sampling rate, based on scope range and numsamples in tmp (1ns)
tdivf = 1/tdivp             # freq based on that sampling rate

# just in case - not needed usually:
triglevel=${scope_triglevel}
trigholdoff=${scope_trigholdo}

toffsamp = toffs/fts		# ${toffs_i}
# time finetune offset - int (samples) (depends on range)
tfoi = ${tfoi}


#### extract bitmap from .png, if .bmp not present
# was -crop 480x234+10+10; now -crop 480x234+95+128

cmdstr = 'if (! test -f "'.fn_bmp.'") ; then \
  echo -n "'.fn_bmp.' not found .. " ; \
  if [ -f "'.fn_pngo.'" ] ; then \
    echo -n "'.fn_pngo.' found - extracting" ; \
    convert -crop 480x234+95+128 "'.fn_pngo.'" "'.fn_bmp.'" ; \
  else \
    echo -n "'.fn_pngo.' not found - cannot extract" ; \
  fi ; \
else \
  echo -n "'.fn_bmp.' found - using that" ; \
fi; echo'

#print cmdstr
# note - since cmdstr above uses double quotes,
# must use single quotes for bash here!:
print system("bash -c '". cmdstr ."' 2>&1")


##################################
###### plot directly with unsigned byte data

set terminal png size 840,480
set termoption enhanced
set termoption font "Helvetica, 12"

set output fn_pngi
set datafile separator ","

# set axis label
set xlabel "index" offset 0.0,0.8
set ylabel "byte unsigned value" offset 1.0,0.0


# horizontal line as functions
zeroline(x)=128
ch1offs(x)=128+voffs1int # (${voff1_ic})
ch2offs(x)=128+voffs2int # (${voff2_ic})

# vertical line - headless arrow
# "y" scope axis in middle:
ymI = acsz/2
set arrow from ymI,0 to ymI,255 nohead ls 5
# time offset:
toI = ymI - toffs/fts
set arrow from toI,0 to toI,255 nohead ls 6


# must use multiplot here, to have two x-axes
# and thus, must set lmargin, so both graphs match

set size 1.0,0.9      # 0.1/2 = 0.05
set bmargin 0
set lmargin 10
set yrange [0:255] # 8-bit


set multiplot

set origin 0,0.1
set xrange [0:acsz]
set xtics in
set xtics offset 0,graph 0.08
plot \
  zeroline(x) with lines notitle ls 5,\
  acsv_fn using 1:2 with lines title "ch1" ls 1, \
  "" using 1:3 with lines title "ch2" ls 2, \
  ch1offs(x) with lines notitle ls 3, \
  ch2offs(x) with lines notitle ls 4

unset arrow # if big offset, line from prev. can 'leak' in next at diff place, so reset

set origin 0,0.1
set xtics out
set xtics offset 0,graph 0.02
set xrange [-acsz/2:acsz/2-1]
#set xtics nomirror 500
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot 0 notitle

set nomultiplot


### reset previous settings
#unset border # no work for default
set border    # Draw default borders:
set ytics
unset yrange


##################################
###### plot with converted real SI units

# reset # resets set style line!

set terminal png size 840,480
set termoption enhanced
set termoption font "Helvetica, 12"

set output fn_pngr
set datafile separator ","

# set axis label
set xlabel "t [s]" offset 0.0,0.1
set ylabel "U [V]" offset 1.0,0.0

# axis tics format
set format y "%.1s%c"
set format x "%.1s%c"


# horizontal line as functions
zerolineR(x)=0
# don't show real offsets; they could be way off depending on V/DIV
#ch1offsR(x)=0+(${voff1})
#ch2offsR(x)=0+(${voff2})

# "y" scope axis in middle (the +1 added to ymI so it snaps at 0):
ymR=(ymI+1)*fts
set arrow from ymR,graph 0 to ymR,graph 1 nohead ls 5
# time offset:
toR=toI*fts
set arrow from toR,graph 0 to toR,graph 1 nohead ls 6
# indicate scope range here too
set arrow from scope_left+toR,graph 0 to scope_left+toR,graph 1 nohead ls 7
set arrow from scope_right+toR,graph 0 to scope_right+toR,graph 1 nohead ls 7


# must use multiplot here, to have two x-axes
# and thus, must set lmargin, so both graphs match

set size 1.0,0.9      # 0.1/2 = 0.05
set bmargin 0
set lmargin 10
set yrange [] writeback # since we don't set explicity, must save autorange
set autoscale y

set multiplot

set origin 0,0.13
set xrange [0:acsz*fts]
set xtics out
set xtics offset 0,graph -0.03
plot \
  zerolineR(x) with lines notitle ls 5,\
  acsv_fn using ($4+tfoi*fts):5 with lines title "ch1" ls 1, \
  "" using ($4+tfoi*fts):6 with lines title "ch2" ls 2

set yrange restore # this saves the found yrange after `plot`
unset arrow # if big offset, line from prev. can 'leak' in next at diff place, so reset

set origin 0,0.13
set xtics out
set xtics offset 0,graph 0.02
set xrange [(-acsz/2)*fts:(acsz/2-1)*fts]
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot GPVAL_Y_MIN notitle

set origin 0,0.13
set xtics in
set xtics offset 0,graph 0.08
# wrong to put xrange [scope_left:scope_right] here;
# as [scope_left:scope_right] could be a snippet,
# and this graph shows entire capture!
# simply move the previous scale for toffset
toRR=(acsz/2.)*fts-toR
set xrange [(-acsz/2)*fts+toRR:(acsz/2-1)*fts+toRR]
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot GPVAL_Y_MIN notitle

set nomultiplot


##################################
###### plot with bitmap and data overlay

# here 840,480 remains as output png size,
# even if not set explicitly; also, make
# the height smaller - so can have gravity North in montage

set terminal png truecolor size 640,305 # size 840,480
set termoption enhanced
myfont="LMSansDemiCond10-Regular"   # LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"
# cannot do concatenation direct in termoption line, so in separate string
myfontb="".myfont.", 12"
set termoption font myfontb

set output fn_pngov
set datafile separator ","


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
# right is only gnuplot 4.6 - without it ok w/ 4.4
#set xtics rotate by -45 offset 2.5,-1.50 right format "%+.1s%c" font myfont.',10'
set xtics rotate by -45 offset 0.0,0.0 format "%+.1s%c" font myfont.',10'
set key noenhanced

# dimensions of scope screenshot bitmap
bmp_w=480
bmp_h=234

# alpha bmp transparency [0:255]
bmp_alpha = 150
# boxes fillstyle transparent solid 0.10
box_transp = (1.-(acsz/16384.))*0.9 + 0.10

# plot string for data in transparent bitmap:
plot1au = "(($0-acsz/2.+tfoi)*fts+toffs):($5)"

# bmp_w=480 bmp_h=234 ; inside 451x201+15+14
# on plot: scope_left:scope_right and scope_bottom:scope_top!
# (so toffset is built in!)

bdx = scope_trange/(451.0-1)  # [s/pixel] /451: 1.99557e-09 vs 2.000e-9 manually
bdy = totalch1Vspan/(201.0-1) # [V/pixel] /201: 0.0199005 vs 0.02005 manually
bofx = -((scope_trange/2.0)-toffs+(15.0+0)*bdx) #-15.0*bdx # -2.8e-7
bofy = -((totalch1Vspan/2.0)+voffs1+(14.0+5)*bdy) #-14.0*bdy # -0.88

# seems `boxes fillstyle transparent solid 0.40` makes some seethroughs
# or something with bmp alpha overlay; but even without, all the same?
# because the red + blue (somehow inverted) creates a gray.. better green or orange

_plot_str = "zerolineR(x) with lines notitle ls 1,\
acsv_fn \
  using ".plot1au." with boxes fillstyle transparent solid box_transp noborder linestyle 3\
  title 'BITMAP+DATA OVERLAY: '.acsv_fn.' (CH1 only)',\
fn_bmp \
  binary array=(bmp_w,bmp_h) skip=54 format='%uchar' \
  dx=bdx dy=bdy origin=(bofx,bofy) \
  using 1:2:3:(bmp_alpha) \
  with rgbalpha t ''"

# seems actual plot in screenshot bitmap (480 × 234)
#  is at: 451x201+15+14; aspect ratio 201/451 = 0.445676
set size ratio 0.445676

eval("plot " . _plot_str)




##################################
###### montage commands

# used to be in attengrab; now here
# call ImageMagick montage via system
# and montage in `gnuplot` (easier to separate)

print "Montaging images..."
# this works in ImageMagick 6.6.2-6, but not in 6.5.7-8
#      '.fn_pngov.' -gravity Center -extent x480  \#
# must spec -extent 640x480 for 6.5

cmdstr = 'montage \
  <(montage \
    <(convert \
      '.fn_bmp.' -gravity Center -crop 640x480-10+0! -flatten  \
      bmp:-) \
    <(convert \
      '.fn_pngov.' -gravity Center -extent 640x480  \
      bmp:-) \
  -tile 1x -geometry +0+0  \
  bmp:-) \
  <(montage \
    '.fn_pngi.' \
    '.fn_pngr.' \
  -tile 1x -geometry +0+0  \
  bmp:-) \
-geometry +0+0 -border 5 \
'.fn_pngo

print cmdstr
print system('bash -c "'. cmdstr .'" 2>&1')

print "Deleting temp files ..."

delcmd = "rm"

# leave the bitmap for now
# actually, let attengrab handle it - since
# it may need to be re-taken!
# #cmdstr = delcmd ." ". fn_bmp
# #print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngr
print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngi
print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngov
print cmdstr . "  " . system(cmdstr . " 2>&1")




# note:
# set terminal png size 840,480 # size defaults to 640x480 px
# set terminal pdf size 10,3 # size defaults to 5x3 in
# enhanced text: set termoption enhanced

# vertical line - headless arrow
# need ymin and ymax; gnuplot gives them only after plot -
# - and even then they do not correspond to end ticks
# - and even then, cannot get the arrow to show, after the second `plot`
# .. nor can I edit it anyhow; it must run before the first `plot`
# so instead of that, position y coordinates relative to graph (0 to 1)
#set arrow 1 from graph 0.5,0 to graph 0.5,1 nohead ls 5

# in multiplot, yrange should be after the size command
# note: xrange could be 2250 or 450
# so leave it to autoscale here? will be accurate since it's integer index...
# now set explicitly by script # below in multiplot

# axis tics format
# for engineering notation - 'help format specifiers':
# "A 'scientific' power is one such that the exponent is a multiple of three."

# print "Montaging images..."

# "The 'tile' size is then set to the largest dimentions
# of all the resized images, and the size actually specified."
# "by removing the 'size' component, non of the images will
# be resized, and the 'tile' size will be set to the largest
# dimensions of all the images given"
# not so simple: http://unix.stackexchange.com/questions/4046/
# can be done in one command with bash subprocess pipes (bash only)
# was: .fn_bmp.' -gravity NorthWest ; fn_pngov.' -gravity North
# can pad with -gravity Center -extent 640x480;
# but also with crop! -flatten - there have offset too!
# -geometry +2+2 can also mess up the last -border 5 !

# bmp scale worked for:
# bmp_w=480 bmp_h=234 ; inside 451x201+15+14
# tdiv = 5e-08,  toffs = 2e-07,  vdiv1 = 0.5,   voffs1 = -1.5,
# dx=2.000e-9 dy=0.02005 origin=(-2.8e-7,-0.88) for
# tspan = 18*tdiv = 18*5e-08 = 9e-07s
# vspan1 = 8*vdiv1 = 8*0.5 = 4V
# tspan/451 = 9e-07/451 = 1.99557e-09 s/pixel
# vspan1/201 = 4/201 = 0.0199005 V/pixel
# bdx=tspan/(451-1) = '9e-07/(451-1)' = 2e-09
# bdy=vspan1/(201-1) = '4/(201-1)' = 0.02
# 15*bdx = 15*2e-9 = 3e-08
# 14*bdy = 14*0.02 = 0.28
# 15*1.99557e-09 = 2.99335e-08
# 14*0.0199005 = 0.278607

__END__
