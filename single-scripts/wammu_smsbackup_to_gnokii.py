#!/usr/bin/env python

"""
# Copyleft 2014, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

# test w:
# python code/alsa-tests/csv_normalize_cols.py /media/netcolstuff/tmp/alsa-capttest/collectmirq_both.csv > code/alsa-tests/data/collectmirq_both_n.csv

import sys, os, os.path
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

import re
import subprocess
import select
import time

class dObject(object): pass # can add attributes/properties dynamically

class smsItem():
  def __init__(self):
    self.text = ""
    self.folder = ""
    self.sender = ""
    self.datetime = ""


# first command line argument is .csv file name to open
if len(sys.argv) > 1:
  infilename = os.path.realpath(sys.argv[1])
else:
  print("Need the first command line option to be a path to a file; exiting\n")
  sys.exit(1)

if not(os.path.isfile(infilename)):
  print("The file {0} is not a valid file\n".format(infilename))
  sys.exit(1)

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

printse("Input file: {0}\n".format(infilename))

ifile  = open(infilename, "rb")

patStartSection = re.compile(r'^\[SMSBackup.+\]$')
patCommentText = re.compile(r'^; (.+)$')
# for some reason, terminating patNumber with $ makes it fail?
patNumber = re.compile(r'^Number = "(.+)"')
# NOTE: not all entries have DateTime - only the IN ones!
patDatetime = re.compile(r'^DateTime = (.+)')
patFolder = re.compile(r'^Folder = (.+)')

parsed_smses = []
smsptr = None

for line in ifile:
  #printso(line) # don't add trailing newline; is included
  line=line.strip('\n\r')
  if patStartSection.match(line):
    printso(line)
    smsptr = smsItem()
  if patCommentText.match(line):
    if smsptr is not None:
      ttxt = patCommentText.findall(line)[0]
      smsptr.text += ttxt
  if patNumber.match(line):
    if smsptr is not None:
      smsptr.sender = patNumber.findall(line)[0]
  if patDatetime.match(line):
    if smsptr is not None:
      smsptr.datetime = patDatetime.findall(line)[0]
  if patFolder.match(line):
    if smsptr is not None:
      smsptr.folder = patFolder.findall(line)[0]
  # this one first, as we need to strip the line?
  # (although could test via "" too)
  if line == "": #"\n":
    if smsptr is not None:
      parsed_smses.append(smsptr)
      smsptr = None

# should have sorted the array here by date ascending; forgot...

# test write - yup, it is always ('4'; 'NULL'): ('OU'; 'NULL')
# also since these are separate SMSes, the length is below 160 for sure
# change folder numbers in this step too
# also reparse the datetime for gnokii
my_env = os.environ.copy() # os.environ
my_env["LD_LIBRARY_PATH"] = "/usr/local/lib"
for isms in parsed_smses:
  tdt = "NULL" if isms.datetime=="" else isms.datetime
  folderid = "IN" if isms.folder=="3" else "OU"
  isms.folder = folderid
  tdr=""
  # 20140530T141539Z -> 140604040101 YYMMDDHHMMSS; put in fake stamp (00=2000)
  if isms.datetime=="":
    tdr="000101000000"
  else:
    tdr=isms.datetime[2:8] + isms.datetime[9:15]
  isms.datetime = tdr
  printso("* {0} ('{1}'; '{2}'), {3} ({4}): {5}\n".format(isms.sender, isms.folder, tdt, isms.datetime, len(isms.text), isms.text))
  cmdstr=""
  if isms.folder == "IN":
    cmdstr="echo '{0}' | gnokii --savesms --sender '{1}' --folder IN --read --deliver --datetime {2}".format(isms.text, isms.sender, isms.datetime)
  else:
    cmdstr="echo '{0}' | gnokii --savesms --sender '{1}' --folder OU --sent --datetime {2}".format(isms.text, isms.sender, isms.datetime)
  printso(cmdstr+"\n")

  # run command
  child_proc = subprocess.Popen(cmdstr, stdout=subprocess.PIPE, stderr=subprocess
.PIPE, shell=True, executable="/bin/bash", env=my_env)
  #stdout_value, stderr_value = child_proc.communicate()
  ## don't wait for return:
  #rc = child_proc.returncode
  #if (rc == 0): # all is fine with command:
  #  ims = stdout_value
  ## ... realtime subprocess out:
  stdout = []
  stderr = []
  while True:
    reads = [child_proc.stdout.fileno(), child_proc.stderr.fileno()]
    ret = select.select(reads, [], [])
    for fd in ret[0]:
      if fd == child_proc.stdout.fileno():
        read = child_proc.stdout.readline()
        sys.stdout.write('stdout: ' + read)
        stdout.append(read)
      if fd == child_proc.stderr.fileno():
        read = child_proc.stderr.readline()
        sys.stderr.write('stderr: ' + read)
        stderr.append(read)
    if child_proc.poll() != None:
      break
  # done command, relax before next loop
  printso("....\n\n")
  time.sleep(0.5)
