import wx

"""
wx sizer test example, copyleft sdaau 2011 :)
http://wiki.wxpython.org/AnotherTutorial
http://wiki.wxpython.org/wxPython%20by%20Example
http://wiki.wxpython.org/BoxSizerTutorial
http://stackoverflow.com/questions/3104323/getting-a-wxpython-panel-item-to-expand
http://stackoverflow.com/questions/1032138/wxpython-good-way-to-overlay-a-wx-panel-on-an-existing-wx-panel
http://stackoverflow.com/questions/1034399/wxpython-making-something-expand
http://www.codeguru.com/forum/showthread.php?t=455996 - panel in wxPython
http://www.daniweb.com/forums/thread111756.html wxPython Size Property - Python
http://osdir.com/ml/wxpython-users/2010-02/msg00423.html Re: [wxPython-users] Can two stage creation bypass Freeze problem? And how? - msg#00423
http://stackoverflow.com/questions/730394/wxpython-making-a-fixed-height-panel
http://stackoverflow.com/questions/5154530/wxpython-nested-sizers-and-little-square-in-top-left-corner
"""

class MyTestPanel(wx.Panel):
	def __init__(self, parent):
		wx.Panel.__init__(self, parent, size=(-1, 30))
		self.SetBackgroundColour(wx.Colour(224, 124, 224))
		
		self.mytitle=wx.StaticText(self, -1, "TestTitle")
		self.mysizer=wx.BoxSizer(wx.HORIZONTAL)
		self.mysizer.Add(self.mytitle, 0, wx.FIXED_MINSIZE)
		
		# add a panel 
		self.mypanel = wx.Panel(self, -1, style=wx.SIMPLE_BORDER)
		self.mypanel.SetBackgroundColour(wx.Colour(124, 124, 224))
		self.mysizer.Add(self.mypanel, 1)
		
		self.SetSizer(self.mysizer)
		self.SetSize(wx.Size(-1, 30))
		#~ self.mysizer.Layout() 
		#~ self.mysizer.Fit(self) # needed here
		#~ self.mytitle.SetPosition(wx.Point(0,0)) # relative to parent position


class MyTestFrame(wx.Frame):
	def __init__(self, parent, title):
		super(MyTestFrame, self).__init__(parent, title=title, 
			size=(250, 150))

		# the master panel of the frame - "Add a panel so it looks correct on all platforms"
		self.panel = wx.Panel(self, wx.ID_ANY)
		self.panel.SetBackgroundColour(wx.Colour(124, 224, 124))


		# want these buttons absolutely positioned
		# must be children of panel - if panel is to encompass them! 
		btn_A = wx.Button(self.panel, id=1, label='A', size=(30, 30))#, pos=(10, 10))
		btn_A.SetBackgroundColour(wx.Colour(224, 124, 124))
		btn_B = wx.Button(self.panel, id=2, label='B', size=(30, 30))#, pos=(45, 10))
		btn_C = wx.Button(self.panel, id=3, label='C', size=(30, 30))#, pos=(80, 10))

		# additional object - again, a child of this self.panel!
		self.tpan = MyTestPanel(self.panel)

		
		btnsizer = wx.BoxSizer(wx.HORIZONTAL)
		btnsizer.Add(btn_A, 0)
		btnsizer.Add(btn_B, 0)
		btnsizer.Add(btn_C, 0)
		
		mastersizer = wx.BoxSizer(wx.VERTICAL)
		mastersizer.Add(btnsizer, 0, wx.EXPAND)
		#~ mastersizer.Add(self.tpan.mysizer, 1, wx.EXPAND)	# NOT the sizer...
		mastersizer.Add(self.tpan, 0, wx.EXPAND)			# ... but the object!
		
		# up to this point, .tpan sticks to bottom.. must add flexible space? yes.. 
		## (self.tpan, 1) sticks to bottom - (self.tpan, 0) doesn't (only to right)
		## but we still must have the panels below as flexible spaces:
		## also (btnsizer, 1) pushes tpan away - (btnsizer, 0) makes it stick to it; 
		##  but still - seems we have to have wx.EXPAND here! 
		
		vertspacer = wx.Panel(self.panel)
		vertspacer.SetBackgroundColour(wx.Colour(124, 224, 124))
		mastersizer.Add(vertspacer, 1, wx.EXPAND)
		mastersizer.Add(MyTestPanel(self.panel), 0, wx.EXPAND) 
		mastersizer.Add(   wx.Panel(self.panel), 1, wx.EXPAND) 
		mastersizer.Add(vertspacer, 1, wx.EXPAND)
		
		
		self.panel.SetSizer(mastersizer)
		#~ mastersizer.Layout() 
		#~ mastersizer.Fit(self) # makes the window as large as the buttons

		self.Centre()
		self.Show()
		
		
if __name__ == '__main__':
	app = wx.App()
	MyTestFrame(None, 'Test')
	app.MainLoop()
