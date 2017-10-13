#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


package adsparse_dvstngs_pl;

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

the relevant data is 37 times r200; start header is 20 bytes:

00000000  44 53 4f 50 50 56 32 30  00 00 48 58 01 05 00 00
00000010  00 04 00 00

settings are 2500 bytes after that; only one header expected in data

NOTE: ssf and .SET files should be "the same", except .ssf is 2500 bytes, .SET is 2048 bytes (the rest in the .ssf is usually zeroes)

=cut

use open IO => ':raw'; # no error

binmode(STDIN);
binmode(STDOUT);

use File::Basename;
use Cwd qw(abs_path);
use lib dirname (abs_path(__FILE__));
# include attenScopeIncludes
use attenScopeIncludes;
# declare from attenScopeIncludes
our @tdiva;
# for .ssf (device settings) parsing:
our (@ssf_trigsrca , @ssf_trigtypa , @ssf_probestga , @ssf_probestia , @ssf_trigedgeslopa , @ssf_couplinga , @ssf_chvdiva , @ssf_trigmodea , @ssf_trigcpla , @ssf_trigpulsewhena , @ssf_trigvidpola , @ssf_trigvidsynca , @ssf_filtypa , @ssf_trigvidstda , @ssf_trigslopeverta , @ssf_trigslopewhena , @ssf_trigslopetimea);

use Number::FormatEng qw(:all);


# Note: say - Just like print, but implicitly appends a newline (v >= 5.10)
# ... but this println I made auto to STDERR, so keeping it:
sub println  { local $,="";   print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }
sub printlns { local $,=$/; print STDERR +( @_ ? @_ : $_ ), $/ } #, "\n" }


#======= "main"

if ($#ARGV < 0) {
 print STDERR "usage:
perl adsparse-dvstngs.pl bindat_file [out_filename_base]

  Without `out_filename_base`, parsed bitmap data goes to STDOUT:
  1) perl adsparse-dvstngs.pl bindat.dat myCapture01
  2) perl adsparse-dvstngs.pl bindat.dat 1>stdout.ssf\n";
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
my $ofnssf; # output filename for the .csv
# check for second argument - otherwise work with STDOUT as main output:
if ((!defined $ARGV[1]) || ($ARGV[1] eq "")) {
  $ofnb = "stdout";
  $ofh = \*STDOUT;
  $ofnssf = "stdout.(ssf)"; # since we cannot know name in this case
  println "Writing to STDOUT";
} else {
  $ofnb = $ARGV[1];
  $ofnssf = "$ofnb.ssf";
  open($ofh,'>',$ofnssf) or die "Cannot open $ofnssf ($!)";
  println "Writing to $ofnb.ssf";
}


# convert string $indata to array/list, for easier indexing
# do NOT use split, not binary safe; use unpack instead
my @aindata = unpack('C*',$indata);



# look for the header signature
my $hdrlookfor = "\x44\x53\x4f\x50\x50\x56\x32\x30\x00\x00\x48\x58\x01\x05\x00\x00\x00\x04\x00\x00";
my @hdrinds = ();
my $pos = 0;
while ($pos>=0) {
  $pos = index($indata, $hdrlookfor, $pos);
  if ($pos>=0) { push(@hdrinds, $pos++) };
}

if ($#hdrinds<0) {
  print STDERR "Header not found; exiting\n";
  exit -1;
}

print STDERR __FILE__.": Found (".($#hdrinds+1).") headers " . "at: ". join(', ', @hdrinds). "\n";


# extract data
my $hind = $hdrinds[0];
my @ssfExtractDat = ();
@ssfExtractDat[0 .. 2499] = @aindata[$hind+20 .. $hind+2520];


# `join` is seemingly NOT binary safe if chars are part of array! use pack here:
my $settingsOutput = pack("C*", @ssfExtractDat);


print { $ofh } $settingsOutput;
println "Saved $ofnssf";
close($ofh);


# attempt to parse trigger level

# have to keep these here for the sub function below
my ($ssf_triglevel_f , $ssf_triglevel_i , $ssf_trigsource , $ssf_trigtype , $ssf_trigedgeslope , $ssf_trigmode1 , $ssf_trigmode2 , $ssf_trigcouple , $ssf_trig_holdoff_i , $ssf_trig_holdoff , $ssf_trigpulsewhen , $ssf_trigvidpol1 , $ssf_trigvidpol2 , $ssf_trigvidsync , $ssf_trigvidstd , $ssf_trigslopevert , $ssf_trigslopewhen , $ssf_trigslopetime_f , $ssf_trigslopetime_x , $ssf_trigslopetime , $ssf_trigfact , $ssf_triglevel);
my ($ssf_ch1probe , $ssf_ch2probe , $ssf_ch1coupling , $ssf_ch2coupling , $ssf_ch1bwlimit , $ssf_ch2bwlimit , $ssf_ch1vdiv , $ssf_ch2vdiv , $ssf_ch1invert , $ssf_ch2invert , $ssf_ch1filter , $ssf_ch2filter , $ssf_ch1filtertype , $ssf_ch2filtertype , $ssf_vdiv1_f , $ssf_vdiv1 , $ssf_vdiv2_f , $ssf_vdiv2 , $ssf_tdiv_1 , $ssf_tdiv_2 , $ssf_toffs_f , $ssf_l1 , $ssf_l2 , $ssf_l3 , $ssf_l4 , $ssf_l5 , $ssf_l6 , $ssf_l7);

#~ &parse_ssf();
#~ println "
#~ $ssf_l1
#~ $ssf_l2
#~ $ssf_l3
#~ $ssf_l4
#~ $ssf_l5
#~ $ssf_l6
#~ $ssf_l7
#~ ";

println "All done; exiting.";

exit 0; # should be by default - but keeping it anyways..

## END MAIN ###############################



sub parse_ssf {

  my @atmp = ();

  # ff ff ff ff = 32bit
  # int seems absolute as in screen position
  # (independent of ch1/ch2 positions)
  # edge screen is at 100/-100, middle of screen at 0
  # and outside 150/-150 is Trig Volt Level limit
  # float seems relative to either ch1 or ch2 (respectively) offset level,
  # and is 112 for 1.12 V (-20 for -200mV) - so *10
  # but for ext it is not *10 - apparently the probe setting!
  ## println "
  ## Trig level:
    ## float[" . 0x10 . "] = $ssf_triglevel_f
    ## int[" .0x34. "] = $ssf_triglevel_i
    ## int as bin: " . sprintf("%032b", $ssf_triglevel_i) ;

  my ($try_Al,$try_Af);
  @atmp[0..3] = @ssfExtractDat[0x2c..0x2f];
  $try_Al = unpack("l", pack("C4", @atmp));
  $try_Af = unpack("f", pack("C4", @atmp));

  my ($try_Bl,$try_Bf);
  @atmp[0..3] = @ssfExtractDat[0x30..0x33];
  $try_Bl = unpack("l", pack("C4", @atmp));
  $try_Bf = unpack("f", pack("C4", @atmp));

  my ($try_Cl,$try_Cf);
  @atmp[0..3] = @ssfExtractDat[0x10c..0x10f];
  $try_Cl = unpack("l", pack("C4", @atmp));
  $try_Cf = unpack("f", pack("C4", @atmp));

  my $try_D = $ssfExtractDat[0x2d6];
  my ($try_El,$try_Ef);
  @atmp[0..1] = @ssfExtractDat[0x43b..0x43c];
  $try_El = unpack("s", pack("C2", @atmp));
  $try_Ef = unpack("S", pack("C2", @atmp));


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
  } elsif ($ssf_trigsource == 3) { # EXT/5
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

  #~ println "Test:
    #~ try_A: $try_Al $try_Af
    #~ try_B: $try_Bl $try_Bf
    #~ try_C: $try_Cl $try_Cf
    #~ trigsource: $ssf_trigsource ".$ssf_trigsrca[$ssf_trigsource]."
    #~ trigtype: $ssf_trigtype ".$ssf_trigtypa[$ssf_trigtype]."
    #~ trigedgeslope: $ssf_trigedgeslope ".$ssf_trigedgeslopa[$ssf_trigedgeslope]."
    #~ ch1probe: $ssf_ch1probe ".$ssf_probestga[$ssf_ch1probe]."
    #~ ch2probe: $ssf_ch2probe ".$ssf_probestga[$ssf_ch2probe]."
    #~ triglevel: " .format_pref(sprintf("%.6e",$ssf_triglevel))."V
    #~ trigmode: $ssf_trigmode1 ($ssf_trigmode2) ".$ssf_trigmodea[$ssf_trigmode1]."
    #~ trigcouple: $ssf_trigcouple ".$ssf_trigcpla[$ssf_trigcouple]."
    #~ trig_holdoff: $ssf_trig_holdoff_i ".format_pref($ssf_trig_holdoff)."s
    #~ trigpulsewhen: $ssf_trigpulsewhen ".$ssf_trigpulsewhena[$ssf_trigpulsewhen]."
    #~ ch1coupling: $ssf_ch1coupling ".$ssf_couplinga[$ssf_ch1coupling]."
    #~ ch2coupling: $ssf_ch2coupling ".$ssf_couplinga[$ssf_ch2coupling]."
    #~ ch1vdiv: $ssf_ch1vdiv ".$ssf_chvdiva[$ssf_ch1vdiv]."
    #~ ch2vdiv: $ssf_ch2vdiv ".$ssf_chvdiva[$ssf_ch2vdiv]."
    #~ ch1bwlimit: $ssf_ch1bwlimit
    #~ ch2bwlimit: $ssf_ch2bwlimit
    #~ ch1invert: $ssf_ch1invert
    #~ ch2invert: $ssf_ch2invert
    #~ ch1filter: $ssf_ch1filter
    #~ ch2filter: $ssf_ch2filter
    #~ ch1filtertype: $ssf_ch1filtertype ".$ssf_filtypa[$ssf_ch1filtertype]."
    #~ ch2filtertype: $ssf_ch2filtertype ".$ssf_filtypa[$ssf_ch2filtertype]."
    #~ vdiv1_f: $ssf_vdiv1_f
    #~ vdiv2_f: $ssf_vdiv2_f
    #~ vdiv1: ".format_pref($ssf_vdiv1)."V
    #~ vdiv2: ".format_pref($ssf_vdiv2)."V
    #~ tdiv_1: $ssf_tdiv_1 ".format_pref($tdiva[$ssf_tdiv_1])."s
    #~ tdiv_2: $ssf_tdiv_2 ".format_pref($tdiva[$ssf_tdiv_2])."s
    #~ toffs_f: $ssf_toffs_f ".format_pref(sprintf("%.6e",$ssf_toffs_f*1e-6))."s
    #~ try_D: $try_D
    #~ try_E: $try_El $try_Ef";

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




