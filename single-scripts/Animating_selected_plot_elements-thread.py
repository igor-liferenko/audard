#!/usr/bin/env python 

# this is the example from http://www.scipy.org/Cookbook/Matplotlib/Animations#head-3d51654b8306b1585664e7fe060a60fc76e5aa08
# rewritten so it uses threads.. 

# http://www.pygtk.org/pygtk2reference/gobject-functions.html#function-gobject--idle-add: "If callback returns FALSE it is automatically removed from the list of event sources and will not be called again."
# http://mail.python.org/pipermail/tutor/2001-June/006702.html: "Python doesn't provide a way to stop threads. Python doesn't support it (for good reasons), so we have to simulate it ourselves."
# http://www.jejik.com/articles/2007/01/python-gstreamer_threading_and_the_main_loop/ 
# http://esclab.tw/wiki/index.php/Matplotlib#Asynchronous_plotting_with_threads_and_the_Tkinter_GUI_toolkit


import sys
import gtk, gobject
import matplotlib
matplotlib.use('GTKAgg')
import pylab as p
import numpy as nx # import matplotlib.numerix as nx # numerix deprecated
import time

import threading # threads


# No need for p.ion()/ioff() here...

ax = p.subplot(111)
canvas = ax.figure.canvas

# for profiling
tstart = time.time()

# create the initial line
x = nx.arange(0,2*nx.pi,0.01)
line, = ax.plot(x, nx.sin(x), animated=True)

# save the clean slate background -- everything but the animated line
# is drawn and saved in the pixel buffer background
background = canvas.copy_from_bbox(ax.bbox)


# just a plain global var to pass data (from main, to plot update thread)
global mypass

# instead of another global variable, we can use pipe
# to exchange data between threads
# http://docs.python.org/library/multiprocessing.html#pipes-and-queues
from multiprocessing import Pipe
global pipe1main, pipe1upd
pipe1main, pipe1upd = Pipe()


# the kind of processing we might want to do in a main() function,
# will now be done in a "main thread" - so it can run in
# parallel with gobject.idle_add(update_line)
def threadMainTest():
	global mypass
	global runthread
	global pipe1main
	
	print "tt"
	
	interncount = 1
	
	while runthread: # just while 1: cannot, must tell this loop somehow to exit
		#~ update_line.cnt += 1	# actually, there is access to .cnt directly from here 
								# (even though, for me, previous tests  failed to change this var ?!) 
		mypass += 1
		if mypass > 100: # start "speeding up" animation, only after 100 counts have passed
			interncount *= 1.03
		pipe1main.send(interncount)
		time.sleep(0.01)
	return


# main plot / GUI update
def update_line(*args):
	global mypass
	global t0
	global runthread
	global pipe1upd
	
	if not runthread:
		return False 	# we must have this return False, else this function 
						# will block sys.exit(0) - and will NEVER exit!! 
						
	# get value from pipe
	if pipe1upd.poll():	# check first if there is anything to receive
		myinterncount = pipe1upd.recv()
	
	# get value from global var (comment to test direst update of .cnt from main thread)
	update_line.cnt = mypass
	
	# restore the clean slate background
	canvas.restore_region(background)
	# update the data
	line.set_ydata(nx.sin(x+(update_line.cnt+myinterncount)/10.0))
	# just draw the animated artist
	ax.draw_artist(line)
	# just redraw the axes rectangle
	canvas.blit(ax.bbox)
	
	if update_line.cnt>=500:
		# print the timing info and quit
		print 'FPS:' , update_line.cnt/(time.time()-tstart)
		
		# to force the main thread to exit:
		# first set runthread to 0 - then wait for it to "join"
		runthread=0
		t0.join(1) 	# if we don't exit threadMainTest otherwise (here via runthread), 
					# timeout as arg to join() here will NOT help to force exit !! 
		print "exiting"
		sys.exit(0)
	
	# for this example, we relegate changing of 
	# update_line.cnt to the main thread:
	#~ update_line.cnt += 1
	return True


# ############## ENTRY POINT 

# global variable to force thread to stop/exit 
global runthread

# set initial values of data exchange/comm. vars
update_line.cnt = 0
mypass = 0

# set the thread state to 'running'
runthread=1

# set the update_line function to run on "idle"
gobject.idle_add(update_line)

# global reference to main thread
global t0

# start the "main" thread
t0 = threading.Thread(target=threadMainTest)
t0.start() 

# start the graphics update thread
p.show()


# nope - I had no luck with separating the processing as below:  
#~ loop = gobject.MainLoop()
#~ gobject.threads_init()
#~ context = loop.get_context()
#~ # p.ion()
#~ p.draw()
#~ p.draw()
#~ # time.sleep(5.0)
#~ p.ioff()
#~ while 1:
	#~ # Handle commands here
	#~ p.draw()
	#~ context.iteration(True)
	#~ time.sleep(0.001)

print "out" # will never print - show() blocks indefinitely! 

# code end. 


# original code from webpage 
"""
import sys
import gtk, gobject
import matplotlib
matplotlib.use('GTKAgg')
import pylab as p
# import matplotlib.numerix as nx
import numpy as nx
import time
ax = p.subplot(111)
canvas = ax.figure.canvas

# for profiling
tstart = time.time()

# create the initial line
x = nx.arange(0,2*nx.pi,0.01)
line, = ax.plot(x, nx.sin(x), animated=True)

# save the clean slate background -- everything but the animated line
# is drawn and saved in the pixel buffer background
background = canvas.copy_from_bbox(ax.bbox)

def update_line(*args):
	# restore the clean slate background
	canvas.restore_region(background)
	# print "sd"
	# update the data
	line.set_ydata(nx.sin(x+update_line.cnt/10.0))
	# just draw the animated artist
	ax.draw_artist(line)
	# just redraw the axes rectangle
	canvas.blit(ax.bbox)
	
	if update_line.cnt==500:
		# print the timing info and quit
		print 'FPS:' , update_line.cnt/(time.time()-tstart)
		sys.exit()
	
	update_line.cnt += 1
	return True

update_line.cnt = 0

gobject.idle_add(update_line)
p.show()
"""

