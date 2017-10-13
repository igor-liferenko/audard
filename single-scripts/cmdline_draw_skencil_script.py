#!/usr/env/bin python
# -*- coding: iso-8859-1 -*-
# started from sk2ps.py
"""
cmdline_draw_skencil_script.py
sdaau 2010

This script is a demonstration of coded (scripted), command line
vector drawing - using Python with the Skencil API.

It shows a concept akin to `tikz` in `LaTeX`, similar in the sense
that:

* (there) - you code your image in a `tikz` script, and then use
`tikz2pdf` to generate a `.pdf` vector output
* (here)  - you code your image in a Python script, and then use
`python` to generate a  `.ps` vector output
* ... an in both cases, you can:
** use the command line exclusively to build your output vector
file, without ever starting a GUI
** have `evince` open your output file, and then automatically
update the display whenever a new output has been generated

... and is different from `tikz`, in the sense that 'class'
thinking, as well as coordinate calculation in context of groups,
may be slightly easier to code in Python (as opposed to LaTeX
macros).


REQUIREMENTS

This script was developed against the 'resurrected' Skencil 1.0alpha
(python-skencil-1.0alpha-rev784_0ubuntu1_10.04_i386.deb), from:

sK1 Project - Skencil - http://sk1project.org/viewpage.php?page_id=21

By installing the deb, the respective Python classes will be
installed in your system (in mine, under
/usr/lib/python2.6/dist-packages/skencil). With that kind of
install, all of the Skencil classes - which are used here - are
available to any python script (possibly with a few gotchas in
respect to paths, look below for 'sys.path.append' and
'config.font_path.append')


USAGE

Simply call Python with this script as argument:

$ python cmdline_draw_skencil_script.py

... and after it is finished, a file 'vectorout.ps' will be
generated in the same directory (note, the Skencil GUI will not be
started at all).

This script simply draws some styled text, lines with arrow
heads/tails, and rectangles - trying to use render time information
(like width of bounding boxes of text fields) to reposition elements
in the figure.


LICENSE:

Same as Skencil and/or Python :)


NOTES

I almost found it surprising that it was possible to find Skencil in
this way - as there is *no* other example I could find on the net
for script based drawing!! (apart from mentions on forums that it
"could" be used in that sense).

The things complicate, as the official documentation:

http://projects.gnome.org/dia/pydia.html
http://www.skencil.org/Doc/devguide.html

is also quite scanty about this kind of use; so this script was put
together by browsing through the source code (and included examples)
of Skencil. As it is not necesarilly trivial to go through all of
that, comments have been left in this file - and some Python
interactive session excerpts have been included at the end of this
file.

FONTS (added 2012):

for some reason, embed_fonts is ignored; and the fonts are NOT embedded in the .pdf,
 and the .ps fails evince with:
  GPL Ghostscript 9.02: Error: Font Renderer Plugin ( FreeType ) return code = -1

based on:
http://zeppethefake.blogspot.com/2008/05/embedding-fonts-in-pdf-with-ghostscript.html

can do:

  gs -dSAFER -dNOPLATFONTS -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sPAPERSIZE=letter -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer -dCompatibilityLevel=1.4 -dMaxSubsetPct=100 -dSubsetFonts=true -dEmbedAllFonts=true -sOutputFile=cdraw-new.py.pdf -f cdraw.py.pdf

(see below for diff)

"""

import sys, os

# modded for 1.0alpha installed on ubuntu:
import skencil
from skencil import * # so no need for skencil.Sketch
# .. well, here too (with it here, warn.py needs not be changed):
sys.path.append("/usr/lib/python2.6/dist-packages/skencil")

#~ from Sketch import load, PostScriptDevice
from Sketch.Lib import util

# imports from mainwindow.py:
#~ from Sketch.Lib import util
from Sketch.warn import warn, warn_tb, INTERNAL, USER
from Sketch import _, config, load, plugins, SketchVersion
from Sketch import Publisher, Point, EmptyFillStyle, EmptyLineStyle, \
	 EmptyPattern, Document, GuideLine, PostScriptDevice, SketchError
import Sketch
from Sketch.Graphics import image, eps
#~ import Sketch.Scripting

from Sketch.const import DOCUMENT, CLIPBOARD, CLOSED, COLOR1, COLOR2
from Sketch.const import STATE, VIEW, MODE, SELECTION, POSITION, UNDO, EDITED,\
	 CURRENTINFO

# imports from create_text.py
from Sketch import SimpleText, Translation, SolidPattern, StandardColors, \
	 GetFont

# imports from svgloader.py
#~ from string import join, replace
#~ import re
from math import atan2, hypot, pi
from Sketch import const, Bezier, EmptyPattern, Trafo, Rotation #, Translation

# from font.py
#~ from Sketch import _
from Sketch import config

# from skloader.py:
from Sketch import Style, Arrow
# define arrows manually:
# #self.style.line_arrow1 = Arrow(path, 1) # <- from drawinput.py
#~ arpath1 = [(0, 3), (0, -3)] # like this it's like the thinnest line ever
# but thin line only when closed=1 - when closed=0, inherits default width
# so do a rectangle (to account for thicker line_width) - for Arrow(arpath1, 1)
#~ arpath1 = [(0, 3), (0, -3), (-1, -3), (-1, 3)]  # unused, as example
arpath2 = [(-4, 3),(2, 0), (-4, -3)] # (same values as default arrow)
from Sketch import Ellipse # circles
elp = Ellipse(start_angle = 0.0, end_angle = 2*pi)
# from EllipseCreator: Trafo(radius, 0, 0, radius, start.x, start.y)
elp_radius = 2.5
elp_startx = 0
elp_starty = 0
elp.trafo = Trafo(elp_radius, 0, 0, elp_radius, elp_startx, elp_starty)
elpbz = elp.AsBezier()
elpbz_nl = elpbz.Paths()[0].NodeList() # as list of Point(x,y)
elpbz_tnl = [] # as list of tuples (x,y)
for tpnt in elpbz_nl:
	elpbz_tnl.append( (tpnt.x, tpnt.y) )
tarrw1 = Arrow(elpbz_tnl, closed=1) #_nl or _tnl - all the same here; ellipse sends four points, which in Arrow are AppendBezier (AppendLine only for two points -- but still it looks like a diamond.. )..
# the difference is in tarrw1.Paths()[0].arc_lengths() vs elpbz.Paths()[0].arc_lengths()
tarrw1.path = elpbz.Paths()[0] # and this FINALLY makes the arrow a circle!
tarrw2 = Arrow(arpath2, closed=1)

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

# from create_spiral.py
from Sketch import CreatePath

# from footprints.py
from Sketch import Group

# additonal
# avoid font glyph problems on AsBezier
config.font_path.append('/var/lib/defoma/gs.d/dirs/fonts')
from Sketch import Graphics
from Sketch import Point, PolyBezier # to draw a line
from Sketch import Rectangle # box
from Sketch import CreateRGBColor # function


global doc

# helper - for easier generating of a line from two points
def getQuickLine(tstart, tend):
	# expected tuple at input

	pstart = Point(tstart[0], tstart[1])
	pend = Point(tend[0], tend[1])
	tpath = CreatePath()

	# Note - apparently, the first appended point is "moveTo";
	# .. the ubsequent ones being "LineTo"
	tpath.AppendLine(pstart) # moveto
	tpath.AppendLine(pend) # lineto

	tline = PolyBezier((tpath,))
	tline.AddStyle(tbase_style) # of Graphics.properties (also in compound, document) - seems to add a 'layer' if dynamic; else seems to 'replace' ?!
	tline.SetProperties(line_pattern = SolidPattern(CreateRGBColor(0.7, 0.7, 0.9)))
	return tline


def sk2ps(filename, psfilename, **psargs):
	global doc
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

def main():
	import Sketch
	global doc
	global tbase_style

	Sketch.init_lib()

	draw_printable = 1
	draw_visible = 0
	embed_fonts = 0
	eps_for = util.get_real_username()
	eps_date = util.current_date()
	eps_title = None
	rotate = 0


	#doc = load.load_drawing('')
	# from mainwindow.py: self.SetDocument(Document(create_layer = 1))
	doc = Document(create_layer = 1)

	# get font info first
	Graphics.font.read_font_dirs()

	# indicate start of coord system first
	# coord system:: + goes upward / rightward
	# from RectangleCreator: trafo = Trafo(off.x, 0, 0, off.y, end.x, end.y)
	# actually, there 'end' seems to correspond to start (llc: lower left corner of rectangle) - and 'off' to the length extended in each direction (i.e. width, height - but can be negative) ; so instead of 'end' - calling it 'start'
	start_x = 5
	start_y = 5
	off_x = -10
	off_y = -10
	trec = Rectangle(trafo = Trafo(off_x, 0, 0, off_y, start_x, start_y))
	trec.update_rects()
	doc.Insert(trec)


	# from create_text.py
	textfld = SimpleText(Translation(50, 50), "xyzzy")
	textfld.SetProperties(fill_pattern = SolidPattern(StandardColors.green),
					   font = GetFont('Courier-Bold'),#('Times-Bold'),
					   font_size = 36)

	#copy textfld
	textfld2 = textfld.Duplicate()
	textfld2.SetProperties(fill_pattern = SolidPattern(StandardColors.blue)) # change color only

	# rotate textfld
	angleDeg = 45
	angleRad = pi*(angleDeg/180.0) # ensure float op - could use math.radians instead
	textfld.Transform(Rotation(angleRad)) # Rotation(angle, center)
	textfld.update_rects() # probably a good idea

	# change textfld's text with the current width (that we see)
	# get bounding box of text
	a = textfld.properties
	llx, lly, urx, ury = a.font.TextBoundingBox(textfld.text, a.font_size)
	# calculate width - its of UNTRANSFORMED text
	twidth = urx - llx
	# insert this width as text in textbox now:
	#~ textfld.text = str(twidth)
	#~ textfld.update_rects() # probably a good idea - again

	# get textfield as bezier
	textbez = textfld.AsBezier()
	#~ print textbez # returns Sketch.Graphics.group.Group; subclass of EditableCompound
	# the bounding rectangle - from Compound (type is Rect):
	textbez_bRect = textbez.bounding_rect
	# calc width now
	t2width = textbez_bRect.right - textbez_bRect.left
	# insert this width as text in textbox now:
	textfld.text = str(t2width)
	textfld.update_rects() # probably a good idea - again

	#~ doc.Insert(textfld)

	# create a line
	# using create_spiral.py technique below (see syntax note #(A1))
	tpath = CreatePath()

	# Note - apparently, the first appended point is "moveTo";
	# .. the ubsequent ones being "LineTo"
	tp = Point(textbez_bRect.left,textbez_bRect.bottom)
	tpath.AppendLine(tp) # moveto

	tp = Point(textbez_bRect.left,textbez_bRect.top)
	tpath.AppendLine(tp) # lineto
	tp = Point(textbez_bRect.right,textbez_bRect.top)
	tpath.AppendLine(tp) # lineto
	tp = Point(textbez_bRect.right,textbez_bRect.bottom)
	tpath.AppendLine(tp) # lineto

	tline = PolyBezier((tpath,))
	tline.AddStyle(tbase_style) # of Graphics.properties (also in compound, document) - seems to add a 'layer' if dynamic; else seems to 'replace' ?!

	#~ doc.Insert(tline)

	# group tline and textfld ...
	# footprints.py has Group(foot_prints = [])
	tgrp = Group([textfld, textfld2, tline])
	tgrp.update_rects()
	doc.Insert(tgrp)

	# add a box.. around textfld2
	# use radius1, radius2 !=  0 AND 1 (logarithmic) to get RoundedRectangle (best between 0.0 and 1.0)
	tfbr = textfld2.bounding_rect
	start_x = tfbr.left
	start_y = tfbr.bottom
	off_x = tfbr.right - tfbr.left
	off_y = tfbr.top - tfbr.bottom
	twid = abs(off_x - start_x)
	thei = abs(off_y - start_y)
	radfact = 1.2*twid/thei
	tradius = 0.05 # if we want to specify a single one, then the actual look will depend on the dimesions of the rectangle - so must 'smooth' it with radfact...
	trec = Rectangle(trafo = Trafo(off_x, 0, 0, off_y, start_x, start_y), radius1 = tradius, radius2 = tradius*radfact)
	trec.update_rects()
	doc.Insert(trec)

	# add another box - any where
	start_x = 100.0
	start_y = 100.0
	off_x = 50.0
	off_y = 50.0
	trec2 = Rectangle(trafo = Trafo(off_x, 0, 0, off_y, start_x, start_y))
	trec2.update_rects()
	doc.Insert(trec2)

	# try change props post insert - OK
	trec2.SetProperties(fill_pattern = SolidPattern(StandardColors.yellow), line_width = 2.0, line_pattern = SolidPattern(CreateRGBColor(0.5, 0.5, 0.7)))

	# try move the group as a whole (Translate - syntax: spread.py)
	# say, align the right edge of tline to left edge of trec2 (x direction)
	# NOTE: group does not define own .AsBezier(self);
	# but it has tgrp.bounding_rect (although python doesn't show it in dir(tgrp))
	# also there is Rectangle.bounding_rect
	# NOTE though - it seems bounding_rect is somehow padded, with (at least) 10 units in each direction! (also, bounding rect of line will include the arrow)
	xmove = (trec2.bounding_rect.left+10)-(tline.bounding_rect.right-10)
	#~ print xmove, trec2.bounding_rect.left, tline.bounding_rect.right
	tgrp.Translate(Point(xmove, 0))
	tgrp.update_rects()

	# add temporary line to indicate bounding boxes
	# and effect of padding (may cover the very first trec)
	tmpbr = trec2.bounding_rect
	doc.Insert(
		getQuickLine(
			(0,0),
			(trec2.bounding_rect.left+10, tline.bounding_rect.top-10)
		)
	)

	# end of draw  - generate output file
	filename = ''
	psfile = 'vectorout.ps'
	sk2ps(filename, psfile, printable= draw_printable, visible = draw_visible,
		  For = eps_for, CreationDate = eps_date, Title = eps_title,
		  rotate = rotate, embed_fonts = embed_fonts)

if __name__ == '__main__':
	result = main()

	if result:
		sys.exit(result)




"""

wrong syntax note #(A1)

	# note - if we make it go along textbez_bRect - it will show the 'original' rotated textfld (before the change of text content)!

	#~ tline_pointlist = (
		#~ Point(textbez_bRect.left,textbez_bRect.bottom),
		#~ Point(textbez_bRect.right,textbez_bRect.top)
	#~ )
	#~ tline = PolyBezier(tline_pointlist, tbase_style) # causes AttributeError: accurate_rect on insert..
	# SO - using create_spiral.py technique instead


Notes and command log


NOTE: only graphic objects having a .name or an .id property in Skencil are layers!
./Sketch/Graphics/layer.py:     self.name = name
---
http://www.skencil.org/Doc/devguide-7.html
"A transformation object, a trafo object or trafo for short, represents an affine 2D transformation."
./Sketch/Graphics/plugobj.py:class TrafoPlugin
print inspect.getsource(Rotation):
	TypeError('arg is not a module, class, method, ')
	object has no attribute 'rfind'
	True only on: inspect.isbuiltin(Rotation), inspect.isroutine(Rotation)
	fail: inspect.getfile(Rotation), inspect.getsource(Rotation) - rest is None
because in usr/lib/skencil/Sketch/__init__.py:
	'from _sketch import Trafo, Scale, Translation, Rotation...'
and: .. skencil$ find . -name '_sk*'
	./Sketch/Modules/_sketchmodule.so
---
NOTE: Currently, Skencil supports only Type 1 fonts. - see http://www.skencil.org/faq.html#FAQ4.3
see /usr/lib/python2.6/dist-packages/skencil/Sketch/Base/config.py for setting default config.font_path... default is:
font_path = ['/usr/X11R6/lib/X11/fonts/Type1',
	     '/usr/share/ghostscript/fonts',
	     '/usr/lib/ghostscript/fonts']
... none of these to be found on Lucid ??! use
	fc-list -v | less
	fc-list -v | grep --color=always 'file\|Type 1' | less -R
	sed -n 's/\(.*\)pfb\(.*\)/\1.pfb/p' /var/lib/defoma/type1.font-cache
	find / -name '*[Tt]ype1*' 2>/dev/null
to find Type1 installed font locations:
/usr/share/fonts/X11/Type1/
/usr/share/fonts/type1/gsfonts/
/usr/share/fonts/type1/mathml/
texlive/texmf-local/fonts/type1 # can be empty
texlive/2009/texmf-dist/fonts/type1 # has subdirs
texlive/2009/texmf-dist/fonts/type1/adobe/courier/
texlive/2009/texmf-dist/fonts/type1/hoekwater/mflogo/logo
texlive/2009/texmf-dist/fonts/type1/public/ # has subdirs
texlive/2009/texmf-dist/fonts/type1/urw/ # has subdirs
texlive/2009/texmf-dist/fonts/type1/vntex/ # has subdirs
# /etc/X11/fonts/Type1 # aliases
/var/lib/defoma/gs.d/dirs/fonts
... though changing font_path directly in config.py doesn't really help.. best to append from script?!
Also - possibly need to append to fontmetric_dir? no: config.font_path.append(config.fontmetric_dir)

./Sketch/Graphics/font.py:def GetFont
from Sketch import Graphics
Graphics.font.read_font_dirs() # to rebuild in console?!
print Graphics.font.fontlist
::: i.e. getting ('NimbusMonL-Regu', 'Nimbus Mono L', 'Regular',
... - though: I cannot find the metrics for the font NimbusMonL-Regu. The file n022003l.afm is not in the font_path.
.. and then can do 'text = SimpleText(' in python terminal..
.. also, open skencil, place text, right-click to see a list of fonts - but note, 1.0alpha seems to have a bug when entering text.
---
>>> text.properties.font.TextBoundingBox(text.text, text.properties.font_size)
(0.0, -2.6160000000000001, 28.356000000000002, 5.4000000000000004)
--
# to get rid of "Cannot find file for font Courier-Bold"; during AsBezier
# find / -xdev -iname '*courier*' 2>/dev/null
note: font looking in def font_file_name:
config.font_path =
['/usr/lib/python2.6/dist-packages/skencil/Sketch/../Resources/Fontmetrics']
Courier-Bold
['courb.pfb', 'courb.pfa', 'n022004l.pfb', 'n022004l.pfa', 'pcrb.pfb', 'pcrb.pfa', 'courb.pfb', 'courb.pfa', 'n022004l.pfb', 'n022004l.pfa', 'pcrb.pfb', 'pcrb.pfa']
... but I don't have these - only afm!
... ops, yes: /var/lib/defoma/gs.d/dirs/fonts/n022004l.pfb
nowork:
sys.path.append("/var/lib/defoma/gs.d/dirs/fonts")
so use (from Sketch import config):
config.font_path.append('/var/lib/defoma/gs.d/dirs/fonts')
---
Note: to load *sk files and analyze them in the python command line interpreter, do:
>>> from Sketch import plugins
>>> plugins.load_plugin_configuration()
>>> doc1 = load.load_drawing('testline.sk')
>>> #print doc1 - (Sketch.Graphics.document.EditDocument)

>>> doc1.SelectAll()
>>> print doc1.CurrentObject()
<Sketch.Graphics.bezier.PolyBezier instance at 0x9f4e4ec>
>>> doc1.SelectNone()
>>> print doc1.CurrentObject()
None
>>> doc1.SelectFirstChild()
>>> print doc1.CurrentObject()
None
>>> doc1.SelectNextObject()
>>> print doc1.CurrentObject()
<Sketch.Graphics.bezier.PolyBezier instance at 0x9f4e4ec>
>>> pbz = doc1.CurrentObject()
>>> print pbz.paths
(<SKCurveObject at 165844392 with 7 nodes>,) # only in Binary file ./Sketch/Modules/_sketchmodule.so matches; note, a single object in a tuple here!
>>> curvo=pbz.paths[0]
### also - pbz.Paths()[0].NodeList()
>>> curvo.NodeList()
[Point(83.0727, 276.565), Point(83.0727, 274.559), Point(203.39, 400.892), Point(275.58, 304.639), Point(357.796, 398.887), Point(421.965, 376.829), Point(421.965, 374.823)]

SKCurveObject: http://www.sfr-fresh.com/unix/misc/sk1-0.9.1pre2_rev1383.tar.gz:a/sk1-0.9.1pre2/src/extensions/skmod/curveobject.h
   79 int SKCurve_AppendLine(SKCurveObject * self, double x, double y,
   80 		       int continuity);
..but: 'NameError: name 'SKCurveObject' is not defined', so create PolyBezier first..  def PolyBezier(self, Paths, Properties):..

# style is in pbz.properties:
>>> print pbz.properties.line_arrow1
<Sketch.Graphics.arrow.Arrow instance at 0x9f4e44c>
>>> print pbz.properties.line_arrow2
<Sketch.Graphics.arrow.Arrow instance at 0x9f4e3cc>
>>> print pbz.properties.line_arrow2.path
<SKCurveObject at 165844632 with 4 nodes>
>>> print pbz.properties.line_arrow2.path.NodeList()
[Point(-4, 3), Point(2, 0), Point(-4, -3)]

## ALSO NOTE:
## if transforming AND using variable for .bounding_rect
##    (i.e. `brect = grp.bounding_rect`);
## you must BOTH:
## * call .update_rects() first
## * then REASSIGN the variable AGAIN after that (i.e. call `brect = grp.bounding_rect` again)
## for instance:
>>> textfld = SimpleText(Translation(0, 0), "aaa")
>>> point_group = Group([textfld])
>>> point_group.update_rects()
>>> pgbr = point_group.bounding_rect
>>> print pgbr
Rect(-2, -2,119999886, 17,95999908, 7,519999981)
>>>
>>> point_group.Transform(Rotation(radians(-90), pgbr.center()))
(<function UndoList at 0xb7416f7c>, [(<bound method ......)
>>> print pgbr
Rect(-2, -2,119999886, 17,95999908, 7,519999981)
>>> point_group.update_rects()
>>> print pgbr
Rect(-2, -2,119999886, 17,95999908, 7,519999981)
>>> pgbr = point_group.bounding_rect
>>> print pgbr
Rect(3,159999371, -7,280000687, 12,79999924, 12,67999935)
>>>


## ALSO NOTE
## To change nodes in curve: path.SetBezier or path.SetLine
## Developer's Guide: Curve Objects - http://www.skencil.org/Doc/devguide-8.html#N12
## * (see also PolyBezierEditor:ButtonUp)
## SetLine(i, x, y[, cont]) "Replace the ith segment by a line segment"
>>> tline.paths[0].Segment(0)
(2, (), Point(0, 0), 0)
>>> tline.paths[0].Segment(1)
(2, (), Point(1, 0), 0)
>>> tline.paths[0].Segment(2)
IndexError: path.Segment: index out of range
>>> tline.paths[0].len # "The number of segments."
2
>>> tline.paths[0].SetLine(1, (3,5)) # "Replace the ith segment by a line segment"
>>> tline.paths[0].Segment(1)
(2, (), Point(3, 5), 0)
>>> tline.paths[0].NodeList()
[Point(0, 0), Point(3, 5)]


## note fonts:

difference in fonts:

$ pdffonts cdraw.py.pdf
name                                 type              emb sub uni object ID
------------------------------------ ----------------- --- --- --- ---------
Helvetica                            Type 1            no  no  no       2  0
Courier-Bold                         Type 1            no  no  no       3  0
Times-Roman                          Type 1            no  no  no       4  0

$ pdffonts cdraw-new.py.pdf
name                                 type              emb sub uni object ID
------------------------------------ ----------------- --- --- --- ---------
RKBEOV+Courier-Bold                  Type 1C           yes yes no      10  0
EBRWWP+Times-Roman                   Type 1C           yes yes no      12  0

-rw-r--r-- 1 ME ME  17725 2012-02-21 08:17 cdraw-new.py.pdf
-rw-r--r-- 1 ME ME   7079 2011-05-16 01:11 cdraw.py.pdf


"""

