#!/usr/bin/env python

# http://effbot.org/zone/readline-performance.htm
# Python function to read file as a string? - Ubuntu Forums - http://ubuntuforums.org/showthread.php?t=443740
# http://stackoverflow.com/questions/587345/python-regular-expression-matching-a-multiline-block-of-text

import re
import numpy
import os

file = open(os.path.expanduser("~/Desktop/hrp7_02-e2.tex"), 'r')

linesstringtext = file.read()

ptrn_moveline = re.compile(r"^\\moveto\((.+),(.+)\)\n\\lineto\((.+),(.+)\)", re.MULTILINE)

# 3.5433071 Inkscape (pstricks) pts = 1 mm = 394 pcbnew units

factor = 394/3.5433071
pcbnwvals = numpy.array([1.0,1.0,1.0,1.0])

# width = 39 in .emp, means 0.381 mm width in pcbnew
width = 39 

# http://www.scipy.org/Numpy_Example_List
## "different output arrays may be specified
## and the output is cast to the new type"
## note: TypeError: 'out' is an invalid keyword to floor ! (but 'round' is OK)
pcbnw_int = numpy.zeros(4, dtype=int)

for match in ptrn_moveline.finditer(linesstringtext):
	#~ print match
	grpz = match.groups()
	#~ print grpz	# ('0', '0', '3.5433071', '0') ; inkscape (0.5)pt units
	xA = float(grpz[0])
	yA = float(grpz[1])
	xB = float(grpz[2])
	yB = float(grpz[3])
	pcbnwvals = numpy.array([xA, yA, xB, yB])*factor
	## the first 'pcbnw_int = ' below, is not strictly needed (but keeping it anyway)
	pcbnw_int = numpy.round(numpy.floor(pcbnwvals),out=pcbnw_int)
	outstr = "DS %d %d %d %d %d 21" % (pcbnw_int[0], pcbnw_int[1], pcbnw_int[2], pcbnw_int[3], width)
	print outstr
	
print '--'
# whole box
## \moveto(0.07444733,5.46777872)
## \lineto(33.36658695,5.46777872)
## \lineto(33.36658695,33.818349)
## \lineto(0.07444733,33.818349)
## \lineto(0.07444733,5.46777872)
# could ignore the last line - but won't

ptrn_moveline = re.compile(r"^\\moveto\((.+),(.+)\)\n\\lineto\((.+),(.+)\)\n\\lineto\((.+),(.+)\)\n\\lineto\((.+),(.+)\)\n\\lineto\((.+),(.+)\)", re.MULTILINE)

# now expecting 10 hits
pcbnw_int = numpy.zeros(10, dtype=int)

for match in ptrn_moveline.finditer(linesstringtext):
	grpz = match.groups()
	xyvals = [float(str) for str in grpz]
	#~ print xyvals
	pcbnwvals = numpy.array(xyvals)*factor
	#~ print pcbnwvals
	## the first 'pcbnw_int = ' below, is not strictly needed (but keeping it anyway)
	pcbnw_int = numpy.round(numpy.floor(pcbnwvals),out=pcbnw_int)
	print "DS %d %d %d %d %d 21" % (pcbnw_int[0], pcbnw_int[1], pcbnw_int[2], pcbnw_int[3], width)
	print "DS %d %d %d %d %d 21" % (pcbnw_int[2], pcbnw_int[3], pcbnw_int[4], pcbnw_int[5], width)
	print "DS %d %d %d %d %d 21" % (pcbnw_int[4], pcbnw_int[5], pcbnw_int[6], pcbnw_int[7], width)
	print "DS %d %d %d %d %d 21" % (pcbnw_int[6], pcbnw_int[7], pcbnw_int[8], pcbnw_int[9], width)



