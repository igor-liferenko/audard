#!/usr/bin/env perl

# ./
# note: . and - cannot be part of package name!
# package - because of Data::Section...
BEGIN {@ARGV=map glob, @ARGV};
package _adscompare_multifile_pl;

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

#~ use Data::Section -setup; # install Data::Section

# to have hashes of Data::Section in order of appearance:
use Tie::IxHash;


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


# ====================
# do manually without Data::Section, Data::Section::Simple or Inline::Files

# Tie::IxHash will guarantee iterating hash
# in "order of appearance" without need
# for explicit sorting
tie my %sections, "Tie::IxHash"
  or die "could not tie %sections";

my @array = <DATA>;
my $content = join '', @array;
$content =~ s/^.*\n__DATA__\n/\n/s; # for win32
$content =~ s/\n__END__\n.*$/\n/s;
my @data = split /^__\[\s+(.+?)\s*\]__\r?\n/m, $content;
shift @data; # trailing whitespaces

while (@data) {
  my ($name, $content) = splice @data, 0, 2;
  #print $name."\n";
  $sections{$name} = $content;
}
# ====================



my ($preamble,$epreamble,$filebase)=("")x3;

for my $filename (keys %sections) {
  if ($filename eq "preamble") {
    printf "Got %s\n", $filename ; #, $sections{$filename};
    $preamble = $sections{$filename};
  } else {
    printf "Outputting %s\n", $filename ; #, $sections{$filename};
    my ($ofh,$content);
    open($ofh,'>',$filename) or die "Cannot open $filename for write ($!)";
    # get filebase
    ($filebase = $filename) =~ s/.gnuplot//;
    # expand preamble variables (filebase)
    ($epreamble = $preamble) =~ s/(\${\w+})/${1}/eeg;
    # get content
    $content = $sections{$filename};
    # save to file
    print { $ofh } $epreamble;
    print { $ofh } $content;
    close($ofh);

    print "Running gnuplot $filename\n";
    my $gpstatus = system("gnuplot", "$filename");
    if (($gpstatus >>=8) != 0) {
        die "Failed to run gnuplot!";
    }
  }
}





__DATA__

__[ preamble ]__

#~ set terminal x11
set terminal png truecolor

set datafile separator ","

# scope screen(shot) properties
tdiv = 50e-9          # T/DIV (50e-9)
toffs = 200e-9        # time offset (scope) (200e-9)
vdiv1 = 500e-3        # V/DIV CH1 (500e-3)
voffs1 = -1.5         # volt offset CH1 (-1.5)
sampintp = 500e-12    # (500e-12)
sampintf = 1/sampintp
sratacqf = 250e6      # (250e6)
sratacqp = 1/sratacqf

# (edges of current capture and divisions)
scope_hdiv=18
scope_vdiv=8
scope_trange = scope_hdiv*tdiv        # (900e-9)
scope_left=toffs-(scope_trange/2)     # (-250e-9)
scope_right=toffs+(scope_trange/2)    # (650e-9)
scope_bottom=-voffs1-(scope_vdiv*vdiv1/2) # -500e-3
scope_top=-voffs1+(scope_vdiv*vdiv1/2)    # 3.5

set style fill transparent solid 0.50 noborder # must noborder!
# transparent fill cannot overlay bitmap!
# only bitmap w/ rgbalpha can overlay!

dsz=0x4000      # DAV size (16384)16384/2
tsz=900         # tmp_wav/.csv size (900)
csz=225         # CSV size (225)
tmove=18
cmove=19
dtf=4                     # DAV time/index factor (multiplies (int) x position)

CSV_fn  = 'scope/ADS00003.CSV'    # USB Thumbdrive
TMP_wav_fn = 'scope/tmp_20130020-013902_wav'
acsv_fn = '20130020-013902.csv'   # from attenload tmp_wav
DAV_fn = 'scope/ADS00003.DAV'

_titl1= '.TMP/.csv'
_titl2= '.CSV'
_titl3= '.DAV'

set output "${filebase}.png"


__[ align01.gnuplot ]__

set title "BMP (func match) vs acsv"

plot \
acsv_fn \
  using ($4-200e-9-26e-9):($5) with boxes  \
  title 'acsv',\
'_TEST.bmp' binary array=(480,234) skip=54 format='%uchar' \
  dx=2.015e-9 dy=0.0202 origin=(-2.60e-7,-0.92) \
  using 1:2:3:(150) \
  with rgbalpha t ''
# dx=2.05e-9 dy=0.02 origin=(-2.7e-7,-1) # must be before `using`



__[ align02.gnuplot ]__

set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1 format "%.s%c" font "Helvetica,9"
set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back linecolor rgb "magenta"

set title "BMP (grid match) vs acsv, ($4-200e-9-26e-9-25e-9)"

plot \
acsv_fn \
  using ($4-200e-9-26e-9-25e-9):($5) with boxes  \
  title 'acsv',\
'_TEST.bmp' binary array=(480,234) skip=54 format='%uchar' \
  dx=2.000e-9 dy=0.02005 origin=(-2.8e-7,-0.88) \
  using 1:2:3:(150) \
  with rgbalpha t ''
# dx=2.05e-9 dy=0.02 origin=(-2.7e-7,-1) # must be before `using`


__[ align03.gnuplot ]__

set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1 format "%.s%c" font "Helvetica,9"
set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back linecolor rgb "magenta"

# size of bitmap: 480 × 234 pixels
# seems actual plot in screenshot bitmap is at: 451x201+15+14
# check in gimp: the same: 451x201+15+14
# aspect ratio y (y-axis length to the x-axis length): 201/451 = 0.445676
# ($4-200e-9-26e-9-25e-9) strangely maps to:
# (($0-tsz/2+tmove)*1e-9+200e-9-18e-9)
# so tmove compensates itself in case of TMP!

set size ratio 0.445676
set title "BMP (grid match) vs acsv, (($0-tsz/2+tmove)*1e-9+200e-9-18e-9)"

plot \
acsv_fn \
  using (($0-tsz/2+tmove)*1e-9+200e-9-18e-9):($5) with boxes  \
  title 'acsv',\
'_TEST.bmp' binary array=(480,234) skip=54 format='%uchar' \
  dx=2.000e-9 dy=0.02005 origin=(-2.8e-7,-0.88) \
  using 1:2:3:(150) \
  with rgbalpha t ''
# dx=2.05e-9 dy=0.02 origin=(-2.7e-7,-1) # must be before `using`


__[ align04.gnuplot ]__

set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1 format "%.s%c" font "Helvetica,9"
set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back linecolor rgb "magenta"


# size of bitmap: 480 × 234 pixels
# seems actual plot in screenshot bitmap is at: 451x201+15+14
# check in gimp: the same: 451x201+15+14
# aspect ratio y (y-axis length to the x-axis length): 201/451 = 0.445676
# ($4-200e-9-26e-9-25e-9) strangely maps to:
# (($0-tsz/2+tmove)*1e-9+200e-9-18e-9)
# so tmove compensates itself in case of TMP!
# also CSV doesn't seem to need cmove!

#~ show size
#size is scaled by 1,1
#No attempt to control aspect ratio

set size ratio 0.445676
#~ show size
#size is scaled by 1,1
#Try to set aspect ratio to 0.445676:1.0

#~ set size noratio
#~ show size
#size is scaled by 1,1
#No attempt to control aspect ratio


set title "BMP (grid match) vs acsv(TMP), DAV, CSV"
get_uint8_val(x) = floor(50*x+53) # no 255, no 127?
#~ get_real_val(x) = (1/50)*x+(-53/50) # this doesn't work ?!
#~ get_real_val(x) = (x*(1/50)+(-53/50)) # neither does this??!
#~ get_real_val(x) = 0.02*x-1.06 # ok
#~ get_real_val(x) = x*1/50+(-53/50) # but this does ???!
get_real_val(x) = x*1/51+(-53/50) # better with 51

# '_TEST.bmp' binary array=(480,234) skip=54 format='%uchar' \
# in the composite .bmp, screenshot is at
# display -crop 480x234+10+10 20130020-013902.png
# that's ((x=10)*rowwidth+(y=10))*(rgb=3) byte offset
# '20130020-013902.png' binary array=(480,234) skip=54 format='%uchar' \
# but png cannot be read directly :(
# so '<convert -crop 480x234+10+10 20130020-013902.png bmp:-'

plot \
acsv_fn \
  using (($0-tsz/2+tmove)*1e-9+200e-9-18e-9):($5) with boxes  \
  title 'acsv',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf*1e-9+200e-9-18e-9):(get_real_val($1)) with boxes fs transparent solid 0.40 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf*1e-9+200e-9+1e-9):($2) with boxes fs transparent solid 0.40 \
  title _titl2, \
'<convert -crop 480x234+10+10 "20130020-013902.png" bmp:-' \
  binary array=(480,234) skip=54 format='%uchar' \
  dx=2.000e-9 dy=0.02005 origin=(-2.8e-7,-0.88) \
  using 1:2:3:(150) \
  with rgbalpha t ''
# dx=2.05e-9 dy=0.02 origin=(-2.7e-7,-1) # must be before `using`



