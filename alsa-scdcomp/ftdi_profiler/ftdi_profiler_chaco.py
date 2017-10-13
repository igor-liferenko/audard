#!/usr/bin/env python
################################################################################
# ftdi_profiler_chaco.py                                                       #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# Tue Dec  3 20:49:15 CET 2013 ; Python 2.7.1+

"""
Note: on natty, Python 2.7, numpy/distutils/system_info.py 1.5.1 needs this hack in the file:
https://code.launchpad.net/~jtaylor/ubuntu/precise/python-numpy/multiarch-fix-818867/+merge/87165
then chaco installed via pip - pulls enable itself;
traits are not a requirement otherwise, "import chaco.api" chokes on it though;
These are latest current versions from pip; otherwise had 3.5 previously which I
has to pip uninstall;

$ pip freeze | grep -i 'chaco\|enable\|enthought\|traits\|numpy'
chaco==4.3.0
enable==4.3.0
numpy==1.5.1
traits==4.3.0
traitsui==4.3.0

Note, that is why the chaco imports are different than from the example on:
http://code.enthought.com/projects/chaco/docs/html/user_manual/how_do_i.html

Also, note that np.fromfile cannot handle comments in textual data file, (but can skip); np.genfromtxt can handle comments (and it's not that slower; and can cast to ints/floats as needed)

Also, note that all operating on data has to be collected as ArrayPlotData before plotting
"""

import os, sys, argparse, fnmatch, inspect#, time
from pprint import pprint
import numpy as np
from numpy.lib.recfunctions import append_fields, merge_arrays
from traits.api import HasTraits, Instance, Enum, Button, List, Int
from traitsui.api import View, Item, Action, UItem, ColorTrait, HGroup, VGroup
from chaco.api import Plot, ArrayPlotData, HPlotContainer, VPlotContainer, Legend, OverlayPlotContainer
from enable.component_editor import ComponentEditor
from enable.api import LineStyle
from chaco.tools.api import PanTool, ZoomTool, DragZoom, BetterSelectingZoom, BetterZoom, LegendHighlighter

class LogInspector(HasTraits):

  container = Instance(VPlotContainer) # OverlayPlotContainer VPlotContainer
  files_string_list = List([''])
  enableDropdown = Int(1)
  selected_file_string = Enum(values='files_string_list')
  resetrange = Button("Reset range")
  selected_line_style = Enum( "solid", "dot dash", "dash", "dot", "long dash")

  traits_view = View(
    Item('selected_file_string', label="logfiles", enabled_when='enableDropdown'),
    HGroup(
      UItem('resetrange', width=15),
      Item('selected_line_style', label="", show_label=False)
    ),
    Item('container', editor=ComponentEditor(), show_label=False),
    width=800, height=500, resizable=True,
    #buttons = [resetrange],
    title="Log Inspector"
  )

  def __init__(self, indir):
    super(LogInspector, self).__init__()
    self.basedir=indir
    self.globBasedir()
    self.bgcolor=0x005500 # nowork
    self.data=[]
    self._selected_file_string_changed() # trigger parsing of first entry; also plots
  def plotParsedData(self):
    self.plotdata = ArrayPlotData(x = self.data["ts"], wrdlt = self.data["wrdlt"])
    self.plotA = Plot(self.plotdata)
    self.plotAA = self.plotA.plot(("x", "wrdlt"), type="line", color=(0,0.99,0), spacing=0, padding=0, alpha=0.7, use_downsampling=True, line_style = "dash") #render_style='connectedhold'
    # cache default axes limits
    self.Arng = [ self.plotA.x_axis.mapper.range.low, self.plotA.x_axis.mapper.range.high,
      self.plotA.y_axis.mapper.range.low, self.plotA.y_axis.mapper.range.high]
    self.plotA.x_axis.tick_label_position="inside"
    self.plotA.y_axis.tick_label_position="inside"
    self.container = VPlotContainer(self.plotA, spacing=0, padding=0, bgcolor="lightgray", use_backbuffer = True)
    self.plotA.spacing = 0 # set child padding after container set!
    self.plotA.padding = 0
    self.plotA.tools.append(PanTool(self.plotA))
    self.plotA.tools.append(ZoomTool(self.plotA))
    self.plotA.overlays.append(BetterSelectingZoom(self.plotA))
    legend = Legend(component=self.plotA, padding=1, align="ur")
    # to hide plots, make LegendHighlighter scale line to 0 on selection
    legend.tools.append(LegendHighlighter(legend, line_scale=0.0))
    self.plots = {}
    self.plots["wrdlt"] = self.plotAA
    legend.plots = self.plots
    self.plotA.overlays.append(legend)
    #self.plotA.legend.visible = True # no need
  def globBasedir(self):
    matches = []
    for root, dirnames, filenames in os.walk(self.basedir):
      for filename in fnmatch.filter(filenames, '*repz.txt'):
        matches.append(os.path.join(root, filename))
    #self.data_name = Enum(matches) # no!
    self.files_string_list = matches
  def parseLogs(self, infile):
    pprint("Parsing file");
    # data is reconstructed as array of tuples
    self.data = np.genfromtxt(infile, delimiter=" ", comments="#",
      #dtype="float,float,int,int,int,int,int,int,int,int",
      #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt"]
      dtype="float,float,int,int,int,int,int,int,int,int,int,int,int",
      names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt", "wrdlt", "wbps", "rbps"]
    )
    # iterate; create and append new columns
    if 0: # (note, takes a while, so avoiding)
      pprint("Got %d entries; processing" % (len(self.data)) )
      i = 0; rdtot=0; wrtot=0; rbps = 0; wbps = 0; wt=[]; #wd = []; wa =[]; ra=[];
      for ix in self.data:
        if ix['fid'] == 1:
          wrtot = ix['tot']
          wbps=wrtot/ix['ts'];
        if ix['fid'] == 2:
          rdtot = ix['tot']
          rbps = rdtot/ix['ts']
        #wd.append( wrtot-rdtot)
        #wa.append( wbps );
        #ra.append( rbps );
        wt.append ( (wrtot-rdtot, wbps, rbps) )
      #my_appended_array = append_fields( self.data, names=['wrdlt','wbps','rbps'], dtypes="int,int,int", data=[wd, wa, ra] ) # problem; "expected a readable buffer"
      self.data = merge_arrays([self.data, np.array(wt, dtype=[('wrdlt', int), ('wbps', int), ('rbps', int)]) ], flatten=True) # cast to int works from here
    #end if 0
    pprint("Done.") #(self.data)
  def _selected_file_string_changed(self):
    print(self.selected_file_string)
    self.enableDropdown = 0
    self.parseLogs(self.selected_file_string)
    self.enableDropdown = 1
    self.plotParsedData()
  def _selected_line_style_changed(self):
    print(self.selected_line_style)
    # note, the LinePlot object is in self.plotAA[0]!
    self.plotAA[0].line_style = self.selected_line_style
    #self.plotA.invalidate_and_redraw() # no need
  def _resetrange_fired(self):
    self.plotA.x_axis.mapper.range.set(low=self.Arng[0], high=self.Arng[1])
    self.plotA.y_axis.mapper.range.set(low=self.Arng[2], high=self.Arng[3])

def processCmdLineOptions():
  global optargs
  optparser = argparse.ArgumentParser(description="TODO",
              formatter_class=argparse.RawDescriptionHelpFormatter,
              fromfile_prefix_chars='@')
  optparser.add_argument('-d', '--directory', action='store',
                          type=str, default=".",
                          help="directory to scan; default if unspec'd: \"%(default)s\"")
  optargs = optparser.parse_args(sys.argv[1:]) #(sys.argv)

if __name__ == "__main__":
  processCmdLineOptions()
  LogInspector(optargs.directory).configure_traits()




"""
from traits.api import HasTraits, Instance, Enum, Button
from traitsui.api import View, Item, Action, UItem
from chaco.api import Plot, ArrayPlotData, HPlotContainer, VPlotContainer
from enable.component_editor import ComponentEditor
from numpy import linspace, sin
from chaco.tools.api import PanTool, ZoomTool, DragZoom, BetterSelectingZoom, BetterZoom

class ConnectedRange(HasTraits):

  container = Instance(VPlotContainer)

  data_name = Enum("p0", "p1", "p2")


  #resetrange = Action(name = "Reset range",
  #  action = "_resetToStartingRanges")

  resetrange = Button("Reset range")
  traits_view = View(
    Item('data_name', label="Y data"),
    UItem('resetrange', width=15),
    Item('container', editor=ComponentEditor(), show_label=False),
    width=1000, height=600, resizable=True,
    #buttons = [resetrange],
    title="Data Chooser / Connected Range"
  )

  def __init__(self):
    super(ConnectedRange, self).__init__()

    x = linspace(-14, 14, 100)
    y = sin(x) * x**3

    self.data = {"p0": sin(x),
                 "p1": sin(x) * x**3,
                 "p2": sin(x*2)}

    # note - these are just initial values;
    # changes must be propagated to both y and y2 from _data_name_changed!
    self.plotdata = ArrayPlotData(x = x, y = self.data["p0"], y2 = 0.5*self.data["p0"]) #(x = x, y = y)

    # note: alpha doesn't seem to work with scatter, although it should;
    # rgba spec does seem to work, though
    # plot must refer to name lavbels in arrayplotdata!
    self.scatter = Plot(self.plotdata)
    self.scatter.plot(("x", "y2"), type="line", color=(0,0.99,0), spacing=0, padding=0, padding_left=0, alpha=0.7)
    self.scatter.plot(("x", "y"), type="scatter", color=(0,0,0.99,0.5), spacing=0, padding=0, padding_left=0, alpha=0.2)
    # cache default axes limits
    self.sorng = [ self.scatter.x_axis.mapper.range.low, self.scatter.x_axis.mapper.range.high,
      self.scatter.y_axis.mapper.range.low, self.scatter.y_axis.mapper.range.high]


    self.line = Plot(self.plotdata)
    self.line.plot(("x", "y"), type="line", color="blue", spacing=0, padding=0, padding_right=0, alpha=0.5)
    self.lorng = [ self.line.x_axis.mapper.range.low, self.line.x_axis.mapper.range.high,
      self.line.y_axis.mapper.range.low, self.line.y_axis.mapper.range.high]


    self.container = VPlotContainer(self.scatter, self.line, spacing=0, padding=0, bgcolor="lightgray")
    # difference shown only after placing in the container!
    self.container.spacing = 0
    self.scatter.padding = 0
    self.line.padding = 0

    self.scatter.tools.append(PanTool(self.scatter))
    self.scatter.tools.append(ZoomTool(self.scatter))

    self.line.tools.append(PanTool(self.line))
    self.line.tools.append(ZoomTool(self.line))
    #line.tools.append(DragZoom(line)) # interferes with PanTool, also not a zoom box
    # BetterSelectingZoom goes to overlays - not tools! And even when alone,
    # requires Ctrl + left mouse button to show up! So can be used with PanTool+ZoomTool!
    self.line.overlays.append(BetterSelectingZoom(self.line))

    self.scatter.range2d = self.line.range2d

  def _data_name_changed(self):
    self.plotdata.set_data("y", self.data[self.data_name])
    self.plotdata.set_data("y2", 0.5*self.data[self.data_name])

  def _resetrange_fired(self):
  #def _resetToStartingRanges(self, info):
    print "Here"
    self.scatter.x_axis.mapper.range.set(low=self.sorng[0], high=self.sorng[1])
    self.scatter.y_axis.mapper.range.set(low=self.sorng[2], high=self.sorng[3])
    self.line.x_axis.mapper.range.set(low=self.lorng[0], high=self.lorng[1])
    self.line.y_axis.mapper.range.set(low=self.lorng[2], high=self.lorng[3])

if __name__ == "__main__":
  ConnectedRange().configure_traits()
"""


"""
import wx
import numpy as np

from chaco.api import HPlotContainer, create_line_plot
#from enable.wx.gl import Window # needs pyglet
#from enable.wx.quartz import Window # needs mac_context
#from enable.wx.image import Window # ok
from enable.wx.cairo import Window # ok

class PlotFrame(wx.Frame):
  def __init__(self, *args, **kw):
    kw["size"] = (850, 550)
    wx.Frame.__init__( *(self,) + args, **kw )
    self.plot_window = Window(self, component=self._create_plot())
    sizer = wx.BoxSizer(wx.HORIZONTAL)
    sizer.Add(self.plot_window.control, 1, wx.EXPAND)
    self.SetSizer(sizer)
    self.SetAutoLayout(True)
    self.Show(True)
    return

  def _create_plot(self):
    x = np.arange(-5.0, 15.0, 20.0/100)
    y = np.sin(x)
    plot = create_line_plot((x,y), bgcolor="white",
                                add_grid=True, add_axis=True)
    container = HPlotContainer(spacing=20, padding=50, bgcolor="lightgray")
    container.add(plot)
    return container

if __name__ == "__main__":
  app = wx.PySimpleApp()
  frame = PlotFrame(None)
  app.MainLoop()
"""


"""
see also:
[https://groups.google.com/forum/?_escaped_fragment_=topic/wxpython-users/P7djirDdeyM#!topic/wxpython-users/P7djirDdeyM RFC: matplotlib vs. Chaco - Google Groups]
http://stackoverflow.com/questions/13014297/translating-a-gridded-csv-file-with-numpy
http://stackoverflow.com/questions/5854515/large-plot-20-million-samples-gigabytes-of-data
http://docs.enthought.com/chaco/user_manual/chaco_tutorial.html
http://docs.scipy.org/doc/numpy/reference/generated/numpy.genfromtxt.html
http://stackoverflow.com/questions/5226311/installing-specific-package-versions-with-pip
https://www.enthought.com/repo/ets/
http://stackoverflow.com/questions/17697598/how-to-restore-chaco-plot-axes-to-default-settings-after-using-tools
[https://mail.enthought.com/pipermail/enthought-dev/2010-November/027563.html [Enthought-Dev] Enum usage question]
http://stackoverflow.com/questions/15815854/how-to-add-column-to-numpy-array
"""

