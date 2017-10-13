#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
################################################################################
# bibview_pygtk.py                                                             #
#                                                                              #
# Copyleft 2014, sdaau <sd[at]imi.aau.dk>                                      #
# This program is free software, released under the LPPL.                      #
# NO WARRANTY; for license information look up LPPL v1.3 or later              #
################################################################################
# started: Sun Jun 29 20:46:03 CEST 2014 ; Python 2.7.1+

import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

TLDIR = "/path/to/texlive/2011"
if 'TLDIR' in os.environ:
  if (os.environ['TLDIR']):
    TLDIR = os.environ['TLDIR']
BSTBASEDIR = "texmf-dist/bibtex/bst/base"
CLSBASEDIR = "texmf-dist/tex/latex/base"
_MYNAME = 'bibview_pygtk.py'
engines = ["bibtex", "biblatex (NO)", "biber (NO)"]
stylefiles = []
clsfiles = []
types = [ "article", "book", "booklet", "conference", "inbook", "incollection", "inproceedings", "manual", "mastersthesis", "misc", "phdthesis", "proceedings", "techreport", "unpublished" ] # got from wiki
filesallentries = {}
from collections import defaultdict # for a 2D dict
# FSentries: filestyleentries['filename']['type']
FSentriesraw = defaultdict(dict)
FSentries = defaultdict(dict)
FSUentries = defaultdict(dict) # unused


import re
import pprint # for debugging

# import pygtk
# pygtk.require('2.0')
import gtk
import gtk.glade # this fails with pygtkcompat

# (note1):
import glob
import tempfile
from StringIO import StringIO
import copy
import subprocess
import pango # highlight
import gobject # delays/schedule: idle_add

class bibviewWindow(object):
  # close the window and quit
  def delete_event(self, widget, event, data=None):
    gtk.main_quit()
    return False
  def __init__(self):
    global ftemp, engines, stylefiles, types, clsfiles
    # Create a new window
    #self.window = gtk.Window(gtk.WINDOW_TOPLEVEL)
    inittempfile()
    self.wTree = gtk.glade.XML(ftemp.name)
    os.unlink(ftemp.name) # ok to delete here
    self.window = self.wTree.get_widget("window1")
    self.window.set_title(_MYNAME)
    self.window.set_size_request(600,310)
    self.window.move(230, 130)
    self.window.connect("delete_event", self.delete_event)
    self.window.set_events(gtk.gdk.KEY_PRESS_MASK)
    #
    self.tooltips = gtk.Tooltips()
    self.combobox1 = self.wTree.get_widget("combobox1")
    self.combobox2 = self.wTree.get_widget("combobox2")
    self.combobox3 = self.wTree.get_widget("combobox3")
    self.combobox4 = self.wTree.get_widget("combobox4")
    liststore1 = gtk.ListStore(str)
    for item in engines:
      liststore1.append([item])
    self.getStyleClassFiles()
    liststore2 = gtk.ListStore(str)
    for item in stylefiles:
      liststore2.append([item])
    liststore3 = gtk.ListStore(str)
    for item in types:
      liststore3.append([item])
    liststore4 = gtk.ListStore(str)
    for item in clsfiles:
      liststore4.append([item])
    self.cbcell = gtk.CellRendererText()
    self.combobox1.set_model(liststore1)
    self.combobox1.pack_start(self.cbcell, True)
    self.combobox1.add_attribute(self.cbcell, "text", 0)
    self.combobox1.set_active(0)
    self.combobox2.set_model(liststore2)
    self.combobox2.pack_start(self.cbcell, True)
    self.combobox2.add_attribute(self.cbcell, "text", 0)
    self.combobox2.set_active(0)
    self.combobox2.connect("changed", self.on_combo_changed_item)
    self.combobox3.set_model(liststore3)
    self.combobox3.pack_start(self.cbcell, True)
    self.combobox3.add_attribute(self.cbcell, "text", 0)
    self.combobox3.set_active(0)
    self.combobox3.connect("changed", self.on_combo_changed_item)
    self.combobox4.set_model(liststore4)
    self.combobox4.pack_start(self.cbcell, True)
    self.combobox4.add_attribute(self.cbcell, "text", 0)
    self.combobox4.set_active(0)
    self.combobox4.connect("changed", self.on_rerender_click)
    for ix in ["2", "3"]:
      for iy in ["l", "r" ]:
        btnarrw = self.wTree.get_widget("button{0}{1}".format(ix,iy))
        btnarrw.connect("clicked", self.on_arrowclick)
        btnarrw.pcombo = self.wTree.get_widget("combobox{0}".format(ix)) # dyn.prop
        if (iy == "l"): btnarrw.emit("clicked") # both 2 and 3
    #
    self.textview1 = self.wTree.get_widget("textview1")
    self.textview2 = self.wTree.get_widget("textview2")
    self.labelview3 = self.wTree.get_widget("labelview3") # in html tab
    self.image1 = self.wTree.get_widget("image1") # in pixel tab
    self.buttonR = self.wTree.get_widget("buttonR") # rerender
    self.buttonR.connect("clicked", self.on_rerender_click)
    buf = self.textview1.get_buffer()
    buf.create_tag("highlight1", weight = pango.WEIGHT_NORMAL, scale = pango.SCALE_MEDIUM, foreground="#000000", background="#FF9185")
    buf.create_tag("highlight2", weight = pango.WEIGHT_NORMAL, scale = pango.SCALE_MEDIUM, foreground="#000000", background="#ECEB98")
    self.notebook1 = self.wTree.get_widget("notebook1") #
    # select-page no fire, change-current-page no fire, switch-page ok
    # must use own callback due num args; will just call on_rerender_click
    self.notebook1.connect("switch-page", self.on_switch_page)
    self.buttonR.emit("clicked") # initialize
    self.window.show_all()
  def getStyleClassFiles(self): # only bibtex for now
    global TLDIR, BSTBASEDIR, CLSBASEDIR, stylefiles, clsfiles
    bibtexsfp = os.path.join(TLDIR, BSTBASEDIR) # bibtexstylefilespath
    stylefiles = [ f for f in os.listdir(bibtexsfp) if os.path.isfile(os.path.join(bibtexsfp,f)) ]
    self.parseStyleFiles()
    texclsfp = os.path.join(TLDIR, CLSBASEDIR) #texclassfilespath
    clsfiles = [ f for f in os.listdir(texclsfp) if (os.path.isfile(os.path.join(texclsfp,f)) and (f.endswith('.cls'))) ]
  def parseStyleFiles(self): # only bibtex for now
    global TLDIR, BSTBASEDIR, stylefiles, filesallentries, types, FSentriesraw, FSentries
    bibtexsfp = os.path.join(TLDIR, BSTBASEDIR)
    patBibAllEntries = re.compile(r"ENTRY.+?{(.+?)}", re.MULTILINE|re.DOTALL)
    patSpaces = re.compile(r"[\s]+", re.MULTILINE|re.DOTALL)
    patNL = re.compile(r"\n", re.MULTILINE|re.DOTALL)
    patPerc = re.compile(r"%")
    patBibFunc = re.compile(r"FUNCTION {(.+?)}") # all seem to be written like this, will not do 'FUNCTION[\s]*{(.+?)}[\s]*'
    patBibOutp = re.compile(r'\s*"*(\S+?)"* (output.[^b][\S]+)') # catch both out and prev word; all but output.bibitem
    for ifile in stylefiles:
      ifpath = os.path.join(bibtexsfp,ifile)
      with open(ifpath, 'r') as f:
        read_data = f.read() # get entire contents
      allentries = patBibAllEntries.findall(read_data)[0]
      allentrieslines = patNL.split(allentries)
      for il, line in enumerate(allentrieslines):
        allentrieslines[il] = patPerc.split(line)[0].strip() # remove % comments
      allentrieslines = list(filter(None,allentrieslines)) # clean up '' entries
      filesallentries[ifile] = allentrieslines
      # now line by line; check when FUNCTION {article}; inside grab those ' output'; cannot use regex for nesting braces; so count?
      lastFuncname = None ; bracecount = -1
      for line in StringIO(read_data):
        line = line.rstrip('\n') # chomp
        funcnamefinds = patBibFunc.findall(line)
        if funcnamefinds:
          funcname = funcnamefinds[0] # actually, entry type, but extracted from the func name
          if funcname in types: # we only care about final "article" function
            lastFuncname = funcname
            bracecount = 0
            FSentriesraw[ifile][funcname] = [] # don't have to collect this line
            FSentries[ifile][funcname] = []
            FSUentries[ifile][funcname] = []
            #print("  >  {0} : {1}".format(funcname, line)) #
        else:
          if lastFuncname:
            openBraces = line.count('{')
            closBraces = line.count('}')
            bracecount += (openBraces - closBraces)
            gotOutp = patBibOutp.findall(line)
            #print(len(gotOutp), gotOutp)
            if (bracecount > 0):
              FSentriesraw[ifile][funcname].append(line)
              if gotOutp:
                #FSentries[ifile][funcname].append("{0}:{1}".format(gotOutp[0][0], gotOutp[0][1]))
                FSentries[ifile][funcname].append([gotOutp[0][0], gotOutp[0][1]])
            elif (bracecount == 0):
              FSentriesraw[ifile][funcname].append(line)
              if gotOutp:
                FSentries[ifile][funcname].appen([gotOutp[0][0], gotOutp[0][1]])
              lastFuncname = None ; bracecount = -1
              #print("entr['{0}']['{1}'] = {2}".format(ifile, funcname, "\n".join(map(" -- ".join, FSentries[ifile][funcname]))))
      # done with contents of file; check for missing types
      #print(FSentries[ifile])
      for ikeytype in FSentries[ifile].keys():
        ale = copy.copy(allentrieslines)
        iarrentrflds = FSentries[ifile][ikeytype]
        #print(" ikey", ikeytype, iarrentrflds)
        for iiarrentries in iarrentrflds:
          curentryfield = iiarrentries[0]
          for iiitem in ale:
            # ale: abbrv.bst, inbook: format.authors - author
            #print("  ale: {0}, {1}: {2} - {3} {4}".format(ifile, ikeytype, iiarrentries[0], iiitem, iiitem in curentryfield))
            # iiitem shorter, so can be in iiarrentries[0]
            if iiitem in curentryfield:
              ale.remove(iiitem)
              break
        # ALE abbrv.bst:techreport> ['address', 'booktitle', 'chapter', 'edition', 'editor', 'howpublished', 'journal', 'key', 'month', 'note', 'organization', 'pages', 'publisher', 'school', 'series', 'type', 'volume']
        # these are declared fields not directly addressed by functions we captured (but may be used in subroutines)
        #print("ALE {0}:{1}> {2}".format(ifile, ikeytype, ale))
        FSUentries[ifile][ikeytype] = ale
    #print(FSUentries)
  def on_arrowclick(self, widget):
    global filesallentries, FSentries
    thisbuttonname = widget.get_name()
    lastcharname = thisbuttonname[-1:] # l or r
    lastindname = thisbuttonname[-2:-1] # 2 or 3
    curselind = widget.pcombo.get_active()
    pliststore = widget.pcombo.get_model()
    didChange = False
    if lastcharname == 'r':
      lastplistind = len(pliststore)-1
      if (curselind < lastplistind):
        widget.pcombo.set_active(curselind+1)
        didChange = True
    else:
      if (curselind > 0):
        widget.pcombo.set_active(curselind-1)
        didChange = True
    if (not(didChange)): # else changed_item will fire it
      self.setComboTooltip(widget.pcombo)
  def setComboTooltip(self, combowidget):
    thiscomboname = combowidget.get_name()
    lastindname = thiscomboname[-1:] # 2 or 3
    if (lastindname == '2'): #
      ifile = combowidget.get_active_text()
      self.tooltips.set_tip(combowidget,
      "\n".join(filesallentries[ifile]))
      itype = self.combobox3.get_active_text()
      fse = FSentries[ifile][itype]
      fsestring = "\n".join( ["{0} ({1})".format(ix[0],ix[1]) for ix in fse] )
      if not(fsestring): fsestring = "[none]"
      self.tooltips.set_tip(self.combobox3, fsestring)
    if (lastindname == '3'): #
      itype = combowidget.get_active_text()
      ifile = self.combobox2.get_active_text()
      fse = FSentries[ifile][itype]
      fsestring = "\n".join( ["{0} ({1})".format(ix[0],ix[1]) for ix in fse] )
      if not(fsestring): fsestring = "[none]"
      self.tooltips.set_tip(combowidget, fsestring)
  def on_combo_changed_item(self, widget):
    #print("ComboBox {0} item was changed to {1}".format(widget.get_name(),widget.get_active_text()))
    self.setComboTooltip(widget)
    self.getBibtexOutput()
  def on_switch_page(self, widget, page, page_num):
    #self.notebook1.set_current_page(page_num) # recurses!
    #self.on_rerender_click(widget) # bad, this runs before tab is actually changed
    gobject.idle_add(self.on_rerender_click, widget) # seems to work
  def on_rerender_click(self, widget):
    self.getBibtexOutput()
  def getBibtexOutput(self):
    global calldir, rawBibtexOut, htmBibtexOut
    self.curtabpage = self.notebook1.get_current_page()
    self.window.set_title(_MYNAME + " (working)")
    #self.window.queue_draw() # does not update
    while gtk.events_pending(): # does update
      gtk.main_iteration_do(True)
    sysTemp = tempfile.gettempdir()
    jobname="bibview"
    # first, get cite key from the text
    patCiteStr=r"@([\S]+?)([\s]*){([\s]*)(.*?),"
    patCitekey=re.compile(patCiteStr, flags=re.DOTALL)
    textbuffer1 = self.textview1.get_buffer()
    tx1bounds = textbuffer1.get_bounds()
    tx1content = textbuffer1.get_text(tx1bounds[0], tx1bounds[1])
    ckeymatches = patCitekey.findall(tx1content)
    if not(ckeymatches) or ((len(ckeymatches[0])<4)) :
      printso("No cite key visible; will not get preview\n")
      self.window.set_title(_MYNAME)
      while gtk.events_pending(): # does update
        gtk.main_iteration_do(True)
      return
    else:
      #print(tx1content)
      citetype = ckeymatches[0][0] # should be replaced!
      citekey = ckeymatches[0][3]
      ifile = self.combobox2.get_active_text() # .bst file
      ifstyle = ifile[:-4]   # .endswith('.bst'):
      itype = self.combobox3.get_active_text()
      iclsf = self.combobox4.get_active_text() # .cls file
      icls = iclsf[:-4]   # .endswith('.cls'):
      # replace citetype with itype
      tx1content = patCitekey.sub(r'@' + itype + r'\2{\3\4,', tx1content)
      start, end = textbuffer1.get_bounds()
      textbuffer1.remove_all_tags(start, end)
      textbuffer1.set_text(tx1content)
      #matches = patCitekey.finditer(tx1content)
      matches = re.finditer(patCiteStr, tx1content, re.DOTALL)
      import inspect
      for m in matches:
        for ix, mg in enumerate(m.groups()):
          if ix in [0, 3]:
            iter_start = textbuffer1.get_iter_at_offset(m.start(ix+1)) # takes a number of group!
            iter_end = textbuffer1.get_iter_at_offset(m.end(ix+1))
            #print("Ak",iter_start,iter_end) # <GtkTextIter at 0x905e0a8>
            #line_number = iter_start.get_line()
            chgtag = "highlight2"
            if ix==0: chgtag = "highlight1"
            textbuffer1.apply_tag_by_name(chgtag, iter_start, iter_end)
      # note: without r''', \r is escaped (elax)!
      auxfcontent = r'''\relax
\citation{{{0}}}
\bibdata{{{1}}}
\bibstyle{{{2}}}
'''.format(citekey, jobname, ifile)
      texfcontent = "" # later
      bibfcontent = tx1content
      auxfname = jobname + ".aux"
      bibfname = jobname + ".bib"
      auxpath = os.path.join(sysTemp,auxfname)
      with open(auxpath, 'wb') as f:
        f.write(auxfcontent)
      bibpath = os.path.join(sysTemp,bibfname)
      with open(bibpath, 'wb') as f:
        f.write(bibfcontent)
      bblfname = jobname + ".bbl"
      blgfname = jobname + ".blg"
      texfname = jobname + ".tex"
      bblpath = os.path.join(sysTemp,bblfname)
      os.chdir(sysTemp)
      #cmdname = "bibtex " + auxfname
      proc=subprocess.Popen(["bibtex", auxfname],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
      shelloutput=proc.communicate(input=None)
      rc = proc.returncode
      if not(rc == 0):
        print("Bibtex Error (returned: {0}) - cannot proceed; {1}".format(rc, shelloutput))
        #return
      else:
        with open(bblpath, 'rb') as f:
          rawBibtexOut = f.read()
        textbuffer2 = self.textview2.get_buffer()
        textbuffer2.set_text(rawBibtexOut)
      pdfname = jobname + ".pdf"
      htmfname = jobname + ".html"
      #
      if self.curtabpage > 0: # for tab=2 or tab=3 (note2)
        texfcontent = r'''
\batchmode % quiet (no errors!)
\documentclass{{{0}}}
\usepackage[utf8]{{inputenc}}
\usepackage{{hyperref}}
\pagestyle{{empty}}
\begin{{document}}
\bibliographystyle{{{1}}}
\ifx\chapter\undefined\else%
\renewcommand{{\chapter}}[2]{{}}% book report and similar classes
\fi%
\ifx\section\undefined\else%
\renewcommand{{\section}}[2]{{}}% article class and similar
\fi
\let\bibname\relax% some may not define this, so no renew
\ifx\thebibliography\undefined [no bibliography!] \else%
\bibliography{{{2}}}
\fi
\end{{document}}
'''.format(icls, ifstyle, jobname)
        texpath = os.path.join(sysTemp,texfname)
        with open(texpath, 'wb') as f:
          f.write(texfcontent)
      #
      if self.curtabpage == 2: # only for tab=3,  where we have pdf pixels:
        proc=subprocess.Popen(["pdflatex", texfname],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
        shelloutput=proc.communicate(input=None)
        rc = proc.returncode
        if not(rc == 0):
          print("Pdflatex Error (returned: {0}) - cannot proceed; {1}".format(rc, shelloutput))
        # convert -density 150 bibview.pdf -crop `convert -density 75 bibview.pdf -trim -format 'x%[fx:h*2+10]+0+%[fx:page.y*2-5]' info:-` bibview.png && feh bibview.png
        # fx:page.width - width pre-trim/crop:
        proc=subprocess.Popen(["convert", "-density", "75", pdfname, "-trim", "-format", '%[fx:page.width*2]x%[fx:h*2+10]+0+%[fx:page.y*2-5]', "info:-"],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
        shelloutput=proc.communicate(input=None)
        rc = proc.returncode
        if not(rc == 0):
          print("Convert Error (returned: {0}) - cannot proceed; {1}".format(rc, shelloutput))
        cropdimens = shelloutput[0].rstrip() # trim/chomp
        patGeomstrsplit = re.compile(r'[x+]')
        cropdimparts = patGeomstrsplit.split(cropdimens)
        proc=subprocess.Popen(["convert", "-density", "150", pdfname, "-crop", cropdimens, "bmp:-"],stdin=subprocess.PIPE,stdout=subprocess.PIPE) # "bmp:-"
        shelloutput=proc.communicate(input=None)
        rc = proc.returncode
        if not(rc == 0):
          print("Convert Error (returned: {0}) - cannot proceed; {1}".format(rc, shelloutput))
        imgdatastr = shelloutput[0] # bmp, xpm;
        nw = int(cropdimparts[0]) ; nh = int(cropdimparts[1])
        mypixbuf = gtk.gdk.pixbuf_new_from_data(imgdatastr, gtk.gdk.COLORSPACE_RGB, has_alpha=False, bits_per_sample=8, width=nw, height=nh, rowstride=nw*3)
        mypixbuf = mypixbuf.rotate_simple(gtk.gdk.PIXBUF_ROTATE_UPSIDEDOWN).flip(True)
        # rescale to fit
        #aspectratio = mypixbuf.get_width()/mypixbuf.get_height()
        imall = self.image1.get_allocation() ;
        aspectmult = (imall.width+0.0)/mypixbuf.get_width()
        mypixbuf = mypixbuf.scale_simple(imall.width, int(mypixbuf.get_height()*aspectmult), gtk.gdk.INTERP_BILINEAR)
        self.image1.set_from_pixbuf(mypixbuf)
      #
      if self.curtabpage == 1: # only for tab=2,  where we have html:
        # html - using tex4ht's htlatex; with inline css:
        # htlatex bibview.tex "xhtml, css-in" ; xhtml must be first
        # "xhtml, css-in, charset='utf8', plain-"
        # html- fastest, html+ bit slower, xhtml slowest
        # html- however causes crash on deleted files: Can't find/open file `bibview.dvi'
        # so at least html, then...
        # must have second pair of options for proper utf-8
        proc=subprocess.Popen(["htlatex", texfname, "html, bib-, plain-, charset='utf8'", " -cunihtf -utf8"],stdin=subprocess.PIPE,stdout=subprocess.PIPE)
        shelloutput=proc.communicate(input=None)
        rc = proc.returncode
        if not(rc == 0):
          print("htlatex Error (returned: {0}) - cannot proceed; {1}".format(rc, shelloutput))
        htmpath = os.path.join(sysTemp,htmfname)
        with open(htmpath, 'ru') as f:
          htmBibtexOut = f.read()
        # GtkWarning: Failed to set text from markup due to error parsing markup: Attribute 'id' is not allowed on the <a> tag
        # error parsing markup: Error on line 12 char 8: Element 'head' was closed, but the currently open element is 'link'
        # error parsing markup: Attribute 'class' is not allowed on the <a>
        # error parsing markup: Unknown tag 'html'
        # error parsing markup: Unknown tag 'head'
        # error parsing markup: Unknown tag 'title'
        # error parsing markup: Unknown tag 'meta'
        # error parsing markup: Unknown tag 'link'
        # error parsing markup: Unknown tag 'body'
        # error parsing markup: Unknown tag 'div'
        # error parsing markup: Unknown tag 'p'
        # Attribute 'class' is not allowed on the <span> tag
        htmBibtexOut = re.sub(r'''<a[\s]*?id=['"].*?['"][\s]*?></a>''', " ", htmBibtexOut, flags=re.DOTALL)
        htmBibtexOut = re.sub(r'''(<a.*?)(class=['"].*?['"])([\s]*>)''', r'\1\3', htmBibtexOut, flags=re.DOTALL )
        htmBibtexOut = re.sub(r'''(<span.*?)(class=['"].*?['"])([\s]*>)''', r'\1\3', htmBibtexOut, flags=re.DOTALL )
        htmBibtexOut = re.sub(r'''<[/]*(html|head|title|meta|link|body|div|p).*?>''', '', htmBibtexOut, flags=re.DOTALL )
        # that's it - but there are too many spaces, so - 2 or more spaces
        htmBibtexOut = re.sub(r'''\s{2,}''', ' ', htmBibtexOut, flags=re.DOTALL )
        #print(htmBibtexOut)
        self.labelview3.set_markup(htmBibtexOut)
      #
      deleteTempFiles = True
      if deleteTempFiles:
        try: # so to fail silently if some files don't exist; but if it does, then not all afterwards will be deleted! Just go with glob; then (but then it's difficult to keep just pdf, etc)
          globpat = jobname + '.*'
          for i in glob.glob(globpat):
            os.unlink (i)
          #~ os.unlink(bblfname)
          #~ os.unlink(bibfname)
          #~ os.unlink(auxfname)
          #~ os.unlink(blgfname)
          #~ os.unlink(texfname)
          #~ os.unlink(jobname + ".log")
          #~ os.unlink(jobname + ".out") # may cause: No such file or directory:
          #~ os.unlink(jobname + ".css") # htlatex
          #~ os.unlink(jobname + ".dvi") # htlatex #may miss
          #~ os.unlink(jobname + ".idv") # htlatex #may miss
          #~ os.unlink(jobname + ".lg") # htlatex
          #~ os.unlink(jobname + ".tmp") # htlatex
          #~ os.unlink(jobname + ".xref") # htlatex
          #~ os.unlink(htmfname) # htlatex
          #~ os.unlink(jobname + ".4ct") # htlatex
          #~ os.unlink(jobname + ".4tc") # htlatex # and many more; .d
        except:
          pass # we don't care
      os.chdir(calldir)
    self.window.set_title(_MYNAME)
    while gtk.events_pending(): # does update window title
      gtk.main_iteration_do(True)


def inittempfile():
  global ftemp
  ftemp = tempfile.NamedTemporaryFile(mode='w+b', prefix='tmpBibView', delete=False)
  ftemp.write(r'''<?xml version="1.0" encoding="UTF-8"?>
<glade-interface>
  <!-- interface-requires gtk+ 2.24 -->
  <!-- interface-naming-policy project-wide -->
  <widget class="GtkWindow" id="window1">
    <property name="can_focus">False</property>
    <child>
      <widget class="GtkVBox" id="vbox1">
        <property name="visible">True</property>
        <property name="can_focus">False</property>
        <child>
          <widget class="GtkHBox" id="hbox1">
            <property name="visible">True</property>
            <property name="can_focus">False</property>
            <child>
              <widget class="GtkButton" id="button1l">
                <property name="visible">True</property>
                <property name="sensitive">False</property>
                <property name="can_focus">False</property>
                <property name="receives_default">False</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow1">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="arrow_type">left</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">0</property>
              </packing>
            </child>
            <child>
              <widget class="GtkComboBox" id="combobox1">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">1</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="button1r">
                <property name="visible">True</property>
                <property name="sensitive">False</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow2">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">2</property>
              </packing>
            </child>
            <child>
              <widget class="GtkVSeparator" id="vseparator1">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="position">3</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="button2l">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow3">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="arrow_type">left</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">4</property>
              </packing>
            </child>
            <child>
              <widget class="GtkComboBox" id="combobox2">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">5</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="button2r">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow4">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">6</property>
              </packing>
            </child>
            <child>
              <widget class="GtkVSeparator" id="vseparator2">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="position">7</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="button3l">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow5">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="arrow_type">left</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">8</property>
              </packing>
            </child>
            <child>
              <widget class="GtkComboBox" id="combobox3">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">9</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="button3r">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="relief">none</property>
                <property name="focus_on_click">False</property>
                <child>
                  <widget class="GtkArrow" id="arrow6">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">10</property>
              </packing>
            </child>
            <child>
              <widget class="GtkVSeparator" id="vseparator3">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="position">11</property>
              </packing>
            </child>
            <child>
              <widget class="GtkComboBox" id="combobox4">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">True</property>
                <property name="fill">True</property>
                <property name="position">12</property>
              </packing>
            </child>
            <child>
              <widget class="GtkVSeparator" id="vseparator4">
                <property name="visible">True</property>
                <property name="can_focus">False</property>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">True</property>
                <property name="position">13</property>
              </packing>
            </child>
            <child>
              <widget class="GtkButton" id="buttonR">
                <property name="label" translatable="yes">Rerender!</property>
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="receives_default">True</property>
                <property name="use_action_appearance">False</property>
                <property name="focus_on_click">False</property>
              </widget>
              <packing>
                <property name="expand">False</property>
                <property name="fill">False</property>
                <property name="position">14</property>
              </packing>
            </child>
            <child>
              <placeholder/>
            </child>
          </widget>
          <packing>
            <property name="expand">False</property>
            <property name="fill">True</property>
            <property name="position">0</property>
          </packing>
        </child>
        <child>
          <widget class="GtkVPaned" id="vpaned1">
            <property name="visible">True</property>
            <property name="can_focus">True</property>
            <property name="position">100</property>
            <property name="position_set">True</property>
            <child>
              <widget class="GtkScrolledWindow" id="scrolledwindow1">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <property name="hscrollbar_policy">automatic</property>
                <property name="vscrollbar_policy">automatic</property>
                <child>
                  <widget class="GtkTextView" id="textview1">
                    <property name="visible">True</property>
                    <property name="can_focus">True</property>
                    <property name="text" translatable="yes">@article{audactor2005pflanzen,
  title = {Wie Pflanzen hören... die Geheimnisse der Sonobotanik},
  author = {Prof. Dr. Hortensia Audactor},
  journal = {Draft: \url{http://www.inventionen.de/2005/sonobotanik.html}},
  year = {2005}
}
</property>
                  </widget>
                </child>
              </widget>
              <packing>
                <property name="resize">False</property>
                <property name="shrink">True</property>
              </packing>
            </child>
            <child>
              <widget class="GtkNotebook" id="notebook1">
                <property name="visible">True</property>
                <property name="can_focus">True</property>
                <child>
                  <widget class="GtkScrolledWindow" id="scrolledwindow2">
                    <property name="visible">True</property>
                    <property name="can_focus">True</property>
                    <property name="hscrollbar_policy">automatic</property>
                    <property name="vscrollbar_policy">automatic</property>
                    <child>
                      <widget class="GtkTextView" id="textview2">
                        <property name="visible">True</property>
                        <property name="can_focus">True</property>
                        <property name="text" translatable="yes">[output]</property>
                      </widget>
                    </child>
                  </widget>
                </child>
                <child>
                  <widget class="GtkLabel" id="label1">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="label" translatable="yes">raw</property>
                  </widget>
                  <packing>
                    <property name="tab_fill">False</property>
                    <property name="type">tab</property>
                  </packing>
                </child>
                <child>
                  <widget class="GtkScrolledWindow" id="scrolledwindow3">
                    <property name="visible">True</property>
                    <property name="can_focus">True</property>
                    <property name="hscrollbar_policy">automatic</property>
                    <property name="vscrollbar_policy">automatic</property>
                    <child>
                      <widget class="GtkViewport" id="viewport1">
                        <property name="visible">True</property>
                        <property name="can_focus">False</property>
                        <child>
                          <widget class="GtkLabel" id="labelview3">
                            <property name="visible">True</property>
                            <property name="can_focus">False</property>
                            <property name="xalign">0</property>
                            <property name="yalign">0</property>
                            <property name="xpad">3</property>
                            <property name="ypad">1</property>
                            <property name="label" translatable="yes">[output]</property>
                            <property name="use_markup">True</property>
                            <property name="wrap">True</property>
                            <property name="selectable">True</property>
                            <property name="track_visited_links">False</property>
                          </widget>
                        </child>
                      </widget>
                    </child>
                  </widget>
                  <packing>
                    <property name="position">1</property>
                  </packing>
                </child>
                <child>
                  <widget class="GtkLabel" id="label2">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="label" translatable="yes">html</property>
                  </widget>
                  <packing>
                    <property name="position">1</property>
                    <property name="tab_fill">False</property>
                    <property name="type">tab</property>
                  </packing>
                </child>
                <child>
                  <widget class="GtkImage" id="image1">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="xalign">0</property>
                    <property name="stock">gtk-missing-image</property>
                  </widget>
                  <packing>
                    <property name="position">2</property>
                  </packing>
                </child>
                <child>
                  <widget class="GtkLabel" id="label3">
                    <property name="visible">True</property>
                    <property name="can_focus">False</property>
                    <property name="label" translatable="yes">pixel</property>
                  </widget>
                  <packing>
                    <property name="position">2</property>
                    <property name="tab_fill">False</property>
                    <property name="type">tab</property>
                  </packing>
                </child>
              </widget>
              <packing>
                <property name="resize">True</property>
                <property name="shrink">True</property>
              </packing>
            </child>
          </widget>
          <packing>
            <property name="expand">True</property>
            <property name="fill">True</property>
            <property name="position">1</property>
          </packing>
        </child>
        <child>
          <placeholder/>
        </child>
      </widget>
    </child>
  </widget>
</glade-interface>
''')
  ftemp.close() # close, so can reopen later

def main():
  mybibview = bibviewWindow()
  gtk.main()

# run the main function; args are: sys.argv[1] .. :
if __name__ == "__main__":
  main()
