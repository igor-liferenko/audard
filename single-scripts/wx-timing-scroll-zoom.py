#!/usr/bin/python
# -*- coding: utf-8 -*-

import wx, wx.lib.scrolledpanel
import math

"""
wx-timing-scroll-zoom.py: example of mousewheel zoom in scrollable panels; for timing diagrams
copyleft sdaau, Mar 2011
"""

color_Bkg = wx.Colour(224, 224, 224)
color_SigBkg = wx.Colour(244, 124, 244)
color_SigNameBkg = 'AQUAMARINE' # wx.Colour(244, 124, 244)
color_TicksBkg = 'AQUAMARINE' # wx.Colour(244, 124, 244)
leftColWidth = 60
rowHeight = 30
cellBorder = wx.SIMPLE_BORDER # wx.SIMPLE_BORDER # wx.NO_BORDER

global zoom, zoombase, zoommax, zoommin, lab_Zoom, totzoom, pixstep
zoom = 0
zoombase = 1.3 # 2 # zoombase^zoom; neg numbers < 1 .. 
zoommax = 20
zoommin = -20
timescale = 20 # timescale, in ns (just for text labels) 
basepix = 10 # timescale, in pixels


class CustomLine(wx.Panel): #PyControl
	"""
	A custom class for a line
	"""
	def __init__(self, parent, id=wx.ID_ANY, label="", pos=wx.DefaultPosition,
			size=wx.DefaultSize, style=wx.NO_BORDER, validator=wx.DefaultValidator,
			name="CustomLine"):
		"""
		Default class constructor.

		@param parent: Parent window. Must not be None.
		@param id: CustomLine identifier. A value of -1 indicates a default value.
		@param label: Text to be displayed next to the checkbox.
		@param pos: CustomLine position. If the position (-1, -1) is specified
					then a default position is chosen.
		@param size: CustomLine size. If the default size (-1, -1) is specified
					 then a default size is chosen.
		@param style: not used in this demo, CustomLine has only 2 state
		@param validator: Window validator.
		@param name: Window name.
		"""
		#~ wx.PyControl.__init__(self, parent, id, pos, size, style, validator, name)
		wx.Panel.__init__(self, parent, id, pos, size, style)
		
		# Bind the events related to our control: first of all, we use a
		# combination of wx.BufferedPaintDC and an empty handler for
		# wx.EVT_ERASE_BACKGROUND (see later) to reduce flicker
		self.Bind(wx.EVT_PAINT, self.OnPaint)
		self.Bind(wx.EVT_ERASE_BACKGROUND, self.OnEraseBackground)
		self.lpen = wx.Pen('yellow', 2, wx.SOLID)	
		self.imagebkg = wx.EmptyImage( 10, 10 )
		#~ self.imagebkg.SetData((255,255,255))
		#~ self.imagebkg.SetAlphaData((1))

	def OnPaint(self, event):
		""" Handles the wx.EVT_PAINT event for CustomLine. """

		# If you want to reduce flicker, a good starting point is to
		# use wx.BufferedPaintDC.
		pdc = wx.BufferedPaintDC(self)
		dc = wx.GCDC(pdc) 

		# Is is advisable that you don't overcrowd the OnPaint event
		# (or any other event) with a lot of code, so let's do the
		# actual drawing in the Draw() method, passing the newly
		# initialized wx.BufferedPaintDC
		self.Draw(dc)

	def Draw(self, dc):
		"""
		Actually performs the drawing operations, for the bitmap and
		for the text, positioning them centered vertically.
		"""

		# Get the actual client size of ourselves
		width, height = self.GetClientSize()

		if not width or not height:
			# Nothing to do, we still don't have dimensions!
			return

		# Initialize the wx.BufferedPaintDC, assigning a background
		# colour and a foreground colour (to draw the text)
		#~ backColour = self.GetBackgroundColour()
		#~ backBrush = wx.Brush((1,1,1,150), wx.TRANSPARENT) # backColour
		#~ backBrush = wx.Brush((10,10,1,150)) # backColour
		dc.SetBackground(wx.TRANSPARENT_BRUSH) #() backBrush
		#~ dc.SetBackgroundMode(wx.TRANSPARENT)
		dc.Clear()

		dc.SetPen(self.lpen)
		dc.DrawLine(0, 0, 100, 100)

	def OnEraseBackground(self, event):
		""" Handles the wx.EVT_ERASE_BACKGROUND event for CustomLine. """

		# This is intentionally empty, because we are using the combination
		# of wx.BufferedPaintDC + an empty OnEraseBackground event to
		# reduce flicker
		pass



class SignalNamePanel(wx.Panel):
	def __init__(self, parent):
		wx.Panel.__init__(self, parent, size=(-1, rowHeight), style=cellBorder)
		self.SetMinSize((-1, rowHeight)) # THIS to fix height! SetInitialSize loses hor. scrollbar!
		self.SetBackgroundColour(color_SigNameBkg)
		
		self.mytitle=wx.StaticText(self, -1, "Signals:")
		self.mysizer=wx.BoxSizer(wx.HORIZONTAL)
		self.mysizer.Add(self.mytitle, 0, wx.EXPAND)
		
		self.SetSizer(self.mysizer)
		
class SignalEntryPanel(wx.Panel):
	def __init__(self, parent):
		wx.Panel.__init__(self, parent, size=(-1, rowHeight), style=cellBorder)
		self.SetMinSize((-1, rowHeight)) # THIS to fix height! 
		self.SetMinSize((2000, rowHeight)) 
		self.SetBackgroundColour(color_SigBkg)
		
		
		self.mysizer=wx.BoxSizer(wx.HORIZONTAL)
		
		# add a panel 
		#~ self.mypanel = wx.Panel(self, -1, style=wx.SIMPLE_BORDER)
		#~ self.mysizer.Add(self.mypanel, 1)
		
		# test content
		#~ sizer=wx.BoxSizer(wx.HORIZONTAL)
		#~ text = "|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_ "
		#~ static_text=wx.StaticText(self.mypanel, -1, text)
		#~ sizer.Add(static_text, wx.EXPAND, 0)
		
		self.SetSizer(self.mysizer)
		self.Bind(wx.EVT_PAINT, self.OnPaint) 
		self.Bind(wx.EVT_MOTION, self.OnSigMotion) 

		
	def OnPaint(self, event):
		#~ dc = wx.PaintDC(self)
		dc = wx.PaintDC(event.GetEventObject())
		pen = wx.Pen('blue', 2, wx.SOLID)		
		dc.SetPen(pen)
		
		dc.DrawLine(0, 0, 100, 20)
		dc.DrawLine(0, 0, 50, 40)
		dc.DrawLine(0, 0, 2000, 60)

	def OnSigMotion(self, event):
		# move 'ghost' pointer when moving here. 
		# getting the 'scaled' coordinated - and we should be same size as TicksPanel
		pframe = event.GetEventObject().GetParent().GetParent().GetParent()
		print event.GetX(), event.GetY(), pframe.panel
		return

class TicksPanel(wx.Panel):
	def __init__(self, parent):
		wx.Panel.__init__(self, parent, size=(-1, rowHeight), style=cellBorder)
		self.myparent = parent
		self.SetMinSize((-1, rowHeight)) # THIS to fix height! 
		self.SetMinSize((2000, rowHeight)) 
		self.SetBackgroundColour(color_TicksBkg)
		
		self.mysizer=wx.BoxSizer(wx.HORIZONTAL)
		
		self.SetSizer(self.mysizer)
		self.Bind(wx.EVT_PAINT, self.OnPaint) 
		self.Bind(wx.EVT_MOUSEWHEEL, self.OnWheel) 
		
	def OnPaint(self, event):		
		#~ dc = wx.PaintDC(self)
		sz = wx.Panel.GetSize(self)
		dc = wx.PaintDC(event.GetEventObject())
		pen = wx.Pen('black', 1, wx.SOLID)
		dc.SetPen(pen)
		totzoom = zoombase ** zoom # python ** is ^ exponentiation
		pixstep = int(math.ceil(basepix/totzoom))
		
		for ix in range(0, sz.x, pixstep):
			dc.DrawLine(ix, 0, ix, 50)
			
	def OnWheel(self, event):
		# inside handler - need globals
		global zoom, zoombase, zoommax, zoommin, lab_Zoom		
		#~ for ix in dir(event):
			#~ print ix, eval('event.'+ix)
		#~ print event.Button, event.EventType, event.ButtonDown(), event.ControlDown(), event.CmdDown(), event.GetButton(), event.GetWheelDelta(), event.GetWheelRotation(), event.GetX(), event.GetY()
		#parnt = event.EventObject.myparent.myparent # should be TicksPanel.myparent.myparent
		if event.ControlDown():
			if ( event.GetWheelRotation() > 0 ): 
				#~ print "YUP"
				if zoom < zoommax:
					zoom += 1
			else:
				#~ print "NUP"
				if zoom > zoommin:
					zoom -= 1
			lab_Zoom.SetLabel(str(zoom))
			event.EventObject.Refresh()
				

class SignalsScrollPanel(wx.lib.scrolledpanel.ScrolledPanel):
	def __init__(self, parent):
		wx.lib.scrolledpanel.ScrolledPanel.__init__(self, parent, id=-1, style=wx.HSCROLL|wx.VSCROLL)
		self.myparent = parent
		self.SetupScrolling()
		
		# test
		sizer=wx.BoxSizer(wx.VERTICAL)
		
		pan_s1 = TicksPanel(self)
		sizer.Add(pan_s1, 0, wx.EXPAND)
		pan_s2 = SignalEntryPanel(self)
		sizer.Add(pan_s2, 0, wx.EXPAND)
		
		#~ text = "Ooga booga Ooga booga Ooga booga Ooga booga \n" * 50
		#~ static_text=wx.StaticText(self, -1, text)
		#~ sizer.Add(static_text, wx.EXPAND, 0)
		
		self.SetSizer(sizer)

		
class SignalsNameScrollPanel(wx.lib.scrolledpanel.ScrolledPanel):
	def __init__(self, parent):
		wx.lib.scrolledpanel.ScrolledPanel.__init__(self, parent, id=-1, style=wx.HSCROLL)
		self.SetMinSize((leftColWidth,-1)) # instead of arg: size=(leftColWidth,-1), 
		self.SetupScrolling()
		
		# test
		sizer=wx.BoxSizer(wx.VERTICAL)
		
		pan_s1 = SignalNamePanel(self)
		pan_s1.SetSize(wx.Size(-1, rowHeight))
		sizer.Add(pan_s1, 0, wx.EXPAND)
		pan_s2 = SignalNamePanel(self)
		pan_s2.mytitle.SetLabel("AAAAAAAAAAAAAAA")
		pan_s2.mysizer.Layout()
		sizer.Add(pan_s2, 0, wx.EXPAND)
		
		#~ text = "Ooga booga Ooga booga Ooga booga Ooga booga \n" * 50
		#~ static_text=wx.StaticText(self, -1, text)
		#~ sizer.Add(static_text, wx.EXPAND, 0)
		
		self.SetSizer(sizer)
		

class WxTimingScrollZoom(wx.Frame):
	def __init__(self, parent, title):
		global lab_Zoom
		super(WxTimingScrollZoom, self).__init__(parent, title=title, 
			size=(250, 150))

		# the master panel of the frame - "Add a panel so it looks correct on all platforms"
		self.panel = wx.Panel(self, wx.ID_ANY)
		self.panel.SetBackgroundColour(color_Bkg)


		# want these buttons absolutely positioned
		# must be children of panel - if panel is to encompass them! 
		self.btn_addSig = wx.Button(self.panel, id=1, label='+S', size=(30, 30))#, pos=(10, 10))
		self.btn_addSig.SetToolTip(wx.ToolTip("Add Signal Track"))
		self.btn_addClk = wx.Button(self.panel, id=2, label='+C', size=(30, 30))#, pos=(45, 10))
		self.btn_addClk.SetToolTip(wx.ToolTip("Add Clock Track"))
		self.btn_addDat = wx.Button(self.panel, id=3, label='+D', size=(30, 30))#, pos=(80, 10))
		self.btn_addDat.SetToolTip(wx.ToolTip("Add Data Track"))
		lab_Zoom = wx.StaticText(self.panel, -1, "0")
		lab_Zoom.SetToolTip(wx.ToolTip("Zoom Level"))
		
		# vertical 'spacer' - not used anymore (just for reference) 
		# comment it - else it shows as a square in top left corner! 
		#~ vertspacer = wx.Panel(self.panel)
		#~ vertspacer.SetBackgroundColour(color_Bkg)

		btnsizer = wx.BoxSizer(wx.HORIZONTAL)
		btnsizer.Add(self.btn_addSig, 0)
		btnsizer.Add(self.btn_addClk, 0)
		btnsizer.Add(self.btn_addDat, 0)
		btnsizer.Add(lab_Zoom, 1)
		
		# signals scrollable panel
		sigscrollsizer = wx.BoxSizer(wx.HORIZONTAL)
		
		self.pan_signames = SignalsNameScrollPanel(self.panel)
		self.pan_sigs = SignalsScrollPanel(self.panel)
		
		sigscrollsizer.Add(self.pan_signames, 0, wx.EXPAND)
		sigscrollsizer.Add(self.pan_sigs, 1, wx.EXPAND)
		
		
		mastersizer = wx.BoxSizer(wx.VERTICAL)
		mastersizer.Add(btnsizer, 0, wx.EXPAND)
		mastersizer.Add(sigscrollsizer, 1, wx.EXPAND)
		
		self.pline = CustomLine(self.pan_sigs, size=(-1,100))

		
		self.panel.SetSizer(mastersizer)
		#~ mastersizer.Layout() 
		#~ mastersizer.Fit(self) # makes the window as large as the buttons

		self.Centre()
		self.Show()
	
		
if __name__ == '__main__':
	app = wx.App()
	WxTimingScrollZoom(None, 'Wx Timing')
	app.MainLoop()



"""
References:
http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/wx-sizer-test.py
http://www.zetcode.com/wxpython/gdi/
http://stackoverflow.com/questions/1147581/scrolling-through-a-wx-scrolledpanel-with-the-mouse-wheel-and-arrow-keys
http://wiki.wxpython.org/VerySimpleDrawing (Draw a line to a panel)
http://www.daniweb.com/code/snippet216737.html (Button demo)
http://wxpython-users.1045709.n5.nabble.com/Question-about-wx-lib-scrolledpanel-td3377119.html
http://www.python-forum.org/pythonforum/viewtopic.php?f=4&t=17138&start=0 ([wxpython] ScrolledPanel in a notebook)
http://wxpython-users.1045709.n5.nabble.com/Scrolling-of-dynamically-resized-panel-using-ScrolledPanel-td2367509.html
http://www.python-forum.org/pythonforum/viewtopic.php?f=2&t=13233  wx.Panel multiple panels and sizers
http://stackoverflow.com/questions/1040290/wx-panel-scales-to-fit-entire-parent-frame-despite-giving-it-a-size
http://markmail.org/message/75der5vrftvrrrqj Re: [wxpython-users] Re: sizers, panel sizes, and FIXED_MINSIZE - Mike Driscoll - com.googlegroups.wxpython-users - MarkMail
http://www.python-forum.org/pythonforum/viewtopic.php?f=2&t=9908 www.python-forum.org • View topic - wx.Pen settings
http://wiki.wxpython.org/CreatingCustomControls
[http://groups.google.com/group/wxpython-users/browse_thread/thread/a02a0c6de6c7ce91 wx.PaintDC and SetBackgroundMode( wx.TRANSPARENT ) support - wxPython-users | Google Groups]
[http://markmail.org/message/h7qy3eiwd2j5ubcp Re: [wxPython-users] wx.Overlay - Chris Mellon - com.googlegroups.wxpython-users - MarkMail] (both examples work)
[http://aroberge.blogspot.com/2004/12/wxpython-woes.html Only Python: wxPython woes] (examples works, but kinda nasty)
http://wxpython-users.1045709.n5.nabble.com/saving-content-of-the-panel-into-PNG-file-td2362059.html
http://www.linuxquestions.org/questions/programming-9/wxwidgets-wxpython-drawing-problems-with-onpaint-event-703946/
http://bytes.com/topic/python/answers/690783-wxpython-drawing-without-paint-event (the frame has Draw methods that draw into a BufferedDC, which is
chained to a bitmap member, inside the paint method, the bitmap member is drawn to screen)
https://github.com/freephys/wxPython-In-Action/blob/357aa1197d7108739be60e95250e76f82aabed24/Chapter-06/example1.py
https://github.com/freephys/wxPython-In-Action/blob/357aa1197d7108739be60e95250e76f82aabed24/Chapter-18/timer.py
https://github.com/freephys/wxPython-In-Action/blob/357aa1197d7108739be60e95250e76f82aabed24/Chapter-12/radargraph.py
[http://www.daniweb.com/code/snippet216881.html Drawing on a wxPython surface - Python]
"""

