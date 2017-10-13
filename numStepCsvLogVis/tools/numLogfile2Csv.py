#!/usr/bin/env python

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
except:
  versionf = scriptdir + os.sep + ".." + os.sep + "VERSION"
  try:    __version__ = next(open(versionf))
  except: __version__ = sys.exc_info()[1]

optargs = None
usagemsg = "numlogfile2csv.py ( %(prog)s ) v.{0}".format(__version__) + """
Converts log file (with numeric data) to CSV (python2.7/3.2)

Usage:
  python numlogfile2csv.py example.syslog 2>/dev/null > example.csv
  cat example.syslog | python numlogfile2csv.py - 2>/dev/null > example.csv

* Stderr is used for messages (redirect to /dev/null to suppress)
* Stdout is used for converted file output (redirect to file to save)
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
def parseLine(inline, innumline):
  global dictCollection
  if not(inline):
    return
  tdl = collections.OrderedDict() # dict()  collections.OrderedDict()
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
def outputContents(infinalcols):
  global dictCollection
  global optargs
  lvCompObj = collections.OrderedDict.fromkeys(infinalcols)
  outstr = "# "
  if optargs.idcol:
    outstr += "id,"
  outstr += ",".join(infinalcols)
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
  printse("Stage 2 - check columns")
  finalcols = getFinalColumns()
  printse(finalcols, "\n")
  printse("Stage 3 - outputting\n")
  outputContents(finalcols)
  printse("\n")
  #printso(pprint.pformat(dictCollection))




# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


