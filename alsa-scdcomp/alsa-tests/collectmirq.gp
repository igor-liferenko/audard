#!/usr/bin/env gnuplot
################################################################################
# collectmirq.gp                                                               #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# script works on gnuplot 4.6 patchlevel 1

reset
clear

# CSV data; must set:
set datafile separator ","

if (! exists("fname")) \
  fname = "collectmirq.csv" ;

set style line 2 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8A2BE2" #"blueviolet", -1
set style line 3 linetype 1 linewidth 1 pointtype 3 linecolor rgb "red"  #playback, 0
set style line 4 linetype 1 linewidth 1 pointtype 3 linecolor rgb "blue" #capture, 1

set palette model RGB maxcolors 2
#set palette defined (2 "#8A2BE2", 3 "red", 4 "blue")
set cbrange [2:4] # avoid possible 'Warning: empty cb range [4:4], adjusting to [3.96:4.04]'; if it happens, redraw in gnuplot wxt messes it up again!
set palette defined (2 "#8A2BE2", 2.9 "red", 3.1 "red", 4 "blue")
unset colorbox


# set clip two makes "drawing and clipping lines between two outrange points"
# default is otherwise noclip two "not drawing lines between two outrange points"
# (more important for animation frames, where there is zoom)
# doesn't seem to work for yerrorbars, though
set clip points
set noclip one
set clip two

set bmargin at screen 0.24
set xtics font ",6" border rotate by -90 left offset 0,screen -0.000

#setxtic(in1,in2,in3) = in1[9:12] . in2 ."-". in3
setxtic(in1,in2,in3) = in1[33:35] . "-" . in1[2:4] . "-" . in1[9:12] . in2 ."-". in3

# to find max number of columns (fields in awk) in line:
# awk -F, '{print NF;}' collectmirq.csv | sort -n -r | head -n 1
# (here gives 26)
# awk -F, '{print NF;}' collectmirqp.csv | sort -n -r | head -n 1
# (here gives 80)
if (! exists("mcol")) \
  mcol=26
if (! exists("ptype")) \
  ptype=1
if (! exists("pltt")) \
  pltt=1

# due to variable number of columns, the below command may complain (but shouldn't)

getcolor(x) = (x<2) ? x+3 : x
getpt(x) = (x<2) ? 1.5 : 0.7
tf = 1.0/44100

# switch var
sw = 0
switch(x) = (sw==0) ? sw=1 : sw=0

# try again
set cbrange [2:4] # if it messes on wxt redraw, will mess up with this command repeated here, as well

# i=4:20:2 -> 4,6,8... loop variable ammount of columns (cheat)
#~ plot for [i=4:20:2] fname using ($0):i:(i+1) with points ls 1 lc variable
#~ plot for [i=4:20:2] fname using ($0):i:(column(i+1)+3) with points ls 1 lc variable notitle
# only pointsize and linecolor accept variable;
# it seems it use of "variable" goes sequentially...
if (pltt==1) {
plot \
0 ls -1 notitle,\
for [i=4:mcol-1:2] fname using ($0):i:(getpt(column(i+1))):(getcolor(column(i+1))):xtic(setxtic(stringcolumn(1),stringcolumn(2),stringcolumn(3))) with points pt ptype ps variable lc variable notitle
}
if (pltt==2) {
plot \
for [i=4:mcol-1:3] fname using ($0):i:(getpt(column(i+1))):(getcolor(column(i+1))):xtic(setxtic(stringcolumn(1),stringcolumn(2),stringcolumn(3))) with points pt 3 ps variable lc variable notitle, \
 for [i=4:mcol-1:3] fname using ($0):i:(column(i)-tf*column(i+2)):i:(getcolor(column(i+1))) with yerrorbars lc variable pt 2 notitle, \
  0 ls -1 notitle
}
if (pltt==3) {
plot \
for [i=4:mcol-1:3] fname using ($0):i:(getpt(column(i+1))):(getcolor(column(i+1))):xtic(setxtic(stringcolumn(1),stringcolumn(2),stringcolumn(3))) with points pt 3 ps variable lc variable notitle, \
 for [i=4:mcol-1:3] fname using ($0):i:(column(i)-tf*column(i+2)):i:(getcolor(column(i+1))) with yerrorbars lc variable pt 2 notitle, \
 for [i=4:mcol-1:3] fname using ($0):i:(stringcolumn(i+2)):(getcolor(column(i+1))) with labels tc palette left offset character 1+switch(sw)*2,0 notitle, \
  0 ls -1 notitle
}

