#!/usr/bin/env python
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
from Tkinter import Tk, Text, BOTH, W, N, E, S, END, INSERT, HORIZONTAL, VERTICAL, NONE,\
    StringVar

# from ttk import Frame, Button, Style, Scrollbar, Checkbutton # with ttk
from Tkinter import Frame, Button, Scrollbar, Checkbutton # without ttk
from os.path import join, dirname
from datetime import datetime

#~ mainpath = join(dirname(__file__), "main.py")
scriptcall = ['tail', '-f', '/var/log/syslog']
#scriptcall = ['bash', './loopchuck.sh',]

#there has got to be a better way to do this in windows.
pythonpath = "python"
if sys.platform == "win32":
    pythonpath = "c:\python27\python.exe"

worker = None

class AssetBuilder(Frame):

    def __init__(self, parent):
        Frame.__init__(self, parent)

        self.parent = parent
        self.isRunning = False

        self.initUI()

    def initUI(self):

        self.parent.title("Script Runner/Caller")
        # self.style = Style()
        # self.style.theme_use("default")
        self.pack(fill=BOTH, expand=1)

        #create a grid 5x4 in to which we will place elements.
        self.columnconfigure(1, weight=1)
        self.columnconfigure(2, weight=0)
        self.columnconfigure(3, weight=0)
        self.columnconfigure(4, weight=0)
        self.columnconfigure(5, weight=0)
        self.rowconfigure(1, weight=1)
        self.rowconfigure(2, weight=0)
        self.rowconfigure(3, weight=0)

        #create the main text are with scrollbars
        xscrollbar = Scrollbar(self, orient=HORIZONTAL)
        xscrollbar.grid(row=2, column=1, columnspan=4, sticky=E + W)

        yscrollbar = Scrollbar(self, orient=VERTICAL)
        yscrollbar.grid(row=1, column=5, sticky=N + S)

        self.textarea = Text(self, wrap=NONE, bd=0,
                             xscrollcommand=xscrollbar.set,
                             yscrollcommand=yscrollbar.set)
        self.textarea.grid(row=1, column=1, columnspan=4, rowspan=1,
                            padx=0, sticky=E + W + S + N)

        xscrollbar.config(command=self.textarea.xview)
        yscrollbar.config(command=self.textarea.yview)

        #create the buttons/checkboxes to go along the bottom
        self.clearButton = Button(self, text="Clear")
        self.clearButton.grid(row=3, column=1, padx=5, pady=5, sticky=W)
        self.clearButton.bind("<ButtonRelease-1>", self.clearText)


        self.runbutton = Button(self, text="Run/Call")
        self.runbutton.grid(row=3, column=3, padx=5, pady=5)
        self.runbutton.bind("<ButtonRelease-1>", self.runScript)

        self.stopbutton = Button(self, text="Stop")
        self.stopbutton.grid(row=3, column=4, padx=5, pady=5)
        self.stopbutton.bind("<ButtonRelease-1>", self.stopScript)

        #tags are used to colorise the text added to the text widget.
        # see self.addTtext and self.tagsForLine
        self.textarea.tag_config("errorstring", foreground="#CC0000")
        self.textarea.tag_config("infostring", foreground="#008800")

        self.addText("Path A: " + os.getcwd() + "\n", ("infostring", ))
        self.addText("(chdir)" + "\n", ("infostring", ))
        os.chdir( dirname(os.path.realpath(__file__)) )
        self.addText("Path B: " + os.getcwd() + "\n\n", ("infostring", ))

        self.addText("Script is: " + " ".join(scriptcall) + "\n\n", ("infostring", ))

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
    root.geometry("650x400+300+300")
    AssetBuilder(root)
    root.mainloop()


if __name__ == '__main__':
    main()

