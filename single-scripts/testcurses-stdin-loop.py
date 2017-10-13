#!/usr/bin/env python 
# http://www.tuxradar.com/content/code-project-build-ncurses-ui-python
# http://diveintopython.org/scripts_and_streams/stdin_stdout_stderr.html
# http://bytes.com/topic/python/answers/42283-curses-disable-readline-replace-stdin
# http://stackoverflow.com/questions/3999114/linux-pipe-into-python-ncurses-script-stdin-and-termios
# http://svn.python.org/projects/python/trunk/Demo/curses/repeat.py
# http://stackoverflow.com/questions/1112343/how-do-i-capture-sigint-in-python
#
# NOTE: press 'q' to exit curses - Ctrl-C will screw up yer terminal

# IF duplicating /dev/tty, call just with:
# for ix in $(seq 1 1 10000) ; do echo "$ix v$ix" ; done | ./testcurses-stdin-loop.py -
# note: keypresses are only visible after piping has finished

import curses
import sys
import os
import atexit
import termios
import time
import signal

def openAnything(source):            
	"""URI, filename, or string --> stream
	
	http://diveintopython.org/xml_processing/index.html#kgp.divein
	
	This function lets you define parsers that take any input source
	(URL, pathname to local or network file, or actual data as a string)
	and deal with it in a uniform manner.  Returned object is guaranteed
	to have all the basic stdio read methods (read, readline, readlines).
	Just .close() the object when you're done with it.
	"""
	if hasattr(source, "read"):
		return source

	if source == '-':
		import sys
		return sys.stdin

	# try to open with urllib (if source is http, ftp, or file URL)
	import urllib                         
	try:                                  
		return urllib.urlopen(source)     
	except (IOError, OSError):            
		pass                              
	
	# try to open with native open function (if source is pathname)
	try:                                  
		return open(source)               
	except (IOError, OSError):            
		pass                              
	
	# treat source as string
	import StringIO                       
	return StringIO.StringIO(str(source)) 
	
def drawFrame(myscreen, writetxt):
	# exit immediately if no writetxt
	lwrt = len(writetxt)
	if lwrt<=0:
		return 0 
	# here lwrt>0; 
	# note, readline will include the \n too - sanitize
	writetxt = writetxt[:lwrt-1] 

	# parse string line
	arr = writetxt.split(' ')
	larr = len(arr)
	
	myscreen.erase()
	
	myscreen.border(0)
	myscreen.addstr(10, 25, "Press [q] to quit")
	myscreen.addstr(12, 25, "String length: " + str(lwrt))	
	myscreen.addstr(13, 25, "       String: " + writetxt)	
	myscreen.addstr(15, 25, "value 1: ") ; myscreen.addstr(15, 45, "value 2: ")
	if larr>0: # >=1
		myscreen.addstr(16, 25, arr[0])
	if larr>1: # >=2
		myscreen.addstr(16, 45, arr[1])
	
	myscreen.refresh()

def signal_handler(signal, frame):
		print 'You pressed Ctrl+C!'
		atexit.register(curses.endwin)
		sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)


def main(argv):

	print argv, len(argv)
	
	fname = ""
	if len(argv):
		fname = argv[0]
		
	writetxt = "Python curses in action!"
	fd9 = 9 
	fd9obj = 0
	if fname != "":
		fobj = openAnything(fname)
		# to handle stdin, copy this object to a new file descriptor, 9
		os.dup2(fobj.fileno(), fd9)
		fd9obj = os.fdopen(fd9)
		#~ writetxt = fobj.readline(100) # max 100 chars read
		#~ fobj.close()

	# http://stackoverflow.com/questions/3999114/
	# We're finished with stdin. Duplicate inherited fd 3,
	# which contains a duplicate of the parent process' stdin,
	# into our stdin, at the OS level (assigning os.fdopen(3)
	# to sys.stdin or sys.__stdin__ does not work).
	#~ os.dup2(3, 0)
	# alt SO-3999114: duplicate /dev/tty
	ftty=open("/dev/tty")
	os.dup2(ftty.fileno(), 0)

	# Now curses can initialize.

	sys.stderr.write("before ")
	print "curses"
	try:
		myscreen = curses.initscr()
		#~ atexit.register(curses.endwin)
	except:
		print "Unexpected error:", sys.exc_info()[0]

	sys.stderr.write("after initscr") # this won't show, even if curseswin runs fine

	writetxt = fd9obj.readline(100)  # os.read(fd9, 100), max 100 bytes 

	# behaviour of getch - window.timeout(0) for non-blocking
	# or - window.nodelay(1) for non-blocking
	# note - non-blocking in 'plain' while loop eats CPU 
	#   so, must add some delay - either sleep, or set in timeout()
	myscreen.timeout(0) 
	
	#hide cursor
	#~ curses.curs_set(0)

	# initial draw
	drawFrame(myscreen, writetxt)

	# draw loop 
	c = 0
	while c != 113:
		c = myscreen.getch()
		# note, readline will include the \n too - sanitize
		writetxt = fd9obj.readline(100)  # os.read(fd9, 100), max 100 bytes			
		lwrt = len(writetxt)
		if lwrt>0:
			writetxt = writetxt[:lwrt-1]
			drawFrame(myscreen, writetxt)
		else:	# only sleep when no receive, for fastest response?
				# it goes too fast like that - but only for small ammt of lines (~10)
			time.sleep(0.001) # seconds; 0.001 - too fast for small, 0.01 is visible (buffered)
		myscreen.move(17, 25) # move cursor two spaces before 'str(c)'
		if c != -1: # for non-blocking, -1 is returned on nothing
			myscreen.addstr(17, 26, "           ")
			myscreen.addstr(17, 27, str(c))

	#~ curses.endwin()
	atexit.register(curses.endwin)
	
	ftty.close()
	fd9obj.close()
	fobj.close()
	
	sys.stderr.write("after end") # this won't show, even if curseswin runs fine


# run the main function - with arguments passed to script:
if __name__ == "__main__":
	main(sys.argv[1:])
	sys.stderr.write("after main1") # these won't show either, 
sys.stderr.write("after main2") 	#  (.. even if curseswin runs fine ..)
