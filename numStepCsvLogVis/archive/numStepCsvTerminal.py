#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes even on Unicode in comments

"""
# Part (archived) of the numStepCsvLogVis package
#
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()
versionf = scriptdir + os.sep + "VERSION"
try: __version__ = next(open(versionf))
except: __version__ = sys.exc_info()[1]

optargs = None
usagemsg = "numStepCsvTerminal.py ( %(prog)s ) v.{0}".format(__version__) + """
steps through CSV (with numeric data), outputting to terminal (python2.7/3.2)

Usage:
  cat example-syslog.csv | python numStepCsvTerminal.py -
  python numStepCsvTerminal.py example-syslog.csv
  python numStepCsvTerminal.py "@args.txt"

* Stdout/stderr is used for "step"/"playback" output
* Ctrl-C, or `q` in terminal to exit
* Comment char `#` only tolerated in header (first) line
  (data rows cannot be commented)
* When entering input in prompt, only Backspace works
  for modifying the input
* Cmdline args (one per line) - including filename -
  can be spec'd in a file, prepended with @

Columnspec for csv - string with format specifiers
prepended with `@`; column 0 is automatic row index, else
actual columns are 1-based (0 can be forced explicitly)
* @n1 or @(n1) - name of column 1
* @v1 or @(v1) - numeric value (of column 1 at current row)
* @V1 or @(V1) - numeric value, shown in engineering notation
* @s1 or @(s1) - string value (of column 1 at current row)
* @nv1 or @(nv1) - expanded name and value (c.r.) of current column (1)
* @:2 - same as @nv:2; exp name & val of cols up to 2 (1 and 2)
* @(:2-[1]+0.5) - exp name, and {value (c.r) - value (row 1) + 0.5} of columns 1 and 2

Step player commands:
 ARW  step next/back w/ arrow keys
 q    quit/exit
 g    go to line number/marker
 m    "add [name]" add marker
      "del [name]" del marker
 l    list markers (toggles in curses)
 p    playback [column step fps] (iff)
      (just ENTER - confirm last settings)
 SPC  space to toggle (stop/start) playback
      (Ctrl-Space for reverse/backwards play)
 ESC  cancel player command prompt (or exit!)
      (also for escape keys: left arrow..)
"""

"""
don't use print (complication with __future__);
a custom function based on sys.stdout.write works
for both Python 2.7 and 3.x
"""
def printso(*inargs):
  outstr = ""
  outstr = " ".join(list(map(str, inargs)))
  sys.stdout.write(outstr)
  sys.stdout.flush()

def printse(*inargs):
  outstr = ""
  outstr = " ".join(list(map(str, inargs)))
  sys.stderr.write(outstr)
  sys.stderr.flush()

CR = "\r"
LF = "\n"

printse("initializing... " )
# for help, add linefeed
if any(i in ["-h","--help"] for i in sys.argv): #("-h" in sys.argv):
  printse(LF)

"""
test for python2/python3 ; __future__ since python2.6
note: cannot import __future__ conditionally (compile-time statement)
(also, sometimes get a stdout lock at import urlopen, requiring
keypress - in that case, reboot, try again)
# make string input work with Python2 or Python3:
# Python2 uses raw_input() for strings
# Python3 uses input() for strings
(NB: preloading .so modules with ctypes or imp doesn't
work - have to respawn Python interpreter: e.g.:
sys.modules['_curses'] is the .so module
but that doesn't give us access to libncurses*.so from Python!
so have to respawn - in checkLoadCurses() )
"""
import __future__ # we can't use this really; keep it anyway
if sys.version_info[0] < 3:
  #printso("sys.version < 3\n")
  from urlparse import urlparse
  from urllib import urlopen
  from StringIO import StringIO
  text_type = unicode
  binary_type = str
  input = raw_input
  def b(x):
    return x
  def u(x):
    return unicode(x, "utf-8")
  def ut(a1, *args): # wrong utf-8 length!
    return str(a1)
  def utt(x):
    return x.encode("utf-8")
  def utd(x): # works if x str
    return x.decode("utf-8")
  #tkinterFound = pu_find_module("Tkinter") # instead of try: import Tkinter as tk
  tkmstr = "Tkinter"
else:
  #printso("sys.version >= 3\n")
  from urllib.request import urlopen
  from urllib.parse import urlparse
  from io import StringIO
  text_type = str
  binary_type = bytes
  import codecs
  def b(x):
    return codecs.latin_1_encode(x)[0]
  def u(x):
    return x
  ut = str
  def utt(x):
    return str(x)
  def utd(x): # if x is bytes
    return x.decode("utf-8")
  #tkinterFound = pu_find_module("tkinter") # instead of try: import tkinter as tk
  tkmstr = "tkinter"


"""
rest of imports that work the same for 2.7 and 3.x:
"""
import linecache
import re
import pprint # for debugging
import collections # OrderedDict, 2.7+
import argparse # command line options (instead of getopt), included in Py 2.7+ (easy_install for 2.6)
import platform # for getTerminalSize
import threading # threads
import os # needed for file mod. dates, getTerminalSize (+exec)
import time # sleep
import signal # Ctrl-C (SIGINT) handler
import atexit # at exit, recover terminal settings (at least)
#import textwrap # doesn't break at special chars, made custom
import math # isnan()
cursesFound = False
try:
  import curses
  cursesFound = True # check for libncursesw - in checkLoadCurses()
except: pass

import locale # may be needed for curses (unix only)/Unicode
locale.setlocale(locale.LC_ALL, '')
code = locale.getpreferredencoding()
if sys.version_info[0] < 3: # may have influence on 2.7 curses
  reload(sys)
  sys.setdefaultencoding("utf-8")


# ##################### FUNCTIONS     ##########################################

def signalINT_handler(signal, frame):
  printse( LF + "You pressed Ctrl+C ({0})! Exiting.".format(os.path.basename(sys.argv[0])), LF)
  exiter()
signal.signal(signal.SIGINT, signalINT_handler)

def openAnything(source):
  """URI, filename, or string --> stream
  based on http://diveintopython.org/xml_processing/index.html#kgp.divein
  This function lets you define parsers that take any input source
  (URL, pathname to local or network file, or actual data as a string)
  and deal with it in a uniform manner.  Returned object is guaranteed
  to have all the basic stdio read methods (read, readline, readlines).
  Just .close() the object when you're done with it.

  test:
  a=openAnything("http://www.yahoo.com"); printso( inputSrcType, a, a.readline() )
  a=openAnything("here a string"); printso( inputSrcType, a, a.readline() )
  a=openAnything("notes.txt"); printso( inputSrcType, a, a.readline() )

  python2.7:
  2 <addinfourl at 151249676 whose fp = <socket._fileobject object at 0x902e96c>> <!DOCTYPE html>
  4 <StringIO.StringIO instance at 0x904a6ac> here a string
  3 <open file 'notes.txt', mode 'r' at 0x8fd0f40> There is this:

  python3.2:
  2 <http.client.HTTPResponse object at 0xb727322c> b'<!DOCTYPE html>\n'
  4 <_io.StringIO object at 0xb7268e6c> here a string
  3 <_io.TextIOWrapper name='notes.txt' mode='r' encoding='UTF-8'> There is this:
  """
  global inputSrcType

  if hasattr(source, "read"):
    inputSrcType = 0
    return source

  if source == '-':
    inputSrcType = 1
    return sys.stdin

  # try to open with native open function (if source is pathname)
  # moving this up because of py2 (urlopen catches local files there)
  # but keeping inputSrcType = 3
  try:
    inputSrcType = 3
    return open(source)
  except (IOError, OSError):
    pass

  # try to open with urllib (if source is http, ftp, or file URL)
  #~ import urllib
  try:
    inputSrcType = 2
    return urlopen(source)
  except (IOError, OSError, ValueError): # ValueError for py3
    pass

  # treat source as string
  #~ import StringIO
  inputSrcType = 4
  return StringIO(str(source))

"""
getTerminalSize cross-platform
http://stackoverflow.com/questions/566746/how-to-get-console-window-width-in-python/6550596#6550596
"""
def getTerminalSize():
  #import platform
  current_os = platform.system()
  tuple_xy=None
  if current_os == 'Windows':
      tuple_xy = _getTerminalSize_windows()
      if tuple_xy is None:
        tuple_xy = _getTerminalSize_tput()
        # needed for window's python in cygwin's xterm!
  if current_os == 'Linux' or current_os == 'Darwin' or  current_os.startswith('CYGWIN'):
      tuple_xy = _getTerminalSize_linux()
  if tuple_xy is None:
      printse("default", LF)
      tuple_xy = (80, 25)      # default value
  return tuple_xy
def _getTerminalSize_windows():
  res=None
  try:
    from ctypes import windll, create_string_buffer
    # stdin handle is -10
    # stdout handle is -11
    # stderr handle is -12
    h = windll.kernel32.GetStdHandle(-12)
    csbi = create_string_buffer(22)
    res = windll.kernel32.GetConsoleScreenBufferInfo(h, csbi)
  except:
    return None
  if res:
    import struct
    (bufx, bufy, curx, cury, wattr,
     left, top, right, bottom, maxx, maxy) = struct.unpack("hhhhHhhhhhh", csbi.raw)
    sizex = right - left + 1
    sizey = bottom - top + 1
    return sizex, sizey
  else:
    return None
def _getTerminalSize_tput():
    # get terminal width
    # src: http://stackoverflow.com/questions/263890/how-do-i-find-the-width-height-of-a-terminal-window
    try:
      import subprocess
      proc=subprocess.Popen(["tput", "cols"],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
      output=proc.communicate(input=None)
      cols=int(output[0])
      proc=subprocess.Popen(["tput", "lines"],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
      output=proc.communicate(input=None)
      rows=int(output[0])
      return (cols,rows)
    except:
      return None
def _getTerminalSize_linux():
  #import os
  env = os.environ
  def ioctl_GWINSZ(fd):
    try:
      import fcntl, termios, struct #, os
      cr = struct.unpack('hh', fcntl.ioctl(fd, termios.TIOCGWINSZ,'1234'))
    except:
      return None
    return cr
  def terminal_size(fd):
    try:
      import fcntl, termios, struct
      h, w, hp, wp = struct.unpack('HHHH',
        fcntl.ioctl(fd, termios.TIOCGWINSZ,
        struct.pack('HHHH', 0, 0, 0, 0)))
      cr = h, w #return w, h
    except:
      return None
    return cr
  # try terminal_size - stdin, stdout, stderr
  cr = terminal_size(1)
  # try ioctl_GWINSZ - stdin, stdout, stderr
  if not cr:
    cr = ioctl_GWINSZ(0) or ioctl_GWINSZ(1) or ioctl_GWINSZ(2)
  # try os.ctermid()
  if not cr:
    try:
      fd = os.open(os.ctermid(), os.O_RDONLY)
      cr = ioctl_GWINSZ(fd)
      os.close(fd)
    except:
      pass
  # try `stty size`
  if not cr:
    try:
      cr = tuple(int(x) for x in os.popen("stty size", "r").read().split())
    except:
      pass
  # try environment variables (should fail - LINES, COLUMNS are not exported by bash!)
  if not cr:
    try:
      cr = (env['LINES'], env['COLUMNS'])
    except:
      pass
  if not cr:
    try:
      cr = (int(os.getenv('LINES')), int(os.getenv('COLUMNS')))
    except:
      return None
  return int(cr[1]), int(cr[0])

"""
getch cross-platform
http://code.activestate.com/recipes/134892-getch-like-unbuffered-character-reading-from-stdin/
we may be using stdin, so fd = sys.stdin.fileno() will fail;
use /dev/tty instead (SO: 7141331)
ttfo = open('/dev/tty') # this is causing buffered reads;
but os.read instead of ttfo.read works to make it unbuffered (Unix)!
Tried also #ttfo = os.fdopen(ttfob.fileno(), 'rb', 0); to
re-open via fileno for unbuff; but problem - not a tty!
Going with global ttfo object instead of stdin (due piping):
fd = ttfo.fileno() #sys.stdin.fileno();
so we can open the file only once and keep on using it
(without constant re-opening and closing; which may screw
up multi-byte keypress sequences);
Note that tty.setraw, and back to old_settings (Unix), must be
done at each call - else the terminal gets screwed up!
Also: ch = os.read(ttfo.fileno(), 1) #ttfo.read(1) # sys.stdin.read(1)
... note that both # ttfo.read(1) and os.read() may be blocking:
but but ttfo.read() is buffered, and causes the OS to
think stdin buffer is exhausted - os.read() is unbuffered
Also, must specify termios.tcsetattr to termios.TCSANOW -
otherwise settings (attrs) are applied (set) ONLY after
stdin buffer is drained (on #.TCSADRAIN)!
To suppress stdin echoing (keypress printout) in terminal,
there is enable_echo; but must use @staticmethod there
for Python2.7 (so it doesn't TypeError: unbound method)
Also, MUST fix ICANON here - else backspace (127) is "eaten"
by "terminal", so must press it a lot of times before kbd
navigation thread detects it!
"""
ttfo = None
class _Getch:
  """Gets a single character from standard input. Does not echo to the
screen."""
  def __init__(self):
    try:
      self.impl = _GetchWindows()
    except ImportError:
      try:
        self.impl = _GetchMacCarbon()
      except(AttributeError, ImportError):
        self.impl = _GetchUnix()
  def __call__(self): return self.impl()
class _GetchUnix:
  fd = -1 # static property
  @staticmethod
  def enable_echo(fd, enabled):
    import termios
    """ http://blog.hartwork.org/?p=1498 """
    (iflag, oflag, cflag, lflag, ispeed, ospeed, cc) \
      = termios.tcgetattr(fd)
    if enabled:     lflag |= (termios.ECHO | termios.ICANON)
    else:           lflag &= ~(termios.ECHO | termios.ICANON)
    new_attr = [iflag, oflag, cflag, lflag, ispeed, ospeed, cc]
    termios.tcsetattr(fd, termios.TCSANOW, new_attr)
  def __init__(self):
    import tty, termios#, sys
    global ttfo
    ttfo = open('/dev/tty')
    fd = ttfo.fileno()
    _GetchUnix.enable_echo(fd, False)
    _GetchUnix.fd = fd
    # recover terminal on exit - but atexit may fail on
    # improper pipes (don't do explicitly in exiter)
    atexit.register(_GetchUnix.enable_echo, _GetchUnix.fd, True)
  def __call__(self):
    import tty, termios #, sys,
    global ttfo
    old_settings = termios.tcgetattr(ttfo.fileno())
    try:
      tty.setraw(ttfo.fileno(), termios.TCSANOW)
      # os.read -blocking, but unbuffered:
      ch = os.read(ttfo.fileno(), 1)
    finally:
      termios.tcsetattr(ttfo.fileno(), termios.TCSANOW, old_settings)
    return ch
class _GetchWindows:
  def __init__(self):
    import msvcrt
  def __call__(self):
    import msvcrt
    return msvcrt.getch()
class _GetchMacCarbon:
  def __init__(self):
    import Carbon
    Carbon.Evt #see if it has this (in Unix, it doesn't)
  def __call__(self):
    import Carbon
    if Carbon.Evt.EventAvail(0x0008)[0]==0: # 0x0008 is the keyDownMask
      return ''
    else:
      (what,msg,when,where,mod)=Carbon.Evt.GetNextEvent(0x0008)[1]
      return chr(msg & 0x000000FF)

"""
kbhit cross-platform - to simulate non-blocking IO
"""
class _Kbhit:
  """Returns true if there are characters to be read."""
  def __init__(self):
    try:
      self.impl = _KbhitWindows()
    except ImportError:
      self.impl = _KbhitUnix()
  def __call__(self): return self.impl()
class _KbhitUnix:
  def __init__(self):
    import tty#, sys
  def __call__(self):
    import tty, termios, select #, sys,
    global ttfo
    old_settings = termios.tcgetattr(ttfo.fileno())
    ret=None
    try:
      tty.setraw(ttfo.fileno(), termios.TCSANOW)
      # non-blocking (timeout=0: poll (return immediately)):
      [i, o, e] = select.select([ttfo.fileno()], [], [], 0)
      if i: ret=True
      else: ret=False
    finally:
      termios.tcsetattr(ttfo.fileno(), termios.TCSANOW, old_settings)
      #printse("kbhit:", [i, o, e], "\n")
      pass
    return ret
class _KbhitWindows:
  def __init__(self):
    import msvcrt
  def __call__(self):
    import msvcrt
    return msvcrt.kbhit()


"""
create an instance of what will be getch() (aka inkey()) function;
and kbhit() function:
Do later in init conditionally (if not loading curses)
"""
getch = None #_Getch()
kbhit = None #_Kbhit()
"""
TODO: master (m_)term_enable_echo (evenutally make cross-platform)
"""
def m_term_enable_echo(inEnable):
  _GetchUnix.enable_echo(ttfo.fileno(), inEnable)


"""
Converts number to fixed-string-length engineering notation string:
e.g. -004.500e+00 ; +161.695e+12 ; +008.482e-15
"""
def myFormatEng(innum):
  innum = float(innum)
  # grab normalized exponent first:
  # {:0=+12.3e} gives +001.587e+01
  numrep1 = "{:0=+12.3e}".format(innum)
  exp1 = numrep1[numrep1.find("e")+1:]
  exp1i = int(exp1)
  engexp = (exp1i//3)*3
  numrepe = "{:0=+8.3f}e{:0=+3d}".format(innum/(10**engexp),engexp)
  return numrepe

"""
converts number to fixed-string-length engineering notation,
but with some trailing and leading zeroes replaced with spaces
SIp - SI prefixes dict
"""
SIp = {-18: "a", -15: "f", -12: "p", -9: "n", -6: "μ", -3: "m", 0: " ", 3: "k", 6: "M", 9: "G", 12: "T", 15: "P"}
def myFormatEngB(innum):
  innum = float(innum)
  if math.isnan(innum):
    return "NaN"
  else:
    # grab normalized exponent first:
    # {:0=+12.3e} gives +001.587e+01
    numrep1 = "{:0=+12.3e}".format(innum)
    exp1 = numrep1[numrep1.find("e")+1:]
    exp1i = int(exp1)
    engexp = (exp1i//3)*3
    # format %g {:g} removes trailing zeroes - I
    # want to replace them with space
    numrepe = "{: > 8.3f}{:s}".format(innum/(10**engexp),SIp[engexp])
    if engexp == 0:
      numrepea = list(numrepe)
      endind = len(numrepea)-2
      while (numrepea[endind] == "0"):
        numrepea[endind] = " "
        endind -= 1
      if (numrepea[endind] == "."):
        if (numrepea[endind+1] == " "):
          numrepea[endind] = " "
      numrepe = "".join(numrepea)
    return numrepe

"""
A container class for CSV data:
* If we're reading from a local file, then we can use linecache,
and we don't need to store any data in the container class;
* Otherwise, we have to copy csv data in this class instance
as "RAM_contents".
Since the entire data may not be received in one go (stdin, or a
file continuously being updated - see genCsvLines.py), we have to
update the state of the container class instance continuously (use
threads).
In any case, the class should have the latest number of CSV (data)
lines (either in RAM memory - or in the local file, if using linecache);
and the columns' names read from the header.
addContentsToRAM: adding raw strings there - so both linecache and RAM
can utilize the same splitter/reproduction function, acting on a CSV
string; also keeps numrows synced to length of contents
parseHeaderLine: remove any initial comment chars: "# "; split on comma,
and depending on optargs, get or generate column names; if generating,
then first row is data, so insert it as such. Also, don't set
isCsvHeaderParsed - allow the threads to set it.
printCurrentLine prints both contents and status line, and pads
the idstr depending on space taken by total number of rows. It
also beeps (by printing audio bell - '\a') if we're at limits
(start or end) of data, and no move is to be made.
numrows should be (1-based) count of __only__ data rows (disregarding
header!) - but for linecache, that also needs to be handled in reading
thread...
Only updateNumRows should handle the numrows count (not addContentsToRAM etc.)
updateNumRows assumes that either on disk, or in RAM, there is a
properly formatted CSV (either with one header line or without, and
otherwise a sequence of proper numeric uncommented data rows).
updateNumRows adjusts __only__ data rows just for linecache - for RAM,
that should be handled by parseHeaderLine
currow now 1-based everywhere - let printCurrentLine take it into account,
and calculate proper index depending on RAM or disk
handleGotoCmd should printCurrentLine even if promptBuffer == "" - if the
command is cancelled, that will update the row display!
In handleGotoCmd, check for self.isRunning, to handle Ctrl-C pressed during prompt
In getFormattedLine (and printDiscontinuityLine), must use
len(u(idstr)) to get the right ammount of characters in
Python 2.7 - however, must NOT return u(idstr) from getIdStr -
that will cause breakage elsewhere in Python 2.7!
parseColRangeSpec: ":4,7,9:" -> [1, 2, 3, 4, 7, 9, 10, 11, 12]
coldsws does not need init to [0]*(len(self.columnnames)+1), because
width of (implied) column 0 (ID) is basically len(str(numrows))
Note: in case of spec '@(v2-[1])', ' -- ', '@(v2)'; first val may be "0",
the other "1000" - and then valwidth would work with the larger of both!
So valwidth should work per value in columnspec - not per column(s) per se!
Also, python2.7 gives the string as is in result from eval; python 3.2
gives the string with a lot more decimals (float).
addNewline - simply to ignore adding LF's when in curses mode; also
printDiscontinuityLine now prints only if not in curses mode
In waitForRow: # in case currow is validated in the linelimits range;
# but the file/stdin has not yet loaded that line,
# then wait for currow line to be available
# (if it is available, the while loop shouldn't even run)
In handleGotoCmd: # the call if self.termmode == "curses": curses.doupdate()
# after printCurrentLine; to make sure leftover input chars are erased
# is not needed anymore - with redrawln marking space blanking!
In handleListMarkersCmd(self): #self.cInfoPad.addstr(1,1, repstr)
# adding multiline string messes border - must addstr each line individually
In  playerThread - if nextCondition():
#printso(CR)       # blank current line with prompt
#self.blankAndCR()  # with these, Py2.7 can sometimes mess up the CRs
# (without - also mess up, also 3.2, but less)
In  playerThread # printCurrentLine prints an extra line at end of playback
# also in case of dump_formatted! So just print status line
In handlePlayToggleCmd: # this below causes double output
#self.promptResultMsg = "playback stopped"
#self.printCurrentLine()
In parseColRangeSpec : colinds = [] is a signal for:
#self.promptResultMsg += "Cannot parse ColRangeSpec "
In expandColumnspec: #self.coldsws.append(0) # here only indexes values,
# can introduce a problem (intialize coldsws later)
In getTextWrapped # managed text wrap means
# that the last wrapped string is remembered;
# the current string to be wrapped is compared to the last;
# and actual calculcation of wrapping indices happens only if
# current string is bigger than the last; this helps preserve
# whitespace of CSV columnspec formatted values; but also
# interferes with stringmode! (so, disable managed for
# stringmode - but do this from caller)
# also # iterator[im-2].span()[1] # not subscriptable
In printCurrentLine #self.cscreen.refresh() # no help for
# form vals scrolling # actually, avoid callind cscreen.refresh()
# now that noutrefresh elsewhere - it is also needed
#at cRawLinesCtxFrame.noutrefresh !
# nb: just touchwin() doesn't work! and OUT of loop!
# at cFormatdValsFrame.noutrefresh():
##self.cFormatdValsFrame.touchwin()
##self.cIFValsFrame.touchwin() # BAD!
##self.cscreen.noutrefresh()  # must be here so framevals is updates? but corrupts - noutrefresh also corrupts;
##   but only if updatecIFValsFrame uses refresh(); if it uses noutrefresh(), then
##   it doesn't corrupt here - but it's not really needed?!
# at self.printStatusLine()
##self.cscreen.noutrefresh() # here blanks everything now!
##curses.doupdate() # introduces a tiny ammount of flicker (esp. when keyboard stepping) - but makes sure leftover input chars are erased (don't use here)
In outputBottomString() - at if self.termmode == "curses":
# from x=2, to skip blanking the border:
#if blank: # always blank bottom for ncurses?
# note: " "*(x-2) here now makes the curses form.vals dissapear!
# note: just blanking first here (to erase user input) was
# unreliable - curses.doupdate() needs to be called, else
# the engine thinks string has not changed - esp. obvious
# with goto numeric command -since the response with "(ok)"
# would be shorter than the user input; and so even this
# explicit addstr (pre-)blanking would NOT have erased input characters!
# (solved by calling curses.doupdate from handleGotoCmd;
# avoid calling that from printCurrentLine - it increases screen flicker then)
# however, now the pre-blanking works ONLY if a legitimate
# character is used "─"*(x-3) ; NOT when space! " "*(x-3)
# Ah - to have space blanking work, use redrawln (not touchline!)
# redrawln can stand before or after addstr - works all the same
# even this was unreliable, without doupdate() ... :
In handleCursesFocusToggleCmd
#self.drawNcursesFrame() # no need, printCurrentLine does it
In drawNcursesFrame - at start:
#self.cscreen.refresh() # immediate border corruption
in drawNcursesFrame: upd=True is needed for initial doupdate()
 (which otherwise causes flicker), specifically for Py2.7 (3.2
 is ok without it)
"""
class CsvContainer:
  def __init__(self):
    self.columnnames = []
    self.coldsws = [] # column data string widths (per columnspec)
    self.numrows = 0
    self.RAM_contents = []
    self.isStoredInRAM = False
    self.infilearg = ""
    self.infilebase = "" # basename (without last extension)
    self.infileObj = None
    self.inputSrcType = -1
    self.isCsvHeaderParsed = False
    self.lastmtime = 0.0
    self.isRunning = False  # thread exit control
    self.threads = []
    self.currow = 0 # current row index
    self.prevrow = 0 # previous row index - as in player (incl. goto jumps)
    self.directionStr = ""  # step direction indicator
    self.upChar = "▲"       # -||-
    self.downChar = "▼"     # -||-
    self.isPromptingUserInput = False
    self.promptStr = " :: "
    self.promptBuffer = ""
    self.promptResultMsg = ""
    # self.promptInputThreadID = None
    self.markers = []   # contains [linenum, "name"]
    self.markChar = "*"
    self.expColSpecA = [] # expCSpec
    self.patInnerSpec = re.compile(r'([@\(\)]+)')
    self.patICmdSpec = re.compile(r'([nvVs])') # note here "command" == "format specifier"
                                              # no need for `^` - .match only for start;
                                              # no need for `()` - except for individual character split
    self.patColSpec = re.compile(r'(@\([\S]+?\)|@\(*[0-9nvVs:,\[\]\.\-\+]+\)*)')
    self.patIInnerSpec = re.compile(r'(\[[^\]]+\]|[\-\+]|[nvVs]+)') #re.compile(r'([\-\+]|[nv]+)') # (r'([0-9\[\]\.\-]+)') # only split on plus/minus, and on command (n, v, nv, s) expected at start; but stuff in [] as a whole!
    self.patRowRef = re.compile(r'(\[.+\])')
    self.patbreakchars = re.compile(r'[-,\s]')
    self.wraplaststr = ""   # last string to be wrapped (for managed wrapping)
    self.wrapsplitinds = [] # last wrap split indices (for managed wrapping)
    self.wrapAtlast = -1    # last wrapAt (to detect changes in terminal size, and force recalc)
    self.playerSettings = [0, 1.0, 2.0]
    self.isPlaying = False
    self.cancelMsg = "cancelled; "
    self.playThreadID = None
    self.playerDirection = 0 # 1: play forward; -1: play backward
    self.playFrameCount = 0  # frame counter (incl. steps) when playing; reset at each play (not really used)
    self.linelimits = []  # limit player to this set of lines [start:end]
    self.disableStatusLine = False # only used for dumping
    self.termmode = "default" # can be "default" or "curses"
    self.cscreen = None   # ref to curses screen/window
    self.cscreensz = []   # y, x - last curses screen/window size
    self.cInfoPad = None  # ref to curses Info subpad
    self.cIInfoPad = None # ref to curses (inner) Info newpad
    self.cIInfoSet = []   # settings: scrollpos, beginy/x, h/w, padh/w
    self.cRawLinesCtxFrame = None # ref to curses "rawlines context" frame
    self.cFormatdValsFrame = None # ref to curses "formatted values" frame
    self.cIFValsFrame = None      # ref to curses inner "formatted values" frame
    self.cIFValsSet = []          # settings: scrollpos, beginy/x, h/w, padh/w
    self.ccrlChar = ">"   # current curses rawline indicator char
    self.cFocus = 0    # current focus in curses window (0 or 1:cFormatdValsFrame); cannot ref frames directly as they are reconstructed
    self.fdX    = -1    # extra reopen of input file to handle stdin for curses
    self.fdXobj = None  # -||-
    self.scriptdir = os.path.dirname(os.path.realpath(__file__))
    self.calldir = os.getcwd()
    self.infiledir = None # populate this, only if input file (from arg) is on local disk filesystem
  def addContentsToRAM(self, inline):
    self.RAM_contents.append(inline)
  def parseHeaderLine(self, inline):
    global optargs
    inline = inline.rstrip() # chomp
    initcommentpat = re.compile(r'^[#\s]*')
    inline_uncomm = initcommentpat.sub("", inline)
    if optargs.no_header_line:
      if self.isStoredInRAM:
        self.addContentsToRAM(inline_uncomm)
      for ix, istr in enumerate(inline_uncomm.split(",")):
        tcolname = "COL"+str(ix)
        self.columnnames.append(tcolname)
    else:
      for istr in inline_uncomm.split(","):
        self.columnnames.append(istr)
  def updateNumRows(self):
    if self.isStoredInRAM:
      self.numrows = len(self.RAM_contents)
    else:
      self.numrows = mapcount(self.infilearg)
      if not(optargs.no_header_line):
        self.numrows = self.numrows - 1
  def waitForRow(self, inrow):
    notstarted = True
    while(self.numrows < inrow):
      if notstarted:
        self.promptResultMsg += "wait for line"
        self.printStatusLine(blank=True)
        notstarted = False
      time.sleep(0.01)
  def setCurrow(self, inval):
    self.waitForRow(inval)
    self.prevrow = self.currow
    self.currow = inval
  def moveToFirstRow(self):
    minrow, maxrow = self.getLogfileLineLimits()
    if self.currow != minrow:
      if (abs(self.currow-1) > 1):
        self.printDiscontinuityLine()
      if self.currow > minrow: self.directionStr = self.downChar
      else:                    self.directionStr = self.upChar
      self.setCurrow(minrow)
      didMove = True
    else:
      self.directionStr = " "
      didMove = False
    return didMove
  def moveToPreviousRow(self):
    minrow, maxrow = self.getLogfileLineLimits()
    if self.currow > minrow:
      self.setCurrow(self.currow - 1)
      self.directionStr = self.downChar
      didMove = True
    else:
      self.directionStr = " "
      didMove = False
    return didMove
  def moveToNextRow(self):
    minrow, maxrow = self.getLogfileLineLimits()
    if self.currow < maxrow:
      self.setCurrow(self.currow + 1)
      self.directionStr = self.upChar
      didMove = True
    else:
      self.directionStr = " "
      didMove = False
    return didMove
  def moveToRowIndex(self, rowind1b):
    minrow, maxrow = self.getLogfileLineLimits()
    if (rowind1b < minrow):
      self.promptResultMsg = "Unhandled/invalid line # {0}, going to {1}; ".format(rowind1b, minrow)
      rowind1b = minrow
    elif (rowind1b > maxrow):
      self.promptResultMsg = "Unhandled/invalid line # {0}, going to {1}; ".format(rowind1b, maxrow)
      rowind1b = maxrow
    if self.currow != rowind1b:
      if (abs(self.currow-rowind1b) > 1):
        self.printDiscontinuityLine()
      if self.currow > rowind1b:  self.directionStr = self.downChar
      else:                       self.directionStr = self.upChar
      self.setCurrow(rowind1b)
      self.promptResultMsg += "ok"
      didMove = True
    else:
      self.directionStr = " "
      self.promptResultMsg += "no move"
      didMove = False
    return didMove
  def blankAndCR(self):
    printso(CR)       # blank current line with prompt
    mystr = " ".ljust( getTerminalSize()[0]-1, ' ')
    printso(mystr + CR)
  def addNewline(self):
    if not (self.termmode == "curses"):
      printso(LF)
  def handleGotoCmd(self):
    self.promptBuffer = ""
    self.isPromptingUserInput = True
    promptAskStr = self.promptStr + "Goto line number/marker? "
    self.outputBottomString(promptAskStr, blank=True)
    # wait either for ending of proper input, or cancel:
    while self.isPromptingUserInput and self.isRunning:
      time.sleep(0.01)
    self.isPromptingUserInput = False
    if not(self.isRunning): return
    isPromptInteger = False
    promptInteger = -1
    if not(self.promptBuffer == ""):
      try:    promptInteger = int(self.promptBuffer)
      except: pass
      if self.promptBuffer == str(promptInteger):
        isPromptInteger = True
      if isPromptInteger:
        self.addNewline()
        self.moveToRowIndex(promptInteger)
        self.printCurrentLine()
      else: # prompt may be marker name
        markFound = -1
        for imarker in self.markers:
          if imarker[1] == self.promptBuffer:
            markFound = imarker[0]
            break
        if markFound != -1: # found
          self.addNewline()
          self.moveToRowIndex(markFound)
          self.printCurrentLine()
        else:
          self.promptResultMsg = "Goto line # or marker not found; "
          self.addNewline()
          self.printCurrentLine()
    else: # empty promptBuffer - possibly cancelled
      self.directionStr = " "
      self.printCurrentLine(blank=True)
  def handleMarkerCmd(self):
    self.promptBuffer = ""
    self.isPromptingUserInput = True
    promptAskStr = self.promptStr + "Marker command (add/del)? "
    self.outputBottomString(promptAskStr, blank=True)
    while self.isPromptingUserInput and self.isRunning:
      time.sleep(0.01)
    self.isPromptingUserInput = False
    if not(self.isRunning): return
    if not(self.promptBuffer == ""):
      promptwords = self.promptBuffer.split(" ")
      if promptwords[0] == "add":
        if len(promptwords)>1:  tname = promptwords[1]
        else:                   tname = "m" + str(len(self.markers))
        self.markers.append([self.currow, tname])
        self.promptResultMsg = "Added marker `{0}` at line # {1}; ".format(tname, self.currow)
      elif promptwords[0] == "del":
        tname = ""
        if len(promptwords)>1:  tname = promptwords[1]
        markfound = -1
        for ix, imarker in enumerate(self.markers):
          if tname != "":
            if imarker[1] == tname:
              markfound = ix
              break
          else:
            if imarker[0] == self.currow:
              markfound = ix
              break
        if markfound > -1:
          try:
            self.promptResultMsg = "Deleted marker `{0}` at line # {1}; ".format(self.markers[markfound][1], self.markers[markfound][0])
            self.markers.pop(markfound)
          except:
            self.promptResultMsg = "Cannot delete marker `{0}`/at line # {1}; ".format(tname, markfound)
        else:
          self.promptResultMsg = "Cannot find marker `{0}`/at line # {1}; ".format(tname, self.currow)
      else:
        self.promptResultMsg = "Invalid marker command `{0}`; ".format(self.promptBuffer)
    #else: # empty promptBuffer - possibly cancelled
    # reprint line explicitly here:
    self.directionStr = " "
    self.printCurrentLine(blank=True)
  def updatecIInfoPad(self):
    scrposy,scrposx, begin_y, begin_x, hlines,wcols, padhlines,padwcols = self.cIInfoSet
    self.cIInfoPad.refresh(scrposy,scrposx, begin_y+1,begin_x+1, begin_y+hlines-2, begin_x+wcols-2)
  def updatecIFValsFrame(self):
    scrposy,scrposx, begin_y, begin_x, hlines,wcols, padhlines,padwcols = self.cIFValsSet
    # .refresh() may cause corruption during playback - noutrefresh doesn't
    self.cIFValsFrame.noutrefresh(scrposy,scrposx, begin_y,begin_x, begin_y+hlines, begin_x+wcols-1)
  def handleListMarkersCmd(self):
    repstra = ["Markers list:"] # list()
    if len(self.markers) > 0:
      for ix, imarker in enumerate(self.markers):
        repstra.append( " {0}: [{1}, \"{2}\"]".format(ix, imarker[0], imarker[1]) )
    else:
      repstra.append("No markers.")
    if self.termmode == "default":
      self.blankAndCR()
      printso( LF.join(repstra) + LF*2 )
      self.directionStr = " "
      self.printCurrentLine()
    elif self.termmode == "curses": # 'l'ist toggles pad in curses mode
      if self.cInfoPad is None:
        hs, ws = self.cscreen.getmaxyx()
        begin_y = 5 ; begin_x = 5
        hlines = hs - 2*begin_y
        if hlines < begin_y: hlines = begin_y
        wcols = ws - 2*begin_x
        if wcols < begin_x: wcols = begin_x
        self.cInfoPad = self.cscreen.subpad(hlines, wcols, begin_y, begin_x)
        self.cInfoPad.erase()
        self.cInfoPad.border(0)
        padhlines = len(repstra)+1
        padwcols = 0
        for line in repstra:
          if len(line) > padwcols: padwcols = len(line)
        padwcols += 1 # else it breaks at last char
        scrposy = scrposx = 0
        self.cIInfoSet = [scrposy,scrposx, begin_y, begin_x, hlines,wcols, padhlines,padwcols]
        self.cIInfoPad = curses.newpad(padhlines, padwcols)
        self.cIInfoPad.idlok(1)
        self.cIInfoPad.scrollok(1)
        for iy, line in enumerate(repstra):
          self.cIInfoPad.addstr(padhlines-1,0, line)#(1+iy,1, line)
          self.cIInfoPad.scroll(1)
        self.cInfoPad.refresh()
        self.cInfoPad.touchwin()
        self.updatecIInfoPad()
      else: # destroy/hide pad if it exists
        self.cInfoPad = None # not "del self.cInfoPad"
        self.cIInfoPad = None
        self.cscreen.touchwin()
        self.cscreen.refresh()
        self.printCurrentLine() # refresh display
  def parsePlayerSettings(self, insetstr):
    shouldPlay = False
    if not(insetstr == ""):
      promptwords = insetstr.split(" ")
      oldps = self.playerSettings
      try:
        self.playerSettings[0] = int(promptwords[0])
        self.playerSettings[1] = float(promptwords[1])
        self.playerSettings[2] = float(promptwords[2])
        shouldPlay = True
      except:
        self.playerSettings = oldps
    return shouldPlay
  def parseLineLimits(self, insetstr):
    global optparser
    global optargs
    isParsed = False
    limitsa = []
    repstr = "Line limits: "
    try:
      limitsa = list(map(int, insetstr.split(":")))
      repstr += "start: "
      if limitsa[0] < 1:
        limitsa[0] = 1
        repstr += "defaulting to 1; "
      else:
        repstr += "{0} ".format(limitsa[0])
      repstr += "end: "
      if limitsa[1] < 0:
        limitsa[1] = 0
        repstr += "defaulting to 0; "
      elif limitsa[1] > 0 and limitsa[1] < limitsa[0]:
        limitsa[1] = 0
        repstr += "defaulting to 0; "
      else:
        repstr += "{0}{1} ".format(limitsa[1], " (last)" if limitsa[1]==0 else "")
    except:
      origdefaults = optparser._option_string_actions['--line-limits'].default
      limitsa = list(map(int, origdefaults.split(":")))
      repstr += "problem with parsing; defaulting to {0}:{1}".format(limitsa[0],limitsa[1])
    self.linelimits = limitsa
    if not(optargs.quiet):
      printse(repstr + LF)
  def handlePlayCmd(self):
    self.promptBuffer = ""
    self.isPromptingUserInput = True
    promptAskStr = self.promptStr + "Play [" + " ".join(map(str, self.playerSettings)) + "]? "
    self.outputBottomString(promptAskStr, blank=True)
    while self.isPromptingUserInput and self.isRunning:
      time.sleep(0.01)
    self.isPromptingUserInput = False
    if not(self.isRunning): return
    # here can compare promptResultMsg to csvCO.cancelMsg, to see if cancelled
    shouldPlay = False
    if not(self.promptResultMsg == self.cancelMsg):
      if not(self.promptBuffer == ""):
        shouldPlay = self.parsePlayerSettings(self.promptBuffer)
        if not(shouldPlay):
          self.promptResultMsg = "Invalid player spec `{0}`; ".format(self.promptBuffer)
      else: # promptBuffer == "" (but if no cancel message, it is a shortcut to start playing)
        shouldPlay = True
    if shouldPlay: # startup playback thread
      self.isPlaying = True
      self.playThreadID = threading.Thread(target=self.playerThread)
      self.playThreadID.start()
    # reprint line explicitly here:
    self.directionStr = " "
    self.printCurrentLine(blank=True)
  def getLogfileLineLimits(self):
    # self.linelimits should be validated by this time,
    # so the below checks should be enough:
    minrow = 1 ; maxrow = self.numrows
    if self.linelimits[0] > minrow: minrow = self.linelimits[0]
    if self.linelimits[1] > 0:      maxrow = self.linelimits[1]
    return minrow, maxrow
  def playerThread(self):
    global optargs
    colind = self.playerSettings[0]
    step = self.playerSettings[1]
    fps = self.playerSettings[2]
    periodsec = 1.0/fps
    if colind > 0:
      trline = self.getRawDataLine(self.currow)
      startoffset = float(trline.split(",")[colind-1])
    else:
      startoffset = self.currow
    itime = startoffset
    minrow, maxrow = self.getLogfileLineLimits()
    if   self.playerDirection== 1:
      def playCondition(): return (self.currow<maxrow)
      def nextCondition(): return (itime >= nextrowtime)
    elif self.playerDirection==-1:
      def playCondition(): return (self.currow>minrow)
      def nextCondition(): return (itime < nextrowtime)
    while self.isPlaying and self.isRunning and playCondition():
      pstr = ""
      if   self.playerDirection == 1: pstr = "f"
      elif self.playerDirection ==-1: pstr = "r"
      self.promptResultMsg = "P{1}: {0}".format(itime, pstr)
      if colind > 0:
        trline = self.getRawDataLine(self.currow+self.playerDirection)
        nextrowtime = float(trline.split(",")[colind-1])
      else: nextrowtime = self.currow+self.playerDirection
      nextcond = nextCondition() #; self.promptResultMsg += " " + str(nextcond) # dbg
      if nextcond:
        self.setCurrow(self.currow + self.playerDirection)
        self.directionStr = ""
        if   self.playerDirection == 1: self.directionStr = self.upChar
        elif self.playerDirection ==-1: self.directionStr = self.downChar
        if optargs.dump_playstep:
          printso("*")
        self.printCurrentLine()
      else:
        self.printStatusLine() # just status
      if optargs.dump_playstep:
        printso(LF)
      itime += step*self.playerDirection
      if not(optargs.no_play_sleep):
        time.sleep(periodsec)
      self.playFrameCount += 1
    if self.promptResultMsg == "": # so it can print "stopped" too
      self.promptResultMsg = "playback finished"
    self.directionStr = " "
    self.printStatusLine(blank=True)
  def handlePlayToggleCmd(self):
    if self.isPlaying:
      self.promptResultMsg = "playback stopped"
      self.isPlaying = False
      self.playThreadID.join()
    else:
      self.isPlaying = True
      self.playThreadID = threading.Thread(target=self.playerThread)
      self.playThreadID.start()
  def getLineMarkerName(self):
    markstr = ""
    for imarker in self.markers:
      if imarker[0] == self.currow:
        markstr = "m: " + imarker[1]
        break
    return markstr
  def parseColRangeSpec(self, instrspec):
    colinds = [] # 1-based! (
    aelems = instrspec.split(",")
    for elem in aelems:
      aintervals = elem.split(":")
      if len(aintervals) == 2:
        if aintervals[0] == "": aintervals[0]=str(1) # col 1 if first unspecified
        if aintervals[1] == "": aintervals[1]=str(len(self.columnnames))
        try:
          for ix in range(int(aintervals[0]), int(aintervals[1])+1):
            colinds.append(ix)
        except:
          colinds = []
          break
      elif len(aintervals) == 1:
        try:
          colinds.append(int(aintervals[0]))
        except:
          colinds = []
          break
    return colinds
  def expandColumnspec(self, instrspec):
    global optargs
    # first, convert '\n' from command line spec
    # (which becomes '\\n') back to '\n'
    instrspec = instrspec.replace(r'\n', '\n')
    patColSpec = self.patColSpec # (r'(@\([\S]+?\)|@\(*[0-9nvVs:,\[\]\.\-\+]+\)*)')
    cspecItems = list(filter(None, patColSpec.split(instrspec))) # remove '' items from split
    expCSpec = []
    patInnerSpec = self.patInnerSpec    # (r'([@\(\)]+)')
    patICmdSpec = self.patICmdSpec      # (r'([nvVs])')
    patIInnerSpec = self.patIInnerSpec  # (r'(\[[^\]]+\]|[\-\+]|[nvVs]+)')
    #self.coldsws = [] # reinit # not here
    for csitem in cspecItems:
      if csitem.startswith(r'@'):
        inparts = list(filter(None, patInnerSpec.split(csitem)))
        # here should be either ['@', 'n5'] or ['@(', 'v6', ')']
        #printse(">  ", inparts, "\n")
        inpartslen = len(inparts)
        isValid = ((inpartslen == 2) or (inpartslen == 3))
        if isValid:
          if inpartslen == 2: # convert to bracketed expression
            if inparts[0] == r'@': inparts[0] += r'('
            inparts.append(r')')
          if not(patICmdSpec.match(inparts[1])): # default cmd if not spec'd (nv)
            inparts[1] = 'nv' + inparts[1]
          #printse(">> ", inparts, "\n")
          inscparts = list(filter(None, patIInnerSpec.split(inparts[1])))
          # at this point, inscparts[1] should be proper ColRangeSpec (without evt. +/-)
          # ['v', '6'] or ['nv', ':4,7,9:'] or ['nv', '5:7', '+', '0.5', '-', '[1]']
          #printse(">>>", inscparts, "\n")
          colinds = self.parseColRangeSpec(inscparts[1])
          # the patICmdSpec regex splits into individual chars
          # (else could have done for char in str:)
          onlycmds = list(filter(None, patICmdSpec.split(inscparts[0])))
          #printse(">>+", onlycmds, colinds, "\n")
          for colind in colinds:
            for cmd in onlycmds:
              if ( (cmd == 'v') or (cmd == 'V') ):
                # join(inscparts[2:]) is empty string if len(inscparts)<3
                tcmd = '@({0}{1}{2})'.format(
                  cmd, colind, "".join(inscparts[2:])
                )
                #self.coldsws.append(0) # here only indexes values, can introduce a problem
              else: # for now, 'n' cmd/specifier - and 's' (also no formulas)
                if optargs.break_at_namescfs:
                  if len(expCSpec) > 0:
                    expCSpec.append('\n')
                # no +/- (inscparts[2:]) if it's a 'n' cmd/specifier
                tcmd = '@({0}{1})'.format(
                  cmd, colind
                )
              expCSpec.append(tcmd)
              expCSpec.append(' ')
          # done with expansion - remove last item (space)
          expCSpec.pop()
      else:
        expCSpec.append(csitem)
    # here just return - set self.expCSpec/expColSpecA (and coldsws) externally
    return expCSpec
  def getColumnspecFormattedString(self, instr, colspec, retfail="", valuePad=True):
    global optargs
    # here instr is a CSV data row string; return
    # reparsed str via self.expColSpecA, where we
    # expect expanded format specifiers (one "command" and one column per spec)
    # moved try to inner block, so it doesn't interrupt any string cspart that may
    # come after a colspec specifier that failed parsing
    outstrA = []
    thisRowData = instr.split(",")
    patInnerSpec = self.patInnerSpec    # (r'([@\(\)]+)')
    patICmdSpec = self.patICmdSpec      # (r'([nvVs])')
    patIInnerSpec = self.patIInnerSpec  # (r'(\[[^\]]+\]|[\-\+]|[nvVs]+)')
    patRowRef = self.patRowRef          # (r'(\[.+\])')
    for icsp, cspart in enumerate(colspec): #self.expColSpecA
      if cspart.startswith(r'@'):
        try: # for now, instead of proper validation, try/except and signal
          inparts = list(filter(None, patInnerSpec.split(cspart)))
          inscparts = list(filter(None, patIInnerSpec.split(inparts[1])))
          # ['v', '6'] or ['nv', ':4,7,9:'] or ['nv', '5:7', '+', '0.5', '-', '[1]']
          # except no 'nv' here, and no ranges - all expanded
          #printse("inscparts", inscparts, "\n")
          tstr = ""
          cmd = inscparts[0]
          colind = int(inscparts[1])
          if (cmd == 'n'): # name
            if colind > 0:
              tstr = self.columnnames[colind-1]
            else: # colind = 0 (auto ID column 0 = row index)
              tstr = "ID"
          elif (cmd == 's'): # string (value)
            if colind > 0:
              tstr = thisRowData[colind-1]
            else: # colind = 0 (auto ID column 0 = row index)
              tstr = str(self.currow)
          elif ( (cmd == 'v') or (cmd == 'V') ): # numeric value
            if colind > 0:
              tstr = thisRowData[colind-1]
            else: # colind = 0 (auto ID column 0 = row index)
              tstr = str(self.currow)
            # the rest are algebraic arguments - reparse for
            # row reference, and get final value via eval
            rest = "".join(inscparts[2:])
            rest_rrparts = patRowRef.split(rest)
            #printse("rest", rest, rest_rrparts, "\n")
            for ir, rrpart in enumerate(rest_rrparts):
              if patRowRef.match(rrpart):
                rowrefs = rrpart[1:-1] # remove square brackets
                try:
                  rowref = int(eval(rowrefs))
                  #printse("rowrefs",rowrefs,"rowref",rowref,"\n")
                  # rowref could be 0 here - possibly reading from column names
                  # so validate, and set tval to 0 (actually, NaN) if invalid rowref
                  tval = ""
                  if (rowref >= 1) and (rowref <= self.numrows):
                    if colind > 0:
                      trow = self.getRawDataLine(rowref)
                      tval = trow.split(",")[colind-1]
                    else: # colind = 0 (auto ID column 0 = row index)
                      tval = rowrefs
                  else: tval = "float('NaN')"
                  rest_rrparts[ir] = tval
                except: rest_rrparts[ir] = ""
            #printse("tstr '"+tstr+"'\n")
            if tstr:
              ntstr = tstr+"".join(rest_rrparts) #; printse("ntstr", ntstr, "rest", rest, rest_rrparts, "\n")
              tstr = str( eval( ntstr ) ) #; printse(" tstr '"+tstr+"'\n")
              if (cmd == 'V'):
                tstr = myFormatEngB(tstr)
              if (not(optargs.no_val_padding) and valuePad):
                #pad values with spaces - per value in coldsws columnspec
                # rjust == left padding as in "% d"
                valwidth = -1
                if len(tstr) > self.coldsws[icsp]:
                  self.coldsws[icsp] = len(tstr)
                valwidth = self.coldsws[icsp]
                tstr = tstr.rjust( valwidth, ' ')
            else: # tstr == ""
              # handle empty values in csv (the above code doesn't run for them)
              # note that eval(" ") (space) raises SyntaxError: unexpected EOF while parsing
              if (not(optargs.no_val_padding) and valuePad):
                valwidth = self.coldsws[icsp]
                tstr = " "
                tstr = tstr.rjust( valwidth, ' ')
              else: raise Exception("Value tstr still empty!")
          outstrA.append(tstr)
        except: # can happen if empty line has been read from input file
          if retfail == "":
            outstrA.append("_colspecfmt_failed_ '"+instr+"'")
          else:
            outstrA.append(retfail)
      else:
        outstrA.append(cspart)
      # endif startswith(r'@'):
    outstr = "".join(outstrA)
    return outstr
  def getIdStr(self, inrow=None):
    idstr = ""
    if inrow is None: inrow = self.currow
    if not(optargs.no_print_rowid):
      idstr = "{0}".format(inrow).rjust(len(str(self.numrows)), ' ')
    if not(optargs.no_print_marker):
      markstr = " "
      for imarker in self.markers:
        if imarker[0] == inrow:
          markstr = self.markChar
          break
      idstr = idstr + markstr
    if not(optargs.no_print_direction):
      if inrow == self.currow:
        idstr = idstr + self.directionStr
      else:
        idstr = idstr + " "
    if not(optargs.no_print_rowid and optargs.no_print_direction and optargs.no_print_marker):
      idstr = idstr + ": "
    return idstr
  def getTextWrapped(self, instr, n=70, hardbreak=False, managed=False, forceRecalc=False):
    global optargs
    wrapa = []
    if (optargs.no_wrap_line or (n==0)): wrapa.append(instr)
    else: # wrap lines:
      recalcsplitinds = True
      splitinds = [0]
      explbinds = [] # explicit breaks indices
      inlen = len(instr)
      if managed and not(forceRecalc):
        if (not(inlen > len(self.wraplaststr)) and not(self.wrapsplitinds == [])):
          recalcsplitinds = False
          splitinds = self.wrapsplitinds
        self.wraplaststr = instr
      if recalcsplitinds:
        patbreakchars = self.patbreakchars # (r'[-,\s]')
        iterator = patbreakchars.finditer(instr)
        isplit = 0
        compare = n
        if (inlen > n):
          matchinds = []
          for match in iterator:
            highend = match.span()[1]
            matchinds.append(highend)
          im=0
          for im, highend in enumerate(matchinds):
            if instr[highend-1] == '\n': # explicit break on \n in columnspec
              if isplit == 0: diff = highend-1
              else: diff = highend-1 - splitinds[isplit-1]
              isplit += 1
              splitinds.append(0)
              explbinds.append(highend-1)
              compare = compare + diff
            elif highend >= compare-1:
              isplit += 1
              splitinds.append(0)
              compare = compare + n
              # set to previous
              if isplit > 1:
                offset = 2
                while(splitinds[isplit-1] - splitinds[isplit-2] >= n):
                  splitinds[isplit-1] = matchinds[im-offset]
                  #printse("*", isplit-1, ",", matchinds[im-offset], "\n")
                  offset += 1
            splitinds[isplit] = highend
          # once more after for loop - for last entry
          offset = 2
          while(splitinds[isplit] - splitinds[isplit-1] >= n):
            splitinds[isplit] = matchinds[im-offset]
            #printse("*", isplit, ",", matchinds[im-offset], "\n")
            offset += 1
          # should append inlen at last (not inlen-1), because the
          # Python string index spec will automatically use it as -1
          if splitinds == [0]:
            if hardbreak:
              tlen = n
              splitinds = []
              while tlen < inlen:
                splitinds.append(tlen)
                tlen += n
              splitinds.append(inlen)
            else:
              splitinds[0] = inlen
          else: # check for dangling tail
            # isplit should currently be at end of splitinds
            # check also if concatenating last line will not go over wrap
            if (inlen-1 - splitinds[isplit] < n) and (inlen-1 - splitinds[isplit-1] < n):
              splitinds[isplit] = inlen
            else:
              splitinds.append(inlen)
        else:
          splitinds[0] = inlen
          # if there are \n's from columnspec, use those
          lbreaks = [m.start() for m in re.finditer('\n', instr)]
          if len(lbreaks)>0:
            splitinds = lbreaks
            splitinds.append(inlen)
        if managed: self.wrapsplitinds = splitinds
      #printse(" spli2", splitinds, "lastind", inlen-1, "nwr", n, "\n")
      # end if recalcsplitinds
      # first, clean up '\n' (from columnspec) from string - replace with ' '
      instr = instr.replace('\n', ' ')
      prevind = 0
      for spind in splitinds:
        wrapa.append(instr[prevind:spind])
        prevind = spind
      if (spind<inlen-1):
        diff = inlen-1 - spind
        lastn = len(wrapa[len(wrapa)-1])
        if lastn+diff < n:
          wrapa[len(wrapa)-1] += instr[spind:]
        else:
          wrapa.append(instr[spind:])
    return wrapa
  def getFormattedLine(self, instr, retArray=False, withIdStr=True, wrapAt=-1):
    global optargs
    if withIdStr:
      idstr = self.getIdStr()
      lenidstr = len(u(idstr))
    else:
      idstr = ""
      lenidstr = 0
    # wrapAt=-1: terminal size; wrapAt=0 - disable wrap (one line)
    if wrapAt == -1: wrapAt = getTerminalSize()[0]-1
    padidstr = " "*lenidstr
    workstr = ""
    linestr = ""
    indicate_trunc = ""
    if (optargs.stringmode):
      if optargs.string_subinds != ":":
        try:
          indicate_trunc = "..."
          workstr = eval( "instr[" + optargs.string_subinds + "]")
        except:
          optsubinds = optargs.string_subinds
          optargs.string_subinds = ":"
          workstr = eval( "instr[" + optargs.string_subinds + "]")
          self.promptResultMsg = "Substring failed with indices `{0}`, defaulting to `{1}`; ".format(optsubinds, optargs.string_subinds)
      else:
        workstr = instr
    else: # not optargs.stringmode - so parse csv: format line according to columnspec
      workstr = self.getColumnspecFormattedString(instr, colspec=self.expColSpecA)
    # managed textwrap interferes with stringmode - disable in that case
    isManaged = not(optargs.stringmode) and not(optargs.no_wrap_managed)
    # detect if terminal size changed; and if so, force recalc of wrap indices:
    forceWrapRecalc = False
    if self.wrapAtlast != wrapAt:
      forceWrapRecalc = True
      self.wrapAtlast = wrapAt
    preformatdlines = self.getTextWrapped(workstr + indicate_trunc, wrapAt - lenidstr, managed=isManaged, forceRecalc=forceWrapRecalc)
    formatdlines = []
    for ix, pfline in enumerate(preformatdlines):
      fline = ""
      if ix == 0: fline = idstr + pfline
      else:       fline = padidstr + pfline
      formatdlines.append(fline.ljust( wrapAt, ' '))
    if retArray: return formatdlines
    else:
      linestr = LF.join(formatdlines)
      return linestr
  def printDiscontinuityLine(self):
    if not (self.termmode == "curses"):
      indent = len(u(self.getIdStr()))
      mystr = " "*indent
      mystr = mystr + "..."
      linestr = mystr.ljust( getTerminalSize()[0]-1, ' ')
      printso( linestr + LF )
  def getRawDataLine(self, rowind1b):
    # rowind1b/self.currow 1-based; may not include header line
    rowind = rowind1b-1
    mystr = ""
    if self.isStoredInRAM:
      # 0-based; data only
      mystr = self.RAM_contents[rowind]
    else: # disk
      rowind = rowind + 1              # linecache is itself 1-based; fix
      if not(optargs.no_header_line):  # skip header line if present:
        rowind = rowind + 1
      mystr = linecache.getline(csvCO.infilearg, rowind)
      mystr = mystr.rstrip() # chomp
    return mystr
  def printCurrentLine(self, shouldMove=True, blank=False):
    global optargs
    if optargs.dump_playstep: return # short-circuit
    if shouldMove:
      mystr = self.getRawDataLine(self.currow)
      self.lastrawdataline = mystr
      if self.termmode == "default":
        if blank:
          self.blankAndCR()
        linestr = self.getFormattedLine(mystr)
        printso( linestr + LF )
        self.printStatusLine()
      elif self.termmode == "curses":
        self.drawNcursesFrame()
        if self.cRawLinesCtxFrame:
          self.cRawLinesCtxFrame.erase()
          self.cRawLinesCtxFrame.border(0)
          yh,xw  = self.cRawLinesCtxFrame.getmaxyx()
          for iy, tind in enumerate(range(self.currow-1, self.currow+1 +1)):
            if (tind == self.currow): crli = self.ccrlChar
            else:                     crli = " "
            lencrli = len(u(crli))
            tstr = ""
            if ((tind >= 1) and (tind <= self.numrows)):
              idstr = self.getIdStr(tind)
              lenidstr = len(u(idstr))
              trstr = self.getRawDataLine(tind)
              lentrstr = len(u(trstr))
              tstr = u(crli + idstr + trstr) # must wrap in u() here?!
              if (len(tstr) >= xw-2): # ok, without len(u(tstr))?!
                dstr = " ..."
                cuti = xw-2-len(u(dstr))
                tstr = tstr[:cuti] + dstr # nowork with just u(tstr)[:cuti] here?!
            self.cRawLinesCtxFrame.addstr(iy+1,1, utt(tstr))
          self.cRawLinesCtxFrame.noutrefresh()
        # cFormatdValsFrame always there - recreate its inner "pad"
        wcols = self.cIFValsSet[5]
        linestra = self.getFormattedLine(mystr, retArray=True, withIdStr=False, wrapAt=wcols-2)
        padhlines = len(linestra)+1
        padwcols = 0
        for line in linestra:
          #line = "'"+line+"'" # debug wrap
          if len(line) > padwcols: padwcols = len(line)
        padwcols += 1 # else it breaks at last char
        self.cIFValsSet[6:7+1] = padhlines,padwcols
        self.cIFValsFrame = curses.newpad(padhlines, padwcols)
        self.cIFValsFrame.idlok(1)
        self.cIFValsFrame.scrollok(1)
        for iy, line in enumerate(linestra):
          #line = "'"+line+"'" # debug wrap
          self.cIFValsFrame.addstr(padhlines-1,0, line)#(1+iy,1, line)
          self.cIFValsFrame.scroll(1)
        self.cFormatdValsFrame.noutrefresh()
        self.updatecIFValsFrame()
        self.printStatusLine()
    else: # shouldMove == False: beep
      printso("\a")
  def printStatusLine(self, blank=False):
    if self.disableStatusLine: return # short-circuit
    myResultMsg = ""
    if (self.promptResultMsg):
      myResultMsg = "({0})".format(self.promptResultMsg)
      self.promptResultMsg = ""
    mystr = "({0}) r: {1}/{2}, c: {3} {4} {5}".format(
      "RAM" if self.isStoredInRAM else "disk",
      self.currow, self.numrows, len(self.columnnames),
      self.getLineMarkerName(),
      myResultMsg
    )
    self.lastStatusLine = mystr
    self.outputBottomString(mystr, blank=blank, retcr=True)
  def outputBottomString(self, instr, blank=False, retcr=False):
    if self.termmode == "default":
      if blank: self.blankAndCR()
      printso(instr) # evt. to stderr, to allow separation if output piping?
      if retcr: printso(CR)
    elif self.termmode == "curses":
      y, x = self.cscreen.getmaxyx()
      self.cscreen.addstr( y-1, 2, " "*(x-3) ) # always blank in curses
      self.cscreen.addstr( y-1, 2, instr)
      self.cscreen.redrawln(y-1, 1)
  def handleCursesFocusToggleCmd(self):
    if self.termmode == "curses":
      if self.cFocus == 0:
        self.cFocus = 1
      else:
        self.cFocus = 0
      self.printCurrentLine()
  def drawNcursesFrame(self, clr=False, upd=False):
    global optargs
    myscreen = self.cscreen
    if clr:
      myscreen.clear() #  clear causes a refresh - to delete possible stderr garbage
    else:
      myscreen.erase() # reduce ncurses flicker when playing back
    myscreen.border(0,0,0," ") # bottom border space (also .box())
    fileIDstr = "CSV/log file: " + optargs.infilename
    myscreen.addstr(0,1, fileIDstr)
    self.cscreensz = myscreen.getmaxyx()
    y, x = self.cscreensz
    # calc: crlcf and cfvf's height, width - and oy (offset y = begin_y)
    crlcfh = crlcfw = cfvfh = 0
    crlcfw = cfvfw = x -2
    cfvoy = 1 ; cfvox = 1
    if optargs.curses_num_rawlines > 0:
      crlcfh = optargs.curses_num_rawlines + 2
      self.cRawLinesCtxFrame =  myscreen.subpad(crlcfh, crlcfw, 1, 1)
      self.cRawLinesCtxFrame.border(0)
      cfvfh = y - (crlcfh+2)
      cfvoy = 1 + crlcfh
    else: cfvfh = y-2
    self.cFormatdValsFrame = myscreen.subpad(cfvfh, cfvfw, cfvoy, cfvox)
    iscfdfFocused = (self.cFocus == 1)
    if iscfdfFocused:
      # emphasize border - plain ASCII or curses.ACS_ only (like addch):
      self.cFormatdValsFrame.border('|', '|', '=', '=')
    else:
      self.cFormatdValsFrame.border(0)
    if (optargs.stringmode):  titstr = "Current line:"
    else:                     titstr = "Current CSV row values:"
    myscreen.addstr(cfvoy,2, titstr)
    # only initialize cIFValsSet at start; so our scroll settings (via TAB)
    # are remembered (otherwise, they are overwritten here)
    # self.cIFValsSet == [] now also a signal to handle terminal resize
    if self.cIFValsSet == []:
      scrposy = scrposx = 0
      padsp = 1 # pad with space from borders
      begin_y = cfvoy+1 +padsp; begin_x = cfvox+1 +padsp
      hlines = cfvfh-2 -2*padsp ; wcols = cfvfw - 2 -2*padsp
      padhlines = padwcols = 0 # modify in printCurrentLine()
      self.cIFValsSet = [scrposy,scrposx, begin_y, begin_x, hlines,wcols, padhlines,padwcols]
    myscreen.noutrefresh()
    if upd:
      curses.doupdate() # bad, now causes flicker here
"""
Instantiate the one (and only) global instance object of CsvContainer
"""
csvCO = CsvContainer()


"""
'Cheap' linecount via mmap; for local files;
opens file readonly, counts lines, and closes file
http://stackoverflow.com/questions/845058/how-to-get-line-count-cheaply-in-python
"""
def mapcount(filename):
  import mmap
  f = open(filename, "r")
  buf = mmap.mmap(f.fileno(), 0, prot=mmap.PROT_READ)
  lines = 0
  readline = buf.readline
  while readline():
    lines += 1
  f.close()
  return lines

"""
CSV reader thread for local files (linecache)
* get initial number of lines;
* parse first line as header (linecache is 1-based!)
* lock into endless loop reading file modification times;
  (refresh rate == sleep time in while; 1s here)
linecache.checkcache is needed if file changed on disk
(else reads will return empty).
NB: isCsvHeaderParsed is used as signal to main thread.
"""
def csvReaderLocalThread():
  global optargs
  global csvCO
  csvCO.numrows = 0
  csvCO.lastmtime = os.stat(csvCO.infilearg).st_mtime
  #
  if ( not(csvCO.isCsvHeaderParsed) ): # (the "if" just for readability)
    firstline = linecache.getline(csvCO.infilearg, 1)
    csvCO.parseHeaderLine(firstline)
    csvCO.updateNumRows()
    csvCO.isCsvHeaderParsed = True
  while (csvCO.isRunning):
    newmtime = os.stat(csvCO.infilearg).st_mtime
    if (newmtime != csvCO.lastmtime):
      linecache.checkcache(csvCO.infilearg)
      csvCO.lastmtime = newmtime
      csvCO.updateNumRows()
    time.sleep(1)

"""
CSV reader thread for stdin/nonlocal files (RAM)
* get initial number of lines (cannot;
  must copy to RAM for this; and the while blocks!)
* parse first line as header
* lock into endless loop reading lines (until EOF)
* Print message to stderr if EOF reached and leave
  (note, check with csvCO.isRunning and don't print
  if user exited)
The `if csvCO.isRunning` hits only if `while` loop breaks.
NB: isCsvHeaderParsed is used as signal to main thread.
"""
def csvReaderRAMThread():
  global optargs
  global csvCO
  csvCO.numrows = 0
  line = "start"
  #
  while( line and csvCO.isRunning ):
    if ( not(csvCO.isCsvHeaderParsed) ):
      rawline = csvCO.fdXobj.readline() # was infileObj
      firstline = line = rawline.rstrip() # chomp
      csvCO.parseHeaderLine(firstline)
      csvCO.updateNumRows()
      csvCO.isCsvHeaderParsed = True
    else:
      rawline = csvCO.fdXobj.readline() # was infileObj
      line = rawline.rstrip() # chomp
      csvCO.addContentsToRAM(line)
      csvCO.updateNumRows()
  if csvCO.isRunning:
    printse("CSV data read completely into RAM ({0} lines); no updates forthcoming.".format(csvCO.numrows), LF)
    if csvCO.linelimits[1] > csvCO.numrows: csvCO.linelimits[1] = csvCO.numrows
    if csvCO.linelimits[0] > csvCO.numrows: csvCO.linelimits[0] = csvCO.numrows


"""
Thread handling keypresses (was stepUINavigationThread);
Leave getch() as blocking - OK, since we're in a thread? Nevermind,
getch() and kbhit() are non-blocking now, emulating Windows
Note that on Linux, different terminals (xterm, gnome-terminal,
konsole), will generate different keycodes for Home, End, F* keys; see
[https://bugzilla.redhat.com/show_bug.cgi?id=121922 Bug 121922 – Home and End keys don't work in nano anymore]
sleep time of 0.1 (100ms) is too slow on Linux, even if kbdrate
says 10.9 cps => 91.7 ms; 0.01 looks OK
Python 3 MUST have ch.decode('utf-8'); else just "+= ch" makes
a string b'a'b'c'... Python 2.7 handles that syntax too
Call .handleGotoCmd etc. delayed, so they run in their own thread,
and they can block on .isPromptingUserInput, until user finishes
typing with ENTER.
On my gnome-terminal, I have ENTER/RETURN produce ^M (13 / 0x0d); however
this code may sometimes may detect \r (13), sometimes \n (10) on Enter;
so don't compare Enter to global LF - that tends to fail
Key 127 is Backspace on my terminal, 8 is Ctrl-H - treat as backspace
# check regular keys - NB: python 3: (ch == b'q');
# i.e. now we must compare to binary strings,
# because of unbuffered os.read! (ok w/ 2.7)
"""
def termUIKeyboardNavigationThread():
  global csvCO
  global ttfo
  import termios
  while(csvCO.isRunning):
    if kbhit():
      ch = getch()
      keych = ord(ch)
      if not(csvCO.isPromptingUserInput):
        # check regular keys
        if ch == b'q':
          call_delayed(exiter) #exiter_call_delayed()
        elif ch == b'g':
          call_delayed(csvCO.handleGotoCmd) #handleGoto_call_delayed() #
        elif ch == b'm':
          call_delayed(csvCO.handleMarkerCmd) #handleMarker_call_delayed()
        elif ch == b'l':
          csvCO.handleListMarkersCmd()
        elif ch == b'p':
          csvCO.playerDirection = 1
          call_delayed(csvCO.handlePlayCmd) #handlePlay_call_delayed()
        elif ch == b' ':
          csvCO.playerDirection = 1
          csvCO.handlePlayToggleCmd()
        elif keych == 0x00: # this is Ctlr-Space (but also Ctrl-`)
                            # in my gnome-terminal
          csvCO.playerDirection = -1
          csvCO.handlePlayToggleCmd()
        elif ch == b'\t': # TAB
          csvCO.handleCursesFocusToggleCmd()
        # special keys check - win32:
        elif sys.platform.startswith('win32'):
          if keych == 224: #Special keys (arrows, f keys, ins, del, etc.)
            keych2 = ord(getch())
            if keych2 == 80: #Down arrow
              down_arrow_pressed()
            elif keych2 == 72: #Up arrow
              up_arrow_pressed()
        # special keys check - others
        # (assuming all other terminals are like bash on Linux)
        elif keych == 27:     # ESC character code 0x1b=27
          nextchar = kbhit()  #  check if multi sequence
          #printse("keych nextchar ", keych, nextchar)
          if (not(nextchar)):
            call_delayed(exiter) #
            #exiter_call_delayed() # only ESC is pressed, so
                                  # exit if not multi-sequence;
            break                 # ... and break out of the while
                                  # (else the next getch will block)!
          keych2 = ord(getch()) # if we got here, it is multi-
                                # sequence; get next char code
          #printse(" keych2", keych2)
          if keych2 == 0x5b:    # second byte in multi-byte,
                                # (for normal and shift), is 0x5b
            keych3 = ord(getch()) # get third byte - is enough to
                                  # determine arrow keys press
            if keych3 == 0x42: #Down arrow
              down_arrow_pressed()
            elif keych3 == 0x41: #Up arrow
              up_arrow_pressed()
            elif keych3 == 0x44: #Left arrow
              left_arrow_pressed()
            elif keych3 == 0x43: #Right arrow
              right_arrow_pressed()
          elif keych2 == 0x4f:  # second byte in multi-byte,
                                # (for my gnome-terminal's Home/End), is 0x4f
            keych3 = ord(getch()) # get third byte - is enough to
                                  # determine Home/End press
            if keych3 == 0x48: #Home key
              home_key_pressed()
            elif keych3 == 0x46: #End key
              end_key_pressed()
        else:
          #printso(ch, keych, LF) # debug: echo unhandled character
          pass
      else: # csvCO.isPromptingUserInput True
        isEnterPressed = ( ch.decode('utf-8') == LF or keych==10 or keych==13)
        isEscPressed = ( keych == 27 )
        isBackSpacePressed = ( keych == 127 or keych == 8 )
        if isEnterPressed:
          csvCO.isPromptingUserInput = False
        elif isEscPressed:
          csvCO.promptResultMsg = csvCO.cancelMsg #"cancelled; "
          csvCO.promptBuffer = ""
          csvCO.isPromptingUserInput = False
        elif isBackSpacePressed:
          if len(csvCO.promptBuffer) > 0:
            printso("\b \b")
            csvCO.promptBuffer = csvCO.promptBuffer[:-1]
        else:
          csvCO.promptBuffer += ch.decode('utf-8')
          printso(ch.decode('utf-8')) # echo
    time.sleep(0.01)


"""
IInfoSet,IFValsSet settings: scrollpos, beginy/x, h/w, padh/w
for curses mode, _when these are called for scrolling_,
there is then no printCurrentLine at end - so some
degree of manual refresh from here is needed.
* when csvCO.cFormatdValsFrame.refresh - very
first press is blank... but nvm, now it started
working ?!
* when csvCO.cscreen.refresh - all is good (but whole
screen refresh demanded)
"""
def up_arrow_pressed():
  global csvCO
  defaultCmd = True
  if csvCO.termmode == "curses":
    if csvCO.cIInfoPad:
      if csvCO.cIInfoSet[0] < csvCO.cIInfoSet[6]-1:
        csvCO.cIInfoSet[0] = csvCO.cIInfoSet[0]+1
        csvCO.updatecIInfoPad()
      else: printso("\a")
      defaultCmd = False
    elif csvCO.cFocus == 1:
      if csvCO.cIFValsSet[0] < csvCO.cIFValsSet[6]-1:
        csvCO.cIFValsSet[0] = csvCO.cIFValsSet[0]+1
        csvCO.updatecIFValsFrame()
      else: printso("\a")
      csvCO.cFormatdValsFrame.refresh()
      defaultCmd = False
  if defaultCmd: csv_next_row()
def right_arrow_pressed():
  global csvCO
  defaultCmd = True
  if csvCO.termmode == "curses":
    if csvCO.cIInfoPad:
      if csvCO.cIInfoSet[1] < csvCO.cIInfoSet[7]-1:
        csvCO.cIInfoSet[1] = csvCO.cIInfoSet[1]+1
        csvCO.updatecIInfoPad()
      else: printso("\a")
      defaultCmd = False
    elif csvCO.cFocus == 1:
      if csvCO.cIFValsSet[1] < csvCO.cIFValsSet[7]-1:
        csvCO.cIFValsSet[1] = csvCO.cIFValsSet[1]+1
        csvCO.updatecIFValsFrame()
      else: printso("\a")
      csvCO.cFormatdValsFrame.refresh()
      defaultCmd = False
  if defaultCmd: csv_next_row()
def down_arrow_pressed():
  global csvCO
  defaultCmd = True
  if csvCO.termmode == "curses":
    if csvCO.cIInfoPad:
      if csvCO.cIInfoSet[0] > 0:
        csvCO.cIInfoSet[0] = csvCO.cIInfoSet[0]-1
        csvCO.updatecIInfoPad()
      else: printso("\a")
      defaultCmd = False
    elif csvCO.cFocus == 1:
      if csvCO.cIFValsSet[0] > 0:
        csvCO.cIFValsSet[0] = csvCO.cIFValsSet[0]-1
        csvCO.updatecIFValsFrame()
      else: printso("\a")
      csvCO.cFormatdValsFrame.refresh()
      defaultCmd = False
  if defaultCmd: csv_prev_row()
def left_arrow_pressed():
  global csvCO
  defaultCmd = True
  if csvCO.termmode == "curses":
    if csvCO.cIInfoPad:
      if csvCO.cIInfoSet[1] > 0:
        csvCO.cIInfoSet[1] = csvCO.cIInfoSet[1]-1
        csvCO.updatecIInfoPad()
      else: printso("\a")
      defaultCmd = False
    elif csvCO.cFocus == 1:
      if csvCO.cIFValsSet[1] > 0:
        csvCO.cIFValsSet[1] = csvCO.cIFValsSet[1]-1
        csvCO.updatecIFValsFrame()
      else: printso("\a")
      csvCO.cFormatdValsFrame.refresh()
      defaultCmd = False
  if defaultCmd: csv_prev_row()
def home_key_pressed():
  csv_first_row()
def end_key_pressed():
  csv_last_row()

def csv_next_row():
  global csvCO
  didMove = csvCO.moveToNextRow()
  csvCO.printCurrentLine(didMove)
def csv_prev_row():
  global csvCO
  didMove = csvCO.moveToPreviousRow()
  csvCO.printCurrentLine(didMove)
def csv_first_row():
  global csvCO
  didMove = csvCO.moveToFirstRow()
  csvCO.printCurrentLine(didMove)
def csv_last_row():
  global csvCO
  minrow, maxrow = csvCO.getLogfileLineLimits()
  didMove = csvCO.moveToRowIndex(maxrow)
  csvCO.printCurrentLine(didMove)

def call_delayed(infunc):
  t = threading.Timer(0.01, infunc)
  t.start()

#def handleGoto_call_delayed():
#  t = threading.Timer(0.01, csvCO.handleGotoCmd)
#  t.start()
#def handleMarker_call_delayed():
#  t = threading.Timer(0.01, csvCO.handleMarkerCmd)
#  t.start()
#def handlePlay_call_delayed():
#  t = threading.Timer(0.01, csvCO.handlePlayCmd)
#  t.start()

"""
checkLoadCurses() should simply check and exit
if curses are requested, but not available,
However, it also does this:
On Ubuntu 11.04, Python 3.2's curses are not linked
against libncursesw (Python 2.7 are OK); messing up
curses UTF-8 display. Can be fixed with LD_PRELOAD;
but to spare the user of messing with that, the
code below checks if libncursesw is linked in, if not
then it respawns the Python interpreter with LD_PRELOAD
although for #if sys.version_info[0] >= 3: ; keeping it
for both, in case some 2.x installation also has
the same problem.
Since now we do a delayed import curses in this function,
we MUST specify a "global curses" - because import is like
setting the "curses" variable to something; and if not
declared global in this function - it will not be visible to
other functions that use it!
"""
def getCommandOutput(incmd):
  import subprocess
  # subprocess.check_output not available in Python 2.6
  # return ut(subprocess.check_output(["ldd", sys.modules['_curses'].__file__]), "utf-8") # encoding="utf-8")
  # use subprocess.Popen - but use shell=False; shell=True otherwise
  #  adds `/bin/sh`, `-c`, and then fails reading the rest of the arguments after the command!
  # communicate() returns a tuple (stdoutdata, stderrdata);
  # must carefully cast its items to unicode string for Python 3.2
  p = subprocess.Popen(incmd, shell=False,
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
  resp = p.communicate() ; respstra = []
  for item in resp:
    if item: respstra.append(ut(item, "utf-8"))
  return "\n".join(respstra)
def checkLoadCurses():
  global cursesFound
  global curses # must have - we set here (via import) now
  if optargs.curses:
    printse("curses requested - starting... ")
    if cursesFound:
      try:
        import curses
        printse("(%s, ok) "%(utd(curses.version)))
      except:
        cursesFound = False
        printse("problem:", sys.exc_info()[0], " Exiting. ", LF)
        exiter(1)
      csvCO.termmode = "curses"
      if sys.platform.startswith('linux'):
        lddresp = getCommandOutput(["ldd", sys.modules['_curses'].__file__])
        printse("Checking for libncursesw... ")
        found = ("libncursesw" in lddresp)
        respawned = ("respawned" in " ".join(sys.argv))
        printse(("found." if found else "not found.") + LF)
        if (not(respawned) and not(found)):
          printse("-> Attempting to respawn this program." + LF)
          nargs = ["python", sys.argv[0], "--respawned"]
          nargs.extend(sys.argv[1:])
          nenv = os.environ
          nenv['LD_PRELOAD'] = '/lib/libncursesw.so.5'
          os.execve(sys.executable, nargs, nenv)
    else:
      printse("Cannot start in curses mode (not available)", LF)
      exiter(1)

"""
Initialize curses terminal display (if requested)
for non-blocking: window.timeout(0) or window.nodelay(1)
window.clear() #  clear causes a refresh, with delete
window.erase() # reduce ncurses flicker
When in curses, cannot read piped stdin;
the open("/dev/tty") seems to work somewhat for Py2.7,
but not for Py3.2?
# On linux: to have curses read from stdin, both
# duplicating to csvCO.fdXobj must be
# done; as well as the dup2 from /dev/tty
# below (which allows the keypresses to be read)
initial draw curses? was via printcurrentline..;
# but now that we're using noutrefresh several place;
# the very first draw can be corrupt;
# unless we call here drawNcursesFrame with clr=True!
"""
def initCurses():
  if not(sys.platform.startswith('win32')):
    ftty=open("/dev/tty")
    os.dup2(ftty.fileno(), 0)
  try:
    csvCO.cscreen = curses.initscr()
  except:
    printse("Error during curses init:", sys.exc_info()[0])
    exiter(1)
  atexit.register(curses.endwin)
  csvCO.cscreen.timeout(0)
  csvCO.cscreen.idlok(1)
  csvCO.cscreen.scrollok(1)
  curses.noecho()
  # initial draw curses
  csvCO.drawNcursesFrame(clr=True, upd=True)

"""
If piping via stdin, and curses terminal mode requested:
# must reopen, so stdin can be read in curses;
# (also open('/dev/tty') in initCurses, so keys can be read in that case)
# the reader thread then reads from fdXobj instead
csvCO.fdX = 7 #  Note, the pipes overtake file descriptors 8 and 9, so make this 7!
# to handle stdin, copy this object infileObj to a new file descriptor, 7
"""
def checkCursesStdinReopen():
  if csvCO.termmode == "curses":
    csvCO.fdX = 7
    csvCO.fdXobj = 0
    os.dup2(csvCO.infileObj.fileno(), csvCO.fdX)
    csvCO.fdXobj = os.fdopen(csvCO.fdX)
    if csvCO.fdXobj == 0: # if no fdXobj, exit
      exiter(1)
      return
  else: csvCO.fdXobj = csvCO.infileObj


def conditionallyDumpAndExit():
  if (optargs.dump_formatted or optargs.dump_playstep):
    optargs.curses = False
    csvCO.termmode = "default"
    if optargs.dump_formatted:
      # for csv lines, ensure stepping through
      # column 0 for fastest (fps don't matter
      # here, if no_play_sleep enabled):
      isParsed = csvCO.parsePlayerSettings("0 1 2")
    csvCO.disableStatusLine = True
    csvCO.playerDirection = 1
    csvCO.moveToFirstRow()
    csvCO.printCurrentLine() # to display first row
    csvCO.handlePlayToggleCmd()
    csvCO.playThreadID.join()
    exiter(0) # just exit(0) here blocks!



"""
Choose which keyboard user interaction functions
for terminal (getch, kbhit) to use - depending
on if we're in curses mode, or (default) not;
redefine global functions accordingly
"""
def initKeyboardUIFuncs():
  global getch    # here we set; needs global
  global kbhit    # here we set; needs global
  if csvCO.termmode == "default":
    getch = _Getch()
    kbhit = _Kbhit()
  elif csvCO.termmode == "curses":
    initCurses()
    def getch():
      c = csvCO.cscreen.getch()
      try:    ret = b(chr(c))
      except: ret = "" #; printse(str(c)+" ")
      return ret
    def kbhit():
      c = csvCO.cscreen.getch()
      ret = (c != -1) and (c != 410)
      # only for curses - char 410 (curses.KEY_RESIZE)
      # is terminal resize ; handle it here
      #  - so UI keyboard thread is unchanged
      if c == 410:
        y, x = csvCO.cscreen.getmaxyx()
        curses.resizeterm(y, x) # Resize curses boundaries
        csvCO.cIFValsSet = [] # signal changes of formatted vals size
        csvCO.printCurrentLine() # refresh
      # push back if actual char (-1, 410 is bad);
      # so next getch will return the same
      if ret:
        curses.ungetch(c)
      return ret

"""
Called from SIGINT (Ctrl-C) callback
Probably no need for additional:
  if not( sys.platform.startswith('win32') ):
    _GetchUnix.enable_echo(_GetchUnix.fd, True)
... here, beyond atexit
"""
def exiter(exitstatus=0):
  global csvCO
  printse(LF + "Waiting for threads to terminate... ")
  csvCO.isRunning = False
  if not(csvCO.infileObj.closed):
    csvCO.infileObj.close()
  for ithr in csvCO.threads:
    ithr.join()
  printse("exited.", LF)
  sys.exit(exitstatus)
"""
Delayed call needed if closing from a thread
"""
#def exiter_call_delayed():
#  t = threading.Timer(0.1, exiter)
#  t.start()

"""
if using argparse, -h/--help is automatically added;
usage is automatically printed if args aren't parsed;
also type= is by default "simple string";
store_false is to store boolean switch value;
just one option in add_argument (without a '-')
means positional argument.
the format must be specified as `%(prog)s` !
action='version' doesn't otherwise show in usage!
If using usage= instead of description=; then
the whole usagemsg (but not all auto arg text)
is dumped on argument error!
Keep optargs local here - and return them.
Note minuses vs. underscores:
--no-header-line becomes optargs.no_header_line
If we want to read the default values from add_argument,
they are in: optparser._option_string_actions['--option'].default
So if we want to read those elsewhere, we ought to make
optparser a global variable for now
"""
def processCmdLineOptions():
  global optparser
  optparser = argparse.ArgumentParser(description=usagemsg,
              formatter_class=argparse.RawDescriptionHelpFormatter,
              fromfile_prefix_chars='@')
  optparser.add_argument('-s', '--stringmode', action='store_true',
                          help='do not parse CSV - just print strings (reduced functionality!)')
  optparser.add_argument('-u', '--string-subinds', action='store',
                          type=str, default=":",
                          help="for stingmode, truncate string (Python substring index spec); default if unspec'd: \"%(default)s\"")
  optparser.add_argument('-n', '--no-header-line', action='store_true',
                          help='use auto column names: 1st line in CSV is data, not a header')
  optparser.add_argument('-i', '--no-print-rowid', action='store_true',
                          help='do not printout row number (index)')
  optparser.add_argument('-d', '--no-print-direction', action='store_true',
                          help='do not printout direction character')
  optparser.add_argument('-m', '--no-print-marker', action='store_true',
                          help='do not printout marker character')
  optparser.add_argument('-w', '--no-wrap-line', action='store_true',
                          help='do not wrap long lines to terminal width')
  optparser.add_argument('-z', '--no-wrap-managed', action='store_true',
                          help='when wrapping long lines, do not use managed wrapping (which recalculates wrap indices only when string length increases, preserving whitespace of left-padded CSV columnspec values; automatically off for stringmode)')
  optparser.add_argument('-q', '--quiet', action='store_true',
                          help='Suppress some startup messages (like columnspec) in terminal')
  optparser.add_argument('-y', '--playerspec', action='store',
                          type=str, default="",
                          help="overload initial player settings (\"{0}\"); default if unspec'd: \"%(default)s\"".format(" ".join(map(str, csvCO.playerSettings))))
  optparser.add_argument('-e', '--no-play-sleep', action='store_true',
                          help='ignore player fps timing - play back as fast as possible')
  optparser.add_argument('-l', '--line-limits', action='store',
                          type=str, default="1:0",
                          help="limit step player to this range \"start:end\" of rows/lines, 1-based (0 for whatever is last line); default if unspec'd: \"%(default)s\"")
  optparser.add_argument('-c', '--columnspec', action='store',
                          type=str, default="@:",
                          help="csv column selection (format string) spec; don't use space to separate arg value if it starts with \"@\"; default if unspec'd: \"%(default)s\"")
  optparser.add_argument('-p', '--no-val-padding', action='store_true',
                          help='do not left-pad values (via CSV columnspec) with spaces')
  optparser.add_argument('-t', '--break-at-namescfs', action='store_true',
                          help='add linebreak before name format specifiers in (expanded) CSV columnspec')
  optparser.add_argument('-f', '--dump-formatted', action='store_true',
                          help='Bypass normal operation; play through all CSV lines available, dump columnspec formatted lines, and exit')
  optparser.add_argument('-b', '--dump-playstep', action='store_true',
                          help='Bypass normal operation; play through all CSV lines available (as per playerspec), dump a character on step/frame transition (else "\\n"), and exit')
  optparser.add_argument('-r', '--curses', action='store_true',
                          help='use (n)curses terminal mode (curses {0})'.format("available" if cursesFound else "NOT available"))
  optparser.add_argument('-a', '--curses-num-rawlines', action='store',
                          type=int, default=3,
                          help="for curses, show this ammount of raw CSV lines (disabled for 0); default if unspec'd: %(default)s")
  optparser.add_argument('--respawned', action='store_true',
                          help='(just a signal for exec (respawn))')
  optparser.add_argument('infilename',
                          help='input file name (`-` for stdin)')
  optargs = optparser.parse_args(sys.argv[1:]) #(sys.argv)
  return optargs



# ##################### MAIN          ##########################################

def main():
  global inputSrcType
  global csvCO
  global optargs  # here we set; needs global;

  optargs = processCmdLineOptions()

  csvCO.infilearg = optargs.infilename #sys.argv[1]
  csvCO.infilebase = os.path.splitext(os.path.basename(csvCO.infilearg))[0]
  csvCO.infileObj = openAnything(csvCO.infilearg)
  csvCO.inputSrcType = inputSrcType

  checkLoadCurses() # if optargs.curses: ... (and possibly respawn)

  printse("Starting...",
          "term mode:", csvCO.termmode,
          "[term size: {0}]".format(getTerminalSize()),
          "pid {0}".format(os.getpid()),
          LF)

  if optargs.playerspec != "":
    isParsed = csvCO.parsePlayerSettings(optargs.playerspec)
    if not(isParsed):
      printse("Parsing playerspec argument failed! (falling back to default)", LF)

  csvCO.parseLineLimits(optargs.line_limits)

  # start the "main" thread
  t0 = None
  csvCO.isRunning = True
  if inputSrcType == 3: # local: linecache
    #csvCO.infileObj.close() # not needed
    csvCO.isStoredInRAM = False
    csvCO.infiledir = os.path.dirname(os.path.realpath(csvCO.infilearg))
    t0 = threading.Thread(target=csvReaderLocalThread)
  else:                 # stdin/nonlocal: RAM
    csvCO.isStoredInRAM = True
    checkCursesStdinReopen()
    t0 = threading.Thread(target=csvReaderRAMThread)
  t0.start()
  csvCO.threads.append(t0)

  # wait for main thread to parse CSV header (even if stringmode)
  while( not(csvCO.isCsvHeaderParsed) ):
    time.sleep(0.2)

  # parse cmdline columnspec
  if not(optargs.stringmode):
    if not(optargs.quiet):
      cnames = ""
      for ix, cn in enumerate(csvCO.columnnames):
        cnames += str(ix+1) + ": '" + cn + "' "
      printse("Columns ({0})>".format(len(csvCO.columnnames)),
              cnames, LF)
    csvCO.expColSpecA = csvCO.expandColumnspec(optargs.columnspec)
    csvCO.coldsws = [0]*len(csvCO.expColSpecA) # index along expCSpec
    if not(optargs.quiet):
      printse("Columnspec:", '"'+optargs.columnspec+'"',
              "=[{0}]=>".format(len(csvCO.expColSpecA)), csvCO.expColSpecA, LF)

  # wait for at least two lines available:
  while( csvCO.numrows <= 1 ):
    time.sleep(0.2)

  printse("Data available. Terminal UI started.", LF)
  printse(LF)

  conditionallyDumpAndExit()

  initKeyboardUIFuncs()

  # if CSV header parsed; start step "player" keyboard UI thread (terminal)
  t1 = threading.Thread(target=termUIKeyboardNavigationThread)
  t1.start()
  csvCO.threads.append(t1)

  # printout first line for start; not implicitly, but
  # forcing shouldMove to True, so it executes anyways
  csvCO.moveToFirstRow()
  csvCO.printCurrentLine()

  # "if your main has nothing better to do" http://stackoverflow.com/a/1635084/277826
  # must have this, _with_ isRunning check, to have Python 2.7 exit on Ctrl-C!
  while ( (threading.active_count() > 0) and csvCO.isRunning ):
    time.sleep(0.1)


# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


