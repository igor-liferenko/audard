#!/usr/env/bin python
# -*- coding: iso-8859-1 -*-
"""
This module reads kicad .sch using kipy, and generates svg using pysvg.. 
http://pyeda.googlecode.com/svn/trunk/kipy/
http://bazaar.launchpad.net/~kicad-developers/kicad/doc/files/head%3A/doc/help/file_formats/
http://code.google.com/p/pysvg/source/browse/trunk/pySVG/doc/pySVG_Tutorial.doc
"""

import sys, os
sys.path.append("/path/to/kipy") # location of kipy folder - also need for pysvg if its not installed

#~ import kipy
# import pysvg

from pysvg.structure import *
from pysvg.core import *
from pysvg.text import *
from pysvg.builders import * # StyleBuilder, ShapeBuilder

from kipy.fileobjs.paths import kicad_demo_root
from kipy.project import Project
from kipy.parsesch import ParseSchematic
from kipy.fileobjs.net import kicadnet

from kipy.fileobjs import SchFile
from kipy.utility import FileAccess


#~ import traceback
import xml.sax.saxutils
import numpy

projdir = "/path/to/kicad/project" 
projname = "myprojname"
#~ projfn = "%s.pro" % (projname)
projpath = "%s/%s.pro" % (projdir, projname)
schpath = "%s/%s.sch" % (projdir, projname)
svgpath = "%s/%s.svg" % (projdir, projname)

# kicad sch units are in mils (1/1000 inch)
# svg: http://www.w3.org/TR/SVG/coords.html#Units
# When a coordinate or length value is a number without a unit identifier (e.g., "25"), then the given coordinate or length is assumed to be in user units (i.e., a value in the current user coordinate system).
# The list of unit identifiers in SVG matches the list of unit identifiers in CSS: em, ex, px, pt, pc, cm, mm and in.

mils2inch = 1.0/1000
oh = ShapeBuilder()
 
def printContents(insch):
	for item in insch.items:
		#~ if not isinstance(item, sch.Component):
			#~ continue
		#~ fields = item.fields
		
		print item #, dir(item)
		#~ if hasattr(item, 'fields'): # only sch.Component
			#~ print item.fields
			
		it = 1
		try: 
			for prop in item:
				print "--%s" % (item[prop])
		except TypeError: it = None
	
		try: 
			for prop in item.__dict__:
				print "==%s:%s" % (prop, item.__dict__[prop])
		except TypeError: it = None

def getText(intext, posx, posy, fontsize=12):
	esctext = xml.sax.saxutils.escape(intext)
	t=text(esctext, x="%fin"%(posx*mils2inch),y="%fin"%(posy*mils2inch))
	#~ t.set_stroke_width('1px')
	#~ t.set_stroke('#00C')
	#~ t.set_fill('none')
	#~ t.set_font_size("36")	
	t.set_font_size("%fin"%(fontsize*mils2inch))	
	return t

def getRect(startx, starty, width, height, linewidth=2, strokecol='yellow', fillcol='#999999'):
	ci = numpy.array([startx, starty, width, height])*mils2inch
	r = oh.createRect("%fin"%(ci[0]), "%fin"%(ci[1]), "%fin"%(ci[2]), "%fin"%(ci[3]), strokewidth=linewidth, stroke=strokecol, fill=fillcol)
	return r

def getCircle(startx, starty, radius, linewidth=2, strokecol='red', fillcol='#AAAAAA'):
	ci = numpy.array([startx, starty, radius])*mils2inch
	c = oh.createCircle("%fin"%(ci[0]), "%fin"%(ci[1]), "%fin"%(ci[2]), strokewidth=linewidth, stroke=strokecol, fill=fillcol)
	return c

def main():
	mySVG=svg(0,0, width="100%", height="100%")
	
	#~ proj = Project(projname)
	#~ if proj.topschfname:
		#~ try:
			#~ sch = ParseSchematic(proj)
			#~ if not proj.netfn.exists:
				#~ print "Netlist file %s not found" % proj.netfn
				#~ continue
			#~ netlistf = kicadnet.NetInfo(proj.netfn)
			#~ netlistf.checkparsed(sch.netinfo)
			
		#~ except Exception:
			#~ print traceback.format_exc()

	fn = FileAccess(schpath)
	sch = SchFile(fn)
	
	#~ printContents(sch)
	
	# iterate through items in sch, generate svg elements
	dbg = True
	for item in sch.items: 
		if isinstance(item, sch.NoConn):
			if dbg: print "NoConn: ", item.posx, item.posy
			radius = 50 # radius in mils - just an indicator
			c = getCircle(item.posx, item.posy, radius, linewidth=0, fillcol='black')
			mySVG.addElement(c)				
		if isinstance(item, sch.Connection):
			if dbg: print "Connection: ", item.posx, item.posy
			radius = 50 # radius in mils - just an indicator
			c = getCircle(item.posx, item.posy, radius, linewidth=2)
			mySVG.addElement(c)
		if isinstance(item, sch.Wire):
			# wiretype: Notes Line or Wire Line
			if dbg: print "Wire: ", item.startx, item.starty, item.endx, item.endy, item.wiretype 
			myStyle = StyleBuilder()
			myStyle.setStrokeWidth(2)
			myStyle.setStroke('black')
			ci = numpy.array([item.startx, item.starty, item.endx, item.endy])*mils2inch
			l = line("%fin"%(ci[0]), "%fin"%(ci[1]), "%fin"%(ci[2]), "%fin"%(ci[3]))
			l.set_style(myStyle.getStyle())
			mySVG.addElement(l)			
		if isinstance(item, sch.Text):
			# texttype: Label
			if dbg: print "Text: ", item.style, item.orientation, item.text, item.posx, item.posy, item.texttype, item.size
			t = getText(item.text, item.posx, item.posy, item.size)
			mySVG.addElement(t)
			
		if isinstance(item, sch.Component):
			if dbg: print "Component: ", item.subpart, item.parttype, item.timestamp, item.altref, item.variant, item.transform, item.redundant_num, item.posx, item.posy, item.parsestate, item.refdes
			rsize = 500 # square size in mils - just an indicator
			r = getRect(item.posx, item.posy, rsize, rsize, linewidth=2)
			mySVG.addElement(r)

			for field in item.fields:
				i_xpos = field[2]
				i_ypos = field[3]
				i_fontsize = field[4]
				i_extranum = field[5]
				
				if field[0] == item.refdes:
					if dbg: print ".. refdes", field[0], i_xpos, i_ypos, i_fontsize, i_extranum
					t = getText(field[0], i_xpos, i_ypos, i_fontsize)
					mySVG.addElement(t)	
				elif field[0] == item.parttype:
					if dbg: print ".. parttype", field[0], i_xpos, i_ypos, i_fontsize, i_extranum
					t = getText(field[0], i_xpos, i_ypos, i_fontsize)
					mySVG.addElement(t)	
				else:
					if dbg: print ".. pcbdes", field[0], i_xpos, i_ypos, i_fontsize, i_extranum
					t = getText(field[0], i_xpos, i_ypos, i_fontsize)
					mySVG.addElement(t)
				
	
	
	#~ t=text("pySVG", x=0,y=100)
	#~ group=g()
	#~ group.set_transform("rotate(-30)")
	#~ t.set_stroke_width('1px')
	#~ t.set_stroke('#00C')
	#~ t.set_fill('none')
	#~ t.set_font_size("36")
	#~ group.addElement(t)
	#~ mySVG.addElement(group)

	#~ print mySVG.getXML()
	mySVG.save(svgpath)

  
if __name__ == '__main__': 
	main()