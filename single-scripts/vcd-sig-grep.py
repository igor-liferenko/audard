#!/usr/bin/env python

# sdaau 2011; based mostly on
# http://stackoverflow.com/questions/4140884/pyparsing-forward-and-recursion
# and http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/single-scripts/ghdl2ngspice-example.sh (([http://sourceforge.net/projects/ngspice/forums/forum/133842/topic/4839104 VHDL sim'd .vcd data - as analog sim source]))

# call with: see usage()


from pprint import pprint, pformat
from pyparsing import Word, alphas, Suppress, Literal, Group, Forward, ZeroOrMore, SkipTo, StringEnd, Each, Optional, OneOrMore, LineEnd, alphanums, printables, Combine, nums
import sys, os
import getopt


## globals

# this script name, as passed by the command line call
scriptcallpath = sys.argv[0]
# the input vcd file path string
inputfile=None
# input file handle
inputfh=None
# the input signal list to grep/filter/select (cmdline string)
inputsigs=None
# the input signal list to grep/filter/select (list)
insigs_l=None
# number of signals there are in the input signal list
insigs_lnum=None
# separator for input signal list
insigs_sep=','
# header as parsed list
VCDheader_pl=None
# how many lines of text in VCD file
VCDfile_linecount=0
# how many lines of text in VCDheader
VCDheader_linecount=0
# how many lines of text in VCDdata
VCDdata_linecount=0
# collection of all reg/wires (all vars) in VCD file (listed in header)
VCD_allvars=[]
# collection of all data in VCD file (parsed) as Python list items
VCD_alldata=[]


SCOPE, VAR, UPSCOPE, END, ENDDEFINITIONS = map(Suppress,
                                "$scope $var $upscope $end $enddefinitions".split())

# these in Literal so they show as "indexes"
DATE, VERSION, TIMESCALE, MODULE, WIRE, REG = map(Literal, "$date $version $timescale module wire reg".split())

# note [1]
DATE.setParseAction(lambda t : "date")
VERSION.setParseAction(lambda t : "version")
TIMESCALE.setParseAction(lambda t : "timescale")

scope_header = Group(SCOPE + MODULE + Word(printables) + END)
wordortwonotend = ( OneOrMore( ~END + Word(printables)) )
wordortwonotend.setParseAction(lambda t : ' '.join(t)) # to put possible multi words in the same string (field) [for signal names with spaces]
wire_map = Group(VAR + WIRE + Word(alphanums) + Word(printables) + wordortwonotend + END)
reg_map = Group(VAR + REG + Word(alphanums) + Word(printables) + wordortwonotend + END)
var_map = (wire_map | reg_map)
scope_footer = (UPSCOPE + END)
enddefs_footer = (ENDDEFINITIONS + END)
#~ wire_map.setDebug()

# note [3]
var_map.setParseAction(lambda t : VCD_allvars.append(t.asList()[0]))

# enveloping Suppress/SkipTo removes the '$end' from match results
date_header = Group( DATE + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )
version_header = Group( VERSION + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )
timescale_header = Group( TIMESCALE + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )

# note [2] - NOTE recursion here!
scope = Forward()
scope << Group(scope_header + ZeroOrMore( (var_map | scope) ) + scope_footer) # with an extra group

vcdpreamble = ( Each([Optional(date_header), Optional(version_header), Optional(timescale_header)]) )

vcdheader = Forward()
vcdheader << ( vcdpreamble +  ZeroOrMore( (var_map | scope) ) + enddefs_footer)

# timescale label "10ns"
timesclabel=Word(nums)+Word(alphas)
# dict for timescale label exponents
tbase_d = {'fs': 1e-15, 'ps': 1e-12, 'ns': 1e-9}

## functions

def usage():
  # global scriptcallpath # no need for global if we just read
  logso("""vcd-sig-grep.py:
* Script for grepping/filtering/selecting signals, from
* an input VCD dump file, into a new output vcd file.

* Usage:

  python2.7/3.2 """ + scriptcallpath + """ -i/--input-file=input.vcd -s/--sigs="sigone[,sigtwo]" 2>/dev/null > sigs_grep_filtered.vcd

* If --input-file is not given, stdin is assumed:

  cat input.vcd | python2.7/3.2 """ + scriptcallpath + """ -s/--sigs="sigone,sigtwo" 2>/dev/null > sigs_grep_filtered.vcd

  ghdl -r test_workbench --stop-time=500ms --vcd=/dev/stdout | python2.7/3.2 """ + scriptcallpath + """ -s/--sigs="sigone,sigtwo" 2>/dev/null > sigs_grep_filtered.vcd

* If sigs is not present/empty (--sigs=""), then only unfiltered VCD preamble is output.
* Input signal list in --sigs is comma separated.
* Add a space to your signals, to be able to select *only* --sigs="sig ,sig3 ," from sig, sig1, sig3, sig31...;
* else --sigs="sig" will select them all

* Stderr is used for messages (redirect to /dev/null to suppress)'
* Stdout is used for converted file output (redirect to file to save)'

""");

def logse(instr, eol="\n"): # to stderr
  sys.stderr.write(instr + eol)
  sys.stderr.flush()

def logso(instr, eol="\n"): # to stderr
  sys.stdout.write(instr + eol)
  sys.stdout.flush()

def main():
  global scriptcallpath, inputfile, inputfh
  global inputsigs, insigs_l, insigs_lnum
  global VCDfile_linecount
  try:
    opts, args = getopt.getopt(sys.argv[1:], "his:", ["help", "input-file=", "sigs=" ])
  except getopt.GetoptError as err: # supported by 2.6 syntax by backport
    # print help information and exit:
    logse(str(err)) # will print something like "option -a not recognized"
    usage()
    sys.exit(2)

  for o, a in opts:
    if o in ("-h", "--help"):
      usage()
      sys.exit()
    elif o in ("-i", "--input-file"):
      inputfile = a
    elif o in ("-s", "--sigs"):
      inputsigs = a
    else:
      assert False, "unhandled option"

  #~ if ((inputfile == None) or (inputsigs == None)):
    #~ usage()
    #~ sys.exit()

  # assume stdin input if no input file specified
  if (inputfile == None):
    inputfile = "sys.stdin"
    inputfh = sys.stdin # open(inputfile)
  else:
    if os.path.isfile(inputfile):
      try:
        # this will open file - if all goes well, we'll have
        # the number of lines in file returned (and file closed)
        VCDfile_linecount = bufcount(inputfile)
      except IOError as e:
        logse('Problems with ' + inputfile + '.')
        logse("({})".format(e))
        logse('Exiting.')
        sys.exit()
    else:
      logse('Not found ' + inputfile + '.')
      logse('Exiting.')
      sys.exit()
    # since at this point, file should exist, and we should have read
    # number of lines in it, just open it directly here
    inputfh = open(inputfile)


  # try parse the signal list
  # (if zero entries; then just output the preamble and exit)
  if (inputsigs == None):
    inputsigs = ""
    insigs_l = []
  elif (inputsigs == ""):
    insigs_l = []
  else: # inputsigs exists and not empty string:
    insigs_l = inputsigs.split(insigs_sep)

  insigs_lnum = len(insigs_l)
  # cleanup
  if (insigs_lnum > 0):
    # note [7]
    for index in range((insigs_lnum-1),-1,-1):
      item=insigs_l[index]
      #~ logse(str(index) + " " + item + " " + str(item==''))
      if (item == ''):
        insigs_l.pop(index)
  # reset count
  insigs_lnum = len(insigs_l)

  sigrep = "Looking for " + str(insigs_lnum) + " signals: "
  if (len(insigs_l)):
    sigrep += str(insigs_l)
  else:
    sigrep += "preamble output only"

  logse("Processing " + inputfile + " ...\n" + sigrep +  " ...\n")

  getVCDHeader()

  if (insigs_lnum < 1):
    sys.exit()

  getVCDdata()
#
# END main()
#



def getVCDHeader():
  global VCDheader_pl, VCDheader_linecount
  logse("getVCDHeader: PROCESSING ...")
  VCDheader_l = []
  inHeader = True
  VCDheader_linecount = 0
  for line in inputfh:
    VCDheader_linecount += 1
    line = line.rstrip() # chomp (all) the whitespace at end
    if (not(not(line))): # if not empty string
      if inHeader:
        addThisLine = True
        if (line.startswith("$var")):
          foundvar = False;
          if (insigs_lnum > 0):
            for isigname in insigs_l:
              if (line.find(isigname) > -1):
                foundvar = True;
                break
            # var line *and* not found in insigs_l? don't add it:
            if not(foundvar): addThisLine = False
        if addThisLine:
          VCDheader_l.append(line) # append first (include the enddefs line)
        if line.startswith("$enddefinitions"):
          inHeader = False
          break
  if inHeader:    # we never reached end of header, alert problem
    # of course, this will never hit if there's a problem with stdin
    # (will hit only with a "prerecorded" file)
    logse("Problem with file tmpe_l+- cannot find end of header:")
    logse("\n".join(VCDheader_l))
    logse('Exiting.')
    sys.exit()

  VCDheader_s = "\n".join(VCDheader_l)
  #~ print(VCDheader_s)
  res = vcdheader.parseString(VCDheader_s)
  #~ pprint(res.dump()) # no .asList(), looks like string only
  VCDheader_pl = res.asList()
  logse(pformat(VCDheader_pl) + "\n") # pprint(VCDheader_pl)
  #~ logse(pformat(VCD_allvars) + "\n")
  # however, we need to output to stdout all the header lines verbatim:
  logso(VCDheader_s)
#
# END getVCDHeader()
#


def getVCDdata():
  global VCDdata_linecount, VCD_alldata
  # note [4]
  logse("getVCDdata: PROCESSING ...")

  VCDdata_linecount = 0
  VCD_alldata = []                # the global array (reset)
  # we're not parsing data into global arrays here;
  #  hence, VCD_alldata will be unused
  # just output lines depending on match...
  # however, we want ONLY those timestamps, where we have a match!
  # so tmpframe is temporary store of lines; will be discarded if no match
  tmpframe=[]
  for line in inputfh:
    VCDdata_linecount += 1
    shouldDumpFrameLines = False
    if (line.startswith("#")): # tis a time marker
      # check previous tmpframe, if anything in it matches
      # if anything in it has matched, then more lines have been added
      # than just the timemarker;
      # thus len(tmpframe) > 1 means we have something, so dump
      if (len(tmpframe) > 1):
        # log as needed
        perc = " - "
        if (VCDfile_linecount > 0):
          perc = "%2.2f%% " % (100*(VCDdata_linecount + VCDheader_linecount) / VCDfile_linecount)
        logse(perc + str(VCDdata_linecount), eol="\r") # indicate progress on stderr
        # lines already contain \n; not rstripped:
        logso("".join(tmpframe), eol="")	# logso("\n".join(tmpframe))
      # we're done dumping the (last) frame, reset (new) tmpframe
      tmpframe = []
      # ... and add/push the current line, ass it's a time marker
      tmpframe.append(line)
      #
    else: # not a time marker; do checks here to add to tmpline
      shouldSaveLine = False;
      for item in VCD_allvars:
        strID = item[2];
        if (line.find(strID) > -1):
          shouldSaveLine = True;
          break;
      if (shouldSaveLine):
        tmpframe.append(line)
  #
  # done dumping filtered data;
  #
  def tformat(ins):
    #~ return pformat(ins) # multiline
    return str(ins) # single line

  logse("Processed " + str(VCDdata_linecount) + " ( +" + str(VCDheader_linecount) + ") lines; ")

  logse("\n---------- DONE READ & PARSE OF INPUT VCD ------ \n\n")
#
# END getVCDdata()
#





#~ http://stackoverflow.com/questions/845058/how-to-get-line-count-cheaply-in-python
def bufcount(filename):
  f = open(filename)
  lines = 0
  buf_size = 1024 * 1024
  read_f = f.read # loop optimization

  buf = read_f(buf_size)
  while buf:
    lines += buf.count('\n')
    buf = read_f(buf_size)

  f.close()
  return lines
#
# END bufcount()
#



# to avoid forward declare of functions problems;
# have a main function, and this at end.
if __name__ == "__main__":
  #~ main() # graceful shutdown, instead:
  try:
      retval = main()
  except KeyboardInterrupt:
      logse("\nCtrl-C pressed; exiting ... ")
      sys.exit(1)





## ------------------------------------

# notes:

# mention of VCD signal selection
# http://www.velocityreviews.com/forums/t650214-using-ghdl-and-have-problems-with-vcd-dump-option.html
# "Presently, if the VCD option is enabled, all signals of the design are recorded. This impacts the performance and requires large disk space.  I generate my own form the VHDL code (example: probe_i2c_slv.vhd). This way it is easy to select what signals to dump and on what time. More details are at : http://web.archive.org/web/20080620054114/http://bknpk.no-ip.biz/I2C/leon_2.html"



# python; "usual python" parser
# http://paddy3118.blogspot.com/2008/03/writing-vcd-to-toggle-count-generator.html

# python, pyparsing (not complete, but has good explanation)
# http://stackoverflow.com/questions/4140884/pyparsing-forward-and-recursion
# http://pyparsing.wikispaces.com/ - http://packages.python.org/pyparsing/ - only docs (or a book)
# sudo apt-get install python-pyparsing # 1.5.2-2;
# https://launchpad.net/ubuntu/+source/pyparsing/1.5.2-2: "use globbing to remove pyparsing_py3.py - Closes: #571505"
# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=571505
# but also in new: "IMPORTANT API CHANGE for PYTHON 3 USERS! - This release also clears up the import discrepancy between the two versions of Python, that was introduced in version 1.5.2 - now regardless of Python version, users can just write import pyparsing in their code, there is no longer a separate pyparsing_py3 module."
# sudo apt-get remove --purge python-pyparsing
# # sudo apt-get install python-setuptools # for easy_install; only 2.7
# # pypi-install in python-stdeb; 16 MB
# curl -O http://python-distribute.org/distribute_setup.py ;
# sudo python2.7 distribute_setup.py # Installing easy_install-2.7 script to /usr/local/bin
# sudo python3.2 distribute_setup.py # Installing easy_install-3.2 script to /usr/local/bin
#~ sudo easy_install-2.7 pyparsing
#~ sudo easy_install-3.2 pyparsing

# py 2 / 3 : "common import idiom is to try the new name first, then fall back to the old name imported as the new name."


#~ Vcdparser/Vtracer "Note: Vcdparser subproject is not functional any more !!!" (also bit strange to work in)
#~ http://vtracer.sourceforge.net/vtracer_spec_5.html#SEC26

# [http://groups.google.com/group/comp.lang.verilog/browse_thread/thread/cde8166b761b1c1d?fwc=2 VCD parser - comp.lang.verilog | Google Groups] - just a question...

# http://docs.python.org/dev/howto/pyporting.html#python-2-3-compatible-source ... http://docs.pythonsprints.com/python3_porting/py-porting.html


# note [1]
# names could be "pwmcount[7:0]" or "pwmcount [7]"; use Combine (no, setParseAction) to merge them
# a "cheap" way to return/write "word" instead of "$word" in the results (without parsing - though could be replaced with a single function that removes initial '$' sign)

# note [2]
# "Forward declaration of an expression to be defined later - used for recursive grammars, such as algebraic infix notation. When the expression is known, it is assigned to the Forward variable using the '<<' operator.... It is recommended that you explicitly group the values inserted into the Forward:"
# NOTE recursion here!

# note [3]
# this will printout and not interfere otherwise (doesn't return a string)
#~ var_map.setParseAction(lambda t : sys.stderr.write(str(t)))
# t is of type pyparsing.ParseResults - need to get actual result asList[0]
# calling like this doesn't interfere with rest of code

  # note [4]
  # after header is parsed (after '$enddefinitions')
  # there may be '$dumpvars'/'$end' - if so, there will be
  # also '$dumpoff'/'$end' ? not always:
  # some: '$dumpvars'/'$end'; some: '$dumpvars'/'$end' + '$dumpoff'/'$end'; some '$dumpvars' only, without terminating end (gtkwave single channel export); ghdl exports no '$dumpvars'
  # if terminating end, then signals/values are listed inside!
  # the first line with '#NUM' will be the starting time..
  # NOTE: 'for line in inputfh' (file open) continues from where it left off last; if header was properly parsed (it broke correctly), it should be next line after $enddefinitions
  # (for file open, we need file close/reopen to "reset the stream"; or seek?
  # .. but for .tell(): "IOError: telling position disabled by next() call"!!)
  #~ print("getVCDdata: Continuing from " + inputfh.tell() + " bytes ..." )
  # go line-by-line (could be big file); pyparsing would need a string in memory!
  # however, we still need an array in memory (tmpL_l), since we're going to resample... (hopefully int(timestamp) will save some memory )


  # note [6]
  # here we have VCD_alldata; however, VCD saves only differences;
  # ngspice d_source format does not need equidistant time samples;
  # however it needs all values for all channels specified in columns!
  # we'll have a master "current values" object (dict); we'll update it respectively; and we'll render it's state
  # however, we have to take care of the timebase too...
  # values: 12-State value (0s, 1s, Us, 0r, 1r, Ur, 0z, 1z, Uz, 0u, 1u, Uu).

    # note [7]
    # note: must iterate from largest index down to 0 -
    #  cause we may pop items: if we go upwards - then deleting 2 will make the next 3 two again; and pop(3) will not work
    #~ for index,item in enumerate(insigs_l):
    # range(2,0,-1): 2,1 (does not include 0, so second argument: -1)


# failed header parses:
#~ > #~ scope_header = Group(SCOPE + MODULE + Word(alphas) + END)
#~ > scope_header = Group(SCOPE + MODULE + Word(printables) + END)
#~ > #~ wire_map = Group(VAR + WIRE + Word(alphanums) + Word(printables) + Word(printables) + END)
#~ > #~ wire_map = Group(VAR + WIRE + Word(alphanums) + Word(printables) + Combine(Word(printables) + Optional(Word(printables))) + END)
#~ > #~ wordortwo = ( Word(printables) + Optional(Word(printables)) + END )
#~ > #~ wordortwo = ( ( (Word(printables)) | (Word(printables) + Optional(Word(printables))) ) + END ) # NOT OK!!!!! must insert END separately!
#~ > #~ wordortwo = ( (Word(printables) + END) | ( Word(printables) + Optional(Word(printables)) + END ) ) # ok
#~ > # pyparsing.wikispaces.com/message/view/home/45375244 "If you write "OneOrMore(Word(printables))" in your grammar, there is a good chance that one expression will read the entire rest of your input string."
#~ > wordortwonotend = ( OneOrMore( ~END + Word(printables)) )
#~ > wordortwonotend.setParseAction(lambda t : ' '.join(t)) # to put possible multi words in the same string (field)
#~ > wire_map = Group(VAR + WIRE + Word(alphanums) + Word(printables) + wordortwonotend + END)
#~ > #~ reg_map = Group(VAR + REG + Word(alphanums) + Word(printables) + OneOrMore(Word(printables)) + END)
#~ > reg_map = Group(VAR + REG + Word(alphanums) + Word(printables) + wordortwonotend + END)
#~ > var_map = (wire_map | reg_map)
#~ > scope_footer = (UPSCOPE + END)
#~ > enddefs_footer = (ENDDEFINITIONS + END)
#~ > #~ wire_map.setDebug()
#~ > #~ scope_footer.setDebug()
#~ > #~ WIRE.setDebug()
#~ > #~ wordortwonotend.setDebug()
#~ >
#~ > #~ date_header = Group( DATE + SkipTo( END | StringEnd()) )
#~ > #~ date_header = Group( DATE + SkipTo( END ) )
#~ > # enveloping Suppress/SkipTo removes the '$end' from match results
#~ > date_header = Group( DATE + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )
#~ > version_header = Group( VERSION + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )
#~ > timescale_header = Group( TIMESCALE + SkipTo( END ) + Suppress(SkipTo( LineEnd() )) )
#~ >
#~ > # "Forward declaration of an expression to be defined later - used for recursive grammars, such as algebraic infix notation. When the expression is known, it is assigned to the Forward variable using the '<<' operator.... It is recommended that you explicitly group the values inserted into the Forward:"
#~ > # NOTE recursion here!
#~ > scope = Forward()
#~ > #~ scope << (scope_header + ZeroOrMore( (var_map | scope) ) + scope_footer)
#~ > #~ scope << (scope_header + ZeroOrMore( Each([ Optional(wire_map), Optional(scope) ]) ) + scope_footer)
#~ > #~ scope << (scope_header + OneOrMore( Each([ Optional(wire_map), Optional(scope) ]) ) + scope_footer)
#~ > #~ scope << (scope_header + wire_map + scope_footer) # debug
#~ > #~ scope << (scope_header + ZeroOrMore(wire_map) + scope_footer) # debug
#~ > #~ scope << (scope_header + OneOrMore( Optional(wire_map) | Optional(scope) ) + scope_footer)
#~ > #~ scope << (scope_header + ZeroOrMore( (var_map | scope) ) + scope_footer) # ok now
#~ > scope << Group(scope_header + ZeroOrMore( (var_map | scope) ) + scope_footer) # with an extra group
#~ > #~ scope.setDebug()
#~ >
#~ >
#~ > #~ vcdpreamble = ( ZeroOrMore(date_header) + ZeroOrMore(version_header) + ZeroOrMore(timescale_header) )
#~ > vcdpreamble = ( Each([Optional(date_header), Optional(version_header), Optional(timescale_header)]) )
#~ > #~ vcdpreamble.setDebug()
#~ >
#~ > vcdheader = Forward()
#~ > #~ vcdheader << ( date_header + version_header + timescale_header + ZeroOrMore(scope) ) # better for debugging like this, then can go with each
#~ > #~ vcdheader << ( vcdpreamble + wire_map + ZeroOrMore(scope) + enddefs_footer) # better for debugging like this, with separate wire_map
#~ > #~ vcdheader << ( vcdpreamble + OneOrMore(var_map | scope) + enddefs_footer)
#~ > #~ vcdheader << ( vcdpreamble + OneOrMore( (var_map | scope) ) + enddefs_footer)
#~ > #~ vcdheader << ( vcdpreamble + OneOrMore( Each ([ Optional(var_map), Optional(scope) ]) ) + enddefs_footer)
#~ > #~ vcdheader << ( vcdpreamble + OneOrMore( ( Optional(var_map) | Optional(scope) ) ) + enddefs_footer)
#~ > #~ vcdheader << ( vcdpreamble + scope + enddefs_footer)
#~ > vcdheader << ( vcdpreamble +  ZeroOrMore( (var_map | scope) ) + enddefs_footer)
#~ > #~ vcdheader.setDebug()
#~ >

#~ Note, data parsing as of now:
#
#~ #2631990000
#~ 1!
#~ 1"
#~ 1#
#~ 1$
#~ #2632000000
#~ 0!
#~ 0#
#~ $dumpoff
#~ x!
#~ x"
#
#~ will be:
#
#~ tmpL_l[len-1]:
#~ [2631990000, ['!', '1'], ['"', '1'], ['#', '1'], ['$', '1']]
#
#~ dumpoffs:
#~ > [[2632000000,
#~ >   ['!', '0'], <====
#~ >   ['#', '0'], <====
#~ >   ['!', 'x'], <==== !!
#~ >   ['"', 'x'],


