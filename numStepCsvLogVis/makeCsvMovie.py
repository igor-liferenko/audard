#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes even on Unicode in comments

"""
# Part of the numStepCsvLogVis package
#
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

"""
No command line options in this script;
all the batch options are set through variables
"""


import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()
versionf = scriptdir + os.sep + "VERSION"
try: __version__ = next(open(versionf))
except: __version__ = sys.exc_info()[1]

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

import subprocess


def getCommandOutput(incmd):
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

def callCommand(incmd):
  # but maybe easier to just go with subprocess.call in this case;
  # no return strings - again shell=False; if we want to pass
  # command as list of arguments!
  subprocess.call(incmd, shell=False)


# #### MAIN BATCH ##############################################################

CSVFILE="./archive/testTSB_log.csv"
#GKFILE="./archive/testTSB_log._gk" # should be read automatically, if name matches
RENDERDIR="render_testTSB_log" # can be autocomputed - for here, manually

PLAYCOLUMN=1
PLAYANIMSTEP=50e-6
PLAYFPS=25.0 # setting for the final movie
PLAYERSPEC=" ".join( map(str, (PLAYCOLUMN, PLAYANIMSTEP, PLAYFPS)) )

ARATE = 8000 # audio file rate/sampling frequency in Hz
PLAYSTEPFILE  = "testTSB_log.playstep"
PLAYSTEPSOUND = "/usr/share/sounds/ubuntu/stereo/bell.ogg" # will be converted
PLAYSTEPSNDU8 = "bell.wav" # name of converted uint8 wav file
CONVOLSCRIPT  = "./tools/naiveConvolveWav2.py"
OUTCWAVU8     = "testTSB_log_u8.wav"  # output of convolution (uint8, 8k)
OUTCWAVF      = "testTSB_log_hCD.wav" # previous file converted to final format for video (16b, 22k)
OUTARATE = 22050
OUTVIDEOFILE  = "testTSB_log2.avi" # avi is now probably better than .mpg; it doesn't lose sync when looping in player

# we have to run the rendering first, to obtain how many frames will be
# obtained for a given animstep and column ; only afterwards we can calculate
# the step for audio

runRenderPng = True
runConvolution = True
runMuxAndPlay = True

# run rendering:

if runRenderPng:
  tcmd = [sys.executable, "numStepCsvLogVis.py",
    "--dump-renderpng",
    "-y", PLAYERSPEC,
    CSVFILE
    ]

  printse(tcmd,LF)
  callCommand(tcmd)

numRenderedFrames = len(os.listdir(RENDERDIR))
durationsec = numRenderedFrames/PLAYFPS
expectedSamples = durationsec*ARATE

PLAYAUDSTEP = PLAYANIMSTEP*numRenderedFrames/((numRenderedFrames/PLAYFPS)*ARATE)

printse("audstep: {0}; expected duration {1}, samples: {2}\n".format(
  PLAYAUDSTEP, durationsec, (numRenderedFrames/PLAYFPS)*ARATE )
  )

PLAYERSPEC2 = " ".join( map(str, (PLAYCOLUMN, PLAYAUDSTEP, PLAYFPS)) )

# must also quote the playerspec arg here, as it contains spaces!
tcmd = [sys.executable, "numStepCsvLogVis.py",
  "--dump-playstep", "-e",
  "-y", '"'+PLAYERSPEC2+'"',
  CSVFILE,
  ">", PLAYSTEPFILE
  ]

# this run in shell=True, as it requires redirection
tcmds = " ".join(tcmd)
printse(tcmds,LF)
subprocess.call(tcmds, shell=True)

# check size
tcmd = ["du", "-b", PLAYSTEPFILE]
printse(tcmd,LF)
#callCommand(tcmd)
ret = subprocess.Popen(tcmd, stdout=subprocess.PIPE, shell=False).stdout.read()
stepfilesize = float(ret.split()[0])
printse(stepfilesize, LF)
stretchfactor = expectedSamples/stepfilesize
printse("stretchfactor", stretchfactor, LF)



# convert audio file
tcmd = ["sox", PLAYSTEPSOUND,
  "-r", str(ARATE), "-e", "unsigned", "-b", "8", "-c", "1",
  PLAYSTEPSNDU8
  ]
printse(tcmd,LF)
callCommand(tcmd)

# check size
tcmd = ["du", "-b", PLAYSTEPSNDU8]
printse(tcmd,LF)
callCommand(tcmd)

if runConvolution:
  # run convolution - use naiveConvolveWav2.py
  tcmd = [sys.executable, CONVOLSCRIPT,
    PLAYSTEPFILE, PLAYSTEPSNDU8,
    ">", OUTCWAVU8
    ]

  # this run again in shell=True, as it requires redirection
  tcmds = " ".join(tcmd)
  printse(tcmds,LF)
  subprocess.call(tcmds, shell=True)

# check size
tcmd = ["du", "-b", OUTCWAVU8]
printse(tcmd,LF)
callCommand(tcmd)

# convert sound again to "output" format - stretch too:
tcmd = ["sox", OUTCWAVU8,
  "-r", str(OUTARATE), "-e", "signed", "-b", "16", "-c", "2",
  OUTCWAVF,
  "stretch", str(stretchfactor)
  ]
printse(tcmd,LF)
callCommand(tcmd)

# get new duration - compare
tcmd = ["soxi", OUTCWAVF]
ret = subprocess.Popen(tcmd, stdout=subprocess.PIPE, shell=False).stdout.read()
reta = utd(ret).split(LF)
printse(reta[5], LF)

# finally, interleave rendered PNG frames, and the audio,
# to generate a movie

if runMuxAndPlay:
  tcmd = ["ffmpeg", "-f", "image2",
    "-i", RENDERDIR+os.sep+"%05d_testTSB_log.png",
    "-itsoffset", "0.01",
    "-async", "0",
    "-i", OUTCWAVF,
    "-y",
    OUTVIDEOFILE
    ]
  printse(tcmd,LF)
  callCommand(tcmd)

  # at end, start mplayer - so we can see the audio/visual experience :)
  #mplayer -really-quiet testTSB_log.mpg -loop 0 2>/dev/null

  tcmd = ["mplayer", "-really-quiet",
    OUTVIDEOFILE,
    "-loop", "0"
    ]
  printse(tcmd,LF)
  callCommand(tcmd)


printse("\nTo delete temp files; run: \n")
printse(" ".join(["rm -rf", RENDERDIR, PLAYSTEPFILE, PLAYSTEPSNDU8, OUTCWAVU8, OUTCWAVF]), LF )
