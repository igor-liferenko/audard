#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

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

is_interactive = 0 # 1 / 0

myfont=""
# new `if` syntax
if (is_interactive == 1) {
  set terminal x11 # press h with window focus to get help
} else {
  set terminal png size 640,640 # 480/3*4 = 640
  set termoption enhanced
  myfont="LMSansDemiCond10-Regular" # LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"
  # cannot do concatenation direct in termoption line, so in separate string
  myfontb="".myfont.", 11"
  set termoption font myfontb
  set output "${filebase}.png"
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

CSV_fn  = 'scope/ADS00003.CSV'    # USB Thumbdrive
TMP_wav_fn = 'scope/tmp_20130020-013902_wav'
acsv_fn = '20130020-013902.csv'   # from attenload tmp_wav
DAV_fn = 'scope/ADS00003.DAV'

dsz=0x4000      # DAV size (16384)16384/2
tsz=900         # tmp_wav/.csv size (900)
csz=225         # CSV size (225)

dtf=4                     # DAV time/index factor (multiplies (int) x position)

set size 1,1
set origin 0,0

_titl1= '.TMP/.csv'
_titl2= '.CSV'
_titl3= '.DAV'

# .CSV: Col 1: min -0.96000, max 2.60000; 2.6+0.96 = 3.56
# .csv: Col 1: min 5, max 183
#~ get_uint8_val(x) = ((x+0.96)/3.56)*200 # no 255, no 127?

# using http://www.sagenb.org/ (or http://www.mathomatic.org/)
# sage: solve([-0.96*x+y==5, 2.6*x+y==183], x, y): [[x == 50, y == 53]]
# inverse:
# sage: solve([5*x+y==-0.96, 183*x+y==2.6], x, y): [[x == (1/50), y == (-53/50)]]
# 8*500m=4; 4/256 = 0.015625; 1/50 = 0.02; 0.02/0.015625 = 1.28 .. ok
get_uint8_val(x) = floor(50*x+53) # no 255, no 127?


__[ adscomp01.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0"

set xrange [] writeback

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(0x4000) format='%uint8' \
  using 0:1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(0x4000) format='%uint8' \
  using 0:1 with linespoints ls 12 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(900) format='%uint8' skip=18944+0x18 \
  using 0:1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(900) format='%uint8' skip=18944+0x18 \
  using 0:1 with linespoints ls 11 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using 0:(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using 0:(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset multiplot



__[ adscomp02.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize"

set xrange [] writeback

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ($0-dsz/2):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ($0-dsz/2):1 with linespoints ls 12 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using ($0-csz/2):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using ($0-csz/2):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset multiplot


__[ adscomp03.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + range by TMP"

set xrange [-tsz/2:tsz/2] writeback

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ($0-dsz/2):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using ($0-dsz/2):1 with linespoints ls 12 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using ($0-csz/2):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using ($0-csz/2):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset multiplot


__[ adscomp04.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + range by TMP"

set xrange [-tsz/2:tsz/2] writeback

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset multiplot


__[ adscomp05.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + range zoom"

set xrange [-100:100] writeback

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title ''

set xrange restore

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset multiplot


__[ adscomp06.gnuplot ]__

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + range zoom2"

set xrange [-20:20] writeback
set xtics 1
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title ''

# using (($0-dsz/2)*dtf-18):1 with linespoints ls 12
# using (($0-csz/2)*dtf+1):(get_uint8_val($2)) with impulses ls 10

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2):1 with impulses ls 11 \
  title '',\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp07.gnuplot ]__

tmove=-1

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + range zoom2"

_titl1= '.TMP/.csv'
_titl2= '.CSV'
_titl3= '.DAV'

set xrange [-20:20] writeback
set xtics 1
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp08.gnuplot ]__

tmove=18

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + range zoom2"

_titl1= '.TMP/.csv'
_titl2= '.CSV'
_titl3= '.DAV'

set xrange [-20:20] writeback
set xtics 1
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp09.gnuplot ]__

tmove=18
cmove=19

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom2"

set xrange [-20:20] writeback
set xtics 1
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp10.gnuplot ]__

tmove=18
cmove=20

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom2"

set xrange [-20:20] writeback
set xtics 1
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp11.gnuplot ]__

tmove=18
cmove=19

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom"

set xrange [-50:50] writeback
set xtics 2
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp12.gnuplot ]__

tmove=18
cmove=20

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom"

set xrange [-50:50] writeback
set xtics 2
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp13.gnuplot ]__

tmove=18
cmove=19

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom"

set xrange [-100:100] writeback
set xtics 5
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp14.gnuplot ]__

tmove=18
cmove=20

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom"

set xrange [-100:100] writeback
set xtics 5
set yrange [155:175] writeback

unset object
set object circle center 8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center -12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center 8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center 8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center -12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp15.gnuplot ]__

tmove=18
cmove=19
oft=100

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom2"

set xrange [oft-100:oft+100] writeback
set xtics 5
set yrange [160:185] writeback

unset object
set object circle center oft+8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft+8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center oft-12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center oft-12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center oft+8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft+8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


__[ adscomp16.gnuplot ]__

tmove=18
cmove=20
oft=100

set multiplot layout 4,1 rowsfirst scale 1.0,1.0 title "all (integer) indexed by col 0 + moved by halfsize + \nDAV/CSV 4*[n] + TMP mv ".tmove." + CSV mv ".cmove." + range zoom2"

set xrange [oft-100:oft+100] writeback
set xtics 5
set yrange [160:185] writeback

unset object
set object circle center oft+8,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft+8,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center oft-12+2+tmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title ''

set xrange restore
set yrange restore
unset object
set object circle center oft-12+cmove,155 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,172 size 0.5 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title _titl2,\
CSV_fn  \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title ''

unset object
set object circle center oft+8,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft+8,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+2+tmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,155 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5
set object circle center oft-12+cmove,172 size 0.2 fillcolor rgb "red" fillstyle transparent solid 0.5

plot zeroline(x) t '' ls 1,\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with linespoints ls 12 \
  title _titl3,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with linespoints ls 11 \
  title _titl1,\
TMP_wav_fn \
  binary record=(tsz) format='%uint8' skip=18944+0x18 \
  using ($0-tsz/2+tmove):1 with impulses ls 11 \
  title '',\
DAV_fn \
  binary record=(dsz) format='%uint8' \
  using (($0-dsz/2)*dtf):1 with impulses ls 12 \
  title _titl3,\
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with impulses ls 10 \
  title _titl2, \
CSV_fn \
  using (($0-csz/2)*dtf+cmove):(get_uint8_val($2)) with linespoints ls 10 \
  title ''

unset multiplot


