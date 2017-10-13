#!/usr/bin/env gnuplot
################################################################################
# ftdi_profiler.gp                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# script works on gnuplot 4.6 patchlevel 1

# call with (from shell; remember - at end instead of persist):
# gnuplot ftdi_profiler.gp -
# gnuplot -e 'fdir=".";' ftdi_profiler.gp -

reset
clear

set clip points
set noclip one
set clip two

if (! exists("fdir")) \
  fdir = '.'

fd = fdir . "/" . "repd.txt" ;
f1 = fdir . "/" . "rep1.txt" ;
f2 = fdir . "/" . "rep2.txt" ;
f2o = fdir . "/" . "rep2o.txt" ;


md=2048 #16384
max1d=system("awk '/max rep1/{print $4; exit}' " . f2o) #220.0 # max play delta
maxd=system("awk '/max repd/{print $4; exit}' " . f2o) #220.0 # max play/capt total delta
print "max1d ", max1d, " maxd ", maxd

#~ plot "rep1.txt" using 1:(int($9)%md) with lines lc rgb "red" t '1', \
#~ "rep1.txt" using 1:(int($9+$10)%md) with lines lc rgb "dark-red" t '1s', \
#~ "rep1.txt" using 1:($10*md/maxd) with linespoints lc rgb "magenta" t '1e', \
#~ "rep2.txt" using 1:(int($9)%md) with lines lc rgb "blue" t '2', \
#~ "repd.txt" using 1:(int($5)%md) with linespoints lc rgb "violet" t 'd', \
#~ "rep2o.txt" using 1:(md) with impulses lc rgb "black" t '2o'


# nb: fillsteps bins on its own, doesn't show exact data on zoom!
# filledcurve fs solid 0.6 is better - but it needs a last point to close the curve! (still problems evn)
# lines unfortunately don't have transparency.
#set yrange [0:maxd]
plot fd using 1:(int($5)%md) with lines lc rgb "violet" t 'd', \
f1 using 1:($10) with lines lc rgb "magenta" t '1e', \
f1 using 1:($10) with points lc rgb "magenta" pt 3 t '1e', \
f1 using 1:($9/$1) with lines lc rgb "red" t '1wbps', \
f2 using 1:($9/$1) with lines lc rgb "blue" t '2rbps', \
f2o using 1:(200000) with impulses lc rgb "black" t '2o'

#~ "repd.txt" using 1:(int($5)%md) with points lc rgb "violet" pt 1 t 'd', \
