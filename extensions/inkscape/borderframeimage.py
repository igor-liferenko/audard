#!/usr/bin/env python
'''
borderframeimage.py
Copyleft sdaau 2011
By selecting an image and applying this effect,
 a rectangle frame and its clone are generated;
 the clone used as an image clipping path;
 and all are grouped.
 The frame border is exagerated (8 pts);
 change afterward manually.
 Note, "selected only" option should be always selected.
Based on embedimage.py and
 http://thepinksylphide.com/2008/11/22/inkscape-web-comic-tutorial-bordering-an-image
 [solved]Image into rounded frame - http://www.inkscapeforum.com/viewtopic.php?f=5&t=1738
 (check code comments for other references)

Copyright (C) 2005,2007 Aaron Spike, aaron@ekips.org

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
'''

import inkex, os, base64, urlparse, urllib
import simplestyle
import gettext
_ = gettext.gettext

class BorderFrameImager(inkex.Effect):
    def __init__(self):
        inkex.Effect.__init__(self)
        self.OptionParser.add_option("-s", "--selectedonly",
            action="store", type="inkbool",
            dest="selectedonly", default=False,
            help="border frame only selected images")

    # http://wiki.inkscape.org/wiki/index.php/Generating_objects_from_extensions
    #SVG element generation routine
    def draw_SVG_square(self, (w,h), (x,y), inid, parent):
        style = {   'stroke'        : '#000000',
                    'width'         : '1',
                    'stroke-width'  : '8',
                    'fill'          : 'none'
                }

        attribs = {
            'style'     : simplestyle.formatStyle(style),
            'id'    : str(inid),
            'height'    : str(h),
            'width'     : str(w),
            'x'         : str(x),
            'y'         : str(y)
                }
        return inkex.etree.SubElement(parent, inkex.addNS('rect','svg'), attribs )

    def draw_Clone(self, (w,h), (x,y), inid, intr, inxlh, parent):
        x_href = inkex.addNS('href', 'xlink')
        #~ clone.attrib[a_href]='#original'
        attribs = {
            'id'    : str(inid),
            'height'    : str(h),
            'width'     : str(w),
            'x'         : str(x),
            'y'         : str(y),
            'transform'    : str(intr),
            #~ 'xlink:href'    : str(inxlh)
            x_href         : str(inxlh)
        }
        clnode = inkex.etree.SubElement(parent, inkex.addNS('use','svg'), attribs )

        #~ xlink = node.get(inkex.addNS('href','xlink'))
        return clnode

    def effect(self):
        # if slectedonly is enabled and there is a selection only embed selected
        # images. otherwise embed all images
        if (self.options.selectedonly):
            self.borderFrameSelected(self.document, self.selected)
        #~ else:
            #~ self.embedAll(self.document)

    def borderFrameSelected(self, document, selected):
        self.document=document
        self.selected=selected
        if (self.options.ids):
            for id, node in selected.iteritems():
                if node.tag == inkex.addNS('image','svg'):
                    self.borderFrameImage(node)

    def embedAll(self, document):
        self.document=document #not that nice... oh well
        path = '//svg:image'
        for node in self.document.getroot().xpath(path, namespaces=inkex.NSS):
            self.borderFrameImage(node)

    def borderFrameImage(self, node):
        xlink = node.get(inkex.addNS('href','xlink'))
        defs = self.document.getroot().xpath('//svg:defs', namespaces=inkex.NSS)
        if defs:
            defs = defs[0]
            # this gets image size in pixels; same as intern inkscape units
            imw = node.get('width')
            imh = node.get('height')
            imx = node.get('x')
            imy = node.get('y')
            imid = node.get('id')

            # "Finding the parent is easy: you can just pass in the current layer from the self object if you like:"
            parent = self.current_layer

            # create frame rectangle
            fid = "frame_"+imid
            fbox = self.draw_SVG_square((imw,imh), (imx,imy), fid, parent)
            # clone frame rectangle
            # cloning is simply an SVG node, with xlink:href pointing to #fid,
            # and a transform - translate(0,0) node
            fclid = "clone_"+fid
            fboxcl = self.draw_Clone((imw,imh), (0,0), fclid, "translate(0,0)", "#"+fid, parent)

            # use the clone as clipping mask for image
            # http://nullege.com/codes/search/inkex.etree.SubElement.set
            # first must add a svg:clipPath to defs; which will contain
            #  a child node: link to the clone (fboxcl with fclid)
            # this should somehow remove the reference to the clone in the layer (will be only in defs as child here);
            clip = inkex.etree.SubElement(defs,inkex.addNS('clipPath','svg'))
            clip.append(fboxcl)
            clipId = "clip_" + fclid
            clip.set('id', clipId)

            # add clip-path attribute to image
            node.set('clip-path', 'url(#'+clipId+')')

            # finally, group the clipped image and the (orig) frame box
            g = inkex.etree.SubElement(parent,inkex.addNS('g','svg'))
            g.set('id', "groupFrame_"+imid)
            g.append(node)
            g.append(fbox)

            #~ inkex.errormsg(_("%s is not of type image/png, image/jpeg, image/bmp, image/gif, image/tiff, or image/x-icon") % path)
            #
            # see also:
            # http://nullege.com/codes/show/src%40i%40n%40inkscape-HEAD%40inkscape%40trunk%40share%40extensions%40edge3d.py/123/inkex.etree.SubElement.set/python
            # scaling text with extensions - Topic - InkscapeForum.com - http://www.inkscapeforum.com/viewtopic.php?f=16&t=8879
            # How to add border/stroke to image? - Topic - InkscapeForum.com - http://www.inkscapeforum.com/viewtopic.php?f=5&t=638


if __name__ == '__main__':
    e = BorderFrameImager()
    e.affect()


# vim: expandtab shiftwidth=4 tabstop=8 softtabstop=4 encoding=utf-8 textwidth=99
