#!/usr/bin/env python
# dev on python2.7

"""
Copyleft sdaau, 2013

youtube-dl GUI with tkInter/tkDND
based on
http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/tkGui_ShellScriptRunner.py

2013-01-22

init release:
* attempts to download tkDND and youtube-dl (linux) itself
* handles drag & drop from text selections like address bar in browser
* as soon as download starts, starts up a player on the current file

"""

import os
import signal
#import urllib2
import urllib  # has urlretrieve
import sys
import tarfile
import stat # to chmod
import subprocess
import threading
import time
from os.path import join, dirname
from datetime import datetime
import string
valid_chars = "-_.()%s%s" % (string.ascii_letters, string.digits)
import random

global scriptdir, calldir

scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()
print ("scriptdir %s calldir %s" % (scriptdir,calldir))


dndtarname = "tkdnd2.6-linux-ix86.tar.gz"
#~ dndtarname = "tkdnd2.6-linux-x86_64.tar.gz"
dndtarlink = "http://downloads.sourceforge.net/project/tkdnd/Linux%20Binaries/TkDND%202.6/" + dndtarname + "?use_mirror=autoselect"
dnddirname = "tkdnd2.6"

os.environ['TKDND_LIBRARY'] = scriptdir + os.sep + dnddirname
print ("" + os.environ['TKDND_LIBRARY'])

import Tkinter
from untested_tkdnd_wrapper import TkDND
from Tkinter import Tk, Text, BOTH, W, N, E, S, END, INSERT, HORIZONTAL, VERTICAL, NONE,\
    StringVar
# from ttk import Frame, Button, Style, Scrollbar, Checkbutton # with ttk
from Tkinter import Frame, Button, Scrollbar, Checkbutton # without ttk
import tkFileDialog

ydlname = "youtube-dl"
ydllink = "http://youtube-dl.org/downloads/2013.01.13/" + ydlname

# Available formats example (via youtube-dl -F/--list-formats ...):
# 22	:	mp4	[720x1280]
# 45	:	webm	[720x1280]
# 35	:	flv	[480x854]
# 44	:	webm	[480x854]
# 34	:	flv	[360x640]
# 18	:	mp4	[360x640]
# 43	:	webm	[360x640]
# 5	:	flv	[240x400]
# 17	:	mp4	[144x176]
# prefer 360p
# master variable template (script needs to change 4th and last entry)
scriptcall = [scriptdir + os.sep + ydlname,
  '--output',
  scriptdir + os.sep + "%(autonumber)s-%(title)s-%(id)s.%(ext)s", # no need for single quotes here
  #'--title', #conflicts with output
  #'--auto-number', #conflicts with output
  '--restrict-filenames',
  '--no-part',
  '--verbose',
  '--rate-limit', '100k',
  '--max-quality', '34',
  'myURL']

playerexe = 'vlc'
# --started-from-file allows one-instance-when-started-from-file
# (~/.config/vlc/vlcrc); so subsequent calls do not open new
# vlc windows - but instead enqueue in the playlist
playcommand = [playerexe, '--started-from-file', '--playlist-enqueue', "savedir+lfname"];
runplayerdelay = 500 # ms

worker = None



# http://stackoverflow.com/questions/8259769/extract-all-files-with-directory-path-in-given-directory
# http://stackoverflow.com/questions/3667865/python-tarfile-progress-output?rq=1
def on_progress(filename, position, total_size):
  if (position == total_size):
    print ("%s: %d of %s" %(filename, position, total_size))

class MyFileObject(tarfile.ExFileObject):
  def read(self, size, *args):
    on_progress(self.name, self.position, self.size)
    return tarfile.ExFileObject.read(self, size, *args)

tarfile.TarFile.fileobject = MyFileObject


############# MAIN

root = Tkinter.Tk()
global dnd

localfiles = []

# http://stackoverflow.com/questions/14267900/python-drag-and-drop-explorer-files-to-tkinter-entry-widget
# check if tkDND is present - else auto-install it in this folder
try:
  dnd = TkDND(root) # this performs actual load of library
  print ("-->", root.tk.eval('package require tkdnd'))
except Tkinter.TclError as e:
  print ("got _tkinter.TclError: {0}".format(str(e)))
  if (os.path.exists(dnddirname)):
    print ("Path " + dnddirname + " exists here, but still got an error")
    print ("Please delete it to allow process to continue")
    os._exit(1)
  print ("Trying to download " + dndtarname)
  response = urllib.urlretrieve (dndtarlink, dndtarname)
  print ("Done; download response " + str(response))
  if (response[0] == dndtarname): #
    print ("Download of " + dndtarname + " successful; unpacking...")
    # unpack
    tar = tarfile.open(dndtarname)
    tar.extractall(path=".", members=None)
    tar.close()
    print ("Done unpacking - testing tkdnd again:")
    try:
      dnd = TkDND(root) # this performs actual load of library
      print ("-->", root.tk.eval('package require tkdnd'))
    except Tkinter.TclError as e:
      print ("got again _tkinter.TclError: {0}".format(str(e)))
      print ("Not sure what the problem is - exiting.")
      os._exit(1)
    else:
      print ("All seems fine with tkdnd; continuing")


# check for presence of youtube-dl; else download it
# now youtube-dl is a binary (but it is a zip file;
# and can be unzipped - see https://github.com/rg3/youtube-dl/pull/342
#~ chmod a+x

if (os.path.isfile(ydlname)):
  print ("Found " + ydlname)
else:
  print ("Trying to download " + ydlname)
  response = urllib.urlretrieve (ydllink, ydlname)
  print ("Done; download response " + str(response))
  if (response[0] == ydlname):
    print ("Download seems ok, continuing.")
    st = os.stat(ydlname)
    os.chmod(ydlname, st.st_mode | stat.S_IEXEC | stat.S_IRWXG | stat.S_IRWXO)



# continue with rest of tkinter

# note; if we have a class member:
# AssetBuilder.URLentry = = Tkinter.Entry(self)
# then its ref (via print) is .3065617612L.3065617900L
# if we just have URLentry = = Tkinter.Entry() on root,
# then its ref (via print) is .3074585164L
# it seems tkDND cannot handle these class refs,
# so the URLentry cannot be a member of AssetBuilder class -
# it will be placed on root
global URLentry

class AssetBuilder(Frame):

    def __init__(self, parent):
      Frame.__init__(self, parent)

      self.parent = parent
      self.isRunning = False

      self.initUI()

    def initUI(self):
      global scriptdir, calldir
      global dnd
      global URLentry
      global savedirentry

      troot = self.parent # self.parent.master # was self.parent; # now parent is child of root
      troot.title("youtube-dl Tkinter/TkDND GUI")
      #~ self.pack(fill=BOTH, expand=1)

      # just a reference here:
      self.URLentry = URLentry
      self.savedirentry = savedirentry
      self.lfname=""
      self.outdir=scriptdir
      savedirentry.delete(0, END)
      savedirentry.insert(0, self.outdir)


      #create a grid 5x4 in to which we will place elements.
      self.columnconfigure(1, weight=0)
      self.columnconfigure(2, weight=1)
      self.columnconfigure(3, weight=0)
      self.columnconfigure(4, weight=0)
      self.columnconfigure(5, weight=0)
      self.rowconfigure(1, weight=0)
      self.rowconfigure(2, weight=1)
      self.rowconfigure(3, weight=0)

      #create the main text are with scrollbars
      xscrollbar = Scrollbar(self, orient=HORIZONTAL)
      xscrollbar.grid(row=3, column=1, columnspan=4, sticky=E + W)

      yscrollbar = Scrollbar(self, orient=VERTICAL)
      yscrollbar.grid(row=2, column=5, sticky=N + S)

      self.textarea = Text(self, wrap=NONE, bd=0,
                           xscrollcommand=xscrollbar.set,
                           yscrollcommand=yscrollbar.set)
      self.textarea.grid(row=2, column=1, columnspan=4, rowspan=1,
                          padx=0, sticky=E + W + S + N)

      xscrollbar.config(command=self.textarea.xview)
      yscrollbar.config(command=self.textarea.yview)

      #create the buttons/checkboxes to go along the bottom
      self.clearButton = Button(self, text="Clear")
      self.clearButton.grid(row=1, column=1, padx=5, pady=5, sticky=W)
      self.clearButton.bind("<ButtonRelease-1>", self.clearText)

      self.delButton = Button(self, text="Del.Files")
      self.delButton.grid(row=1, column=2, padx=5, pady=5, sticky=W)
      self.delButton.bind("<ButtonRelease-1>", self.deleteFiles)


      self.runbutton = Button(self, text="Run/Call")
      self.runbutton.grid(row=1, column=3, padx=5, pady=5)
      self.runbutton.bind("<ButtonRelease-1>", self.runScript)

      self.stopbutton = Button(self, text="Stop")
      self.stopbutton.grid(row=1, column=4, padx=5, pady=5)
      self.stopbutton.bind("<ButtonRelease-1>", self.stopScript)

      #tags are used to colorise the text added to the text widget.
      # see self.addTtext and self.tagsForLine
      self.textarea.tag_config("errorstring", foreground="#CC0000")
      self.textarea.tag_config("infostring", foreground="#008800")

      self.addText("Path A: " + calldir + "\n", ("infostring", ))
      self.addText("(chdir)" + "\n", ("infostring", ))
      os.chdir( scriptdir )
      self.addText("Path B: " + os.getcwd() + "\n\n", ("infostring", ))

      self.addText("DL command is: " + " ".join(scriptcall) + "\n", ("infostring", ))
      self.addText("Player command is: " + " ".join(playcommand) + "\n\n", ("infostring", ))

    def handleURLentry(self, event):
      # to replace text - delete first
      istr = event.data.strip()
      #~ ''.join(c for c in filename if c in valid_chars) # no need
      event.widget.delete(0, END)
      event.widget.insert(0, istr)
    def handlesavedirentry(self, event):
      istr = event.data.strip()
      # to replace text - delete first
      event.widget.delete(0, END)
      event.widget.insert(0, istr)

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

    def runPlayer(self):
      # with subprocess.PIPE so it doesn't lock the rest
      self.addText(" ".join(playcommand) + "\n", ("infostring", ))
      subprocess.Popen(playcommand, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
      localfiles.append(self.lfname) # push
      self.addText("Local files: " + str(localfiles) + "\n", ("infostring", ))

    def deleteFiles(self, event):
      for i in reversed(range(len(localfiles))):
        file = localfiles.pop(i)
        try:
          os.remove(file)
        except OSError as e:
          self.addText("Error removing: " +file+ "; " + e + "\n", ("infostring", ))
        else:
          self.addText("Removed: " +file+ "\n", ("infostring", ))

    def runScriptThread(self, event):
      """callback from the run/call button"""
      myURL = self.URLentry.get()
      self.outdir = self.savedirentry.get()
      self.moveCursorToEnd()
      if not myURL:
        self.addText("URL is empty, can't do anything.\n", ("infostring", ))
        self.isRunning = False
        return
      if not(self.outdir and os.path.exists(self.outdir) and os.path.isdir(self.outdir)):
        self.addText("Invalid save directory, can't do anything.\n", ("infostring", ))
        self.isRunning = False
        return
      self.addText("Starting run %s\n" % (str(datetime.now())), ("infostring", ))

      scriptcall[-1] = myURL # myURL is last, anyways
      # then a bit nastier - must consider exact third field to set outdir, and concat too; careful if changing scriptcall args
      scriptcall[2] = self.outdir + os.sep + "%(autonumber)s-%(title)s-%(id)s.%(ext)s" # don't put this in single quotes!
      cmdlist = scriptcall

      self.addText(" ".join(cmdlist) + "\n", ("infostring", ))

      self.proc = subprocess.Popen(cmdlist,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               universal_newlines=True,
                               preexec_fn=os.setsid)

      while True:
        line = self.proc.stdout.readline()
        # if match [download] Destination
        if "[download] Destination" in line:
          tda = line.split(": ")
          self.lfname = tda[1].rstrip()
          playcommand[-1] = self.lfname # [playerexe, lfname]; # now lfname contains the self.outdir + os.sep +

          # yet another call - to player to start playing
          # tkInter has after to run scheduled function after delay
          self.parent.after(runplayerdelay, self.runPlayer)# parent is root

        if not line:
            break
        self.addText(line)
        #this triggers an update of the text area, otherwise it doesn't update
        self.textarea.update_idletasks()

      self.isRunning = False
      retcode = self.proc.wait() # should return self.proc.returncode
      self.addText("Script Finished (%s) %s\n" % (str(retcode), str(datetime.now())), ("infostring", ))
      self.addText("*" * 80 + "\n", ("infostring", ))
      if not((retcode == 0) or (retcode == -15)): # -15 is when it is interrupted by user
        self.addText("* Command did not complete succesfully\n", ("infostring", ))
        randwait = random.randint(10, 20)
        self.addText("* Waiting at random %d seconds, and\n" % (randwait), ("infostring", ))
        time.sleep(randwait)
        self.addText("* Restarting command\n", ("infostring", ))
        #self.isRunning = True
        #self.worker = threading.Thread(
        #  target=self.runScriptThread,
        #  args=(event,))
        #self.worker.start()
        # seems Timer needs float (ignored int) as delay argument?!
        t = threading.Timer(1.0, self.runScript(event=None))
        t.start()

    def stopScript(self, event):
      """callback from the stop button"""
      os.killpg(self.proc.pid, signal.SIGTERM)
      self.proc.terminate()
      self.proc.kill()
      print self.worker.isAlive() # True here. still



def chooseSaveDir(event):
  global asob
  global savedirentry
  global scriptdir
  tdirname = tkFileDialog.askdirectory(parent=root,initialdir=scriptdir,title='Please select a directory')
  if len(tdirname) > 0:
    # print "You chose %s" % dirname
    savedirentry.delete(0, END)
    savedirentry.insert(0, tdirname)




def main():
  global URLentry
  global savedirentry
  global asob
  # root = Tk() # already done previously
  root.geometry("650x450+300+300")

  # it seems TkDND cannot bind members of classes (see below);
  # so URLentry must be here
  # must add a frame so label+entry are on top? Nope,
  # even it as parent messes things up
  #~ mframe = Tkinter.Frame(master=root, borderwidth=5, bg = 'cyan')
  #~ # mframe.grid(fill=BOTH) #nope:
  #~ mframe.pack(fill=BOTH, expand=1)

  #~ mframe.columnconfigure(1, weight=0)
  #~ mframe.columnconfigure(2, weight=1)
  #~ mframe.rowconfigure(1, weight=0)
  #~ mframe.rowconfigure(2, weight=1)

  root.columnconfigure(1, weight=0)
  root.columnconfigure(2, weight=1)
  root.rowconfigure(1, weight=0)
  root.rowconfigure(2, weight=0)
  root.rowconfigure(3, weight=1)

  # label
  showLabel = Tkinter.Label( text = "URL: ") # master=root
  showLabel.grid(row=1, column=1, sticky=W)

  # text entry for URL
  # actually, even if the entry just has mframe as master,
  # then it still has ref .155766380.155791436 and
  # fails TkDND binding;
  # only when master=root does it work
  URLentry = Tkinter.Entry() # master=root
  #print "URLentry ref: ", URLentry #
  URLentry.grid(row=1, column=2, columnspan=1, sticky=E + W, padx=5)
  #~ URLentry.pack(fill=BOTH, expand=1)

  # button:
  savedirButton = Button( text="savedir")
  savedirButton.grid(row=2, column=1, padx=5, pady=0, sticky=W)

  # text entry for save (output) directory
  savedirentry = Tkinter.Entry() # master=root
  savedirentry.grid(row=2, column=2, columnspan=1, sticky=E + W, padx=5)

  # now the rest (will refer to URLentry inside)
  asob = AssetBuilder(root)
  asob.grid(row=3, column=1, columnspan=2, sticky= W + S + E)

  # note, binding to a function which is a class member is not a problem
  # note, text/plain also picks up filedrops like text/uri-list!

  dnd.bindtarget(URLentry, asob.handleURLentry, 'text/plain;charset=UTF-8') # this reacts on text selection drops from applications (but also file/dir icon drops); 'text/plain;charset=UTF-8'
  print dnd.bindtarget_query(URLentry)
  dnd.bindtarget(savedirentry, asob.handlesavedirentry, 'text/plain;charset=UTF-8')
  # print "-", dnd.bindtarget(savedirentry, asob.handlesavedirentry, 'text/uri-list'), "-" # only file/dir icon drops (no text sel)
  print dnd.bindtarget_query(savedirentry)

  savedirButton.bind("<ButtonRelease-1>", chooseSaveDir)

  # context menu (right-click)
  asob.make_menu(root)
  # binds class - so entries are covered with this
  URLentry.bind_class("Entry", "<Button-3><ButtonRelease-3>", asob.show_menu)
  # binds element
  asob.textarea.bind("<Button-3><ButtonRelease-3>", asob.show_menu)


  root.mainloop()


if __name__ == '__main__':
  main()



"""
entry = Tkinter.Entry()
entry.pack()

def handle(event):
  event.widget.insert(0, event.data)

dnd.bindtarget(entry, handle, 'text/uri-list') # this reacts on files being dropped, extracts their path
dnd.bindtarget(entry, handle, 'text/plain;charset=UTF-8') # this reacts on text selection drops from applications

root.mainloop()
"""
