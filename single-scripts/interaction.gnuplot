
# in gnuplot terminal, issue:
# load 'interaction.gnuplot'

print ""
print "interaction.gnuplot starting"

set terminal x11

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


# note: Cannot set internal variables GPVAL_ and MOUSE_

# go to x (at center) at current range..
# call with: eval gox(0.0)
gox(x) = sprintf("set xrange [%f:%f]; replot", x-((GPVAL_X_MAX-GPVAL_X_MIN)/2), x+((GPVAL_X_MAX-GPVAL_X_MIN)/2))

# go to y (at center) at current range..
# call with: eval goy(0.0)
goy(y) = sprintf("set yrange [%f:%f]; replot", y-((GPVAL_Y_MAX-GPVAL_Y_MIN)/2), y+((GPVAL_Y_MAX-GPVAL_Y_MIN)/2))

# go to x,y (at center) at current range..
# call with: eval go(0.0,0.0)
go(x,y) = sprintf("set xrange [%f:%f]; set yrange [%f:%f]; replot", x-((GPVAL_X_MAX-GPVAL_X_MIN)/2), x+((GPVAL_X_MAX-GPVAL_X_MIN)/2), y-((GPVAL_Y_MAX-GPVAL_Y_MIN)/2), y+((GPVAL_Y_MAX-GPVAL_Y_MIN)/2))



# define capt & other string variable as sequence
#  of commands, semicolon separated

round(x) = x-int(x)>=0.5?ceil(x):floor(x)

capt = "print 'Saving...' ; set terminal png ; set output 'gnuplot.png' ; replot ; set terminal x11"
pr = 'print sprintf("xrange [%.2f:%.2f] yrange [%.2f:%.2f]", GPVAL_X_MIN, GPVAL_X_MAX, GPVAL_Y_MIN, GPVAL_Y_MAX); print sprintf("xrange [%d:%d] yrange [%d:%d]", floor(GPVAL_X_MIN), ceil(GPVAL_X_MAX), floor(GPVAL_Y_MIN), ceil(GPVAL_Y_MAX))'

print "macros state: "
show macros

print "enabling macros state:"
set macros
show macros

print "The @capt command should be available now."
print "The @pr command should be available now."
print ""
print "interaction.gnuplot ending"
print ""



