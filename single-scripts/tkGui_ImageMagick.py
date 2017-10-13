#!/usr/bin/env python

# (works in python 2.7, linux)
# https://bitbucket.org/executionunit/tkbuilder/src/b0b226933943fb9603d55a4bf0a947bf5860aeda/tkbuilder.py?at=default
# http://stackoverflow.com/questions/665566/python-tkinter-shell-to-gui
# http://stackoverflow.com/questions/4084322/solvedkilling-a-process-created-with-pythons-subprocess-popen
# http://stackoverflow.com/questions/4789837/how-to-terminate-a-python-subprocess-launched-with-shell-true

# edited so it can work with older python (without ttk, and Tkinter without Style)
# just (un)comment corresponding lines to get back that functionality

"""main script that builds the interface and calls main.py"""

import subprocess
import sys
import os, signal
import threading
import time
import Tkinter
from Tkinter import Tk, Text, BOTH, W, N, E, S, END, INSERT, HORIZONTAL, VERTICAL, NONE,\
    StringVar

# from ttk import Frame, Button, Style, Scrollbar, Checkbutton # with ttk
from Tkinter import Frame, Button, Scrollbar, Checkbutton # without ttk
from os.path import join, dirname
from datetime import datetime

import Image, ImageTk
import StringIO
import pprint


#~ mainpath = join(dirname(__file__), "main.py")

#scriptcall = ['bash', './loopchuck.sh',]
#~ scriptcall = ['tail', '-f', '/var/log/syslog']

scriptpath = dirname(os.path.realpath(__file__))
callpath = os.getcwd()

#there has got to be a better way to do this in windows.
pythonpath = "python"
if sys.platform == "win32":
    pythonpath = "c:\python27\python.exe"

worker = None


#~ startcmd = "convert -size 200x100 xc:red bmp:-"
startcmd = """montage \\
  <(convert -size 100x100 xc:red bmp:-) \\
  <(convert -size 100x100 xc:red bmp:-) \\
  -geometry +5+5 bmp:-"""


class AssetBuilder(Frame):

    def __init__(self, parent):
        Frame.__init__(self, parent)

        self.parent = parent
        self.isRunning = False

        self.initUI()

    def initUI(self):

        self.parent.title("ImageMagick caller")
        # self.style = Style()
        # self.style.theme_use("default")
        self.pack(fill=BOTH, expand=1)

        self.mpw = Tkinter.PanedWindow(orient=VERTICAL,sashwidth=2,sashrelief=Tkinter.RAISED,relief=Tkinter.RAISED,showhandle=True)
        self.mpw.pack(fill=BOTH, expand=1)

        self.topfr = Frame(self.mpw)

        #create a grid 5x4 in to which we will place elements.
        self.topfr.columnconfigure(1, weight=1)
        self.topfr.columnconfigure(2, weight=0)
        self.topfr.columnconfigure(3, weight=0)
        self.topfr.columnconfigure(4, weight=0)
        self.topfr.columnconfigure(5, weight=0)
        self.topfr.rowconfigure(1, weight=1)
        self.topfr.rowconfigure(2, weight=0)
        self.topfr.rowconfigure(3, weight=0)
        self.topfr.rowconfigure(4, weight=0)

        #create the main text are with scrollbars
        xscrollbar = Scrollbar(self.topfr, orient=HORIZONTAL)
        xscrollbar.grid(row=2, column=1, columnspan=4, sticky=E + W)

        yscrollbar = Scrollbar(self.topfr, orient=VERTICAL)
        yscrollbar.grid(row=1, column=5, sticky=N + S)

        self.textarea = Text(self.topfr, wrap=NONE, bd=0,
                             xscrollcommand=xscrollbar.set,
                             yscrollcommand=yscrollbar.set)
        self.textarea.grid(row=1, column=1, columnspan=4, rowspan=1,
                            padx=0, sticky=E + W + S + N)
        self.textarea.bind('<Control-Return>', self.runImageMagickCommand)

        xscrollbar.config(command=self.textarea.xview)
        yscrollbar.config(command=self.textarea.yview)

        # don't use bind - use command, so buttons actions can be disabled
        # [http://www.daniweb.com/software-development/python/threads/69669/tkinter-button-disable- Tkinter Button "Disable" ? | DaniWeb]
        #
        #create the buttons/checkboxes to go along the bottom

        self.clearButton = Button(self.topfr, text="Clear", command=self.clearText)
        self.clearButton.grid(row=4, column=1, padx=5, pady=5, sticky=W)
        #~ self.clearButton.bind("<ButtonRelease-1>", self.clearText)

        self.runbutton = Button(self.topfr, text="Run/Call", command=self.runScript, state=Tkinter.DISABLED)
        self.runbutton.grid(row=4, column=3, padx=5, pady=5)
        #~ self.runbutton.bind("<ButtonRelease-1>", self.runScript)

        self.stopbutton = Button(self.topfr, text="Stop", command=self.stopScript, state=Tkinter.DISABLED)
        self.stopbutton.grid(row=4, column=4, padx=5, pady=5)
        #~ self.stopbutton.bind("<ButtonRelease-1>", self.stopScript)

        self.infoVar = StringVar()
        self.infoLabel = Tkinter.Label(self.topfr, textvariable=self.infoVar) #text="[info]")
        self.infoVar.set("[ready]")
        self.infoLabel.grid(row=4, column=2, padx=5, pady=5)

        #tags are used to colorise the text added to the text widget.
        # see self.addTtext and self.tagsForLine
        self.textarea.tag_config("errorstring", foreground="#CC0000")
        self.textarea.tag_config("infostring", foreground="#008800")

        self.addText("#  scriptpath: " + scriptpath + "\n", ("infostring", ))
        self.addText("#    callpath: " + callpath + "\n", ("infostring", ))
        self.addText("# One-line imagemagick call only; \n", ("infostring", ))
        self.addText("#  call is via system (bash); use \\ to separate at newline; \n", ("infostring", ))
        #~ self.addText("#  use \\ to separate at newline; \n", ("infostring", ))
        self.addText("#  comments w/ # at start OK; use bmp:- as out (stdout is read and shown here) \n", ("infostring", ))
        self.addText("#  Run this Python script from terminal, to set scriptpath (to refer to files in same dir) \n", ("infostring", ))
        #~ self.addText("#  use bmp:- as out (stdout is read and shown here) \n", ("infostring", ))
        self.addText("# To call command: click to focus on text editor, and press Ctrl-Return \n", ("infostring", ))
        #~ self.addText("#  and press Ctrl-Return \n", ("infostring", ))
        self.addText("\n", ("infostring", ))
        #~ os.chdir( dirname(os.path.realpath(__file__)) )
        #~ self.addText("Path B: " + os.getcwd() + "\n\n", ("infostring", ))

        #~ self.addText("Script is: " + " ".join(scriptcall) + "\n\n", ("infostring", ))
        self.addText(startcmd)
        self.addText("\n") # one more <Enter> - easier when clicking in textarea for first time

        self.mpw.add(self.topfr)
        # bottom
        self.imgLabel = Tkinter.Label(self.mpw, text="IMG:") # height=10
        self.mpw.add(self.imgLabel)

        #~ print self.mpw.sash_coord(0)
        self.mpw.sash_mark(0)
        #~ self.mpw.sash("dragto", 0, 1, 10)
        # first MUST update root...: http://www.developpez.net/forums/d263794/autres-langages/python-zope/gui/tkinter/probleme-sash-panedwindows/
        self.parent.update()
        # ... then can sash_place(index, x, y) - y is from y=0 @ top
        self.mpw.sash_place(0, 1, 270)
        # right-click/context menu on textarea:
        self.make_menu(self.parent)
        self.textarea.bind("<Button-3><ButtonRelease-3>", self.show_menu)



    def tagsForLine(self, line):
        """return a tuple of tags to be applied to the line of text 'line'
           when being added to the text widet"""
        l = line.lower()
        if "error" in l or "traceback" in l:
            return ("errorstring", )
        return ()

    def addText(self, str, tags=None):
        """Add a line of text to the textWidget. If tags is None then
        self.tagsForLine will be used to assign tags to the line"""
        self.textarea.insert(INSERT, str, tags or self.tagsForLine(str))
        self.textarea.yview(END)

    def clearText(self, event):
        """Clear all the text from the text widget"""
        self.textarea.delete("1.0", END)
        print "isAlive:", self.worker.isAlive(), ", isRunning:", self.isRunning

    def moveCursorToEnd(self):
        """move the cursor to the end of the text widget's text"""
        self.textarea.mark_set("insert", END)

    def runImageMagickCommand(self, event):
      #~ print "runImageMagickCommand"
      # indicate
      self.infoVar.set("[working]")
      # must update here too - otherwise this change not visible:
      self.infoLabel.update_idletasks()
      # fromstring: "Note that this function decodes pixel data, not entire images.
      # If you have an entire image file in a string, wrap it
      # in a StringIO object, and use open to load it."
      #~ cmdstr = "convert -size 200x100 xc:red bmp:-"
      # "Where 1.0 means first line, zeroth character (ie before the first!)
      # is the starting position and END is the ending position."
      cmdstr = self.textarea.get(1.0,END)
      print "cmdstr " + cmdstr
      #~ ims = os.popen(cmdstr).read() # in sh on Linux, not bash
      #~ ims = subprocess.Popen(cmdstr, stdout=subprocess.PIPE, shell=True, executable="/bin/bash").stdout.read() # this is in bash
      # use `communicate` instead, to retrieve stderr too:
      # (here must be stderr=subprocess.PIPE, not subprocess.STDOUT,
      # to have it read in separate variable!
      child_proc = subprocess.Popen(cmdstr, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, executable="/bin/bash")
      stdout_value, stderr_value = child_proc.communicate()
      rc = child_proc.returncode
      if (rc == 0): # all is fine with command:
        ims = stdout_value
        imsiobuf = StringIO.StringIO()
        imsiobuf.write(ims)
        imsiobuf.seek(0) # must after write! http://stackoverflow.com/questions/1664861/
        img = Image.open(imsiobuf)
        imgwidth, imgheight = img.size # img.size[0], img.size[1]
        self.infoVar.set("size: " + str(imgwidth) + "x" + str(imgheight))
        #~ pprint.pprint(self.mpw.config())
        #~ print self.imgLabel.winfo_width(), self.imgLabel.winfo_height() # http://stackoverflow.com/questions/3950687/
        labelwidth, labelheight = self.imgLabel.winfo_width(), self.imgLabel.winfo_height()
        finalwidth, finalheight = imgwidth, imgheight
        # find best fit - only handle if image is bigger
        # force floating point operation
        ratio_w = imgwidth*1.0/labelwidth
        ratio_h = imgheight*1.0/labelheight
        #~ print "imw: %d imh: %d lw: %d lh: %d" % (imgwidth, imgheight, labelwidth, labelheight)
        #~ print "rw: %f rh: %f " % (ratio_w, ratio_h)
        if ((ratio_w > 1.0) or (ratio_h > 1.0)):
          fw1, fh1, fw2, fh2 = 0, 0, 0, 0
          if (ratio_w > 1.0):
            fw1 = labelwidth
            fh1 = imgheight/ratio_w
          if (ratio_h > 1.0):
            fw2 = imgwidth/ratio_h
            fh2 = labelheight
          f1ok = ((fw1 > 0) and (fh1 > 0) and (fw1 <= labelwidth) and (fh1 <= labelheight))
          f2ok = ((fw2 > 0) and (fh2 > 0) and (fw2 <= labelwidth) and (fh2 <= labelheight))
          #~ print "f1ok: %d fw1: %d fh1: %d " % (f1ok, fw1, fh1)
          #~ print "f2ok: %d fw2: %d fh2: %d " % (f2ok, fw2, fh2)
          if (f1ok):
            finalwidth, finalheight = fw1, fh1
          elif (f2ok):
            finalwidth, finalheight = fw2, fh2
          # convert to integers
          finalwidth = int(round(finalwidth))
          finalheight = int(round(finalheight))
          #
        # EXTENT: http://stackoverflow.com/questions/3368740
        imgsz = img.transform((finalwidth, finalheight), Image.EXTENT, (0, 0, imgwidth, imgheight))
         # Convert the Image object into a TkPhoto object
        tkimage = ImageTk.PhotoImage(image=imgsz)
        self.imgLabel.img = tkimage # prevent garbage coll.
        # set image to label:
        self.imgLabel.configure(image=tkimage)
      else: # exit status (rc) not zero - there was a problem
        self.infoVar.set("[ready]")
        # not using stringvar here, since the label
        # could also be an image;
        # see also http://tkinter.unpythonic.net/wiki/PhotoImage for pyimage1
        # http://mail.python.org/pipermail/tutor/2006-November/050922.html:
        # 'setting lbl["image"] = "" worked (as opposed to None, which raises a TclError with the message that pyimage2'
        #~ print stderr_value
        self.imgLabel.configure(image="") #(image=None)
        self.imgLabel.img = None # force garbage coll
        self.imgLabel.configure(text=stderr_value) # here: 'image "pyimage1" doesn't exist' (if image=None)
        self.imgLabel.update_idletasks()
      # finally:
      # when Ctrl-Return pressed, we do not actually want Enter inserted:
      # "prevent Tkinter from propagating the event to other handlers":
      return "break"

    # http://stackoverflow.com/questions/8449053/how-to-make-menubar
    def make_menu(self, w):
      global the_menu
      the_menu = Tkinter.Menu(w, tearoff=0)
      the_menu.add_command(label="Cut")
      the_menu.add_command(label="Copy")
      the_menu.add_command(label="Paste")
      the_menu.add_command(label="Delete")
    def show_menu(self, e):
      global the_menu
      w = e.widget
      the_menu.entryconfigure("Cut",
      command=lambda: w.event_generate("<<Cut>>"))
      the_menu.entryconfigure("Copy",
      command=lambda: w.event_generate("<<Copy>>"))
      the_menu.entryconfigure("Paste",
      command=lambda: w.event_generate("<<Paste>>"))
      #no <<Delete>> as generic event - there is <<Clear>>
      # http://www.tcl.tk/man/tcl8.5/TkCmd/event.htm
      the_menu.entryconfigure("Delete",
      command=lambda: w.event_generate("<<Clear>>"))
      the_menu.tk.call("tk_popup", the_menu, e.x_root, e.y_root)

    # these are older; currently inactive here:
    def runScript(self, event):
        if (not(self.isRunning)):
            self.isRunning = True
            self.worker = threading.Thread(
                target=self.runScriptThread,
                args=(event,))
            self.worker.start()

    def runScriptThread(self, event):
        """callback from the run/call button"""
        self.moveCursorToEnd()
        self.addText("Calling script %s\n" % (str(datetime.now())), ("infostring", ))

        #~ cmdlist = filter(lambda x: x if x else None,
            #~ [pythonpath, mainpath, self.verboseVar.get(), self.forceVar.get()])
        cmdlist = scriptcall

        self.addText(" ".join(cmdlist) + "\n", ("infostring", ))

        self.proc = subprocess.Popen(cmdlist,
                                 stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT,
                                 universal_newlines=True,
                                 preexec_fn=os.setsid)

        while True:
            line = self.proc.stdout.readline()
            if not line:
                break
            self.addText(line)
            #this triggers an update of the text area, otherwise it doesn't update
            self.textarea.update_idletasks()

        self.isRunning = False
        self.addText("Script Finished %s\n" % (str(datetime.now())), ("infostring", ))
        self.addText("*" * 80 + "\n", ("infostring", ))


    def stopScript(self, event):
        """callback from the stop button"""
        #~ os.kill(signal.CTRL_C_EVENT, 0)
        #~ os.kill(self.proc.pid, signal.CTRL_C_EVENT) # AttributeError: 'module' object has no attribute 'CTRL_C_EVENT'
        #~ os.kill(self.proc.pid, signal.SIGTERM)
        os.killpg(self.proc.pid, signal.SIGTERM)
        self.proc.terminate()
        self.proc.kill()
        print self.worker.isAlive() # True here
        # only after this function exits completely,
        # does the os.kill effectuate!
        #~ self.worker.join() # join() locks! (since kill not yet effectuated here)
        # self.worker.isAlive called from clearText - after stop - shows False as expected!


def main():
    root = Tk()
    root.geometry("650x450+300+300")
    AssetBuilder(root)
    root.mainloop()


if __name__ == '__main__':
    main()

