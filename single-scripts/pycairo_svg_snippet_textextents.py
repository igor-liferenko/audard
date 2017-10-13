#!/usr/env/bin python
"""
Graph using pycairo (io this case, py2cairo)
init start: copy from examples/cairo_snippets/snippets_svg.py
see also: Cairo Tutorial for Python Programmers - http://www.tortall.net/mu/wiki/CairoTutorial
"""

from __future__ import division
from math import pi as M_PI  # used by many snippets
import sys

import cairo
if not cairo.HAS_SVG_SURFACE:
	raise SystemExit ('cairo was not compiled with SVG support')

#~ from snippets import snip_list, snippet_normalize

global width_in_inches, height_in_inches, width_in_points, height_in_points, width, height

width_in_inches, height_in_inches = 2, 2
width_in_points, height_in_points = width_in_inches * 72, height_in_inches * 72
docwidth, docheight = width_in_points, height_in_points # used by snippet_normalize()

# function used by some or all snippets
def snippet_normalize (ctx, width, height):
    ctx.scale (width, height)
    ctx.set_line_width (0.04)


def main():
	global width_in_inches, height_in_inches, width_in_points, height_in_points, docwidth, docheight
	
	filename = 'minivosc_struct_layout.svg' 
	surface = cairo.SVGSurface (filename, width_in_points, height_in_points)
	cr = cairo.Context (surface)

	cr.save()
	#~ try:
		#~ execfile ('snippets/%s.py' % snippet, globals(), locals())
		
	#~ except:
		#~ exc_type, exc_value = sys.exc_info()[:2]
		#~ print >> sys.stderr, exc_type, exc_value
	#~ else:
	
	utf8 = "cairo"

	snippet_normalize (cr, docwidth, docheight)

	cr.select_font_face ("Sans",
						 cairo.FONT_SLANT_NORMAL,
						 cairo.FONT_WEIGHT_NORMAL)

	cr.set_font_size (0.4)
	x_bearing, y_bearing, docwidth, docheight, x_advance, y_advance = cr.text_extents (utf8)

	x=0.1
	y=0.6

	cr.move_to (x,y)
	cr.show_text (utf8)

	#/* draw helping lines */
	cr.set_source_rgba (1,0.2,0.2,0.6)
	cr.arc (x, y, 0.05, 0, 2*M_PI)
	cr.fill ()
	cr.move_to (x,y)
	cr.rel_line_to (0, -docheight)
	cr.rel_line_to (docwidth, 0)
	cr.rel_line_to (x_bearing, -y_bearing)
	cr.stroke ()

	cr.restore()
	cr.show_page()
	surface.finish()


if __name__ == '__main__': 
	main()