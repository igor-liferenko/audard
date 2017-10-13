from glipper import *
from gettext import gettext as _
import gtk
import glib
import gobject
import itertools

# regex library
import re

# OrderedDict for storing shortcut key combo
from collections import OrderedDict

"""

# filter.py - glipper plugin
# copyleft sdaau, 2013
# started from append.py: (
#  https://bugs.launchpad.net/glipper/+bug/875371
#  http://sdaaubckp.svn.sf.net/viewvc/sdaaubckp/extensions/glipper/append.py
# )

For install instructions, see at end of script.

This glipper plugin is intended for filtering copy/pastes from terminal;
when the plugin is active, upon a Copy action (Ctrl-C/Ctrl-Shift-C)
it will filter the clipboard contents (process them with a regex);
and then put the filtered result in glipper's history list - and in
the default selection (so its ready for pasting).

Multiple regex filters are shown in the submenu entry for
this plugin. They are by default turned off (meaning filtering
is off) when `glipper` starts; their activation is toggled by
clicking on their respective (sub)menu entries. The filters' menu
items are marked with 'T' (true = active) and 'f' (false = not active).
In normal operation, if any filter is active, then the filtering as
a whole is active - and applied whenever `glipper` as a whole
registers a Copy action (like anytime Copy has been performed in a
desktop application).

If you're comfortable with Python, you can edit this file, and
add your own filters - see further on in this file for how the
current filters are implemented.

If any of the keys of the `glipper` shortcut key sequence (default:
<Ctrl><Alt><c>) are being held when the filter submenu items are
clicked, normal toggling is bypassed: instead, an attempt is
made to get the (latest) text selection, filter it with the chosen
filter, and store the result in glipper history (at the
last history location, without adding a new entry) or clipboard
- and this without an explicit "Copy" command.

Choices in the plugin Preferences:
* "Immediately update clipboard with filtered contents":
  - if active, then the filtered contents will be set as
  the clipboard contents, immediately upon a Copy action
  (filtered contents can be pasted immediately after Copy)
  - if inactive, then the filtered contents are stored
  in `glipper`s history list, while the clipboard keeps
  its original contents; so to paste the filtered result,
  one must click on (the latest) `glipper` history item
  first
* "Exclusive choice of regex filters in menu":
  - if active, choosing one filter in the submenu disables
  all the others - making the current choice of filter
  exclusive
  - if inactive, multiple filters can be chosen, such that the
  output of one is "piped" into the next; the order of filtering
  is set by the order of filters shown in the menu (and that
  order is set by)
"""


# the toggle global variable:
# (the default value here controls
# the state at each start of glipper)
is_filtering = False

# from Preferences:
should_update_immediately = True
are_filters_exclusive = True

# (main) menu item
menu_item = gtk.MenuItem(_("Filtering: " + str(is_filtering)))
menu = gtk.Menu()


"""
============================================================
Filter regex related variables and functions;
============================================================

variables are as "global"/"root" variables
(so they don't recalculate)

There should be one function defining the regex actions per filter;
by convention, this function should be prepended with `rxD*_`,
where D* are digits (e.g. rx1_TermCmdLog). By convention, all
related functions and variables should also be prepended with
the same prefix. The function should accept the `item` string, and
return it's filtered version; within the function, then one
can choose if the processing is to happen per line, or on the
entire string as a whole. Finally, register the function with
the manager, to have it show up in the Filtering submenu, from
where it can be toggled.

Below are some helper classes for implementing the filter manager;
FilterManager also keeps a copy of the selection (primary)
clipboard (used when bypassing normal operation), outside of the
handling of `glipper`. This "primfilt" clipboard is then used to
retrieve the selected text, when normal operation is bypassed.
"""

class FilterEntry:
  def __init__(self, function, name='', isactive=False, menuitem=None):
    self.function = function
    self.name = name
    self.isactive = isactive
    self.menuitem = menuitem

class FilterManager:
  def __init__(self):
    self.filters = list()
    glipper.GCONF_USE_PRIMFILT_CLIPBOARD = glipper.GCONF_DIR + "/use_primfilt_clipboard"
    glipper.GCONF_CLIENT.set_bool(glipper.GCONF_USE_PRIMFILT_CLIPBOARD, True)
    self.primary_clipboard = glipper.Clipboard(gtk.clipboard_get("PRIMARY"), self.primfilt_cb, glipper.GCONF_USE_PRIMFILT_CLIPBOARD)
  # callback for GCONF_USE_PRIMFILT_CLIPBOARD
  # note, we cannot have just "pass" here;
  def primfilt_cb(self, data):
    #~ print "primfilt", data
    pass
  # return the text in the primary clipboard (selection)
  # don't forget the return :)
  def getSelectionText(self):
    return self.primary_clipboard.get_text()
  def register(self, function, name='', isactive=False):
    """
    if name is empty - remove "rxD*_" signature from
    function name, and use that as name
    """
    if name=='':
      name = function.func_name
      regexFuncSignature = re.compile('rx\d+_')
      if regexFuncSignature.match(name):
        name = regexFuncSignature.sub("", name)
    """
    create a filter entry object
    and add it to filters array
    """
    tmp_fe = FilterEntry(function, name, isactive)
    self.filters.append(tmp_fe)
    lastindex = len(self.filters)-1
    #print "Registered:", lastindex+1, self.filters[lastindex].name, self.filters[lastindex].isactive, self.filters[lastindex].function
  def getFiltersStatus(self):
    # return a string with status for all filters
    outstr="[ "
    for tmp_fe in self.filters:
      outstr += "%s:%s " % (tmp_fe.name, tmp_fe.isactive)
    outstr+="]"
    return outstr
  def updateFilteringStatus(self):
    # depending on state of individual filters,
    # update the master status variable
    global is_filtering
    is_filtering = False # reset first
    for tmp_fe in self.filters:
      is_filtering = is_filtering or tmp_fe.isactive
    return is_filtering



# main object instance of the filter manager
filterManager = FilterManager()



"""
============================================================
Regex Example: rx1_TermCmdLog (terminal to "command log")
============================================================

Typically, terminal output is like:

username@pcname:dir$ echo AA
AA
username@pcname:dir$ echo -e "AA\nEE"
AA
EE

We'd want to convert that into format suitable for later copypasting of
commands - where prompt is removed, and the shell output is commented:

echo AA
# AA
echo -e "AA\nEE"
# AA
# EE

So the regex would be:

* If the line starts with uninterrupted (by whitespace) character stream,
  that finishes with "$ " (endprompt and space) -
  then delete this start, up to and including the endprompt and space
* else (if not) - then insert a comment character "#" and space at start of line

NB: ('^\S+\$ ') does not match lone prompt "$ " ; but ('^\S*\$ ') does!

The code for that regex filtering follows:
"""

rx1_regexObj_StartPrompt = re.compile('^\S*\$ ')
rx1_startCommentStr = "# "

# the line filter function:
def rx1_doFilterLine(in_linestr):
  global rx1_regexObj_StartPrompt, rx1_startCommentStr
  retstr = 0
  if rx1_regexObj_StartPrompt.match(in_linestr) is not None: # we have a match
    # regex replace the match with empty '' - with .sub()
    retstr = rx1_regexObj_StartPrompt.sub('', in_linestr)
  else: # we do not have a match for start prompt
    retstr = rx1_startCommentStr + in_linestr
  return retstr


def rx1_TermCmdLog(inStr):
  # here transforming each line
  # of the (possibly) multiline
  # input text `item` separately
  ofiltStr = ""
  for iline in inStr.splitlines(True):
    ofiltStr += rx1_doFilterLine(iline)
  return ofiltStr


"""
============================================================
Regex Example: rx2_TermMinPrompt (terminal to "minimal prompt")
============================================================

Typically, terminal output is like:

username@pcname:dir$ echo AA
AA
username@pcname:dir$ echo -e "AA\nEE"
AA
EE

We'd want to convert that into format suitable for pasting to e.g.
a forum - where prompt is minimized to last `$`, and the shell
output is left unchanged:

$ echo AA
AA
$ echo -e "AA\nEE"
AA
EE

So the regex would be:

* If the line starts with uninterrupted (by whitespace) character stream,
  that finishes with "$ " (endprompt and space) -
  then delete this start, keeping the endprompt and space
* else (if not) - then do nothing

The code for that regex filtering follows:
"""

# while we use same start prompt regex as before;
# we must recompile the regex object, because we want
# to find all matches (/g) in multiline string;
# so we must enable "dot match all" so it matches \n;
# and multiline so ^ reacts as start of string after each \n
rx2_regexObj_StartPrompt = re.compile('^\S+\$ ', flags=re.DOTALL|re.MULTILINE)
# the minimized form of prompt for replacement:
rx2_startPromptStr = '$ '

# there is now no line filter function;
# rx2_TermMinPrompt filters the entire
# multiline string input in one go.
# if no prompt is found, the function
# returns the input unchanged
def rx2_TermMinPrompt(inStr):
  ofiltStr = inStr
  if rx2_regexObj_StartPrompt.match(inStr) is not None: # we have a match
    ofiltStr = rx2_regexObj_StartPrompt.sub(rx2_startPromptStr, inStr)
  return ofiltStr


"""
============================================================
Regex Example: rx3_EmailQuote (email quote a text selection)
============================================================

Let's say input is again a terminal output like:

username@pcname:dir$ echo AA
AA
username@pcname:dir$ echo -e "AA\nEE"
AA
EE

We'd want to convert that into format suitable for pasting to e.g.
email - where all lines are prepended with quote prefix: the
character `>` and a space:

> username@pcname:dir$ echo AA
> AA
> username@pcname:dir$ echo -e "AA\nEE"
> AA
> EE

So the regex would be:

* At each new line, insert '> '

The code for that regex filtering follows:
"""

# we want to find all matches (/g) in multiline string;
# so we must enable "dot match all" so it matches \n;
# and multiline so ^ reacts as start of string after each \n
# works for single lines too
rx3_regexObj_StartLine = re.compile('^', flags=re.DOTALL|re.MULTILINE)
# the quote prefix for replacement:
rx3_startQuoteStr = '> '

# Again we filter in one go:
def rx3_EmailQuote(inStr):
  ofiltStr = inStr
  if rx3_regexObj_StartLine.match(inStr) is not None: # we have a match
    ofiltStr = rx3_regexObj_StartLine.sub(rx3_startQuoteStr, inStr)
  return ofiltStr





"""
============================================================
Filter regex function registration, and main function
============================================================

"""

# register filter functions:
filterManager.register(rx1_TermCmdLog)
filterManager.register(rx2_TermMinPrompt)
filterManager.register(rx3_EmailQuote)


"""
Main regex filtering function (called from `on_new_item`)
Calls filters stored in filter manager, in order of
registration, and executes them if they are enabled.
If more than one is enabled, the output of one filter is
daisychained/piped as input of the next enabled filter.
"""
def filterWithRegex(item):
  # just in case: if item is "", simply return it
  if not(item):
    return item
  ofiltStr = ""
  for tmp_fe in filterManager.filters:
    if tmp_fe.isactive:
      filtfunc = tmp_fe.function
      if ofiltStr=="":
        ofiltStr = filtfunc(item)
      else:
        tmpstr = filtfunc(ofiltStr)
        ofiltStr = tmpstr
  return ofiltStr



"""
============================================================
Gtk Event queue inspection:
============================================================

Since we cannot use emit_stop_by_name/stop_emission to
prevent recursive event firing upon set_text of clipboard,
done in a callback;
and we cannot use gtk.gdk.event_peek() as it always None
within a callback;
the event queue must be "manually" reconstructed; see:
http://stackoverflow.com/questions/13108149/peeking-a-gtk-event-gtk-gdk-event-peek-always-returns-none

dumpEventQueue simply prints out the contents of
the event queue on terminal (for debug purposes):
"""
def dumpEventQueue():
  queue = []
  # temporarily set the global event handler to queue
  # the events
  gtk.gdk.event_handler_set(queue.append)
  print "Event queue: ",
  try:
    oldpos = len(queue)
    while gtk.events_pending():
      gtk.main_iteration()
    newa = itertools.islice(queue, oldpos, None)
    for tevent in newa:
      #~ print tevent, ", ",
      print "type:", tevent.type,
      try:
        print "property:", tevent.property,
      except:
        pass
      try:
        print "requestor:", tevent.requestor,
      except:
        pass
      try:
        print "target:", tevent.target,
      except:
        pass
      try:
        print "selection:", tevent.selection,
      except:
        pass
      print
  finally:
    # restore the handler and replay the events
    #~ handler = gtk.main_do_event
    gtk.gdk.event_handler_set(gtk.main_do_event)
  print

"""
The first time clipboard setting event (`change-owner`)
fires, and our `on_new_item` runs, the event in the
queue at that time does not have a .selection property;
however, after we set the clipboard text in the timer
callback `timer_settext_cb` - another `change-owner` is
fired, starting a recursive/endless event loop. However,
in the subsequent event firings, the events in the queue
do have .selection property of gtk.gdk.SELECTION_CLIPBOARD.

This is used by the isEventQueueRecursing to detect and
return whether a recursive event loop has started
"""
def isEventQueueRecursing():
  amRecursing = False
  queue = []
  # temporarily set the global event handler to queue
  # the events
  gtk.gdk.event_handler_set(queue.append)
  try:
    oldpos = len(queue)
    while gtk.events_pending():
      gtk.main_iteration()
    newa = itertools.islice(queue, oldpos, None)
    for tevent in newa:
      try:
        if (tevent.selection == gtk.gdk.SELECTION_CLIPBOARD):
          amRecursing = True
          break
      except:
        pass
  finally:
    # restore the handler
    gtk.gdk.event_handler_set(gtk.main_do_event)
    # somehow, it seems the above messing with event
    # handlers, kills the main GDK event stream;
    # so set it up once more here - so it keeps working
    gtk.gdk.event_handler_set(gSKM.allGDKeventHandler)
  return amRecursing



"""
============================================================
Plugin callback functions
============================================================

When a "Copy" action is made (via Ctrl-C/Ctrl-Shift-C), and
the text has been first copied to clipboard, Gtk fires the
`owner-change` event - `glipper` reacts to it, and in turn
fires the `new-item` event; our plugin, in fact, reacts to this
`new-item` event, by executing the `on_new_item` handler
function.

The filtering of the (old) clipboard contents happens in
`on_new_item`. After that, the latest entry in `glipper`s
history list is set to the (new) filtered contents, and it
is not a problem to do so in that function. However, if we
also try to set_text of the clipboard itself in `on_new_item`,
not only do we start an endless event loop - but it is also
recursive, in the sense that a new `on_new_item` runs before
the old one has exited, which breaks Python's recursion levels.
This also makes some global variables to not change, thus
making it impossible to discriminate between a legitimate event
(originating from a user's "Copy" action) and a looped event
caused by set_text of clipboard in `on_new_item` (although,
the current event queue wasn't tested in that case).

Because of that, in case of a legitimate event, `on_new_item`
calls a timer callback function, which runs an ammount of
milliseconds after `on_new_item` exits. This allows that the
callbacks due looped events are not nested anymore - and
reading the event queue presents different events for
legitimate "Copy" vs. a `set_text` done by this plugin. This
allows `on_new_item` to refuse to do a `set_text` of a
clipboard, and thereby break the endless event loop.

This timer callback function is timer_settext_cb:
"""
def timer_settext_cb(inFiltStr):
  """
  Note: since this is a callback, it cannot see
  "global" variables at "root" of the script!
  Thus, all data for it must be passed as arguments
  when the timer is started!
  First, retrieve reference to glipper clipboards:
  """
  gcs = get_glipper_clipboards()
  """
  Then, set the incoming filtered text as the selection
  contents: do a set_text - this will trigger "owner-change"
  event of this object later; which must be detected (via
  isEventQueueRecursing) and suppressed in `on_new_item`
  function, to prevent an endless recursive loop!!
  Also, attempting to prevent event "owner-change" firing
  here via emit_stop_by_name/stop_emission does NOT work
  (thus the queue must be obtained "manually", which is
  done in isEventQueueRecursing())
  """
  gcs.default_clipboard.clipboard.set_text(inFiltStr)
  """
  A timer callback must return False, so it runs only once
  (otherwise it would be repeated)
  """
  return False

"""
`on_new_item` is the handler/callback function which runs upon
a `new-item` event by `glipper` (which is in turn issued in
response to a `owner-change` event of a Gtk clipboard; initiated
by user's "Copy" action). Or - it defines what happens when new
content comes to clipboard.

Notes:
* it turns out, if `glipper` is set to handle the "Selection"
(primary) clipboard - then `on_new_item` will run,
whenever a just a text *selection* is made (without being
followed by a copy command)!!
* the incoming variable 'item' is always == to get_history_item(0);
get_history_item(1) is the previous one;
* item could be a multiline string! so iterate...
splitlines(True) preserves original line endings!
"""
def on_new_item(item):
  # declare global variables
  global is_filtering
  global should_update_immediately
  """
  because of recursion occuring when we `set_text`,
  check first if item is empty string or None.
  if so, refuse to process further and return
  (although, with proper event queue management,
  that situation doesn't happen (a lot) anymore)
  """
  if not(item):
    #print "item is NOT"
    return
  """
  Check first if we should filter at all,
  depending on state of global toggle;
  however, we do not want the glipper history
  updated when the looped events hit either!
  Thus, do a check for isEventQueueRecursing
  (read more below) already here!
  """
  _isEventQueueRecursing = isEventQueueRecursing()
  #~ print "isEventQueueRecursing", _isEventQueueRecursing
  if is_filtering and not(_isEventQueueRecursing):
    doFilterProcess(item)

"""
doFilterProcess is now split from
`on_new_item`, so we can call it
while bypassing normal operations
"""
def doFilterProcess(item):
  _isEventQueueRecursing = isEventQueueRecursing()
  """
  Perform the actual filtering of the
  [old] clipboard text contents (`item`)
  into [new] filtered text (`filtStr`)
  """
  filtStr = filterWithRegex(item)
  """
  Save the filtered result as the
  latest item in glipper history
  note: if it so happens that filtStr == get_history_item(0)
  then one item (extra) is deleted from history list!
  do a check first
  """
  gho = get_glipper_history()
  #~ print "doFilterProcess:",len(gho.history)
  #~ print get_history_item(0)
  #~ print filtStr
  if not(filtStr == get_history_item(0)):
    set_history_item(0, filtStr)
    """
    must emit `changed`, so the displayed
    `glipper` menu reflects the state of
    history after change
    """
    try:
      gho.emit('changed', gho.history)
    except:
      pass
    """
    up to this point, the history item in Glipper's menu is changed;
    but the clipboard still has original contents, which will be
    pasted on Ctrl-V. Then you must open Glipper menu again, and
    click on the (now modified) history item, to replace the clipboard
    contents with the filtered string, so it can be pasted!
    get_glipper_clipboards() should be used:
    API: /usr/lib/pymodules/python2.7/glipper/Clipboards.py
     can see it in action in on_menu_item_activate from:
     /usr/lib/pymodules/python2.7/glipper/AppIndicator.py
    so re-set the filtered string, to be the content of clipboard(s)?
    but this sets recursion going (print "AAAAA" here would be
    continously output to terminal, as a sign of endless loop)!
    with proper event queue checking - no more need for
    "emit_stop_by_name" (which doesn't work here) ...

    See first whether the Preferences are set to "Immediately
    update clipboard with filtered contents"
    """
    if should_update_immediately:
      """
      so check first if events in queue indicate a recursion loop;
      and if a loop is not yet started - only then set the clipboard
      itself with the filtered text.
      Since this check is now already performed above, we can only
      come to this part when not(_isEventQueueRecursing) is True;
      so it is unnecessarry - but keeping it for development history
      """
      if not(_isEventQueueRecursing):
        glib.timeout_add(250, timer_settext_cb, filtStr)



"""
============================================================
Keypress Listener Class
============================================================

This class used to listen to keypresses once the `glipper`
menu window is raised via main `glipper` keyboard shortcut;
so that we can bypass normal operation when one of these
keys are held, when a filter menu item has been clicked from
the filter plugin submenu. It basically keeps a state of
the keys in the shortcut (whether they're being held or not)
"""
class glipperShortcutKeysManager:
  def __init__(self):
    self.keystatus = list()
    self.chideid=-1
  """
  timer callback for delayed reset
  returns False so it runs only once
  """
  def reset_keystatus_cb(self):
    for tkey in self.keystatus.keys():
      self.keystatus[tkey] = 0
    #~ print "reset", self.keystatus, hex(id(self.keystatus))
    return False
  """
  allGDKeventHandler needs two arguments for .connect callback
  one (or two) for gtk.gdk.event_handler_set
  note: these functions just convert betw. keys' names and
  values - they do not get current state of keys:
  #~ kx11 = gtk.gdk.keymap_get_default()
  #~ keycode = gtk.gdk.keyval_from_name("Alt_L")
  #~ kets = kx11.get_entries_for_keyval(keycode)
  #~ print data, kets, kx11, event
  note: gtk.gdk.KEY_RELEASE : <enum GDK_KEY_RELEASE

  the events coming here now (with main_do_event added)
  are only some - not all - events; but after key combo
  is pressed, `glipper` comes into focus, and now *can*
  listen to all events! But, we can therefore never
  hear the GDK_KEY_PRESS's that activate `glipper`;
  we can only hear the GDK_KEY_RELEASE!
  that is why we also listen now to "activated"
  signal from glipper.Keybinder

  note: make sure data is None (for GDK events)
  so we don't pass the keybinder event to main_do_event
  """
  def allGDKeventHandler(self, event, data=None):
    doPrint = 0
    if data is not None:                # this is keybinder "activated" or menu "hide"
      if (data == menu_item):             # this is # menu "hide" calling
        # this is a result of the menu_item "hide" below;
        # set all shortcut keys to "released";
        # but this may run before we execute our `on_activate`
        # so reset by calling a callback after certain time
        glib.timeout_add(500, self.reset_keystatus_cb)
        # reset listening of menu_item; maybe not needed?
        #~ if self.chideid != -1:
          #~ menu_item.get_parent().disconnect(self.chideid)
          #~ self.chideid = -1
      else:                               # this is keybinder "activated" calling
        # set all shortcut keys to "pressed":
        for tkey in self.keystatus.keys():
          self.keystatus[tkey] = 1
        # listen to master `menu_item`' window?
        # it's parent Menu fires, but has data: None!
        # fix here: simply pass menu_item as (otherwise
        # useless) data
        if self.chideid == -1:
          self.chideid = menu_item.get_parent().connect("hide", self.allGDKeventHandler, menu_item)
      doPrint = 1
    else:                               # data is None - this is Gdk event
      # event.keyval: 65513;
      # gtk.gdk.keyval_name(event.keyval): 'Alt_L'
      # tkey = 'Alt'
      # but problem with tkey = 'c'; keyval_name = 'Escape'
      # so work only with numeric keyvals:
      # 65513 Alt_L; 65514 Alt_R; 65507 Control_L; 65508 Control_R; 99 c
      # but then numeric comparison (as of now) cannot adapt to other
      # shortcuts that <Ctrl><Alt><c>!!
      if event.type == gtk.gdk.KEY_RELEASE:
        # old string comparison:
        #~ for tkey in self.keystatus.keys():
          #~ if tkey in gtk.gdk.keyval_name(event.keyval):
            #~ self.keystatus[tkey] = 0
        # numeric comparison:
        if event.keyval == 65513 or event.keyval == 65514:
          self.keystatus['Alt'] = 0
        if event.keyval == 65507 or event.keyval == 65508:
          self.keystatus['Control'] = 0
        if event.keyval == 99:
          self.keystatus['c'] = 0
        doPrint = 2
      elif event.type ==  gtk.gdk.KEY_PRESS:
        # old string comparison:
        #~ for tkey in self.keystatus.keys():
          #~ if tkey in gtk.gdk.keyval_name(event.keyval):
            #~ self.keystatus[tkey] = 1
        # numeric comparison:
        if event.keyval == 65513 or event.keyval == 65514:
          self.keystatus['Alt'] = 1
        if event.keyval == 65507 or event.keyval == 65508:
          self.keystatus['Control'] = 1
        if event.keyval == 99:
          self.keystatus['c'] = 1
        doPrint = 2
      # MUST have main_do_event at end,
      # else Gnome stops responding to keypresses!
      gtk.main_do_event(event)
    # at end, print for debug (if commenting, leave the pass at end)
    if doPrint > 0:
      #~ print "allGDK", self.isAnyShortcutKeyHeld(), self.keystatus, hex(id(self.keystatus))
      #~ if doPrint > 1:
        #~ print event.keyval, gtk.gdk.keyval_name(event.keyval),
      #~ print event #, menu_item.get_parent().get_parent()
      pass
  """
  if any of the main shortcut keys
  are kept pressed, this function returns true
  """
  def isAnyShortcutKeyHeld(self):
    ret = 0
    for tkey in self.keystatus.keys():
      ret = ret or self.keystatus[tkey]
    return True if ret else False
  """
  main setup of listeners in this class
  """
  def setupGDKKeyListener(self):
    # listen all GDK events (including key press & release)
    gtk.gdk.event_handler_set(self.allGDKeventHandler)
    # listen to 'activated' of keybinder
    gkb = glipper.Keybinder.get_glipper_keybinder()
    gkb.connect("activated", self.allGDKeventHandler)
    # listen to master `menu_item`' window?
    # cannot from here - may not exist yet! do
    # when "activated" is handled, above
    #~ menu_item.get_parent().get_parent().connect("hide", self.allGDKeventHandler)
    # parse shortcut for dict
    key_combo_str = gkb.get_key_combination()
    key_combo_keylist = filter(None, re.compile('[<>]+').split(key_combo_str))
    #~ print key_combo_keylist
    # when creating keystatus dict, replace Ctrl with Control
    # so we can do string comparison in allGDKeventHandler
    self.keystatus = OrderedDict(( key if key != 'Ctrl' else 'Control', 0) for key in key_combo_keylist)
    #~ print self.keystatus


# main object instance of the keys manager
gSKM = glipperShortcutKeysManager()



"""
============================================================
Main plugin & menu setup/initialization
============================================================

"""

def on_show_preferences(parent):
  preferences(parent).show()

def info():
  info = {"Name": _("Filter"),
          "Description": _("This plugin takes the current selection, and filters its lines according to a regex that removes prompt if existing, or prepends a comment character otherwise\\n."),
          "Preferences": True}
  return info


# helper function that updates global vars and prints a message
def update_globals(inmsg):
  global should_update_immediately
  global are_filters_exclusive
  global is_filtering
  cf = confFile("r")
  should_update_immediately = cf.getImmediately()
  are_filters_exclusive = cf.getExclusive()
  cf.close()
  filterManager.updateFilteringStatus() # updates is_filtering
  # if debugging, uncomment this first
  #~ print("glipper filter.py update_globals:", inmsg, is_filtering, should_update_immediately, are_filters_exclusive, filterManager.getFiltersStatus(), gSKM.keystatus, hex(id(gSKM.keystatus)))


# callback when menu item is pressed
def on_activate(inmenuitem, inFilterEntry):
  global is_filtering
  #~ is_filtering = not(is_filtering) # no more master toggle
  # first of all, check if this is a permanent toggle,
  # or temporary action, by checking if keyboard keys are held
  mylabel="on_activate"
  if gSKM.isAnyShortcutKeyHeld():
    #~ gcs = get_glipper_clipboards()
    #~ gcs.primary_clipboard.get_text() could be empty,
    # if it is not activated from glipper;
    # so use our alternative primary clipboard in
    # the filterManager
    seltext = filterManager.getSelectionText()
    mylabel += "_BYPASS"
    #~ print "shortcut key held; bypassing normal operation"
    # disable all filters temporarily, and
    # enable only the one clicked on;
    # also save the initial values..
    origactives = []
    for tmp_fe in filterManager.filters:
      origactives.append(tmp_fe.isactive)
      tmp_fe.isactive = False
      if (tmp_fe == inFilterEntry):
        tmp_fe.isactive = True
    # now do the filter process
    doFilterProcess(seltext)
    # finally restore the original values
    for i in range(len(filterManager.filters)):
      filterManager.filters[i].isactive = origactives[i]
    # and for good measure, update_globals etc at end, should
    # confirm nothing from the usual process has been changed..
    # except that in this case, shortcut key releases
    # are not detected - so do a timer callback reset also here:
    glib.timeout_add(500, gSKM.reset_keystatus_cb)
  else:
    # now individual toggle on submenu click
    # note: we cannot just change variables and
    # call update_menu here, since it destroys
    # and recreates menu - including the source for
    # this callback!
    # however, check first are_filters_exclusive;
    # and if so, reset the filters before toggling:
    # but keep the original isactive value first:
    oldval_active = inFilterEntry.isactive
    if are_filters_exclusive:
      for tmp_fe in filterManager.filters:
        tmp_fe.isactive = False
        filtstr = tmp_fe.name + " " + ( "T" if tmp_fe.isactive else "f" )
        tmp_fe.menuitem.set_label(glipper.format_item(filtstr))
        tmp_fe.menuitem.set_tooltip_text(filtstr)
    # now toggle for real
    inFilterEntry.isactive = not(oldval_active)
    # indicate status on submenu entry
    filtstr = inFilterEntry.name + " " + ( "T" if inFilterEntry.isactive else "f" )
    inmenuitem.set_label(glipper.format_item(filtstr))
    inmenuitem.set_tooltip_text(filtstr)
  # now call update_globals first, to get latest is_filtering
  mylabel += ":"
  update_globals(mylabel)
  # indicate on the master `menu_item`
  menu_item.set_label("Filtering: " + str(is_filtering))


# `menu_item` is the master entry in `glipper` menu ("Filtering: ")
# `menu` is the submenu which we attach to the master `menu_item`
# update_menu destroys and recreates the submenu (`menu`)
# expected to be called once (or few times); here a reference
# to a GtkWindow is available, to set up listening for keypresses
# for detecting held buttons
def update_menu():
  max_length = glipper.GCONF_CLIENT.get_int(glipper.GCONF_MAX_ITEM_LENGTH)
  global menu
  menu.destroy()
  menu = gtk.Menu()
  if not(len(filterManager.filters) > 0):
    menu.append(gtk.MenuItem(_("No filters available")))
  else:
    for tmp_fe in filterManager.filters:
      filtstr = tmp_fe.name + " " + ( "T" if tmp_fe.isactive else "f" )
      item = gtk.MenuItem(glipper.format_item(filtstr))
      if len(filtstr) > max_length:
        item.set_tooltip_text(filtstr)
      item.connect('activate', on_activate, tmp_fe)
      tmp_fe.menuitem = item
      menu.append(item)
  menu.show_all()
  menu_item.set_submenu(menu)
  # menu .get_parent() makes reaction only when
  # master `menu_item` is focused (by hovering mouseover)
  # parent window is gtk.Window (GtkWindow): key_press_event
  #~ pWindow = menu.get_root_window()
  #~ pWindow.connect('key-press-event', onKeyPress_f)
  #~ pWindow.connect('key-release-event', onKeyRelease_f)
  # use root window instead
  # root window is gtk.gdk.Window (GdkWindow): unknown signal name: key_press_event
  # must listen to all GDK events then - via gSKM.allGDKeventHandler()


def stop():
  global menu
  menu.destroy()



def init():
  glipper.add_menu_item(menu_item)
  # master `menu_item` no longer reacts to clicks:
  #~ menu_item.connect('activate', on_activate)
  glipper.GCONF_CLIENT.notify_add(glipper.GCONF_MAX_ITEM_LENGTH, lambda x, y, z, a: update_menu())
  gSKM.setupGDKKeyListener()
  update_menu()





"""
============================================================
Preferences dialog and config file setup
============================================================

"""

#config file class:
class confFile:
  def __init__(self, mode):
    self.mode = mode

    conf_path = os.path.join(glipper.USER_PLUGINS_DIR, 'filter.conf')
    if (mode == "r") and (not os.path.exists(conf_path)):
      self.immediately = True
      self.exclusive = True
      return
    self.file = open(conf_path, mode)

    if mode == "r":
      self.immediately = self.file.readline()[:-1] == "True"
      self.exclusive = self.file.readline()[:-1] == "True"

  def setImmediately(self, im):
    self.immediately = im
  def getImmediately(self):
    return self.immediately
  def setExclusive(self, im):
    self.exclusive = im
  def getExclusive(self):
    return self.exclusive
  def close(self):
    if not 'file' in dir(self):
      return
    try:
      if self.mode == "w":
        self.file.write(str(self.immediately) + "\n")
        self.file.write(str(self.exclusive) + "\n")
    finally:
      self.file.close()


#preferences dialog:
class preferences:
  def __init__(self, parent):
    builder_file = gtk.Builder()
    builder_file.add_from_file(os.path.join(os.path.dirname(__file__), "filter.ui"))
    self.prefWind = builder_file.get_object("preferences")
    self.prefWind.set_transient_for(parent)
    self.immediatelyCheck = builder_file.get_object("immediatelyCheck")
    self.exclusiveCheck = builder_file.get_object("exclusiveCheck")
    self.prefWind.connect('response', self.on_prefWind_response)

    #read configurations
    f = confFile("r")
    self.immediatelyCheck.set_active(f.getImmediately())
    self.exclusiveCheck.set_active(f.getExclusive())
    f.close()

  def destroy(self, window):
    window.destroy()

  def show(self):
    self.prefWind.show_all()

  #EVENTS:
  # must set the global variable here too, if we want a live update;
  # either that, or we call update_globals()
  def on_prefWind_response(self, widget, response):
    if response == gtk.RESPONSE_DELETE_EVENT or response == gtk.RESPONSE_CLOSE:
      f = confFile("w")
      f.setImmediately(self.immediatelyCheck.get_active())
      f.setExclusive(self.exclusiveCheck.get_active())
      f.close()
      update_globals("on_prefWind_response:")
      widget.destroy()





"""
Install instructions:

In glipper Preferences there is "Which clipboards should be managed by Glipper?"
(use_primary_clipboard_check): Selection (mark/middle mouse button)
(use_default_clipboard_check): Copy (Ctrl+C/Ctrl+V)

To use this plugin properly - make sure:
* "Selection" is *not* checked (inactive); and
* only "Copy" clipboard is activated


to install: glipper plugin locations:

/usr/share/glipper/plugins
/home/username/.local/share/glipper/plugins/
( ~/.local/share/glipper/plugins/ )

can symlink? ~/.local/share... one doesn't work!!
(it only has actions.conf there)
# ln -s /path/filter.py ~/.local/share/glipper/plugins/
# glipper       # not present in Plugins
# rm ~/.local/share/glipper/plugins/filter.py

# only symlink to /usr/share works (needs sudo):

sudo ln -s /path/filter.py /usr/share/glipper/plugins/
sudo ln -s /path/filter.ui /usr/share/glipper/plugins/

# kill running glipper:

$ pgrep -fl glipper
1748 /usr/bin/python /usr/bin/glipper
$ pkill -f glipper ; echo $?
0             # 0 if killed

# run glipper twice after changing a script

# run glipper from command line once as `sudo`
# after symlinking and killing running instance;
# and check once if plugin present there, then exit;
# so compiled python `.pyc` is generated
# (though a compiled .pyc is not good while developing)

$ sudo glipper
SHARED_DATA_DIR: /usr/share/glipper
Binding shortcut <Ctrl><Alt>c to popup glipper
Changed process name to: glipper
^CTraceback (most recent call last):
  File "/usr/bin/glipper", line 45, in <module>
    gtk.main()
KeyboardInterrupt

$ ls -la /usr/share/glipper/plugins | grep filter
lrwxrwxrwx 1 root root    51 2013-04-07 13:45 filter.py -> /path/filter.py
-rw-r--r-- 1 root root  2099 2013-04-07 13:46 filter.pyc

Now can run `glipper` from "Run Application" (Alt+F2 in Gnome);
Go to plugins - activate checkmark for "Enabled" and "Autostart"

Then when filter is needed, call up glipper, and activate the
"Filtering: (status)" menu entry; status will be updated in the
menu entry itself

To find syntax errors with this file
(then glipper exits before a Traceback going to this file):
python -m py_compile filter.py

Developed on:

$ uname -a
# Linux ljutntcol 2.6.38-16-generic #67-Ubuntu SMP Thu Sep 6 18:00:43 UTC 2012 i686 i686 i386 GNU/Linux

$ cat /etc/issue
# Ubuntu 11.04 \n \l

$ python --version
# Python 2.7.1+

$ apt-show-versions glipper
# glipper/natty uptodate 2.1-0ubuntu1

$ apt-show-versions python-gtk2
# python-gtk2/natty uptodate 2.22.0-0ubuntu1.1

filter.ui started from nopaste.ui and actions.ui

"""

