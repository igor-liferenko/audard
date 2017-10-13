from glipper import *
from gettext import gettext as _
import gtk

# 2011-10-15:
# [https://bugs.launchpad.net/glipper/+bug/875371 Bug #875371 “Enhancement: append to clipboard plugin” : Bugs : Glipper]
#~ import inspect
#~ import pprint
#~ pp = pprint.PrettyPrinter(indent=4)

# based on snippets.py, newline.py plugins

# global var 
is_appending = False

# menu item
menu_item = gtk.MenuItem(_("Appending: " + str(is_appending))) #(_("Append"))
menu = gtk.Menu()


def printarr(inarr):
	print("\n")
	ic = 0
	for item in inarr:
		print(ic, inarr[ic], "\n")
		ic+=1 

def on_new_item(item):
	global is_appending
	global pp
	gho = get_glipper_history()
	if is_appending: 
		#~ print("glipper append.py on_new_item:")
		#~ print(item, " -> ", get_history_item(0)) #" *** ", get_history_item(1))
		## printarr(gho.get_history()) #DBG

		previtem=""
		try:
			previtem=get_history_item(1)
		except:
			pass
		if previtem is None:
			previtem=""

		# the incoming var 'item' is always == to get_history_item(0); 
		# get_history_item(1) is the previous one 
		# append current at end of previous (previous first)
		tempmerge = previtem + "\n" + item
		# replace the 0 history entry with appended/merged content
		set_history_item(0, tempmerge)
		
		## printarr(gho.get_history()) #DBG
		
		# erase previous history entry (1)
		try:
			# must emit changed so the display reflects state of history after change
			remove_history_item(1)
			gho.emit('changed', gho.history)
		except:
			pass
		## printarr(gho.get_history()) #DBG

def info():
	info = {"Name": _("Append"),
	        "Description": _("This plugin takes the current selection, and appends it to the first history item, along with a \\n."),
	        "Preferences": False}
	return info


def on_activate(menuitem):
	global is_appending
	is_appending = not(is_appending)
	menuitem.set_label("Appending: " + str(is_appending))
	print("glipper append.py on_activate:", is_appending) 

def init():
	glipper.add_menu_item(menu_item)
	menu_item.connect('activate', on_activate)
	
