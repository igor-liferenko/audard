#!/usr/bin/env gnuplot

# to run: run `gnuplot` from command line,
# and from gnuplot prompt (remember double quotes):
# load "basictest.gnuplot"

# also can call: gnuplot basictest.gnuplot
# or note: with a shebang, could also chmod +x basictest.gnuplot
#          and call: ./basictest.gnuplot
# but in that case: if output is plain windows,
# (no file - terminal 'wxt'), then script will just exit!

# first, specify the data 'inline' in the gnuplot script
# (so we don't type a separate file)
# "set table" allows to "plot" into a table (http://gnuplot-tricks.blogspot.com/2010/01/further-new-features-in-gnuplot-44.html)
# "plot '-'" will accept data from stdin to plot (http://www.gnuplot.info/docs_4.0/gnuplot.html)
# (e to end plot '-')
# don't forget 'unset table' at end - else subsequent plots won't run!
# unfortunately, set table + plot seems to accept only first two columns, and strips rest
# (that can be seen through !less ./inline.dat in gnuplot prompt)
# use a shell call to generate the file

print "Generating data..."

# reset
# set table 'inline.dat'
# plot '-'
# 10.0 1 a 2
# 10.2 2 b 2
# 10.4 3 a 2
# 10.6 4 b 2
# 10.8 4 c 10
# 11.0 4 c 20
# e
# unset table

# !cat exits immediately, the other lines cause errors
#!cat > inline.dat <<"EOF"
#10.0 1 a 2
#10.2 2 b 2
#10.4 3 a 2
#10.6 4 b 2
#10.8 4 c 10
#11.0 4 c 20
#EOF

#shell # just spawns here directly
#cat > inline.dat <<"EOF"
#10.0 1 a 2
#10.2 2 b 2
#10.4 3 a 2
#10.6 4 b 2
#10.8 4 c 10
#11.0 4 c 20
#EOF
#exit

# to specify data inline in script:
# only system can work, as it is quoted;
# but still have to escape newlines!

system "cat > ./inline.dat <<EOF\n\
10.0 1 a 2\n\
10.2 2 b 2\n\
10.4 3 a 2\n\
10.6 4 b 2\n\
10.8 4 c 10\n\
11.0 4 c 20\n\
EOF\n"

print "done generating."


# set ranges
set yrange [0:30]
set xrange [0:4]

# define line styles - can call them up later
set style line 1 linetype 1 linewidth 3 pointtype 3 linecolor rgb "red"
set style line 2 linetype 1 linewidth 2 pointtype 3 linecolor rgb "green"
set style line 3 linetype 1 linewidth 2 pointtype 3 linecolor rgb "blue"

# interaction - bind keys (help bind)
# Gnuplot good for interactive graphing? - comp.graphics.apps.gnuplot | Google Groups - http://groups.google.com/group/comp.graphics.apps.gnuplot/browse_thread/thread/65ebdbd20318f553
# normal move
bind 'Left' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN-dx/10:GPVAL_X_MAX-dx/10]; replot'
bind 'Right' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN+dx/10:GPVAL_X_MAX+dx/10]; replot'
bind 'Up' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN-dy/10:GPVAL_Y_MAX-dy/10]; replot'
bind 'Down' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN+dy/10:GPVAL_Y_MAX+dy/10]; replot'
# nudge move - alt
bind 'alt-Left' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN-dx/100:GPVAL_X_MAX-dx/100]; replot'
bind 'alt-Right' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN+dx/100:GPVAL_X_MAX+dx/100]; replot'
bind 'alt-Up' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN-dy/100:GPVAL_Y_MAX-dy/100]; replot'
bind 'alt-Down' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN+dy/100:GPVAL_Y_MAX+dy/100]; replot'
# zoom per axis - ctrl
bind 'ctrl-Left' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN-dx/10:GPVAL_X_MAX+dx/10]; replot'
bind 'ctrl-Right' 'dx=GPVAL_X_MAX-GPVAL_X_MIN; set xrange [GPVAL_X_MIN+dx/10:GPVAL_X_MAX-dx/10]; replot'
bind 'ctrl-Up' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN-dy/10:GPVAL_Y_MAX+dy/10]; replot'
bind 'ctrl-Down' 'dy=GPVAL_Y_MAX-GPVAL_Y_MIN; set yrange [GPVAL_Y_MIN+dy/10:GPVAL_Y_MAX-dy/10]; replot'


# offset the X axis: instead of 1:2, use: ($1-10):2
# to "mix", use "" for last datset - but must also repeat the "using"!
# ... and plot:

plot 'inline.dat' using ($1-10):2 with impulses linestyle 1,\
     "" using ($1-10):2 notitle with points linestyle 1,\
     "" using ($1-10):2 notitle with lines linestyle 2,\
     'inline.dat' using ($1-10):4 with impulses linestyle 3,\
     "" using ($1-10):4 notitle with points linestyle 3

# below just for saving file
# MUST be commented if only doing wxt window interaction
#set terminal png
#set output 'basictest.png'
#replot

