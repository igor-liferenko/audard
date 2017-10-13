#!/usr/bin/env python

# http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/single-scripts/testcurses-stdin.py
# http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/single-scripts/split-parse-tokenize.py
#  http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/Animating_selected_plot_elements-thread.py
# http://www.artfulcode.net/articles/multi-threading-python/
# Re: subplots and forked show() - msg#00072 - python.matplotlib.general - http://osdir.com/ml/python.matplotlib.general/2004-07/msg00072.html
# Re: [pygtk] Close/hide a child window - http://www.mail-archive.com/pygtk@daa.com.au/msg14653.html
# Issue 5155: Multiprocessing.Queue created by sub-process fails when used in sub-sub-process ("bad file descriptor" in q.get()) - Python tracker - http://bugs.python.org/issue5155

# measured FPS shown (with sinusoid), goes from 25 up to 35..
# measured FPS shown (with 7 lines), goes from 10  up to approx 26..
## The FPS is cumulative, so it is not accurate - will report higher when nothing is drawn (60), slowly down to lesser for animation (25), and slowly down to even less for saving (~1). 

# remember to have terminal window in focus - to have keystrokes registered!
# also, note that saving images in player, only safe thing is to step frame by frame;
# - as playback with saving images will skip frames !! (since its executed in GUI callback! )
# - unfortunately, amSaving doesn't work well as mutex - frames are still skipped (if saveImages + playback).. 
# - doing g.source_remove and idle_add within gui callback helps - but still frames are skipped
# - instead of amSaving, use lastFrameSaved - set to 0 while processing, and check in main thrad that lastFrameSaved == lastFrame before continuing
# also, when pressing 'i' in the mid of capture, lines may get wrongly positioned; click on 's' to reset state for saving images.

# data is repeated lines of:
st="[ 1644.672042] :  tmr_fnc: bWr:0 bsl:176 pbpos: 176, irqps: 176, hd: 0, tl: 0, sz: 131072, tlR: 0, hdW: 0, Wrp: 0-0"

# for stdin, call with:
# cat nc.txt | python ./anim_parse_data-pipecursethrd.py -
# for regular file, call with:
# ./anim_parse_data-pipecursethrd.py nc.txt

# if it is a regular file (inputSrcType==2 OR 3), implement a player:
# with states PLAY, STOP (spacebar could toggle) - maybe also REVP (reverse play)
# and definitely navigation: left arrow: -1 line in text file; right arrow: +1 line in text file
# and more shortcuts (see threadMainTest)

# NOTE - in the usual mode of player - EVERY line triggers a redraw, 
# even if it doesn't contain relevant data! which is why animating usual
# logs like this, can be misleading in terms of speed.. 
# which is why, first we may want to use a "cleaned" file instead, with
# only the relevant lines, i.e.: 
## grep 'tmr_fnc: bWr:\|snd_card_audard_pcm_prepare' nc.txt > nc-clean.txt
# with nc-clean.txt, getting approx same deltas for each frame, 
# which means animation should be more appropriate.. 
# more grep options
# to get also "fin: aWB:176" stamp on same line - append consecutive lines using paste: 
## cat <(grep '_prepare' nc.txt) <(cat nc.txt | sed 's/Nov\(.*\)fin/fin/' | grep 'tmr_fnc: bWr:\|fin:' |  paste -d' ' - -) > nc-clean.txt




import sys
import os
import atexit
import time
import signal

import gtk, gobject
import matplotlib
matplotlib.use('GTKAgg')
from matplotlib.backends.backend_gtkagg import new_figure_manager # http://osdir.com/ml/python.matplotlib.general/2004-07/msg00072.html
import pylab as p
#~ import matplotlib.pyplot as p # has no attribute "close"
import numpy as nx # import matplotlib.numerix as nx # numerix deprecated

import threading # threads

import logging
LOG_FILENAME = 'anim_parse_data.log'
logging.basicConfig(filename=LOG_FILENAME,level=logging.DEBUG)
logging.disable(logging.DEBUG) # to disable logging, only DEBUG messages here; comment this to get logging

import linecache


# No need for p.ion()/ioff() here...

# cannot get ref for window closing like this:
ax = p.subplot(111)
canvas = ax.figure.canvas

# for profiling
tstart = time.time()

# create the initial line
#~ x = nx.arange(0,2*nx.pi,0.01)
#~ line, = ax.plot(x, nx.sin(x), animated=True)
# matplotlib horizontal line: plt.plot([3,4],[20,20],'bo-')
# dict is pseudo-random hashtable, no inherent ordering!
# so using tuple to set the order of names; and then a dict for colors
lineseq=("pbpos", "irqps", "hd", "tlR", "bWr", "bsl", "tl")
linecols={"pbpos":"blue", "irqps":"red", "tlR":"cyan", 
		"bWr":"magenta", "bsl":"green", "hd":"yellow", "tl":"black"}
linesdata={} # dictionary.. dynamically add "properties"
icnt=0
#~ for key,clr in linecols.items(): # dictionary needs items() for 'for' iteration
for key in lineseq: 
	icnt += 1
	clr = linecols[key]
	# plot - note: "Return value is a list of lines that were added."
	# since only one requested here - extract the line directly (tmplot[0]) for linesdata
	tmplot = ax.plot([3,4],[icnt,icnt],'o-', color=clr, animated=True)
	# main annotation (on left) - label for name of param scanned
	tmannot = ax.annotate(key, xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),)
	# end annotation (on right) - current value on bigger zoom levels .. 
	teannot = ax.annotate(str(icnt), xy=(4, icnt-0.1), ha="left", animated=True, )
	if key=='irqps': teannot.set_annotation_clip(False)
	# each entry - immutable tuple
	linesdata[key] = (tmplot[0], tmannot, teannot)

# helpers
# handle annotation_clip attribute too - The default is None, which behave as True only if xycoords is "data" (no dice); for panning graph 
# bug: set_annotation_clip: http://www.mail-archive.com/matplotlib-users@lists.sourceforge.net/msg18330.html
linesdata_helper = (ax.plot([0,0],[1.3,1.3],'-', color="chartreuse", animated=True)[0], 
	None, #ax.annotate('helper', xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),), 
	ax.annotate("0", xy=(0, 1.3-0.1), xycoords='data', annotation_clip=False, ha="left", va="bottom", animated=True, ))
linesdata_helperB = (ax.plot([0,0],[1.5,1.5],'o-', color="forestgreen", animated=True)[0], 
	None, #ax.annotate('helper', xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),), 
	ax.annotate("0", xy=(0, 1.5-0.1), xycoords='data', annotation_clip=False, ha="left", va="bottom", animated=True, ))
linesdata_helperB2 = ax.axvline(color="forestgreen", animated=True)
linesdata_helperC = (ax.plot([0,0],[2,2],'-', color="#FFA2A2", animated=True)[0], #light red
	None, #ax.annotate('helper', xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),), 
	ax.annotate("0", xy=(0, 2-0.1), xycoords='data', annotation_clip=False, ha="left", va="bottom", animated=True, ))
linesdata_helperD = (ax.plot([0,0],[1,1],'-', color="#A2A2FF", animated=True)[0], #light blue
	None, #ax.annotate('helper', xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),), 
	ax.annotate("0", xy=(0, 1-0.1), xycoords='data', annotation_clip=False, ha="left", va="bottom", animated=True, ))
linesdata_helperE = (ax.plot([0,0],[1.7,1.7],'o-', color="darkviolet", animated=True)[0], 
	None, #ax.annotate('helper', xy=(0, icnt), ha="right", bbox=dict(boxstyle="round", fc="0.8"),), 
	ax.annotate("0", xy=(0, 1.7-0.1), xycoords='data', annotation_clip=False, ha="left", va="bottom", animated=True, )) # aWB
linesdata_helper[2].set_annotation_clip(False)
linesdata_helperB[2].set_annotation_clip(False)
linesdata_helperC[2].set_annotation_clip(False)
linesdata_helperD[2].set_annotation_clip(False)
linesdata_helperE[2].set_annotation_clip(False)

#~ print linesdata
	
global annotinit
annotinit = 0 # try to save annots on background
#~ ant3.draw(ax) # does nothing - draw_artist needs _cache, which is N/A here

# save the clean slate background -- everything but the animated line
# is drawn and saved in the pixel buffer background
global background
background = canvas.copy_from_bbox(ax.bbox)


# axes ranges init
global startxlim, startylim
startxlim = [0,200000] ; startylim = [0,8]
ax.set_xlim(startxlim[0],startxlim[1])
ax.set_ylim(startylim[0],startylim[1])


# just a plain global var to pass data (from main, to plot update thread)
global mypass
# global variable to force thread to stop/exit
global runthread
# global reference to main thread
global t0
# id of  gobject idle thread (update)
global gidle_id

# to cleanup file descriptors, declare as global
global ftty, fd9obj, fobj

# for knowing whether we have file or stdin opened.
# we count either on stdin (=1) or normal file (=3) 
global inputSrcType
# for file - player:
# player state: 0 stopped; 1 play forward, 2 play backward
# player state: 1 play forward, -1 play backward (for calc on keys too)
global playerState, playerDirection
playerState = 0 # set here - else very first time, drawcurses may complain
playerDirection = 0
global saveImages # should we save images - only when player w file (not realtime w stdin)
saveImages = 0
global nlines # number of lines in file
nlines = 0 # set here - else drawcurses may complain
global lcount # current line number
global lastlcount # last lcount - for gauging render images
lcount = 0 # set here - else drawcurses may complain
lastlcount = 0
global lastFrameSaved
lastFrameSaved = 0

# instead of another global variable, we can use pipe
# ... ALTHOUGH, will just use globals here - easier.
# to exchange data between threads
# http://docs.python.org/library/multiprocessing.html#pipes-and-queues
# NOTE: pipe1main, pipe1upd here will take file descriptors 8 and 9!
# if it happens that the fd that we copy stdin to is 9 (or 8), then we crash w/
#   IOError: [Errno 9] Bad file descriptor !!!!
from multiprocessing import Pipe
global pipe1main, pipe1upd
pipe1main, pipe1upd = Pipe()

# pass value
global curval

# ###### FUNCTIONS

def signal_handler(signal, frame):
	global gidle_id
	
	print 'You pressed Ctrl+C!', pipe1main, pipe1upd
	exiter() # exiter_callback() in 100 m
	return
signal.signal(signal.SIGINT, signal_handler)

# http://stackoverflow.com/questions/273192/python-best-way-to-create-directory-if-it-doesnt-exist-for-file-write
def ensure_dir(f):
	d = os.path.dirname(f)
	if not os.path.exists(d):
		#~ os.makedirs(d)
		# "makedirs() will become confused if the path elements to create include os.pardir."
		# so, no relative
		os.mkdir(d)
		
def switchAnimated(inval):
	for key in lineseq: 
		linesdata[key][0].set_animated(inval)
		linesdata[key][2].set_animated(inval)
	linesdata_helper[0].set_animated(inval)
	linesdata_helper[2].set_animated(inval)
	linesdata_helperB[0].set_animated(inval)
	linesdata_helperB[2].set_animated(inval)
	linesdata_helperB2.set_animated(inval)
	linesdata_helperC[0].set_animated(inval)
	linesdata_helperC[2].set_animated(inval)
	linesdata_helperD[0].set_animated(inval)
	linesdata_helperD[2].set_animated(inval)
	linesdata_helperE[0].set_animated(inval)
	linesdata_helperE[2].set_animated(inval)

def openAnything(source):
	"""URI, filename, or string --> stream
	
	http://diveintopython.org/xml_processing/index.html#kgp.divein

	This function lets you define parsers that take any input source
	(URL, pathname to local or network file, or actual data as a string)
	and deal with it in a uniform manner.  Returned object is guaranteed
	to have all the basic stdio read methods (read, readline, readlines).
	Just .close() the object when you're done with it.
	"""
	global inputSrcType
	
	if hasattr(source, "read"):
		inputSrcType = 0
		return source
	
	if source == '-':
		import sys
		inputSrcType = 1
		return sys.stdin
	
	# try to open with urllib (if source is http, ftp, or file URL)
	import urllib
	try:
		inputSrcType = 2
		return urllib.urlopen(source)
	except (IOError, OSError):
		pass
	
	# try to open with native open function (if source is pathname)
	try:
		inputSrcType = 3
		return open(source)
	except (IOError, OSError):
		pass
	
	# treat source as string
	import StringIO
	inputSrcType = 4
	return StringIO.StringIO(str(source))


# http://stackoverflow.com/questions/845058/how-to-get-line-count-cheaply-in-python
def bufcount(filename):
    f = open(filename)                  
    lines = 0
    buf_size = 1024 * 1024
    read_f = f.read # loop optimization

    buf = read_f(buf_size)
    while buf:
        lines += buf.count('\n')
        buf = read_f(buf_size)

    return lines


import re

# initword = "tmr_fnc" # consider dict ordered, will be holder for string values
# both dictionary of words to be parsed - and also a holder for values
# dictionary: curval - parsed values; last entry will be timestamp
curval = {
	"tmr_fnc":0, # always empty, it's just a marker string; keeping it so we don't waste time getting rid of it
	"bWr":0,
	"bsl":0,
	"pbpos":0,
	"irqps":0,
	"hd":0,
	"tl":0,
	"sz":0,
	"tlR":0,
	"WrpA":0,
	"WrpB":0,
	"WCnt":0, # wrapcount
	"timestamp":0,
	"tsprev":0, # previous timestamp - for delta
	"hdprev":0, # previous hd - for hdpb
	"pbprev":0, # previous pbpos - for hdpb
	"hdpb":0, # value of prev pbpos when hd first became nonzero
	"bps":0,
	"bpj":0,
	"HZ":0,
	"buffer_size":0,
	"pcm_period_size":0,
	"bpjtot":0,
	"irqprev":0, # previous irqpos - for irqpos wrap counter.. 
	"irqwrp":0, #irqpos wrap counter.. 
	#"pbprev":0, # previous pbpos - for pbpos wrap counter.. 
	"pbwrp":0, #pbpos wrap counter.. 
	"aWB":0, 
	"aWBtot":0, # total actual written.. 
}

whitespace = re.compile('\W+')

# tuple - immutable list
patterns = [
	('timestamp', re.compile(r'''.*\[ (.*)\]'''), 1),
	('tmr_fnc', re.compile(r'.*?tmr_fnc:(\d*)'), 1), # .*? non-greedy.. , don;t use (.*?) - ? misses
	('bWr', re.compile(r'''.*?bWr:(\d*)'''), 1),
	('bsl', re.compile(r'.*?bsl:(\d*)'), 1),
	('pbpos', re.compile(r'.*?pbpos:\W*(\d*)'), 1), # again, no \W* here..
	('irqps', re.compile(r'.*?irqps:\W*(\d*)'), 1),
	('hd', re.compile(r'.*?hd:\W*(\d*)'), 1),
	('tl', re.compile(r'.*?tl:\W*(\d*)'), 1),
	('sz', re.compile(r'.*?sz:\W*(\d*)'), 1),
	('tlR', re.compile(r'.*?tlR:\W*(\d*)'), 1),
	('Wrp', re.compile(r'.*?Wrp:\W*(\d*-\d*)'), 1),
	('aWB', re.compile(r'.*?aWB:\W*(\d*)'), 1),
	('bps', re.compile(r'''.*?bps:(\d*)'''), 1), # prepare line; just have em in order.. 
	('bpj', re.compile(r'.*?bpj:\W*(\d*)'), 1),
	('HZ', re.compile(r'.*?HZ:\W*(\d*)'), 1),
	('buffer_size', re.compile(r'.*?buffer_size:\W*(\d*)'), 1),
	('pcm_period_size', re.compile(r'.*?pcm_period_size:\W*(\d*)'), 1) 
]

def tokenize(string):
	# don't use check if string has been completely emptied for our case;
	# we just need the token data extracted.
	#~ while string:
		# strip off whitespace at start only - don't need it, strips my '['
		#~ m = whitespace.match(string)
		#~ if m:
		#	#~ string = string[m.end():]
		#
		for tokentype, pattern, grp in patterns:
			m = pattern.match(string)
			#~ print tokentype, pattern, grp, m
			#~ print string
			if m:
				yield tokentype, m.group(grp)
				string = string[m.end():] # if the string is cut, less work next loop

def parseText(intext):
	global curval
	global playerDirection
	#~ print intext
	ans = ""
	for tokentype, literal in tokenize(intext):
		#~ ans = ans + tokentype + "----" + literal + "\n"
		try:
			if tokentype == "Wrp": # "0-0"
				both = literal.split("-")
				curval['WrpA'] = int(both[0])
				curval['WrpB'] = int(both[1])
				if curval['WrpA'] != 0: # wrap calc will not work for player when backwards!
					curval['WCnt'] += 1  # so not actually using it.. 
			elif tokentype == "timestamp":
					curval['tsprev'] = curval[tokentype] 
					curval[tokentype] = float(literal)
			elif tokentype == "hd":
					curval['hdprev'] = curval[tokentype] 
					curval[tokentype] = int(literal)
			elif tokentype == "pbpos":
					curval['pbprev'] = curval[tokentype] 
					curval[tokentype] = int(literal)
			elif tokentype == "irqps":
					curval['irqprev'] = curval[tokentype] 
					curval[tokentype] = int(literal)
			else:
				curval[tokentype] = int(literal)
		except:
			pass
			
	# check hdpb - after for loop is done pbprev
	if (curval['hdpb']==0 and (curval['hdprev']==0 and curval['hd']>0)):
		curval['hdpb']=curval['pbprev']
	
	# handle bpjtot - note, will not work for stepping frames
	# handle also irqwrp
	if curval['irqps']==0: # total reset when 0; not extremely correct, but will work
		curval['bpjtot']=0
		curval['irqwrp']=0 
		curval['pbwrp']=0 
		curval['aWBtot']=0 
	else:
		curval['bpjtot'] += playerDirection*curval['bpj']
		curval['aWBtot'] += playerDirection*curval['aWB']
		curval['irqwrp'] += playerDirection*(playerDirection*curval['irqprev'] > playerDirection*curval['irqps']) #should be 1 for pos wrap, -1 for neg wrap, and 0 elsewhere.
		curval['pbwrp'] += playerDirection*(playerDirection*curval['pbprev'] > playerDirection*curval['pbpos']) #should be 1 for pos wrap, -1 for neg wrap, and 0 elsewhere.
	
	if curval['irqwrp'] < 0: curval['irqwrp'] = 0
	if curval['pbwrp'] < 0: curval['pbwrp'] = 0
	
	return curval # ans 



def exiter():
	global ftty, fd9obj, fobj
	global runthread

	runthread=0								# "signal" end of main loop
	tz = gobject.source_remove(gidle_id)	# "signal" end of update_line drawing

	# cleanup
	try:
		ftty.close()
		fd9obj.close()
		fobj.close() # this causes bad file fd: if no stdin AND 'q' is pressed ?!
	except:
		#~ sys.stderr.write("Unexpected error: %s" % sys.exc_info()[0])
		#~ raise # don't raise, pass
		pass

	gobject.timeout_add(100, exiter_callback) # exiter_callback in
	return

def exiter_callback():
	global t0
	global gidle_id

	if 't0' in globals(): # globals().has_key('t0')
		t0.join(1) 	# if we don't exit threadMainTest otherwise (here via runthread),
					# timeout as arg to join() here will NOT help to force exit !!

	atexit.register(curses.endwin)	# end curses

	mngr = p.get_current_fig_manager()

	#~ mngr.destroy() # mngr.canvas=canvas -> no attribute 'canvas??!!!
	# mngr.window - http://www.pygtk.org/docs/pygtk/class-gtkwindow.html

	# in callback, these messages spill in curses..
	print p, ax #, manager1
	#~ print "No input data, exiting...", gobject.signal_name(gidle_id), gobject.signal_query(gidle_id), mngr, "\n", dir(mngr), "\n", dir(p), "\n", dir(canvas), "\n", dir(p.allclose), "\n", dir(mngr.window)

	# note, if time.sleep is 0.3 here, it blocks until mouseover;
	# 	if time.sleep is 0.1, it exits with crash!
	#~ time.sleep(0.2) # give it time so update_loop dies; takes more than the set value
	# ... but not if it if handled with callbacks with a bit of waiting time..
	# ... also, as we're in callback now, we probably don't need to call
	#     update_line() (so as to "refresh" the global 'runthread', and cause exit )

	# same message always : 'size-changed'
	logging.debug('TEST0')
	for i in range(1, 10):
		logging.debug('INLOOP')
		# note, using "% %s" % here, will fail w/ "not enough args for format string"!
		logging.debug("%s" % str(gobject.signal_name(gidle_id)) )
		logging.debug("%s" % str(gobject.signal_query(gidle_id)) )


	# kill/destroy/close the maplotlib/pyplot window
	#~ mngr.window.close() # no attribute 'close'
	mngr.window.set_destroy_with_parent(True) #
	mngr.window.destroy() #
	canvas.destroy()
	# after these cmds are execd, gobject.signal_name(gidle_id) is 'null' !!
	p.close('all') #~ p.allclose() # p.close()

	print "... exiting done.."
	sys.exit(0)
	return



# for direct stdout
def drawText(indrobj):
	#~ print indrobj
	print ""
	for tokenkey, value in indrobj.items():
		print "%s = %s" % (tokenkey, value)

def shouldIRenderAnnot():
	xmin_datac, xmax_datac = ax.get_xlim()
	xrange = xmax_datac - xmin_datac
	return xrange

# main plot / GUI update
def update_line(*args):
	global mypass
	global t0
	global runthread
	global pipe1upd
	global curval
	global annotinit
	global background
	global saveImages, lcount, lastlcount, lastFrameSaved, gidle_id

	if not runthread:
		print "not runthread"
		return False 	# we must have this return False, else this function
						# will block sys.exit(0) - and will NEVER exit!!

	lastFrameSaved = 0 # when 0, more like amDrawing :)

	# optimize a bit - draw only if changed frame:
	# NOTE - when saveImages, memory gets dealloced @ 59 Mib down to 30 
	#  (and then repete) - even without a clf!. 
	# so, we just have to make sure frames are in sequentially - 
	# - which is why we cannot do this optimize if we saveImages during playback! 
	if ((not saveImages) and (not (lastlcount != lcount))): # if lastlcount == lcount
		amSaving = 0
		time.sleep(.01)
		update_line.cnt += 1 # this cheats a bit as FPS.. better with, though..  
		return True
		
	# get value from pipe - NOT used for now (
	# sys.stderr.write(str(pipe1upd)) # not from here - spills in curses !
	#~ if pipe1upd.poll():	# check first if there is anything to receive
		#~ mytobj = pipe1upd.recv()
	
	# lets try release memory here.. kills savefig - with or without not ! 
	#~ if not saveImages: p.clf()
	#~ else: p.draw()
	
	if saveImages:
		gobject.source_remove(gidle_id)
	
	# restore the clean slate background
	#~ if not (saveImages and (lastlcount != lcount)): # this still don't recover draw while save
	canvas.restore_region(background)

	# so we don't redraw the labels - just draw them once
	# and them save them as background (must be done here,
	# since here _cache is defined)
	# NOTE: that panning in plot window -  will delete these ! 
	if annotinit == 0:
		annotinit = 1
		for key,val in linesdata.items(): # dict needs items for iter
			tmpannot = val[1]
			ax.draw_artist(tmpannot)  # draw annotation
		background = canvas.copy_from_bbox(ax.bbox)

	# update the data
	#~ line.set_ydata(nx.sin(x+(update_line.cnt)/10.0))
	#~ line.set_ydata(nx.sin(x+(curval["pbpos"])/5000.0))
	# matplotlib horizontal line: p.plot([3,4],[20,20],'bo-')
	# wrap calc (pbm/irm) will not work for player - backwards
	#~ pbm = curval['WCnt']*4408 #move buffer_size: ,
	#~ irm = curval['WCnt']*4408 # 1102 #move pcm_period_size: ,
	
	# redraw all lines
	for key,val in linesdata.items(): # dict needs items for iter
		tmpline = val[0]
		if key=='irqps':
			k = curval['irqwrp']*curval['pcm_period_size']
			tmpline.set_xdata([k, k+curval[key]])
			linesdata_helperC[0].set_xdata([0, k])
			ax.draw_artist(linesdata_helperC[0])
		elif key=='pbpos':
			k = curval['pbwrp']*curval['buffer_size']
			tmpline.set_xdata([k, k+curval[key]])
			linesdata_helperD[0].set_xdata([0, k])
			ax.draw_artist(linesdata_helperD[0])
		else:
			tmpline.set_xdata([0, curval[key]])
		ax.draw_artist(tmpline)
	
	# draw helpers if we can
	if curval['hdpb']>0:
		tmpline = linesdata_helper[0]
		tmpeannot = linesdata_helper[2]
		tmpline.set_xdata([curval['hdpb']+0, curval['hdpb']+curval['hd']])
		ax.draw_artist(tmpline)
	if curval['bpjtot']>0:
		tmpline = linesdata_helperB[0]
		tmpeannot = linesdata_helperB[2]
		tmpline.set_xdata([curval['bpjtot']-curval['bpj'], curval['bpjtot']])
		ax.draw_artist(tmpline)
		linesdata_helperB2.set_xdata(curval['bpjtot']) # vertical line
		ax.draw_artist(linesdata_helperB2)
	if curval['aWBtot']>0:
		tmpline = linesdata_helperE[0]
		tmpeannot = linesdata_helperE[2]
		tmpline.set_xdata([curval['aWBtot']-curval['aWB'], curval['aWBtot']])
		ax.draw_artist(tmpline)
		
		
	shouldI = shouldIRenderAnnot()
	if shouldI < 50000:
		# invisible items should not be rendered with this loop, even if triggered 
		for key,val in linesdata.items(): # dict needs items for iter
			tmpeannot = val[2]
			tmpline = val[0]
			# set_position, set_x have no effect here (and are not in plot coords)
			#~ tmpeannot.set_position( (float(curval[key]), tmpline.get_ydata()[1]) )
			#~ tmpeannot.set_x( float(curval[key]) )
			#~ tmpeannot.xytext[0]=curval[key]	# "'tuple' object does not support item assignment"
			if key=='irqps':
				tmpeannot.xytext=(curval['irqwrp']*curval['pcm_period_size']+curval[key], tmpline.get_ydata()[1]-0.1) # ok
			elif key=='pbpos':
				tmpeannot.xytext=(curval['pbwrp']*curval['buffer_size']+curval[key], tmpline.get_ydata()[1]-0.1) 
			else:
				tmpeannot.xytext=(curval[key], tmpline.get_ydata()[1]-0.1) # ok
			tmpeannot.set_text( str(curval[key]) )
			#~ tmpeannot.update_bbox_position_size(ax)
			ax.draw_artist(tmpeannot)
		if curval['hdpb']>0:
			tmpeannot = linesdata_helper[2]
			k = curval['hdpb']+curval['hd']
			tmpeannot.set_text( str(k) )
			tmpeannot.xytext=(k, tmpeannot.xytext[1])
			#~ tmpeannot.update_bbox_position_size(ax)
			ax.draw_artist(tmpeannot)
		if curval['bpjtot']>0:
			tmpeannot = linesdata_helperB[2]
			k = curval['bpjtot']
			tmpeannot.set_text( str(k) )
			tmpeannot.xytext=(k, tmpeannot.xytext[1])
			#~ tmpeannot.update_bbox_position_size(ax)
			ax.draw_artist(tmpeannot)
		if curval['aWBtot']>0:
			tmpeannot = linesdata_helperE[2]
			k = curval['aWBtot']
			tmpeannot.set_text( str(k) )
			tmpeannot.xytext=(k, tmpeannot.xytext[1])
			#~ tmpeannot.update_bbox_position_size(ax)
			ax.draw_artist(tmpeannot)
	
	# at this point, plot is finished
	# export render if required
	## http://old.nabble.com/saving-animations-td29528469.html
	## Technically speaking, animation to the screen is completely different
	## from what you are trying to do here.  When showing an animation to 
	## the screen, a bunch of tricks are needed to make it efficient and for
	## looping. However, if you only wish to save the individual frames, I 
	## would suggest that you just simply create your figures normally (none
	## of this blitting and update_lines stuff) and save each of them as 
	## you would normally. Be sure to call clf() to prevent memory usage to 
	## grow out of control.	
	# ax.figure.clf will allow animated to be drawn on screen while saving - 
	# - but the saving will be completely blank
	# without clf, doing savefig blanks the screen render of animated -
	# - and it saves only background (i.e. blit) - but not the animated
	## also, http://www.mail-archive.com/matplotlib-devel@lists.sourceforge.net/msg07320.html
	## ok, it grabs images if switching the animated attribute - then it still won't render to screen though.. clf will help render to screen - but will blank the png.. 
	if (saveImages): # and (lastlcount != lcount) # moved above
		amSaving = 1
		fname = 'render/_apd%05d.png'%lcount
		ax.figure.savefig(fname) 	#  p.savefig is completely blank ; ax.figure - clf kills it!
								# no canvas.savefig
		#~ ax.figure.clf() # clf will blank all subsequent savefigs, but the very first one! 
		p.draw() # THIS to both savfefig (animated=false) AND show to screen!
		#~ time.sleep(.01) # some time for savefig?!
		lastFrameSaved = lcount # HERE, NOT AFTER LAST SLEEP!! 
	else:
		# just redraw the axes rectangle
		canvas.blit(ax.bbox)
		#~ p.clf() # here it don't seem to harm.. only when saving imgs - and that, even with and 'if'!! 

	lastlcount = lcount	
	
	if saveImages:
		gidle_id = gobject.idle_add(update_line)
	
	update_line.cnt += 1
	time.sleep(.01)
	
	return True


# for curses
# tried with def drawNcursesBckg(myscreen): ; 
# however, cannot  separate "background" curses from 
# foreground with clear()/erase() running!  
SX=5 ; SY=5 # start X, Y of curses draw
SYB=SY+12
import curses
def drawNcursesFrame(myscreen, c=''): # we will draw parsed curval
	global curval
	global inputSrcType
	global playerState
	global nlines
	global lcount
	global saveImages

	if (playerState==0 and (inputSrcType==2 or inputSrcType==3)):
		myscreen.clear() #  clear causes a refresh - to delete possible stderr garbage
	else:
		myscreen.erase() # reduce ncurses flicker when playing back

	myscreen.border(0)

	myscreen.addstr(SX, SY, "Press [q] to quit") ; myscreen.addstr(SX, SY+20, "r: "+str(shouldIRenderAnnot()))

	myscreen.addstr(SX+2, SY, "timestamp:") ;	myscreen.addstr(SX+2, SYB, str(curval['timestamp']) )
	myscreen.addstr(SX+2, SYB+14, "delta us: %6d" % (1000000*(curval['timestamp']-curval['tsprev'])));
	
	myscreen.addstr(SX+3, SY, "bWr:") ; myscreen.addstr(SX+3, SYB, str(curval['bWr']) )
	if c==99: # 'c':
		myscreen.addstr(SX+3, SYB+14, "bpj:%d bfs:%d pps:%d si:%d" % ( curval['bpj'], curval['buffer_size'], curval['pcm_period_size'], saveImages )); 
	
	myscreen.addstr(SX+4, SY, "bsl:") ; myscreen.addstr(SX+4, SYB, str(curval['bsl']) )
	myscreen.addstr(SX+5, SY, "pbpos:") ; myscreen.addstr(SX+5, SYB, str(curval['pbpos']) )
	myscreen.addstr(SX+6, SY, "irqps:") ; myscreen.addstr(SX+6, SYB, str(curval['irqps']) )
	myscreen.addstr(SX+7, SY, "hd:") ; myscreen.addstr(SX+7, SYB, str(curval['hd']) )
	myscreen.addstr(SX+8, SY, "tl:") ; myscreen.addstr(SX+8, SYB, str(curval['tl']) )
	myscreen.addstr(SX+9, SY, "sz:") ; myscreen.addstr(SX+9, SYB, str(curval['sz']) )
	myscreen.addstr(SX+10, SY, "tlR:") ; myscreen.addstr(SX+10, SYB, str(curval['tlR']) )
	myscreen.addstr(SX+11, SY, "WrpA:") ; myscreen.addstr(SX+11, SYB, str(curval['WrpA']) )
	myscreen.addstr(SX+12, SY, "WrpB:") ; myscreen.addstr(SX+12, SYB, str(curval['WrpB']) )
	myscreen.addstr(SX+13, SY, "aWB:") ; myscreen.addstr(SX+13, SYB, str(curval['aWB']) )
	myscreen.addstr(SX+14, SY, "FPS:") ; myscreen.addstr(SX+14, SYB, str(update_line.cnt/(time.time()-tstart)) )

	if inputSrcType==2 or inputSrcType==3:
		myscreen.addstr(SX+16, SY, "          ")
		myscreen.addstr(SX+16, SY+3, str(c))
		myscreen.addstr(SX+16, SY+10, "nl_"+str(playerState)+": " + str(nlines)+":"+str(lcount))
	
	myscreen.move(SX+16, SY) # move cursor

	myscreen.refresh()


# the kind of processing we might want to do in a main() function,
# will now be done in a "main thread" - so it can run in
# parallel with gobject.idle_add(update_line)
def threadMainTest(argv):
	global mypass
	global runthread
	global pipe1main
	global gidle_id
	global curval
	global ftty, fd9obj, fobj
	global inputSrcType
	global playerState, playerDirection
	global nlines
	global lcount
	global saveImages, lastFrameSaved

	print "threadMainTest started"

	fname = ""
	if len(argv):
		fname = argv[0]

	writetxt = "Python curses in action!"
	fd9 = 7 #  Note, the pipes overtake file descriptors 8 and 9, so make this 7!
	fd9obj = 0
	if fname != "":
		fobj = openAnything(fname)
		# to handle stdin, copy this object to a new file descriptor, 7 (was 9)
		os.dup2(fobj.fileno(), fd9)
		fd9obj = os.fdopen(fd9)

	# if no fd9obj, exit
	if fd9obj == 0:
		exiter() # exiter_callback() in 100 ms - WORKS; now exit proper!
		return

	# SO-3999114: os.dup2(3, 0)
	#~ alt: duplicate /dev/tty
	ftty=open("/dev/tty")
	os.dup2(ftty.fileno(), 0)

	writetxt='' # reuse
	if inputSrcType==2 or inputSrcType==3: # file
		# - ignore the above - use linecache to open file
		writetxt = linecache.getline(fname, 1)
		if writetxt=='':
			exiter() # exiter_callback() in 100 ms - WORKS; now exit proper!
			return
		# ok, we have a file - get number of lines total
		nlines = bufcount(fname)


	# Now curses can initialize.

	try:
		myscreen = curses.initscr()
		#~ atexit.register(curses.endwin) # in callback now
	except:
		print "Unexpected error:", sys.exc_info()[0]

	# behaviour of getch (not used here) - window.timeout(0) for non-blocking
	# or - window.nodelay(1) for non-blocking
	# note - non-blocking in 'plain' while loop eats CPU
	#   so, must add some delay - either sleep, or set in timeout()
	myscreen.timeout(0)

	myscreen.idlok(1)
	myscreen.scrollok(1)

	#hide cursor
	#~ curses.curs_set(0)

	# pause for a second, to allow matplotlib window to start
	time.sleep(1)
	
	# for profiling
	tstart = time.time()

	# initial draw curses
	drawNcursesFrame(myscreen)

	# main loop
	c = 0
	lcount = 1 # for file player: we pre-read first line already, tline
	startup = 1	# for file player
	playerState = 0
	# initial draw curses
	drawNcursesFrame(myscreen) # needs playerstate defined now..	
	while runthread and c != 113: # was while 1:; now wait for 'q'
		c = myscreen.getch()
		#~ logging.debug("loop %d %d", c, inputSrcType, )
		if inputSrcType==1: # stdin
			# note, readline will include the \n too - sanitize
			# .readline(100), os.read(fd9, 100) - max 100 bytes
			writetxt = fd9obj.readline()
			lwrt = len(writetxt)
			if lwrt>0:
				writetxt = writetxt[:lwrt-1]
				#~ print writetxt

				# parse and pass data to plot draw thread
				# tobj is actually global curval, so it will
				#   be "auto-passed" ... no need to use pipe
				#~ pipe1main.send(tobj) # NOTE: pipe can lock this loop totally (if it is not emptied!)
				tobj = parseText(writetxt)

				#~ drawText(tobj) # for stdout
				drawNcursesFrame(myscreen)
			else:	# only sleep when no receive, for fastest response?
					# it goes too fast like that - but only for small ammt of lines (~10)
				time.sleep(0.01) # seconds; 0.001 - too fast for small, 0.01 is visible (buffered)
		elif inputSrcType==2 or inputSrcType==3: # file
			dorender=1
			if startup==1:
				# for startup, writetext should already be cached - but repeat getline anyway
				writetxt = linecache.getline(fname, lcount) 
				lwrt = len(writetxt)
				if lwrt>0:
					writetxt = writetxt[:lwrt-1]				
				startup=0 
			elif c==32:		# space - toggle playback (forward or stop)
				if playerState==0:
					playerState=1
					playerDirection=1
					lastFrameSaved = lcount
				else:
					playerState=0
			elif c==0:		# Ctrl+Space - playback reverse
				playerState=2
				playerDirection=-1
				lastFrameSaved = lcount
			elif c==67 or playerState==1:		# arrow right 
				if saveImages: 
					while(lastFrameSaved != lcount): time.sleep(0.01)
				playerDirection = 1
				lcount += 1
				if lcount > nlines:
					lcount = nlines
					playerState = 0
				writetxt = linecache.getline(fname, lcount)
				if playerState==0:
					curses.flushinp() # "Flush all input buffers. This throws away any typeahead that has been typed by the user and has not yet been processed by the program." 				
			elif c==68 or playerState==2:		# arrow left
				if saveImages: 
					while(lastFrameSaved != lcount): time.sleep(0.01)
				playerDirection = -1
				lcount -= 1
				if lcount < 1: 
					lcount = 1
					playerState = 0
				writetxt = linecache.getline(fname, lcount)
				if playerState==0:
					curses.flushinp() # "Flush all input buffers....." 
			elif c==115:		# 's' - start
				lcount=1
				writetxt = linecache.getline(fname, lcount)
			elif c==101:		# 'e' - end
				lcount=nlines
				writetxt = linecache.getline(fname, lcount)
			elif c==110:		# 'n' - next - 10 lines
				lcount += 10
				if lcount > nlines: lcount = nlines
				writetxt = linecache.getline(fname, lcount)
			elif c==78:			# Shift+'N' - supernext - 100 lines
				lcount += 100
				if lcount > nlines: lcount = nlines
				writetxt = linecache.getline(fname, lcount)
			elif c==98:			# 'b' - back - 10 lines
				lcount -= 10
				if lcount < 1: lcount = 1
				writetxt = linecache.getline(fname, lcount)
			elif c==66:			# Shift+'B' (AND arrow down :) ) - superback - 100 lines
				lcount -= 100
				if lcount < 1: lcount = 1
				writetxt = linecache.getline(fname, lcount)
			elif c==105:		# 'i' - toggle saving images
				if saveImages==0:
					saveImages=1
					ensure_dir('render/')
				else:
					saveImages=0
				switchAnimated(not saveImages)
			else:	# only sleep when no receive, for fastest response?
					# it goes too fast like that - but only for small ammt of lines (~10)
				dorender=0
				if c != -1: # for non-blocking, -1 is returned on nothing
					drawNcursesFrame(myscreen, c) # this to simply draw the key press number
				time.sleep(0.01)
			
			if dorender:
				#~ myscreen.addstr(10, 3, str(lcount)+": "+tline) 
				#~ myscreen.scroll()
				tobj = parseText(writetxt)
				drawNcursesFrame(myscreen, c)

	# we're out of loop (maybe 'q' pressed...) - close
	exiter() # exiter_callback() in 100 ms

	return



# ##################### MAIN

def main(argv):
	global mypass
	global gidle_id
	global runthread

	print argv, len(argv)

	# set initial values of data exchange/comm. vars
	update_line.cnt = 0
	mypass = 0

	# set the thread state to 'running'
	runthread=1

	# set the update_line function to run on "idle"
	gidle_id = gobject.idle_add(update_line)

	# start the "main" thread
	t0 = threading.Thread(target=threadMainTest, args=(argv,))
	t0.start()

	# start the graphics update thread
	p.show()
	#~ manager1.window.show() # non blocking




# ##################### ENTRY POINT

# run the main function - with arguments passed to script:
if __name__ == "__main__":
	main(sys.argv[1:])
	#sys.stderr.write("after main1") # these won't show either,







"""

"""