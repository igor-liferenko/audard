#!/usr/bin/env python
#"""
# Part of the numStepCsvLogVis package
#
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
#"""
"""
only 8-bit mono wav input is supported
(ok Python 2.7/3.2)

perl -e '$i=0; while ($i < 16000) {$a="\n"; if (not($i%3500)) {$a="*\n";}; print $a ; $i=$i+1; } ' > testw.dat
sox /usr/share/sounds/ubuntu/stereo/bell.ogg -r 8k -e unsigned -b 8 -c 1 bell.wav
python naiveConvolveWav.py testw.dat bell.wav > out.wav
"""
# http://docs.cython.org/src/userguide/numpy_tutorial.html
# modded for 1-D convolution (int):
from __future__ import division
import numpy #as np
def naive_convolve(f, g):
  # f is an image and is indexed by (v, w)
  # g is a filter kernel and is indexed by (s, t),
  #   it needs odd dimensions
  # h is the output image and is indexed by (x, y),
  #   it is not cropped
  if len(g) % 2 != 1: #g.shape[0] % 2 != 1 or g.shape[1] % 2 != 1:
      raise ValueError("Only odd dimensions on filter supported")
  # smid and tmid are number of pixels between the center pixel
  # and the edge, ie for a 5x5 filter they will be 2.
  #
  # The output size is calculated by adding smid, tmid to each
  # side of the dimensions of the input image.
  vmax = f.shape[0] #len(f) #f.shape[0]
  smax = g.shape[0] #len(g) #g.shape[0]
  smid = smax // 2
  xmax = vmax + 2*smid
  # Allocate result image.
  h = numpy.zeros([xmax], dtype=numpy.float) #[0]*xmax #np.zeros([xmax], dtype=int)
  numop = 1
  # Do convolution
  for x in range(xmax):
    # Calculate pixel value for h at (x,y). Sum one component
    # for each pixel (s, t) of the filter g.
    s_from = max(smid - x, -smid)
    s_to = min((xmax - x) - smid, smid + 1)
    value = 0
    if not(x%1000): sys.stderr.write("{0} ({1})\r".format(x, numop))
    for s in range(s_from, s_to):
      v = x - smid + s
      value += g[smid - s] * f[v]
      numop+=1
    h[x] = value
  return h

"""
a = [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 ]
b = [5, 4, 3, 2, 1]
print(naive_convolve(a, b))
"""

import sys
if sys.version_info[0] < 3:
  text_type = unicode
  binary_type = str
  binout = sys.stdout
else:
  text_type = str
  binary_type = bytes
  binout = sys.stdout.buffer

import array
import struct
import ctypes


if (len(sys.argv) != 3):
  print("usage (mono, 8-bit only): {0} datfile wavfile > out.wav".format(sys.argv[0]))
  exit(1)

datfile = sys.argv[1]
wavfile = sys.argv[2]

adat = []
with open(datfile, "rb") as f:
  byte = f.read(1)
  while byte:
    if byte == b'\n':
      adat.append(0)
    else:
      adat.append(1)
    byte = f.read(1)
awav = []
with open(wavfile, "rb") as f:
  byte = f.read(1)
  while byte:
    awav.append(ord(byte))
    byte = f.read(1)

wavheader = awav[:44]
awavraw = awav[44:]

if len(awavraw) % 2 != 1:
  awavraw.append(0)

sys.stderr.write("size {0}x{1} convolution: {2}\n".format(
  len(adat), len(awavraw), len(adat)+len(awavraw)) )

# convert lists to np.array floating numbers
# scale the uint (0-255) values of awavraw to range -1.0:1.0
awavraw = numpy.array(awavraw, dtype=numpy.float)
awavraw = (awavraw-128.0)/128.0
# "fade out" - actually force the tail (last 10 samples) of awavraw to 0.0 - so we avoid nasty double-clicks at end of sound in convolution:
awavraw[-10:] = [0.0]*10
# adat is already 0 and 1 - just cast to float
adat = numpy.array(adat, dtype=numpy.float)

# testing truncation
#awavraw = awavraw[:9]
#adat = adat[:9]

aconvo = naive_convolve(adat, awavraw)
#numpy.save("aconvobin", aconvo)

#aconvo = numpy.load("aconvobin.npy")

sys.stderr.write("\n")
# normalize
aconvomax = max(abs(aconvo))
#aconvonrm = [int(x*(2**8-1)/aconvomax) for x in aconvo]
aconvonrm = aconvo/aconvomax
# very crude replacement of 0 with 127 (which is audio zerolevel)
# will also distort the sound, however
#aconvonrm = [127 if x==0 else x for x in aconvonrm]

# adding adat back to the convolution seems to enhance the beats a little - just don't overflow (-0.008 overflows):
aconvonrme = adat*0.2-0.007
#sys.stderr.write(str(aconvonrme)+"\n")
#don't resize up:
#aconvonrme.resize(aconvonrm.shape)
#sys.stderr.write(str(aconvonrme)+"\n")

#resize down to original input instead!
aconvonrm.resize(adat.shape)
aconvonrme = aconvonrm + aconvonrme

aconvonrm2 = aconvonrme*128.0+128.0 # floats

#aconvonrmu = numpy.zeros([aconvonrm.shape[0]], dtype=int)
#aconvonrmu = int(aconvonrm*128+128)
aconvonrmu = aconvonrm2.astype(int)

aout = wavheader
aout.extend(aconvonrmu)

SubChunk2Size = len(aconvonrmu)
s2sdat=ctypes.create_string_buffer(4)
# I unsigned int; i signed int
struct.pack_into("<I", s2sdat, 0, SubChunk2Size)
ChunkSize = 36 + SubChunk2Size
csdat=ctypes.create_string_buffer(4)
struct.pack_into("<I", csdat, 0, ChunkSize)
#sys.stderr.write(str(list(s2sdat))+"\n")
#sys.stderr.write(str(list(csdat))+"\n")
csdata = [ord(x) for x in csdat]
s2sdata = [ord(x) for x in s2sdat]
aout[4:8] = csdata
aout[40:44] = s2sdata

a = array.array('B', aout)
a.tofile(binout)

