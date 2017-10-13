#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes even on Unicode in comments

"""
# Part of the numStepCsvLogVis package
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
usagemsg = "numStepCsvLogVis.py ( %(prog)s ) v.{0}".format(__version__) + """
steps through CSV (with numeric data), outputting to terminal (python2.7/3.2)

Usage:
  cat example-syslog.csv | python numStepCsvLogVis.py -
  python numStepCsvLogVis.py example-syslog.csv
  python numStepCsvLogVis.py "@args.txt"

* Stdout/stderr is used for "step"/"playback" output
* Ctrl-C (doesn't work if GUI started!), or `q` in terminal to exit
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

GUI: step/play commands are synchronized with GUI (slower!)
to render frames: toggle "Render", and then Play/Stop (via terminal)
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
  def utdd(x): # for _gk_update (matplotlib 0.99 UTF-8)
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
  def utdd(x): # if x is str
    return x
  #tkinterFound = pu_find_module("tkinter") # instead of try: import tkinter as tk
  tkmstr = "tkinter"

"""
even faster module check (than old pu_find_module) -
loop through modules only once:
"""
import pkgutil
cursesFound = False
tkinterFound = False
numpyFound = False
matplotlibFound = False
for (module_loader, name, ispkg) in pkgutil.iter_modules():
  if name == "curses":      cursesFound = True
  if name == tkmstr:        tkinterFound = True
  if name == "numpy":       numpyFound = True
  if name == "matplotlib":  matplotlibFound = True


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
In playerThread - for PNG rendering:
# rendering will be done via update from printCurrentLine(), if needed
# for first frame only, force update (if... self.playFrameCount == 1:)
#  self.ax.figure.savefig! guiCO.fig.show() - cannot! #guiCO.ax.figure.draw() - 2 args!
#  the fig.canvas.draw() is actually enough in first frame force update,
#  as long as playframecount is correct; no need for "full" update!
# if guiCO.isRendering: # now explicit for each step
#  as update_gkLines doesn't run savePNGFrameRender anymore; and
#  putting it above before printCurrentLine doesn't help, as it's async;
#  so wait until its GUI is done updating
#  #guiCO.fig.canvas.draw() # render requires explicit draw here? Not, it seems
In handlePlayToggleCmd:
# if guiCO.isGuiUsed: printse(guiCO.renderFrameCount, len(guiCO.renderedFrames)...
#  depending on how the thread is stopped; renderFrameCount could
#  be bigger than len(guiCO.renderedFrames); resync on stop playback
#  via if guiCO.isRendering...
#  now use global isGuiUsed
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
    self.patIInnerSpec = re.compile(r'(\[[^\]]+\]|[\-\+]|[nvVs]+)') # only split on plus/minus, and on command (n, v, nv, s) expected at start; but stuff in [] as a whole!
    self.patRowRef = re.compile(r'(\[.+\])')
    self.patbreakchars = re.compile(r'[-,\s]')
    self.lastrawdataline = "" # last raw data line obtained in printCurrentLine
    self.lastStatusLine = ""  # last status line obtained in printStatusLine
    self.wraplaststr = ""   # last string to be wrapped (for managed wrapping)
    self.wrapsplitinds = [] # last wrap split indices (for managed wrapping)
    self.wrapAtlast = -1    # last wrapAt (to detect changes in terminal size, and force recalc)
    self.playerSettings = [0, 1.0, 2.0]
    self.isPlaying = False
    self.cancelMsg = "cancelled; "
    self.playThreadID = None
    self.playerDirection = 0 # 1: play forward; -1: play backward
    self.playFrameCount = 0  # frame counter (incl. steps) when playing; reset at each play (not really used), xcept for render plot refresh
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
          self.cIInfoPad.addstr(padhlines-1,0, line)
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
    if shouldPlay:        # startup playback thread
      self.playStartup()  # from function, as playframecount etc. needs to be managed too
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
    global guiCO, isGuiUsed
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
      rstr = ""
      if isGuiUsed:
        if guiCO.isRendering: rstr = " Rfr: {0}".format(guiCO.getFormattedRFC())
      self.promptResultMsg = "P{1}[{2}]: {0}{3}".format(itime, pstr, self.playFrameCount, rstr)
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
        self.printCurrentLine() # rendering will be done via update from here, if needed
      else:
        self.printStatusLine()  # just status
        if optargs.dump_playstep:
          printso(LF)
        if isGuiUsed:
          if guiCO.isRendering and self.playFrameCount == 1: # for first frame only, force update
            guiCO.fig.canvas.draw()
      if isGuiUsed:
        if guiCO.isRendering: # and csvCO.isPlaying (always True in this thread) # now explicit
          while(guiCO.isGuiUpdating): time.sleep(0.01) # wait
          guiCO.savePNGFrameRender() # manages .renderFrameCount
      itime += step*self.playerDirection
      if not(optargs.no_play_sleep):
        time.sleep(periodsec)
      self.playFrameCount += 1
    if self.promptResultMsg == "": # so it can print "stopped" too
      self.promptResultMsg = "playback finished"
      if optargs.dump_renderpng:
        guiCO.quitButton.event_generate("<ButtonRelease-1>", rootx=-1, rooty=-1)
    self.directionStr = " "
    self.printStatusLine(blank=True)
  def handlePlayToggleCmd(self):
    global guiCO, isGuiUsed
    if self.isPlaying:
      self.promptResultMsg = "playback stopped"
      self.isPlaying = False
      self.playThreadID.join()
      if isGuiUsed:
        #printse(guiCO.renderFrameCount, len(guiCO.renderedFrames), guiCO.renderedFrames, os.listdir(guiCO.renderSubdir), "\n")
        if guiCO.isRendering:
          if guiCO.renderFrameCount > len(guiCO.renderedFrames)+1:
            guiCO.renderFrameCount = len(guiCO.renderedFrames)+1
        guiCO.update_idle()
    else:
      self.playStartup()
  def playStartup(self):
    global guiCO, isGuiUsed
    self.isPlaying = True
    self.playFrameCount = 1
    if isGuiUsed:
      if guiCO.isRendering and not(guiCO.continuousRFC):
        guiCO.resetDeleteRenderFrameCount()
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
                if len(tstr) > self.coldsws[icsp]: # here may typically except? Yes, if coldsws got overwritten by GuiCO call to expandColumnspec!
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
    global optargs, guiCO, isGuiUsed
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
          self.cIFValsFrame.addstr(padhlines-1,0, line)
          self.cIFValsFrame.scroll(1)
        self.cFormatdValsFrame.noutrefresh()
        self.updatecIFValsFrame()
        self.printStatusLine()
      if isGuiUsed: guiCO.update_idle() #update_idle()
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
Main matplotlib GUI related class
tk.Toplevel - has no attribute 'pack'
tk.Frame    - has no attribute 'protocol'
self.top.protocol("WM_DELETE_WINDOW", self.top.destroy) - no help for close
Trying to start GUI window behind calling terminal -
apparently can't, so drop that for now:
#self.root.lower() = doesn't change the stacking order (cannot open
below terminal window)
#self.root.after_idle(self.root.lower) # same
#self.root.overrideredirect(1) - makes window disappear;
#self.textarea.insert(tk.INSERT, self.root.tk.eval('wm stackorder '+str(self.root))) # nothing much
Note: For python 2.7 matplotlib, a hack is required in the lib
file backend_tkagg.py for FigureCanvasTkAgg(self.fig, master=self.root);
else "_tkinter.TclError: bad screen distance "250.0""
see http://stackoverflow.com/questions/10374841/ ;
can be fixed with an extra inheriting class (FigureCanvasTkAggFix),
which overloads with fixed version of needed methods;
However, makes this class conditional on libraries found,
to prevent crashing errors. Note also:
#self.fig.bbox.bounds = map(int, self.fig.bbox.bounds)# AttributeError: can't set attribute
#funcType = type(self.figcanvas.resize)
#self.figcanvas._resize_callback = funcType(TkAggResize, self.figcanvas, FigureCanvasTkAgg) # overloads; but that's not it
#self.figcanvas.resize = funcType(TkAggResize, self.figcanvas, FigureCanvasTkAgg) # nowork
... but can fake integer points like this:
#self.fig.bbox_inches._points = np.asarray(self.fig.bbox_inches._points, np.int_) # works!
#self.fig.bbox._bbox._points = np.asarray(self.fig.bbox._bbox._points, np.int_) # works!
#self.fig.bbox.get_points()
#self.fig.bbox._points = np.array([[ 0,  0], [ 600,  400]], dtype=np.int_)
... still, that isn't enough - int must be placed at create_image, requiring
the overload.
If ".resize" isn't overridden, it will fail at "create_image(width/2,height/2" with
"bad screen distance" - but if overriden, no more failure, even if no explicit cast to
int in there...
For both 3.2 and 2.7, _resize_callback is None
Even if both Py3.2 and 2.7 use the fix - 2.7 still doesn't stretch the matplotlib figure to fit the bounds of the screen completely - even if they get the same width/height values
self.figcanvas.get_width_height() is same (500, 400) in both cases
NB: FigureCanvasTkAggFix(self.fig, master=self.root) makes window dissappear in Py3.2/2.7 - master must be self.frame!
3.2/2.7: get_width_height (500, 400) winfo_req 510 410 geom 650x251+0+38
The problem is in .resize - 2.7 will interpret w/hinch = 600/100 as
as ints, making the figure not scale properly; 3.2 deals with them as
floats (so its ok) - thus simply fix the w/hinch calc to default to float
Python 3.2 can do without these fixes (with matplotlib 1.2.0 from source)
In initMatPlot: can do without self.figcanvas.show()
also both of these refs work: #self.canvas = self.figcanvas.get_tk_widget() #.pack(side=Tk.TOP, fill=Tk.BOTH, expand=1) #ok
# self.canvas = self.figcanvas._tkcanvas # ok now
Only tk.Checkbutton can toggle state : sticky it to N+S, so Checkbutton is same height as Buttons in the frame!
* in tk.Checkbutton, indicatoron is whether to show a checkbox inside the button!
NB: The fix classes need to refer to tk. (not Tk. as they originally do),
as the reference is in this file!
initMatPlot now uses custom marker '@', which doesn't change size on zoom;
else it had:  printse("aspect", self.ax.get_aspect())
  customMarkers = []
  for x, y in self.getNumpyXyIter(np.array([t,s])): #np.nditer([t,s]):
    #printse("%f:%f\n" % (x,y))
    pathCS1 = self.getCustomMarkerPath01(x,y,0.05,650.0/251.0)
    patchCS1 = matplotlib.patches.PathPatch(pathCS1, facecolor='orange', lw=1) # no
    customMarkers.append(patchCS1)
  pcolm = matplotlib.collections.PatchCollection(customMarkers)
  pcolm.set_alpha(0.9)
  pcolm.set_facecolor('red')
  self.ax.add_collection(pcolm)
The classes need a reference to e.g. FigureCanvasTkAgg from already
imported matplotlib; and since now the import is delayed until actually
requested - put the matplotlib classes initialization in a function,
and then call that function after the actual import happened.
Also, because of this setup, all classes def'd in initMatplotlibClasses
now also need to be declared "global", else those names wouldn't be
found by other functions
For self.guiconfdefault = "" #_guiconfdefault #% (sys.argv[0], csvCO.infilearg)
#  default for non-existing _gk files; but infilearg not ready here;
#  initBuildWindow is too late - do in determineAndOpenGUIconfFile
# default extension: ._gk ("GUI 'k'onfiguration", so its not "_gc" garbage collection)
Adding extra #self.labelM2S after labelM22 - # screws up layout in v22
For testing, self.canvas can be a plain tkinter canvas:
# self.canvas = tk.Canvas(self.frame, closeenough=1.0, relief="flat", background="white")
# self.canvas.grid(row=3, column=1, columnspan=4, sticky=tk.E + tk.W + tk.S + tk.N)
... however, set it later on (None at first) to the matplotlib figure canvas!
For .labelM04 , width=3 # specify width (in characters), else the whole frame layout changes!
For toggling tkinter buttons, we cannot use self.mplToolbarButton = tk.Button;
we must use tk.Checkbutton (with variable)
For self.textarea:
# for some reason, textarea needs a height=18, so that it scales
# on window resize with approx the same size as canvas?!
# (height=17 leaves canvas a tiny bit bigger than textarea)
# cannot use tk.StringVar() with tk.Text - tk.Text is a full
# blown editor, where text is INSERT-ed, not set
# give it name, so can arrange bindtags later, to make
# the custom key press event fire after the change has been made,
# so the indication of changed text in textarea is correct!
For buttons binding:
# buttons with 'bind' will fire even if button is disabled;
# to not fire when button disabled, use command=...
# NB: the command=lambda needs actual `function()` - not just the name `function`!
For self.deletePNGButton:
# list comprehension to run two commands as one-liner (lambda needed):
# command=lambda: [self.resetDeleteRenderFrameCount(updateGUI=False), self.update_idle()]
# but update from here may mess up when rendering - pass argument instead
# must lambda again, because I want to call with an argument!
For OnTextAreaKeyPress(self, event):
  #value = event.widget.get()
  # dbg code:
  if event.char == event.keysym:
    msg = 'Normal Key %r' % event.char
  elif len(event.char) == 1:
    msg = 'Punctuation Key %r (%r)' % (event.keysym, event.char)
  else:
    msg = 'Special Key %r' % event.keysym
  string="press of %s is '%s'" % (event.widget._name, msg)
  printse(string, event.char == '\x1a', "\n")
For initGUILabelText - tk.Text:
#  # cannot use tk.StringVar() with tk.Text
# mark this as unmodified text (start of undo buffer):
# edit_modified(False) resets the state that involves
# changes by keypresses, but NOT undo level buffers;
# undo buffers are reset with edit_reset (or edit_separator?)!
# also, to not include last (extra) \n, use self.textarea.get(1.0, "end-1c")
For initMatPlot:    # init matplotlib figure: WH 650 251 (5,4)
# note that the figsize here will influence percentage
# of space that the matplot claims from the master frame/window!
For mplToolbarToggle:     #printse(self.mplToolbarButton.cget('relief'), self.mplToolbarButton.var.get(), tk.RAISED, "\n")
# for tk.Checkbutton, this "if" and .config works
# (the .config nowork for tk.Button):
#if self.mplToolbarButton.cget('relief') == tk.SUNKEN:
#  self.mplToolbarButton.config(relief=tk.RAISED)
# also, tk.Checkbutton is FLAT (not RAISED) by default;
# also, deselect()/select() sets the value to off/onvalue,
# but ONLY for checkbox indicator (not shown here);
# so still must manage the .var manually
# but specifically for tk.Checkbutton, we keep track of a
# variable - so use it;
# NOTE: the variable is automatically managed via clicks,
# (also the select()/deselect() state)
# so we SHOULD NOT set the _var_ here in the toggle;
# here simply manage the relief!
For renderPNGToggle:     # just get the button variable, and set .isRendering accordingly
# don't interfere with playerThread conditions; to turn
# off playback/render from this button, set csvCO.isPlaying:
For def update: can do either of:
#self.update_gkLines() # maybe better keep in sync; not much gain in having the gui update faster than the matplot?
#self.root.after_idle(self.update_gkLines) # or maybe it just seems more responsive, even if gui texts update first?
Also, everywhere there is .update_idle() call; update() can be called instead for
synchronous operation - but it may make the GUI as a whole lock more (and be less responsive)
In parseGUIconfFile:
# re-initialize the GUI config matplotlib objects' container;
# self._gk = type('Object', (object,), {}) - (as a generic object,
# capable of dynamically added attributes) ####
# reconstruct _gk script again - here without
# current row expansion (getColumnspecFormatted_gkLines); as
# there may be no current row yet? Actually with, so can have
# proper instantiation - except modified getColumnspecFormattedString
# to return 0 on failed colspec entries, so the eval here doesn't crash
## best results obtained with compile() AST to run eval/exec code; else:
# eval like this works (with expression):
#eval("printse('from eval, self._gk:{0}'.format(self._gk) + '\\n')")
# but assignment is a statement in Python, not expression, so this fails:
#eval('self._gk.tval = float("0")')
# use exec instead:
#exec('self._gk.tval = float("0")')
#printse("self._gk.tval", self._gk.tval, "\n")
# eval script - NOT eval, as it has assignment - exec
#_gk_setup = None ; _gk_update = None
#d = dict(locals(), **globals())
#exec (gk_processed_str, d, d) # exec(gk_processed_str) #eval(gk_processed_str)
# local_env = locals() # even if before exec - it gets updated by it!
# #exec gk_processed_AST in global_env
# exec (gk_processed_AST)#, global_env)#, local_env) # _env args not even needed!
###~ printse("global_env.keys() =", global_env.keys(), "\n")
###~ printse("local_env.keys() =", local_env.keys(), "\n")
###print(_gk_setup)  # NameError("global name '_gk_setup' is not defined",)
##_gk_setup = local_env["_gk_setup"]   # req'd for Py3.2; but not really 2.7
# re-assign the methods which should now be there as (local) vars:
# cannot just re-assign simply:
#self._gk_setup = _gk_setup
# must use types, or "exploit the fact that functions are descriptors":
##  # clear the figure, and call the setup
##  # (to create gk matplotlib plot elements)
##  #self.fig.clf(keep_observers=True) # aka .clear(); but may delete axes reference
##  self.ax.cla() # probably better, so we don't lose ax reference?
In update_gkLines:     # we'd need a matplotlib (not just tkinter) refresh here
##self.ax.draw()# ax and fig draw/update need renderer #self.canvas.update() # nothing; no attr "draw"
##if self.isRendering and csvCO.isPlaying: self.savePNGFrameRender() - only in playerthread now
#self.fig.canvas.draw() # this is it!
For getColumnspecFormatted_gkLines:
# must call csvCO.getColumnspecFormattedString with valuePad = False here,
# otherwise the managed wrapping gets messed up completely!
For savePNGFrameRender:
# even if renderedFrames.append(fname) is after savefig, doesn't matter;
# 'cause the draw() afterwards actually triggers? anyways, seems to keep sync with actually saved figures
# self.ax.figure.savefig(fname) needs draw() after!? or not?
# (it seems savefig needs draw() before; and it does actually save the figure;
# so it is savePNGFrameRender, not prepPNGFrameRender)
for resetDeleteRenderFrameCount:
#while len(self.renderedFrames) > 0: .pop() # hmm... fails? no, there was retrigger that saved additional frame; but for+reset seems good (even safer) too? Nope, in case of failure, better to have stuff popped:
#for fname in self.renderedFrames: ...
#self.renderedFrames = []
# if updateGUI: # calling just update_idle from here, causes a PNG to be saved if self.isRendering
# so now that the update call is split, call just update_GUI:
For quit:
#self.root = None # so we do not destroy it twice
## value rootx,y = -42,-42 is signal from exiter;
## so if clicked from a button, also call exiter
## (otherwise not, to prevent feedback loop)
Now having global isGuiUsed, so we can
conditionally load all this gui-related stuff only
if both available and requested.
"""
isGuiUsed = tkinterFound and numpyFound and matplotlibFound \
  and (any(i in ["-g","--gui"] for i in sys.argv) \
  or any(i in ["-j","--dump-renderpng"] for i in sys.argv)) \
  and not(any(i in ["-s","--stringmode"] for i in sys.argv))
# copy of /usr/lib/pymodules/python2.7/matplotlib/backends/backend_tkagg.py (mpl 0.99)
# with fix /usr/local/lib/python3.2/dist-packages/matplotlib/backends/backend_tkagg.py (mpl 1.2):
if isGuiUsed:
  def initMatplotlibClasses():
    global FigureCanvasTkAggFix, NavigationToolbar2TkAggFix
    if matplotlib.__version__ < "1": #sys.version_info[0] < 3:
      class FigureCanvasTkAggFix(FigureCanvasTkAgg):
        def __init__(self, figure, master=None, resize_callback=None):
          matplotlib.backends.backend_tkagg.FigureCanvasAgg.__init__(self, figure)
          self._idle = True
          t1,t2,w,h = self.figure.bbox.bounds
          w, h = int(w), int(h)
          self._tkcanvas = tk.Canvas(
            master=master, width=w, height=h, borderwidth=4)
          self._tkphoto = tk.PhotoImage(
            master=self._tkcanvas, width=w, height=h)
          #self._tkcanvas.create_image(int(w/2), int(h/2), image=self._tkphoto) # fix
          self._tkcanvas.create_image(w//2, h//2, image=self._tkphoto) # fix as in mpl1.2 backend
          self._resize_callback = resize_callback
          self._tkcanvas.bind("<Configure>", self.resize)
          self._tkcanvas.bind("<Key>", self.key_press)
          self._tkcanvas.bind("<Motion>", self.motion_notify_event)
          self._tkcanvas.bind("<KeyRelease>", self.key_release)
          for name in "<Button-1>", "<Button-2>", "<Button-3>":
            self._tkcanvas.bind(name, self.button_press_event)
          for name in "<ButtonRelease-1>", "<ButtonRelease-2>", "<ButtonRelease-3>":
            self._tkcanvas.bind(name, self.button_release_event)
          for name in "<Button-4>", "<Button-5>":
            self._tkcanvas.bind(name, self.scroll_event)
          root = self._tkcanvas.winfo_toplevel()
          root.bind("<MouseWheel>", self.scroll_event_windows)
          self._master = master
          self._tkcanvas.focus_set()
          self.sourced = dict()
          def on_idle(*ignore):
            self.idle_event()
            return True
        def resize(self, event):
          width, height = event.width, event.height
          if self._resize_callback is not None:
            self._resize_callback(event)
          # compute desired figure size in inches
          dpival = self.figure.dpi
          winch = 1.0*width/dpival # fix
          hinch = 1.0*height/dpival # fix
          self.figure.set_size_inches(winch, hinch)
          self._tkcanvas.delete(self._tkphoto)
          self._tkphoto = tk.PhotoImage(
            #master=self._tkcanvas, width=width, height=height) # orig
            master=self._tkcanvas, width=int(width), height=int(height)) # mpl1.2 backend
          #self._tkcanvas.create_image(width/2,height/2,image=self._tkphoto) # orig
          self._tkcanvas.create_image(int(width/2),int(height/2),image=self._tkphoto) # mpl1.2 backend
          self.resize_event()
          self.show()
      class NavigationToolbar2TkAggFix(NavigationToolbar2TkAgg):
        def _init_toolbar(self):
          xmin, xmax = self.canvas.figure.bbox.intervalx
          height, width = 50, int(xmax-xmin) # fix
          tk.Frame.__init__(self, master=self.window,
                            width=width, height=height,
                            borderwidth=2)
          self.update()  # Make axes menu
          self.bHome = self._Button( text="Home", file="home.ppm",
                                     command=self.home)
          self.bBack = self._Button( text="Back", file="back.ppm",
                                     command = self.back)
          self.bForward = self._Button(text="Forward", file="forward.ppm",
                                       command = self.forward)
          self.bPan = self._Button( text="Pan", file="move.ppm",
                                    command = self.pan)
          self.bZoom = self._Button( text="Zoom",
                                     file="zoom_to_rect.ppm",
                                     command = self.zoom)
          self.bsubplot = self._Button( text="Configure Subplots", file="subplots.ppm",
                                     command = self.configure_subplots)
          self.bsave = self._Button( text="Save", file="filesave.ppm",
                                     command = self.save_figure)
          self.message = tk.StringVar(master=self)
          self._message_label = tk.Label(master=self, textvariable=self.message)
          self._message_label.pack(side=tk.RIGHT)
          self.pack(side=tk.BOTTOM, fill=tk.X)
    else: #matplotlib.__version__ >= "1":
      FigureCanvasTkAggFix = FigureCanvasTkAgg
      NavigationToolbar2TkAggFix = NavigationToolbar2TkAgg
  # to avoid conflict in expansion of guiconfdefault;
  # use "%s" % (vars) to write in stuff like filename etc later,
  # and inside the guiconfdefault code use "{0}".format(vars)!
  _guiconfdefault = """self._gk.id = "%s / %s / %s"

# self._gk = type('Object', (object,), {}) # already done
# do NOT use engineering notation @V specifier, in
# direct numeric value setters (eg. where float()!)

self._gk.cname = "@(n1)"
self._gk.cval  = "@(s1)"
try:    self._gk.cvalf = float(self._gk.cval)
except: self._gk.cvalf = 0.0

self._gk.xvals    = np.array( [self._gk.cvalf] , dtype=np.float)
self._gk.yvals    = np.array( [2] )
self._gk.marker   = "CUST1"
self._gk.marksz   = 10
self._gk.markclr  = "orange"


def _gk_setup(self):
  # self.frame.clear() # or ax.cla(): already done
  matplotlib.rc('font',**{'family':'sans-serif','sans-serif':['Arial']})
  matplotlib.rcParams.update({'font.size': 10})
  fnames = self._gk.id.split(' / ')
  self.ax.set_title('{0} plot for {1} (GUI config {2})'.format(fnames[0], fnames[1], fnames[2]))
  self.ax.title.set_fontsize(11)
  self.ax.set_xlabel('Numeric value')
  self.ax.set_ylabel('Column as position')
  self.fig.subplots_adjust(left=0.13, bottom=0.2, top=0.85, right=0.95)
  tlines = self.ax.plot(self._gk.xvals[0], self._gk.yvals[0],
    marker=self._gk.marker, markersize=self._gk.marksz, markerfacecolor=self._gk.markclr
    )
  self._gk.plotelem = tlines[0]
  annotoffsets = (-10,-20)
  self._gk.annot = self.ax.annotate('', xy=(self._gk.xvals[0], self._gk.yvals[0]),
    size = 8, ha = 'right', va = 'bottom',
    xytext = annotoffsets, textcoords = 'offset points',
    bbox = dict(
      boxstyle='round,pad=0.3', fc='yellow', alpha=0.55),
    arrowprops = dict(
      arrowstyle='->', connectionstyle='arc3,rad=0')
    )
  self._gk.anchtxt = mpl_toolkits.axes_grid.anchored_artists.AnchoredText("",
        prop=dict(size=8), frameon=True,
        loc=1, # which corner
        bbox_to_anchor=(0., 0.),      # this and below, to ...
        bbox_transform=self.ax.transAxes,  # place textbox out of plot
        )
  self._gk.anchtxt.patch.set_boxstyle("round,pad=0.,rounding_size=0.2")
  self.ax.add_artist(self._gk.anchtxt)

def _gk_update(self):
  global csvCO
  try:    self._gk.cvalf = float(self._gk.cval)
  except: self._gk.cvalf = 0.0
  self._gk.xvals[0] = self._gk.cvalf
  self._gk.plotelem.set_xdata(np.array([self._gk.cvalf]))
  if matplotlib.__version__ < "1":
    self._gk.plotelem.recache()
  self._gk.annot.xy = (self._gk.cvalf, self._gk.annot.xy[1])
  self._gk.annot.set_text("{0}:\\n{1}".format(self._gk.cname, self._gk.cval))
  self._gk.anchtxt.txt.set_text("Row/Line:\\n{0}".format(csvCO.currow))
  self.update_Axes_xylim_range(self.ax, min(self._gk.xvals), max(self._gk.xvals), "x")

"""
  class GuiContainer:
    def __init__(self):
      global csvCO
      self.isGuiUsed = False
      self.guiconfdir = None    # populate this: evt. either infiledir, or calldir
      self.guiconfext = "_gk"   # default extension: ._gk ("GUI 'k'onfiguration")
      self.guiconffile = None   # calculate this if not specified as cli argument
      self.guiconffileObj = None
      self.guiconfdefault = ""  #_guiconfdefault - do in determineAndOpenGUIconfFile
      self.guiconfdatastr = ""
      self.root = None
      self.frame = None
      self.redbutton = None
      self._gk = None       # main dynamic object file - storage for gui conf file objects
      self._gk_CSV = []       # lines of gui conf file containing CSV columnspec for expansion
      self._gk_CSVecs = []    # array of e(xpanded) c(olumn)s(pec) line arrays of gui conf file
      self._gk_REST = []      # rest of gui conf file lines
      self._gk_split = []     # key of how gui conf file is split into CSV and REST
      self._gk_setup = None   # gui conf setup function (reassign)
      self._gk_update = None  # gui conf update function (reassign)
      self.isRendering = False      # connected to Render PNG button; if True, play commands render frames
      self.renderSubdir = "render_" # no need for directory checks - can go directly into filename for .savefig
                                    # (this becomes a subdir prefix in determineAndOpenGUIconfFile)
      self.renderFrameCount = 0     # render frame count (used for rendered PNG filename)
      self.continuousRFC = False    # if True, do not erase previous PNGs (and reset renderFrameCount), on activating Render/Play (connected to cfc checkbox)
      self.RFCformat = "%05d"   # format for render frame count (for PNG filename): 5 digits, zero padded (left)
      self.renderedFrames = []  # container of all rendered PNG frames (filenames) up to now; used also for - and reset upon - delete
      self.isGuiUpdating = False # needed for thread synchronisation when rendering PNG
    def initBuildWindow(self):
      self.root = tk.Tk()
      self.root.option_add('*Dialog.msg.font', 'Helvetica 11') # font size messagebox
      self.root.geometry("650x450+50+50")
      self.root.title("{0} matplotlib GUI".format(sys.argv[0]))
      self.frame = tk.Frame(self.root, name="mframe")
      self.frame.pack(fill=tk.BOTH, expand=1)
      #create a (master) grid 5x7 in to which we will place elements.
      self.frame.columnconfigure(1, weight=0)
      self.frame.columnconfigure(2, weight=0)
      self.frame.columnconfigure(3, weight=1)
      self.frame.columnconfigure(4, weight=0)
      self.frame.columnconfigure(5, weight=0)
      self.frame.rowconfigure(1, weight=0)
      self.frame.rowconfigure(2, weight=0)
      self.frame.rowconfigure(3, weight=1)
      self.frame.rowconfigure(4, weight=0)
      self.frame.rowconfigure(5, weight=0)
      self.frame.rowconfigure(6, weight=1)
      self.frame.rowconfigure(7, weight=0)
      # start elements
      self.labelM11 = tk.Label(self.frame, text="CSV/log file:")
      self.labelM11.grid(row=1, column=1, columnspan=2, sticky=tk.E)
      v21 = tk.StringVar()
      self.labelM21 = tk.Label(self.frame, textvariable=v21, text="/...")
      self.labelM21.var = v21
      self.labelM21.grid(row=1, column=3, columnspan=1, sticky=tk.W)
      self.labelM12 = tk.Label(self.frame, text="At row/line:")
      self.labelM12.grid(row=2, column=1, columnspan=2, sticky=tk.E)
      v22 = tk.StringVar() #IntVar()
      self.labelM22 = tk.Label(self.frame, textvariable=v22)
      self.labelM22.var = v22
      self.labelM22.grid(row=2, column=3, columnspan=1, sticky=tk.W)
      self.fig = None
      self.ax = None
      self.figcanvas = None
      self.canvas = None
      v04 = tk.StringVar()
      self.labelM04 = tk.Label(self.frame, textvariable=v04, text="()", width=3)
      self.labelM04.var = v04
      self.labelM04.grid(row=5, column=1, columnspan=1, sticky=tk.W)
      self.labelM14 = tk.Label(self.frame, text="GUI conf file:")
      self.labelM14.grid(row=5, column=2, columnspan=1, sticky=tk.E)
      v24 = tk.StringVar()
      self.labelM24 = tk.Label(self.frame, textvariable=v24, text="/...")
      self.labelM24.var = v24
      self.labelM24.grid(row=5, column=3, columnspan=1, sticky=tk.W)
      # buttons row
      self.saveButton = tk.Button(self.frame, text="Save")
      self.saveButton.grid(row=4, column=2, columnspan=1, sticky=tk.W)
      self.frameButtons = tk.Frame(self.frame)
      self.frameButtons.grid(row=4, column=3, columnspan=1, sticky=tk.E + tk.W)
      self.frameButtons.columnconfigure(9, weight=1) # last column stretches
      self.reloadButton = tk.Button(self.frameButtons, text="Reload") #
      self.reloadButton.grid(row=1, column=1, sticky=tk.E)
      vmTB = tk.IntVar()
      self.mplToolbarButton = tk.Checkbutton(self.frameButtons, text="MToolbar", variable=vmTB, onvalue = 1, offvalue = 0, indicatoron=0)
      self.mplToolbarButton.var = vmTB
      self.mplToolbarButton.grid(row=1, column=2, sticky=tk.E + tk.N + tk.S)
      self.stepPrevButton = tk.Button(self.frameButtons, padx="1.5m", text="<")
      self.stepPrevButton.grid(row=1, column=3, sticky=tk.E)
      self.stepNextButton = tk.Button(self.frameButtons, padx="1.5m", text=">")
      self.stepNextButton.grid(row=1, column=4, sticky=tk.E)
      self.labelPNG = tk.Label(self.frameButtons, text="PNG:")
      self.labelPNG.grid(row=1, column=5, columnspan=1, sticky=tk.E)
      vcFC = tk.IntVar()
      self.cfcCheckbutton = tk.Checkbutton(self.frameButtons, text="cfc", variable=vcFC, onvalue = 1, offvalue = 0, indicatoron=1, padx="0", justify="left", borderwidth="0")
      self.cfcCheckbutton.grid(row=1, column=6, sticky=tk.E)
      self.cfcCheckbutton.var = vcFC
      vRP = tk.IntVar()
      self.renderPNGButton = tk.Checkbutton(self.frameButtons, padx="1.5m", text="Render", variable=vRP, onvalue = 1, offvalue = 0, indicatoron=0)
      self.renderPNGButton.grid(row=1, column=7, sticky=tk.E + tk.N + tk.S)
      self.renderPNGButton.var = vRP
      self.deletePNGButton = tk.Button(self.frameButtons, padx="1.5m", text="DEL", foreground="#ff0000")
      self.deletePNGButton.grid(row=1, column=8, sticky=tk.E)
      self.quitButton = tk.Button(self.frameButtons, text="Quit")
      self.quitButton.grid(row=1, column=9, sticky=tk.E) # set to .E so it sticks right, here?!
      #create the main text area with scrollbars
      self.xscrollbar = tk.Scrollbar(self.frame, orient=tk.HORIZONTAL)
      self.xscrollbar.grid(row=7, column=1, columnspan=3, sticky=tk.E + tk.W)
      self.yscrollbar = tk.Scrollbar(self.frame, orient=tk.VERTICAL)
      self.yscrollbar.grid(row=6, column=4, sticky=tk.N + tk.S)
      self.textarea = tk.Text(self.frame, wrap=tk.NONE, bd=0, height=17,
                          undo=True, name="textarea",
                          xscrollcommand=self.xscrollbar.set,
                          yscrollcommand=self.yscrollbar.set)
      self.textarea.grid(row=6, column=1, columnspan=3, rowspan=1,
                          sticky=tk.E + tk.W + tk.S + tk.N)
      self.xscrollbar.config(command=self.textarea.xview)
      self.yscrollbar.config(command=self.textarea.yview)
      # set bindings (buttons)
      self.quitButton.bind("<ButtonRelease-1>", self.quit)
      self.mplToolbarButton.bind("<ButtonRelease-1>", self.mplToolbarToggle)
      self.stepPrevButton.configure(command=lambda: call_delayed(csv_prev_row))
      self.stepNextButton.configure(command=lambda: call_delayed(csv_next_row))
      self.saveButton.configure(command=self.saveGUIconfFile)
      self.reloadButton.configure(command=self.reloadGUIconfFile)
      self.textarea.bindtags(('Text', '.mframe.textarea', '.', 'all'))
      self.textarea.bind("<KeyPress>", self.OnTextAreaKeyPress)
      self.renderPNGButton.bind("<ButtonRelease-1>", self.renderPNGToggle)
      self.cfcCheckbutton.bind("<ButtonRelease-1>", self.cfcCheckToggle)
      self.deletePNGButton.configure(command=lambda: self.resetDeleteRenderFrameCount(updateGUI=True))
      # finish init window building
      self.initGUILabelText()
      self.initMatPlot()
      #self.update() # too early here - csvCO not ready yet
    def OnTextAreaKeyPress(self, event):
      # "_tkinter.TclError: nothing to undo" can also be thrown - use try!
      if event.char == '\x1a': # Ctrl pressed
        if   event.keysym == 'z': # Ctrl-Z pressed
          try: self.textarea.edit_undo()
          except: pass
        elif event.keysym == 'Z': # Ctrl-Shift-Z pressed
          try: self.textarea.edit_redo()
          except: pass
      self.updateTextAreaGUI()
    def updateTextAreaGUI(self):
      # update text-area relevant GUI:
      isTAmodified = self.textarea.edit_modified()
      self.labelM04.var.set("(*)" if isTAmodified else "   ")
      self.saveButton.configure(state = tk.NORMAL if isTAmodified else tk.DISABLED)
    def initGUILabelText(self): # only for texts that won't change throughout run
      global csvCO
      ifpath = "" if csvCO.infiledir is None else csvCO.infiledir+os.sep
      ifpath += csvCO.infilearg
      self.labelM21.var.set(ifpath)
      gfpath = self.guiconfdir +os.sep+ self.guiconffile
      self.labelM24.var.set(gfpath)
      if (self.textarea.get(1.0, "end-1c") != self.guiconfdatastr):
        self.textarea.delete(1.0, tk.END)
        self.textarea.insert(tk.INSERT, self.guiconfdatastr)
        self.textarea.edit_modified(False)
        self.textarea.edit_reset()
    def setupCustomMarker01(self):
      def getCustomMarkerPath01(): # must be "global" function
        verts = [
            (0.0, 0.0), # left, bottom
            (0.0, 0.7), # left, top
            (1.0, 1.0), # right, top
            (0.8, 0.0), # right, bottom
            (0.0, 0.0), # ignored
            ]
        codes = [matplotlib.path.Path.MOVETO,
                 matplotlib.path.Path.LINETO,
                 matplotlib.path.Path.LINETO,
                 matplotlib.path.Path.LINETO,
                 matplotlib.path.Path.CLOSEPOLY,
                 ]
        pathCS1 = matplotlib.path.Path(verts, codes)
        return pathCS1, verts
      if matplotlib.__version__ < "1.0.0":
        # define a marker drawing function, that uses
        # the above custom symbol Path
        def _draw_mypath(self, renderer, gc, path, path_trans):
          gc.set_snap(renderer.points_to_pixels(self._markersize) >= 2.0)
          side = renderer.points_to_pixels(self._markersize)
          transform = matplotlib.transforms.Affine2D().translate(-0.5, -0.5).scale(side)
          rgbFace = self._get_rgb_face()
          mypath, myverts = getCustomMarkerPath01()
          renderer.draw_markers(gc, mypath, transform,
                                path, path_trans, rgbFace)
        # add this function to the class prototype of Line2D
        matplotlib.lines.Line2D._draw_mypath = _draw_mypath
        # add marker shortcut/name/command/format spec 'CUST1' to Line2D class,
        # and relate it to our custom marker drawing function
        matplotlib.lines.Line2D._markers['CUST1'] = '_draw_mypath'
        matplotlib.lines.Line2D.markers = matplotlib.lines.Line2D._markers
      else:
        def _set_mypath(self):
          self._transform = matplotlib.transforms.Affine2D().translate(-0.5, -0.5)
          self._snap_threshold = 2.0
          mypath, myverts = getCustomMarkerPath01()
          self._path = mypath
          self._joinstyle = 'miter'
        matplotlib.markers.MarkerStyle._set_mypath = _set_mypath
        matplotlib.markers.MarkerStyle.markers['CUST1'] = 'mypath'
        matplotlib.lines.Line2D.markers = matplotlib.markers.MarkerStyle.markers
    def getNumpyXyIter(self, inarr):
      # this supports older numpy, where nditer is not available
      if np.__version__ >= "1.6.0":
        return np.nditer(inarr.tolist())
      else:
        dimensions = inarr.shape
        xlen = dimensions[1]
        xinds = np.arange(0, xlen, 1)
        return np.transpose(np.take(inarr, xinds, axis=1))
    def initMatPlot(self):
      matplotlib.rc('font',**{'family':'sans-serif','sans-serif':['Arial']})
      matplotlib.rcParams.update({'font.size': 11})
      self.setupCustomMarker01()
      # matplotlib - the plot figure:
      self.fig = Figure(figsize=(5,4), dpi=100)
      self.ax = self.fig.add_subplot(111)
      t = np.arange(0.0,3.0,0.1)
      s = np.sin(2*np.pi*t)
      self.ax.plot(t,s , marker='CUST1', markerfacecolor='orange', markersize=10.0)
      self.ax.set_title('Tk embedding')
      self.ax.title.set_fontsize(12)
      self.ax.set_xlabel('X axis label')
      self.ax.set_ylabel('Y label')
      self.fig.subplots_adjust(left=0.13, bottom=0.2, top=0.85, right=0.95)
      # rest of tkinter GUI setup for matplotlib figure;
      # both row and column must expand (weight), so canvas can stretch correctly inside!
      self.frameMPL = tk.Frame(self.frame)
      self.frameMPL.grid(row=3, column=1, columnspan=5, sticky=tk.E + tk.W + tk.S + tk.N)
      self.frameMPL.columnconfigure(1, weight=1)  # column 1 expands
      self.frameMPL.rowconfigure(1, weight=1)     # row 1 expands
      self.figcanvas = FigureCanvasTkAggFix(self.fig, master=self.frameMPL)
      self.canvas = self.figcanvas._tkcanvas
      self.canvas.grid(row=1, column=1, columnspan=1, rowspan=1, sticky=tk.E + tk.W + tk.S + tk.N)
      self.toolbar = NavigationToolbar2TkAggFix( self.figcanvas, self.frameMPL )
      self.toolbar.update()
      self.toolbar.grid(row=2, column=1, columnspan=1, rowspan=1, sticky=tk.E + tk.W + tk.S + tk.N)
      self.mplToolbarButton.deselect() # this for initial hide (and ...
      self.mplToolbarToggle(None)      # ... render thereof) of mpl toolbar
    def mplToolbarToggle(self, event):
      if (self.mplToolbarButton.var.get() == 0):
        self.mplToolbarButton.config(relief=tk.FLAT)
        self.toolbar.grid_forget()
      else: # == 1
        self.mplToolbarButton.config(relief=tk.SUNKEN)
        self.toolbar.grid(row=2, column=1, columnspan=1, rowspan=1, sticky=tk.E + tk.W + tk.S + tk.N)
    def renderPNGToggle(self, event):
      global csvCO
      self.isRendering = True if self.renderPNGButton.var.get() else False
      if (self.isRendering):
        if not(self.continuousRFC):
          self.resetDeleteRenderFrameCount()
        else:
          if self.renderFrameCount == 0: # this can happen if doing cfc render from very start!
            self.renderFrameCount = 1
      if (self.isRendering): # ensure_dir
        d = os.path.dirname(self.renderSubdir + os.sep) #('render_/')
        if not os.path.exists(d):
          os.mkdir(d)
      else: #if not(self.isRendering):
        csvCO.isPlaying = False
    def cfcCheckToggle(self, event):
      self.continuousRFC = True if self.cfcCheckbutton.var.get() else False
    def update_Axes_xylim_range(self, inax, inmin, inmax, axchoice):
      if axchoice == "y":
        minx, maxx = inax.get_xlim()
        corners = (minx, inmin), (maxx, inmax)
      elif axchoice == "x":
        miny, maxy = inax.get_ylim()
        corners = (inmin, miny), (inmax, maxy)
      if matplotlib.__version__ >= "1":
        inax.set_xmargin(0.0) # no padding w/ autoscale
        inax.set_ymargin(0.0)
      inax.update_datalim(corners)      # needed; but it's not enough on it's own
      inax.autoscale_view(tight=False)  # needed; but it's not enough on it's own
    def update_GUI(self):
      global csvCO
      self.labelM22.var.set(str(csvCO.currow) + "\t" + csvCO.lastStatusLine)
      minrow, maxrow = csvCO.getLogfileLineLimits()
      self.stepPrevButton.configure(state = tk.NORMAL if csvCO.currow>minrow else tk.DISABLED)
      self.stepNextButton.configure(state = tk.NORMAL if csvCO.currow<maxrow else tk.DISABLED)
      self.deletePNGButton.configure(state = tk.NORMAL if (len(self.renderedFrames) and not(csvCO.isPlaying)) else tk.DISABLED)
      self.updateTextAreaGUI()
    def update(self):
      self.isGuiUpdating = True
      self.update_GUI()
      # ... and update matplotlib figure (may also render as PNG):
      self.root.after_idle(self.update_gkLines)
    def update_idle(self):
      self.isGuiUpdating = True
      self.root.after_idle(self.update)
    def saveGUIconfFile(self):
      gfpath = self.guiconfdir+os.sep+self.guiconffile
      # end-1c for correctly ignoring last \n in tk.Text:
      tatext = self.textarea.get(1.0, "end-1c") #tk.END)
      # only save if actual change:
      if (tatext != self.guiconfdatastr):
        self.guiconfdatastr = tatext
        try:
          with open(gfpath, "w+") as self.guiconffileObj:
            self.guiconffileObj.write(self.guiconfdatastr)
        except: # overwrite content with error here:
          errmsg = "Failed saving {0} with '{1}'; exiting.".format(gfpath, sys.exc_info()[0])
          self.guiconfdatastr = errmsg
      else:
        printso("\a") # bell
      self.textarea.edit_modified(False)
      self.textarea.edit_reset()
      try:
        self.parseGUIconfFile()
      except:
        import traceback
        errmsg = "problem parseGUIconfFile: " + str(sys.exc_info()) + "\n".join(traceback.format_tb(sys.exc_info()[2]))
        tkMsgBox.showerror(title="Error", message=errmsg, parent=self.root)
        return
      self.update_idle() #update_idle()
    def reloadGUIconfFile(self):
      # explicitly always replace (in case of extern edit)
      gfpath = self.guiconfdir+os.sep+self.guiconffile
      try:
        with open(gfpath, "r") as self.guiconffileObj:
          self.guiconfdatastr = self.guiconffileObj.read()
      except:  # overwrite content with error here:
        errmsg = "Failed opening {0} with '{1}'; exiting.".format(gfpath, sys.exc_info()[0])
        self.guiconfdatastr = errmsg
      self.textarea.delete(1.0, tk.END)
      self.textarea.insert(tk.INSERT, self.guiconfdatastr)
      self.textarea.edit_modified(False)
      self.textarea.edit_reset()
      try:
        self.parseGUIconfFile()
      except:
        import traceback
        errmsg = "problem parseGUIconfFile: " + str(sys.exc_info()) + "\n".join(traceback.format_tb(sys.exc_info()[2]))
        tkMsgBox.showerror(title="Error", message=errmsg, parent=self.root)
        return
      self.update_idle() #update_idle()
    def parseGUIconfFile(self):
      global csvCO
      self._gk_CSV = []
      self._gk_CSVecs = []
      self._gk_REST = []
      self._gk_split = []
      patColSpec = csvCO.patColSpec # (r'(@\([\S]+?\)|@\(*[0-9nvVs:,\[\]\.\-\+]+\)*)')
      # re-initialize the GUI config matplotlib objects' container:
      self._gk = type('Object', (object,), {})
      # parse
      tlines = self.guiconfdatastr.splitlines()
      for ix, tline in enumerate(tlines):
        hasCSVcolumnspec = False
        if tline.startswith('self._gk.'):
          if len(list(filter(None, patColSpec.split(tline)))) > 1:
            hasCSVcolumnspec = True
        if hasCSVcolumnspec:
          self._gk_CSV.append( tline )
          self._gk_split.append( [self._gk_CSV, len(self._gk_CSV)-1] )
        else:
          self._gk_REST.append( tline )
          self._gk_split.append( [self._gk_REST, len(self._gk_REST)-1] )
      for tline in self._gk_CSV:
        tecsa = csvCO.expandColumnspec(tline)
        self._gk_CSVecs.append(tecsa)
      # reconstruct _gk script again
      gk_CSV_curlines = self.getColumnspecFormatted_gkLines()
      gk_processed = []
      for splititem in self._gk_split:
        if splititem[0] == self._gk_CSV:
          gk_processed.append(gk_CSV_curlines[ splititem[1] ])
        else:
          gk_processed.append(self._gk_REST[ splititem[1] ])
      # get script string to execute (evaluate):
      gk_processed_str = "\n".join(gk_processed)
      gk_processed_AST = compile(gk_processed_str, "_gk Processed", "exec")
      global_env = globals()
      local_env = locals()
      exec (gk_processed_AST)
      _gk_setup = local_env["_gk_setup"]
      _gk_update = local_env["_gk_update"]
      # re-assign the methods which should now be there as (local) vars:
      self._gk_setup = _gk_setup.__get__(self, GuiContainer)
      self._gk_update = _gk_update.__get__(self, GuiContainer)
      # clear the figure, and call the setup
      self.ax.cla()
      self._gk_setup()
    def update_gkLines(self):
      global csvCO
      # get script string to execute (evaluate):
      # here only the lines with columnspec containing variables
      gk_CSV_curlines = self.getColumnspecFormatted_gkLines()
      gk_processed_str = "\n".join(gk_CSV_curlines)
      # eval/exec script
      gk_processed_AST = compile(gk_processed_str, "_gk Processed", "exec")
      global_env = globals()
      local_env = locals()
      exec(gk_processed_AST)
      # run the update function
      if self._gk_update: self._gk_update()
      self.fig.canvas.draw()      # we'd need a matplotlib refresh here
      self.isGuiUpdating = False  # now we're done updating
    def getColumnspecFormatted_gkLines(self):
      global csvCO
      instr = csvCO.lastrawdataline # instr = csvCO.getRawDataLine(csvCO.currow)
      formatd_gklines = []
      for gk_colspeca in self._gk_CSVecs:
        workstr = csvCO.getColumnspecFormattedString(instr, colspec=gk_colspeca, retfail="0", valuePad=False)
        formatd_gklines.append(workstr)
      return formatd_gklines
    def getFormattedRFC(self):
      return self.RFCformat % (self.renderFrameCount)
    def savePNGFrameRender(self):
      global csvCO
      # do not include `"_l" + str(csvCO.currow)` in the filename;
      # the video encoders can only handle one change (like %05d) in the filename!
      fname = self.renderSubdir + os.sep + self.getFormattedRFC() +"_"+ csvCO.infilebase + ".png"
      #printse("savePNGFrameRender", fname, "\n")
      self.ax.figure.savefig(fname)
      self.renderedFrames.append(fname)
      self.renderFrameCount += 1
    def resetDeleteRenderFrameCount(self, updateGUI=False):
      global csvCO
      self.renderFrameCount = 1
      if len(self.renderedFrames):
        csvCO.promptResultMsg = "Deleting {0} PNG frames".format(len(self.renderedFrames))
        csvCO.printStatusLine()
      while len(self.renderedFrames) > 0:
        fname = self.renderedFrames.pop()
        os.remove(fname) # unlink
      if updateGUI:
        self.update_GUI()
    def quit(self, event):
      if self.root:
        self.root.destroy()
      self.root = None
      if not(event.x_root == -42 and event.y_root == -42):
        call_delayed(exiter)
  """
  Instantiate the one (and only) global instance object of GuiContainer
  """
  guiCO = GuiContainer()



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
  global optargs, csvCO, guiCO
  if (optargs.dump_formatted or optargs.dump_playstep or optargs.dump_renderpng):
    optargs.curses = False
    csvCO.termmode = "default"
    if optargs.dump_formatted:
      # for csv lines, ensure stepping through
      # column 0 for fastest (fps don't matter
      # here, if no_play_sleep enabled):
      isParsed = csvCO.parsePlayerSettings("0 1 2")
    csvCO.disableStatusLine = True
    if optargs.dump_renderpng:
      csvCO.disableStatusLine = False
      optargs.gui = True
      checkGuiStartup()
      guiCO.renderPNGButton.var.set(1)
      guiCO.renderPNGToggle(None)
    csvCO.playerDirection = 1
    csvCO.moveToFirstRow()
    csvCO.printCurrentLine() # to display first row
    if optargs.dump_renderpng:
      t1 = threading.Timer(1.5, guiCO.update_idle)
      t1.start()
      t = threading.Timer(3, csvCO.handlePlayToggleCmd)
      t.start()
    else: csvCO.handlePlayToggleCmd()
    if optargs.dump_renderpng: # issue exit from "playback finished" here
      guiCO.root.mainloop()
    else:
      csvCO.playThreadID.join()
    exiter(0) # just exit(0) here blocks!

"""
in checkGuiStartup, we must have global references to
tkinterFound, numpyFound, matplotlibFound - even if we
don't set them in this function; however, they are otherwise
not visible to this function.
Also, same as in curses case - for all imported names, we
also need a global declaration inside this function, as we
set them here
"""
def checkGuiStartup():
  global optargs
  global guiCO, isGuiUsed
  global tkinterFound, numpyFound, matplotlibFound # we don't set, but must have
  global tk, np, matplotlib # must have - we set here (via import) now
  global itertools, mpl_toolkits, tkMsgBox # must have - we set here (via import) now
  global FigureCanvasTkAgg, NavigationToolbar2TkAgg, Figure # must have ...
  if optargs.gui:
    if optargs.stringmode:
      printse("GUI requested - but stringmode cancels it; will not start GUI.", LF)
      return
    elif tkinterFound and numpyFound and matplotlibFound:
      printse("GUI requested - starting...", LF)
      determineAndOpenGUIconfFile() # open in guiCO.initBuildWindow? nope
      # import required libraries
      if tkinterFound:
        printse("> loading [Tt]kinter... ")
        try:
          if sys.version_info[0] < 3:
            import Tkinter as tk
            import tkMessageBox as tkMsgBox
          else:
            import tkinter as tk
            import tkinter.messagebox as tkMsgBox
          printse("(%s) ok. "%(tk.__version__))
        except:
          tkinterFound = False
          printse("problem:", sys.exc_info()[0], " Exiting. ", LF)
          exiter(1)
      if numpyFound:
        printse("loading numpy... ")
        try:
          import numpy as np
          printse("(%s) ok. "%(np.__version__))
        except:
          numpyFound = False
          printse("problem:", sys.exc_info()[0], " Exiting. ", LF)
          exiter(1)
      if matplotlibFound:
        printse("loading matplotlib... ")
        try:
          import matplotlib
          matplotlib.use('TkAgg')
          from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2TkAgg
          from matplotlib.figure import Figure
          import matplotlib.path, matplotlib.patches
          # implement the default mpl key bindings
          #from matplotlib.backend_bases import key_press_handler
          if matplotlib.__version__ >= "1.0.0":
            import matplotlib.markers
          import mpl_toolkits.axes_grid.anchored_artists
          import itertools
          printse("(%s) ok. "%(matplotlib.__version__))
        except:
          matplotlibFound = False
          printse("problem:", sys.exc_info()[0], " Exiting. ", LF)
          exiter(1)
      printse(LF, LF)
      initMatplotlibClasses()
      isGuiUsed = guiCO.isGuiUsed = True
      guiCO.initBuildWindow()
      try:
        guiCO.parseGUIconfFile()
      except:
        import traceback
        printse("problem parseGUIconfFile:", sys.exc_info(), traceback.print_tb(sys.exc_info()[2]), " Exiting. ", LF)
        exiter(1)
    else:
      printse("GUI requested; however, dependencies: tkinter {0}available, numpy {1}available, matplotlib {2}available. Exiting.".format(
        "" if tkinterFound else "not ",
        "" if numpyFound else "not ",
        "" if matplotlibFound else "not "
      ), LF)
      exiter(1)

"""
determineAndOpenGUIconfFile() - also determines directories of guiconf file, render
# at this point, infilearg should be defined
# note: os.realpath doesn't crash on non-existing files; but returns a path in cwd!
# also open here, so we can dump results to terminal
# if not exist, create and write default settings in there
# and exit upon failure; "r+" mode also opens for writing, but doesn't create!
# w+ truncates - ok when creating new (append is a+)
# 'with .. as' ensures close()
exit if guiconf cannot be parsed!
"""
def determineAndOpenGUIconfFile():
  global csvCO, guiCO, optargs
  if optargs.gui_conf == "":  # autodetermine gui conf file name:
    if csvCO.inputSrcType == 3:   # local: linecache;    .isStoredInRAM = False
      guiCO.guiconfdir = csvCO.infiledir
    else:                         # stdin/nonlocal: RAM; .isStoredInRAM = True
      guiCO.guiconfdir = csvCO.calldir
    if csvCO.infilearg == "-": guiCO.guiconffile = "stdin" + "."+guiCO.guiconfext
    else: guiCO.guiconffile = csvCO.infilebase + "."+guiCO.guiconfext
  else:                       # use gui conf file from optargs
    guiCO.guiconfdir = os.path.dirname(os.path.realpath(optargs.gui_conf))
    guiCO.guiconffile = os.path.basename(optargs.gui_conf)
  gfpath = guiCO.guiconfdir+os.sep+guiCO.guiconffile
  guiCO.guiconfdefault = _guiconfdefault % (sys.argv[0], csvCO.infilearg, guiCO.guiconffile)
  guiCO.renderSubdir = guiCO.renderSubdir + os.path.splitext(guiCO.guiconffile)[0]  # was #+ csvCO.infilebase
  if not(optargs.quiet):
    printse("GUI conf file:", gfpath, "renderSubdir:", guiCO.renderSubdir, LF)
  # also open (or create) file here, so we can dump results to terminal
  isGuiConfRead = False
  if not(os.path.exists(gfpath)):
    if not(optargs.quiet): printse("creating GUI conf file... ")
    try:
      with open(gfpath, "w+") as guiCO.guiconffileObj:
        guiCO.guiconffileObj.write(guiCO.guiconfdefault)
      if not(optargs.quiet): printse("ok. ")
    except:
      errmsg = "Failed creating {0} with '{1}'; exiting.".format(gfpath, sys.exc_info()[0])
      printse(errmsg, LF)
      guiCO.guiconfdatastr = errmsg # just debug (wouldn't show due exit)
      exiter(1)
  if not(optargs.quiet): printse("reading GUI conf file... ")
  try:
    with open(gfpath, "r") as guiCO.guiconffileObj:
      guiCO.guiconfdatastr = guiCO.guiconffileObj.read()
    if not(optargs.quiet): printse("ok. ")
    isGuiConfRead = True
  except:
    errmsg = "Failed opening {0} with '{1}'; exiting.".format(gfpath, sys.exc_info()[0])
    printse(errmsg, LF)
    guiCO.guiconfdatastr = errmsg # just debug (wouldn't show due exit)
  printse(LF)
  if not(isGuiConfRead): exiter(1)



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
Also: note that is guiCO.root.quit() is ran before
the threads are joined (say, right after the message),
it will fail with "RuntimeError: main thread is not in main loop"
But - if it is called _after_ the threads are joined,
then it seems not a problem (with only a button in tk.Frame)!
But also, after adding textfields/scrollbars to Frame;
root.quit() starts blocking forcing pkill! Turns out happens
elsewhere: "freeze up IDLE a few times in the past.. associated
with the use of root.quit()." - so don't use root.quit,
just use root.destroy().. But then root.destroy() kills the
frame, but still blocks.. just frame.destroy sometimes exits
blocking, sometimes not..
Right - if we raise/dispatch an event via the quitButton (a fake
mouse click); then it is within the threading of the tkinter
framework - and afterwards root.destroy() may block a bit,
but it will exit when the window is properly destroyed.
Even with that fixed, it is so for curses; for termmode default
guiCO.root.destroy will still "main thread is not in main loop";
so don't even call guiCO.root.destroy() from exiter() -
rely on the quitButton.event_generate to do that
#guiCO.root.destroy() # no, via callback: guiCO.quitButton.event_generate...
"""
def exiter(exitstatus=0):
  global csvCO
  global guiCO, isGuiUsed
  printse(LF + "Waiting for threads to terminate... ")
  csvCO.isRunning = False
  if not(csvCO.infileObj.closed):
    csvCO.infileObj.close()
  for ithr in csvCO.threads:
    ithr.join()
  if isGuiUsed:
    if guiCO.root is not None:
      guiCO.quitButton.event_generate("<ButtonRelease-1>", rootx=-42, rooty=-42)
  printse("exited.", LF)
  sys.exit(exitstatus)


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
  optparser.add_argument('-g', '--gui', action='store_true',
                          help='Start GUI window; requires tkinter ({0}available), numpy ({1}available), matplotlib ({2}available)'.format(
                            "" if tkinterFound else "not ",
                            "" if numpyFound else "not ",
                            "" if matplotlibFound else "not "
                          ))
  optparser.add_argument('-k', '--gui-conf', action='store',
                          type=str, default="",
                          help="for GUI mode, use this configuration file, instead of auto-determined one; default if unspec'd: \"%(default)s\"")
  optparser.add_argument('-j', '--dump-renderpng', action='store_true',
                          help='Bypass normal operation; like --dump-formatted, but start gui and render png, and exit')
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
  global guiCO, isGuiUsed

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

  checkGuiStartup()

  initKeyboardUIFuncs()

  # if CSV header parsed; start step "player" keyboard UI thread (terminal)
  t1 = threading.Thread(target=termUIKeyboardNavigationThread)
  t1.start()
  csvCO.threads.append(t1)

  # printout first line for start; not implicitly, but
  # forcing shouldMove to True, so it executes anyways
  csvCO.moveToFirstRow()
  csvCO.printCurrentLine()

  if isGuiUsed:
    guiCO.root.mainloop()
  else:
    # "if your main has nothing better to do" http://stackoverflow.com/a/1635084/277826
    # must have this, _with_ isRunning check, to have Python 2.7 exit on Ctrl-C!
    while ( (threading.active_count() > 0) and csvCO.isRunning ):
      time.sleep(0.1)


# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


