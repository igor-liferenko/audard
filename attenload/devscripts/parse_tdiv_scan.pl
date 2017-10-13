#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


package parse_tdiv_scan_pl;

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::FormatEng

=cut


use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

use Number::FormatEng qw(:all);

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

$| = 1; # $|++; # set flushing of output buffers ALREADY HERE;

=note README

parse_tdiv_scan.pl is a simple script which writes out
the %timediv_sint_map array in adsparse-wave.pl

This array is produced by headers of .CSV files (saved by
scope to USB thumbdrive, with Data Depth: Displayed), obtained
for all TIME/DIV settings for two channel capture (one channel
may have different values), collected in a file.

To create this file, copy the content in the __DATA__ section
of this script and save it as ADSCSV_tdiv_scan.txt. Finally,
call the script with:

perl parse_tdiv_scan.pl ADSCSV_tdiv_scan.txt | less

The script will then dump the contents of %timediv_sint_map.

=cut

my %timediv_srate_map = (
  50        ,     50, # 12.5
  25        ,    100, # 25
  10        ,    250, # 50
   5        ,    500, # 125
   2.50     ,   1000, # 250
   1        ,   2500, # 500
   500e-3   ,   5000, # 1250
   250e-3   ,  10e3 , # 2500
   100e-3   ,  25e3 , # 5e3
    50e-3   ,  12.50e3 , # 12.5e3
    25e-3   ,  25e3 , # 25e3
    10e-3   ,  50e3 , # 50e3
     5e-3   , 125e3 , # 125e3
   2.5e-3   , 250e3 , # 250e3
     1e-3   , 500e3 , # 500e3
   500e-6   , 1.25e6 , # 1.25e6
   250e-6   , 2.5e6 , # 2.5e6
   100e-6   , 5e6 , # 5e6
    50e-6   , 12.5e6 , # 12.5e6
    25e-6   , 25e6 , # 25e6
    10e-6   , 50e6 , # 50e6
     5e-6   , 100e6 , # 100e6
   2.5e-6   , 100e6 , # 100e6
     1e-6   , 250e6 , # 250e6
   500e-9   , 250e6 , # 250e6
   250e-9   , 250e6 , # 250e6
   100e-9   , 250e6 , # 250e6
    50e-9   , 250e6 , # 500e6
    25e-9   , 250e6 , # 500e6
    10e-9   , 250e6 , # 500e6
     5e-9   , 250e6 , # 500e6
   2.5e-9   , 250e6   # 500e6
);


if ($#ARGV < 0) {
 print STDERR "usage:
perl parse_tdiv_scan.pl ADSCSV_tdiv_scan.txt | less
\n";
 exit 1;
}

my $adscsvfile = $ARGV[0];

say "\nProcessing $adscsvfile";

my $fh;
open($fh,'<',$adscsvfile) or die "Cannot open $adscsvfile ($!)";
binmode($fh);
#my @csvlines = <$fh>;

my @adscsvdata;
my ($adscsvreclen, $adscsvdatlen, $dopack) = (0)x3;
my ($adssampintch1, $adssampintch2) = (0)x2;
my ($adshu, $adshs, $adstrange) = (0)x3; # "Horizontal Units" (s), "Horizontal Scale" (0.0050000000), time range
my (@adsch1vals,@adsch2vals,@adstimevals);
my $curadsfile="";
my $rest;
my ($dopackcnt,$tsfirst,$tslast,$diffts)=(0)x4;

# http://stackoverflow.com/questions/3652527/match-regex-and-assign-results-in-single-line-of-code
# print my ($v1,$v2,$v3) = "769.230769230769G" =~ /(\.[\d][\d])(\d+)([a-zA-Z])/;
# print my ($v1) = ($v1 = "769.230769230769G") =~ s/(\.[\d][\d])(\d+)([a-zA-Z])/$1/;

while (<$fh>) {
  if ($dopack) {
    # skip any potential commented lines (#) remaining
    next if ($_ =~ "^#");
    chomp($_);
    if ($_ =~ /^\*\*\*\*\*/) { # moved so it ends record
      $dopack = 0;

      #~ say "$curadsfile: RecLen: ", sprintf "%6s", $adscsvreclen;
      #~ say " Sampl.int. (period) ch1:",$adssampintch1," ch2:",$adssampintch2;
      my $sampint = 1;
      my $freqsampint = 1;
      if ($adssampintch1 == $adssampintch2) {
        $sampint = $adssampintch1;
        $freqsampint = 1/$sampint;
        #~ say " sampint ", $sampint+0, "  freqsampint ", format_pref($freqsampint+0);
      } else { say "!!!!"; }
      if ($adshs eq "0.0010000001") { $adshs = 0.001; }
      $adshs += 0;
      my $srateTDIV = $timediv_srate_map{$adshs};
      $diffts = $tslast-$tsfirst;
      #~ say " tsfirst $tsfirst tslast $tslast";
      my $origreclen = $diffts/$sampint;
      my $origsampint = $diffts/$adscsvreclen;
      my $eqsampint = 18*$adshs/$adscsvreclen;
      my $eqsampfreq = 1/$eqsampint;
      #~ say " diffts $diffts diffts/sampint $origreclen diffts/RecLen $origsampint";
      #~ say " Horizontal Scale (timebase, T/DIV): $adshs Units: [$adshu]; srateTDIV ", format_pref($srateTDIV+0);
      #~ say " eqsampint $eqsampint eqsampfreq ", format_pref($eqsampfreq);
      (my $tmporl = sprintf "%10.3f",  $origreclen) =~ s/.000/    /;
      my $tmphs = format_eng($adshs);
      (my $tmpesf = format_pref($eqsampfreq)) =~ s/\.([\d])+/\.$1/;
      (my $tmpsfi = format_pref($freqsampint)) =~ s/(\.[\d][\d])(\d+)/$1/;
      (my $tmpesi = format_eng($eqsampint)) =~ s/(\.[\d][\d])(\d+)/$1/;
      (my $tmpeso = format_eng($origsampint)) =~ s/(\.[\d][\d])(\d+)/$1/;
      say "  # $curadsfile:                  len:", sprintf("%6s (%9s)", $adscsvreclen, $tmporl);
      say sprintf("  %6s, %s ,    # (%7s)(%9s) %5s/%7s,[%7s]", $tmphs, $adssampintch1, $tmpesi, $tmpeso, format_pref($srateTDIV), $tmpesf, $tmpsfi);
    } else {
      $dopackcnt++;

      $_ =~ s/^\s+//; #ltrim
      $_ =~ s/\s+$//; #rtrim
      my @csvline = split(",", $_);
      push(@adscsvdata, \@csvline); # must push ARRAY ref here, for 2D index!
      push(@adstimevals, $csvline[0]);
      push(@adsch1vals, $csvline[1]);
      push(@adsch2vals, $csvline[2]);

      if ($dopackcnt == 1) { $tsfirst = $csvline[0]; }
      if ($dopackcnt == 5) { $tslast = $csvline[0]; }

      $adscsvdatlen++;
    }
  } else {
    if ($_ =~ /^lines/) {
      if ($_ =~ /ADS(.+)\./) { $curadsfile = "ADS$1"; }
    }
    if ($_ =~ /Record Length/) {
      # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
      ($rest, $adscsvreclen) = split /,/, $_, 2;
      chomp($adscsvreclen);
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
      $dopackcnt=0;
    }
  }
}
close($fh);

=cut sample out(s)
ADS00001: RecLen:     12
 Sampl.int. (period) ch1:0.0000000000013 ch2:0.0000000000013
 sampint 1.3e-12  freqsampint 769.230769230769G
 tsfirst -0.00000001680 tslast 0.00000007120
 diffts 8.8e-08 diffts/sampint 67692.3076923077 diffts/RecLen 7.33333333333333e-09
 Horizontal Scale (timebase, T/DIV): 2.5e-09 Units: [s]; srateTDIV 250M
 eqsampint 3.75e-09 eqsampfreq 266.666666666667M

  # ADS00001:                  len:    12 ( 67692.308)
  2.5e-9, 0.0000000000013 ,    # (3.75e-9)(  7.33e-9)  250M/ 266.7M,[769.23G]
=cut

__DATA__

728	/path/to/ADS00001.CSV
lines 25 /path/to/ADS00001.CSV
Record Length,12
Sample Interval,CH1:0.0000000000013 CH2:0.0000000000013
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000000025,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000001680,0.19200,0.01200
-0.00000000880,0.24200,0.01200
...
 0.00000006320,0.24200,0.01200
 0.00000007120,0.22400,0.01200
*****
1069	/path/to/ADS00002.CSV
lines 36 /path/to/ADS00002.CSV
Record Length,23
Sample Interval,CH1:0.0000000000050 CH2:0.0000000000050
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000000050,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000003780,0.18400,0.00400
-0.00000002980,0.20600,0.00800
...
 0.00000013020,0.24000,0.00400
 0.00000013820,0.22800,0.00400
*****
1751	/path/to/ADS00003.CSV
lines 58 /path/to/ADS00003.CSV
Record Length,45
Sample Interval,CH1:0.0000000000200 CH2:0.0000000000200
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000000100,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000008560,0.17000,0.00800
-0.00000007760,0.17200,0.01200
...
 0.00000025840,0.23600,0.01200
 0.00000026640,0.23000,0.01200
*****
3860	/path/to/ADS00004.CSV
lines 126 /path/to/ADS00004.CSV
Record Length,113
Sample Interval,CH1:0.0000000001250 CH2:0.0000000001250
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000000250,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000022000,0.16400,0.00400
-0.00000021200,0.16800,0.00400
...
 0.00000066800,0.23400,0.00800
 0.00000067600,0.23000,0.00400
*****
7332	/path/to/ADS00005.CSV
lines 238 /path/to/ADS00005.CSV
Record Length,225
Sample Interval,CH1:0.0000000005000 CH2:0.0000000005000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000000500,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000044800,0.16000,0.00800
-0.00000044000,0.16400,0.00400
...
 0.00000133600,0.23400,0.00800
 0.00000134400,0.23200,0.01200
*****
14307	/path/to/ADS00006.CSV
lines 463 /path/to/ADS00006.CSV
Record Length,450
Sample Interval,CH1:0.0000000040000 CH2:0.0000000040000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000001000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000090000,0.15800,0.00800
-0.00000089600,0.16000,0.00800
...
 0.00000089200,0.36000,0.01200
 0.00000089600,0.35800,0.01200
*****
73368	/path/to/ADS00007.CSV
lines 2263 /path/to/ADS00007.CSV
Record Length,2250
Sample Interval,CH1:0.0000000020000 CH2:0.0000000020000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000002500,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000225000,0.15800,0.00800
-0.00000220000,0.16200,0.00800
...
 0.00011015000,-0.10600,-0.71200
 0.00011020000,-0.10600,-0.71200
*****
72128	/path/to/ADS00008.CSV
lines 2263 /path/to/ADS00008.CSV
Record Length,2250
Sample Interval,CH1:0.0000000040000 CH2:0.0000000040000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000005000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000450000,0.15800,0.00800
-0.00000449600,0.16000,0.00800
...
 0.00000449200,-0.10600,-0.71200
 0.00000449600,-0.10600,-0.71200
*****
146378	/path/to/ADS00009.CSV
lines 4513 /path/to/ADS00009.CSV
Record Length,4500
Sample Interval,CH1:0.0000000040000 CH2:0.0000000040000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000010000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00000900000,0.15800,0.00800
-0.00000899600,0.16000,0.00800
...
 0.00000899200,-0.10600,-0.71200
 0.00000899600,-0.10600,-0.71200
*****
146378	/path/to/ADS00010.CSV
lines 4513 /path/to/ADS00010.CSV
Record Length,4500
Sample Interval,CH1:0.0000000100000 CH2:0.0000000100000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000025000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00002250000,0.15800,0.00800
-0.00002249000,0.16000,0.00800
...
 0.00002248000,-0.10600,-0.71200
 0.00002249000,-0.10600,-0.71200
*****
294878	/path/to/ADS00011.CSV
lines 9013 /path/to/ADS00011.CSV
Record Length,9000
Sample Interval,CH1:0.0000000100000 CH2:0.0000000100000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000050000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00004500000,0.15800,0.00800
-0.00004499000,0.16000,0.00800
...
 0.00004498000,-0.10600,-0.71200
 0.00004499000,-0.10600,-0.71200
*****
294878	/path/to/ADS00012.CSV
lines 9013 /path/to/ADS00012.CSV
Record Length,9000
Sample Interval,CH1:0.0000000200000 CH2:0.0000000200000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000100000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00008999999,0.15800,0.00800
-0.00008997999,0.16000,0.00800
...
 0.00008996000,-0.10600,-0.71200
 0.00008998000,-0.10600,-0.71200
*****
369129	/path/to/ADS00013.CSV
lines 11263 /path/to/ADS00013.CSV
Record Length,11250
Sample Interval,CH1:0.0000000400000 CH2:0.0000000400000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000250000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00022500000,0.15800,0.00800
-0.00022496000,0.16000,0.00800
...
 0.00022492000,-0.10600,-0.71200
 0.00022496000,-0.10600,-0.71200
*****
369129	/path/to/ADS00014.CSV
lines 11263 /path/to/ADS00014.CSV
Record Length,11250
Sample Interval,CH1:0.0000000800000 CH2:0.0000000800000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0000500000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00045000000,0.15800,0.00800
-0.00044992000,0.16000,0.00800
...
 0.00044984000,-0.10600,-0.71200
 0.00044992000,-0.10600,-0.71200
*****
294878	/path/to/ADS00015.CSV
lines 9013 /path/to/ADS00015.CSV
Record Length,9000
Sample Interval,CH1:0.0000002000000 CH2:0.0000002000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0001000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00090000000,0.15800,0.00800
-0.00089980000,0.16000,0.00800
...
 0.00089960006,-0.10600,-0.71200
 0.00089980006,-0.10600,-0.71200
*****
369129	/path/to/ADS00016.CSV
lines 11263 /path/to/ADS00016.CSV
Record Length,11250
Sample Interval,CH1:0.0000004000000 CH2:0.0000004000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0002500000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00225000016,0.15800,0.00800
-0.00224960016,0.16000,0.00800
...
 0.00224920016,-0.10600,-0.71200
 0.00224960016,-0.10600,-0.71200
*****
369129	/path/to/ADS00017.CSV
lines 11263 /path/to/ADS00017.CSV
Record Length,11250
Sample Interval,CH1:0.0000008000001 CH2:0.0000008000001
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0005000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00450000031,0.15800,0.00800
-0.00449920031,0.16000,0.00800
...
 0.00449840031,-0.10600,-0.71200
 0.00449920031,-0.10600,-0.71200
*****
294878	/path/to/ADS00018.CSV
lines 9013 /path/to/ADS00018.CSV
Record Length,9000
Sample Interval,CH1:0.0000020000002 CH2:0.0000020000002
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0010000001,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.00900000063,0.15800,0.00800
-0.00899800125,0.16000,0.00800
...
 0.00899600063,-0.10600,-0.71200
 0.00899800000,-0.10600,-0.71200
*****
369129	/path/to/ADS00019.CSV
lines 11263 /path/to/ADS00019.CSV
Record Length,11250
Sample Interval,CH1:0.0000040000000 CH2:0.0000040000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0025000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.02249999844,0.15800,0.00800
-0.02249600000,0.16000,0.00800
...
 0.02249199844,-0.10600,-0.71200
 0.02249600000,-0.10600,-0.71200
*****
369129	/path/to/ADS00020.CSV
lines 11263 /path/to/ADS00020.CSV
Record Length,11250
Sample Interval,CH1:0.0000080000000 CH2:0.0000080000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0050000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.04499999688,0.15800,0.00800
-0.04499200000,0.16000,0.00800
...
 0.04498399688,-0.10600,-0.71200
 0.04499200000,-0.10600,-0.71200
*****
294878	/path/to/ADS00021.CSV
lines 9013 /path/to/ADS00021.CSV
Record Length,9000
Sample Interval,CH1:0.0000200000000 CH2:0.0000200000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0100000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.08999999375,0.15800,0.00800
-0.08998000000,0.16000,0.00800
...
 0.08995999375,-0.10600,-0.71200
 0.08998000000,-0.10600,-0.71200
*****
369129	/path/to/ADS00022.CSV
lines 11263 /path/to/ADS00022.CSV
Record Length,11250
Sample Interval,CH1:0.0000400000031 CH2:0.0000400000031
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0250000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.22500001563,0.15800,0.00800
-0.22496001563,0.16000,0.00800
...
 0.22492000000,-0.10600,-0.71200
 0.22496001563,-0.10600,-0.71200
*****
369129	/path/to/ADS00023.CSV
lines 11263 /path/to/ADS00023.CSV
Record Length,11250
Sample Interval,CH1:0.0000800000063 CH2:0.0000800000063
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.0500000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.45000003125,0.15800,0.00800
-0.44992003125,0.16000,0.00800
...
 0.44984000000,-0.10600,-0.71200
 0.44992003125,-0.10600,-0.71200
*****
294878	/path/to/ADS00024.CSV
lines 9013 /path/to/ADS00024.CSV
Record Length,9000
Sample Interval,CH1:0.0002000000156 CH2:0.0002000000156
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.1000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-0.90000006250,0.15800,0.00800
-0.89980006250,0.16000,0.00800
...
 0.89960000000,-0.10600,-0.71200
 0.89980000000,-0.10600,-0.71200
*****
369129	/path/to/ADS00025.CSV
lines 11263 /path/to/ADS00025.CSV
Record Length,11250
Sample Interval,CH1:0.0004000000000 CH2:0.0004000000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.2500000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-2.25000000000,0.15800,0.00800
-2.24960000000,0.16000,0.00800
...
 2.24920000000,-0.10600,-0.71200
 2.24960000000,-0.10600,-0.71200
*****
369129	/path/to/ADS00026.CSV
lines 11263 /path/to/ADS00026.CSV
Record Length,11250
Sample Interval,CH1:0.0008000000000 CH2:0.0008000000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,0.5000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-4.50000000000,0.15800,0.00800
-4.49920000000,0.16000,0.00800
...
 4.49840000000,-0.10600,-0.71200
 4.49920000000,-0.10600,-0.71200
*****
294878	/path/to/ADS00027.CSV
lines 9013 /path/to/ADS00027.CSV
Record Length,9000
Sample Interval,CH1:0.0020000001563 CH2:0.0020000001563
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,1.0000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-9.00000000000,0.15800,0.00800
-8.99800000000,0.16000,0.00800
...
 8.99600000000,-0.10600,-0.71200
 8.99800000000,-0.10600,-0.71200
*****
372255	/path/to/ADS00028.CSV
lines 11263 /path/to/ADS00028.CSV
Record Length,11250
Sample Interval,CH1:0.0040000003125 CH2:0.0040000003125
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,2.5000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-22.50000000000,0.15800,0.00800
-22.49600000000,0.16000,0.00800
...
22.49200000000,-0.10600,-0.71200
22.49600000000,-0.10600,-0.71200
*****
373505	/path/to/ADS00029.CSV
lines 11263 /path/to/ADS00029.CSV
Record Length,11250
Sample Interval,CH1:0.0080000006250 CH2:0.0080000006250
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,5.0000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-45.00000000000,0.15800,0.00800
-44.99200000000,0.16000,0.00800
...
44.98400000000,-0.10600,-0.71200
44.99200000000,-0.10600,-0.71200
*****
298880	/path/to/ADS00030.CSV
lines 9013 /path/to/ADS00030.CSV
Record Length,9000
Sample Interval,CH1:0.0200000000000 CH2:0.0200000000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,10.0000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-90.00000000000,0.15800,0.00800
-89.98000000000,0.16000,0.00800
...
89.96000000000,-0.10600,-0.71200
89.98000000000,-0.10600,-0.71200
*****
380757	/path/to/ADS00031.CSV
lines 11263 /path/to/ADS00031.CSV
Record Length,11250
Sample Interval,CH1:0.0400000000000 CH2:0.0400000000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,25.0000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-225.00000000000,0.15800,0.00800
-224.96000000000,0.16000,0.00800
...
224.92000000000,-0.10600,-0.71200
224.96000000000,-0.10600,-0.71200
*****
383382	/path/to/ADS00032.CSV
lines 11263 /path/to/ADS00032.CSV
Record Length,11250
Sample Interval,CH1:0.0800000000000 CH2:0.0800000000000
Vertical Units,CH1:V CH2:V,,
Vertical Scale,CH1:0.05 CH2:0.10,,
Vertical Offset,CH1:-0.15000 CH2:0.20000,,
Horizontal Units,s,,
Horizontal Scale,50.0000000000,,
Model Number,ADS1202CL+,,
Serial Number,ADS00001121687,,
Software Version,3.01.01.31R16,,

Source,CH1,CH2
Second,Volt,Volt
-450.00000000000,0.15800,0.00800
-449.92000000000,0.16000,0.00800
...
449.84000000000,-0.10600,-0.71200
449.92000000000,-0.10600,-0.71200
*****




