#!/usr/bin/env python
# coding: utf-8

"""
    wxPDFViewer - Simple PDF Viewer using Python-Poppler and wxPython
    Marcelo Fidel Fernandez - BSD License
    http://www.marcelofernandez.info - marcelo.fidel.fernandez@gmail.com

    http://code.activestate.com/recipes/577195-wxpython-pdf-viewer-using-poppler/
    wxPython PDF Viewer using Poppler « Python recipes « ActiveState Code

    mod sdaau Nov 2012:
    * accepts multiple files at command line:

      python -d pdfview.py $(find `pwd` -name '*.pdf')
      python -d pdfview.py $(ls `pwd`/*.pdf)

    * can switch between files (PDF documents) by using keys N(ext) and B(ack)
    ** (zoom is preserved when switching; but scrollbars are not reset)

"""

import wx
import wx.lib.wxcairo as wxcairo
import sys
import poppler


class PDFWindow(wx.ScrolledWindow):
    """ This example class implements a PDF Viewer Window, handling Zoom and Scrolling """

    MAX_SCALE = 6 # was 2
    MIN_SCALE = 1
    SCROLLBAR_UNITS = 20  # pixels per scrollbar unit

    def __init__(self, parent):
        wx.ScrolledWindow.__init__(self, parent, wx.ID_ANY)
        # Wrap a panel inside
        self.myparent = parent
        self.panel = wx.Panel(self)
        # Initialize variables
        self.n_page = 0
        self.scale = 1
        self.document = None
        self.n_pages = None
        self.current_page = None
        self.width = None
        self.height = None
        self.maxdocind = 0
        self.current_docind = 0
        # Connect panel events
        self.panel.Bind(wx.EVT_PAINT, self.OnPaint)
        self.panel.Bind(wx.EVT_KEY_DOWN, self.OnKeyDown)
        self.panel.Bind(wx.EVT_LEFT_DOWN, self.OnLeftDown)
        self.panel.Bind(wx.EVT_RIGHT_DOWN, self.OnRightDown)

    def LoadDocument(self, file):
        self.document = poppler.document_new_from_file("file://" + file, None)
        self.n_pages = self.document.get_n_pages()
        self.current_page = self.document.get_page(self.n_page)
        self.width, self.height = self.current_page.get_size()
        self._UpdateSize()
        self._UpdateScale(self.scale)
        self.myparent.SetTitle(file)


    def OnPaint(self, event):
        dc = wx.PaintDC(self.panel)
        cr = wxcairo.ContextFromDC(dc)
        cr.set_source_rgb(1, 1, 1)  # White background
        if self.scale != 1:
            cr.scale(self.scale, self.scale)
        cr.rectangle(0, 0, self.width, self.height)
        cr.fill()
        self.current_page.render(cr)

    def OnLeftDown(self, event):
        self._UpdateScale(self.scale + 0.2)

    def OnRightDown(self, event):
        self._UpdateScale(self.scale - 0.2)

    def _UpdateScale(self, new_scale):
        if new_scale >= PDFWindow.MIN_SCALE and new_scale <= PDFWindow.MAX_SCALE:
            self.scale = new_scale
            # Obtain the current scroll position
            prev_position = self.GetViewStart()
            # Scroll to the beginning because I'm going to redraw all the panel
            self.Scroll(0, 0)
            # Redraw (calls OnPaint and such)
            self.Refresh()
            # Update panel Size and scrollbar config
            self._UpdateSize()
            # Get to the previous scroll position
            self.Scroll(prev_position[0], prev_position[1])

    def _UpdateSize(self):
        u = PDFWindow.SCROLLBAR_UNITS
        self.panel.SetSize((self.width*self.scale, self.height*self.scale))
        self.SetScrollbars(u, u, (self.width*self.scale)/u, (self.height*self.scale)/u)

    def OnKeyDown(self, event):
        update = True
        # More keycodes in http://docs.wxwidgets.org/stable/wx_keycodes.html#keycodes
        keycode = event.GetKeyCode()
        if keycode in (wx.WXK_PAGEDOWN, wx.WXK_SPACE):
            next_page = self.n_page + 1
        elif keycode == wx.WXK_PAGEUP:
            next_page = self.n_page - 1
        elif keycode == 78: # n
            sys.stdout.write( "press N " )
            tmpmax = self.maxdocind-1
            if (self.current_docind < tmpmax):
                self.current_docind += 1
                sys.stdout.write( "+ " + str(self.current_docind) + " " + str(tmpmax))
                self.LoadDocument(sys.argv[self.current_docind])
                self.SetFocus()
            print
            return
        elif keycode == 66:
            sys.stdout.write( "press B " )
            if (self.current_docind > 1):
                self.current_docind -= 1
                sys.stdout.write( "- " + str(self.current_docind) )
                self.LoadDocument(sys.argv[self.current_docind])
                self.SetFocus()
            print
            return
        elif keycode == 82:
            print( "press R(eset)" )
            self.Scroll(0, 0)
            self.Refresh()
            self.SetFocus()
            print
            return
        else:
            update = False
        if update and (next_page >= 0) and (next_page < self.n_pages):
                self.n_page = next_page
                self.current_page = self.document.get_page(next_page)
                self.Refresh()


class MyFrame(wx.Frame):

    def __init__(self):
        wx.Frame.__init__(self, None, -1, "wxPdf Viewer", size=(680,480))
        self.pdfwindow = PDFWindow(self)
        self.pdfwindow.maxdocind = len(sys.argv)
        self.pdfwindow.current_docind = 1
        print "." + str(self.pdfwindow.current_docind) + " . " + str((self.pdfwindow.maxdocind-1))
        self.pdfwindow.LoadDocument(sys.argv[self.pdfwindow.current_docind])
        self.pdfwindow.SetFocus() # To capture keyboard events


if __name__=="__main__":
    app = wx.App()
    f = MyFrame()
    f.Show()
    app.MainLoop()
