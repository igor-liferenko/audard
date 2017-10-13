#!/usr/bin/env python 
# http://www.tuxradar.com/content/code-project-build-ncurses-ui-python
# http://diveintopython.org/scripts_and_streams/stdin_stdout_stderr.html
# http://bytes.com/topic/python/answers/42283-curses-disable-readline-replace-stdin
#
# NOTE: press 'q' to exit curses - Ctrl-C will screw up yer terminal

# ./testcurses-stdin.py "blabla" 					# works fine (curseswin shows)
# ./testcurses-stdin.py -	 					# works fine, (type, enter, curseswins shows):
# echo "blabla" | ./testcurses-stdin.py "sdsd"		# fails to raise curses window 
# 
# NOTE: when without pipe: termios.tcgetattr(sys.__stdin__.fileno()): [27906, 5, 1215, 35387, 15, 15, ['\x03', 
# NOTE: when with pipe |   : termios.tcgetattr(sys.__stdin__.fileno()): termios.error: (22, 'Invalid argument') 
#
# http://stackoverflow.com/questions/3999114/:
# MUST somehow duplicate the terminals' stdin:
# IF using os.dup2(3, 0), must use 'extern' redirect with bash, so call: 
# (echo "blabla" | ./testcurses-stdin.py -) 3<&0
# IF duplicating /dev/tty, call just with:
# echo "blabla" | ./testcurses-stdin.py -


import curses
import sys
import os
import atexit
import termios

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
	


def main(argv):

	print argv, len(argv)
	print "stdout/stdin (obj):", sys.__stdout__, sys.__stdin__ 
	print "stdout/stdin (fn):", sys.__stdout__.fileno(), sys.__stdin__.fileno()
	print "env(TERM):", os.environ.get('TERM'), os.environ.get("TERM", "unknown")
	
	stdin_term_attr = 0
	stdout_term_attr = 0
	std3_term_attr = 0
	try:
		stdin_term_attr = termios.tcgetattr(sys.__stdin__.fileno())
	except:
		stdin_term_attr = "%s::%s" % (sys.exc_info()[0], sys.exc_info()[1]) 
	try:
		stdout_term_attr = termios.tcgetattr(sys.__stdout__.fileno())
	except:
		stdout_term_attr = `sys.exc_info()[0]` + "::" + `sys.exc_info()[1]` 
	try:
		std3_term_attr = termios.tcgetattr(3)
	except:
		std3_term_attr = `sys.exc_info()[0]` + "::" + `sys.exc_info()[1]` 
	print "stdin_termios_attr", stdin_term_attr
	print "stdout_termios_attr", stdout_term_attr
	print "std3_termios_attr", std3_term_attr
	
	
	fname = ""
	if len(argv):
		fname = argv[0]
		
	writetxt = "Python curses in action!"
	if fname != "":
		print "opening", fname
		fobj = openAnything(fname)
		print "obj", fobj
		writetxt = fobj.readline(100) # max 100 chars read
		print "wr", writetxt
		fobj.close()
		print "at end"

	# http://stackoverflow.com/questions/3999114/
	# We're finished with stdin. Duplicate inherited fd 3,
	# which contains a duplicate of the parent process' stdin,
	# into our stdin, at the OS level (assigning os.fdopen(3)
	# to sys.stdin or sys.__stdin__ does not work).
	#~ os.dup2(3, 0)
	
	# alt SO-3999114: duplicate /dev/tty
	ftty=open("/dev/tty")
	os.dup2(ftty.fileno(), 0)
	stdtty_term_attr = 0
	try:
		stdtty_term_attr = termios.tcgetattr(0)
	except:
		stdtty_term_attr = "%s::%s" % (sys.exc_info()[0], sys.exc_info()[1]) 
	print "stdtty_term_attr", stdtty_term_attr

	# Now curses can initialize.

	sys.stderr.write("before ")
	print "curses", writetxt
	try:
		myscreen = curses.initscr()
		#~ atexit.register(curses.endwin)
	except:
		print "Unexpected error:", sys.exc_info()[0]

	sys.stderr.write("after initscr") # this won't show, even if curseswin runs fine

	myscreen.border(0)
	myscreen.addstr(12, 25, writetxt)
	myscreen.refresh()
	myscreen.getch()

	#~ curses.endwin()
	atexit.register(curses.endwin)
	
	sys.stderr.write("after end") # this won't show, even if curseswin runs fine


# run the main function - with arguments passed to script:
if __name__ == "__main__":
	main(sys.argv[1:])
	sys.stderr.write("after main1") # these won't show either, 
sys.stderr.write("after main2") 	#  (.. even if curseswin runs fine ..)
