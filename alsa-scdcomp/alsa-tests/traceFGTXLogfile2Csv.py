#!/usr/bin/env python
################################################################################
# traceFGTXLogfile2Csv.py                                                      #
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
# actual data is obtained in parseLineX
# they both save to the same dictCollection; (which is sorted
# with relative timestamps only after both parses)
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
  # first, find the minimum time (note, here the dictCollection
  # may be unsorted) - and subtract from time, so capture starts from 0
  min_time = min(float(item['time']) for item in dictCollection)
  for item in dictCollection:
    ntime = float(item['time']) - min_time
    item['time'] = "%.6f" % (ntime)
  if optargs.sorttime:
    # the output of `cat /sys/kernel/debug/tracing/trace_pipe`
    # is not guaranteed to preserve order of lines; but
    # at least it seems to provide proper timestamps
    # if the command line option is given, then
    # sort the array of dict dictCollection according to rel. timestamp!
    newlist = sorted(dictCollection, key=lambda k: float(k['time']))
    dictCollection = newlist
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

    #~ finalcols = ['time', 'ktime', 'cpu', 'proc', 'pid', 'durn', 'ftype', 'func', 'findent', 'ppos', 'aptr', 'hptr']
    #~ printse("       explicit reorder:", finalcols, "\n")

    outfilename = infiledir + os.sep + 'trace-' + fsuffix + '.csv'
    printse("Stage 3 - outputting %s \n" % (outfilename))
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


