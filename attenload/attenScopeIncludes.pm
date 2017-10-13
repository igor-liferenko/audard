#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

use 5.10.1;
use warnings;
use strict;

# declare
our $adsFactor;
our %timediv_srate_map;
our %timediv_sint_map;
our $scope_hdivs; # 18
our $scope_vdivs; # 8
our %timediv_move_map;
our %timediv_length_map;

our @tdiva;
# for .ssf (device settings) parsing:
our (@ssf_trigsrca , @ssf_trigtypa , @ssf_probestga , @ssf_probestia , @ssf_trigedgeslopa , @ssf_couplinga , @ssf_chvdiva , @ssf_trigmodea , @ssf_trigcpla , @ssf_trigpulsewhena , @ssf_trigvidpola , @ssf_trigvidsynca , @ssf_filtypa , @ssf_trigvidstda , @ssf_trigslopeverta , @ssf_trigslopewhena , @ssf_trigslopetimea);

# Data from Atten ADS1202CL+ oscilloscope

# $adsFactor found by bruteforce (see comments in adscompare.pl)
# ADS voltage scale factor
# was 0.78125; now 1/0.78125 = 1.28
$adsFactor = 1.28;

$scope_hdivs=18;
$scope_vdivs=8;

# map between time/DIV and sample rates on (ADS1202CL+) scope
# via Acquire: SaRate infobox on scope (ovserve when changing time/DIV [S/Div] switch)
# [0] - time/div, real, s; [1] - sampling rate, real, Hz(Sa/s)
# assoc array - with %a; called with $a{50}
# note: this is declared sampled rate for two channels (commented - sample rate for one channel [ch2 turned of from its button]); but it depends, sorta?
%timediv_srate_map = (
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

# however, this seems more important:
# timediv versus Sampling Interval written in scope .CSV (ADS1202CL+)
# it changes somewhat strangely according to the rates above!
# [0] - time/div, real, s; [1] - sampling interval, real, s
%timediv_sint_map = (
  # ADS00001:                  len:    12 ( 67692.308)
  2.5e-9, 0.0000000000013 ,    # (3.75e-9)(  7.33e-9)  250M/ 266.7M,[769.23G]
  # ADS00002:                  len:    23 ( 35200    )
    5e-9, 0.0000000000050 ,    # (3.91e-9)(  7.65e-9)  250M/ 255.6M,[   200G]
  # ADS00003:                  len:    45 ( 17600    )
   10e-9, 0.0000000000200 ,    # (   4e-9)(  7.82e-9)  250M/   250M,[    50G]
  # ADS00004:                  len:   113 (  7168    )
   25e-9, 0.0000000001250 ,    # (3.98e-9)(  7.92e-9)  250M/ 251.1M,[     8G]
  # ADS00005:                  len:   225 (  3584    )
   50e-9, 0.0000000005000 ,    # (   4e-9)(  7.96e-9)  250M/   250M,[     2G]
  # ADS00006:                  len:   450 (   449    )
  100e-9, 0.0000000040000 ,    # (   4e-9)(  3.99e-9)  250M/   250M,[   250M]
  # ADS00007:                  len:  2250 ( 56225    )
  250e-9, 0.0000000020000 ,    # (   2e-9)( 49.97e-9)  250M/   500M,[   500M]
  # ADS00008:                  len:  2250 (  2249    )
  500e-9, 0.0000000040000 ,    # (   4e-9)(  3.99e-9)  250M/   250M,[   250M]
  # ADS00009:                  len:  4500 (  4499    )
    1e-6, 0.0000000040000 ,    # (   4e-9)(  3.99e-9)  250M/   250M,[   250M]
  # ADS00010:                  len:  4500 (  4499    )
  2.5e-6, 0.0000000100000 ,    # (  10e-9)(  9.99e-9)  100M/   100M,[   100M]
  # ADS00011:                  len:  9000 (  8999    )
    5e-6, 0.0000000100000 ,    # (  10e-9)(  9.99e-9)  100M/   100M,[   100M]
  # ADS00012:                  len:  9000 (  8998.999)
   10e-6, 0.0000000200000 ,    # (  20e-9)( 19.99e-9)   50M/    50M,[    50M]
  # ADS00013:                  len: 11250 ( 11249    )
   25e-6, 0.0000000400000 ,    # (  40e-9)( 39.99e-9)   25M/    25M,[    25M]
  # ADS00014:                  len: 11250 ( 11249    )
   50e-6, 0.0000000800000 ,    # (  80e-9)( 79.99e-9) 12.5M/  12.5M,[  12.5M]
  # ADS00015:                  len:  9000 (  8999    )
  100e-6, 0.0000002000000 ,    # ( 200e-9)(199.97e-9)    5M/     5M,[     5M]
  # ADS00016:                  len: 11250 ( 11249.001)
  250e-6, 0.0000004000000 ,    # ( 400e-9)(399.96e-9)  2.5M/   2.5M,[   2.5M]
  # ADS00017:                  len: 11250 ( 11248.999)
  500e-6, 0.0000008000001 ,    # ( 800e-9)(799.92e-9) 1.25M/   1.5M,[  1.24M]
  # ADS00018:                  len:  9000 (  8998.999)
    1e-3, 0.0000020000002 ,    # (   2e-6)(  1.99e-6)  500k/   500k,[499.99k]
  # ADS00019:                  len: 11250 ( 11249    )
  2.5e-3, 0.0000040000000 ,    # (   4e-6)(  3.99e-6)  250k/   250k,[   250k]
  # ADS00020:                  len: 11250 ( 11249    )
    5e-3, 0.0000080000000 ,    # (   8e-6)(  7.99e-6)  125k/   125k,[   125k]
  # ADS00021:                  len:  9000 (  8999    )
   10e-3, 0.0000200000000 ,    # (  20e-6)( 19.99e-6)   50k/    50k,[    50k]
  # ADS00022:                  len: 11250 ( 11249    )
   25e-3, 0.0000400000031 ,    # (  40e-6)( 39.99e-6)   25k/    25k,[ 24.99k]
  # ADS00023:                  len: 11250 ( 11249    )
   50e-3, 0.0000800000063 ,    # (  80e-6)( 79.99e-6) 12.5k/  12.5k,[ 12.49k]
  # ADS00024:                  len:  9000 (  8999    )
  100e-3, 0.0002000000156 ,    # ( 200e-6)(199.97e-6)   25k/     5k,[  4.99k]
  # ADS00025:                  len: 11250 ( 11249    )
  250e-3, 0.0004000000000 ,    # ( 400e-6)(399.96e-6)   10k/   2.5k,[   2.5k]
  # ADS00026:                  len: 11250 ( 11249    )
  500e-3, 0.0008000000000 ,    # ( 800e-6)(799.92e-6)    5k/   1.5k,[  1.25k]
  # ADS00027:                  len:  9000 (  8998.999)
       1, 0.0020000001563 ,    # (   2e-3)(  1.99e-3)  2.5k/    500,[ 499.99]
  # ADS00028:                  len: 11250 ( 11248.999)
     2.5, 0.0040000003125 ,    # (   4e-3)(  3.99e-3)    1k/    250,[ 249.99]
  # ADS00029:                  len: 11250 ( 11248.999)
       5, 0.0080000006250 ,    # (   8e-3)(  7.99e-3)   500/    125,[ 124.99]
  # ADS00030:                  len:  9000 (  8999    )
      10, 0.0200000000000 ,    # (  20e-3)( 19.99e-3)   250/     50,[     50]
  # ADS00031:                  len: 11250 ( 11249    )
      25, 0.0400000000000 ,    # (  40e-3)( 39.99e-3)   100/     25,[     25]
  # ADS00032:                  len: 11250 ( 11249    )
      50, 0.0800000000000      # (  80e-3)( 79.99e-3)    50/   12.5,[   12.5]
);


# since I cannot find a good formula for Cmove/Dmove
# (in adscompare);
# will tune them manually - and enter them in this dict
# as strings/formulas - so can use $osf and such in them
# note: for 500ns, there is some weird displacements of cmove
#  in respect to bitmap overlay (not getting the same for 250ns/div)
#  apparently related to Vmax/Vtrigger - but reading the data
#  for trigger, doesn't help much - so unsolved..
%timediv_move_map = (
  "TDIV"    , ["Dmove"     , "Cmove",   , "cmove",  "csvi_offs_ch2"],
  50        , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # TODO: CHECK (just a guess, not checked with captures!)
  25        , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # TODO: CHECK (just a guess, not checked with captures!)
  10        , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # TODO: CHECK (just a guess, not checked with captures!)
   5        , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # TODO: CHECK (just a guess, not checked with captures!)
   2.50     , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1, u: 4.00000031)
   1        , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1, u: 5.00000039)
   500e-3   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1, u:4)
   250e-3   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1, u:4)
   100e-3   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1, u:5)
    50e-3   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1)
    25e-3   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
    10e-3   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
     5e-3   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1)
   2.5e-3   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
     1e-3   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
   500e-6   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1)
   250e-6   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
   100e-6   , ['-1*$osf-11', '1*$osf-9', -164,      '-($osf-1)'] ,    # Dmove -12, Cmove -8 (osf 1)
    50e-6   , ['-1*$osf-11', '1*$osf-10', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -9 (osf 1)
    25e-6   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1)
    10e-6   , ['-1*$osf-11', '1*$osf-10', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -9 (osf 1)
     5e-6   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1)
   2.5e-6   , ['-1*$osf-11', '1*$osf-11', -164,     '-($osf-1)'] ,   # Dmove -12, Cmove -10 (osf 1) (once here and above (full 16000 samples for .csv), csv needs move too (tfoi) of -164)
     1e-6   , ['-1*$osf+2', '1*$osf-1', 0,          '-($osf-1)'] ,   # Dmove 1, Cmove 0 (osf 1)
   500e-9   , ['-1*$osf+3', '1*$osf-1', 16,          '-($osf-1)'] ,   # Dmove 2, Cmove 0 (osf 1)
   250e-9   , ['-2*$osf+5', '1*$osf+1123', 0,       '-($osf-1)'] ,# Dmove 1, Cmove 1125 (osf 2) /special
   100e-9   , ['-1*$osf+2', '1*$osf-1', 0,          '-($osf-1)'] ,   # Dmove 1, Cmove 0 (osf 1)
    50e-9   , ['-2*$osf-5', '1*$osf-2', 0,          '-($osf-1)'] ,   # Dmove -13, Cmove 2 (osf 4)
    25e-9   , ['-2*$osf-3', '1*$osf-2', 0,          '-($osf-1)'] ,   # Dmove -19, Cmove 6 (osf 8)
    10e-9   , ['-2*$osf+8', '1*$osf-6', 0,          '-($osf)'] ,   # Dmove -32, Cmove 14 (osf 20) (+ ch2)
     5e-9   , ['-2*$osf-30', '1*$osf+3', 0,         '-($osf)'] ,  # Dmove -110, Cmove 43 (osf 40) (+ ch2)
   2.5e-9   , ['-2*$osf-31', '1*$osf-12', 0,        '-($osf-1)']   # Dmove -191, Cmove 68 (osf 80)
);

%timediv_length_map = (
  "TDIV"  ,  ["CSVlen", "csv len",  "osf"],
  2.5e-9  ,  [12,       900,        80],
    5e-9  ,  [23,       900,        40],
   10e-9  ,  [45,       900,        20],
   25e-9  ,  [113,      900,        8],
   50e-9  ,  [225,      900,        4],
  100e-9  ,  [450,      450,        1],
  250e-9  ,  [2250,     2250,       2],
  500e-9  ,  [2250,     2250,       1],
    1e-6  ,  [4500,     4500,       1],
  2.5e-6  ,  [4500,     16000,      1.0],
    5e-6  ,  [9000,     16000,      1.0],
   10e-6  ,  [9000,     16000,      1.0],
   25e-6  ,  [11250,    16000,      1.0],
   50e-6  ,  [11250,    16000,      1.0],
  100e-6  ,  [9000,     16000,      1.0],
  250e-6  ,  [11250,    16000,      1.0],
  500e-6  ,  [11250,    16000,      1.0],
    1e-3  ,  [9000,     16000,      1.0],
  2.5e-3  ,  [11250,    16000,      1.0],
    5e-3  ,  [11250,    16000,      1.0],
   10e-3  ,  [9000,     16000,      1.0],
   25e-3  ,  [11250,    16000,      1.0],
   50e-3  ,  [11250,    16000,      1.0],
  100e-3  ,  [9000,     16000,      1.0],
  250e-3  ,  [11250,    16000,      1.0],
  500e-3  ,  [11250,    16000,      1.0],
    1     ,  [9000,     16000,      1.0],
  2.5     ,  [11250,    16000,      1.0],
    5     ,  ['N/A',    'N/A',      'N/A'],   # TODO
   10     ,  ['N/A',    'N/A',      'N/A'],   # TODO
   25     ,  ['N/A',    'N/A',      'N/A'],   # TODO
   50     ,  ['N/A',    'N/A',      'N/A']    # TODO
);

# all T/DIV settings array
# (as for .ssf - moved start from index [0] to [1])
@tdiva = ("",
  2.5e-9  ,
    5e-9  ,
   10e-9  ,
   25e-9  ,
   50e-9  ,
  100e-9  ,
  250e-9  ,
  500e-9  ,
    1e-6  ,
  2.5e-6  ,
    5e-6  ,
   10e-6  ,
   25e-6  ,
   50e-6  ,
  100e-6  ,
  250e-6  ,
  500e-6  ,
    1e-3  ,
  2.5e-3  ,
    5e-3  ,
   10e-3  ,
   25e-3  ,
   50e-3  ,
  100e-3  ,
  250e-3  ,
  500e-3  ,
    1     ,
  2.5     ,
    5     ,
   10     ,
   25     ,
   50
);

# for .ssf (device settings) parsing:
@ssf_trigsrca = ("CH1", "CH2", "EXT", "EXT/5", "AC Line");
@ssf_trigtypa = ("Edge", "Pulse", "Video", "Slope", "Alternative");
@ssf_probestga = ("1X", "5X", "10X", "50X", "100X", "ISFE", "500X", "1000X");
@ssf_probestia = (1, 5, 10, 50, 100, 200, 500, 1000);
@ssf_trigedgeslopa = ("Up", "Down", "UpDown");
@ssf_couplinga = ("DC", "AC", "GND" );
@ssf_chvdiva = ("Coarse", "Fine" );
@ssf_trigmodea = ("Auto", "Normal", "Single" );
@ssf_trigcpla = ("DC", "AC", "HFReject", "LFReject" );
@ssf_trigpulsewhena = ("P<", "P>", "P=", "IP<", "IP>", "IP=");
@ssf_trigvidpola = ("Up", "Down");
@ssf_trigvidsynca = ("AllLines", "LineNum", "OddField", "EvenField");
@ssf_filtypa = ("low-pass", "high-pass", "band-pass", "band-reject" );
@ssf_trigvidstda = ("Pal/Secam", "NTSC");
@ssf_trigslopeverta = ("Top", "Bottom", "Both");
@ssf_trigslopewhena = ("R>", "R<", "R=", "F>", "F<", "F=" );
@ssf_trigslopetimea = (0, 1e-9, 1e-6, 1e-3, 1e0, 1e3);





# .pm (module) must return 1?
1;
