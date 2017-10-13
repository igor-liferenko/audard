#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes even on Unicode in comments

"""
# Copyleft 2014, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

MYNAME="visRegexTester"

#### README:
"""
visRegexTester is a small Python/Tkinter GUI application to assist
with writing of regular expressions; tested with Python 2.7 and
3.2. In fact, it is merely an interface for other command line
programs: it exploits the fact that a lot of Unix/GNU/Linux
programs used as regex processors in the terminal (e.g. `grep`,
`sed`, `perl`), have a similar command-line syntax in three parts:

  (PROGRAM --ARGS) ('REGEX') (FILENAME)

Upon start, there are four labeled sections in the GUI: "prog" and
"regex" dropdowns/comboboxes, and "inp" and "out" text area fields.
"prog", "regex" and "inp" correspond to the three parts above,
"out" shows the output of the command. When you press the "Rerun!"
button, the command specified by "prog", "regex" and "inp" is
executed, and the results are shown in the "out" text field.

You can Shift+Left mouse click the "prog" and "regex" dropdowns -
then they become editable. If the "Auto rerun?" checkbox is
checked, then upon typing in the "regex", the "Rerun" procedure
executes each time the text content of the "regex" field changes.
Otherwise, in both of these fields, while they're edited, you can:

* press Return/Enter to "save" the modified contents as the new
entry at end of the dropdown list
* press Escape to "cancel" the modification of contents, and go
back to the last saved state of the field.

The Rerun procedure will refresh the output also when the dropdowns
are set to another choice. The command line used in Rerun, will be
shown both in the "out" text area as the first line - and will be
printed to stdout of the terminal.

If there are keypresses in the "inp" text area field, they will be
counted as if they have changed the content - and thus, the "Save
Input" button will be activated. If you copy-paste, it's best you
first select the old contents in the "inp" text area field, press
Delete to delete them, and then paste - to make sure the "Save
Input" button will be enabled after this operation. Upon clicking
the "Save Input" button, the contents of the "inp" text area are
saved in a file called `tmpvisRegexTester_Input.txt` in the
system's temporary directory; the path of this file is used as the
(FILENAME) argument for the command lines.

Finally, the system tries to intercept ANSI color escape codes -
specifically those for red text, as used by `grep --color=always`:

* `echo -e '\033[01;31m\033[K` to start coloring
* `echo -e '\033[m\033[K`      to end coloring

The program starts with three entries (for `grep`, `sed` and
`perl`) in the "prog" dropdown - and three corresponding regex
entries in the "regex" field; the output of `grep` is automatically
colorized (due to its `--color=always` argument) - while the ANSI
escape codes are written into the search/replace regexes for the
`sed` and `perl` cases (however, that is done directly from Python,
and thus the escaped characters are munged when shown in the
"regex" dropdown text).

A dropdown field "infil" now exists, which specifies an input
file, other than the temporary one, which will be used in the
command. This dropdown can be edited the same way (Shift+click)
as the "prog" and "regex" dropdowns/comboboxes. At the moment,
the "Save Input" button will only work if this dropdown is set to
the default temporary file.

BUGS:
* There were some problems with Unicode/utf-8 across Python2.7/3.2;
  they seem fixed now - but be wary!
* Occasionally selection in dropdown boxes doesn't trigger a
  refresh;     (seems fixed after focus/selection_clear edits)
* Shift+click (esp. in Python3.2) may fail to start editing the
  dropdown box (seems fixed after focus/selection_clear edits)
* GUI elements for choosing text input file are added, but there is
  no code for them yet, so they are disabled

"""


import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

if sys.version_info[0] < 3:
  tkmstr = "Tkinter"
  import Tkinter as tk
  import tkMessageBox as tkMsgBox
  import ttk
  #import Tix as tix
  def b(x):
    return x
  def uttb(x):
    return x.encode("utf-8")
  def utdd(x): # for _gk_update (matplotlib 0.99 UTF-8)
    return x.decode("utf-8")
else:
  tkmstr = "tkinter"
  import tkinter as tk
  import tkinter.messagebox as tkMsgBox
  from tkinter import ttk as ttk
  #import tkinter.tix as tix
  def b(x):
    return bytes(x, 'UTF-8')
  def uttb(x):
    return bytes(x, 'UTF-8')
  def utdd(x): # if x is str
    return x

# same for both Python 2.7, 3.2
import subprocess
import tempfile
tmpfpath = os.path.join(tempfile.gettempdir(), 'tmp' + MYNAME + '_Input.txt')
import shlex # for correct tokenization
import re

DEFAULT_TEXT_INP = """Just some tæxt here. Спутtник おたく/オタク values: 10 kΩ, 10 µF...
Just something here, just some text.
Just text here, some-text.
Some text here, some-thing.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer eu leo leo. Donec felis urna, rhoncus nec ullamcorper bibendum, dapibus ac urna.
Etiam ut mauris non tellus tristique dictum in ac est. Phasellus feugiat maximus nulla. Donec varius tortor nec orci posuere porttitor.
Suspendisse rhoncus condimentum bibendum. Cras euismod blandit massa, at ullamcorper ligula malesuada sit amet. Sed sit amet metus arcu.
Aenean quis luctus tellus.
Aliquam ac sem enim.
"""

# whitespace.ttf
# https://bugzilla-attachments-4619.netbeans.org/bugzilla/attachment.cgi?id=97902

# http://stackoverflow.com/questions/16369470/tkinter-adding-line-number-to-text-widget
class TextLineNumbers(tk.Canvas):
  def __init__(self, *args, **kwargs):
    tk.Canvas.__init__(self, *args, **kwargs)
    self.textwidget = None
  def attach(self, text_widget):
    self.textwidget = text_widget
  def redraw(self, *args):
    '''redraw line numbers'''
    self.delete("all")
    i = self.textwidget.index("@0,0")
    while True :
      dline= self.textwidget.dlineinfo(i)
      if dline is None: break
      y = dline[1]
      linenum = str(i).split(".")[0]
      self.create_text(2,y,anchor="nw", text=linenum)
      i = self.textwidget.index("%s+1line" % i)
class CustomText(tk.Text):
  def __init__(self, *args, **kwargs):
    tk.Text.__init__(self, *args, **kwargs)
    self.tk.eval('''
      proc widget_proxy {widget widget_command args} {

        # call the real tk widget command with the real args
        set result [uplevel [linsert $args 0 $widget_command]]

        # generate the event for certain types of commands
        if {([lindex $args 0] in {insert replace delete}) ||
          ([lrange $args 0 2] == {mark set insert}) ||
          ([lrange $args 0 1] == {xview moveto}) ||
          ([lrange $args 0 1] == {xview scroll}) ||
          ([lrange $args 0 1] == {yview moveto}) ||
          ([lrange $args 0 1] == {yview scroll})} {

          event generate  $widget <<Change>> -when tail
        }

        # return the result from the real widget command
        return $result
      }
      ''')
    self.tk.eval('''
      rename {widget} _{widget}
      interp alias {{}} ::{widget} {{}} widget_proxy {widget} _{widget}
    '''.format(widget=str(self)))

# http://stackoverflow.com/questions/3221956/what-is-the-simplest-way-to-make-tooltips-in-tkinter
# http://svn.python.org/view/python/trunk/Demo/tix/samples/Balloon.py?revision=78779&view=markup
# Tix - tkinter sub-library, has tooltips, installed w/ Python 2.7, 3.2;
# (in natty, python3-tk doesn't include it, the `tix` package on natty is specifically for Python3? but it has only the tcl interface, not Python; actually both are there without need to install `tix` specially; just be careful about 2/3 imports; however will get _tkinter.TclError: can't find package Tix if it is not installed once it bumps into root = Tix.Tk()! )
# so going with standalone class
# http://www.voidspace.org.uk/python/weblog/arch_d7_2006_07_01.shtml
class ToolTip(object):
  def __init__(self, widget):
    self.widget = widget
    self.tipwindow = None
    self.id = None
    self.x = self.y = 0
  def showtip(self, text):
    "Display text in tooltip window"
    self.text = text
    if self.tipwindow or not self.text:
      return
    x, y, cx, cy = self.widget.bbox("insert")
    x = x + self.widget.winfo_rootx() + 27
    y = y + cy + self.widget.winfo_rooty() +27
    self.tipwindow = tw = tk.Toplevel(self.widget)
    tw.wm_overrideredirect(1)
    tw.wm_geometry("+%d+%d" % (x, y))
    try:
      # For Mac OS
      tw.tk.call("::tk::unsupported::MacWindowStyle",
             "style", tw._w,
             "help", "noActivates")
    except tk.TclError:
      pass
    # using tk.Message instead of tk.Label because it breaks text automatically if
    # it has width set - else this is just single line;
    # note: here width is in pixels - for Label, it is in characters!
    label = tk.Message(tw, text=self.text, justify=tk.LEFT,
            background="#ffffe0", relief=tk.SOLID, borderwidth=1,
            font=("tahoma", "8", "normal"), width=200)
    label.pack(ipadx=1)
  def hidetip(self):
    tw = self.tipwindow
    self.tipwindow = None
    if tw:
      tw.destroy()


# main GUI class:
class GuiContainer:
  def __init__(self):
    self.root = None
    self.frame = None
  def initBuildWindow(self):
    self.root = tk.Tk()
    self.root.bind("<KeyPress>", self.masterKeyPress)
    self.root.option_add('*Dialog.msg.font', 'Helvetica 11') # font size messagebox
    self.root.geometry("650x450+50+50")
    self.root.title("{0} GUI".format(sys.argv[0]))
    self.s = ttk.Style()
    # http://stackoverflow.com/questions/5235998/tkinter-combobox-selection-highlighting-python-3
    # http://stackoverflow.com/questions/18610519/ttk-combobox-glitch-when-state-is-read-only-and-out-of-focus
    # instead of .selection_clear() - map; but it doesn't really work as such, because after selection, the widget is still in focus (and these are for !focus)
    # actually, .selection_clear() turned out to work...
    #self.s.map("TCombobox",
    #  selectbackground=[
    #      ('!readonly', '!focus', 'SystemWindow'),
    #      ('readonly', '!focus', 'SystemButtonFace'),
    #      ],
    #  fg=[
    #      ('!readonly', '!focus', 'SystemWindow'),
    #      ('readonly', '!focus', 'SystemButtonText'),
    #      ],
    #)
    self.frame = tk.Frame(self.root, name="mframe")
    self.frame.pack(fill=tk.BOTH, expand=1)
    #create a (master) grid 7x3 in to which we will place elements.
    self.frame.columnconfigure(1, weight=0)
    self.frame.columnconfigure(2, weight=1)
    self.frame.columnconfigure(3, weight=0)
    self.frame.rowconfigure(1, weight=0)
    self.frame.rowconfigure(2, weight=0)
    self.frame.rowconfigure(3, weight=0)
    self.frame.rowconfigure(4, weight=0)
    self.frame.rowconfigure(5, weight=1)
    self.frame.rowconfigure(6, weight=0)
    self.frame.rowconfigure(7, weight=1)
    self.frame.rowconfigure(8, weight=0)
    # start elements
    #self.labelM11 = tk.Label(self.frame, text="TT")
    #self.labelM11.grid(row=1, column=1, columnspan=1, sticky=tk.E)
    self.frameButtons = tk.Frame(self.frame)
    self.frameButtons.grid(row=1, column=2, columnspan=1, sticky=tk.E + tk.W)
    self.frameButtons.columnconfigure(4, weight=1) # last column stretches
    self.autorerun = tk.IntVar()
    self.autorerun.set(1) # default: on
    self.autoCButton = tk.Checkbutton(self.frameButtons, text="Auto rerun?", variable=self.autorerun, onvalue = 1, offvalue = 0)#, indicatoron=0) # indicatoron controls if checkbox is shown
    #self.autoCButton.var = self.autorerun
    self.autoCButton.grid(row=1, column=1, sticky=tk.E + tk.N + tk.S)
    self.rerunButton = tk.Button(self.frameButtons, text="Rerun!") #
    self.rerunButton.grid(row=1, column=2, sticky=tk.E)
    self.rerunButton.bind("<Button-1>", self._on_clk_rerun)
    self.saveInpButton = tk.Button(self.frameButtons, text="Save Input", state="disabled") #
    self.saveInpButton.grid(row=1, column=3, sticky=tk.E)
    self.saveInpButton.bind("<Button-1>", self._on_clk_saveinp)
    #
    self.labelM21 = tk.Label(self.frame, text="prog")
    self.labelM21.grid(row=2, column=1, columnspan=1, sticky=tk.E)
    self.labelM31 = tk.Label(self.frame, text="regex")
    self.labelM31.grid(row=3, column=1, columnspan=1, sticky=tk.E)
    self.labelM41 = tk.Label(self.frame, text="infil")
    self.labelM41.grid(row=4, column=1, columnspan=1, sticky=tk.E)
    self.labelM51 = tk.Label(self.frame, text="inp")
    self.labelM51.grid(row=5, column=1, columnspan=1, sticky=tk.E + tk.N)
    self.labelM71 = tk.Label(self.frame, text="out")
    self.labelM71.grid(row=7, column=1, columnspan=1, sticky=tk.E + tk.N)
    #
    self.ST = r"\x1b[01;31m\x1b[K"
    self.ED = r"\x1b[m\x1b[K"
    self.STP = r'\033[31m' # not sure why STP/EDP are needed for python?
    self.EDP = r'\033[0m'
    self.OPTIONS_PROG = [
        "grep --color=always",
        "sed -n",
        "perl -lne",
        "python -c"
    ]
    self.OPTIONS_REGX = [
        "'some[ ]*t'",
        r"""'s/\\(.*\\)\\(some.*t\\)\\(.*\\)/\\1"""+self.ST+r"""\\2"""+self.ED+r"""\\3/gp'""", # only like this r""" can escape with \\ ?! have to keep inner quote ' anyway...
        r"""'print if s/(.*)(some.*t)(.*)/$1"""+self.ST+r"""$2"""+self.ED+r"""$3/g'""",
      # aah - for python, don't use r"" for the replace regex, use just "", to have correct color chars - but then have to escape \\1, \\2, \\3 inside! STP/EDP are not really needed (mess up the search later)
        r"""'import sys,re; rgx=r"(.*)(some.*t)(.*)";  [sys.stdout.write(re.sub(rgx, "\\1"""+self.ST+r"""\\2"""+self.ED+r"""\\3", line) if re.match(rgx, line) else "") for line in open(sys.argv[1],"rb")]'""",
    ]
    self.OPTIONS_INFL = [
        tmpfpath,
    ]
    self.TEXT_INP = DEFAULT_TEXT_INP
    # nb: for master=self; here it complains "AttributeError: GuiContainer instance has no attribute 'tk'"
    self.dd_prog_var = tk.StringVar(master=self.root)
    self.dd_prog_var.set(self.OPTIONS_PROG[0]) # default value
    #~ self.dd_prog = tk.OptionMenu(self.frame, self.dd_prog_var, *self.OPTIONS_PROG)
    self.dd_prog_var.trace('w',self._on_field_change_dd_prog)
    self.dd_prog = ttk.Combobox(self.frame, state="readonly",textvariable= self.dd_prog_var, values=self.OPTIONS_PROG)
    self.dd_prog.grid(row=2, column=2, columnspan=2, sticky=tk.E + tk.W)
    self.dd_prog.oldval=self.dd_prog_var.get() # initialize add-on var here
    self.dd_prog.prevval="-1"
    self.dd_prog.bind("<Button-1>", self._on_clk_dd_prog) # <Double-Button-1> doesn't react here
    self.dd_prog.bind("<<ComboboxSelected>>", self.defocusAll)
    self.dd_regx_var = tk.StringVar(master=self.root)
    self.dd_regx_var.set(self.OPTIONS_REGX[0]) # default value
    #~ self.dd_regx = tk.OptionMenu(self.frame, self.dd_regx_var, *self.OPTIONS_REGX)
    self.dd_regx_var.trace('w',self._on_field_change_dd_regx)
    self.dd_regx = ttk.Combobox(self.frame, state="readonly",textvariable= self.dd_regx_var, values=self.OPTIONS_REGX)
    self.dd_regx.grid(row=3, column=2, columnspan=2, sticky=tk.E + tk.W)
    self.dd_regx.oldval=self.dd_regx_var.get()
    self.dd_regx.prevval="-1"
    self.dd_regx.bind("<Button-1>", self._on_clk_dd_regx)
    self.dd_regx.bind("<<ComboboxSelected>>", self.defocusAll)
    self.frameInfl = tk.Frame(self.frame)
    self.frameInfl.grid(row=4, column=2, columnspan=2, sticky=tk.E + tk.W)
    self.frameInfl.columnconfigure(1, weight=1) # first column stretches!
    self.frameInfl.columnconfigure(2, weight=0)
    self.dd_infl_var = tk.StringVar(master=self.root)
    self.dd_infl_var.set(self.OPTIONS_INFL[0]) # default value
    self.dd_infl_var.trace('w',self._on_field_change_dd_infl)
    self.dd_infl = ttk.Combobox(self.frameInfl, state="readonly",textvariable= self.dd_infl_var, values=self.OPTIONS_INFL)
    self.dd_infl.grid(row=1, column=1, columnspan=1, sticky=tk.E + tk.W)
    self.dd_infl.oldval=self.dd_infl_var.get()
    self.dd_infl.prevval="-1"
    self.dd_infl.bind("<Button-1>", self._on_clk_dd_infl)
    self.dd_infl.bind("<<ComboboxSelected>>", self.defocusAll)
    #self.dd_infl.config(state="disabled")
    self.freezeinp = tk.IntVar()
    self.freezeinp.set(1) # default: on
    self.freezeCButton = tk.Checkbutton(self.frameInfl, text="Freeze?", variable=self.freezeinp, onvalue = 1, offvalue = 0)#, indicatoron=0) # indicatoron controls if checkbox is shown
    self.freezeCButton.grid(row=1, column=2, sticky=tk.E + tk.N + tk.S)
    self.freezeCButton.config(state="disabled")
    #~
    self.freezeToolTip = ToolTip(self.freezeCButton)
    def freezeEnter(event):
        self.freezeToolTip.showtip("NOT IMPLEMENTED YET: Whether to 'freeze' the inp field - if you're loading large input text files, you may not want to lose CPU cycles on showing that text in the inp(ut) field; so if this checkbox is enabled, then the inp field is disabled, and it will not show the text contents of the input file (just a note on loading path and status)")
    def freezeLeave(event):
        self.freezeToolTip.hidetip()
    self.freezeCButton.bind('<Enter>', freezeEnter)
    self.freezeCButton.bind('<Leave>', freezeLeave)
    #
    self.xscrollbari = tk.Scrollbar(self.frame, orient=tk.HORIZONTAL)
    self.xscrollbari.grid(row=6, column=2, columnspan=1, sticky=tk.E + tk.W)
    self.yscrollbari = tk.Scrollbar(self.frame, orient=tk.VERTICAL)
    self.yscrollbari.grid(row=5, column=3, sticky=tk.N + tk.S)
    #~ self.tainput = tk.Text(self.frame, wrap=tk.NONE, bd=0, height=17,
    self.frameInp = tk.Frame(self.frame)
    self.frameInp.grid(row=5, column=2, columnspan=1, sticky=tk.E + tk.W + tk.S + tk.N)
    #self.frameInp.columnconfigure(2, weight=1) # last column stretches; this is bad with grid, so don't use this and go with pack
    self.tainput = CustomText(self.frameInp, wrap=tk.NONE, bd=0, height=17,
                      undo=True, name="tainput",
                      xscrollcommand=self.xscrollbari.set,
                      yscrollcommand=self.yscrollbari.set
                      )
    # http://stackoverflow.com/questions/26895896/showing-whitespace-nonprintable-characters-in-tkinter-textarea-maybe-via-font # cannot
    self.tainput.config(font="monospace 9")
    self.tainput.tag_config("errorstring", foreground="#CC0000")
    #~ self.tainput.grid(row=4, column=2, columnspan=1, rowspan=1,
    #self.tainput.grid(row=1, column=2, columnspan=1, rowspan=1,
    #                  sticky=tk.E + tk.W + tk.S + tk.N)
    self.linenumsinput = TextLineNumbers(self.frameInp, width=30)
    self.linenumsinput.attach(self.tainput)
    #self.linenumsinput.grid(row=1, column=2, columnspan=1, rowspan=1)
    self.linenumsinput.pack(side="left", fill="y")
    self.tainput.pack(side="right", fill="both", expand=True)
    self.tainput.bind("<<Change>>", self._on_change_tainput)
    self.tainput.bind("<Configure>", self._on_change_tainput)
    self.xscrollbari.config(command=self.tainput.xview)
    self.yscrollbari.config(command=self.tainput.yview)
    self.tainput.insert(tk.INSERT, self.TEXT_INP)
    self.tainput.config(wrap=tk.WORD)
    with open(tmpfpath, 'wb') as f:
      f.write(b(self.TEXT_INP))
    #
    self.xscrollbaro = tk.Scrollbar(self.frame, orient=tk.HORIZONTAL)
    self.xscrollbaro.grid(row=8, column=2, columnspan=1, sticky=tk.E + tk.W)
    self.yscrollbaro = tk.Scrollbar(self.frame, orient=tk.VERTICAL)
    self.yscrollbaro.grid(row=7, column=3, sticky=tk.N + tk.S)
    #~ self.taoutput = tk.Text(self.frame, wrap=tk.NONE, bd=0, height=17,
    self.frameOut = tk.Frame(self.frame)
    self.frameOut.grid(row=7, column=2, columnspan=1, sticky=tk.E + tk.W + tk.S + tk.N)
    self.taoutput = CustomText(self.frameOut, wrap=tk.NONE, bd=0, height=17,
                      undo=True, name="taoutput",
                      xscrollcommand=self.xscrollbaro.set,
                      yscrollcommand=self.yscrollbaro.set)
    #self.taoutput.grid(row=6, column=2, columnspan=1, rowspan=1,
    #                  sticky=tk.E + tk.W + tk.S + tk.N)
    self.linenumsoutput = TextLineNumbers(self.frameOut, width=30)
    self.linenumsoutput.attach(self.taoutput)
    self.linenumsoutput.pack(side="left", fill="y")
    self.taoutput.pack(side="right", fill="both", expand=True)
    self.taoutput.bind("<<Change>>", self._on_change_taoutput)
    self.taoutput.bind("<Configure>", self._on_change_taoutput)
    self.xscrollbaro.config(command=self.tainput.xview)
    self.yscrollbaro.config(command=self.tainput.yview)
    #tags are used to colorise the text added to the text widget.
    # see self.addText and self.tagsForLine
    self.taoutput.config(font="monospace 9")
    self.taoutput.tag_config("errorstring", foreground="#CC0000")
    self.taoutput.tag_config("infostring", foreground="#008800")
    # do reRun once at start, so the output is not empty
    self.doRerun()
  def defocusAll(self, event):
    #import inspect ; print(inspect.getmembers(event))
    # event.widget is the "parent" originator of the event
    # to defocus all, simply focus root? nowork here
    #self.root.after_idle(self.root.focus) # nope
    event.widget.selection_clear() # THIS works here!
    self.root.focus() # now can add this too, just in case
  # NOTE: these react on change of variable - NOT change of combobox
  def _on_field_change_dd_prog(self, index, value, op):
    # op is "w", dd_prog.get() is a string
    # this still reacts if it is being edited, suppress
    # instead of adding a variable to check for edit, check readonly status
    # to get config settings: cget
    #print(str(self.dd_prog.cget('state')), (str(self.dd_prog.cget('state')) == "readonly"))
    if (str(self.dd_prog.cget('state')) == "readonly"):
      #print("combobox updated to -{0}-{1}-{2}-{3}-".format(index, value, op, self.dd_prog.get()))
      self.dd_prog.oldval=self.dd_prog_var.get()
      self.doRerun()
      #self.root.focus() # put focus on root, to remove focus from widget! (nowork here)
      #self.root.after_idle(self.root.focus) # nope
  def _on_field_change_dd_regx(self, index, value, op):
    if (str(self.dd_regx.cget('state')) == "readonly"):
      self.dd_regx.oldval=self.dd_regx_var.get()
      self.doRerun()
  def _on_field_change_dd_infl(self, index, value, op):
    #self.dd_infl.selection_clear() # nowork
    if (str(self.dd_infl.cget('state')) == "readonly"):
      if(self.dd_infl.oldval != self.dd_infl_var.get()):
        self.dd_infl.oldval=self.dd_infl_var.get()
        self.reloadInpText()
        self.doRerun()
  def _on_clk_dd_prog(self, event):
    #import inspect ; print(inspect.getmembers(event))
    #print(event.keysym,event.keysym_num,event.char,event.state)
    # event.state is 1 if SHIFT is pressed;
    # also save old value as add-on dynamic variable here
    # actually, could be 16 = 0b10000 and 17 = 0b10001 if SHIFT is pressed!
    # so try: (event.state & 1) == 1 instead of event.state == 1:
    if (event.state & 1) == 1:
      self.dd_prog.oldval=self.dd_prog_var.get()
      self.dd_prog.config(state="normal")
  def _on_clk_dd_regx(self, event):
    if (event.state & 1) == 1:
      self.dd_regx.oldval=self.dd_regx_var.get()
      self.dd_regx.config(state="normal")
  def _on_clk_dd_infl(self, event):
    if (event.state & 1) == 1:
      self.dd_infl.oldval=self.dd_infl_var.get()
      self.dd_infl.config(state="normal")
      #self.dd_infl.selection_clear() # nowork
  def reloadInpText(self):
    newfilename = self.dd_infl_var.get()
    #~ print("reloadInpText " + newfilename)
    self.tainput.delete(1.0, tk.END)
    try:
      with open(newfilename, 'rb') as f:
        self.tainput.insert(tk.INSERT, f.read()) # read entire file
    except:
      #exc_type, exc_value, exc_traceback = sys.exc_info()
      self.tainput.insert(tk.INSERT, str(sys.exc_info()), ("errorstring", ))
  def _on_clk_rerun(self, event):
    self.doRerun(force=True)
  def tagsForLine(self, line):
    """return a tuple of tags to be applied to the line of text 'line'
       when being added to the text widet"""
    l = line.lower()
    if "error" in l or "traceback" in l:
      return ("errorstring", )
    return ()
  def addOutText(self, str, tags=None):
    """Add a line of text to the textWidget. If tags is None then
    self.tagsForLine will be used to assign tags to the line"""
    self.taoutput.insert(tk.INSERT, str, tags or self.tagsForLine(str))
    self.taoutput.yview(tk.END) # scroll down to end
  def doRerun(self, force=False):
    # this check is enough to prevent reaction on arrow keys etc.
    if (self.dd_regx_var.get() == self.dd_regx.prevval) and (self.dd_prog_var.get() == self.dd_prog.prevval) and (self.dd_infl_var.get() == self.dd_infl.prevval):
      if not(force):
        return # if no change, bail out early
    self.dd_prog.prevval = self.dd_prog_var.get()
    self.dd_regx.prevval = self.dd_regx_var.get()
    self.dd_infl.prevval = self.dd_infl_var.get()
    # clear output completely, first
    self.rerunButton.config(state="disabled")
    self.rerunButton.update()
    self.taoutput.delete("1.0", tk.END)
    cmd = "{0} {1} {2}".format( self.dd_prog_var.get(), self.dd_regx_var.get(), self.dd_infl_var.get())
    self.addOutText(cmd + "\n", ("infostring", ))
    print(cmd)
    # must tokenize cmd into an array correctly: shlex
    cmdargs = shlex.split(cmd)
    #print(cmdargs)
    self.proc = subprocess.Popen(cmdargs,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT,
                             #universal_newlines=True, # converts \n, don't do it
                             preexec_fn=os.setsid)
    lnum = 0
    while True:
      line = utdd(self.proc.stdout.readline().strip())
      if not line:
          break
      # code to find any colored ranges from grep:
      lnum += 1
      foundRanges = []
      matchs = re.search(r"([\x1b]\[01;31m[\x1b]\[K)", line)
      while (matchs):
        starttag = matchs.start(1)
        # after find, truncate (not to mess further calcs):
        line = re.sub(r"([\x1b]\[01;31m[\x1b]\[K)", "", line, count=1)
        matche = re.search(r"(\x1b\[m\x1b\[K)", line)
        endtag = matche.start(1)
        # after find, truncate (not to mess further calcs):
        line = re.sub(r"(\x1b\[m\x1b\[K)", "", line, count=1)
        #print(starttag, endtag, matchs.groups(), matche.groups(), line)
        foundRanges.append( (starttag,endtag) )
        matchs = re.search(r"([\x1b]\[01;31m[\x1b]\[K)", line)
      #print(foundRanges)
      self.addOutText(line+"\n")
      # http://stackoverflow.com/questions/14786507/how-to-change-the-color-of-certain-words-in-the-tkinter-text-widget/14786570#14786570
      tlnum = lnum+1
      numtag = 0
      for irng in foundRanges:
        tgnm = "mch{0}-{1}".format(lnum,numtag)
        self.taoutput.tag_add(tgnm, "{0}.{1}".format(tlnum, irng[0]), "{0}.{1}".format(tlnum, irng[1]))
        self.taoutput.tag_config(tgnm, foreground="red") # background="black",
        numtag += 1
      #this triggers an update of the text area, otherwise it doesn't update
      self.taoutput.update_idletasks()
    self.rerunButton.config(state="normal")
    self.rerunButton.update()
  def _on_clk_saveinp(self, event):
    #print("_on_clk_saveinp " + str(event.widget.cget('state')))
    # for some reason, this fires even if button is disabled,
    # so force early return to make it not react; event.widget == self.saveInpButton
    if(str(event.widget.cget('state')) == "disabled"):
      return
    # save contents:
    with open(tmpfpath, 'wb') as f:
      f.write(uttb(self.tainput.get(1.0, "end-1c"))) # without the last \n
    # disable button
    self.saveInpButton.config(state="disabled")
    # put focus on root window:
    self.root.focus()
    # good to have feedback instantly:
    self.doRerun(force=True)
  def _on_change_tainput(self, event):
    #print(event.type)
    #print("'{0}', '{1}', '{2}', '{3}'".format(event.keysym,event.keysym_num,event.char,event.state).replace('\n', ' ').replace('\r', ''))
    # this handler reacts on both keypresses and scrolling; handle the save input button in the master key handler
    self.linenumsinput.redraw()
  def _on_change_taoutput(self, event):
    self.linenumsoutput.redraw()
  def masterKeyPress(self, event):
    #print("'{0}', '{1}', '{2}', '{3}'".format(event.keysym,event.keysym_num,event.char,event.state).replace('\n', ' ').replace('\r', ''))
    #print(event.widget, event.widget == self.dd_prog, event.widget == self.dd_regx) # all OK, event.widget seems to be the "parent" - actually, source of event
    # self.autorerun
    if (event.keysym == 'q') and (event.widget == self.root):
          sys.exit(0)
    elif event.keysym == 'Escape':
      # reset edits in combobox/dropdown textfields
      #print(self.dd_prog_var.get()) # here is already changed!
      if (event.widget == self.dd_prog):
        self.dd_prog_var.set(self.dd_prog.oldval)
        self.dd_prog.config(state="readonly")
        self.dd_prog.selection_clear() # works here, but needs escape press; fixed elsewhere for just changing - this is needed if we actually make a selection in edit mode, and then press escape!
        self.root.focus() # not obvious; just in case
      elif (event.widget == self.dd_regx):
        self.dd_regx_var.set(self.dd_regx.oldval)
        self.dd_regx.config(state="readonly")
        self.dd_regx.selection_clear()
        self.root.focus() # not obvious; just in case
      elif (event.widget == self.dd_infl):
        self.dd_infl_var.set(self.dd_infl.oldval)
        self.dd_infl.config(state="readonly")
        self.dd_infl.selection_clear()
      self.root.focus() # focus on root, to let 'q' execute after text field edit
      self.doRerun() # just in case, so restoration is clear
    elif event.keysym == 'Return':
      if (event.widget == self.dd_prog):
        self.OPTIONS_PROG.append(self.dd_prog_var.get())
        self.dd_prog.config(state="readonly", values=self.OPTIONS_PROG)
        self.dd_prog.oldval = self.dd_prog_var.get()
        self.doRerun() # nice to have feedback instantly here
      elif (event.widget == self.dd_regx):
        #self.dd_regx_var.set(re.escape(self.dd_prog_var.get())) # nope, cuts a lot
        # but re.escape in the append, seems to fix it - the edit from the default sed is definitely saved properly (with the colors, too)!!
        # check if any spaces in expression, if so, don't escape?
        # it seems to work for saving the perl expression...
        addexpr = ""
        if re.match(r'.*\s', self.dd_regx_var.get()):
          addexpr = self.dd_regx_var.get();
        else:
          addexpr = re.escape(self.dd_regx_var.get())
        self.OPTIONS_REGX.append(addexpr)
        self.dd_regx.config(state="readonly", values=self.OPTIONS_REGX)
        self.dd_regx.oldval = self.dd_prog_var.get()
        # already have feedback here, as it updated on keypress!
      elif (event.widget == self.dd_infl):
        self.OPTIONS_INFL.append(self.dd_infl_var.get())
        self.dd_infl.config(state="readonly", values=self.OPTIONS_INFL)
        self.dd_infl.oldval = self.dd_infl_var.get()
        self.reloadInpText()
        self.doRerun() # nice to have feedback instantly here
    elif event.widget == self.tainput:
      # text has changed in tainput; allow for save;
      # but (for now) only when the input field is tmpfpath
      if (self.dd_infl_var.get() == tmpfpath):
        self.saveInpButton.config(state="normal")
    elif (self.autorerun.get()) and (event.widget == self.dd_regx):
      #print(event.keysym)
      self.doRerun()

"""
Instantiate the one (and only) global instance object of GuiContainer
"""
guiCO = GuiContainer()


def main():
  global guiCO
  guiCO.initBuildWindow()
  guiCO.root.mainloop()


# ##################### ENTRY POINT   ##########################################

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  main()

