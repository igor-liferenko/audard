
################################################################################
# captmini-debug-fg.gdb                                                        #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# captmini-debug-fg.gdb (fg: function graph)
# have to call this script via gdb on command line with:
# LD_PRELOAD=/media/disk/src/alsa-lib-1.0.24.1/src/.libs/libasound.so.2.0.0 gdb -batch -x captmini-debug-fg.gdb

#target exec ./captmini # not this;
# can only use `file` for the executable:
file ./captmini

# ... but cannot `load` nor `add-symbol-file` the .so from here;
# thus must call from cmdline with LD_PRELOAD as above;
# if called without LD_PRELOAD, then `step` will act like `next`;
# (and only the first level steps will be shown)
# if called with LD_PRELOAD and a debug .so - then
# step will step within the .so as well...

# $pc is current addresss
# `where` is like `backtrace`

## an example of gdb script API:

#break doCapture
#commands
#  silent
#  #printf "\n"
#  #print $pc
#  list *$pc,+0
#  #printf "\n"
#  continue
#end
#
#break captmini.c:74
#commands
#  silent
#  #printf "\n"
#  list *$pc,+0
#  #printf "\n"
#  continue
#end

## through Python API:

python

# note: Python gdb API has sys - but without sys.argv!

def getCurrentSourceLine():
  # gdb.write - like print, but somewhat more buffered, even with flush (though letting gdb print its own is faster that to_string=True)
  # gdb.decode_line() - like gdb.find_pc_line(pc)
  #~ current_line = gdb.decode_line()
  #~ sourcefilename = current_line[1][0].symtab.filename # can go wrong with filename, too!
  listingline = gdb.execute("list *$pc,+0", to_string=True)
  listpreamble, gdbsourceline = listingline.split("\n")[:2]
  addr, noneed, noneed, funcname, fileloc = listpreamble.split(" ")[:5]
  sourcefilename = fileloc[1:fileloc.rfind(":")]
  outline = "%s % 16s:%s\n" % (addr, sourcefilename[-16:], gdbsourceline)
  return outline

class MyBreakpoint(gdb.Breakpoint):
  import sys
  def __init__(self, spec, parent, isStopper):
    super(MyBreakpoint, self).__init__(spec, gdb.BP_BREAKPOINT,
                                             internal = False)
    self.parent = parent
    self.isStopper = isStopper
  def stop(self):
    #gdb.execute("silent") # here disables printout completely!
    gdb.write(getCurrentSourceLine(), gdb.STDOUT) ; gdb.flush(gdb.STDOUT)
    #~ print(getCurrentSourceLine())
    #gdb.execute("silent") # here printout ok for source line - but not steps!
    if not(self.isStopper):
      self.parent.isRunning = True
    else:
      self.parent.isRunning = False
    #gdb.execute("silent") # here printout ok for source line and steps; but doesn't prevent the default as it should!
    return True

#~ ax = MyBreakpoint("doCapture", None, False)
#~ bx = MyBreakpoint("captmini.c:74", None, True)

class BreakpointFuncTraceStepper(object):
  def __init__(self, specStart, specStop):
    self.bpStart = MyBreakpoint(specStart, self, False)
    self.bpStop = MyBreakpoint(specStop, self, True)
    self.isRunning = False
  def stop_handler (self, event):
    # if resulting from breakpoint returning True from stop();
    # then here we get gdb.BreakpointEvent, which in gdb 7.3
    # has no attributes (so no .breakpoint or .breakpoints)!
    #print("event type: stop", self.isRunning, event, dir(event), ax)
    if self.isRunning:
      # note: even when extending gdb.Command - `libpython.py` uses
      # `gdb.execute(,to_string=True)` for "silent" stepping!
      # but, even if both breakpoints and this step are suppressed
      # in that way, just the very act of stepping slows everything
      # down - enough to generate error at second read
      # even "silent" `next` (or `until`) instead of `step` causes error too - only `continue` doesn't!
      gdb.execute("step")
      #~ gdb.execute("next")
      #~ gdb.execute("step", to_string=True) # "silent"; supresses last breakpoint printout! (and errors still happen)
      #~ print(gdb.execute("step", to_string=True)) # print(to_string) is too slow
      #~ print(gdb.execute("step", to_string=True).split("\n")[0])
      #~ gdb.write(gdb.execute("next", to_string=True), gdb.STDOUT) ; gdb.flush(gdb.STDOUT)
    else:
      gdb.execute("continue")
      #~ gdb.write(gdb.execute("continue", to_string=True), gdb.STDOUT) ; gdb.flush(gdb.STDOUT)

# CHANGE TRACE END-BREAKPOINTS HERE
bf1 = BreakpointFuncTraceStepper("doCapture", "captmini.c:74")

# this is needed for "grounding", it seems;
# apparently, if there aren't references to bpStart/Stop on the "root";
# then the stop_handler never fires??!
ax = bf1.bpStart
bx = bf1.bpStop

gdb.events.stop.connect (bf1.stop_handler)

#~ print(dir(bf1))

# end Python code
end

# must enforce "silent" from gdb - cannot do it from the Python breakpoints
commands 1
  silent
end
commands 2
  silent
end


run

python
#print(dir(gdb))

# cannot use gdb.FinishBreakpoint with gdb 7.3; needs at least 7.4
# http://stackoverflow.com/questions/10501121/gdb-script-not-working-as-expected/10547319#10547319
# 7.3 says: AttributeError: 'module' object has no attribute 'FinishBreakpoint'
#class MyFinishBreakpoint(gdb.FinishBreakpoint):
#  def __init__(self, spec, command=""):
#    super(MyFinishBreakpoint, self).__init__(spec, gdb.BP_BREAKPOINT,
#                                             internal = False)
#    self.command = command # not used
#
#  def stop (self):
#    print("AM HERE")
#    return False # don't want to stop
#bx = MyFinishBreakpoint("doCapture")
end
