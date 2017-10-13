#!/usr/bin/env python

#~ see http://matplotlib.sourceforge.net/api/pyplot_api.html#matplotlib.pyplot.plot for line marker format string characters
#~ for non-filled markers, markerfacecolor='None' (http://www.mail-archive.com/matplotlib-users@lists.sourceforge.net/msg00484.html)

import matplotlib
import pylab as p
import numpy as nx # import matplotlib.numerix as nx # numerix deprecated

ax = p.subplot(111)
canvas = ax.figure.canvas

# lines - not , animated=True
# line marker 'o-'
yline = 0
clr = "blue" #~ "#FFA2A2"
period_line = ax.plot([3,4],[yline,yline],'o-', color=clr)
period_line_annot = ax.annotate("4", xy=(4, yline), ha="right", bbox=dict(boxstyle="round", fc="0.8"), color=clr,)

#ax.draw() #TypeError: draw_wrapper() takes at least 2 arguments (1 given)
p.show() # should block, and 'start the graphics update thread'

