#!/usr/bin/env python
################################################################################
# traceFGLatLogfile2Csv.py                                                     #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

"""
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()
versionf = scriptdir + os.sep + "VERSION"
try: __version__ = next(open(versionf))
except:
  versionf = scriptdir + os.sep + ".." + os.sep + "VERSION"
  try:    __version__ = next(open(versionf))
  except: __version__ = "0.1" #sys.exc_info()[1]

optargs = None
usagemsg = "traceFGTXLogfile2Csv.py ( %(prog)s ) v.{0}".format(__version__) + """
Converts Linux kernel ftrace "function_graph" log file obtained with trace-cmd report -O fgraph:exitprint (with numeric data for _pointer in another, normal "function_graph" log) to CSV (python2.7/3.2)

Usage:
  python traceFGTXLogfile2Csv.py -s ./captures 2>/dev/null

* Stderr is used for messages (redirect to /dev/null to suppress)
* Stdout is not particularly used

The script will look for tracepipe-*.txt (tracepipe-dummy.txt ...) files in the directory given as input argument, and generate respective .csv files there.

NOTE: must sort in order to get accurate timestamps (in increasing order)!
"""


"""
don't use print (complication with __future__);
a custom function based on sys.stdout.write works
for both Python 2.7 and 3.x
"""
def printso(*inargs):
  outstr = ""
  #for inarg in inargs:
  #  outstr += str(inarg) + " "
  #outstr += "\n"
  outstr = " ".join(list(map(str, inargs)))
  sys.stdout.write(outstr)
  sys.stdout.flush()

def printse(*inargs):
  outstr = ""
  #for inarg in inargs:
  #  outstr += str(inarg) + " "
  #outstr += "\n"
  outstr = " ".join(list(map(str, inargs)))
  sys.stderr.write(outstr)
  sys.stderr.flush()

"""
test for python2/python3 ; __future__ since python2.6
note: cannot import __future__ conditionally (compile-time statement)
(also, sometimes get a stdout lock at import urlopen, requiring
keypress - in that case, reboot, try again)
"""
import __future__ # we can't use this really; keep it anyway
if sys.version_info[0] < 3:
  #printso("sys.version < 3\n")
  from urlparse import urlparse
  from urllib import urlopen
  from StringIO import StringIO
  text_type = unicode
  binary_type = str
else:
  #printso("sys.version >= 3\n")
  from urllib.request import urlopen
  from urllib.parse import urlparse
  from io import StringIO
  text_type = str
  binary_type = bytes

# doesn't really help with outer for bash loop; though note
#  http://serverfault.com/questions/105386/bash-loop-how-to-stop-the-loop-when-i-press-control-c-inside-a-command
# in bash, either `|| break`, or `(for ...)`, is needed
# otherwise, the python script will exit even without the
# signal trap, due to KeyboardInterrupt exception
#~ import signal
#~ def signal_handler(signal, frame):
  #~ print 'You pressed Ctrl+C!'
  #~ sys.exit(0)
#~ signal.signal(signal.SIGINT, signal_handler)


"""
rest of imports that work the same for 2.7 and 3.x:
"""
import linecache
import re
import pprint # for debugging
import collections # OrderedDict, 2.7+
import argparse # command line options (instead of getopt), 2.7+
import glob # select matching filenames

# ##################### FUNCTIONS     ##########################################

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


# for testing logfiles:
# awk '{if ($3 == "0)"){print}}' captures-2013-07-30-02-42-28/tracepipe-dummy.txt

"""
Here we find matches ;
column names are fixed;
"""
patStartComment = re.compile(r'^#')
patNonSpace = re.compile(r'(\S+)')
patDigits = re.compile(r'(\d+)')
# in function_graph ftrace, there is always a start space!
patStartTaskSw = re.compile(r'^ [-]+')
# pipe must be escaped as pattern
patPipe = re.compile(r'\|')
patTaskSw = re.compile(r' =>')
patDotDigits = re.compile(r'([\d\.]+)')
patTStamp = re.compile(r'\s*([\d\.]+)') #(r'([ \d\.\[\]:]+)')
patCol1Split = re.compile(r'\) |(-[\d]+)')
patFSingle = re.compile(r';')
patFEntry = re.compile(r'{')
patFExit = re.compile(r'}')
patReadi = re.compile(r'readi_func')
patPointer = re.compile(r'_pointer')
patSpaceIndent = re.compile(r'^([\s]+)')
patIrqIn  = '==========>' #re.compile(r'==========>')
patIrqOut = '<==========' #re.compile(r'<==========')
patFinTSw = 'finish_task_switch' #re.compile(r'finish_task_switch')
patReadiFunc = 'readi_func'
patPointer = '_pointer:'
patPointerSplit = re.compile(r'[:()\s]')
patSpaceEPCSplit = re.compile(r'[\s:\[\]]+')
patSpaceEPSplit = re.compile(r'[\s\[\]]+')
patProcSplit = re.compile(r'(-[\d]+)')
patFuncExitSplit = re.compile(r'[}/\s]')
patKernComment = re.compile(r'/\*\s*(.+?)\s*\*/') # 'non-greedy'/"lazy"? inside, so it rstripts spaces at end!
patOtherKern = re.compile(r'(spcm_drain|pcm_startr)')

firstTS = -1.0
#~ frgbtp = 0 # frg bytes total playback
#~ frgbtc = 0 # frg bytes total capture
frameSizeBytes = 4

# marker irq stack - maintain per CPU!
mIrqStack = []
mIrqStack.append([]) # mIrqStack[0]
mIrqStack.append([]) # mIrqStack[1]

sciUnits = {'us': 'e-6'}

"""
# when doing parseLineO - we're only interested in
# obtaining the proper _pointer; readi_func from userspace; and the IRQ switch lines (for cross-check)
# actual data (rest of kernel funcs) is obtained in parseLineX
# they both save to the same dictCollection; (which is sorted
# with relative timestamps only after both parses)
# actually, now with latency, there are no readi_func from userspace
# written explicitly - they have to be extrapolated!
"""
def parseLineO(inline, innumline):
  global dictCollection
  global mIrqStack
  inline = inline.rstrip('\n') # chomp LF first (else cannot detect empty string!)
  # do not process if line is empty string
  if not(inline):
    return
  # do not process if comment line or taskswitch marker line
  if patStartComment.match(inline) or patStartTaskSw.match(inline):
    return
  # for IRQs, we expect IRQ in, then IRQ out;
  # if we start with IRQ out - or end with IRQ in, we drop those
  # collect the IRQ in a stack, and compact them
  # to one event with duration in dictCollection
  tdl = None
  if patReadiFunc in inline:
    tdl = collections.OrderedDict()
    # NB: maxsplit=2 means "aa", " ", "bb", " ", "rest..."!
    columns = patPipe.split(inline)  #; printso(columns, '\n')
    ktime = patDotDigits.findall(columns[0])[0]
    tdl["time"] = ktime
    tdl["ktime"] = ktime # save orig value
    col1parts = filter(None, patCol1Split.split(columns[1]))
    tdl["cpu"] = col1parts[0].strip()
    tdl["proc"] = col1parts[1].strip()
    tdl["pid"] = col1parts[2][1:] # avoid hanging minus
    tdl["durn"] = "0"
    tdl["ftype"] = "1" # type 1: userspace marker
    tdl["func"] = patReadiFunc
    tdl["findent"] = "0"
  elif patPointer in inline:
    tdl = collections.OrderedDict()
    columns = patPipe.split(inline)  #; printso(columns, '\n')
    ktime = patDotDigits.findall(columns[0])[0]
    tdl["time"] = ktime
    tdl["ktime"] = ktime # save orig value
    col1parts = filter(None, patCol1Split.split(columns[1]))
    tdl["cpu"] = col1parts[0].strip()
    tdl["proc"] = col1parts[1].strip()
    tdl["pid"] = col1parts[2][1:] # avoid hanging minus
    tdl["durn"] = "0"
    tdl["ftype"] = "2" # type 2: pointer data
    tdl["func"] = patPointer
    # calc proper indent:
    indent = 0
    spacestartmatch = patSpaceIndent.match(columns[3][2:]) # avoid 2 spaces generic indent!
    if spacestartmatch:
      indent = len(spacestartmatch.group()) # get indent
    tdl["findent"] = str(indent)
    # grab pointer data
    pparts = filter(None, patPointerSplit.split(columns[3][2+indent:]))
    tdl["ppos"] = pparts[2]
    tdl["aptr"] = pparts[5]
    tdl["hptr"] = pparts[7]
    tdl["rdly"] = pparts[9] # runtime delay
    tdl["strm"] = pparts[3] # stream: 0 playback, 1 capture
  #~ elif '/*' in inline: # treat any other kernel comment as userspace cmd, too? No, too many at times (can catch some closing statements)
  elif patOtherKern.findall(inline): #
    tdl = collections.OrderedDict()
    columns = patPipe.split(inline)  #; printso(columns, '\n')
    ktime = patDotDigits.findall(columns[0])[0]
    tdl["time"] = ktime
    tdl["ktime"] = ktime # save orig value
    col1parts = filter(None, patCol1Split.split(columns[1]))
    tdl["cpu"] = col1parts[0].strip()
    tdl["proc"] = col1parts[1].strip()
    tdl["pid"] = col1parts[2][1:] # avoid hanging minus
    tdl["durn"] = "0"
    tdl["ftype"] = "1" # type 1: userspace marker
    tdl["func"] = patKernComment.findall(columns[3])[0]
    tdl["findent"] = "0"
  elif patIrqIn in inline:
    # tdl here goes to mIrqStack!
    tdl = collections.OrderedDict()
    columns = patPipe.split(inline)  #; printso(columns, '\n')
    ktime = patDotDigits.findall(columns[0])[0]
    tdl["time"] = ktime
    tdl["ktime"] = ktime # save orig value
    col1parts = filter(None, patCol1Split.split(columns[1]))
    tdl["cpu"] = col1parts[0].strip()
    tdl["proc"] = col1parts[1].strip()
    tdl["pid"] = col1parts[2][1:] # avoid hanging minus
    tdl["durn"] = "0"
    tdl["ftype"] = "3" # type 3: IRQ marker (mIRQ)
    tdl["func"] = "mIRQ"
    tdl["findent"] = "0"
    mIrqStack[int(tdl["cpu"])].append(tdl)
    tdl = None # do NOT add to dictCollection at end
  elif patIrqOut in inline:
    # if tdl match here, it goes to dictCollection!
    tdl = collections.OrderedDict()
    columns = patPipe.split(inline)  #; printso(columns, '\n')
    ktime = patDotDigits.findall(columns[0])[0]
    tdl["time"] = ktime
    tdl["ktime"] = ktime # save orig value
    col1parts = filter(None, patCol1Split.split(columns[1]))
    tdl["cpu"] = col1parts[0].strip()
    tdl["proc"] = col1parts[1].strip()
    tdl["pid"] = col1parts[2][1:] # avoid hanging minus
    tdl["durn"] = "0"
    tdl["ftype"] = "3" # type 3: IRQ marker (mIRQ)
    tdl["func"] = "mIRQ"
    tdl["findent"] = "0"
    cid = int(tdl["cpu"])
    if len(mIrqStack[cid]) > 0:
      otdl = mIrqStack[cid].pop()
      # timestamps in seconds - duration in seconds too
      # (up to 6 decimals - can only get microsecond resolution here!)
      duration = float(tdl["time"]) - float(otdl["time"])
      # switch tdl to otdl - for correct start timestamp!
      tdl = otdl
      # now write calculated duration:
      tdl["durn"] = "%.6f" % ( duration )
    else:
      printse("Problem: unmatched mIRQ out; dropping! \n")
      tdl = None
  if tdl is not None:
    #~ printse("\n",tdl,"\n") # debug
    dictCollection.append(tdl)
  printse("\rParsed line " + str(innumline))

"""
# when doing parseLineX - we're only interested in
# stuff we didn't get in parseLineO - which is most
# of the kernel functions; so we want:
# * entries if from a kernel leaf function; and
# * exits if from a kernel nested function ( which
# thanks to the `exitprint` plugin, have both start
# and duration encoded)
# since we don't print anything on nested entries (due `exitprint`),
# we can just match '|' to see if it's a line we want to parse!
# because of this, timestamps will be out of order
# in dictCollection after this pass
"""
def parseLineX(inline, innumline):
  global dictCollection
  inline = inline.rstrip('\n') # chomp LF first (else cannot detect empty string!)
  # do not process if line is empty string
  if not(inline):
    return
  # process only if line contains a pipe `|`:
  tdl = None
  if "|" in inline:
    tdl = collections.OrderedDict()
    # in printout from trace-cmd with `exitprint`;
    # there is only one pipe per line - split there first
    columnstr, kfunc = inline.split('|')
    # NOTE: here we could get a process name line "kworker/1:1-25";
    # so we cannot use patSpaceEPCSplit: '[\s:\[\]]+' (will mess up due colons)
    # so use pattern without colon (patSpaceEPSplit) here; and remove the
    # colon from time manually (it's the last character there anyway)
    columns = filter(None, patSpaceEPSplit.split(columnstr))
    tdl["time"] = columns[2][:-1]
    tdl["ktime"] = tdl["time"] # save orig value
    tdl["cpu"] = "%d" % (int(columns[1]))
    procparts = patProcSplit.split(columns[0])
    tdl["proc"] = procparts[0]
    tdl["pid"] = procparts[1][1:] # avoid hanging minus
    durn_unit = columns[-1] # last in columns is the unit ('us')
    durn      = columns[-2] # before last in columns is the duration
    # express duration in seconds;
    # (here I've only gotten 'us' as unit; with decimals - ns precision)
    durn_f = float( "%s%s" % (durn, sciUnits[durn_unit]) )
    tdl["durn"] = "%.9f" % (durn_f)
    tdl["ftype"] = "4" # type 4: kernel function
    # out here we have either entry for a leaf func (with ';')
    # or exit for a nest func (with '} /') - parse accordingly
    if ';' in kfunc:        # leaf entry
      kfuncs = kfunc[2:] # avoid 2 spaces generic indent!
      # calc proper indent:
      indent = 0
      spacestartmatch = patSpaceIndent.match(kfuncs) # avoid 2 spaces generic indent!
      if spacestartmatch:
        indent = len(spacestartmatch.group()) # get indent
      tdl["func"] = kfuncs[indent:] # drop indents from kernel function
      tdl["findent"] = str(indent)
    elif '} /' in kfunc:    # nest exit
      kfuncs = kfunc[2:] # avoid 2 spaces generic indent!
      kfexparts = filter(None, patFuncExitSplit.split(kfuncs))
      # in this case, the columns[2] timestamp is actually function exit
      # while function entry timestamp is in kfexparts[1] - modify:
      # (duration is still the same)
      tdl["time"] = kfexparts[1]
      tdl["ktime"] = tdl["time"] # save orig value
      # calc proper indent:
      indent = 0
      spacestartmatch = patSpaceIndent.match(kfuncs) # avoid 2 spaces generic indent!
      if spacestartmatch:
        indent = len(spacestartmatch.group()) # get indent
      # append '()' to function name if it isn't already there
      if kfexparts[0][-2:] != "()":
        kfexparts[0] = kfexparts[0] + "()"
      tdl["func"] = kfexparts[0] # indents from kernel function dropped already
      tdl["findent"] = str(indent)
    else:
      printse("\nProblematic kernel function at %s; skipping\n" % (tdl["time"]))
      tdl = None
  if tdl is not None:
    #~ printse("\n",tdl,"\n") # debug
    dictCollection.append(tdl)
  printse("\rParsed line " + str(innumline))


def calcMinAndNotionalTime():
  global dictCollection
  global optargs # not setting, but keep this
  # first, find the minimum time (note, here the dictCollection
  # may be unsorted) - and subtract from time, so kernel log capture starts from 0
  # added cutatfunc - if specified, use that for min_time, and add offset
  # (e.g. snd_pcm_link kern-userspace 5.874080-5.874066 = 1.4e-05 ;
  # kern-typ.start 5.874080-5.874058 = 2.2e-05; so take 25 us = 0.000025 offset)
  # NOTE: some optargs.cutatfunc MUST be specified with a semicolon,
  # if it appears (e.g. 'snd_pcm_pre_start();')!
  min_time = -1000 # big value as sanity check
  if (optargs.cutatfunc != ""):
    offset = 0.000025
    printse("Will attempt to make log start with", optargs.cutatfunc, "offset", offset, "\n")
    for item in dictCollection:
      if(item['func'] == optargs.cutatfunc):
        min_time = float(item['ktime'])-offset
        break # exit for loop
  #~ else: # nope, do also if the above fails for some reason:
  if (min_time == -1000):
    printse("min_time not specified; looking for log start\n")
    min_time = min(float(item['ktime']) for item in dictCollection)
  # adjust time:
  for item in dictCollection:
    ntime = float(item['ktime']) - min_time
    item['time'] = "%.6f" % (ntime)
  # clear negative time values
  if (optargs.cutatfunc != ""):
    # filter(lambda dubitem: not(dubitem[3]>0), dubIRQs[tcpu])
    newlist = filter(lambda dictItem: float(dictItem['time'])>=0.0, dictCollection)
    dictCollection = newlist



def sortDictCollection():
  global dictCollection
  #~ if optargs.sorttime: # now explicit
  # the output of `cat /sys/kernel/debug/tracing/trace_pipe`
  # is not guaranteed to preserve order of lines; but
  # at least it seems to provide proper timestamps
  # if the command line option is given, then
  # sort the array of dict dictCollection according to rel. timestamp!
  newlist = sorted(dictCollection, key=lambda k: float(k['time']))
  dictCollection = newlist


"""
extrapolateUserSpaceCmds expects parseLineX pass to be finished
look up sys_ioctl, where snd_pcm_lib_read/write has happened,
"rewind" the sys_ioctl's timestamp for 5 (was 10) us; and
insert the expected command as userspace.
It also assumes sorted array!
It also assumes sys_ioctl is always followed by snd_pcm_playback/capture_ioctl first!
Also, this calculates whether a mIRQ is playback, capture or none
(i.e. assign stream direction to mIRQ - for easier coloring in gnuplot):
 essentially, what needs to be done is to check whether _pointer is
 called in the duration of mIRQ, and get stream (direction: play/capt)
 from that _pointer.
 However, that is not enough - a stronger condition is needed (else
 fake decisions are made): _pointer needs to be in context (within duration)
 of snd_pcm_period_elapsed; and mIRQ+_elapsed+_pointer need to happen on
 the same processor and same processID (otherwise, fakes can be triggered
 by _pointer called in a different context on different processor, which
 happens before the actual _pointer that should be considered)
 (gnuplot otherwise decides via presence of via `azx_interrupt` or
 `dummy_hrtimer_callback`, as appropriate for given debuglog)
 However, that is not enough either - sometimes _two_ (azx)_interrupt can
 hit in a single mIRQ (on same processor); so we again need to manage an
 IRQ queue, so we take that into account - so to solve this, we attribute
 for the mIRQ stream direction: -2 for audio unrelated; -1 for (one or
 more) _interrupt present in mIRQ; 0 or 1 for _elapsed->_pointer present
 within mIRQ, inheriting that stream direction;
 then gnuplot only has to select for mIRQ >= -1
 Also, nested mIRQ on the same processor with _pointer will all match; so
 do not exit the _pointer/mIRQ for loop early - keep going until the end,
 keeping track of changes; so if found twice, reset the previous mIRQ and
 apply to this one!
NOTE: in dummy driver, e.g. snd_pcm_do_start can be called _twice_ in
 context of same sys_ioctl; for now, the second call will be skipped (i.e.
 no userspace cmd will be attributed to it), and a warning will be
 printed for it in the stderr log printouts
Also, in dummy driver, hrtimer callback for both capture and playback
 can be answered by a _single_ IRQ! Thus, mIRQ direction -1 here makes
 no sense (cannot occur callback without _elapsed in same mIRQ?);
 we (may) have:
 hda: mIRQ { _interrupt (-1) { snd_pcm_period_elapsed { _pointer (0,1) } } } } x 2
 dum: mIRQ { hrt_callback x2 ; hrtimer_pcm_elapsed { snd_pcm_period_elapsed { _pointer (0,1) } } x2 }
 Thus - keep a per-cpu dubIRQs array; push mIRQ index on it anytime _interrupt/_callback is matched;
 then when checking _pointer, on match, pop(first) from dubIRQs array; then next time
 when checking _pointer, if dubIRQs is not empty, _push another_ mIRQ in dict collection,
 with the same time attributes as the respective _interrupt/_callback? No, that may be
 too difficult to manage correctly; instead, collect ids of mirq, _int/_call, and _pointer;
 and at end, loop through dubIRQs, and "correct" (insert) mIRQs in dictCollection as needed
However, hda-intel can *also* have two _elapsed/_pointer in answered by single mIRQ, which can
 *also* be nested! Which is why now there is two more passes, where outer IRQs are detected
 and sorted and eliminated in dubIRQs, before any corrections/insertions of mIRQ are made!
Also, two _elapsed/_pointers can appear in single mIRQ for hda-intel;
Also, an inner mIRQ can appear without _pointer, whereas the outer has _pointer;
 handle that so inner increments outer only if it has the same _pointer!
 NOTE: in dummy, this may result with detection of "spurious" -1 mIRQs for the inner mIRQs,
 while the outer mIRQs end up being treated as 0/1 (play/capt mIRQ); for
 the time being, this will not be solved further.
Also, added *_poll as userspace commands (related to sys_poll; but have
 individual userspace markers)
"""
def extrapolateUserSpaceCmds():
  global dictCollection
  calcMinAndNotionalTime()
  sortDictCollection()
  ts_ioctl = ""
  kts_ioctl = ""
  cpu_ioctl = ""
  proc_ioctl = ""
  pid_ioctl = ""
  pc_ioctl = -1
  toffs = 5e-6 # 10e-6
  mirqindex = -1
  mirqcinds = [] # and per cpu, arrays:
  mirqcinds.append([]) #mirqcinds[0] = []
  mirqcinds.append([]) #mirqcinds[1] = []
  mirqpcval = -1
  elapindex = -1
  # should log elapindex per cpu; but no need to keep arrays
  elapcinds = [] #
  elapcinds.append(elapindex) # elapcinds[0]
  elapcinds.append(elapindex) # elapcinds[1]
  dubIRQs = [] # and per cpu, arrays:
  dubIRQs.append([]) #dubIRQs[0] = []
  dubIRQs.append([]) #dubIRQs[1] = []
  tcollect = list()
  for id, ditem in enumerate(dictCollection):
    if "func" in ditem:
      if ditem["ftype"] == "3":   # type 3: IRQ marker (mIRQ)
        mirqindex = id
        mirqcinds[int(ditem["cpu"])].append(mirqindex)
        mirqpcval = -2
        dictCollection[mirqindex]["strm"] = str(mirqpcval) # init at -2
      elif ditem["func"] == 'azx_interrupt()' or ditem["func"] == 'dummy_hrtimer_callback()': # interrupt detection
        tcpu = int(ditem["cpu"])
        istart = float(ditem["time"])
        idurn = float(ditem["durn"])
        mfound = [-1, -1] # keep track if found for nested mIRQ
        for mind in mirqcinds[tcpu]:
          mirqstart = float(dictCollection[mind]["time"])
          mirqdurn = float(dictCollection[mind]["durn"]) # duration
          if ( (mirqstart < istart) and (istart+idurn < mirqstart+mirqdurn) ):
            if not(mfound == [-1, -1]): # something has been found previously; restore it
              mfind = mfound[0]
              dictCollection[mfind]["strm"] = mfound[1]
            mfound = [mind, dictCollection[mind]["strm"]] # remember old vals if found
            dictCollection[mind]["strm"] = str(-1) # set to -1 if interrupt present
            dictCollection[mind]["ppos"] = str(-1) # set also ppos to -1 if interrupt present
            dubIRQs[tcpu].append([mind, id, -1, 0]) # ids of mirq, _int/_call, and _pointer (-1, later) - and IRQ nest level (0, later)
            #~ printse("dub ", dubIRQs, "\n")
            #break # exit for-loop if we found anything this time # do NOT exit early, to account for nested mIRQ!
      elif ditem["func"] == 'snd_pcm_period_elapsed()': #
        elapindex = id
        elapcinds[int(ditem["cpu"])] = elapindex
      elif ditem["ftype"] == "2": # type 2: pointer data
        ptrstart = float(ditem["time"])
        ptrcpu = int(ditem["cpu"])
        ptrpid = int(ditem["pid"])
        mfound = [-1, -1] # keep track if found for nested mIRQ
        for mind in mirqcinds[ptrcpu]: # was: # if mirqindex > -1:
          mirqstart = float(dictCollection[mind]["time"])
          mirqdurn = float(dictCollection[mind]["durn"]) # duration
          #mirqcpu = int(dictCollection[mind]["cpu"])
          mirqpid = int(dictCollection[mind]["pid"])
          elapindex = elapcinds[ptrcpu]
          elapstart = float(dictCollection[elapindex]["time"])
          elapdurn = float(dictCollection[elapindex]["durn"]) # duration
          #elapcpu = int(dictCollection[elapindex]["cpu"])
          elappid = int(dictCollection[elapindex]["pid"])
          #cond_cpu = ( (ptrcpu == mirqcpu) and (ptrcpu == elapcpu) )
          cond_pid = ( (ptrpid == mirqpid) and (ptrpid == elappid) )
          cond_edurn = ( ( mirqstart < elapstart ) and ( elapstart+elapdurn < mirqstart+mirqdurn ) )
          #~ cond_ppos = ((mirqstart < ptrstart) and (ptrstart < mirqstart+mirqdurn))
          cond_ppos = ((elapstart < ptrstart) and (ptrstart < elapstart+elapdurn))
          if (cond_pid and cond_edurn and cond_ppos):
            #~ printse(ptrcpu, ": ", mind, ": ", mfound, " / ", dictCollection[mind], " / ", dubIRQs[ptrcpu], " / ", ditem, "\n")
            if not(mfound == [-1, -1]): # something has been found previously (outer); restore it
              mfind = mfound[0]
              dictCollection[mfind]["strm"] = mfound[1]
            #~ printse("mir ", mirqcinds, "\n")
            for dubid, dubitem in enumerate(dubIRQs[ptrcpu]):
              if (dubitem[0] == mind):
                if (dubitem[2] == -1): # yet unhandled
                  dubitem[2] = id
                else: # could be extra valid _pointer in a single mIRQ - append
                  #printse("INSERT\n")
                  tmpd = dubitem[:] # copy
                  tmpd[2] = id
                  dubIRQs[ptrcpu].insert(dubid+1, tmpd) # mirq, _int/_call, and _pointer, and irq nest level - at index dubid+1 for correct ordering
                break # exit this for-loop
            mfound = [mind, dictCollection[mind]["strm"]] # remember old vals if found
            mirqpcval = ditem["strm"]
            dictCollection[mind]["strm"] = str(mirqpcval)
            dictCollection[mind]["ppos"] = ditem["ppos"]
            #~ printse(dictCollection[mind]["strm"], "\n")
            mirqindex = -1 # no need anymore; but keep it
            elapindex = -1
            #~ break # exit for-loop # do NOT exit early, to account for nested mIRQ!
      if ditem["func"] == 'sys_ioctl()':
        ts_ioctl = ditem["time"]
        kts_ioctl = ditem["ktime"]
        cpu_ioctl = ditem["cpu"]
        proc_ioctl = ditem["proc"]
        pid_ioctl = ditem["pid"]
      if ditem["func"] == 'snd_pcm_playback_ioctl()':
        pc_ioctl = 0 # playback: 0
      if ditem["func"] == 'snd_pcm_capture_ioctl()':
        pc_ioctl = 1 # capture: 1
      if (ditem["func"] == 'snd_pcm_lib_read1()') \
        or (ditem["func"] == 'snd_pcm_lib_write1()') \
        or (ditem["func"] == 'snd_pcm_link()') \
        or (ditem["func"] == 'snd_pcm_do_start()') \
        or (ditem["func"] == 'snd_pcm_drain()') \
        or (ditem["func"] == 'snd_pcm_drop()') \
        or (ditem["func"] == 'snd_pcm_status()') \
      :
        tdl = collections.OrderedDict()
        #printse(ditem,"\n")
        if ts_ioctl=='':
          printse("WARNING: no userspace cmd for: ", ditem, "\n")
          continue # skip rest of this for-loop iteration
        tdl["time"] =  "%.6f" % (float(ts_ioctl)-toffs)
        tdl["ktime"] = "%.6f" % (float(kts_ioctl)-toffs)
        tdl["cpu"] = cpu_ioctl
        tdl["proc"] = proc_ioctl
        tdl["pid"] = pid_ioctl
        tdl["durn"] = "0"
        tdl["ftype"] = "1" # type 1: userspace marker
        if ditem["func"] == 'snd_pcm_lib_read1()':
          tdl["func"] = "snd_pcm_readi"
          tdl["strm"] = "1" # capture: 1
        if ditem["func"] == 'snd_pcm_link()':
          tdl["func"] = "snd_pcm_link"
          tdl["strm"] = str(pc_ioctl) if pc_ioctl>-1 else "1" # capture: 1 (it's a capture _ioctl!)
        if ditem["func"] == 'snd_pcm_do_start()':
          tdl["func"] = "snd_pcm_start"
          tdl["strm"] = str(pc_ioctl) if pc_ioctl>-1 else "1" # capture: 1 (it's a capture _ioctl!)
        if ditem["func"] == 'snd_pcm_drop()':
          tdl["func"] = "snd_pcm_drop" # also calls snd_pcm_stop;
          tdl["strm"] = str(pc_ioctl) if pc_ioctl>-1 else "1" # capture: 1 (it's a capture _ioctl here!)
        if ditem["func"] == 'snd_pcm_lib_write1()':
          tdl["func"] = "snd_pcm_writei"
          tdl["strm"] = "0" # playback: 0
        if ditem["func"] == 'snd_pcm_drain()':
          tdl["func"] = "snd_pcm_drain"
          tdl["strm"] = str(pc_ioctl) if pc_ioctl>-1 else "0" # playback: 0 (it's a playback _ioctl!)
        if ditem["func"] == 'snd_pcm_status()':
          tdl["func"] = "snd_pcm_status"
          tdl["strm"] = str(pc_ioctl) if pc_ioctl>-1 else "0" # it goes with both here; but choose a default
        tdl["findent"] = "0"
        tcollect.append(tdl) # ... and reset (prob. superfluous, except for pc_ioctl):
        ts_ioctl = ""
        kts_ioctl = ""
        pc_ioctl = -1
      # polls are related to sys_poll; but multiple can happen inside
      # so give them each an individual "userspace" marker
      if (ditem["func"] == 'snd_pcm_capture_poll()') \
        or (ditem["func"] == 'snd_pcm_playback_poll()') \
      :
        tdl = collections.OrderedDict()
        tdl["time"] =  "%.6f" % (float(ditem["time"])-toffs)
        tdl["ktime"] = "%.6f" % (float(ditem["ktime"])-toffs)
        tdl["cpu"] = ditem["cpu"]
        tdl["proc"] = ditem["proc"]
        tdl["pid"] = ditem["pid"]
        tdl["durn"] = "0"
        tdl["ftype"] = "1" # type 1: userspace marker
        if ditem["func"] == 'snd_pcm_capture_poll()':
          tdl["func"] = "snd_pcm_capture_poll"
          tdl["strm"] = "1" # capture: 1
        if ditem["func"] == 'snd_pcm_playback_poll()':
          tdl["func"] = "snd_pcm_playback_poll"
          tdl["strm"] = "0" # playback: 1
        tdl["findent"] = "0"
        tcollect.append(tdl)
      #if 'strm' in dictCollection[5220]: printse(id,":",dictCollection[5220]['strm'],"\n") # just debug
  #printse(dictCollection[1454], "\n") # just debug
  # append tcollect to dictCollection
  # (dictCollection will have to be resorted again later!)
  dictCollection.extend(tcollect)
  lastmind = -1
  # second pass - find nested IRQ (if any) in dubIRQs;
  # (as we'll want to process only innermost (0) level irqs) ? Not necessarilly -
  # not if they're empty; detect outer only if inner has the same _pointer!
  #~ printse(dubIRQs, "\n")
  for tcpu in [0, 1]:
    for idb, dubitem in enumerate(dubIRQs[tcpu]): # check if this is inner IRQ to the compared one
      if idb > 0: # the first irq cannot be inner, so skip it
        for idbc, dubitemc in enumerate(dubIRQs[tcpu]): # comparison:
          if idb != idbc: # do not compare to "yourself"
            mind = dubitem[0] ; mindc = dubitemc[0] # mirq, _int/_call, and _pointer, and irq nest level
            mirqstart = float(dictCollection[mind]["time"])
            mirqdurn = float(dictCollection[mind]["durn"]) # duration
            mirqcstart = float(dictCollection[mindc]["time"])
            mirqcdurn = float(dictCollection[mindc]["durn"]) # duration
            # looking for:
            # mirqcstart < mirqstart < mirqstart+mirqdurn < mirqcstart+mirqcdurn
            isStartNested = (mirqcstart < mirqstart)
            isDurnNested = (mirqstart+mirqdurn < mirqcstart+mirqcdurn)
            isPointerSame = (dubitem[2] == dubitemc[2])
            if (isStartNested and isDurnNested and isPointerSame):
              dubIRQs[tcpu][idbc][3] += 1 # IRQ nest level: mark the compared as "outer" in the fourth array item
  # third pass - sort by index (time); remove outer nested IRQs in dubIRQs
  # NOTE: do NOT remove/pop (modify) items from array while iterating it;
  # the indexes change and impossible to manage! Here also looping over a copy
  # of the array doesn't work either! so must use filter!
  for tcpu in [0, 1]:
    #printse("orig ", dubIRQs[tcpu], "\n")
    newlist = sorted(dubIRQs[tcpu], key=lambda dubitem: int(dubitem[0])) # dubIRQs[tcpu][0] is mIRQ index (mind)
    dubIRQs[tcpu] = newlist
    #printse("new ", newlist, "\n")
    #printse("filter ", filter(lambda dubitem: not(dubitem[3]>0), dubIRQs[tcpu]), "\n")
    dubIRQs[tcpu] = filter(lambda dubitem: not(dubitem[3]>0), dubIRQs[tcpu])
    printse("cpu %d removed %d outer mirq; " % (tcpu, len(newlist)-len(dubIRQs[tcpu])))
    #for idb, dubitem in enumerate(dubIRQs[tcpu]):
    #  printse(tcpu, " ", dubitem, " // ")
    #  if dubitem[3] > 0: # is an outer nest - remove:
    #    printse(dubIRQs[tcpu][idb])
    #    dubIRQs[tcpu].pop(idb)
    #  printse("\n")
  printse("\n")
  # fourth pass - decide correction or insert if necessary
  # must check lastiind (usually in pair with lastpind)
  # too, to account for IRQ nesting in hda-intel; and
  # avoid unnecesarry correction
  lastiind = -1
  for tcpu in [0, 1]:
    for dubitem in dubIRQs[tcpu]:
      printse(tcpu, ": ", dubitem, "\n")
      # printse(tcpu, ": ", dubitem, " P: ", dictCollection[dubitem[2]], "\n") # dbg
      mind = dubitem[0] ; iind = dubitem[1] ; pind = dubitem[2]
      msd = dictCollection[mind]["strm"]
      psd = dictCollection[pind]["strm"]
      seenmind = (lastmind==mind)
      seeniind = (lastiind==iind)
      #~ printse(dictCollection[mind],"\n")
      printse("\t", msd, " : ", psd, " / ", seenmind, " / ",  seeniind) #, "\n")
      # those where pind == -1 refer to the same where mIRQ["strm"] == -1 (hda-intel);
      # so skip those from processing
      # also skip those mIRQs that are determined -2 (msd == "-2"; careful it's string)
      if ( (pind == -1) or (msd == "-2") ):
        #continue # skip rest of this for-loop iteration? nope,
        printse(" skip ")
        pass # use pass and elif, so we have include lastmind calc
      elif ( not(seenmind) and seeniind): # skip this too - avoid unnecessary correction
        printse(" skipB ")
        pass # use pass and elif, so we have include lastmind calc
      # where msd != psd and not seenmind before, correct (dummy)
      elif ( (msd != psd) and not(seenmind) ):
        dictCollection[mind]["strm"] = psd
        dictCollection[mind]["ppos"] = dictCollection[pind]["ppos"]
        printse(" correct ", psd )
      # where seenmind before, append (dummy) [usually msd == psd here, but irrelevant]
      # append a mIRQ with the interrupt/callback data
      elif (seenmind):
        tdl = collections.OrderedDict()
        tdl["time"] = dictCollection[iind]["time"]
        tdl["ktime"] = dictCollection[iind]["ktime"]
        tdl["cpu"] = dictCollection[iind]["cpu"]
        tdl["proc"] = dictCollection[iind]["proc"]
        tdl["pid"] = dictCollection[iind]["pid"]
        tdl["ppos"] = dictCollection[pind]["ppos"] # didn't seem to work with iind index!
        tdl["durn"] = "0"
        tdl["ftype"] = "3" # type 3: IRQ marker (mIRQ)
        tdl["func"] = "mIRQ"
        tdl["findent"] = "0"
        tdl["strm"] = psd
        dictCollection.append(tdl)
        printse(" append ", psd )
      printse("\n")
      lastmind = mind
      lastiind = iind
  sortDictCollection()
  if (optargs.cutatfunc != ""): # second time, so we can select user-space commands as well
    calcMinAndNotionalTime() # once more


"""
Here we check the keys (columns) of each dict in
the collection.
If an entry happens to contain more columns,
it is taken as the reference one? Nope:
check key by key - insert unknown keys
"""
def getFinalColumns():
  global dictCollection
  finalcolarray = list()
  for ditem in dictCollection:
    tkeys = ditem.keys()
    for ik, tkey in enumerate(tkeys):
      keyfound = False
      for keyfca in finalcolarray:
        if (keyfca == tkey):
          keyfound = True
          break # item found; exit inner for loop
      if not(keyfound):
        insloc = ik
        if (ik > 1) and (ik < len(finalcolarray)-1):
          while ( finalcolarray[ik-1] in finalcolarray[insloc] ):
            insloc += 1
        finalcolarray.insert(insloc, tkey)
  return finalcolarray

"""
output dictCollection according to
columns specified in infinalcols.
First output header commented with #;
then values;
add numrow as first column 'id' if req'd.
( called 'id' as in MySQL autoincrement
column, but is actually ordinal index )
Don't need `global optargs` here since
we just read; keeping it for legibility.
lvCompObj is "last value Compare Object",
to keep "last legal" values, in case they
are to be repeated; initialized with
infinalcols as keys (init value is None).
"""
def getOutputContents(infinalcols):
  global dictCollection
  global optargs
  lvCompObj = collections.OrderedDict.fromkeys(infinalcols)
  #~ calcMinAndNotionalTime()
  if optargs.sorttime:
    sortDictCollection()
  # now after the (potential) sort, we'd do potential accumulation (none here)!
  # now output:
  totoutstr = ""
  outstr = "# "
  if optargs.idcol:
    outstr += "id,"
  #~ outstr += ",".join(infinalcols)
  outstr += ",".join([str(i+1)+"_"+x for i,x in enumerate(infinalcols)])
  totoutstr += outstr+"\n" #printso(outstr+"\n")
  for di, ditem in enumerate(dictCollection):
    outstra = []
    if optargs.idcol:
      outstra.append(str(di))
    for tkey in infinalcols:
      if tkey in ditem:
        outstra.append(ditem[tkey])
        lvCompObj[tkey] = ditem[tkey]
      else:
        if optargs.repeatvals:
          if lvCompObj[tkey]:
            outstra.append(lvCompObj[tkey])
          else:
            outstra.append(str(optargs.defaultrval))
        else:
          outstra.append(str(optargs.defaultrval))
    outstr = ",".join(outstra)
    totoutstr += outstr+"\n" #printso(outstr+"\n")
  return totoutstr

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
NB: TypeError: 'required' is an invalid argument for positionals.
Only way for -d to be handled alone:
> nargs='?', default="def", const="con" - and
> add -- to break: ... -i -r -d -- example.syslog ...
More trouble to have -d handle those cases;
so OK to fail if -d option value not specified
(if -d option not spec'd, then default is used)
---
custom: action=defstrAction, type=defstrtype:
  def defstrtype(string):
    printse("_defstrtype_", "%r" % (string), "*\n")
    if not string:
      string = 'eh' # ends up setting defaultrval!
    return string
  class defstrAction(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
      printse( 'defstrAction %r %r %r \n' % (namespace, values, option_string))
      setattr(namespace, self.dest, values)
... but cannot interrupt custom processing in custom manner!
"""
def processCmdLineOptions():
  #if len(sys.argv) != 2:
  #  usage()
  #  sys.exit()
  optparser = argparse.ArgumentParser(description=usagemsg,
              formatter_class=argparse.RawDescriptionHelpFormatter)
  optparser.add_argument('-i', '--idcol', action='store_true',
                          help='add id (index/numrow) column')
  optparser.add_argument('-r', '--repeatvals', action='store_true',
                          help='for unspecified values, repeat last specified')
  optparser.add_argument('-s', '--sorttime', action='store_true',
                          help='sort output by timestamp')
  optparser.add_argument('-c', '--cutatfunc', action='store',
                          type=str, default="",
                          help="if specified, make the log start at first occurence of this kernel function" )
  optparser.add_argument('-d', '--defaultrval', action='store',
                          type=str, default="",
                          help="for unspecified values, use this value (unless repeatvals is set); default if unspec'd: \"%(default)s\"")
  optparser.add_argument('infiledir',
                          help='input directory with trace.*txt files')
  #optparser.add_argument('--version', action='version', version='%(prog)s 2.0')
  optargs = optparser.parse_args(sys.argv[1:])#(sys.argv)
  #printso(optargs, optargs.idcol, "\n\n\n")
  return optargs



# ##################### MAIN          ##########################################

"""
not really necessarry to use linecache for files here,
as we anyways have to create structures in memory;
but leaving it for demonstration purposes
"""
infilenamePatternX = 'trace-cmdX-*.txt'
infilenamePatternO = 'trace-o-*.txt'
infiledir = ""
patFileOSuffix = re.compile('trace-o-(.*)\.txt')

def main():
  global inputSrcType
  global dictCollection
  global optargs # here we set; needs global
  global firstTS
  global infiledir
  global mIrqStack

  optargs = processCmdLineOptions()
  infiledir = optargs.infiledir #sys.argv[1]

  if not(infiledir) or not(os.path.exists(infiledir)):
    printse("ERROR: Bad input directory!\n")
    printse(usagemsg);
    sys.exit(1)

  # get matching input files
  infilelistX = glob.glob(infiledir + os.sep + infilenamePatternX)
  infilelistO = glob.glob(infiledir + os.sep + infilenamePatternO)
  if not(infilelistX) or not(infilelistO) or not(len(infilelistX) == len(infilelistO)):
    if not(infilelistX):
      printse("ERROR: Cannot find files matching '{0}' in directory {1}!\n".format(infilenamePatternX, infiledir))
    if not(infilelistO):
      printse("ERROR: Cannot find files matching '{0}' in directory {1}!\n".format(infilenamePatternO, infiledir))
    if not(len(infilelistX) == len(infilelistO)):
      printse("ERROR: Number of files matching '{0}' vs those matching '{1}' in directory {2} are not equal!\n".format(infilenamePatternX, infilenamePatternO, infiledir))
    printse(usagemsg);
    sys.exit(1)

  # note - as run-alsa-capttest.sh gives the same filename suffixes;
  # infilelistX and infilelistO should match by alphabetic order
  printse("Found input files:\n", infilelistX, "\n", infilelistO, "\n")

  for ifn in range(0, len(infilelistX)): # range auto-does len-1

    dictCollection = list()

    mIrqStack = []
    mIrqStack.append([]) # mIrqStack[0]
    mIrqStack.append([]) # mIrqStack[1]

    ifileO = infilelistO[ifn]
    infileObjO = openAnything(ifileO)

    # get the filename suffix
    fsuffix = patFileOSuffix.findall(ifileO)[0]
    printse("\n>>> Processing", fsuffix, " ... \n")

    printse("\nProcessing", ifileO, "\n\n")

    # do not calculate delta/firstTS in stage 1
    # do later (after sort) because we have timestamps from two files now

    numline=1
    #firstTS = -1.0

    line = "start"
    printse("Stage 1a\n")
    if inputSrcType == 3:
      infileObjO.close()
      while( line ):
        line = linecache.getline(ifileO, numline)
        parseLineO(line, numline)
        numline += 1
    else:
      while( line ):
        line = infileObjO.readline()
        parseLineO(line, numline)
        numline += 1
      infileObjO.close()
    # do a check for matched mIrq
    for cid in [0, 1]:
      if len(mIrqStack[cid]) > 0: # here should be zero if all are matched
        printse("Problem: unmatched mIRQ in (cpu %d); dropping! \n" % (cid))
    printse("\n Got starting %d entries \n" % (len(dictCollection)))

    ifileX = infilelistX[ifn]
    infileObjX = openAnything(ifileX)
    printse("\nProcessing", ifileX, "\n\n")

    numline=1
    #firstTS = -1.0

    line = "start"
    printse("Stage 1b\n")
    if inputSrcType == 3:
      infileObjX.close()
      while( line ):
        line = linecache.getline(ifileX, numline)
        parseLineX(line, numline)
        numline += 1
    else:
      while( line ):
        line = infileObjX.readline()
        parseLineX(line, numline)
        numline += 1
      infileObjX.close()
    printse("\n Got total %d entries \n" % (len(dictCollection)))

    # for some reason, captures from trace-cmd (old or new -
    # but not from `cat ...trace`!) may contain duplicate entries??!
    # thus - clean up duplicates (preserving the random order we have here)
    seen = set()
    new_l = []
    for dictentry in dictCollection:
        t = tuple(dictentry.items())
        if t not in seen:
            seen.add(t)
            new_l.append(dictentry)
    dictCollection = new_l
    printse(" Got unique total %d entries \n" % (len(dictCollection)))

    printse("Stage 2 - check columns: ")
    finalcols = getFinalColumns()
    # use this to check - see what the columns are:
    printse(finalcols, "\n")

    #~ finalcols = ['time', 'ktime', 'cpu', 'proc', 'pid', 'durn', 'ftype', 'func', 'findent', 'ppos', 'aptr', 'hptr', 'rdly', 'strm']
    #~ printse("       explicit reorder:", finalcols, "\n")
    printse("Stage 3 - calc min time, sort, extrapolate UserSpace... \n")
    extrapolateUserSpaceCmds()

    outfilename = infiledir + os.sep + 'trace-' + fsuffix + '.csv'
    printse("Stage 4 - outputting %s \n" % (outfilename))
    totoutstr = getOutputContents(finalcols)

    outfileObj = open(outfilename,"w")
    outfileObj.write(totoutstr)
    outfileObj.close()

    printse("\n")
    #printso(pprint.pformat(dictCollection))



# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


