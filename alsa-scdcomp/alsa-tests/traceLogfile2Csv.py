#!/usr/bin/env python
################################################################################
# traceLogfile2Csv.py                                                          #
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
  except: __version__ = sys.exc_info()[1]

optargs = None
usagemsg = "traceLogfile2Csv.py ( %(prog)s ) v.{0}".format(__version__) + """
Converts log file (with numeric data) to CSV (python2.7/3.2)

Usage:
  python traceLogfile2Csv.py -s trace_syslog 2>/dev/null > example.csv
  cat trace_syslog | python traceLogfile2Csv.py -s - 2>/dev/null > example.csv

* Stderr is used for messages (redirect to /dev/null to suppress)
* Stdout is used for converted file output (redirect to file to save)

NOTE: without sort, those values that are internally accumulated, will
be calculated wrongly!
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

"""
Here we find matches composing of digits and
the dot . as decimal point - those are
the numeric values which will be .csv column data;
column names are derived from previous words in the
split on same matches;
if separating string between numeric values is
only one character long (i.e. '-' or ';'), then
derive column name from previous one.
(column name may end up being one-character too,
as we explicitly use only last word, and filter ':';
but we allow '[' in column name)
Use enumerate() to do `for loop` with index;
must check i > oi because values could otherwise
repeat (e.g. '0')
"""
patNonSpace = re.compile(r'(\S+)')
patDigits = re.compile(r'(\d+)')
patDotDigits = re.compile(r'([\d\.]+)')
patTStamp = re.compile(r'([ \d\.\[\]:]+)')
patPav = re.compile(r'pav:(\d+)')
patCav = re.compile(r'cav:(\d+)')
patPhwav = re.compile(r'phwav:(\d+)')
patChwav = re.compile(r'chwav:(\d+)')
patAptb = re.compile(r'apt:\d+;(\d+)')
patHptb = re.compile(r'hpt:\d+;(\d+)')
patPbtot = re.compile(r'pbtot:(\d+)')
patPlyb = re.compile(r'plyb:(\d+)')
patFra = re.compile(r'fra:(\d+)')
patFrg = re.compile(r'frg:(\d+)')
# these could be -1 as well; handle
patCdfi = re.compile(r'cdfi:([-\d]+)')
patPpi = re.compile(r'ppi:([-\d]+)')
firstTS = -1.0
frgbtp = 0 # frg bytes total playback
frgbtc = 0 # frg bytes total capture
def parseLine(inline, innumline):
  global dictCollection
  global firstTS #, frgbtp, frgbtc
  if not(inline):
    return
  if "[     0.000000]" in inline:
    return
  tdl = collections.OrderedDict() # dict()  collections.OrderedDict()
  # NB: maxsplit=2 means "aa", " ", "bb", " ", "rest..."!
  firstthree = patNonSpace.split(inline, maxsplit=3)
  ktime = patDotDigits.findall(firstthree[5])[0]
  if firstTS == -1.0:
    firstTS = float(ktime)
  tdl["time"] = "%.6f" % (float(ktime) - firstTS)
  tdl["ktime"] = ktime # make this entry sit after "time"
  restA = firstthree[6]
  restAA = []
  restB = ""
  if ("snd_card_audard_pcm_hrtimer_tasklet:" in restA) or ("dummy_hrtimer_pcm_elapsed:" in restA):
    restAA = patNonSpace.split(restA, maxsplit=3)
    restD = restAA[6]
    if restAA[5] == 'tmr_fnc_capt:A':
      tdl["fuid"] = "1"
      tdl["func"] = "hrtlC"
      tdl["patime"] = ""
      #~ tdl["cav"] = patCav.findall(restD)[0]
      #~ tdl["chwav"] = patChwav.findall(restD)[0]
      # should be cavb/chwavb - but leave it, so we don't change rest of code
      tdl["cav"] = str(4*int(patCav.findall(restD)[0]))
      tdl["chwav"] = str(4*int(patChwav.findall(restD)[0]))
      tdl["aptb"] = patAptb.findall(restD)[0]
      tdl["hptb"] = patHptb.findall(restD)[0]
      tdl["cbtot"] = patPbtot.findall(restD)[0]
    elif restAA[5] == 'fwr:D':
      tdl["fuid"] = "2"
      tdl["func"] = "hrtlP"
      tdl["patime"] = ""
      #~ tdl["pav"] = patPav.findall(restD)[0]
      #~ tdl["phwav"] = patPhwav.findall(restD)[0]
      tdl["pav"] = str(4*int(patPav.findall(restD)[0]))
      tdl["phwav"] = str(4*int(patPhwav.findall(restD)[0]))
      tdl["aptb"] = patAptb.findall(restD)[0]
      tdl["hptb"] = patHptb.findall(restD)[0]
      tdl["plyb"] = patPlyb.findall(restD)[0]
    else: return
  elif "CallbackThreadFunc:" in restA:
    restAA = patNonSpace.split(restA, maxsplit=4)
    if restAA[5] == 'c:1':
      tdl["fuid"] = "3"
      tdl["func"] = "cbthC"
    elif restAA[7] == 'p:1':
      tdl["fuid"] = "4"
      tdl["func"] = "cbthP"
    else: return
    restB = restAA[8]
    restC = patTStamp.split(restB, maxsplit=1)
    tdl["patime"] = patDotDigits.findall(restC[1])[0]
    restD = restC[2]
    tdl["frab"] = str(int(patFra.findall(restD)[0])*4)
    frg = int(patFrg.findall(restD)[0])*4
    if restAA[5] == 'c:1':
      #frgbtc += frg # don't accumulate here - do that after the sort!
      tdl["frgbtc"] = frg # str(frgbtc)
    elif restAA[7] == 'p:1':
      #frgbtp += frg # don't accumulate here - do that after the sort!
      tdl["frgbtp"] = frg #str(frgbtp)
  elif "PaAlsaStream_WaitForFrames:" in restA: # these have to be merged somehow (did from source)
    restAA = patNonSpace.split(restA, maxsplit=2)
    if ('crdy:1' in restAA[4]) or ('plc:1' in restAA[4]):
      tdl["fuid"] = "5"
      tdl["func"] = "pawfC"
    elif ('prdy:1' in restAA[4]) or ('plp:1' in restAA[4]):
      tdl["fuid"] = "6"
      tdl["func"] = "pawfP"
    elif ('Drop input' in restAA[4]):
      tdl["fuid"] = "7"
      tdl["func"] = "pawDropIn"
    else: return
    restB = restAA[4]
    if tdl["fuid"] == "7":
      tdl["patime"] = ""
      tdl["frab"] = str(int(patFra.findall(restB)[0])*4)
    else:
      restC = patTStamp.split(restB, maxsplit=1)
      tdl["patime"] = patDotDigits.findall(restC[1])[0]
      restD = restC[2]
      tdl["frab"] = str(int(patFra.findall(restD)[0])*4)
  elif "PACallback" in restA:
    restAA = patNonSpace.split(restA, maxsplit=4)
    if restAA[7] == 'c:1':
      tdl["fuid"] = "8"
      tdl["func"] = "PAcbC"
    elif restAA[5] == 'p:1':
      tdl["fuid"] = "9"
      tdl["func"] = "PAcbP"
    restB = restAA[8]
    # again, possible delta/diff - after the sort
    tcdfi = int(patCdfi.findall(restB)[0])
    if (tcdfi > -1):
      tdl["cdfib"] = str(4*tcdfi)
    tppi = int(patPpi.findall(restB)[0])
    # note: data->playbackIndex is in samples, not frames!
    if (tppi > -1):
      tdl["ppib"] = str(2*tppi)
  else: return
  # make these last
  tdl["proc"] = firstthree[1]
  tdl["cpu"] = patDigits.findall(firstthree[3])[0]
  #~ printse("\n", tdl, "\n", len(dictCollection), restD, "\n")

  """ # forget this - not doing autocolumns; since explicitly extracting data
  pat = re.compile(r'(-*[\d\.]+)') # also neg numbers; - only in front
  lastword = re.compile(r'([\w\[]+)[:;,-]?\s*$')
  asplits = pat.split(inline)
  anums = pat.findall(inline)
  colnameprev = "start"
  colnamecnt = 1
  oi = 0
  for anum in anums:
    for i, asplit in enumerate(asplits):
      if ( (asplit == anum) and (i > oi) ):
        colname = ""
        if (len(asplits[i-1]) > 1): # check length in raw content
          asplprevlw = lastword.findall(asplits[i-1])[0] # last word in raw content
          colname = asplprevlw
          colnameprev = colname
          colnamecnt = 1
        else:
          colnamecnt += 1
          colname = colnameprev + str(colnamecnt)
        oi = i
        tdl[colname] = anum
        break # item found; exit inner for loop
  """
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
cdfibprev = -1
ppibprev = -1
def outputContents(infinalcols):
  global dictCollection
  global optargs
  global frgbtp, frgbtc
  global ppibprev, cdfibprev
  lvCompObj = collections.OrderedDict.fromkeys(infinalcols)
  if optargs.sorttime:
    # the output of `cat /sys/kernel/debug/tracing/trace_pipe`
    # is not guaranteed to preserve order of lines; but
    # at least it seems to provide proper timestamps
    # if the command line option is given, then
    # sort the array of dict dictCollection according to rel. timestamp!
    newlist = sorted(dictCollection, key=lambda k: float(k['time']))
    dictCollection = newlist
  # now after the (potential) sort, perform the accumulation of frg where needed!
  for di, ditem in enumerate(dictCollection):
    if ditem["func"] == "cbthC":
      frgbtc += ditem["frgbtc"]     # accumulate (old content) frg
      ditem["frgbtc"] = str(frgbtc) # set new content to accumulated value
    elif ditem["func"] == "cbthP":
      frgbtp += ditem["frgbtp"]     # accumulate (old content) frg
      ditem["frgbtp"] = str(frgbtp) # set new content to accumulated value
    # to calculate delta/diff
    elif ditem["func"] == "PAcbC" or ditem["func"] == "PAcbP":
      if "cdfib" in ditem:
        if ditem["cdfib"]:
          if cdfibprev == -1:
            cdfibprev = int(ditem["cdfib"])
            ditem["cdfib"] = "0"
          else:
            cdfib = int(ditem["cdfib"])
            ditem["cdfib"] = str(cdfib - cdfibprev)
            cdfibprev = cdfib
      if "ppib" in ditem:
        if ditem["ppib"]:
          if ppibprev == -1:
            ppibprev = int(ditem["ppib"])
            ditem["ppib"] = "0"
          else:
            ppib = int(ditem["ppib"])
            ditem["ppib"] = str(ppib - ppibprev)
            ppibprev = ppib
  outstr = "# "
  if optargs.idcol:
    outstr += "id,"
  #~ outstr += ",".join(infinalcols)
  outstr += ",".join([str(i+1)+"_"+x for i,x in enumerate(infinalcols)])
  printso(outstr+"\n")
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
    printso(outstr+"\n")

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
  optparser.add_argument('infilename',
                          help='input file name (`-` for stdin)')
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
def main():
  global inputSrcType
  global dictCollection
  global optargs # here we set; needs global

  optargs = processCmdLineOptions()

  infilearg = optargs.infilename #sys.argv[1]
  infileObj = openAnything(infilearg)
  dictCollection = list()

  numline=1
  line = "start"
  printse("Stage 1\n")
  if inputSrcType == 3:
    infileObj.close()
    while( line ):
      line = linecache.getline(infilearg, numline)
      parseLine(line, numline)
      numline += 1
  else:
    while( line ):
      line = infileObj.readline()
      parseLine(line, numline)
      numline += 1
  printse("\n")
  printse("Stage 2 - check columns: ")
  finalcols = getFinalColumns()
  # use this to check - see what the columns are:
  printse(finalcols, "\n")
  # ... however, the order of columns will depend on which
  # instruction is processed first; so then explicitly
  # re-set the order here (by copy/pasting the check above
  # here) - so it is the same for multiple log files:
  #~ finalcols =  ['time', 'ktime', 'fuid', 'func', 'patime', 'pav', 'phwav', 'frab', 'frgbtp', 'plyb', 'cav', 'chwav', 'frgbtc', 'cbtot', 'aptb', 'hptb', 'proc', 'cpu']
  finalcols =  ['time', 'ktime', 'fuid', 'func', 'patime', 'pav', 'phwav', 'frab', 'frgbtp', 'plyb', 'ppib', 'cav', 'chwav', 'frgbtc', 'cbtot', 'cdfib', 'aptb', 'hptb', 'proc', 'cpu']
  printse("       explicit reorder:", finalcols, "\n")
  printse("Stage 3 - outputting\n")
  outputContents(finalcols)
  printse("\n")
  #printso(pprint.pformat(dictCollection))




# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


