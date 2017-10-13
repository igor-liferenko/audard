#!/usr/env/bin python
# -*- coding: iso-8859-1 -*-
"""
sdaau 2010 
cmdl-blockdiag-fig-skencil.py

This script is a demonstration of coded (scripted), command line
vector drawing - using Python with the Skencil API. 

Based on script: http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/cmdline_draw_skencil_script.py?view=markup
License: same as above 'based on' script :) 

# call with:
# $ python [scriptname].py
# and a '[scriptname].py.ps' file will be generated in the same dir.. 
"""

import sys, os
from math import atan2, hypot, pi, radians
#~ from string import join, replace
#~ import re

# for 1.0alpha installed on ubuntu: 
sys.path.append("/usr/lib/python2.6/dist-packages/skencil")
import skencil 
from skencil import * # so no need for skencil.Sketch

import Sketch
#~ import Sketch.Scripting
from Sketch import _, const, config, load, plugins, SketchVersion
from Sketch import Graphics
# avoid font glyph problems on .AsBezier()
config.font_path.append('/var/lib/defoma/gs.d/dirs/fonts') 
config.font_path.append('/usr/share/fonts/X11/Type1')
config.font_path.append('/usr/share/fonts/type1/gsfonts')
config.font_path.append('/usr/share/fonts/type1/mathml')
# get font info first
Graphics.font.read_font_dirs()
#~ print Graphics.font.fontlist 


from Sketch import Publisher, Document, GuideLine, PostScriptDevice, SketchError
from Sketch.const import DOCUMENT, CLIPBOARD, CLOSED, COLOR1, COLOR2
from Sketch.const import STATE, VIEW, MODE, SELECTION, POSITION, UNDO, EDITED,\
	 CURRENTINFO

from Sketch.Lib import util
from Sketch.warn import warn, warn_tb, INTERNAL, USER
from Sketch.Graphics import image, eps

from Sketch import Style, EmptyFillStyle, EmptyLineStyle, EmptyPattern
from Sketch import SolidPattern, StandardColors, CreateRGBColor
from Sketch import SimpleText, GetFont

from Sketch import Trafo, Translation, Rotation, CreatePath
from Sketch import Point, Bezier, PolyBezier # to draw a line
from Sketch import Rectangle	# box
from Sketch import Arrow		# arrowhead/tails for lines
from Sketch import Ellipse		# circles
from Sketch import Group

# must add the right (sub)directory
sys.path.append("/usr/lib/python2.6/dist-packages/skencil/Plugins/Filters")
import pdfgensaver
from Sketch.Graphics import pagelayout


# define arrows manually: 
elp = Ellipse(start_angle = 0.0, end_angle = 2*pi)
elp_radius = 2.5
elp_startx = 0
elp_starty = 0
elp.trafo = Trafo(elp_radius, 0, 0, elp_radius, elp_startx, elp_starty)
elpbz = elp.AsBezier() 
elpbz_nl = elpbz.Paths()[0].NodeList() # as list of Point(x,y)
arpath2 = [(-4, 3),(2, 0), (-4, -3)] # (same values as default arrow)
arpath3 = [(0, -2),(0, 2)] # juss a line

global tarrw1, tarrw2, tarrw3
tarrw1 = Arrow(elpbz_nl, closed=1) 
tarrw1.path = elpbz.Paths()[0] # make real circle! 
tarrw2 = Arrow(arpath2, closed=1)
tarrw3 = Arrow(arpath3, closed=0) # open, its just a line (two points) - so it inherits line_width

global tbase_style
tbase_style = Style()
tbase_style.fill_pattern = EmptyPattern
tbase_style.fill_transform = 1
tbase_style.line_pattern = SolidPattern(StandardColors.red)
tbase_style.line_width = 2.0
tbase_style.line_join = const.JoinMiter
tbase_style.line_cap = const.CapButt
tbase_style.line_dashes = ()
tbase_style.line_arrow1 = tarrw1
tbase_style.line_arrow2 = tarrw2
tbase_style.font = None
tbase_style.font_size = 12.0

global courfont
courfont = GetFont('Courier-Bold') #('Times-Bold')


"""
Helpers. ................................................
"""
# helper - for easier generating of a line from two points as tuples
def getQuickLine(tstart, tend):
	# expected tuple at input 
	
	pstart = Point(tstart[0], tstart[1])
	pend = Point(tend[0], tend[1])
	tpath = CreatePath()
	
	# Note - apparently, the first appended point is "moveTo";
	# .. the subsequent ones being "LineTo"	
	tpath.AppendLine(pstart) # moveto
	tpath.AppendLine(pend) # lineto
	
	tline = PolyBezier((tpath,))
	#~ tline.AddStyle(tbase_style) # of Graphics.properties (also in compound, document) - seems to add a 'layer' if dynamic; else seems to 'replace' ?!
	#~ tline.SetProperties(line_pattern = SolidPattern(CreateRGBColor(0.7, 0.7, 0.9)))
	tline.update_rects()
	return tline

# helper - for easier generating a rectangle - four points as numbers
def getQuickRect(sx, sy, ox, oy):
	start_x = sx
	start_y = sy
	off_x = ox
	off_y = oy
	trec = Rectangle(trafo = Trafo(off_x, 0, 0, off_y, start_x, start_y))
	trec.update_rects()
	return trec

# seems just calling textfld.bounding_rect is a bit better than getTfBB
def getTfBB(inTextField):
	a = inTextField.properties 
	return a.font.TextBoundingBox(inTextField.text, a.font_size) # llx, lly, urx, ury = 

def getStructBoxnode(inlabel, plist,vlist):
	global courfont
	global tarrw1, tarrw2, tarrw3
	pvfnsz = 12 # font size for pointers/vars
	
	# here we'll also generate a dict of all graphic objects
	# global 'id' is not needed - it will be a part of a tuple, along with master group
	sbdict = {}
	
	## pointers - horizontal 
	yoff = 0 
	ypad = 2
	lastcharpad = pvfnsz # so the arrow dont overlap with last char
	xoutermost = 0 # to get the longest arrow (so we use it to make arrows same length) 
	point_tflist = [] # list of actual textfield objects
	tcount = 0 
	for iptxt in plist:
		textfld = SimpleText(Translation(0, yoff), iptxt)
		textfld.SetProperties(font = courfont, font_size = pvfnsz)
		textfld.update_rects()
		sbdict['ptf_'+str(tcount)] = textfld
		# add connector line
		tfbr = textfld.bounding_rect
		tfline = getQuickLine((tfbr.left, tfbr.bottom),(tfbr.right+lastcharpad,tfbr.bottom))
		tfline.SetProperties(line_width = 2.0, line_arrow1 = tarrw1, line_arrow2 = tarrw2)
		tfline.update_rects()
		sbdict['ptfl_'+str(tcount)] = tfline
		if tfbr.right+lastcharpad > xoutermost:
			xoutermost = tfbr.right+lastcharpad
		# group line and text
		tgrp = Group([tfline, textfld])
		tgrp.update_rects()
		sbdict['ptfg_'+str(tcount)] = tgrp
		# add the group - not just textfld - to list here
		point_tflist.append(tgrp)
		# get height - calc next offset; yoff will go negative, but nvm (will group and move)  
		# don't use tgrp's BB, its too high
		llx, lly, urx, ury = textfld.bounding_rect # /tgrp. /getTfBB(textfld)
		tfHeight = ury - lly
		yoff -= tfHeight + ypad
		tcount += 1
	# done - now resize all the arrows according to xoutermost, 
	# so they are same length
	# SetLine(i, x, y[, cont]) "Replace the ith segment by a line segment"
	# where the i-th segment is the node.. 
	for tgrp in point_tflist: 		# loop (in a list)
		tfline = tgrp.objects[0]	# access Group (sub)object - tfline is first [0]
		# get 2nd node (=segment 1) - in there, Point() is third in list ([2]) 
		tmpep = tfline.paths[0].Segment(1)[2]
		# change 2nd node (=segment 1) of the (first) path (paths[0])
		tfline.paths[0].SetLine(1, (xoutermost,tmpep.y))
		tfline.update_rects()
		tgrp.update_rects()
	# finally, group all these 
	point_group = Group(point_tflist) # accepts list directly 
	point_group.update_rects()	
	sbdict['ptg'] = point_group
	
	## variables - vertical (so, rotate group afterwards)
	yoff = 0 
	ypad = 2
	lastcharpad = 1 # pvfnsz /so the arrow dont overlap with last char
	xoutermost = 0 # to get the longest arrow (so we use it to make arrows same length) 	
	varbl_tflist = [] # list of actual textfield objects
	tcount = 0 
	havevars = len(vlist) # could be zero! 
	for ivtxt in vlist:
		textfld = SimpleText(Translation(0, yoff), ivtxt)
		textfld.SetProperties(font = courfont, font_size = pvfnsz)
		textfld.update_rects()
		sbdict['vtf_'+str(tcount)] = textfld
		# add connector line
		tfbr = textfld.bounding_rect
		tfline = getQuickLine((tfbr.left, tfbr.bottom),(tfbr.right+lastcharpad,tfbr.bottom))
		tfline.SetProperties(line_width = 2.0, line_arrow1 = tarrw1, line_arrow2 = tarrw3)
		tfline.update_rects()
		sbdict['vtfl_'+str(tcount)] = tfline
		if tfbr.right+lastcharpad > xoutermost:
			xoutermost = tfbr.right+lastcharpad		
		# group line and text
		tgrp = Group([tfline, textfld])
		tgrp.update_rects()
		sbdict['vtfg_'+str(tcount)] = tgrp
		# add the group - not just textfld - to list here		
		varbl_tflist.append(tgrp)
		# get height - calc next offset; yoff will go negative, but nvm (will group and move)  
		llx, lly, urx, ury = textfld.bounding_rect # getTfBB(textfld)
		tfHeight = ury - lly
		yoff -= tfHeight + 2
		tcount += 1
	# done - now resize all the arrows according to xoutermost, 
	# so they are same length
	# SetLine(i, x, y[, cont]) "Replace the ith segment by a line segment"
	# where the i-th segment is the node.. 
	for tgrp in varbl_tflist: 		# loop (in a list)
		tfline = tgrp.objects[0]	# access Group (sub)object - tfline is first [0]
		# get 2nd node (=segment 1) - in there, Point() is third in list ([2]) 
		tmpep = tfline.paths[0].Segment(1)[2]
		# change 2nd node (=segment 1) of the (first) path (paths[0])
		tfline.paths[0].SetLine(1, (xoutermost,tmpep.y))
		tfline.update_rects()
		tgrp.update_rects()
	# finally, group all these 		
	varbl_group = Group(varbl_tflist) # accepts list directly 
	varbl_group.update_rects()
	sbdict['vtg'] = varbl_group
	
	# rotate variable group 
	# for repositioning - easiest to rotate around 
	#  upper-left corner (instead of center point) 
	vgbr = varbl_group.bounding_rect
	varbl_g_cp = vgbr.center() # centerpoint
	varbl_g_ul = Point(vgbr.left, vgbr.top) # top (upper) left
	varbl_group.Transform(Rotation(radians(-90), varbl_g_ul))
	varbl_group.update_rects()
	
	# must reassign variable for .bounding_rect
	#  after transform and update_rects()!!: 
	vgbr = varbl_group.bounding_rect 
	vgbr_w = vgbr.right - vgbr.left
	vgbr_h = vgbr.top - vgbr.bottom
	# also, below needed for box & move calc:
	#~ point_group.update_rects()	
	pgbr = point_group.bounding_rect
	pgbr_w = pgbr.right - pgbr.left
	pgbr_h = pgbr.top - pgbr.bottom	
	
	# and note - groups seem to add some sort of padding, so align to intern lines instead (instead of group BB edges) 
	# get first (moveto) Point of first tf's line (align to that, instead of pgbr) - needed for 'boxing' below:
	tfline = point_group[0].objects[0]
	tmpep = tfline.paths[0].Segment(0)[2]
	tmpep_v = Point(0, 0)
	if havevars != 0:
		tmpep_v = varbl_group[0].objects[0].paths[0].Segment(0)[2]
	xmoveadj = tmpep.x-pgbr.left # adjustment due to group padding
	ymoveadj = -(tmpep_v.y-vgbr.top) # only for moving varbl_group
	
	# move rotated varbl_group below left of point_group
	xmove = 0 # -vgbr_w # looks ok like this
	xmove += xmoveadj # adjust due to group padding
	ymove = -pgbr_h
	ymove += ymoveadj # adjust due to group padding
	varbl_group.Translate(Point(xmove, ymove))
	varbl_group.update_rects()
	vgbr = varbl_group.bounding_rect
		
	## add the box label 
	lxpad = 10 # box label x padding
	tfld_label = SimpleText(Translation(0, 0), inlabel)
	tfld_label.SetProperties(font = courfont, font_size = 16)
	tfld_label.update_rects()
	# reposition
	# on y: center align tfld_label with center of point_group
	cp_pg = pgbr.center()
	tlbr = tfld_label.bounding_rect
	cp_tl = tlbr.center()
	ymove = -(cp_tl.y - cp_pg.y)
	# on x: <NO>align right edge of tfld_label + pad with left edge of point_group</NO>
	#    center in respect to expected boxwidth instead
	# calc expected boxwidth first
	tlbr = tfld_label.bounding_rect
	tlbr_w = tlbr.right - tlbr.left
	boxwidth = lxpad + tlbr_w + lxpad # only title text label width + padding
	varbl_width = vgbr.right - vgbr.left
	if boxwidth < lxpad + varbl_width + lxpad:
		boxwidth = lxpad + varbl_width + lxpad		
	#~ xmove = -(tlbr.right + lxpad - pgbr.left) # title text left aligned w/ right edge
	xmove = -( (tlbr.center().x - pgbr.left) + boxwidth/2)
	xmove += xmoveadj # adjust due to group padding
	tfld_label.Translate(Point(xmove, ymove))
	tfld_label.update_rects()
	tlbr = tfld_label.bounding_rect # must reassign variable (though we won't need it anymore)

	## create a box for point/varbl_group
	# start at upper left point of point_group BB; 
	# go downleft, to <NO>upper left point of varbl_group BB</NO>
	#  .. note - groups seem to add some sort of padding, so align to intern lines:
	# go downleft, to upper edge of varbl_group, and ([left edge of tfld_label] - pad)
	# get first (moveto) Point of first tf's line (align to that, instead of pgbr)
	tfline = point_group[0].objects[0]
	tmpep = tfline.paths[0].Segment(0)[2] 
	start_x = tmpep.x # pgbr.left
	start_y = pgbr.top
	off_x = -( boxwidth ) # -vgbr_w
	off_y = -pgbr_h
	trec = Rectangle(trafo = Trafo(off_x, 0, 0, off_y, start_x, start_y))
	trec.SetProperties(line_width = 2.0,
		fill_pattern = SolidPattern(CreateRGBColor(0.7, 0.7, 0.9)),
	)
	trec.update_rects()
	sbdict['box'] = trec
	
	# now group all these 
	# grouping goes: 1st on bottom, 2nd on top of it, etc.. 
	retgrp = Group([trec, tfld_label, point_group, varbl_group])
	retgrp.update_rects()
	
	# move lower left corner of retgrp to 0,0
	rgbr = retgrp.bounding_rect
	retgrp.Translate(Point(-rgbr.left, -rgbr.bottom))
	retgrp.update_rects()
	
	return (retgrp, sbdict)

def getStdConnLine(fromobj, toobj, cplist=()):
	global tarrw1, tarrw2, tarrw3
	#~ snAdct['ptfl_1'],	# from (startpoint - moveto)
	#~ snBdct['box'],		# to (endpoint)
	#~ # here optional arguments for 'in-between' points;
	#~ # (ordered) tuple of dict, where key is command: 
	#~ # like in tikz:: '|' means along y  ,  '-' means along x
	#~ # (last {'-':-10}, is not needed - endpoint specifies it 
	#~ ({'-':10}, {'|':-20}, {'-':-30}, {'|':-40})
	
	# for now, we expect that fromobj is always going to be a
	# 'pointer' tf line; and to obj is going to be a box
	
	connlineCol = SolidPattern(CreateRGBColor(0.3, 0.3, 0.3))
	
	# retrieve start point - endpoint of fromobj ptf line
	# get 2nd node (=segment 1) - in there, Point() is third in list ([2]) 
	tmpep_start = fromobj.paths[0].Segment(1)[2]
	
	# NOTE though: 'skpoint' object has only read-only attributes !! (cannot assign to .x)
	
	# retrieve end point - the center left (west) point of the box of to obj:
	#~ tmpep_end = toobj.bounding_rect.center()
	#~ tmpep_end.x = toobj.bounding_rect.left
	# there seems to be a 10 units padding for bounding_rect; (see below)
	# compensate it
	tobr = toobj.bounding_rect.grown(-10)
	tmpep_end = Point(tobr.left, tobr.center().y)
	
	# start drawing the line 

	tpath = CreatePath()
	
	tpath.AppendLine(tmpep_start) # moveto
	
	# are there any 'in-between' connection points ? 
	prevPoint = tmpep_start
	nextPoint = tmpep_start
	for ibcp in cplist:
		axiscommand = ibcp.keys()[0]
		moveval = ibcp[axiscommand]
		if axiscommand == '-': # along x
			#~ nextPoint.x = prevPoint.x + moveval
			nextPoint = Point(prevPoint.x + moveval, prevPoint.y)
		elif axiscommand == '|': # along y
			#~ nextPoint.y = prevPoint.y + moveval
			nextPoint = Point(prevPoint.x, prevPoint.y + moveval)
		tpath.AppendLine(nextPoint) # moveto
		prevPoint = nextPoint
	
	tpath.AppendLine(tmpep_end) # lineto
	
	tline = PolyBezier((tpath,))
	#~ tline.AddStyle(tbase_style) # of Graphics.properties (also in compound, document) - seems to add a 'layer' if dynamic; else seems to 'replace' ?!
	tline.SetProperties(line_width = 2.0, 
		line_pattern = connlineCol,
		line_arrow2 = tarrw2
	)
	tline.update_rects()

	return tline 
	


"""
Main code start. ................................................
"""
global doc, psfile
thisfilename = __file__

def sk2ps(filename, infilename, **psargs):
	global doc
	psfilename = infilename + ".ps"
	# convert the SK file FILENAME into a PostScript file PSFILENAME.
	# Any keyword arguments are passed to the PostScript device class.
	# we will not load doc - we will draw on doc directly here... 
	#~ doc = load.load_drawing(filename)
	bbox = doc.BoundingRect(visible = psargs.get('visible', 0),
							printable = psargs.get('printable', 1))
	psargs['bounding_box'] = tuple(bbox)
	psargs['document'] = doc
	ps = apply(PostScriptDevice, (psfilename,), psargs)
	doc.Draw(ps)
	ps.Close()
	
	# do pdf export, too 
	pdffilename = infilename + ".pdf"
	pdffile	= None
	if pdffile is None:
		pdffile = open(pdffilename, 'w')
	#~ module.save(document, file, filename, options)
	#~ save(document, file, filename, options = {}):
	# note: pdfgensaver:  self.pdf.setPageSize(document.PageSize())
	#~ print doc.PageSize() # (595.27559055118104, 841.88976377952747)
	# document.py: PageSize returns self.page_layout.Width(), - SetLayout for that 
	# load_SetLayout - direct without undo ; see drawinput.py
	# pagelayout.PageLayout -> import color, selinfo, pagelayout
	# default bbox sort of crops, so grow it
	# # pagelayout.orientation: Portrait = 0, Landscape = 1
	#~ pdfbbox = bbox.grown(20) # 20 seems OK here? 
	#~ # actually width = bbox.right (without -bbox.left) seems to have same effect as pdfbbox
	#~ pdfw = pdfbbox.right-pdfbbox.left
	#~ pdfh = pdfbbox.top-pdfbbox.bottom
	# note - orientation seems to want to be 0 (Portrait) - EVEN if the format is actually landscape (w>h)!! 
	pdfo = 0 # (portrait, w<h)
	#~ if pdfw > pdfh:
		#~ pdfo = 1
	# must set layout like this - else pdf will have incorrect size
	#  - also, the output pdf seems offset somewhat towards top-right
	#  - also, anything going in the -y part of the page will be truncated - so make sure 
	#    *manually* that all objects are placed in positive x/y parts of the page! 
	doc.SelectAll()
	doc.GroupSelected()
	mg = doc.CurrentObject() # master group 
	# center mg according to its bounding rect:
	# NVM, just set lower left corner manually 
	pad = 0 # since we move the group, which already seems to contain padding, this should remain 0 
	#~ mgbr = mg.bounding_rect
	#~ mgw = mgbr.right-mgbr.left
	#~ mgh = mgbr.top-mgbr.bottom
	mg.SetLowerLeftCorner(Point(pad, pad)) #move
	mg.update_rects()
	mgbr = mg.bounding_rect
	doc.load_SetLayout( pagelayout.PageLayout(width = mgbr.right+pad, height = mgbr.top+pad, orientation = pdfo) )
	
	pdfgensaver.save(doc, pdffile, pdffilename)
	pdffile.close()

def main():
	import Sketch
	global doc, psfile
	global tbase_style, courfont
	
	Sketch.init_lib()

	draw_printable = 1
	draw_visible = 0
	embed_fonts = 0
	eps_for = util.get_real_username()
	eps_date = util.current_date()
	eps_title = None
	rotate = 0


	doc = Document(create_layer = 1)
	
	## *****************************
	# start of drawing 
	
	# indicate start of coord system first: + goes upward / rightward
	trec = getQuickRect(5,5,-10,-10)
	doc.Insert(trec)
		
	# from create_text.py 
	textfld = SimpleText(Translation(0, 0), "24pt")
	textfld.SetProperties(font = courfont, font_size = 24)
	doc.Insert(textfld)
	
	## add struct box nodes
	
	structNodeA = getStructBoxnode(
		"struct1",	# title label
		("*pnt1", "*pointer2", "*point3"), 
		("var1", "variable2", "Varib3")
	)
	structNodeB = getStructBoxnode(
		"str2",		# title label
		("*pnt1", "*pnt2", "*pnt3", "*pnt4", "*pnt5", "*pnt6", ), 
		("var1", "var2", "var3", "var4", "var5", "var6", "var7", "var8", "var9" )
	)
	structNodeC = getStructBoxnode(
		"str3",		# title label
		("*pnt1", ), 
		()
	)
	snAgrp = structNodeA[0]
	snBgrp = structNodeB[0]
	snCgrp = structNodeC[0]
	
	## position nodes
	
	# place node A
	snAgrp.Translate(Point(100, 200))
	snAgrp.update_rects()
	
	# place node B - 'below left' of node A
	# (i.e. find lower right corner of A group; 
	#   align upper left corner of B with that)
	sabr = snAgrp.bounding_rect
	sbbr = snBgrp.bounding_rect
	xtran = sabr.right - sbbr.left
	ytran = sabr.bottom - sbbr.top
	snBgrp.Translate(Point(xtran, ytran))
	snBgrp.update_rects()
	sbbr = snBgrp.bounding_rect
	
	# place node C - below, left aligned to node B
	scbr = snCgrp.bounding_rect
	xtran = sbbr.left - scbr.left
	ytran = sbbr.bottom - scbr.top
	snCgrp.Translate(Point(xtran, ytran))
	snCgrp.update_rects()
	scbr = snCgrp.bounding_rect
	
	# show struct nodes on drawing
	doc.Insert(snAgrp)
	doc.Insert(snBgrp)
	doc.Insert(snCgrp)
	
	# display the bounding boxes of struct nodes
	trecA = getQuickRect(sabr.left,sabr.bottom,sabr.right-sabr.left,sabr.top-sabr.bottom)
	trecA.SetProperties( line_pattern = SolidPattern(StandardColors.red) )	
	trecB = getQuickRect(sbbr.left,sbbr.bottom,sbbr.right-sbbr.left,sbbr.top-sbbr.bottom)
	trecB.SetProperties( line_pattern = SolidPattern(StandardColors.red) )	
	trecC = getQuickRect(scbr.left,scbr.bottom,scbr.right-scbr.left,scbr.top-scbr.bottom)
	trecC.SetProperties( line_pattern = SolidPattern(StandardColors.red) )	
	doc.Insert(trecA)
	doc.Insert(trecB)
	doc.Insert(trecC)
	
	# make a connection
	# get dicts first
	snAdct = structNodeA[1]
	snBdct = structNodeB[1]
	snCdct = structNodeC[1]
	
	# put a rect around snBdct['box']
	# since grown(-10) aligns to box; shows that theres 10 units padding!
	tbr = snBdct['box'].bounding_rect.grown(-10)
	trecC = getQuickRect(tbr.left,tbr.bottom,tbr.right-tbr.left,tbr.top-tbr.bottom)
	trecC.SetProperties( line_pattern = SolidPattern(StandardColors.green) )	
	doc.Insert(trecC)
	
	# for easier calc after: 
	yjump = abs(snAdct['ptfl_1'].bounding_rect.center().y - snBdct['box'].bounding_rect.center().y) / 2
	
	# 'standard' connection: 
	# start from 2nd [1] pointer of structNodeA - end in 'input' (left) of box of structNodeB
	# so, from dict we need:: structNodeA:'ptfl_1'; and structNodeB:'box'
	tconnline = getStdConnLine(
		snAdct['ptfl_1'],	# from (startpoint - moveto)
		snBdct['box'],		# to (endpoint)
		# here optional arguments for 'in-between' points;
		# (ordered) tuple of dict, where key is command: 
		# like in tikz:: '|' means along y  ,  '-' means along x
		# (last {'-':-10}, is not needed - endpoint specifies it 
		({'-':30}, {'|':-yjump}, {'-':-40}, {'|':-yjump})
	)
	doc.Insert(tconnline)
	
	# for easier calc after - 
	# we won't use the "half-the-distance" directly, so we don't divide /2 here 
	yjumpAC = abs(snAdct['ptfl_2'].bounding_rect.center().y - snCdct['box'].bounding_rect.center().y) 
	
	tconnlineAC = getStdConnLine(
		snAdct['ptfl_2'],	# from (startpoint - moveto)
		snCdct['box'],		# to (endpoint)
		({'-':20}, {'|':-(yjump-30)}, {'-':-40}, {'|':-(yjumpAC-(yjump-30))})
	)
	doc.Insert(tconnlineAC)
	
	
	
	
	## *****************************
	# end of drawing - generate output file
	
	filename = '' # was .sk filename to convert
	sk2ps(filename, thisfilename, printable= draw_printable, visible = draw_visible,
		  For = eps_for, CreationDate = eps_date, Title = eps_title,
		  rotate = rotate, embed_fonts = embed_fonts)

	## *****************************
	# end of main()
	## *****************************


"""
Entry point. ................................................
"""
if __name__ == '__main__':
	result = main()

	if result:
		sys.exit(result)
		


