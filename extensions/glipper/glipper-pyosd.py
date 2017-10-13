from glipper import *
from gettext import gettext as _
import gtk
# don't call this file pyosd.py - else recursion with libname below!
import pyosd # XOSD ;

# to install:
# sudo ln -s $PWD/pyosd.py /usr/share/glipper/plugins/

# 2014-06-23

#~ import inspect
#~ import pprint
#~ pp = pprint.PrettyPrinter(indent=4)

# based on pyosd.py plugin

# global var
is_osd = False

# menu item
menu_item = gtk.MenuItem(_("PyOSD: " + str(is_osd))) #
menu = gtk.Menu()

# default_font="-*-helvetica-medium-r-normal-*-*-360-*-*-p-*-*-*"
# xlsfonts | less # to find fonts, say
# -misc-fixed-bold-r-normal--0-0-75-75-c-0-iso10646-1:
#~ tfont="-*-fixed-bold-r-normal--*-*-100-*-c-*-*-*"
tfont="-*-fixed-bold-r-normal--*-*-150-150-c-*-*-*"
osd = pyosd.osd(font=tfont, colour='#FF0000', lines=3) #1) #3)
#~ osd.set_align(pyosd.ALIGN_CENTER)
osd.set_align(pyosd.ALIGN_LEFT)
osd.set_pos(pyosd.POS_MID)
display = osd.display
osd.set_timeout(1)
# display will last as long the python program hasn't exited!
#display("Hello")
#display(50, type=pyosd.TYPE_SLIDER, line=0)

display("Hello from glipper pyosd/XOSD", line=1) #0) #1)

def printarr(inarr):
	print("\n")
	ic = 0
	for item in inarr:
		print(ic, inarr[ic], "\n")
		ic+=1

def on_new_item(item):
	global is_osd
	global pp
	gho = get_glipper_history()
	if is_osd:
		#~ print("glipper pyosd.py on_new_item:")
		#~ print(item, " -> ", get_history_item(0)) #" *** ", get_history_item(1))
		## printarr(gho.get_history()) #DBG

		#~ nowitem=""
		#~ try:
			#~ nowitem=get_history_item(0)
		#~ except:
			#~ pass
		#~ if nowitem is None:
			#~ nowitem=""
		nowitem=get_history_item(0)
		#display(nowitem, line=0)  # ok, but
		lines=nowitem.splitlines()
		lln = len(lines)
		if (lines[0]):
			display(lines[0], line=0)
		else:
			display("", line=0)
		if (lln>1):
			display(lines[1], line=1)
		else:
			display("", line=1)
		if (lln>2):
			display(lines[len(lines)-1], line=2)
		else:
			display("", line=2)




def info():
	info = {"Name": _("PyOSD"),
	        "Description": _("This plugin should make an on-screen display upon a copy operation\\n."),
	        "Preferences": False}
	return info


def on_activate(menuitem):
	global is_osd
	is_osd = not(is_osd)
	menuitem.set_label("PyOSD: " + str(is_osd))
	print("glipper pyosd.py on_activate:", is_osd)

def init():
	glipper.add_menu_item(menu_item)
	menu_item.connect('activate', on_activate)

