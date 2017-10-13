#!/usr/bin/env python

# http://code.activestate.com/recipes/134892-getch-like-unbuffered-character-reading-from-stdin/
# http://docs.python.org/release/2.4.1/lib/module-curses.wrapper.html
# http://www.gossamer-threads.com/lists/python/dev/724734
# also: inputoutput.html:
##~ To read a file's contents, call f.read(size), which reads some 
##~ quantity of data and returns it as a string. size is an optional 
##~ numeric argument. When size is omitted or negative, the entire 
##~ contents of the file will be read and returned; it's your problem
##~ if the file is twice as large as your machine's memory. 
# linecache seems best to get a given line in a file:
## The linecache module allows one to get any line from any file, 
## while attempting to optimize internally, using a cache, the 
## common case where many lines are read from a single file. 
##~ >>> import linecache
##~ >>> linecache.getline('/var/log/messages', 1000)
##~ 'Nov  7 11:44:12 kernel: [    0.320971] pci 0000:00:1c.3:   PREFETCH window: 0x00000040400000-0x000000405fffff\n'

# note, this script will exit on stdin (-) as argument ! "Real" files only! 



import sys
import os
import atexit
import time
import signal

import curses
import linecache

# ###### FUNCTIONS

def signal_handler(signal, frame):
	global gidle_id
	
	print 'You pressed Ctrl+C!'
	exiter() # exiter_callback() in 100 m
	return
signal.signal(signal.SIGINT, signal_handler)


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



def exiter():
	global myscreen
	print "exiting.."
	if 'myscreen' in globals():
		try:
			atexit.register(curses.endwin)
		except:
			pass
	sys.exit(0)
	return




# ##################### MAIN

def main(argv):
	global myscreen
	
	print argv, len(argv)

	print "started"

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
	
	# - ignore the above - use linecache to open file
	tline = linecache.getline(fname, 1)
	if tline=='':
		exiter() # exiter_callback() in 100 ms - WORKS; now exit proper!
		return		

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

	#hide cursor
	#~ curses.curs_set(0)

	# for profiling
	tstart = time.time()
	
	# initial draw curses
	#~ drawNcursesFrame(myscreen)
	myscreen.idlok(1)
	myscreen.scrollok(1)
	
	# curses codes:
	# arrow up		65
	# arrow down	66
	# arrow left		68
	# arrow right	67
	
	# main loop
	c = 0
	lcount = 1 # we pre-read first line already, tline
	startup = 1
	LSX=10 ; LSY = 3 # newline start pos
	while c != 113: # was while 1:; now wait for 'q'
		c = myscreen.getch()
		# note, readline will include the \n too - sanitize
		# .readline(100), os.read(fd9, 100) - max 100 bytes
		#~ writetxt = fd9obj.readline()
		
		if startup==1:
			myscreen.addstr(10, 3, str(lcount)+": "+tline) 
			myscreen.scroll()
			startup=0
		elif c==65:		# arrow up 
			lcount += 1
			tline = linecache.getline(fname, lcount)
			myscreen.addstr(10, 3, str(lcount)+": "+tline) 
			myscreen.scroll()
		elif c==66:		# arrow down
			lcount -= 1
			if lcount < 1: lcount = 1 
			tline = linecache.getline(fname, lcount)
			myscreen.addstr(10, 3, str(lcount)+": "+tline) 
			myscreen.scroll()
		else:	# only sleep when no receive, for fastest response?
				# it goes too fast like that - but only for small ammt of lines (~10)
			time.sleep(0.01) # seconds; 0.001 - too fast for small, 0.01 is visible (buffered)
		myscreen.addstr(13, 5, "Press q to quit") # also scrolled... - cover w/ empty "buffer"
		myscreen.move(12, 3) # reset - move cursor
		# show pressed character
		if c != -1: # for non-blocking, -1 is returned on nothing
			myscreen.addstr(11, 4, "                ") # note, scroll also scrolls this!
			myscreen.addstr(12, 4, "                ") # so, adding a smpty line "buffer"
			myscreen.addstr(12, 5, str(c))
		
	# we're out of loop (maybe 'q' pressed...) - close
	exiter() # exiter_callback() in 100 ms



# ##################### ENTRY POINT

# run the main function - with arguments passed to script:
if __name__ == "__main__":
	curses.wrapper(main(sys.argv[1:]))
	#sys.stderr.write("after main1") # these won't show either,







"""

"""