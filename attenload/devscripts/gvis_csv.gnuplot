
# Part of the attenload package
#
# Copyleft 2012, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

# DON'T FORGET to remove any binary data from .dat files
# (handled in perl scripts)

# default pdf terminal is 5in x 3in
set terminal pdf # size 5,3

# if lots of data, for widened size and smaller font:
#~ set terminal pdf size 10,3
#~ set xtics font "Helvetica,6"

set output 'gvis_csv.pdf'
set datafile separator ","


# better set y range explicitly, as it has no meaning here
# ... but we can still use it to position text/etc
set yrange [0:6]


# set axis label
set xlabel "t [ms]" offset 0.0,1.0

# for this plot, xticks at 100 ms - and minor xticks @10ms!
set xtics 100
set mxtics 10

# gnuplot variables; replaced by prep_csv_gvis.sh
TIMEOFFSA=458267
TIMEOFFSB=32293
INDXOFFSA=4
INDXOFFSB=0


# functions for providing formatted data to columns
myarrYpos(colref) = (strcol(colref) eq ">>>") ? 2 : 3     # returns number!
myarrYpos2(colref) = (strcol(colref) eq ">>>") ? 4 : 5     # returns number!
myarrlablMod(collab,colpos,offs) = (strcol(collab) eq ">>>") ? (sprintf(">%d",column(colpos)-offs)) : (sprintf("<%d",column(colpos)-offs))  # returns string!
myarrlabl(collab,colpos) = (strcol(collab) eq ">>>") ? (sprintf(">%d",column(colpos))) : (sprintf("<%d",column(colpos)))  # returns string!


# color specified by linestyles (ls)
set style line 1 lt 1 linecolor rgb "red"
set style line 2 lt 2 linecolor rgb "green"


# plot both 'vis_usbsnoop.csv' and 'vis_usbmon.csv' datasets on the same graph

plot 'vis_usbsnoop.csv' using ($1-TIMEOFFSA):($3-INDXOFFSA) with points notitle, \
"" using ($1-TIMEOFFSA):(myarrYpos(5)):(myarrlablMod(5,3,INDXOFFSA)) with labels textcolor ls 1 left rotate notitle, \
"" using ($1-TIMEOFFSA):(myarrYpos(5)) with impulses lt 1 linewidth 2 notitle, \
\
'vis_usbmon.csv' using ($1-TIMEOFFSB):($3-42) with points notitle, \
"" using ($1-TIMEOFFSB):(myarrYpos2(5)):(myarrlablMod(5,3,INDXOFFSB)) with labels textcolor ls 2 left rotate notitle, \
"" using ($1-TIMEOFFSB):(myarrYpos2(5)) with impulses lt 2 linewidth 2 notitle



