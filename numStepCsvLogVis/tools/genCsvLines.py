#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes on Unicode in comments

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
usagemsg = "genCsvLines.py ( %(prog)s ) v.{0}".format(__version__) + """
Tester that generates CSV file lines, and
outputs them at uneven intervals (python2.7/3.2)
(NB: piping into `echo` fails - pipe into `cat`!)
Loops forever - press Ctrl+C to exit

Usage:
  python genCsvLines.py | cat

  ( trap : SIGTERM SIGINT ; \\
  python genCsvLines.py > csvlines.csv & p1=$! ; \\
  tail -f csvlines.csv & p2=$! ; \\
  echo $p1 $p2 ; wait ; \\
  kill -9 $p1 $p2 ; sleep 0.1 ; ps -p $p1 $p2  )

"""
# keep the subprocess bash command in parenthesis,
# to exit succesfully; for more, see:
# http://stackoverflow.com/questions/1644856/terminate-running-commands-when-shell-script-is-killed
# http://stackoverflow.com/questions/10430126/how-to-stop-tail-f-command-executed-in-sub-shell
# also, use `wait` without a pid - so it waits for all child processes;
# in that case, in most cases, kill -9 will complain with "No such process", but nvm
# sometimes `wait` may get stuck too - when we pipe genCsvLines into
# numStepCsvTerminal.py, and we press `q` to exit numStepCsvTerminal;
# in this case an extra Ctrl-C should help...
# Thus - only exit the subprocess pipe with Ctrl-C (not with `q`, ESC or similar)

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

"""
test for python2/python3 ; __future__ since python2.6
note: cannot import __future__ conditionally (compile-time statement)
(also, sometimes get a stdout lock at import urlopen, requiring
keypress - in that case, kill program, try again)
"""
import __future__ # we can't use this really; keep it anyway
if sys.version_info[0] < 3:
  #printso("sys.version < 3\n")
  text_type = unicode
  binary_type = str
else:
  #printso("sys.version >= 3\n")
  text_type = str
  binary_type = bytes

"""
rest of imports that work the same for 2.7 and 3.x:
"""
import argparse # command line options (instead of getopt), 2.7+
import time # sleep
import signal # Ctrl-C (SIGINT) handler
#import os # basename

# ##################### FUNCTIONS     ##########################################

def signalINT_handler(signal, frame):
  printse("\nYou pressed Ctrl+C ({0})! Exiting.\n".format(os.path.basename(sys.argv[0])))
  sys.exit(0) # just return doesn't exit!
signal.signal(signal.SIGINT, signalINT_handler)

"""
When piping into programs like `echo`, that
don't accept stdin, SIGPIPE is generated:
[http://bugs.python.org/issue11380 Issue 11380: "close failed in file object destructor" when "Broken pipe" happens on stdout - Python tracker]
Inside main(); the following doesn't catch SIGPIPE:
  try:
  except:
    te = sys.exc_info()[1]
    printse("Pipe has been closed by app on other end; exiting,", te, "\n")
    sys.exit(1)
... when making the mistake of piping into `echo` and similar; see
http://stackoverflow.com/questions/16314321/suppressing-printout-of-exception-ignored-message-in-python-3
So, we add a SIGPIPE handler, and perform the exiting from there;
however, in Python 3 the handler can be called multiple times,
resulting at end with `Exception ... ignored` message.
So as soon as this handler has been called once, prevent double call -
set SIGPIPE (for next time) to run SIG_DFL (the default op; possibly ignoring)
In this way, we have same error msg for both Python 2.7 and 3.3;
but for python 2.7 - we must also have a try/except!
# also note TypeError: signal handler must be
# signal.SIG_IGN, signal.SIG_DFL, or a callable object
"""
def signalPIPE_handler(signal, frame):
  import signal
  printse("signalPIPE_handler! ({0}): {1} \n".format(
    os.path.basename(sys.argv[0]), sys.exc_info()[1]) )
  printse("Pipe has been closed by app on other end; exiting.\n")
  signal.signal(signal.SIGPIPE, signal.SIG_DFL)
  sys.exit(0) # just return doesn't exit!
signal.signal(signal.SIGPIPE, signalPIPE_handler)


"""
Here we had no command line options; and
we used argparse simply to generate a help message;
but now we have an actual option
"""
def processCmdLineOptions():
  optparser = argparse.ArgumentParser(description=usagemsg,
              formatter_class=argparse.RawDescriptionHelpFormatter)
  optparser.add_argument('-n', '--no-header-line', action='store_true',
                          help='don\'t print header: 1st line in CSV is data, not a header')
  optargs = optparser.parse_args(sys.argv[1:])  #(sys.argv)
  return optargs

# ##################### MAIN          ##########################################

def main():
  global optargs # here we set; needs global
  optargs = processCmdLineOptions()
  # output header
  tsrt = "# testA,testB,icount,testC,testD"
  try:
    if not(optargs.no_header_line):
      printso(tsrt,"\n")
    # output lines - loop forever (exit with Ctrl-C)
    icount = 0
    while True:
        tarr = [icount, 10, icount, 100, 100]
        if icount == 0:
          tarr[0] = "INIT"
          tarr[3] = ""
        printso(",".join(map(str,tarr)),"\n")
        icount += 1
        time.sleep(0.5)
        itest = 0
        for ix in list(range(1,4)): # 1..3
          itest += icount + ix
          itest2 = itest % 5
          tarr = (icount, 20, 20, itest, itest2)
          printso(",".join(map(str,tarr)),"\n")
          icount += 1
        time.sleep(1)
        for ix in list(range(1,5)): # 1..4
          tarr = (icount, 10, 10, 40, 40)
          printso(",".join(map(str,tarr)),"\n")
          icount += 1
          time.sleep(0.6)
        time.sleep(1.5)
  except IOError:
    printse("This message won't print, signalPIPE_handler will exit before; the except clause is added only to prevent traceback from Python 2.7 in case of SIGPIPE\n")


# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()





