#!/usr/bin/env python
################################################################################
# csv-pygtk.py                                                                 #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# Tue Jun 24 07:19:15 CEST 2014 ; Python 2.7.1+

# to run:
# cat ./test.csv | python csv-pygtk.py -

# https://github.com/FiloSottile/Griffith-mirror/blob/master/lib/plugins/imp/CSV.py
# http://stackoverflow.com/questions/1447187/embed-a-spreadsheet-table-in-a-pygtk-application
# http://islascruz.org/html/index.php/blog/show/Wrap-text-in-a-TreeView-column.html
# [http://faq.pygtk.org/index.py?req=show&file=faq13.031.htp PyGTK FAQ Entry - How do I change the color of a row or column of a TreeView?]
# http://heim.ifi.uio.no/bjarneh/source/checklist/code/checklist.html

import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

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

import linecache
import re
import pprint # for debugging
import collections # OrderedDict, 2.7+
import csv
import copy

if sys.version_info[0] < 3:
  #printso("sys.version < 3\n")
  from urlparse import urlparse
  from urllib import urlopen
  from StringIO import StringIO
else:
  #printso("sys.version >= 3\n")
  from urllib.request import urlopen
  from urllib.parse import urlparse
  from io import StringIO

def openAnything(source):
  """URI, filename, or string --> stream
  based on http://diveintopython.org/xml_processing/index.html#kgp.divein
  This function lets you define parsers that take any input source
  (URL, pathname to local or network file, or actual data as a string)
  and deal with it in a uniform manner.  Returned object is guaranteed
  to have all the basic stdio read methods (read, readline, readlines).
  Just .close() the object when you're done with it.

  test:
  a=openAnything("http://www.yahoo.com"); printso( inputSrcType, a, a.readline() )
  a=openAnything("here a string"); printso( inputSrcType, a, a.readline() )
  a=openAnything("notes.txt"); printso( inputSrcType, a, a.readline() )

  python2.7:
  2 <addinfourl at 151249676 whose fp = <socket._fileobject object at 0x902e96c>> <!DOCTYPE html>
  4 <StringIO.StringIO instance at 0x904a6ac> here a string
  3 <open file 'notes.txt', mode 'r' at 0x8fd0f40> There is this:

  python3.2:
  2 <http.client.HTTPResponse object at 0xb727322c> b'<!DOCTYPE html>\n'
  4 <_io.StringIO object at 0xb7268e6c> here a string
  3 <_io.TextIOWrapper name='notes.txt' mode='r' encoding='UTF-8'> There is this:
  """
  global inputSrcType

  if hasattr(source, "read"):
    inputSrcType = 0
    return source

  if source == '-':
    inputSrcType = 1
    return sys.stdin

  # try to open with native open function (if source is pathname)
  # moving this up because of py2 (urlopen catches local files there)
  # but keeping inputSrcType = 3
  try:
    inputSrcType = 3
    return open(source)
  except (IOError, OSError):
    pass

  # try to open with urllib (if source is http, ftp, or file URL)
  #~ import urllib
  try:
    inputSrcType = 2
    return urlopen(source)
  except (IOError, OSError, ValueError): # ValueError for py3
    pass

  # treat source as string
  #~ import StringIO
  inputSrcType = 4
  return StringIO(str(source))

import pygtk
pygtk.require('2.0')
import gtk

class CsvPygtkTreeViewColumn(object):

  # close the window and quit
  def delete_event(self, widget, event, data=None):
    gtk.main_quit()
    return False

  def key_press_event(self, widget, event, data=None):
    #print(widget, event, event.keyval)
    # keyval=q>, 113)
    # keyval=w>, 119)
    # keyval=Escape>, 65307)
    if (event.keyval == 113) or (event.keyval == 119) or (event.keyval == 65307):
        gtk.main_quit()
    elif (event.keyval == 32): # keyval=space>, 32); note, also selects a row in table!
      self.toggleColumnWidthHandling()
    return False

  def toggleColumnWidthHandling(self):
    print("toggleColumnWidthHandling, changing to {0}".format(not(self.is_resize_wrap)))
    if not(self.is_resize_wrap):
      self.sizaEvConnId = self.scroll.connect_after('size-allocate', self.resize_wrap)#, self.treeview, self.columns, render)
      #self.treeview.set_size_request(0,-1)
      self.resize_wrap(self.scroll, self.window.get_allocation())
      self.is_resize_wrap = True
    else:
      self.scroll.disconnect(self.sizaEvConnId)
      self.resize_nowrap()
      self.is_resize_wrap = False

  def resize_nowrap(self):
    #if not(self.handling_nowrap):
      #self.handling_nowrap = True
      newWidth = 300 # per column
      # this handles width of text wrap inside the column cell
      for cell in self.cells:
        # if cell.props.wrap_width == newWidth or newWidth <= 0:
          # continue #return
        #cell.set_fixed_height_from_font(1) # naah; arg is number of rows
        ## cell.props.width_chars = -1
        ## cell.props.wrap_width = -1 #newWidth
        #cell.props = self.cellinitprops # nope
        for ia in self.cellinitprops: # SEEMS TO RESTORE stretch column to text width!
          pspec = ia[0]; prop = ia[1]
          #print(str(pspec), prop)
          try:
            cell.set_property(pspec.name, prop) #; print("ok1")
          except:
            pass
      # this handles width of column
      for ix, tvcolumn in enumerate(self.columns):
        #tvcolumn.set_property('sizing', gtk.TREE_VIEW_COLUMN_AUTOSIZE)
        #tvcolumn.set_expand(True)
        #tvcolumn.set_property('resizable', True)
        #~ tvcolumn.set_property('min-width', newWidth + 5) #
        #~ tvcolumn.set_property('max-width', -1) #newWidth + 10)
        #tvcolumn.props = self.tvcolinitprops # nope
        for ia in self.tvcolinitprops: # SEEMS TO RESTORE stretch column to text width!
          pspec = ia[0]; prop = ia[1]
          try:
            tvcolumn.set_property(pspec.name, prop) #; print("ok2")
          except:
            pass
      # didn't need any of this below; just had a bad loop (for ix in cells: cell.do(..))!
      for cell in self.cells:
        cell.set_property('editable', True)
        #~ cell.set_property('editable-set', True)
        #~ cell.set_property('ellipsize-set', True)
        #~ cell.set_property('mode', gtk.CELL_RENDERER_MODE_EDITABLE)
        #~ cell.set_sensitive(True)
        #cell.set_editable(True)
      #~ for ix, tvcolumn in enumerate(self.columns):
        #~ tvcolumn.set_expand(True) # no effect
        #~ tvcolumn.set_property('resizable', True)
        #~ tvcolumn.set_clickable(True)
        #~ tvcolumn.set_sort_column_id(ix)#(0)
        #~ tvcolumn.set_sizing(gtk.TREE_VIEW_COLUMN_AUTOSIZE)
        #~ tvcolumn.set_alignment(1.0)
        #~ tvcolumn.set_expand(False)
        #~ #tvcolumn.add_attribute(self.cells[0], "editable", 2) # Warning: unable to set property `editable' of type `gboolean' from value of type `gchararray'?
        #~ ## tvcolumn.pack_start(self.cells[0], True)
        #~ #tvcolumn.set_attributes(self.cells[0], text=ix, background=(self.ncols+ix))
      # must call also this, because height remains otherwise too big:
      store = self.treeview.get_model()
      iter = store.get_iter_first()
      while iter and store.iter_is_valid(iter):
        store.row_changed(store.get_path(iter), iter)
        iter = store.iter_next(iter)
      #self.treeview.columns_autosize()
      self.treeview.set_size_request(0,-1) # redraw/refresh/invalidate
      #for cell in self.cells: print(cell.get_fixed_size()) # -1,-1
      #for cell in self.cells: print("_nowrap", cell.get_size(self.treeview)) # (0, 0, 4, 19)
    #else:
    #  self.handling_nowrap = False

  def resize_wrap(self, scroll, allocation):#, treeview, column, cell):
    #if not(self.handling_wrap):
      #self.handling_wrap = True
      newWidth = allocation.width/len(self.columns) # per column
      newWidth -= self.treeview.style_get_property("horizontal-separator") * 4
      #~ print(newWidth,self, self.scroll, allocation)
      #if newWidth < 300: # this prevents the resize to smaller colwidths
      #  newWidth = 300
      for ix, tvcolumn in enumerate(self.columns):
        #tvcolumn.set_property('sizing', gtk.TREE_VIEW_COLUMN_GROW_ONLY) #gtk.TREE_VIEW_COLUMN_FIXED)
        tvcolumn.set_expand(False)
        tvcolumn.set_property('resizable', True)
        tvcolumn.set_property('min-width', newWidth + 5) # with 5 here instead of 10, tends to fit without horizontal scrollbar!
        tvcolumn.set_property('max-width', newWidth + 10)
      for cell in self.cells:
        #cell.set_fixed_height_from_font(0) # naah; arg is number of rows
        if cell.props.wrap_width == newWidth: # or newWidth <= 0:
          continue #return
        cell.props.wrap_width = newWidth
      store = self.treeview.get_model()
      iter = store.get_iter_first()
      while iter and store.iter_is_valid(iter):
        store.row_changed(store.get_path(iter), iter)
        iter = store.iter_next(iter)
      self.treeview.set_size_request(0,-1) # redraw/refresh/invalidate
      #for cell in self.cells: print("_wrap", len(self.cells), cell.get_size(self.treeview)) # (0, 0, 28, 34)
    #else:
    #  self.handling_wrap = False

  def __init__(self, mycsvreadr):
    self.is_resize_wrap = False # so at start, is toggled to True
    self.handling_wrap = False
    self.handling_nowrap = False

    # Create a new window
    self.window = gtk.Window(gtk.WINDOW_TOPLEVEL)
    self.window.set_title('csv-pygtk.py: {0}'.format(sys.argv[1]))
    self.window.set_size_request(600,300)
    self.window.move(300, 200)
    self.window.connect("delete_event", self.delete_event)
    self.window.connect("key_press_event", self.key_press_event)
    self.window.set_events(gtk.gdk.KEY_PRESS_MASK)

    #self.vbox = gtk.VBox()
    #self.window.add(self.vbox)
    self.scroll = gtk.ScrolledWindow()
    self.scroll.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
    self.window.add(self.scroll)

    # create a liststore with one string column to use as the model
    #self.liststore = gtk.ListStore(str, str, str, 'gboolean')
    # retrieve header, and then make model
    # [http://www.daa.com.au/pipermail/pygtk/2008-February/014833.html [pygtk] Re: Trouble getting a ListStore with dynamic column number.]
    csv_header = mycsvreadr.next()
    self.ncols = len(csv_header)
    colors=['#00FFFF', '#FFBFC8', '#7575FF', '#AE6CBE',] # cyan, pink, (lighter)
    # since we have to add indiv. colors per cell, need twice as many columns
    ncollsz = 2*self.ncols
    self.liststore = gtk.ListStore(*([str] * ncollsz))

    # create the TreeView using liststore
    self.treeview = gtk.TreeView(self.liststore)

    # create the TreeViewColumns to display the data
    self.columns = []
    for name in csv_header:
      tvcolumn = gtk.TreeViewColumn(name) # no set any properties yet!
      self.columns.append(tvcolumn)
    self.tvcolinitprops = [] #self.columns[0].props
    for pspec in self.columns[0].props:
      #~ print pspec
      #~ print self.columns[0].get_property(pspec.name)
      # all but title:
      if pspec.name not in ["title"]:
        self.tvcolinitprops.append([pspec, self.columns[0].get_property(pspec.name)])

    lencols = len(self.columns)

    # add a row with text
    for ir, row in enumerate(mycsvreadr):
      #~ print len(row), row
      if len(row) == lencols:
        # with this, all row in first column:
        #iterator = self.liststore.append()
        #self.liststore.set_value(iterator, 0, row)
        # so just append here:
        tcolors = []
        for icol in range(0, lencols):
          tcolors.append(colors[ (ir%2)*2 + (icol%2) ])
        row.extend(tcolors) # note, this returns None; changes row in-place!
        self.liststore.append(row)

    # add columns to treeview, with properties
    for ix, tvcolumn in enumerate(self.columns):
      tvcolumn.set_property('resizable', True)
      tvcolumn.set_clickable(1)
      # Allow sorting on the column
      tvcolumn.set_sort_column_id(ix)#(0)
      #tvcolumn.set_property('sizing', gtk.TREE_VIEW_COLUMN_AUTOSIZE)
      tvcolumn.set_sizing(gtk.TREE_VIEW_COLUMN_AUTOSIZE)
      tvcolumn.set_alignment(1.0)
      tvcolumn.set_expand(False)
      self.treeview.append_column(tvcolumn)

    # create a CellRenderers to render the data
    # (now array is pointless, but keeping this as example)
    self.cells=[]
    for ix in range(0,4): # no properties here yet
      cell = gtk.CellRendererText()
      self.cells.append(cell) # = [cell, cell1]
    self.cellinitprops = [] #copy.deepcopy(self.cells[0].props)
    for pspec in self.cells[0].props:
      try:
        self.cellinitprops.append([pspec, self.cells[0].get_property(pspec.name)])
      except:
        pass

    for ix in self.cells:
      cell.set_property('editable', 1)

    # set background color property
    #~ self.cells[0].set_property('cell-background', '#00FFFF') # cyan
    #~ self.cells[1].set_property('cell-background', '#FFBFC8') # pink
    #~ self.cells[2].set_property('cell-background', '#7575FF')
    #~ self.cells[3].set_property('cell-background', '#AE6CBE')

    # add the cells to the columns - 2 in the first
    for ix, tvcolumn in enumerate(self.columns):
      #~ tvcolumn.pack_start(self.cells[ix%2], True)
      #~ tvcolumn.set_attributes(self.cells[ix%2], text=ix)
      tvcolumn.pack_start(self.cells[0], True)
      tvcolumn.set_attributes(self.cells[0], text=ix, background=(self.ncols+ix))

    # make treeview searchable
    self.treeview.set_search_column(0)

    # Allow drag and drop reordering of rows
    self.treeview.set_reorderable(True)

    #self.window.add(self.treeview)
    #self.vbox.pack_start(self.treeview)
    self.scroll.add(self.treeview)
    # instead of connect_after('size-allocate' and set_size_request(0,-1)
    # directly here, call the toggle function
    self.toggleColumnWidthHandling()

    self.window.show_all()

# ignore `#` comments in .csv file
# (http://bytes.com/topic/python/answers/513222-csv-comments)
def CommentStripper (iterator):
  for line in iterator:
    if line [:1] == '#':
      continue
    if not line.strip ():
      continue
    yield line

def main():
  global inputSrcType
  if (len(sys.argv)>1):
    infileObj = openAnything(sys.argv[1])
    inputSrcType = inputSrcType
    printso("Tried opening {0}: {1}, {2}\n".format(sys.argv[1], infileObj, inputSrcType))
    mycsvreadr = csv.reader(CommentStripper(infileObj)) #, delimiter=',', quotechar='"')

    tvcexample = CsvPygtkTreeViewColumn(mycsvreadr)
    gtk.main()

    infileObj.close()
  else:
    printso("Need filename as first argument.\n")

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()


"""
        print "TVCOLUMN.PROPS" ;
        for pspec in self.tvcolumn.props:
          print pspec
          print self.tvcolumn.get_property(pspec.name)
        ""
TVCOLUMN.PROPS
<GParamPointer 'user-data'>
None
<GParamBoolean 'visible'>
True
<GParamBoolean 'resizable'>
False
<GParamInt 'width'>
0
<GParamInt 'spacing'>
0
<GParamEnum 'sizing'>
<enum GTK_TREE_VIEW_COLUMN_GROW_ONLY of type GtkTreeViewColumnSizing>
<GParamInt 'fixed-width'>
1
<GParamInt 'min-width'>
-1
<GParamInt 'max-width'>
-1
<GParamString 'title'>
column 1
<GParamBoolean 'expand'>
False
<GParamBoolean 'clickable'>
True
<GParamFloat 'alignment'>
0.0
""
        print "CELL.PROPS" ;
        for pspec in self.cell.props:
          print pspec
          try:
            print self.cell.get_property(pspec.name)
          except:
            pass
""
CELL.PROPS
<GParamPointer 'user-data'>
None
<GParamEnum 'mode'>
<enum GTK_CELL_RENDERER_MODE_INERT of type GtkCellRendererMode>
<GParamBoolean 'visible'>
True
<GParamBoolean 'sensitive'>
True
<GParamFloat 'xalign'>
0.0
<GParamFloat 'yalign'>
0.5
<GParamUInt 'xpad'>
2
<GParamUInt 'ypad'>
2
<GParamInt 'width'>
-1
<GParamInt 'height'>
-1
<GParamBoolean 'is-expander'>
False
<GParamBoolean 'is-expanded'>
False
<GParamBoolean 'single-paragraph-mode'>
False
<GParamInt 'width-chars'>
-1
<GParamInt 'wrap-width'>
-1
<GParamEnum 'alignment'>
<enum PANGO_ALIGN_LEFT of type PangoAlignment>
<GParamInt 'size'>
0
<GParamDouble 'size-points'>
0.0
<GParamEnum 'ellipsize'>
<enum PANGO_ELLIPSIZE_NONE of type PangoEllipsizeMode>
<GParamEnum 'wrap-mode'>
<enum PANGO_WRAP_CHAR of type PangoWrapMode>
""
"""
