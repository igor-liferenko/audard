################################################################################
# multitrack_plot.py                                                           #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# needs gtk-builder (not for libglade)
# tried with python 2.7: mpl 0.99 is difficult to set up, so using gnuplot pipe (now via Xnuplot)
# python-gtk2/natty uptodate 2.22.0-0ubuntu1.1
# python-numpy/natty uptodate 1:1.5.1-1ubuntu2
# since python doesn't compile .pyc/.pyo for main files, can use:
# python -O -m py_compile tests/multitrack_plot.py
# but when this file is imported, pyc is automatically created (even if .pyo already exists)
print("importing modules...")
import pygtk
pygtk.require("2.0")
import gtk
import copy
from pprint import pprint, pformat
import inspect
import numpy as np
import numpy.lib.recfunctions as nprf #from numpy.lib.recfunctions import append_fields
# not using matplotlib now - uncomment these below if matplotlib example is wanted:
#~ import matplotlib
#~ matplotlib.use('Agg')
#~ from matplotlib.figure import Figure
#~ from matplotlib.backends.backend_gtkagg import FigureCanvasGTKAgg as FigureCanvas
#~ from matplotlib.backends.backend_agg import FigureCanvasAgg
#~ from matplotlib import rcParams
import subprocess
from gi.repository import GdkPixbuf
from string import Template
import sys
import gobject
import os, time
import warnings

global gladefile, data , xgplots , winmousepos , SHIFT_PRESSED , isZoomXSelecting , zmxrange_default , zmxrange_history , zmxrange_current , zmxrange_lastmus , status_txts , indatfile , last_track_mousedover , owint , zoomIOfactor , panLRfactor , xmarkers , current_xpos_rel , current_xmarker

gladefile = "/media/disk/work/AudioFPGA_git/driver_pc/snd_ftdi_audard-an16s/tests/multitrack_plot.glade"

# NOTE: needs HACKED Xnuplot (which can recognize and return PNG in stdout stream!)
sys.path.append("/media/disk/src/Xnuplot_git")
import xnuplot # Python 2.6 or 2.7 (not Python 3); Gnuplot 4.4 or above; Pexpect

class dObject(object): pass # can add attributes/properties dynamically
data = dObject() #np.array([])

#xgplot = xnuplot.Plot(autorefresh=False)
xgplots = []
winmousepos = None
SHIFT_PRESSED = False
isZoomXSelecting = False
zmxrange_default = (0.0, 1.0)
zmxrange_history = [] ; zmxrange_history.append(zmxrange_default)
zmxrange_current = 0
zmxrange_lastmus = None ; zmxrange_lastcmd = ""
status_txts = []
indatfile = "" # ref; init in setupPlotData()
last_track_mousedover = None
owint = "" # ref; init in copyTemplateAndClear()
zoomIOfactor = 0.1
panLRfactor = 0.1
xmarkers = dObject() # ref; init in setupPlotData()
current_xpos_rel = 0
current_xmarker = 0


def main():
  global window
  print("main start")
  wTree = gtk.Builder()
  wTree.add_from_file(gladefile)
  window = wTree.get_object("window1")
  if not(window): return

  window.set_size_request(700, 400)
  copyTemplateAndClear() # does window.realize()
  buildTracks()          # does window.show()

  window.connect("destroy", gtk.main_quit)
  window.add_events(gtk.gdk.KEY_PRESS_MASK | gtk.gdk.KEY_RELEASE_MASK | gtk.gdk.POINTER_MOTION_MASK | gtk.gdk.POINTER_MOTION_HINT_MASK | gtk.gdk.BUTTON_PRESS_MASK)
  window.connect('key-press-event', on_key_press_event)
  window.connect('key-release-event', on_key_release_event)
  #window.connect("motion-notify-event", on_mouse_move)  # let the widgets, rather
  #window.connect("button-press-event", on_button_press) # let the widgets, rather
  #window.connect("button-release-event", on_button_release)
  window.show_all() # must have!
  gtk.main()

def copyTemplateAndClear():
  global window, track_template, vb1, tracks, maxtracks, owint
  # note: the window must be realized here, otherwise even
  # hb1_ref.tda.get_allocation will be: gtk.gdk.Rectangle(-1, -1, 1, 1)
  # after realize hb1_ref: gtk.gdk.Rectangle(0, 0, 684, 150);
  #                   vb1: gtk.gdk.Rectangle(0, 0, 684, 450)
  window.realize()
  owint = window.get_title()
  # get template object
  hb1_ref = get_descendant(window, "handlebox1", level=0, doPrint=False)
  #track_template = copy.deepcopy(hb1_ref) # GObject non-copyable
  track_template = deep_clone_widget(hb1_ref)
  gtk.Buildable.set_name(track_template, "track_template")
  # get the container to be cleared
  vb1 = get_descendant(window, "vbox1", level=0, doPrint=False)
  vb1a = vb1.get_allocation()
  wa = window.get_allocation()
  da1a = hb1_ref.get_child().get_allocation()
  vb1.startwidth = vb1a.width # add as new attribute; afterwards it will be gone
  vb1.dastartwidth = da1a.width # add as new attribute; ...
  vb1.wdd = wa.width - da1a.width #
  # delete pre-existing in vbox (incl. hb1_ref)
  for i in vb1.get_children():
    vb1.remove(i)
  tracks=[]
  maxtracks=0

def buildTracks():
  #buildTracksMatplotlib()
  #buildTracksGnuplot()
  #buildTracksXnuplotData_Test()
  buildTracksXnuplotData()

def on_key_press_event(widget, event):
  global SHIFT_PRESSED, zoomIOfactor, panLRfactor, zmxrange_history, zmxrange_current
  # for some reason, I'm getting always event.state = flags 0? while release works?
  # because of gtk.gdk.KEY_PRESS_MASK above? Nope, leave it
  # event.keyval & gtk.gdk.SHIFT_MASK fires also on Ctrl - directly detect the SHIFT's via keyval
  #modifiers = gtk.accelerator_get_default_mod_mask()
  #print event.keyval & gtk.gdk.SHIFT_MASK, event.get_state() , event.state & gtk.gdk.SHIFT_MASK
  keyname = gtk.gdk.keyval_name(event.keyval)
  #print "Key %s (%d) was pressed" % (keyname, event.keyval)
  # use gtk.timeout_add for exportAllXmarkersAtRange, so they run "outside" of gtk callbacks,
  # also if it's called from GUI, make it use current zoom range:
  if event.keyval in [65505, 65506]:
    SHIFT_PRESSED = True
    # set back default value (8), so drag is enabled:
    setEnablingDragThreshold(8, "multitrack:shift-press:drag-enabled")
  elif keyname == 'r': toggleWindowTitleWorkingStatus(); rerenderXnuplotTracks() ; toggleWindowTitleWorkingStatus() #rerenderXnuplotTracks_Test() # rerenderGnuplotTracks()
  elif keyname == 'n': stepZoomXRangeNext() # 'Up'
  elif keyname == 'b': stepZoomXRangePrev() # 'Down'
  elif keyname == 'space': stepZoomXRangeFirst()
  elif keyname == 'k': resetZoomXRange() # 'r' is rerender, so 'k' for kill
  elif keyname == 'y': toggleAutoYRange()
  elif keyname == 'p': generateEntireImage()
  elif keyname == 'a': addCurrentXrangeToHistory()
  elif keyname == 'm': addMarkerAtXlocPosition()
  elif keyname == 'c': clearUserXmarkers()
  elif keyname == 'j': jumpCenterNextXmarker()
  elif keyname == 'h': jumpCenterPrevXmarker()
  elif keyname == 'E': gtk.timeout_add(500, exportAllXmarkersAtRange, zmxrange_history[zmxrange_current]) # after 500 ms; use shift, as its too close to 'r', and can be pressed by accident; don't use 'e' and SHIFT_PRESSED, use 'E'
  elif keyname == 'Up': ZoomAroundXlocPosition(zoomin=True, zfactor = zoomIOfactor) # also in on_mouse_scroll_wheel
  elif keyname == 'Down': ZoomAroundXlocPosition(zoomin=False, zfactor = zoomIOfactor) # also in on_mouse_scroll_wheel
  elif keyname == 'Left': PanXrangeLR(panleft=True, pfactor = panLRfactor) # also in on_mouse_scroll_wheel
  elif keyname == 'Right': PanXrangeLR(panleft=False, pfactor = panLRfactor) # also in on_mouse_scroll_wheel
  elif (keyname == 'q' or keyname == 'Escape'): gtk.main_quit()
  return True


def on_key_release_event(widget, event):
  global tracks, SHIFT_PRESSED
  if event.state & gtk.gdk.SHIFT_MASK:
    SHIFT_PRESSED = False
    # set to large value here, so drag never gets initiated!
    setEnablingDragThreshold(3000, "multitrack:shift-release:drag-disabled")
  return True

def setEnablingDragThreshold(innum, msg):
    global tracks
    for ttc in tracks:
      tda = ttc.get_child()
      gSettings = tda.get_settings();
      gSettings.set_long_property("gtk-dnd-drag-threshold", innum, msg)

def buildTracksXnuplotData():
  global xgplots, vb1
  setupPlotData()
  window.show() #.realize() # realize not enough for pixmp - must use show
  for ix, ixgp in enumerate(xgplots):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    ttc = addTrack(color=gtk.gdk.Color(colstr), incanvas=None, startwidth=vb1.dastartwidth)
    ttc.add_events(gtk.gdk.POINTER_MOTION_MASK | gtk.gdk.POINTER_MOTION_HINT_MASK)
    tda = ttc.get_child()
    #tgps = gpscript.safe_substitute(dict(color=colstr)) #gpscript.format(color=colstr)
    x, y, width, height = tda.get_allocation() # w,h: 1,1 here!
    width, height = tda.get_size_request()
    tda.gpixbuf = getXnuplotPixbuf("", ix, width, height) # add as new attribute
    tda.gpixmap = gtk.gdk.Pixmap(tda.window, width, height) # add as new attribute
    tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    tda.connect("expose_event", da_expose_event)
    tda.connect("size_allocate", da_resize_event)
    ttc.connect("button-press-event", on_button_press) # tda cannot have button press!
    ttc.connect("button-release-event", on_button_release)
    ttc.connect("motion-notify-event", on_mouse_move) # window as mousemove master makes it problematic to translate relative coords, so now handlebox
    # these two to manage mousever over tracks - since otherwise the
    # last track is kept, even if outside any tracks! must add_events too!
    ttc.add_events(gtk.gdk.ENTER_NOTIFY_MASK | gtk.gdk.LEAVE_NOTIFY_MASK)
    ttc.connect("enter-notify-event", on_mouse_enter_track)
    ttc.connect("leave-notify-event", on_mouse_leave_track)
    ttc.connect("scroll-event", on_mouse_scroll_wheel)
    ttc.set_shadow_type(gtk.SHADOW_NONE)
  setEnablingDragThreshold(3000, "multitrack:start:drag-disabled")

# colors - see: gnuplot -e "show colornames" 2>&1 | less

gps_preamble = '''set tics in border mirror; set grid xtics ytics;
set xtics offset 0,2; set ytics offset 2,0 left;
set tmargin 0; set bmargin 0; set lmargin 0; set rmargin 0;
#set lmargin at screen 0 ; set bmargin at screen 0 ; set rmargin at screen 0.99999 ; set tmargin at screen 0.99999 ;
set autoscale xfix x2fix ykeepfix y2keepfix
set x2tics format ""; set y2tics format "";
set clip two
'''

def getPrepXgplot(tsz=""):
  global gps_preamble
  xgplot = xnuplot.Plot(autorefresh=False)
  #xgplot("set terminal png font ',9' %s" % (tsz))
  xgplot("set terminal png font 'FreeSans,9' %s" % (tsz))
  xgplot('set output "/dev/stdout"')
  xgplot(gps_preamble)
  return xgplot

def setupPlotData():
  global data, status_txts, xgplots, indatfile, xmarkers #, xgplot
  if not(indatfile): # by default its ""
    #indatfile = "/media/disk/tmp/ftdi_prof/repztest.txt"
    indatfile = "/media/disk/tmp/ftdi_prof/ftdiprof-2013-12-06-05-03-49_64/repz.txt"
  print("Reading data from " + indatfile + "...")
  initStatusHist(indatfile)
  xgplots = []
  #np.setbufsize(1e7) # performance?
  # note: np.array is "somewhat static" like tuple, if you need
  #  manipulation, build a list - and then at end np.array
  # np.loadtxt is faster than np.genfromtxt; but cannot
  #  handle missing values, and doesn't support column names
  # genfromtxt doesn't have a total length/count of lines to read;
  #  it has skip_header (at start) and skip_footer (at end)
  # note: "st0", "st1" are hex strings; use a convert function for them
  # set up caching here too, not in a sep func - since we want to have the fields in view as well!
  # actually, better with function and arguments!
  # (delete the cached file to reconstruct it)
  indtype="float,float,int,int,int,int,int,int,int,int,int,int,int"
  innames=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt", "wrdlt", "wbps", "rbps"]
  hexconvertfunc = lambda x: int(x, 16)
  inconverters={"st0": hexconvertfunc, "st1": hexconvertfunc }
  pdata = NploadFromTxtCached(indatfile, indtype, innames, inconverters)
  # build arrays by SELECT FROM pdata ( like sql :) ) manually; change column names
  #ts1 = pdata[pdata['fid']==1][['ts']] ; ts1.dtype.names = ('ts1',)
  #---
  #wrdltz = pdata[np.logical_or(pdata['fid']==1,pdata['fid']==2)][['wrdlt']]
  #wrdltz.dtype.names = ('wrdltz',)
  # for the xange, we assume we always start from 0 !
  # array, so the str representation matches gnuplot range syntax?
  # nah - tuple, then format string ...
  data.orig_data_xrange = (0, np.max(pdata['ts']))
  print("orig_data_xrange", data.orig_data_xrange)
  # NOTE!: even if we specify out of order 'ts','tot','len','rbps', 'st1',
  # this selection will return these fields named in order,
  # which the rename afterward would screw up!
  # so here ALWAYS spec fields in order!
  # also, fancy: [['ts','tot','dlt','wbps']] -> [ k ] ; where k=['ts', ..
  # so store wanted fields as array:
  print("ats1")
  ats1_wflds=['ts','tot','dlt','wbps']
  ats1=pdata[pdata['fid']==1][ats1_wflds] #[['ts','tot','dlt','wbps']]
  print("ats1 rearr")
  ats1=rearrangeNumpyArrFields(ats1, ats1_wflds)
  ats1.dtype.names = ('ts1','wtot1','wdlt1','wbps1') # now rename
  #
  print("ats2")
  ats2_wflds=['ts','tot','len','rbps', 'st1']
  ats2=pdata[pdata['fid']==2][ats2_wflds] #[['ts','tot','len','rbps', 'st1']]
  print("ats2 rearr")
  ats2=rearrangeNumpyArrFields(ats2, ats2_wflds)
  ats2.dtype.names = ('ts2','rtot2','rlen2','rbps2', 'st12')
  #
  print("atsz")
  atsz=pdata[np.logical_or(pdata['fid']==1,pdata['fid']==2)][['ts','wrdlt']]
  atsz.dtype.names = ('tsz','wrdltz')
  # better to us fill_value = 0 here for out of bounds, because we need difference/subtraction?
  print "interp to atsz"
  wbpz, rbpz = getNPsaZeroDInterpolatedOver(ats1, 'ts1', 'wbps1', ats2, 'ts2', 'rbps2', atsz, 'tsz') # getNPsaLinInterpolatedOver  # getNPsaNearestInterpolatedOver getNPsaZeroInterpolatedOver , fill_value=0
  print "subtract"
  wrbpsz = np.subtract(wbpz['wbps1'], rbpz['rbps2']) # dtype/name is here lost
  #~ print "ats1", pformat(ats1[["ts1", "wbps1"]][:5])
  #~ print "ats2", pformat(ats2[["ts2", "rbps2"]][:5])
  #~ print "wbpz", pformat(wbpz[:5]) #[186:190])
  #~ print "rbpz", pformat(rbpz[:5]) #[186:190])
  #~ print "wrbpsz", pformat(wrbpsz[:5]) #[186:190])
  # nearest: wrbpsz array([154963, 168642, 160133, 171466, 172043]) - same as wbps1 (ok, but other probs.)
  # linear:  wrbpsz array([126247, 139926, 131417, 142750, 143327])
  # zeroB:   wrbpsz array([154963, 168642, 160133, 171466, 172043]) - same as wbps1 (ok)
  #atsz = append_fields(atsz, names='wbps1z', data=wbpz['wbps1'], dtypes=wbpz.dtype['wbps1'], usemask=False)
  print "atsz append_fields"
  atsz = nprf.append_fields(atsz, names='wrbpsz', data=wrbpsz, dtypes=wbpz.dtype['wbps1'], usemask=False)
  atsz = nprf.append_fields(atsz, names='wbpsz', data=wbpz['wbps1'], dtypes=wbpz.dtype['wbps1'], usemask=False)
  atsz = nprf.append_fields(atsz, names='rbpsz', data=rbpz['rbps2'], dtypes=rbpz.dtype['rbps2'], usemask=False)
  #
  # awk '{n=strtonum("0x" $6);if(and(rshift(n,1),1)){print;};}' repz.txt > rep2o.txt
  # overruns to go xmarkers
  # note: np.logical_and returns bool, which can select numpy rows;
  # but np.bitwise_and returns int, so must be cast astype(bool) to select!
  print "atso2"
  atso2 = ats2[ np.bitwise_and(np.right_shift(ats2['st12'],1), np.ones_like(ats2['st12'])).astype(bool) ]
  #
  data.structured = [ ats1, ats2, atsz, atso2 ]  # mere reference
  #a = np.asarray(ats1) #if a.ndim != 2: # still 1d!
  # ndim=1 for structured arrays:
  #print("ndim", a.ndim, ats1.ndim, np.array(ats1, ndmin=2).ndim)
  # have to do this because "array for Gnuplot array/record must have ndim >= 2",
  # this seems to be the only way to reshape and preserve datatype:
  print "aats 1,2,z"
  aats1 = np.ndarray((ats1.shape[0],len(ats1.dtype)), dtype = object) #aa[:,0] = a['x']
  for ix, ins in enumerate(ats1.dtype.names): # also get a count iterator
    aats1[:,ix] = ats1[ins]
  aats2 = np.ndarray((ats2.shape[0],len(ats2.dtype)), dtype = object)
  for ix, ins in enumerate(ats2.dtype.names):
    aats2[:,ix] = ats2[ins]
  aatsz = np.ndarray((atsz.shape[0],len(atsz.dtype)), dtype = object)
  for ix, ins in enumerate(atsz.dtype.names):
    aatsz[:,ix] = atsz[ins]
  data.plotformat = [ aats1, aats2, aatsz ]  # mere reference
  # ---
  #data = numpy.column_stack((x, y1, y2))
  print "prep xgplot1"
  xgplot1=getPrepXgplot()
  xgplot1.myxrange = data.orig_data_xrange # add as new attribute
  xgplot1.origyrange = "set yrange [176400:176700]"
  xgplot1.myyrange = xgplot1.origyrange
  xgplot1(xgplot1.myyrange)
  xgplot1("set xrange [{0}:{1}]".format(xgplot1.myxrange[0], xgplot1.myxrange[1]))
  xgplot1.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
    options="t'wbps1' with steps lc rgb 'red'"
  ))
  #~ xgplot1.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
    #~ options="t'' with points lc rgb 'red' pt 7"
  #~ ))
  xgplot1.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
    options="t'rbps2' with steps lc rgb 'blue'"
  ))
  #~ xgplot1.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
    #~ options="t'' with points lc rgb 'blue' pt 7"
  #~ ))
  xgplots.append(xgplot1) ###
  print "prep xgplot2"
  xgplot2=getPrepXgplot()
  xgplot2.myxrange = data.orig_data_xrange # add as new attribute
  xgplot2.origyrange = "set yrange [0:150]"
  xgplot2.myyrange = xgplot2.origyrange
  xgplot2(xgplot2.myyrange)
  xgplot2("set xrange [{0}:{1}]".format(xgplot2.myxrange[0], xgplot2.myxrange[1]))
  xgplot2.append(xnuplot.record( aatsz, using=(0, 2), # tsz/wrbpsz
    options="t'wrbpsz' with steps lc rgb 'purple'"
  ))
  #~ xgplot2.append(xnuplot.record( aatsz, using=(0, 2), # tsz/wrbpsz
    #~ options="t'' with points lc rgb 'purple' pt 7"
  #~ ))
  xgplots.append(xgplot2) ###
  print "prep xgplot3"
  xgplot3=getPrepXgplot()
  xgplot3.myxrange = data.orig_data_xrange # add as new attribute
  xgplot3.origyrange = "set yrange [176400:176700]"
  xgplot3.myyrange = xgplot3.origyrange
  xgplot3(xgplot3.myyrange)
  xgplot3("set xrange [{0}:{1}]".format(xgplot3.myxrange[0], xgplot3.myxrange[1]))
  xgplot3.append(xnuplot.record( aatsz, using=(0, 3), # tsz/wbpsz
    options="t'wbpsz' with steps lc rgb 'red'"
  ))
  #~ xgplot3.append(xnuplot.record( aatsz, using=(0, 3), # tsz/wbpsz
    #~ options="t'' with points lc rgb 'red' pt 7"
  #~ ))
  xgplot3.append(xnuplot.record( aatsz, using=(0, 4), # tsz/rbpsz
    options="t'rbpsz' with steps lc rgb 'blue'"
  ))
  #~ xgplot3.append(xnuplot.record( aatsz, using=(0, 4), # tsz/rbpsz
    #~ options="t'' with points lc rgb 'blue' pt 7"
  #~ ))
  xgplots.append(xgplot3) ###
#~ >   xgplot4=getPrepXgplot()
#~ >   xgplot4.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot4.origyrange = "set yrange [176400:176700]"
#~ >   xgplot4.myyrange = xgplot4.origyrange
#~ >   xgplot4(xgplot4.myyrange)
#~ >   xgplot4("set xrange [{0}:{1}]".format(xgplot4.myxrange[0], xgplot4.myxrange[1]))
#~ >   xgplot4.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
#~ >     options="t'wbps1' with steps lc rgb 'red'"
#~ >   ))
#~ >   xgplot4.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
#~ >     options="t'rbps2' with steps lc rgb 'blue'"
#~ >   ))
#~ >   xgplots.append(xgplot4) ###
#~ >   xgplot5=getPrepXgplot()
#~ >   xgplot5.myxrange = data.orig_data_xrange # add as new attribute
#~ >   xgplot5.origyrange = "set yrange [176400:176700]"
#~ >   xgplot5.myyrange = xgplot5.origyrange
#~ >   xgplot5(xgplot5.myyrange)
#~ >   xgplot5("set xrange [{0}:{1}]".format(xgplot5.myxrange[0], xgplot5.myxrange[1]))
#~ >   xgplot5.append(xnuplot.record( aats1, using=(0, 3), # ts1/wbps1
#~ >     options="t'wbps1' with steps lc rgb 'red'"
#~ >   ))
#~ >   xgplot5.append(xnuplot.record( aats2, using=(0, 3), # ts2/rbps2
#~ >     options="t'rbps2' with steps lc rgb 'blue'"
#~ >   ))
#~ >   xgplots.append(xgplot5) ###
  # for the xmarker, we only need x (ts) data; but may need other, for, say, color
  print "xmarkers"
  xmarkers = dObject()
  xmarkers.data = atso2[['ts2','st12']]
  # given we assume data_xrange starts from zero,
  # the data xrange length is the max in [1];
  # use it to get relative x positions (in range 0.0:1.0) :
  xmarkers.dataxrel = atso2['ts2']/data.orig_data_xrange[1]
  # application specific
  xmarkers.appd = np.array([]) # in data domain (will be np.array later)
  xmarkers.appdxrel = [] # in 0.0:1.0 domain

def setGlobalFunc(instr): #set_setupPlotData(instr):
  cc=compile(instr,'abc','single')
  exec(cc, globals()) # globals() here does the trick

def NploadFromTxtCached(indatfile, indtype, innames, inconverters):
  cachefn = indatfile + '.npy' ; pdata = None
  if os.path.isfile(cachefn):
    print("Cached data found - loading cached data")
    pdata = np.load(cachefn) #, mmap_mode='r')
  else:
    print("Cached data not found - loadfromtxt ...")
    pdata = np.genfromtxt(indatfile, delimiter=" ", comments="#",
      #dtype="float,float,int,int,int,int,int,int,int,int",
      #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt"]
      dtype=indtype,
      names=innames,
      converters=inconverters
    )
    print("Saving cache ... ")
    np.save(cachefn, pdata)
  updateStatusLabelTxt() # this will make selection slightly visible at start - but will also erase default filler text in label
  gobject.idle_add(updateStatusLabelTxt) # enable selectable later - so it doesn't start with a full text selection
  return pdata



def getXmarkersGnuplotCmdsStr():
  global xmarkers
  # xmarkers go on all plots, so string is independent of widget
  rets = "unset arrow\n" # delete all arrows
  rets += "set arrow from screen 0, first 0 to screen 1, first 0 lw 2 lc rgb 'black'\n" # at y=0
  tmpl = 'set arrow from first {0},screen 0 to first {0},screen 1 lw 2 lc rgb "{1}"\n'
  for ixm in xmarkers.data:
    tstr = tmpl.format(ixm['ts2'], 'dark-blue' if ixm['st12']==0x62 else 'red')
    rets += tstr
  # application may add relative, so first convert to data coordinates;
  # cast to np.array, to do the calc in one line;
  # again assume data_xrange starts from zero, so length in [1]
  xmarkers.appd = np.array(xmarkers.appdxrel)*data.orig_data_xrange[1]
  for ixma in xmarkers.appd:
    tstr = tmpl.format(ixma, 'light-gray')
    rets += tstr
  return rets

def getXnuplotPixbuf(tgps, ix, width, height):
  global xgplots, zmxrange_history, zmxrange_current, data
  # there are as many tracks as xgplots ; get corresponding to ix
  tsz = ""
  if (width>0 and height>0):
    tsz = "size {x},{y}".format(x=width,y=height)
  xgplot = xgplots[ix]
  # this __call__() simply adds/sends another command to underlying gnuplot
  #xgplot("reset") # a reset here may mess up initial grids, etc!
  xgplot("set terminal png font ',9' %s" % (tsz))
  # send marker commands
  xgplot(getXmarkersGnuplotCmdsStr())
  # recalc the xrange according to zoom settings
  currange = zmxrange_history[zmxrange_current]
  dataoriglen = data.orig_data_xrange[1]-data.orig_data_xrange[0]
  nrleft = data.orig_data_xrange[0]+currange[0]*dataoriglen
  nrright = data.orig_data_xrange[0]+currange[1]*dataoriglen
  xgplot.myxrange = (nrleft, nrright)
  xgplot("set xrange [{0}:{1}]".format(xgplot.myxrange[0], xgplot.myxrange[1]))
  # also repeat the yrange (could be toggled auto)
  xgplot(xgplot.myyrange)
  imgdatstdout = xgplot.refresh()
  #xgplot.close()
  loader = GdkPixbuf.PixbufLoader('png') #.new_with_type('png')
  if (imgdatstdout[1:4] != "PNG"):
    print "imgdatstd", imgdatstdout
  loader.write(imgdatstdout)
  pixbuf = loader.get_pixbuf()
  loader.close()
  return pixbuf

def rerenderXnuplotTracks(blocking=False):
  global window, tracks, xgplots
  # window.get_size_request() is unchanged here!
  wx, wy, winw, winh = window.get_allocation()
  #print "rerender X", winw
  for ix, ixgp in enumerate(xgplots):
    #print ix,
    rerenderXnuplotTrack(ix, blocking=blocking)
  #print
  #window.window.invalidate_rect(window.get_allocation(), invalidate_children=True)
  if blocking: updateStatusLabelTxt()
  else: gobject.idle_add(updateStatusLabelTxt) # also here (rerender can be called independently of refreshTracksDraw); schedule later

def rerenderXnuplotTrack(ix, blocking=False):
  global tracks, window
  ttc = tracks[ix]
  tda = ttc.get_child()
  x, y, width, height = tda.get_allocation() # w,h: was 1,1 here! but here ok...
  swidth, sheight = tda.get_size_request()
  tda.gpixbuf = getXnuplotPixbuf("", ix, width, sheight) # add as new attribute
  # here was tda.window reference, can be window.window;
  # tda.window seems able to survive the call from offscreenwindow too..
  tda.gpixmap = gtk.gdk.Pixmap(tda.window, width, sheight) # add as new attribute
  tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
  #tda.window.invalidate_rect(tda.get_allocation(), invalidate_children=False)
  if blocking:
    tda.window.invalidate_rect(tda.get_allocation(), invalidate_children=False)
    #~ while gtk.events_pending():
      #~ gtk.main_iteration(block=True) # False or True, is bad here
  else: tda.queue_draw() # more responsive

def initStatusHist(indatfile):
  global window, status_txts, zmxrange_history, zmxrange_default, zmxrange_current, current_xmarker
  status_txts = [] # reinit
  statuslabel = get_descendant(window, "statuslabel", level=0, doPrint=False)
  status_txts.append(statuslabel) #[0]
  fslashinds = [i for i,c in enumerate(indatfile) if c=='/']
  if (fslashinds[-2]): statset = indatfile[fslashinds[-2]+1:]
  else: statset = indatfile
  status_txts.append(statset) #[1]
  status_txts.extend(["", "", ""]) #[2], [3], [4] ; initialize the other fields here too
  zmxrange_history = [] ; zmxrange_history.append(zmxrange_default); zmxrange_current = 0 # reinit
  current_xmarker = 0
  status_txts[2] = getZoomXRangeString()


# helper vertical line / marqee / editing cursor
def on_mouse_move(widget, event):
  global winmousepos, tracks, last_track_mousedover, current_xpos_rel, zmxrange_history, zmxrange_current, status_txts
  if event.is_hint:
    x, y, state = event.window.get_pointer()
  else:
    x = event.x; y = event.y
    state = event.state
  #if pixmap != None: # state & gtk.gdk.BUTTON1_MASK and
  # is child is detached, ret is ()!
  if not(widget.get_child_detached()):
    ret = widget.translate_coordinates(widget.get_child(), int(x), int(y))
    tx, ty = ret
    winmousepos = (tx, ty, state) #draw_cursor(widget, x, y)
    last_track_mousedover = widget
    # also calc current_xpos_rel here
    tda = last_track_mousedover.get_child()
    dx, dy, dw, dh = tda.get_allocation()
    zmxrL, zmxrR = zmxrange_history[zmxrange_current]
    zmxrw = zmxrR - zmxrL
    current_xpos_rel = zmxrL+(float(winmousepos[0])/dw)*zmxrw
    status_txts[3] = "%.08f" % (current_xpos_rel)
    #
    widget.set_shadow_type(gtk.SHADOW_IN) #drag_highlight()
    gobject.idle_add(refreshTracksDraw) # much better responsiveness than if called directly!
  return True # True so it doesn't propagate further

# to prevent some problems with enter/leave events not being sequential,
# don't use enter_ at all - use mouse_move above to set the highlight,
# and use the leave to reset - which also handles out-of-window moves;
# that should make it a bit more responsive...
def on_mouse_enter_track(widget, event):
  #~ global last_track_mousedover, tracks
  #~ #print "on_mouse_enter_track", widget
  #~ #for ttc in tracks: ttc.drag_unhighlight()
  #~ # prevent some problems with enter/leave events not being sequential?: no dice here
  #~ # reset all first:
  #~ last_track_mousedover = None
  #~ for ttc in tracks:
    #~ widget.set_shadow_type(gtk.SHADOW_NONE)
  #~ widget.set_shadow_type(gtk.SHADOW_IN) #drag_highlight()
  #~ last_track_mousedover = widget
  pass

def on_mouse_leave_track(widget, event):
  global last_track_mousedover
  #print "on_mouse_leave_track", widget
  # prevent some problems with enter/leave events not being sequential
  if (last_track_mousedover == widget):
    last_track_mousedover = None
    widget.set_shadow_type(gtk.SHADOW_NONE) #drag_unhighlight()

def on_mouse_scroll_wheel(widget, event):
  global zoomIOfactor, panLRfactor, SHIFT_PRESSED
  #print "on_mouse_scroll_wheel", event
  # wheel up down is otherwise used to scroll the scrolledwindow;
  # so make the zooms only if shift is pressed too - although
  # even that makes zoom-in work only if scrollbar is at top,
  # and zoom-out only is scrollbar is at bottom:
  if (event.direction == gtk.gdk.SCROLL_UP):
    if SHIFT_PRESSED: ZoomAroundXlocPosition(zoomin=True, zfactor = zoomIOfactor)
  elif (event.direction == gtk.gdk.SCROLL_DOWN):
    if SHIFT_PRESSED: ZoomAroundXlocPosition(zoomin=False, zfactor = zoomIOfactor)
  elif (event.direction == gtk.gdk.SCROLL_LEFT):
    PanXrangeLR(panleft=True, pfactor = panLRfactor)
  elif (event.direction == gtk.gdk.SCROLL_RIGHT):
    PanXrangeLR(panleft=False, pfactor = panLRfactor)

def on_button_press(widget, event):
  global zmxrange_lastmus, SHIFT_PRESSED, isZoomXSelecting
  #print("on_button_press", event, widget)
  widget.cdelta_over = (); widget.cdelta = (); widget.delta = (); widget.selrelxrange = () # init here
  if ((event.button == 1) and not(SHIFT_PRESSED)): # 1: left-click
    # better to do translate here, to avoid problems with negative x in some widgets in da_draw
    ret = widget.translate_coordinates(widget.get_child(), int(event.x), int(event.y))
    if ret != ():
      tx, ty = ret
      # if tx is negative here, means we've click on the handlebox bar;
      # in that case, do NOT start selecting!
      if (tx>=0):
        zmxrange_lastmus = (tx, ty, widget)
        isZoomXSelecting = True
  #elif event.button == 4: print "UP" # mouse wheel up? NOPE
  return False # False so others? YES, otherwise with true, handlebox detach does not work!

def on_button_release(widget, event):
  global zmxrange_lastmus, SHIFT_PRESSED, isZoomXSelecting, status_txts
  # note: even if we release over another widget, it's still the originator
  # of the button_press that shows up as widget here!
  # to detect if we've released outside of the track, calc delta height,
  # but that is probably best done when the cursor/marquee is calced
  #print("on_button_release", isZoomXSelecting, widget.cdelta, widget.cdelta_over, widget.delta)
  if ((event.button == 1) and isZoomXSelecting): # 1: left-click
    isZoomXSelecting = False
    zmxrange_lastmus = None
    status_txts[4] = "[ , ]";
    if widget.cdelta_over != (): # now should be nearly same as cdelta[0]<1; telling us if x position during drag changed at all? nope - that is still delta[0]! (cdelta is like position, more-less)
      if not(widget.cdelta_over[0] or widget.cdelta_over[1] or (abs(widget.delta[0])<1)): # also add threshold here
        doNewZoomXRange(widget)
      else:
        # refresh tracks anyways if not doing zoomx, so end of selection is indicated
        refreshTracksDraw()
    else: refreshTracksDraw()
  return True # False so others?

def updateStatusLabelTxt():
  global status_txts
  statuslabel = status_txts[0]
  statuslabel.set_text(" ".join(status_txts[1:]))
  #x, y, width, height = statuslabel.get_allocation()
  #statuslabel.queue_draw_area(x, y, width, height)

def doNewZoomXRange(widget):
  global tracks, zmxrange_history, zmxrange_current, status_txts, window
  # take the first track? - we have widget; but they should all have selrelxrange
  currange = zmxrange_history[zmxrange_current]
  currellen = currange[1]-currange[0]
  nrleft = currange[0]+widget.selrelxrange[0]*currellen
  nrright = currange[0]+widget.selrelxrange[1]*currellen
  newrange = (nrleft, nrright)
  AddXrangeToHistory(newrange)
  doStepZoomXRange("doNewZoomXRange")

def AddXrangeToHistory(newrange):
  global zmxrange_history, zmxrange_current
  zmxrange_current+=1 # also helps so we can never overwrite zmxrange_current=0
  if ( len(zmxrange_history)-1 < zmxrange_current ):
    zmxrange_history.append(None)
  zmxrange_history[zmxrange_current] = newrange;

def addCurrentXrangeToHistory():
  global zmxrange_history, zmxrange_current, status_txts
  newrange = zmxrange_history[zmxrange_current]
  AddXrangeToHistory(newrange)
  # to make sure keypress action is indicated
  status_txts[2] = getZoomXRangeString()
  gobject.idle_add(updateStatusLabelTxt)

def resetZoomXRange():
  global zmxrange_history, zmxrange_default, zmxrange_current
  if (len(zmxrange_history) > 1):
    zmxrange_history = [] ; zmxrange_history.append(zmxrange_default); zmxrange_current = 0 # reinit
    doStepZoomXRange("resetZoomXRange")

def stepZoomXRangeNext():
  global zmxrange_history, zmxrange_current
  maxlimit = len(zmxrange_history)-1
  if (zmxrange_current >= maxlimit):
    zmxrange_current = maxlimit
    return # no redraw here
  else: zmxrange_current+=1
  doStepZoomXRange("stepZoomXRangeNext")

def stepZoomXRangePrev():
  global zmxrange_current
  if (zmxrange_current <= 0):
    zmxrange_current = 0
    return # no redraw here
  else: zmxrange_current-=1
  doStepZoomXRange("stepZoomXRangePrev")

def stepZoomXRangeFirst():
  global zmxrange_current
  zmxrange_current = 0
  doStepZoomXRange("stepZoomXRangeFirst")

def doStepZoomXRange(printstr="doStepZoomXRange", blocking=False):
  global status_txts, zmxrange_lastcmd
  toggleWindowTitleWorkingStatus()
  status_txts[2] = getZoomXRangeString()
  rerenderXnuplotTracks(blocking=blocking) #refreshTracksDraw()
  zmxrange_lastcmd = printstr
  #print "%s: %s" % (printstr, status_txts[2])
  toggleWindowTitleWorkingStatus()

def getZoomXRangeString():
  global zmxrange_history, zmxrange_current
  return "zxrh[%d/%d] = (%.06f, %.06f)" % (zmxrange_current+1, len(zmxrange_history), zmxrange_history[zmxrange_current][0], zmxrange_history[zmxrange_current][1])

def toggleAutoYRange():
  global last_track_mousedover, tracks, xgplots
  #print "toggleAutoYRange", str(last_track_mousedover)
  if last_track_mousedover is not None:
    #print gtk.Buildable.get_name(last_track_mousedover)
    toggleWindowTitleWorkingStatus()
    ix = tracks.index(last_track_mousedover) # ; ttc = last_track_mousedover
    xgplot = xgplots[ix]
    if (xgplot.myyrange == xgplot.origyrange):
      xgplot.myyrange = "set yrange [*:*]"
    else: xgplot.myyrange = xgplot.origyrange
    rerenderXnuplotTrack(ix)
    toggleWindowTitleWorkingStatus()

def toggleWindowTitleWorkingStatus():
  global window, owint
  if (window.get_title() == owint):
    window.set_title("%s [WORKING]" % (owint))
    #window.get_window().invalidate_rect(window.get_allocation(), False) #process_updates(update_children=False) # get gtk.gdk.Window/GdkWindow? no dice, cannot speed up set_title!
    gtk.gdk.window_process_all_updates() # THIS speeds up the title redraw! Now it's more accurate!
  else:
    window.set_title(owint)

def ZoomAroundXlocPosition(zoomin=True, zfactor = 0.1):
  global zmxrange_history, zmxrange_current, winmousepos, zmxrange_lastcmd, last_track_mousedover, current_xpos_rel
  # zoomin=False means zoom out
  # zfactor = 0.1 # percent (1.0 = 100) of range to zoom in/out
  # (winmousepos should be translated as local widget coordinates)
  if last_track_mousedover is None:
    return # bail out early, as last_track is used for reference
  tda = last_track_mousedover.get_child()
  dx, dy, dw, dh = tda.get_allocation()
  # deduce zoom in/out: -1 in, +1 out
  zio = -1 if zoomin else 1
  zmxrL, zmxrR = zmxrange_history[zmxrange_current]
  zmxrw = zmxrR - zmxrL
  #current_xpos_rel = zmxrL+(float(winmousepos[0])/dw)*zmxrw # have it already now (in mouse_move)!
  # length of delta xpos to range edges:
  ldxposL, ldxposR = current_xpos_rel-zmxrL, zmxrR-current_xpos_rel
  ldxposLF, ldxposRF = (1+zio*zfactor)*ldxposL, (1+zio*zfactor)*ldxposR
  # new xrange borders/edges:
  nxrL, nxrR = current_xpos_rel-ldxposLF, current_xpos_rel+ldxposRF
  #nxrW = nxrR-nxrL
  #newrange = (nxrL, nxrR) # truncate new borders to (0, 1) range:
  newrange = (nxrL if (nxrL>=0) else 0, nxrR if (nxrR<=1) else 1)
  # only update if different from current xrange:
  if (newrange != zmxrange_history[zmxrange_current]):
    # check if add current xrange to history - so this (and subsequent)
    # ZoomArounds will change that (current) history entry
    if not(zmxrange_lastcmd in ["ZoomAroundXlocPosition", "PanXrangeLR", "showXrangeCenteredAtPosition"]):
      AddXrangeToHistory(zmxrange_history[zmxrange_current])
    # overwrite current history entry with newrange
    zmxrange_history[zmxrange_current] = newrange
    # execute (calls rerenderxnuplot, as we change range):
    doStepZoomXRange("ZoomAroundXlocPosition")

def PanXrangeLR(panleft=True, pfactor = 0.1):
  global zmxrange_history, zmxrange_current
  zmxrL, zmxrR = zmxrange_history[zmxrange_current]
  zmxrw = zmxrR - zmxrL
  plr = -1 if panleft else 1
  nxrL, nxrR = zmxrL+plr*pfactor*zmxrw, zmxrR+plr*pfactor*zmxrw
  # only perform if we don't go outside of the 0,1 boundaries
  if not( (nxrL<0) or (nxrR>1) ):
    newrange = nxrL, nxrR
    # only update if different from current xrange:
    if (newrange != zmxrange_history[zmxrange_current]):
      # check if add current xrange to history - so this (and subsequent)
      # ZoomArounds will change that (current) history entry
      if not(zmxrange_lastcmd in ["ZoomAroundXlocPosition", "PanXrangeLR", "showXrangeCenteredAtPosition"]):
        AddXrangeToHistory(zmxrange_history[zmxrange_current])
      # overwrite current history entry with newrange
      zmxrange_history[zmxrange_current] = newrange
      # execute (calls rerenderxnuplot, as we change range):
      doStepZoomXRange("PanXrangeLR")

def showXrangeCenteredAtPosition(xpos, blocking=False):
  global zmxrange_history, zmxrange_current, zmxrange_lastcmd
  # xpos expected to be relative, range 0.0:1.0
  zmxrL, zmxrR = zmxrange_history[zmxrange_current]
  zmxrw = zmxrR - zmxrL
  nxrL, nxrR = xpos-zmxrw/2. , xpos+zmxrw/2.
  # only perform if we don't go outside of the 0,1 boundaries? now do with:
  if True: # not( (nxrL<0) or (nxrR>1) ):
    newrange = nxrL, nxrR
    # only update if different from current xrange:
    if (newrange != zmxrange_history[zmxrange_current]):
      # check if add current xrange to history - so this (and subsequent)
      # ZoomArounds will change that (current) history entry
      if not(zmxrange_lastcmd in ["ZoomAroundXlocPosition", "PanXrangeLR", "showXrangeCenteredAtPosition"]):
        AddXrangeToHistory(zmxrange_history[zmxrange_current])
      # overwrite current history entry with newrange
      zmxrange_history[zmxrange_current] = newrange
      # execute (calls rerenderxnuplot, as we change range):
      doStepZoomXRange("showXrangeCenteredAtPosition", blocking=blocking)

def addMarkerAtXlocPosition():
  global last_track_mousedover, current_xpos_rel, xmarkers
  if last_track_mousedover is None:
    return # bail out early, as last_track is used for reference
  xmarkers.appdxrel.append(current_xpos_rel)
  doStepZoomXRange("addMarkerAtXlocPosition")

def clearUserXmarkers():
  global xmarkers
  xmarkers.appdxrel = []
  doStepZoomXRange("clearUserXmarkers")

def jumpCenterNextXmarker():
  global xmarkers, current_xmarker
  # len(np.array) - same as np.array.shape (len,) here
  # here shape is (3,), so len = np.array.shape[0]
  all_xmarkers = np.concatenate( (xmarkers.dataxrel, xmarkers.appdxrel) )
  len_all_xmarkers = len(all_xmarkers) #all_xmarkers.shape[0]
  if not(len_all_xmarkers > 0):
    return # bail out early
  # in case of cleared markers:
  if current_xmarker > len_all_xmarkers-1: current_xmarker = len_all_xmarkers-1
  current_xmarker = (current_xmarker+1) % len_all_xmarkers
  current_xmarker_pos = all_xmarkers[current_xmarker]
  showXrangeCenteredAtPosition(current_xmarker_pos)

def jumpCenterPrevXmarker():
  global xmarkers, current_xmarker
  all_xmarkers = np.concatenate( (xmarkers.dataxrel, xmarkers.appdxrel) )
  len_all_xmarkers = len(all_xmarkers) #all_xmarkers.shape[0]
  if not(len_all_xmarkers > 0):
    return # bail out early
  # in case of cleared markers:
  if current_xmarker > len_all_xmarkers-1: current_xmarker = len_all_xmarkers-1
  if current_xmarker == 0: current_xmarker = len_all_xmarkers
  current_xmarker = (current_xmarker+1) % len_all_xmarkers
  current_xmarker_pos = all_xmarkers[current_xmarker]
  showXrangeCenteredAtPosition(current_xmarker_pos)

def exportAllXmarkersAtRange(inrange=[0, 0.005]):
  global xmarkers, zmxrange_history, zmxrange_current, zmxrange_lastcmd
  all_xmarkers = np.concatenate( (xmarkers.dataxrel, xmarkers.appdxrel) )
  len_all_xmarkers = len(all_xmarkers) #all_xmarkers.shape[0]
  if not(len_all_xmarkers > 0):
    return # bail out early
  # in this case, first temporarily replace the current zoom
  # with requested inrange, then loop through all the markers,
  # show and export corresponding range, then restore original
  # zoom range; also sort all xmarkers
  # cheat and lie about zmxrange_lastcmd too - to avoid add to xrange history; but don't restore it at end
  origxrange = zmxrange_history[zmxrange_current]
  zmxrange_history[zmxrange_current] = inrange;
  oldlastcmd = zmxrange_lastcmd
  zmxrange_lastcmd = "showXrangeCenteredAtPosition"
  all_xmarkers_sorted = np.sort(all_xmarkers)
  for ix in range(0,len_all_xmarkers): # goes to len-1
    ixmark_pos = all_xmarkers_sorted[ix]
    showXrangeCenteredAtPosition(ixmark_pos, blocking=True)
    fns="m%02d" % (ix)
    # MUST have this wait here - otherwise:
    #  multitrack_plot.py:74: GtkWarning:  drawable is not a native X11 window
    #  glib.GError: Fatal error reading PNG image file: Not a PNG file
    #  multitrack_plot.py:912: GtkWarning: gtk_widget_size_allocate(): attempt to allocate widget with width -11 and height 148
    #  gnuplot: warning: Too many axis ticks requested (>6)
    while gtk.events_pending():
      gtk.main_iteration(block=True) # is good here
    generateEntireImage(fnsuffix=fns, prompt=False, blocking=True)
  zmxrange_history[zmxrange_current] = origxrange
  doStepZoomXRange("exportAllXmarkersAtRange")


def refreshTracksDraw():
  global tracks
  for ttc in tracks:
    tda = ttc.get_child()
    da_draw(tda, -3, -3, 0, 0)
  gobject.idle_add(updateStatusLabelTxt) # schedule later

# NumPy (two) structured arrays linearly interpolated over third;
# array A, timestamp field A, value field A; same for B; array I, interp. field I
def getNPsaLinInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis):
  # ats, avals, bts, bvals - field names in aa, bb,
  # (since they get lost for a single column a['x'])
  # create union of both timestamp arrays as tsz
  #~ ntz = np.union1d(aa[ats], bb[bts]) # now ii[iis]
  # interpolate `a` values over tsz
  a_z = np.interp(ii[iis], aa[ats], aa[avals])
  # interpolate `b` values over tsz
  b_z = np.interp(ii[iis], bb[bts], bb[bvals])
  # create structured arrays for resampled `a` and `b`,
  # indexed against tsz timestamps;
  # append also iis name to new value names (avals+iis, ...)? Nah,
  # gets difficult to select afterwards ...
  # below more correct for differing types;
  # first pass in creation must be without changing dtypes (else wrong values!)
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  #return a_npz, b_npz
  # in second pass, we can return asarray which will correctly cast values to orig. types
  return \
    np.asarray( a_npz, dtype=[(iis, ii[iis].dtype), (avals, aa[avals].dtype)] ), \
    np.asarray( b_npz, dtype=[(iis, ii[iis].dtype), (bvals, bb[bvals].dtype)] )

# the above gives linear interpolation; here we'd need null (no) interpolation
# http://stackoverflow.com/questions/12240634/what-is-the-best-drop-in-replacement-for-numpy-interp-if-i-want-the-null-interpo
# these is one such in scipy: scipy.interpolate.interp1d
# In general, using numpy, we could just copy-paste (without installing scipy):
#  _Interpolator1D(object): # ./scipy/interpolate/polyint.py
#  interp1d(_Interpolator1D): # ./scipy/interpolate/interpolate.py
# and it will work - but only for linear interpolation...
# BUT - if we want the null (kind='zero') interpolation,
# that uses interpolate.py: def splmake( -> def spleval( -> _fitpack._bspleval(
# so - unfortunately, splmake needs _fitpack.so ... which
# means that scipy must be installed to get zero interpolation!
# natty: sudo apt-get install libamd2.2.0 libumfpack5.4.0 python-scipy
# however, SO:12240634 also points to a hack of the linear interpolator
# for a numpy-only version - it works, but is a bit slower (see test below);
# and in the end, it turns out zero interpolator can delay values
# for arrays with x out of bounds; and what I need is actually nearest!
# nearest (scipy/numpy) is slower than np.interp, but not much;
# so worth copying the classes for! (done below; see below for tests)...
# getNPsaNearestInterpolatedOver seems to give me nan for out-of-bounds, though...
# better to use 0 as fill_value instead of np.nan; because we can then return
# np.asarray with the original types! (if we return to int, gnuplot may have it easier..)
# BIT, there is a problem with this, too! Namely if some value is closer to another;
# then it could be pulled in early, thus messing up the calc!:
# wbpz array([(0.033108, 176495), (0.03336, 176498), (0.033723, 176496), (0.034099, 176236)],
# rbpz array([(0.033108, 169415), (0.03336, 169415), (0.033723, 166309), (0.034099, 166309)],
# wrbpsz array([           7080,              7083,              10187,               9927])
# jump to 10000 there because for r 0.033723 is closer to 0.034099, and pulls that value!
# so MUST use zero - but it delays even where it shouldn't!
def getNPsaNearestInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis, fill_value=0):
  fa = scipy_interp1d(aa[ats], aa[avals], kind='nearest', copy=True, bounds_error=False, fill_value=fill_value)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='nearest', copy=True, bounds_error=False, fill_value=fill_value)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  # first pass in creation must be without changing dtypes (else wrong values!)
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  # in second pass, we can return asarray which will correctly cast values to orig. types
  return \
    np.asarray( a_npz, dtype=[(iis, ii[iis].dtype), (avals, aa[avals].dtype)] ), \
    np.asarray( b_npz, dtype=[(iis, ii[iis].dtype), (bvals, bb[bvals].dtype)] )

# seemingly I got the zero interpolation fixed (below, with np.concatenate), so let's try it?
# actually - even THAT shows same problems as nearest - likely because of use of np.searchsorted !
def getNPsaZeroInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis, fill_value=0):
  # must use bounds_error=False, else ValueError("A value in x_new is above the interpolation "...)
  # but then, it can "delay" values in the problematic array... (fixed w/ zeroB np.concatenate)
  # keep fill_value at 0 for out-of-bound - better for difference calc
  fa = scipy_interp1d(aa[ats], aa[avals], kind='zeroB', copy=True, fill_value=fill_value, bounds_error=False)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='zeroB', copy=True, fill_value=fill_value, bounds_error=False)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  # first pass in creation must be without changing dtypes (else wrong values!)
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  #return a_npz, b_npz
  # in second pass, we can return asarray which will correctly cast values to orig. types
  return \
    np.asarray( a_npz, dtype=[(iis, ii[iis].dtype), (avals, aa[avals].dtype)] ), \
    np.asarray( b_npz, dtype=[(iis, ii[iis].dtype), (bvals, bb[bvals].dtype)] )

# well, this has been tested, *should* work - but it's not vectorized: (below for tests)
def getNPsaZeroCInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis, fill_value=0.0):
  # http://stackoverflow.com/questions/12200580/numpy-function-for-simultaneous-max-and-min
  # arrays are sorted by x - even if x values may repeat;
  # so instead of min/max, I can just use first/last elem
  atmin, atmax = aa[ats][0], aa[ats][-1]
  btmin, btmax = bb[bts][0], bb[bts][-1]
  # compose interpolated versions via list append
  aail = [] ; lastvala = None
  bbil = [] ; lastvalb = None
  for itz in ii[iis]:
    a_outrange = (itz<atmin or itz>atmax)
    a_exists = itz in aa[ats]
    b_outrange = (itz<btmin or itz>btmax)
    b_exists = itz in bb[bts]
    #~ print itz, a_outrange, a_exists, lastvala
    # [-1:] prefers the last element, if there are multiple with same x (timestamp)
    #val = (itz,fill_value) if a_outrange else aa[aa[ats]==itz][-1:][0] if a_exists else (itz,lastval[1])
    # this code works - but creates array of array of tuple [ [()], [()], .. ]
    #if a_outrange:
    #  val = np.array( [(itz,fill_value)], dtype=[(iis, ii[iis].dtype), (ats, aa[ats].dtype)] )
    #elif a_exists:
    #  val = aa[ aa[ats]==itz ][-1:]
    #  pprint(type(val))
    #else:
    #  val = np.array( [(itz,lastval[0][1])], dtype=[(iis, ii[iis].dtype), (ats, aa[ats].dtype)] )
    # just use plain tuples in array
    if a_outrange:
      vala = (itz,fill_value)
    elif a_exists:
      vala = aa[ aa[ats]==itz ][[ats, avals]][-1:] # val[0] here is otherwise not tuple, it's np.void/array!
      vala = tuple( vala[0] )
    else:
      vala = (itz, lastvala[1])
    aail.append(vala)
    lastvala = vala
    if b_outrange:
      valb = (itz,fill_value)
    elif b_exists:
      valb = bb[ bb[bts]==itz ][[bts, bvals]][-1:] # val[0] here is otherwise not tuple, it's np.void/array!
      valb = tuple( valb[0] )
    else:
      valb = (itz, lastvalb[1])
    bbil.append(valb)
    lastvalb = valb
    #print itz, a_outrange, a_exists, vala, b_outrange, b_exists, valb
  print aail[:10]
  a_npz = np.array( aail, dtype=[(iis, ii[iis].dtype), (avals, aa[avals].dtype)])
  b_npz = np.array( bbil, dtype=[(iis, ii[iis].dtype), (bvals, bb[bvals].dtype)])
  return a_npz, b_npz

# without prints, with corrections:
def getNPsaZeroDInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis, fill_value=0.0):
  atsu,atsuind,atsuinv= np.unique(aa[ats], return_index=True, return_inverse=True)
  btsu,btsuind,btsuinv= np.unique(bb[bts], return_index=True, return_inverse=True)
  ia = ii[iis] ; av = aa[avals]; bv = bb[bvals]
  npnza = np.nonzero( np.setmember1d(ia, atsu) )[0]
  npnzb = np.nonzero( np.setmember1d(ia, btsu) )[0] # unique: removes duplicates
  out_of_bounds_a = np.logical_or(ia < atsu[0], ia > atsu[-1])
  out_of_bounds_b = np.logical_or(ia < btsu[0], ia > btsu[-1])
  npnzae = np.ediff1d( npnza , to_end=[1]*(len(atsu)-len(npnza)+1) )
  npnzbe = np.ediff1d( npnzb , to_end=[1]*(len(btsu)-len(npnzb)+1) )
  ainds = np.repeat( np.arange(0, len(atsu)), npnzae ) #indices   #(aa[ats], npnzae)#timestamps
  binds = np.repeat( np.arange(0, len(btsu)), npnzbe ) #indices
  avalid = av[np.zeros(len(ia), dtype=np.intp)]
  avalid[~out_of_bounds_a] = av[atsuind][ainds]; avalid[out_of_bounds_a] = fill_value
  bvalid = bv[np.zeros(len(ia), dtype=np.intp)]
  bvalid[~out_of_bounds_b] = bv[btsuind][binds]; bvalid[out_of_bounds_b] = fill_value
  a_npz = np.zeros((len(ia),), dtype=[(iis, ia.dtype), (avals, av.dtype)])
  a_npz[iis] = ia; a_npz[avals] = avalid;
  b_npz = np.zeros((len(ia),), dtype=[(iis, ia.dtype), (bvals, bv.dtype)])
  b_npz[iis] = ia; b_npz[bvals] = bvalid;
  return a_npz, b_npz

def getNPsaPieceCumSum(aa, ats, avals, threshold=0.5):
  # will count in those at same location, too
  d = np.ediff1d(np.concatenate(([0.], aa[ats], [np.inf]))) # timestamps are floats, and monotonically increasing sequence, so add +infinity as last, so last entry is counted (in the indexes) too
  #print d
  #print np.nonzero(d>=threshold)[0]
  n = np.nonzero(d>=threshold)[0]-1 # also delay/offset 1 sample early
  n[np.nonzero(n<0)[0]] = 0 # in case it matches at index 0, which by here will be moved to -1 (this could be non-empty, if first at 0.0 matches criteria)
  #print n
  s = np.cumsum(aa[avals])
  dv = np.concatenate(([0], np.ediff1d(np.concatenate(([0], s[n]))) ))
  # pre-allocate output, and adding its fields
  #outarr = np.zeros(len(dv), dtype=aa.dtype) #returns all fields!
  outarr = np.zeros(len(dv), dtype=[(ats, aa[ats].dtype), (avals, aa[avals].dtype)]) #returns only requested fields
  tn = aa[ats][n]
  #print aa.shape, dv.shape, tn.shape, outarr.shape
  outarr[ats] = np.concatenate(([0], tn))
  outarr[avals] = dv
  return outarr


# test for rearrangeNumpyArrFields:
#a = np.array([ (1, 4.0, "Hello"),
               #(-1, -1.0, "World")],
       #dtype=[("f0", ">i4"), ("f1", ">f4"), ("S2", "|S10")])
#want_rearr = ['S2', 'f1', 'f0']
#print "a ", pformat(a)
#rarr = rearrangeNumpyArrFields(a, want_rearr)
#print "rarr ", pformat(rarr)
def rearrangeNumpyArrFields(inarr, want_rearr):
  # get rearranged dtypes:
  rdtypesa = [] #; rdtypesd = {}
  for wrs in want_rearr:
    for idname, idtype in inarr.dtype.fields.items():
      if idname == wrs:
        #rdtypesd[idname] = idtype # is not an OrderedDict, so no matter
        rdtypesa.append( (idname, idtype[0]) )
        continue
  #print "rD ", rdtypesd, "\nrA ", rdtypesa
  #~ ra = [np.array(inarr[rdt[0]]).view([rdt]) for rdt in rdtypesa]
  #print "ra ", ra
  #~ return nprf.merge_arrays( ( ra ) )
  # merge_arrays is a bit slow, even if written like this!
  #return nprf.merge_arrays( ( [np.array(inarr[rdt[0]]).view([rdt]) for rdt in rdtypesa] ) )
  # prob. better to preallocate new array with np.zeros (calloc)
  outarr = np.zeros(inarr.shape, dtype=rdtypesa)
  for wrs in want_rearr: outarr[wrs] = inarr[wrs]
  return outarr


def generateEntireImage(fnsuffix="", prompt=True, blocking=False):
  global vb1, window, indatfile, twindow
  toggleWindowTitleWorkingStatus()
  fndir = os.path.dirname(os.path.abspath(indatfile))
  fnbase = os.path.basename(indatfile)
  #fnexts = os.path.splitext(fnbase) # fnroot, fnext
  tstamp = time.strftime('%F-%H-%M-%S') # takes timestamp anytime it runs
  if (fnsuffix==""): fnsuffix=tstamp
  fnbasenew = "mtp_%s_%s.png" % (fnbase.replace(".", "-"), fnsuffix)
  fnpathnew = os.path.join(fndir, fnbasenew)
  outfn_final = fnpathnew
  if prompt:
    dialog = gtk.Dialog(title="Save image", parent=window, flags= gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT, buttons=(gtk.STOCK_OK, gtk.RESPONSE_OK, gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL))
    dialog.set_default_response(gtk.RESPONSE_OK) # for easier keyboard; but also needs to be set first above for the tab order!
    label = gtk.Label("Save .png image location:")
    label.set_alignment(0.02,0.5) # left-aligned
    dialog.vbox.pack_start(label, gtk.TRUE, gtk.TRUE, 0)
    entry = gtk.Entry()
    entry.set_width_chars(len(fnpathnew)+5) # no pixel width!
    entry.set_text(fnpathnew)
    def entact(entry):
      btnOK = None
      for ibt in dialog.action_area.get_children():
        if gtk.STOCK_OK == ibt.get_label():
          btnOK = ibt ; break
      btnOK.clicked() # emit clicked OK signal
    entry.connect("activate", entact) # activate - when Enter pressed
    dialog.vbox.pack_start(entry, gtk.TRUE, gtk.TRUE, 0)
    dialog.show_all()
    entry.set_position(fnpathnew.rfind('.')) # also cursor before last dot; needs to be set after the show!
    response = dialog.run()
    outfn_final = entry.get_text()
    dialog.destroy()
    # could be other responses like delete - so check if not ok:
    if response != gtk.RESPONSE_OK: # == gtk.RESPONSE_CANCEL:
      # bail out early - do not render:
      toggleWindowTitleWorkingStatus()
      return
  statushbox = get_descendant(window, "statushbox", level=0, doPrint=False)
  #~ print gtk.gdk.Pixbuf.get_from_drawable()
  # NOTE: while this seems to give the correct size;
  # .get_snapshot of vb1 gets obscured by window size!
  # SO - should render vb1 to OffscreenWindow!
  shbpixmap = statushbox.get_snapshot(clip_rect=None)
  vb1pixmap = vb1.get_snapshot(clip_rect=None)
  shbw, shbh = shbpixmap.get_size()
  vb1w, vb1h = vb1pixmap.get_size()
  nw = vb1w #max(shbw,vb1w)
  nh = shbh + vb1h
  #~ print statushbox.is_drawable(), shbpixmap.get_size(), # has them, if window is instantiated; not so in python terminal with just new!
  #~ print vb1.is_drawable(), vb1pixmap.get_size()
  # re-rendering vb1 offscreen; note that it MUST have show_all(),
  # otherwise portions are missing even when offscreen!
  # ALSO - the .add() generates multitrack_plot.py:849: GtkWarning: Attempting to add a widget with type GtkVBox to a container of type GtkOffscreenWindow, but the widget is already inside a container of type GtkViewport, the GTK+ FAQ at http://library.gnome.org/devel/gtk-faq/stable/ explains how to reparent a widget
  # however, reparent() raises parent != NULL exception... GtkWarning: IA__gtk_widget_reparent: assertion `widget->parent != NULL' failed
  # and then have to also reparent back to window - and then that fails, so vb1 is gone!
  # but with reparent we have OK png, with add - again obscured with black!
  # same thing but set_parent instead of reparent - AGAIN obscured!
  # Also, must reparent vb1 back before twindow is destroyed, AND it must be reparented to its original parent (not window)!
  # also, always re-render after resize, else export fails!
  # ANYWAYS - the trick here seems to be - not reparent; but A: doing parent.remove(child); then newparent.add(child); then newparent.remove(child); then parent.add(child) - where parent is the viewport, and newparent the offscreen window! then most problems go away - except after resize of window and re-render, then RuntimeError: could not create GdkPixmap; note with this setup with remove, reparent segfaults!
  # (the resize problem may have to do with right scrollbar, and its influence on size... indeed it did)
  vp1 = vb1.get_parent()
  #~ print "A", vb1.get_allocation()
  twindow = gtk.OffscreenWindow()
  twindow.set_default_size(nw, nh)
  #with warnings.catch_warnings():
    #warnings.simplefilter("ignore")
  # "Remove the widget again (so we can reparent it later)"
  vp1.remove(vb1)
  twindow.add(vb1) #vb1.reparent(twindow)
  vb1.show_all()
  #~ print "B", vb1.get_allocation()
  twindow.show_all()
  # now, with change to ref. to window.window instead of tda.window, can
  # also call rerenderXnuplotTracks() also here in offscreen, so I can finally
  # get the accurate/proper bitmap as screen one! ACTUALLY, rerenderXnuplotTrack()
  # can in fact also use tda.window, still works OK! The only problem is that
  # it causes the cursor/marquee to be a bit displaced in the render, but nevermind that - without rerender, then the entire bitmap is sort of innacurate, with jagged edges.. actually, even without this rerender, the marquee/cursor is off (even with the jagged edges).. actually, fixed by using nw = vb1w (and fixing accordingly below! now looks ok...)
  # moving it before the remove doesn't do anything, really
  rerenderXnuplotTracks(blocking=blocking)
  vb1pixmap = vb1.get_snapshot(clip_rect=None)
  vb1w, vb1h = vb1pixmap.get_size() # and this!? strange, this kills outpixbuf?
  # yes, because everything after then needs to be recalced!
  # vb1w, vb1h: before 684 750; after 700 765
  nw = vb1w #max(shbw,vb1w)
  nh = shbh + vb1h
  twindow.remove(vb1)
  vp1.add(vb1) #vb1.reparent(vp1)
  #~ gobject.idle_add(twindow.destroy) # crashes things!
  twindow.destroy() # no problem; actually MUST be here, else X: 'BadWindow'!
  # create new output pixbuf via new pixmap
  # depth=-1 apparently only reads the depth info from input drawable;
  # input drawable only "determine default values for the new pixmap", does not copy pixels!
  outpixmap = gtk.gdk.Pixmap(drawable=shbpixmap, width=nw, height=nh, depth=-1) # outpixmap.get_size() ; depth=vb1pixmap.get_depth()
  outpixbuf = gtk.gdk.Pixbuf(gtk.gdk.COLORSPACE_RGB, has_alpha=True, bits_per_sample=8, width=nw, height=nh) # width/height of image in pixels; no get_size! get_width/height!
  # get_from drawable "Returns : the pixbuf or None on error"
  # if we pass the width=nw, it is bigger than shbw, and so we get None back!
  # so careful - else cannot append further!
  outpixbuf = outpixbuf.get_from_drawable(src=shbpixmap, cmap=shbpixmap.get_colormap(), src_x=0, src_y=0, dest_x=0, dest_y=0, width=min(shbw,nw), height=shbh)
  outpixbuf = outpixbuf.get_from_drawable(src=vb1pixmap, cmap=vb1pixmap.get_colormap(), src_x=0, src_y=0, dest_x=0, dest_y=shbh, width=nw, height=vb1h)
  outpixbuf.save(outfn_final, "png") # , options=None
  print("Saved %dx%d in %s" % (outpixbuf.get_width(), outpixbuf.get_height(), outfn_final))
  #~ vb1.show_all()
  #~ window.show_all()
  #~ vb1.queue_resize()
  toggleWindowTitleWorkingStatus()
  # now with the wait pending in RerenderXnuplotTrack, no need for these C/D:
  #~ print "C", vb1.get_allocation()
  #~ vb1.show_all()
  #~ window.show_all()
  #~ vb1.set_reallocate_redraws(needs_redraws=True)
  #~ print "D", vb1.get_allocation()
  #x, y, width, height = vb1.get_allocation()
  #vw,vh = vb1.get_size_request()
  #~ vb1a = vb1.get_allocation()
  #~ vx,vy,vw,vh = vb1a
  #~ vb1.queue_draw_area(vx,vy,vw,vh) # no invalidate_rect for vbox;
  #~ window.queue_resize()
  #~ gtk.gdk.Window.invalidate_rect(window.get_window(), window.get_allocation(), invalidate_children=True)
  #~ vb1.set_size_request(vw,vh) # no set_size
  #~ vb1.set_allocation(vb1a)
  #~ vb1.show_all()
  #~ #gobject.idle_add(vb1.set_reallocate_redraws, True) # no invalidate_rect for vbox; vb1.set_reallocate_redraws(needs_redraws=True) nowork
  # not needed anymore:
  #~ vb1.set_parent_window(window.get_window())
  #~ ww,wh = window.get_size_request()
  #~ window.set_size_request(vb1w+20,wh)
  #~ gtk.gdk.window_process_all_updates()




def buildTracksXnuplotData_Test():
  setupPlotData_Test()
  window.show() #.realize() # realize not enough for pixmp - must use show
  for ix in range(0,4):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    ttc = addTrack(color=gtk.gdk.Color(colstr), incanvas=None)
    tda = ttc.get_child()
    #tgps = gpscript.safe_substitute(dict(color=colstr)) #gpscript.format(color=colstr)
    x, y, width, height = tda.get_allocation() # w,h: 1,1 here!
    width, height = tda.get_size_request()
    tda.gpixbuf = getXnuplotPixbuf_Test("", ix, width, height) # add as new attribute
    tda.gpixmap = gtk.gdk.Pixmap(tda.window, width, height) # add as new attribute
    tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    tda.connect("expose_event", da_expose_event)
    tda.connect("size_allocate", da_resize_event)

def setupPlotData_Test():
  global data #, xgplot
  x = np.linspace(0, 5.0 * np.pi, 200)
  y1 = np.sin(x)
  y2 = np.cos(x)
  data = np.column_stack((x, y1, y2)) # Make a 200-by-3 array.

def getXnuplotPixbuf_Test(tgps, ix, width, height):
  global data
  tsz = ""
  if (width>0 and height>0):
    tsz = "size {x},{y}".format(x=width,y=height)
  xgplot = xnuplot.Plot(autorefresh=False)
  # nb: size property is only for multiplot class!
  xgplot("set terminal png font ',9' %s" % (tsz))
  xgplot('set output "/dev/stdout"')
  xgplot('set tics in border mirror; set grid xtics ytics; set xtics offset 0,2; set ytics offset 2,0 left; set tmargin 0; set bmargin 0; set lmargin 0; set rmargin 0; set x2tics format ""; set y2tics format "";')
  if ix%2 == 0: xgplot.append(xnuplot.record(data, using=(0, 1), options="t'a' with lines"))
  xgplot.append(xnuplot.record(data, using=(0, 2), options="t'b' with lines"))
  imgdatstdout = xgplot.refresh()
  xgplot.close()
  loader = GdkPixbuf.PixbufLoader('png') #.new_with_type('png')
  loader.write(imgdatstdout)
  pixbuf = loader.get_pixbuf()
  loader.close()
  return pixbuf

def rerenderXnuplotTracks_Test():
  global window, tracks
  # window.get_size_request() is unchanged here!
  wx, wy, winw, winh = window.get_allocation()
  print "rerender XT", winw
  for ix in range(0,4):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    ttc = tracks[ix]
    tda = ttc.get_child()
    #tgps = gpscript.safe_substitute(dict(color=colstr)) #gpscript.format(color=colstr)
    x, y, width, height = tda.get_allocation() # w,h: was 1,1 here!
    width, height = tda.get_size_request()
    tda.gpixbuf = getXnuplotPixbuf_Test("", ix, winw, height) # add as new attribute
    tda.gpixmap = gtk.gdk.Pixmap(tda.window, winw, height) # add as new attribute
    tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    tda.window.invalidate_rect(tda.get_allocation(), invalidate_children=False)
  #window.window.invalidate_rect(window.get_allocation(), invalidate_children=True)



# .format chokes on key error - so Template for here; .format can go for {size} (it's last)
gpscript = Template('set terminal png font ",9" {size}; set output "/dev/stdout"; set tics in border mirror; set grid xtics ytics; set xtics offset 0,2; set ytics offset 4,0; set tmargin 0; set bmargin 0; set lmargin 0; set rmargin 0; set x2tics format ""; set y2tics format ""; plot sin({fact}*x) with lines lc rgb "${color}"\n')

def buildTracksGnuplot():
  window.show() #.realize() # realize not enough for pixmp - must use show
  for ix in range(0,4):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    ttc = addTrack(color=gtk.gdk.Color(colstr), incanvas=None)
    tda = ttc.get_child()
    tgps = gpscript.safe_substitute(dict(color=colstr)) #gpscript.format(color=colstr)
    x, y, width, height = tda.get_allocation() # w,h: 1,1 here!
    width, height = tda.get_size_request()
    tda.gpixbuf = getGnuplotPixbuf(tgps, ix, width, height) # add as new attribute
    tda.gpixmap = gtk.gdk.Pixmap(tda.window, width, height) # add as new attribute
    tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    tda.connect("expose_event", da_expose_event)
    tda.connect("size_allocate", da_resize_event)

def getGnuplotPixbuf(ingps, num, width=0, height=0):
  tsz = ""
  if (width>0 and height>0):
    tsz = "size {x},{y}".format(x=width,y=height)
  gscript = ingps.format(size=tsz, fact=num+1)
  proc = subprocess.Popen(
    ['gnuplot',], shell=True,
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
  )
  (imgdatstdout, stderr) = proc.communicate(gscript)
  if (stderr): print(stderr)
  loader = GdkPixbuf.PixbufLoader('png') #.new_with_type('png')
  loader.write(imgdatstdout)
  pixbuf = loader.get_pixbuf()
  loader.close()
  return pixbuf

def rerenderGnuplotTracks():
  global window, tracks
  # window.get_size_request() is unchanged here!
  wx, wy, winw, winh = window.get_allocation()
  print "rerender", winw
  for ix in range(0,4):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    ttc = tracks[ix]
    tda = ttc.get_child()
    tgps = gpscript.safe_substitute(dict(color=colstr))
    x, y, width, height = tda.get_allocation() # w,h: was 1,1 here!
    width, height = tda.get_size_request()
    tda.gpixbuf = getGnuplotPixbuf(tgps, ix, winw, height) # add as new attribute
    tda.gpixmap = gtk.gdk.Pixmap(tda.window, winw, height) # add as new attribute
    tda.gpixmap.draw_pixbuf(None, tda.gpixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    tda.window.invalidate_rect(tda.get_allocation(), invalidate_children=False)
  #window.window.invalidate_rect(window.get_allocation(), invalidate_children=True)

def da_resize_event(widget, rect):
  ww, wh = widget.get_size_request()
  # use allocation .height instead of size_request wh (seems more correct)
  # get_allocation() is actually now same as rect!
  # but after fixup, now after screenshow getting errors here for new pixmap!
  ax, ay, aw, ah = widget.get_allocation()
  new_pixbuf = widget.gpixbuf.scale_simple(rect.width, rect.height, gtk.gdk.INTERP_NEAREST)
  widget.gpixbuf = new_pixbuf
  # here widget.window could actually be none, right after the "screenshot!)
  # or rather, during it - as after it's all fine!
  # that is probably the resize being called on the widgets during add to offscreen window!
  # just bail out then? that seems to fix it - images still come in ok...
  if widget.window is not None:
    widget.gpixmap = gtk.gdk.Pixmap(widget.window, rect.width, rect.height) # must have, so window size changes propagate!
  #~ wpar = widget.get_parent() # the handle_box!? not really
  #~ pww, pwh = widget.translate_coordinates(wpar, ww, wh)
  #~ wpar.set_size_request(pww, pwh)

def da_expose_event(widget, event):
  x , y, width, height = event.area
  da_draw(widget, x , y, width, height)
  return False

def da_draw(widget, x , y, width, height):
  global window, winmousepos, zmxrange_lastmus, isZoomXSelecting, tracks, status_txts
  ww, wh = widget.get_size_request()
  wpar = widget.get_parent()
  xa, ya, widtha, heighta = widget.get_allocation()
  if not(width) or not(height) or (x==-3 and y==-3):
    if not(width): width = widtha
    if not(height): height = heighta
    if (x==-3 and y==-3): # a "signal" from other functions
      x = xa ; y = ya
  #~ widget.gpixmap = gtk.gdk.Pixmap(widget.window, width, wh) # must have, so window size changes propagate!
  #~ new_pixbuf = widget.gpixbuf.scale_simple(width, wh, gtk.gdk.INTERP_NEAREST)
  #~ # here the map should be 0,0 , 0,0 - else the scroll is screwed!
  # do NOT do translate_coordinates here, as we're using them repeated in children (and sometimes give neg. coords); do them where they're captured!
  widget.gpixmap.draw_pixbuf(None, widget.gpixbuf, 0, 0, 0, 0, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
  if winmousepos is not None: # cursor over the plot pixels..
    tcxy = (winmousepos[0], winmousepos[1])
    if tcxy == (): tx, ty = 0, 0
    else: tx, ty = tcxy
    style = widget.get_style()
    gc = style.fg_gc[gtk.STATE_NORMAL]
    cursor_gc = gtk.gdk.GC(widget.window)
    cursor_gc.set_dashes(1, (8, 8))
    cursor_gc.set_line_attributes(1, gtk.gdk.LINE_ON_OFF_DASH, gtk.gdk.CAP_BUTT, gtk.gdk.JOIN_MITER) # LINE_ON_OFF_DASH for "transparency" (no real alpha here)
    if isZoomXSelecting:
      otcxy = (zmxrange_lastmus[0], zmxrange_lastmus[1])
      if otcxy == (): otx, oty = 0, 0
      else: otx, oty = otcxy
      # add as new property; # works only on drag! keeps last value on single click:
      wpar.delta = (tx-otx, oty-ty)
      wpar.cdelta = (tx-x, ty-y) # criteria delta - for cancel of selection
      # seems widtha/heighta are right here; not ww/wh?!
      wpar.cdelta_over = ( ((wpar.cdelta[0]<0) or (abs(wpar.cdelta[0])>widtha)), ((wpar.cdelta[1]<0) or (abs(wpar.cdelta[1])>heighta)) )
      if (tx>otx): wpar.selrelxrange = (float(otx)/widtha, float(tx)/widtha)
      else: wpar.selrelxrange = (float(tx)/widtha, float(otx)/widtha)
      status_txts[4] = "[%d, %d]" % (wpar.delta[0], wpar.delta[1])
      if (wpar.cdelta_over[0] or wpar.cdelta_over[1]):
        cursor_gc.set_foreground(cursor_gc.get_colormap().alloc_color("#aaa"))
      else:
        cursor_gc.set_foreground(cursor_gc.get_colormap().alloc_color("#f00"))
      cursor_gc.set_background(cursor_gc.get_colormap().alloc_color("#fff"))
      widget.gpixmap.draw_line(cursor_gc, otx, 0, otx, height)
      cursor_gc.set_foreground(cursor_gc.get_colormap().alloc_color("#aaa"))
      widget.gpixmap.draw_line(cursor_gc, otx, ty, tx, ty)
    cursor_gc.set_foreground(cursor_gc.get_colormap().alloc_color("#aaa"))
    cursor_gc.set_background(cursor_gc.get_colormap().alloc_color("#fff"))
    widget.gpixmap.draw_line(cursor_gc, tx, 0, tx, height)
  widget.window.draw_drawable(widget.get_style().fg_gc[gtk.STATE_NORMAL],
                              widget.gpixmap, x, y, x, y, width, height)
  return False

def buildTracksMatplotlib():
  global window, track_template, vb1, tracks
  rcParams['xtick.direction'] = 'in'
  rcParams['xtick.direction'] = 'in'
  rcParams['axes.labelsize'] = 9
  rcParams['xtick.labelsize'] = 9
  rcParams['ytick.labelsize'] = 9
  rcParams['legend.fontsize'] = 9
  for ix in range(0,4):
    hexcoll = list("000000")
    hexcoll[(2*ix)%6] = "F" ; hexcoll[(2*ix+1)%6] = "F" ;
    colstr = "#%s" % ("".join(hexcoll))
    # create plot
    fig = Figure() #(figsize=(5,4), dpi=100)
    #~ fig.tight_layout() #no
    ax = fig.add_subplot(111)
    #ax.axis().invert_ticklabel_direction() # don't have this
    #ax.get_yaxis().set_tick_params(which='both', direction='out') # don't have this
    #ax.tick_params(direction='out', pad=5) # don't have this
    t = np.arange(0.0,3.0,0.01)
    s = np.sin(2*(ix+1)*np.pi*t)
    fig.aspect='auto' # auto/ "Note the grey border on the sides is related to the aspect rario of the Axes" ? not here
    #~ ax.spines['right'].set_color('none') # nope...
    #~ ax.spines['left'].set_color('none')
    #~ ax.spines['top'].set_color('none')
    #~ ax.spines['bottom'].set_color('none')
    ax.plot(t,s, color=colstr)
    canvas = FigureCanvas(fig)  # a gtk.DrawingArea
    # this for/zip is a significant startup slowdown:
    #~ for (tx, ty) in zip(ax.xaxis.get_major_ticks(), ax.yaxis.get_major_ticks()):
      #~ tx.label1.set_fontsize(9)
      #~ tx.set_pad(-3.0) # no effect in 0.99
      #~ tx.label1.set_verticalalignment('top')
      #~ print tx.get_pad()
      #~ ty.label1.set_fontsize(9)
      #~ ty.set_pad(10.0) # no effect in 0.99
      #~ #ty.label1.set_rotation('vertical')
      #~ ty.label.set_horizontalalignment('left')
    # create and add plot as track
    #canvas.draw_idle()
    addTrack(color=gtk.gdk.Color(colstr), incanvas=canvas)

def addTrack(name="", color=gtk.gdk.Color('#aa0'), incanvas=None, startwidth=0):
  global window, track_template, vb1, tracks, maxtracks
  track_copy = deep_clone_widget(track_template)
  maxtracks+=1
  if not(name): name = "track_%d" % (maxtracks)
  gtk.Buildable.set_name(track_copy, name)
  vb1.pack_start(track_copy, expand=False, fill=True, padding=0)
  # set_size_request to drawingarea needed for detach dragging;
  # window.set_size_request needs to be called before this:
  tda = track_copy.get_child()
  # use vb1 instead of width here - to account for right scrollbar?
  # cannot, X crashes; must be realized, probably? it is show() in buildTracks
  # even with window.show, vb1.get_size_request() here is (-1,-1);
  # but also its parent, the viewport, is (-1, -1)
  # probably best to pass an argument for startwidth here
  if not(startwidth): startwidth = window.get_size_request()[0]
  tda.set_size_request(startwidth, track_copy.get_size_request()[1])
  tda.modify_bg(gtk.STATE_NORMAL, color)
  # "In GTK+, for an application to be capable of DND, it must first define and set up the widgets that will participate in it"
  TARGET_TYPE_NUMBER = 82 # info is an application assigned integer identifier.
  fromto = [ ( "number", gtk.TARGET_SAME_APP, TARGET_TYPE_NUMBER) ]
  track_copy.drag_source_set(gtk.gdk.BUTTON1_MASK, targets=fromto, actions=gtk.gdk.ACTION_MOVE)
  track_copy.drag_dest_set(gtk.DEST_DEFAULT_ALL, targets=fromto, actions=gtk.gdk.ACTION_MOVE)
  # Connect to signals
  track_copy.connect("drag_drop", dragdrop_cb)
  track_copy.connect("drag_motion", dragmotion_cb)
  # don't need these - for reorder, _drop (and _motion) is enough
  track_copy.connect("drag-begin", dragbegin_cb)
  #tda.connect("drag-begin", multihandle_cb)
  #~ track_copy.connect("drag-motion", multihandle_cb)
  #~ track_copy.connect("drag-drop", multihandle_cb)
  #~ track_copy.connect("drag-data-get", multihandle_cb)
  #~ track_copy.connect("drag-data-received", multihandle_cb)
  #~ track_copy.connect("drag-data-delete", multihandle_cb)
  #~ track_copy.connect("drag-end", multihandle_cb)
  #~ track_copy.connect("drag-failed", multihandle_cb)
  #~ track_copy.connect("drag-leave", multihandle_cb)
  #~ track_copy.connect("child-attached", multihandle_cb)
  track_copy.connect("child-detached", child_detached_cb)
  if incanvas is not None:
    # don't need the tda dummy drawingarea anymore;
    # replacing it with plot canvas:
    track_copy.remove(tda)
    track_copy.add(incanvas)
  tracks.append(track_copy)
  return track_copy

# "The motion_cb() handler just sets the drag status for the drag context so that a drop will be enabled"
def dragmotion_cb(widget, context, x, y, time):
  context.drag_status(gtk.gdk.ACTION_COPY, time)
  #context.drop_finish(success=False, time=time) # keeps on the drag going forever, never stopping
  #~ context.drag_abort(time) # nothing
  #context.finish(False, True, time) # segfault
  return True

def dragbegin_cb(widget, drag_context):
  global window
  #print ("dragbegin_cb widget", widget, "drag_context", drag_context)
  #GTK_DRAG_RESULT_USER_CANCELLED = 2
  #pprint(dir(drag_context))
  #~ drag_context.drop_finish(success=False, time=gtk.gdk.CURRENT_TIME)
  #drag_context.drag_abort(time=gtk.get_current_event_time()) # does nothing; don't need it anymore
  #~ drag_context.finish(False, True, time=gtk.gdk.CURRENT_TIME)
  #window.emit("drag-failed", drag_context, GTK_DRAG_RESULT_USER_CANCELLED) # nope; drag_context cannot even fire this
  # http://svn.gna.org/svn/congabonga/trunk/lib/misc.py
  #~ gobject.idle_add(drag_context.drag_abort, gtk.get_current_event_time()) # works, but simply the drop doesn't work
  #gobject.idle_add(drag_context.drop_finish, False, gtk.get_current_event_time()) # icon stick to pointer, app freeze!
  #~ gobject.idle_add(drag_context.finish, False, True, gtk.get_current_event_time()) # icon stick to pointer, app freeze!
  #~ gtk.gdk.test_simulate_key(window, 0, 0, button=1, modifiers=0, button_pressrelease=gtk.gdk.BUTTON_RELEASE) # none such
  # WORKS this cancels drag-n-drop: but in here, the first it is full drag (so this gets registered), only then if the drag not started
  #~ gSettings = widget.get_settings();
  #~ gSettings.set_long_property("gtk-dnd-drag-threshold", 3000, "multitrack:dragbegin_cb")
  return False


def dragdrop_cb(widget, context, x, y, time):
  global vb1
  dragstarter = context.get_source_widget()
  #print ("dragdrop_cb widget", widget, "context", dragstarter, x, y)
  # have to reorder both for proper reorder
  ids = vb1.get_children().index(dragstarter)
  iwd = vb1.get_children().index(widget)
  vb1.reorder_child(widget, ids)
  vb1.reorder_child(dragstarter, iwd)
  context.finish(True, False, time)
  return True

# handlebox at/det: def callback(handlebox, widget, user_param1, ...)
# drag-begin/end  : def callback(widget, drag_context, user_param1, ...)
# here just checking drag-begin actually
def multihandle_cb(self, event):
  print("multihandle_cb event", event, "self", self)
  #event.drag_highlight()
    #~ return True
  #~ return False

def child_detached_cb(handlebox, widget):
  # doing this callback, so plot is still drawn at detach!
  tda = widget #.get_child() # here is already the drawing area child!
  da_draw(tda, -3, -3, 0, 0)


# http://stackoverflow.com/questions/20460848/templating-overflowing-content-with-glade-and-pygtk
# http://stackoverflow.com/questions/20461464/how-do-i-iterate-through-all-gtk-children-in-pygtk-recursively
def get_descendant(widget, child_name, level, doPrint=False):
  if widget is not None:
    if doPrint: print("-"*level + str(gtk.Buildable.get_name(widget)) + " :: " + widget.get_name())
  else:
    if doPrint:  print("-"*level + "None")
    return None
  if(gtk.Buildable.get_name(widget) == child_name):
    return widget;
  if (hasattr(widget, 'get_child') and callable(getattr(widget, 'get_child')) and child_name != ""):
    child = widget.get_child()
    if child is not None:
      return get_descendant(child, child_name,level+1,doPrint)
  elif (hasattr(widget, 'get_children') and callable(getattr(widget, 'get_children')) and child_name !=""):
    children = widget.get_children()
    found = None
    for child in children:
      if child is not None:
        found = get_descendant(child, child_name,level+1,doPrint)
        if found: return found

def deep_clone_widget(widget, inparent=None):
  dbg = 0
  widget2 = clone_widget(widget)
  if inparent is None: inparent = widget2
  if (hasattr(widget, 'get_child') and callable(getattr(widget, 'get_child'))):
    child = widget.get_child()
    if child is not None:
      if dbg: print("A1 inp", inparent.get_name(), "w2", widget2.get_name())
      childclone = deep_clone_widget(child, widget2)
      if dbg: print("A2", childclone.get_name())
      widget2.add( childclone )
      #return inparent
  elif (hasattr(widget, 'get_children') and callable(getattr(widget, 'get_children')) ):
    children = widget.get_children()
    for child in children:
      if child is not None:
        if dbg: print("B1 inp", inparent.get_name(), "w2", widget2.get_name())
        childclone = deep_clone_widget(child, widget2)
        if dbg: print("B2", childclone.get_name())
        inparent.add( childclone )
        #return childclone
  return widget2

# http://stackoverflow.com/questions/1321655/how-to-use-the-same-widget-twice-in-pygtk
def clone_widget(widget):
  dbg = [] # [ ix for ix in range(1,5) ] #[1, 3]
  if 1 in dbg: print(" > clone_widget in: " + str(gtk.Buildable.get_name(widget)) + " :: " + widget.get_name() )
  widget2=widget.__class__()
  # these must go first, else they override set_name from next stage
  skip_pspec= ['window', 'child', 'composite-child', 'child-detached', 'parent']
  if widget.__class__ == gtk.DrawingArea: skip_pspec.append('style')
  for pspec in widget.props:
    if pspec.name not in skip_pspec:
      try:
        prop = widget.get_property(pspec.name)
        if 2 in dbg: print("  > " + pspec.name + " " + str(prop))
        widget2.set_property(pspec.name, prop)
      except Exception as e:
        print(e)
  # here set_name is obtained
  skip_prop= ["set_buffer"]
  if widget.__class__ == gtk.DrawingArea: skip_prop.append('set_style') # "set_colormap", "set_allocation", "set_activate_signal",

  for prop in dir(widget):
    if prop.startswith("set_") and prop not in skip_prop:
      if 3 in dbg: print("  ! " + prop + " ")
      prop_value=None
      try:
        prop_value=getattr(widget, prop.replace("set_","get_") )()
      except Exception as e:
        if 4 in dbg: print (e)
        try:
          prop_value=getattr(widget, prop.replace("set_","") )
        except:
          try:
            prop_value=getattr(widget, prop.replace("set_","") )()
          except:
            try:
              prop_value=getattr(widget, prop.replace("set_","is_") )()
            except:
              continue
      if prop_value == None:
        continue
      try:
        if 5 in dbg: print("  > " + prop + " " + prop_value )
        if prop != "set_parent": # else pack_start complains: assertion `child->parent == NULL' failed
          getattr(widget2, prop)( prop_value )
      except:
        pass
  nn = gtk.Buildable.get_name(widget)
  gtk.Buildable.set_name(widget2, "" if not nn else nn )
  ## style copy:
  #for pspec in gtk.widget_class_list_style_properties(widget):
  #  print pspec, widget.style_get_property(pspec.name)
  #  #gtk.widget_class_install_style_property(widget2, pspec) #nope, for class only, not instances!
  # none of these below seem to change anything - still getting a raw X11 look after them:
  widget2.ensure_style()
  widget2.modify_style(widget.get_modifier_style())
  #widget2.set_default_style(widget.get_default_style().copy()) # noexist; evt. deprecated? http://stackoverflow.com/questions/19740162/how-to-set-default-style-for-widgets-in-pygtk
  if widget.__class__ != gtk.DrawingArea:
    # these two still don't do much - here because they kill drawingarea
    widget2.set_style(widget.get_style().copy()) # kills drawingarea!
    widget2.set_style(gtk.widget_get_default_style()) # kills drawingarea!
    # this is the right one, so we don't get raw X11 look:
    widget2.set_style(widget.rc_get_style()) # kills drawingarea!
  return widget2

# copied from scipy:
# http://stackoverflow.com/questions/12240634/what-is-the-best-drop-in-replacement-for-numpy-interp-if-i-want-the-null-interpo
class _scipy_Interpolator1D(object): # ./scipy/interpolate/polyint.py
  __slots__ = ('_y_axis', '_y_extra_shape', 'dtype')
  def __init__(self, xi=None, yi=None, axis=None):
    self._y_axis = axis
    self._y_extra_shape = None
    self.dtype = None
    if yi is not None:
      self._set_yi(yi, xi=xi, axis=axis)
  def __call__(self, x):
    """ Evaluate the interpolant ...  """
    x, x_shape = self._prepare_x(x)
    y = self._evaluate(x)
    return self._finish_y(y, x_shape)
  def _evaluate(self, x):
    """ Actually evaluate the value of the interpolator. """
    raise NotImplementedError()
  def _prepare_x(self, x):
    """Reshape input x array to 1-D"""
    x = np.asarray(x)
    x_shape = x.shape
    return x.ravel(), x_shape
  def _finish_y(self, y, x_shape):
    """Reshape interpolated y back to n-d array similar to initial y"""
    y = y.reshape(x_shape + self._y_extra_shape)
    if self._y_axis != 0 and x_shape != ():
      nx = len(x_shape)
      ny = len(self._y_extra_shape)
      s = (list(range(nx, nx + self._y_axis))
         + list(range(nx)) + list(range(nx+self._y_axis, nx+ny)))
      y = y.transpose(s)
    return y
  def _reshape_yi(self, yi, check=False):
    yi = np.rollaxis(np.asarray(yi), self._y_axis)
    if check and yi.shape[1:] != self._y_extra_shape:
      ok_shape = "%r + (N,) + %r" % (self._y_extra_shape[-self._y_axis:],
                       self._y_extra_shape[:-self._y_axis])
      raise ValueError("Data must be of shape %s" % ok_shape)
    return yi.reshape((yi.shape[0], -1))
  def _set_yi(self, yi, xi=None, axis=None):
    if axis is None:
      axis = self._y_axis
    if axis is None:
      raise ValueError("no interpolation axis specified")
    yi = np.asarray(yi)
    shape = yi.shape
    if shape == ():
      shape = (1,)
    if xi is not None and shape[axis] != len(xi):
      raise ValueError("x and y arrays must be equal in length along "
              "interpolation axis.")
    self._y_axis = (axis % yi.ndim)
    self._y_extra_shape = yi.shape[:self._y_axis]+yi.shape[self._y_axis+1:]
    self.dtype = None
    self._set_dtype(yi.dtype)
  def _set_dtype(self, dtype, union=False):
    if np.issubdtype(dtype, np.complexfloating) \
        or np.issubdtype(self.dtype, np.complexfloating):
      self.dtype = np.complex_
    else:
      if not union or self.dtype != np.complex_:
        self.dtype = np.float_

class scipy_interp1d(_scipy_Interpolator1D): # ./scipy/interpolate/interpolate.py
  def __init__(self, x, y, kind='linear', axis=-1,
          copy=True, bounds_error=True, fill_value=np.nan):
    """ Initialize a 1D linear interpolation class."""
    _scipy_Interpolator1D.__init__(self, x, y, axis=axis)
    self.copy = copy
    self.bounds_error = bounds_error
    self.fill_value = fill_value
    if kind in ['zero', 'slinear', 'quadratic', 'cubic']:
      order = {'nearest': 0, 'zero': 0, 'slinear': 1,
               'quadratic': 2, 'cubic': 3}[kind]
      kind = 'spline'
    elif isinstance(kind, int):
      order = kind
      kind = 'spline'
    elif kind not in ('linear', 'nearest', 'zeroB'):
      raise NotImplementedError("%s is unsupported: Use fitpack "
                    "routines for other types." % kind)
    # zeroB will be handled here?
    x = np.array(x, copy=self.copy)
    y = np.array(y, copy=self.copy)
    if x.ndim != 1:
      raise ValueError("the x array must have exactly one dimension.")
    if y.ndim == 0:
      raise ValueError("the y array must have at least one dimension.")
    # Force-cast y to a floating-point type, if it's not yet one
    if not issubclass(y.dtype.type, np.inexact):
      y = y.astype(np.float_)
    # Backward compatibility
    self.axis = axis % y.ndim
    # Interpolation goes internally along the first axis
    self.y = y
    y = self._reshape_yi(y)
    # Adjust to interpolation kind; store reference to *unbound* ...
    if kind in ('linear', 'nearest', 'zeroB'):
      # Make a "view" of the y array that is rotated to the interpolation ...
      minval = 2
      if kind == 'nearest':
        self.x_bds = (x[1:] + x[:-1]) / 2.0
        self._call = self.__class__._call_nearest
      elif kind == 'zeroB':
        self._call = self.__class__._call_zeroB
      else:
        self._call = self.__class__._call_linear
    else:
      minval = order + 1
      self._spline = splmake(x, y, order=order)
      self._call = self.__class__._call_spline
    if len(x) < minval:
      raise ValueError("x and y arrays must have at "
               "least %d entries" % minval)
    self._kind = kind
    self.x = x
    self._y = y
  def _call_linear(self, x_new):
    # 2. Find where in the orignal data, the values to interpolate ...
    x_new_indices = np.searchsorted(self.x, x_new)
    # 3. Clip x_new_indices so that they are within the range of ...
    x_new_indices = x_new_indices.clip(1, len(self.x)-1).astype(int)
    # 4. Calculate the slope of regions that each x_new value falls in.
    lo = x_new_indices - 1
    hi = x_new_indices
    x_lo = self.x[lo]
    x_hi = self.x[hi]
    y_lo = self._y[lo]
    y_hi = self._y[hi]
    # Note that the following two expressions rely on the specifics of the ...
    slope = (y_hi - y_lo) / (x_hi - x_lo)[:, None]
    # 5. Calculate the actual value for each entry in x_new.
    y_new = slope*(x_new - x_lo)[:, None] + y_lo
    return y_new
  def _call_zeroB(self, x_new):
    # 2. Find where in the orignal data, the values to interpolate ...
    x_new_indices = np.searchsorted(self.x, x_new)
    # 3. Clip x_new_indices so that they are within the range of ...
    x_new_indices = x_new_indices.clip(1, len(self.x)-1).astype(int)
    # 4. Calculate the slope of regions that each x_new value falls in.
    lo = x_new_indices - 1
    hi = x_new_indices
    x_lo = self.x[lo]
    x_hi = self.x[hi]
    y_lo = self._y[lo]
    y_hi = self._y[hi]
    # Note that the following two expressions rely on the specifics of the ...
    slope = 0
    # 5. Calculate the actual value for each entry in x_new.
    #y_new = slope*(x_new - x_lo)[:, None] + np.concatenate((y_lo[0:1], y_hi[1:])) #+ y_lo
    y_new = np.concatenate((y_lo[0:1], y_hi[1:]))
    return y_new
  def _call_nearest(self, x_new):
    """ Find nearest neighbour interpolated y_new = f(x_new)."""
    # 2. Find where in the averaged data the values to interpolate
    x_new_indices = np.searchsorted(self.x_bds, x_new, side='left')
    # 3. Clip x_new_indices so that they are within the range of x indices.
    x_new_indices = x_new_indices.clip(0, len(self.x)-1).astype(np.intp)
    # 4. Calculate the actual value for each entry in x_new.
    y_new = self._y[x_new_indices]
    return y_new
  def _call_spline(self, x_new):
    return spleval(self._spline, x_new)
  def _evaluate(self, x_new):
    # 1. Handle values in x_new that are outside of x.  Throw error,
    x_new = np.asarray(x_new)
    out_of_bounds = self._check_bounds(x_new)
    y_new = self._call(self, x_new)
    if len(y_new) > 0:
      y_new[out_of_bounds] = self.fill_value
    return y_new
  def _check_bounds(self, x_new):
    """Check the inputs for being in the bounds of the interpolated data. ... """
    # If self.bounds_error is True, we raise an error if any x_new values ...
    below_bounds = x_new < self.x[0]
    above_bounds = x_new > self.x[-1]
    # !! Could provide more information about which values are out of bounds
    if self.bounds_error and below_bounds.any():
      raise ValueError("A value in x_new is below the interpolation "
        "range.")
    if self.bounds_error and above_bounds.any():
      raise ValueError("A value in x_new is above the interpolation "
        "range.")
    # !! Should we emit a warning if some values are out of bounds? ...
    out_of_bounds = np.logical_or(below_bounds, above_bounds)
    return out_of_bounds

# print " ".join( get_namestr_vars('bpw', 'fbps', 'ftpd', 'abps', 'apd') )
def get_namestr_vars(*args):
  retstrs = []
  for count, var_str in enumerate(args):
    gval = " [g] {0}".format( globals()[var_str] ) if var_str in globals() else ""
    lval = " [l] {0}".format( locals()[var_str] ) if var_str in locals() else ""
    sval = "{0}: {1}{2}".format(var_str, gval, lval)
    retstrs.append(sval)
  return retstrs

if __name__ == "__main__":
  main()

"""
http://www.compsci.hunter.cuny.edu/~sweiss/course_materials/csci493.70/lecture_notes/GTK_dragndrop.pdf
http://www.pygtk.org/pygtk2tutorial/sec-DNDMethods.html
http://python.developpez.com/cours/pygtktutorial/php/pygtken/sec-DNDMethods.php
http://matplotlib.org/examples/user_interfaces/embedding_in_gtk.html
[http://lists.freedesktop.org/archives/cairo/2013-April/024209.html [cairo] How to output images from data originating from files?]
http://stackoverflow.com/questions/7313806/select-rows-from-numpy-rec-array
http://stackoverflow.com/questions/15182381/how-to-return-a-view-of-several-columns-in-numpy-structured-array
http://stackoverflow.com/questions/16860820/select-range-of-rows-from-record-ndarray/20488862#20488862
http://stackoverflow.com/questions/17128116/why-is-numpy-any-so-slow-over-large-arrays
http://stackoverflow.com/questions/12647471/the-truth-value-of-an-array-with-more-than-one-element-is-ambigous-when-trying-t
http://stackoverflow.com/questions/20490479/ndim-of-structured-arrays-in-numpy
http://stackoverflow.com/questions/17456086/numpy-stacking-1d-arrays-into-structured-array
http://stackoverflow.com/questions/13630295/how-to-simply-build-a-integer-and-float-mixed-numpy-array
http://stackoverflow.com/questions/3048148/alpha-blending-in-gtk
http://svn.majorsilence.com/pygtknotebook/trunk/examples/more-pygtk/drag_and_drop.py
https://developer.gnome.org/pygtk/2.24/class-gtkwidget.html#signal-gtkwidget--drag-failed # drag-failed
https://partiwm.googlecode.com/hg/working-notes/gdk-gtk-guts.txt # drag_check_threshold
[http://www.daa.com.au/pipermail/pygtk/2004-June/008017.html [pygtk] Widget.drag_check_threshold - replacing the method?]: g_object_get (gtk_widget_get_settings (widget),
		"gtk-dnd-drag-threshold", &drag_threshold,
		NULL);
http://www.sicem.biz/personal/lgs/docs/gobject-python/gobject-tutorial.html#d0e127
http://learngtk.org/pygtk-tutorial/dialog.html
http://stackoverflow.com/questions/12228322/numpy-recarray-sort-of-columns-and-stack/20533912#20533912
https://gist.github.com/sahib/5536772/raw/b1d20ecb6de6419b7bd6cc1c7cda45bc5c403068/swipe.py #     # Remove the widget again (so we can reparent it later)


scaled image with pixbuf: in class:

import subprocess
from gi.repository import GdkPixbuf

  def expose_event(self, widget, event):
    x , y, width, height = event.area
    self.pixmap = gtk.gdk.Pixmap(self.drawingarea.window, width, height) # must have, so window size changes propagate!
    new_pixbuf = self.pixbuf.scale_simple(width, height, gtk.gdk.INTERP_NEAREST)
    self.pixmap.draw_pixbuf(None, new_pixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)
    widget.window.draw_drawable(widget.get_style().fg_gc[gtk.STATE_NORMAL],
                                self.pixmap, x, y, x, y, width, height)
    return False

    self.drawingarea.connect("expose_event", self.expose_event)

  def __init__(self):
    ...
    ta = gtk.DrawingArea()
    self.drawingarea.connect("expose_event", self.expose_event)
    ...
    self.drawingarea.show()
    window.show()

    # window must be realized for this to pass wout errors; so after window_show!
    # (better in configure_event - see scribblesimple.py)
    # but without expose_event, this happens only at start, and is overwritten..
    # with expose_event, all previous stuff with rgb background is overwritten
    img_fn="/media/disk/tmp/ftdi_prof/ftdiprof-2013-12-06-05-03-49_64/rep.png"
    gpscript = 'set terminal png; set output "/dev/stdout"; plot sin(x)\n'
    proc = subprocess.Popen(
      ['gnuplot',],
      shell=True,
      stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    (stdout, stderr) = proc.communicate(gpscript)
    imgdat = stdout
    loader = GdkPixbuf.PixbufLoader('png') #.new_with_type('png')
    loader.write(imgdat)
    self.pixbuf = loader.get_pixbuf()
    loader.close()

    x, y, width, height = self.drawingarea.get_allocation()
    #self.pixbuf = gtk.gdk.pixbuf_new_from_file(img_fn) #one way to load a pixbuf
    self.pixmap = gtk.gdk.Pixmap(self.drawingarea.window, width, height)
    self.pixmap.draw_pixbuf(None, self.pixbuf, 0, 0, x, y, -1, -1, gtk.gdk.RGB_DITHER_NONE, 0, 0)

...

#aa = np.ndarray((a.shape[0],len(a.dtype)), dtype = object, buffer=a) # segfault
aa = np.ndarray((a.shape[0],len(a.dtype)),dtype = object)
aa[:,0] = a['x']
aa[:,1] = a['y']
pprint(aa)
print(aa.shape)
# array([[1.5, 2],
#        [3.0, 4],
#        [1.0, 3]], dtype=object)
# (3, 2)

... scipy zero interpolation test:

# installed python-scipy/natty uptodate 0.8.0+dfsg1-1ubuntu1
# vs. copied/hacked "pure numpy" (.git v0.9.0rc5)

x = np.arange(0, 10)
y = np.exp(-x/3.0)
# one of these:
#f = scipy_interp1d(x, y, kind='zeroB', copy=True)
#f = scipy.interpolate.interp1d(x, y, kind='zero', copy=True)

xnew = np.arange(0,9, 0.1)
meas = []
for ix in range(0,100):
  start_time = time.time()
  ynew = f(xnew)   # use interpolation function returned by `interp1d`
  dt = time.time() - start_time
  meas.append(dt)
  #print dt, "seconds"
print "mean:", np.mean(np.array(meas))
# scipy_interp1d 'zeroB' (copied .git v0.9.0rc5):
#   mean: 0.000491211414337, mean: 0.000778119564056
# scipy.interpolate 'zero' (0.8.0+dfsg1-1ubuntu1):
#   mean: 0.000308830738068, mean: 0.000508503913879


# some more tests - seems I need nearest interpolator, instead of zero!!
# (zero can delay some arrays which trigger x out of bounds during interp!)
# also, building an array with list comprehension
# is much faster than nrpf.merge_arrays!

def getNPsaLinInterpolatedOverOld(aa, ats, avals, bb, bts, bvals, ii, iis):
  a_z = np.interp(ii[iis], aa[ats], aa[avals])
  b_z = np.interp(ii[iis], bb[bts], bb[bvals])
  # below not so correct for differing dtypes?
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, aa[ats].dtype), (avals, aa[avals].dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, bb[bts].dtype), (bvals, bb[bvals].dtype)] )
  return a_npz, b_npz

def getNPsaLinInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis):
  a_z = np.interp(ii[iis], aa[ats], aa[avals])
  b_z = np.interp(ii[iis], bb[bts], bb[bvals])
  # below more correct for differing types
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  return a_npz, b_npz

def getNPsaLinInterpolatedOverMerge(aa, ats, avals, bb, bts, bvals, ii, iis):
  # much slower - but correct!
  a_z = np.interp(ii[iis], aa[ats], aa[avals])
  b_z = np.interp(ii[iis], bb[bts], bb[bvals])
  raz = [ ii[iis].view([(iis, ii[iis].dtype)]), a_z.view([(avals, a_z.dtype)]) ]
  a_npz = nprf.merge_arrays( ( raz ) )
  rbz = [ ii[iis].view([(iis, ii[iis].dtype)]), b_z.view([(bvals, b_z.dtype)]) ]
  b_npz = nprf.merge_arrays( ( rbz ) )
  return a_npz, b_npz

def getNPsaZeroInterpolatedOverMerge(aa, ats, avals, bb, bts, bvals, ii, iis):
  # must use bounds_error=False, else ValueError("A value in x_new is above the interpolation "...)
  # but then, it can "delay" values in the problematic array...
  fa = scipy_interp1d(aa[ats], aa[avals], kind='zeroB', copy=False)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='zeroB', copy=False, fill_value=-1, bounds_error=False)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  raz = [ ii[iis].view([(iis, ii[iis].dtype)]), a_z.view([(avals, a_z.dtype)]) ]
  a_npz = nprf.merge_arrays( ( raz ) )
  rbz = [ ii[iis].view([(iis, ii[iis].dtype)]), b_z.view([(bvals, b_z.dtype)]) ]
  b_npz = nprf.merge_arrays( ( rbz ) )
  return a_npz, b_npz

def getNPsaZeroInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis):
  # must use bounds_error=False, else ValueError("A value in x_new is above the interpolation "...)
  # but then, it can "delay" values in the problematic array...
  fa = scipy_interp1d(aa[ats], aa[avals], kind='zeroB', copy=False)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='zeroB', copy=False, fill_value=-1, bounds_error=False)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  return a_npz, b_npz

# actually, I want nearest - not zero interpolation!
def getNPsaNearestInterpolatedOverMerge(aa, ats, avals, bb, bts, bvals, ii, iis):
  # nearest is now correct...
  fa = scipy_interp1d(aa[ats], aa[avals], kind='nearest', copy=True, bounds_error=False)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='nearest', copy=True, bounds_error=False)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  raz = [ ii[iis].view([(iis, ii[iis].dtype)]), a_z.view([(avals, a_z.dtype)]) ]
  a_npz = nprf.merge_arrays( ( raz ) )
  rbz = [ ii[iis].view([(iis, ii[iis].dtype)]), b_z.view([(bvals, b_z.dtype)]) ]
  b_npz = nprf.merge_arrays( ( rbz ) )
  return a_npz, b_npz

def getNPsaNearestInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis):
  fa = scipy_interp1d(aa[ats], aa[avals], kind='nearest', copy=True, bounds_error=False)
  a_z = fa(ii[iis])   # use interpolation function returned by `interp1d`
  fb = scipy_interp1d(bb[bts], bb[bvals], kind='nearest', copy=True, bounds_error=False)
  b_z = fb(ii[iis])   # use interpolation function returned by `interp1d`
  a_npz = np.array( [ (tz,az) for tz,az in zip(ii[iis],a_z) ],
    dtype=[(iis, ii[iis].dtype), (avals, a_z.dtype)] )
  b_npz = np.array( [ (tz,bz) for tz,bz in zip(ii[iis],b_z) ],
    dtype=[(iis, ii[iis].dtype), (bvals, b_z.dtype)] )
  return a_npz, b_npz

# D version; based on:
# a_npz = aa[ np.repeat(aa[ats], np.ediff1d( np.nonzero( np.setmember1d(ii[iis], aa[ats]) )[0] , to_end=1 ) ) ]
# but that is not the whole thing; here is
# original with some mistakes; (the shortened+corrected is above):
def getNPsaZeroDInterpolatedOver(aa, ats, avals, bb, bts, bvals, ii, iis, fill_value=0.0):
  # ii[iis] should already be unique (via union)
  # check for duplicate timestamps - and retrieve only corresponding values for processing
  # by default, this will keep the first of duplicates, and drop the rest
  atsu,atsuind,atsuinv= np.unique(aa[ats], return_index=True, return_inverse=True)
  btsu,btsuind,btsuinv= np.unique(bb[bts], return_index=True, return_inverse=True)
  print "atsu", atsu, "\natsuind", atsuind
  print "btsu", btsu, "\nbtsuind", btsuind
  sma = np.setmember1d(ii[iis], atsu)
  npnza = np.nonzero( sma )[0]
  smb = np.setmember1d(ii[iis], btsu)
  npnzb = np.nonzero( smb )[0] # unique: removes duplicates
  print "len aa, atsu, bb, btsu, ii:", len(aa), len(atsu), len(bb), len(btsu), len(ii)
  print atsu, "\n", btsu, "\n", ii[iis]
  print "sma", len(sma), sma
  print "npnza", len(npnza), npnza
  print "smb", len(smb), smb
  print "npnzb", len(npnzb), npnzb
  a_below_bounds = ii[iis] < atsu[0]
  a_above_bounds = ii[iis] > atsu[-1]
  out_of_bounds_a = np.logical_or(a_below_bounds, a_above_bounds)
  print "out_of_bounds_a", out_of_bounds_a
  b_below_bounds = ii[iis] < btsu[0]
  b_above_bounds = ii[iis] > btsu[-1]
  out_of_bounds_b = np.logical_or(b_below_bounds, b_above_bounds)
  # with to_end 1, we'll always repeat to the right; add also above_bounds repeats (but those need to just increase the last element!) ... nevermind that, live with zeroes for now +len(np.nonzero(a_above_bounds)[0])
  npnzae = np.ediff1d( npnza , to_end=[1]*(len(atsu)-len(npnza)+1) )
  npnzbe = np.ediff1d( npnzb , to_end=[1]*(len(btsu)-len(npnzb)+1) )
  print "npnzae", len(npnzae), npnzae
  print "npnzbe", len(npnzbe), npnzbe
  print len(npnza), len(npnzae), len(atsu), "..", len(npnzb), len(npnzbe), len(btsu) # with unique, all equal now
  print "out_of_bounds_b", out_of_bounds_b
  ainds = np.repeat( np.arange(0, len(atsu)), npnzae ) #indices   #(aa[ats], npnzae)#timestamps
  print "ainds", len(ainds), ainds
  binds = np.repeat( np.arange(0, len(btsu)), npnzbe ) #indices
  print "binds", len(binds), binds
  print "ar", atsu[ainds]
  print "br", btsu[binds]
  # because of out-of-bounds, must use slicing:
  avalid = atsu[np.zeros(len(ii[iis]), dtype=np.intp)]
  avalid[~out_of_bounds_a] = atsu[ainds]
  avalid[out_of_bounds_a] = fill_value
  print "avalid", avalid
  bvalid = btsu[np.zeros(len(ii[iis]), dtype=np.intp)]
  bvalid[~out_of_bounds_b] = btsu[binds]
  bvalid[out_of_bounds_b] = fill_value
  print "bvalid", bvalid
  # try fill by field (length must be allocated first):
  a_npz = np.zeros((len(ii[iis]),), dtype=[(iis, ii[iis].dtype), (avals, aa[avals].dtype)])
  a_npz[iis] = ii[iis]; a_npz[avals] = avalid;
  b_npz = np.zeros((len(ii[iis]),), dtype=[(iis, ii[iis].dtype), (bvals, bb[bvals].dtype)])
  b_npz[iis] = ii[iis]; b_npz[bvals] = bvalid;
  return a_npz, b_npz



mlen = 5

print "x", pformat( x[:mlen] )
print "xv", pformat( x.view([("ts1", x.dtype)])[:mlen] )

ra = [ x.view([("ts1", x.dtype)]), y.view([("val1", y.dtype)]) ]
np1 = nprf.merge_arrays( ( ra ) )
print "np1", len(np1), pformat( np1[:mlen] )

rb = [ xnew.view([("ts2", xnew.dtype)]), xnew.view([("val2", xnew.dtype)]) ]
#np2 = xnew.view([("ts2", xnew.dtype)])
np2 = nprf.merge_arrays( ( rb ) )
print "np2", len(np2), pformat( np2[:mlen] )

ntz = np.union1d(np1['ts1'], np2['ts2'])
ntzv = ntz.view([("tsz", ntz.dtype)])
print "ntz", len(ntzv), pformat( ntzv[:mlen] )

meas = []
a_npz=None ; b_npz = None
for ix in range(0,100):
  start_time = time.time()
  a_npz, b_npz = getNPsaNearestInterpolatedOver(np1, 'ts1', 'val1', np2, 'ts2', 'val2', ntzv, 'tsz')
  dt = time.time() - start_time
  meas.append(dt)
  #print dt, "seconds"
print "mean:", np.mean(np.array(meas))
# getNPsaLinInterpolatedOverOld: # wrong
# mean: 0.00086954832077
# mean: 0.000939509868622
# getNPsaLinInterpolatedOverMerge: # much, much slower, but correct!
# mean: 0.0195999765396
# mean: 0.0197598004341
# getNPsaLinInterpolatedOver # corrected - is faster than before, even!
# mean: 0.000778861045837
# mean: 0.00081226348877
# getNPsaZeroInterpolatedOverMerge / getNPsaNearestInterpolatedOverMerge
# mean: 0.0205674123764
# mean: 0.021320977211
# getNPsaZeroInterpolatedOver
# mean: 0.00185162305832
# mean: 0.00213847160339
# getNPsaNearestInterpolatedOver # a bit slower (though close to zeroB), but correct
# mean: 0.00161790847778
# mean: 0.00262930870056

print "a_npz", len(a_npz), pformat( a_npz[:mlen] )
print "b_npz", len(b_npz), pformat( b_npz[:mlen] )

######


a = np.array([
	(0.0, 1),
	(1.0, 100),
	(2.0, 200),
	(3.0, 300)
],
dtype=[('ta', 'f8'), ('va', 'i4')]
)

b = np.array([
	(0.1, 1),
	(0.2, 1.3),
	(0.8, 1.5),
	(0.9, 90.5),
	(1.1, 103.3),
	(1.2, 105.3),
	(1.2, 107.7),
	(1.8, 115.5),
	(1.9, 195.3),
	(2.0, 199.9),
	(2.2, 204.6),
	(2.8, 212.6),
	(2.9, 280.8)
],
dtype=[('tb', 'f8'), ('vb', 'f8')]
)

tz = np.union1d(a['ta'], b['tb']).view([('tz', a['ta'].dtype)])
pprint(tz)

a_npz, b_npz = getNPsaZeroCInterpolatedOver(a, 'ta', 'va', b, 'tb', 'vb', tz, 'tz')

# getNPsaZeroCInterpolatedOver # quite slow
# mean: 0.0130051255226
# mean: 0.0141918158531 # mean: 0.0196661424637

# improved:
# getNPsaZeroDInterpolatedOver
# mean: 0.00147910356522
# mean: 0.00160797119141
# getNPsaZeroDInterpolatedOver # shortened+often_vars_referred+corrected
# mean: 0.00144465684891
# mean: 0.00155482530594

# will count in those at same location, too
# mean: 0.000482497215271
a2 = np.array([(0.002159, 62), (0.002163, 62), (0.002165, 14), (0.003156, 62),
       (0.003159, 62), (0.003162, 59), (0.004149, 62), (0.004152, 62),
       (0.004155, 61), (0.005145, 62)],
      dtype=[('ts2', '<f8'), ('rlen2', '<i4')])

cs = getNPsaPieceCumSum(a2, 'ts2', 'rlen2', threshold=5.3e-4)
cs = getNPsaPieceCumSum(b, 'tb', 'vb', threshold=0.5)
print "cs", pformat( cs )

############

# http://stackoverflow.com/questions/18196811/cumsum-reset-at-nan
# [http://mail.scipy.org/pipermail/numpy-discussion/2012-October/064264.html [Numpy-discussion] Is there a way to reset an accumulate function?]
# http://stackoverflow.com/questions/11061928/numpy-array-slicing
# http://stackoverflow.com/questions/20672478/convert-a-numpy-boolean-array-to-int-one-with-distinct-values
# http://stackoverflow.com/questions/9378707/how-can-i-use-numpy-to-calculate-a-series-effectively
# There is no general way to vectorise recursive sequence definitions in NumPy.
# http://stackoverflow.com/questions/4407984/is-a-for-loop-necessary-if-elements-of-the-a-numpy-vector-are-dependant-upon-t
# http://stackoverflow.com/questions/20672478/convert-a-numpy-boolean-array-to-int-one-with-distinct-values
# http://stackoverflow.com/questions/5891410/numpy-array-initialization-fill-with-identical-values


ats1 = np.array([(1.426768, 252032), (1.427186, 252096), (1.427488, 252160),
       (1.427862, 252224), (1.428204, 252288), (1.428575, 252352),
       (1.428949, 252416), (1.429307, 252480), (1.430637, 252544),
       (1.430739, 252608), (1.431161, 252672), (1.431473, 252736), # 1.431161-1.430739=0.000422
       (1.431834, 252800), (1.432189, 252864), (1.432553, 252928),
       (1.432923, 252992), (1.433286, 253056), (1.433645, 253120),
       (1.434008, 253184), (1.434374, 253248), (1.434759, 253312),
       (1.435179, 253376), (1.435457, 253440), (1.435832, 253504),
       (1.436192, 253568), (1.436557, 253632)],
      dtype=[('ts1', '<f8'), ('wtot1', '<i4')])

print pformat( ats1[:10] )
bpw = 64 #ats1[0]['wtot1'] # bytes per write is also the first value in wtot1! (if we do it from start)
fbps=200000; ftpd=float(bpw)/fbps;
abps=44100*4; apd=float(bpw)/abps;

print " ".join( get_namestr_vars('bpw', 'fbps', 'ftpd', 'abps', 'apd') )

tsd = np.ediff1d( np.concatenate(([0.], ats1['ts1'] )) )
print "tsd  ", pformat(tsd)
tsdb=(tsd/ftpd)*bpw
with printoptions(precision=3, suppress=True):
  print "tsdb ", pformat(tsdb)


# ftqh=ftq-tsdb; ftqhb=bpw-tsdb
# ftq=ftqhh = (ftqh<0)?0+bpw:( (ftqhb<0)?ftqh+bpw:ftq+ftqhb )
##
# ftqh[0]=ftq[-1]-tsdb[0]; ftqhb[0]=bpw-tsdb[0]
# ftq[0]=ftqhh[0] = (ftqh[0]<0)? 0+bpw : ( (ftqhb[0]<0)?ftqh[0]+bpw:ftq[-1]+ftqhb[0] )
##
# ftq[0]=ftqhh[0] = ((ftq[-1]-tsdb[0])<0)? 0+bpw : ( ((bpw-tsdb[0])<0)?(ftq[-1]-tsdb[0])+bpw:ftq[-1]+(bpw-tsdb[0]) )
##
# ((bpw-tsdb[0])<0)?(ftq[-1]-tsdb[0])+bpw:ftq[-1]+(bpw-tsdb[0]) # same!? ftqh1
# this "previous"[-1] thing seems to be handled by the ediff1d!

ftqhb=bpw-tsdb
with printoptions(precision=3, suppress=True):
  print "ftqhb ", pformat(ftqhb)
#ftqhh = np.zeros(ftqhb.shape, dtype=ftqhb.dtype)
#ftqhh[ np.nonzero(ftqhb<0) ] = -tsdb + bpw
ftqh1 = -tsdb + bpw # here same as ftqhb
with printoptions(precision=3, suppress=True):
  print "ftqh1 ", pformat(ftqh1)
ftqh2 = np.concatenate(([0.], ftqh1[:-1]))
with printoptions(precision=3, suppress=True):
  print "ftqh2 ", pformat(ftqh2)
ftqh12 = ftqh1+ftqh2
with printoptions(precision=3, suppress=True):
  print "ftqh12 ", pformat(ftqh12)
ftqhh = np.array(ftqh1+bpw, copy=True)
ftqhh[np.nonzero((ftqh1-tsdb)<0)] = 0+bpw
with printoptions(precision=3, suppress=True):
  print "ftqhh ", pformat(ftqhh)

#ftqhf = np.zeros(len(ftqh1), dtype=ftqh1.dtype)
#ftqhf[:] = bpw
ftqhf=np.empty(len(ftqh1), dtype=ftqh1.dtype); ftqhf.fill(bpw)

inds1 = np.nonzero(ftqh1[:-1]>=0)[0]
#np.add(ftqhf[:-1], (ftqh1[:-1]>=0)*ftqh1[:-1], ftqhf[1:])
#np.add(ftqhf[(inds1-1)], ftqh1[inds1], ftqhf[inds1]) # nope - this returns copy, must slice
#[np.add(ftqhf[ix-1:ix], ftqh1[ix:ix+1], ftqhf[ix:ix+1]) for ix in inds1] # list comprehension just to iterate (not using the outer list) - changes data
#[np.add( (np.add(ftqhf[ix-1:ix], ftqh1[ix:ix+1])>bpw)*ftqh1[ix:ix+1], ftqhf[ix-1:ix], ftqhf[ix:ix+1]) for ix in inds1]
# np.add( (np.add(ftqhf[:-1], ftqh1[1:])>bpw)*ftqh1[1:], ftqhf[:-1], ftqhf[1:]) # works, not fully ok
# with selection indexing? nah, have to use zip then, gets complicated; then must repeat the bool calc twice, as this is recursive...
# ftqhf[:-1] in return of np.where will get "frozen"!
#np.add( (np.add(ftqhf[:-1], ftqh1[1:])>bpw)*ftqh1[1:], ftqhf[:-1], ftqhf[1:])
#np.add( (np.add(ftqhf[:-1], ftqh1[1:])>bpw)*ftqh1[1:],
#        (np.add(ftqhf[:-1], ftqh1[1:])>bpw)*ftqhf[:-1] + ~(np.add(ftqhf[:-1], ftqh1[1:])>bpw)*bpw,
#        ftqhf[1:]) # sorta
#np.add( (np.add(ftqhf[:-1], -tsdb[1:])>0)*np.add(ftqhf[:-1], -tsdb[1:]),
#        bpw,
#        ftqhf[1:]) # nope

#np.add( ((ftqhf[:-1]-tsdb[1:])>0)*(ftqhf[:-1]-tsdb[1:]),
#np.add( ftqhf[:-1]-tsdb[1:],  # not ok, not even via np.add(ftqhf[:-1],-tsdb[1:])
#np.add( np.add(ftqhf[:-1],-tsdb[1:]),
#        bpw,
#        ftqhf[1:]) #
#np.add( ftqhf[:-1],  # just ftqhf[:-1]+1 is enough to stop recursion!
#        -tsdb[1:]+bpw,
#        ftqhf[1:]) # this recurses

# this works:
# mean: 0.00039404630661 mean: 0.000503389835358
#for ix in xrange(0, len(ftqhf[:-1])):
#  ftqhf[ix+1] = ( 0 if ftqhf[ix]-tsdb[ix+1]<0 else ftqhf[ix]-tsdb[ix+1] ) + bpw

# this works - slower than above!
# mean: 0.000854609012604 mean: 0.000996341705322
for ix in xrange(0, len(ftqhf[:-1])):
  ftqhf[ix+1] = ( ftqhf[ix]-tsdb[ix+1] ).clip(0) + bpw


with printoptions(precision=3, suppress=True):
  for ix in range(0,len(tsd)):
    print "{0:.06f}  {1:7.1f} {2:7.1f} {3:7.1f} {4:7.1f} {5:7.1f}".format(
      tsd[ix], tsdb[ix], ftqh1[ix], ftqh2[ix], ftqh12[ix], ftqhf[ix]
    )

# tried - but its' not just cumulative sum:

x = np.array([2,3,4,5,6,7,8])
n = np.array([True, False, False, True, True, False, False])
xx = np.array(x)
#~ xx[n] = 0                                         # [0 3 4 0 0 7 8]
#~ reset_idx = np.zeros(len(x), dtype=int)
#~ reset_idx[n] = np.arange(len(x))[n]               # [0 0 0 3 4 0 0]
#~ reset_idxc = np.maximum.accumulate(reset_idx)     # [0 0 0 3 4 4 4]
#~ cumsum = np.cumsum(xx)                            # [ 2  5  9 14 20 27 35]x [ 0  3  7  7  7 14 22]xx
#~ cumsumr = cumsum[reset_idxc]                      # [ 2  2  2 14 20 20 20]x [ 0  0  0  7  7  7  7]xx
#~ #cumsum-cumsumr                                   # [ 0  3  7  0  0  7 15]x [ 0  3  7  0  0  7 15]xx

xx[~n] = 0                                           # [2 0 0 5 6 0 0]
reset_idx = np.zeros(len(x), dtype=int)
reset_idx[~n] = np.arange(len(x))[~n]                 # [1 0 0 2 5 0 0]
reset_idxc = np.maximum.accumulate(reset_idx)        # [1 1 1 2 5 5 5]
cumsum = np.cumsum(xx)                               # [ 2  2  2  7 13 13 13]
cumsumr = cumsum[reset_idxc]                         # [ 2  2  2  2 13 13 13]
print xx
print reset_idx
print reset_idxc
print cumsum
print cumsumr
print cumsum-cumsumr

# http://stackoverflow.com/questions/9378707/how-can-i-use-numpy-to-calculate-a-series-effectively
# There is no general way to vectorise recursive sequence definitions in NumPy.
# http://stackoverflow.com/questions/4407984/is-a-for-loop-necessary-if-elements-of-the-a-numpy-vector-are-dependant-upon-t

c1 = np.arange(10.)
print "c1", c1
c1[1:] = c1[:-1] + c1[1:]
print "c1", c1
c1 = np.arange(10.)
print "c1[:-1]", c1[:-1]
print "c1[:1] ", c1[1:]
c2 = np.add(c1[:-1], c1[1:], c1[1:])
print "c1    ", c1
print "c2", c2


# >>> a = np.array([1,2,3]) ; np.add(a[:-1], 2, a[1:]) ; print a
# array([3, 5])
# [1 3 5]
# >>> a = np.array([1,2,3]) ; np.add(a[0:1], 2, a[1:2]) ; print a
# array([3])
# [1 3 3]
# >>> a = np.array([1,2,3]) ; np.add(a[1], 5, a[2]) ; print a
# Traceback (most recent call last):
#   File "<stdin>", line 1, in <module>
# TypeError: return arrays must be of ArrayType
# >>> a = np.array([1,2,3]) ; np.add(a[np.array(0)], 2, a[np.array(1)]) ; print a
# Traceback (most recent call last):
#   File "<stdin>", line 1, in <module>
# TypeError: return arrays must be of ArrayType
# >>> a = np.array([1,2,3]) ; np.add(a[[0,1]], 2, a[[1,2]]) ; print a
# array([3, 4])
# [1 2 3]
# >>> a = np.array([1,2,3]) ; np.add(a[0:1], 5, a[1:2]) ; print a
# array([6])
# [1 6 3]
# >>> inds = np.array([0,1])
# >>> a = np.array([1,2,3]) ; np.add(a[inds], 5, a[inds+1]) ; print a
# array([6, 7])
# [1 2 3]
# >>> a = np.array([1,2,3]) ; np.add(a[[inds]], 5, a[[inds+1]]) ; print a
# array([6, 7])
# [1 2 3]
# >>> a = np.array([1,2,3]) ; [np.add(a[ix:ix+1], 5, a[ix+1:ix+2]) for ix in inds]  ; print a
# [array([6]), array([11])]
# [ 1  6 11]


# "Remember that a slicing tuple can always be constructed as obj and used in the x[obj] notation."
# "Advanced indexing always returns a copy of the data (contrast with basic slicing that returns a view)."
# http://scipy-lectures.github.io/intro/numpy/numpy.html "Numpy arrays can be indexed with slices, but also with boolean or integer arrays (masks). This method is called fancy indexing. It creates copies not view."

#~ >>> print slice(1,10,2)
#~ slice(1, 10, 2)
#~ >>> print slice(1,10,2,4)
#~ Traceback (most recent call last):
  #~ File "<stdin>", line 1, in <module>
#~ TypeError: slice expected at most 3 arguments, got 4
#~ >>> print slice(inds)
#~ slice(None, array([0, 1]), None)
#~ >>> print [slice(ix,ix+1) for ix in inds]
#~ [slice(0, 1, None), slice(1, 2, None)]
#~ >>> a = np.array([1,2,3]) ; np.add(a[slice(0,1)], 5, a[slice(1,2)]) ; print a
#~ array([6])
#~ [1 6 3]
#~ >>> print a[slice(0,1), slice(1,2)]
#~ Traceback (most recent call last):
  #~ File "<stdin>", line 1, in <module>
#~ IndexError: too many indices




"""
