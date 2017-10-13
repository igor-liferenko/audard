#!/usr/bin/env python
#  Ccal - Curses Calendar and todo-list manager.
#  Copyright (C) 2004  Jamie Hillman.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  The GNU GPL is contained in /usr/doc/copyright/GPL on a Debian
#  system and in the file COPYING in the Linux kernel source.
#
# Changes:
#
# 0.2: added color and fixed the go-to date function made cursor invisible when
# drawing, made things a bit flickery
#
#
# Changes:
# 0.3: added support for network-based storage of data - via cgi script 
# much better handling of terminal resizing - works with sizes other than 
# just vt100 now
#
# 0.4: now has an UpNext mode - triggered with the u
# key also changed the default colours to get rid of the dark blue that's a
# problem on some terminals
# added todo-list summary to main page
# cut-n-paste added (y or d to copy/cut and p to paste)
# added ical import  (thanks to python-pdi - http://savannah.nongnu.org/projects/python-pdi)
#   this code is dumped into this one file as I didn't want to ship lots of separate files or have
#   to require people to download extra libraries.  I also did some hacking about to make the parser more
#   tolerant of deviations from the standard.
#   imported entries can be prefixed with a string of the users choosing
#   in order to distinguish them from other entries
# added help feature - triggered with ?
# warning - i key isn't toggle storage any more, it's import ical.  toggle storage is now assigned to the z key
#
# 0.5
# * colour coded entries to indicate priority etc.  press 0-3 to colour code
# * upnext has friendly entries for dates - how far they are away (thanks to Nick Blundell)
# * can now press x to get a postscript file (to print) summarising forthcoming appointments (thanks to Nick Blundell) (requires latex and dvips)
# * now have (e)xtended mode for entries.  
#   when adding an entry enter only e and an editor will be launched.
#   the first line of the text file is the title and the rest will be stored under
#   that entry.  entries with extra text appear with "(e)" after them.  pressing e over these entries (in entry or todo mode) will bring the editor up again so you can edit the entry.
#   you can also edit existing entries by pressing e.
#   to set a different editor (default is vim) or different tmp path (default is /tmp) add something like the following to your config file:
#
#	[editing]
#	temppath=/tmppath
#	editor=myeditor
#   export is now on E as this feature has stolen e from it.
#
#
# 0.6
# * fixed some weird behaviour with cut 'n' paste.
# * added email-import to todo list (only tested with mutt).  you can pipe an email in mutt to ccal and it will be imported as a todo list item with the subject as the title and the message as the extended text of the item.
# 0.6.1
# small changes by sdaau to prevent crashing during import of my specific ics files.. 
# added -n switch for temp usage without reference to database
# added -i switch for import of ics via command line




import curses
import imaplib,getpass
import copy
import email
import curses.textpad
import time
import threading
import shelve
import calendar
import datetime
import os
import sys
reload(sys)
sys.setdefaultencoding( "utf-8" ) 
import httplib, urllib, pickle, urllib2
import ConfigParser
from optparse import OptionParser,OptionError

import vobject
from vobject import base, icalendar, behavior, vcard, hcalendar

# not using resource_stream now, so no need for pkg_resources (which requires installation of setuptools)
# from pkg_resources import resource_stream 

import logging
import subprocess

class CursesCal:
	def __init__(self):

		self.charsep = "," # separator character for importics
		LOG_FILENAME = str(sys.argv[0])+".log" # 'ccal-0.6.1.log'

		parser=OptionParser()
		parser.add_option("-c","--cal",dest="cal",action="store_true",default=False,help="print todays appointment to the command line and quit")
		parser.add_option("-t","--todo",dest="todo",action="store_true",default=False,help="print todo list to the command line and quit")
		parser.add_option("-m","--mutt",dest="mutt",action="store_true",default=False,help="used to pipe a message from mutt to be added to the todo list")
		# parser.add_option("-d","--debuglog",dest="debuglog",action="store_true",default=False,help="generate debug log")
		parser.add_option("-n","--nousedb",dest="nousedb",action="store_true",default=False,help="don't use a local or remote db (no load or save, temp run)")
		parser.add_option("-i","--importics",dest="importics",action="store",type="string",help="import .ics local file; expects '"+self.charsep+"' separated list, no spaces:    file1.ics"+self.charsep+"string-to-prepend1"+self.charsep+"file2.ics"+self.charsep+"string-to-prepend2"+self.charsep+"... ")

		(options, args) = parser.parse_args()
		
		callingloc = os.getcwd() 
		#print sys.argv[0], callingloc # argv[0] is /usr/bin if symlinked, cwd is loc of script
		os.chdir(callingloc) # cd to the location of the calling directory
		sys.path.append(callingloc) 
		
		self.useServerStorage=False
		self.noUseDb=False
		self.dbglog=False
		self.importIcs=None
		rcpath=os.path.expanduser("~")+"/.ccalrc"
		cp=ConfigParser.ConfigParser()
		cp.read(rcpath)
		self.temppath="/tmp"
		self.editor="vim"
		self.prependsa = {} # dict where key is prepend string of ical, and val is color index 
		self.newcount=0
		
		try:
			self.temppath=cp.get("editing","temppath")
			self.editor=cp.get("editing","editor")
			self.cgiURL=cp.get("database","cgiURL")
			self.useServerStorage=True
		except Exception,e:
			pass	

		if options.cal or options.todo:
			self.printTodaysAppointments(todo=options.todo,cal=options.cal)
			sys.exit()

		if options.nousedb:
			self.noUseDb=True

		# #if not options.debuglog: #still creates a 0 bytes file
		# #	logging.disable(logging.DEBUG)
		
		# tlog = logging.getLogger("ccal-0.6.1") #(__name__)
		# if options.debuglog:
			# self.dbglog=True
			# logging.basicConfig(filename=LOG_FILENAME,level=logging.DEBUG)
			# tlog.setLevel(logging.DEBUG)
			# fh = logging.FileHandler(LOG_FILENAME)
			# fh.setLevel(logging.DEBUG)
			# tlog.addHandler(fh)
		# else:
			# logging.disable(logging.DEBUG)
		
		self._cal=Calendar(self)
		self._cal.loadDatabase()

		if options.importics:
			self.importIcs = options.importics.split(self.charsep)
			iicslen = len(self.importIcs)
			if (iicslen % 2)==0 and iicslen>0:
				for i in range(iicslen/2):
					dubi = 2*i
					filename = self.importIcs[dubi]
					afilename = os.path.abspath(filename) # if needed
					prepend = self.importIcs[dubi+1]
					print "Loading: ", prepend, "-", filename #'preloader'
					### if self.dbglog: tlog.debug( "%s %s %s", "importics: " + str(i)+"/"+str(dubi)+","+str(dubi+1), filename, prepend )  
					#colnum=i+1 # try to fake different colors for calendar prepend strings # cannot here
					self._cal.importIcal(prepend,filename)
			else:
				raise OptionError(self,"\nimportics\n\nNumber of importics arguments must be > 0, and must be even\n\n")
		
		if options.mutt:
			pipeinput=""
			line=sys.stdin.read()
			while (line!=""):
				pipeinput+=line
				line=sys.stdin.read()

			msg=email.message_from_string(pipeinput)
			title=msg['subject']
			body=""

			for part in msg.walk():
				if part.get_content_type()=="text/plain":
					body+=part.get_payload()

			body=body.split("\n")
			if not title==None and not title=="":
				self._cal.addToImportList(ccalItem(title,fullentry=body))
				sys.exit(0)
			else:
				print "Couldn't parse email!"
				sys.exit(1)

		self.scr=curses.initscr()
		
		rows, cols = self.scr.getmaxyx()
		if rows<24 or cols<80:
			print "Your terminal is not big enough!"
			sys.exit()
		curses.start_color()
		try:
			curses.curs_set(0)
		except:
			pass
		curses.init_pair(1, curses.COLOR_RED, curses.COLOR_BLACK)		
		curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)	# date, title and NextUp dates
		curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)	
		curses.init_pair(4, curses.COLOR_BLACK, curses.COLOR_WHITE)

		for i in range(7): # for ics prepends
			curses.init_pair(11+i, 1+i, curses.COLOR_BLACK)
		
		curses.noecho()
		curses.cbreak()
		self.scr.keypad(1)
		self.mode=0  # 0,1 or 2  - - 0 for browsing dates, 1 for manipulating entries, 2 for todo list
		self.previousMode=0
		self.selected=0 #selected diary entry
		self.pasteText=""
		self.running=True
		self.scr.timeout(5000)


	def printTodaysAppointments(self,todo=False,cal=False):
		self._cal=Calendar(self)
		self._cal.loadDatabase(withcurses=False)
		print "ccal entries:\n"
		if cal:
			print "Calendar:\n"
			for item in self._cal.getItems():
				if not str(item.__class__)=="__main__.ccalItem":
					item=ccalItem(item)

				print item.entry
			print "\n"
		if todo:
			print "Todo list:\n"
			entries=self._cal.getItems("todolist")	
			if entries!=None:
				for entry in entries:
					if not str(entry.__class__)=="__main__.ccalItem":
						entry=ccalItem(entry)
	
					print entry.entry

	def destroy(self):
		self.running=False
		curses.nocbreak()
		self.scr.keypad(0)
		self._cal.destroy()
		curses.echo()
		curses.endwin()


	def setItemTypeForSelected(self,type):
		entries=self._cal.getItems()
		if entries==None:
			return
		try:
			self._cal.setItemType(self.selected,type)	
		except exception,e:
			pass


	def errorMessage(self,message):
		rows, cols = self.scr.getmaxyx()
		self.addstr(rows-2,1,message)
		self.scr.refresh()
		curses.beep()
		time.sleep(1)

	def addstr(self,y,x,string,*args):
		try:
			if len(args)!=0:
				self.scr.addstr(y,x,string,args[0])
			else:
				self.scr.addstr(y,x,string)
			
		except Exception,e :
			self.handleException(e)
		
	def handleException(self,e):
		if str(e.__class__)!="_curses.error":
			curses.nocbreak()
			self.scr.keypad(0)
			curses.echo()
			curses.endwin()
			print e
			sys.exit()


	def drawTitleBar(self):
		self.addstr(0,1,"CursesCal - by Jamie Hillman",curses.color_pair(2))
		rows, cols = self.scr.getmaxyx()
		self.addstr(0,cols-len(self._cal.currentdatestring),str(self._cal.currentdatestring),curses.color_pair(2))
		

	def drawFooter(self):
		rows, cols = self.scr.getmaxyx()
		self.addstr(rows-1,0," "+str(self.newcount)+" new messages in inbox")

	def drawCurrentDayTitle(self):
		self.addstr(1,1,"Currently Viewing: "+self._cal.viewdatestring,curses.color_pair(1))

	def drawMode(self):

		rows, cols = self.scr.getmaxyx()
		if self.mode==0:
			self.addstr(rows-1,cols-12,"Mode: Date")
		elif self.mode==1:
			self.addstr(rows-1,cols-12,"Mode: Entry")
		elif self.mode==2:
			self.addstr(rows-1,cols-12,"Mode: To-do")
		elif self.mode==3:
			self.addstr(rows-1,cols-14,"Mode: NextUp") # crash here when cols-12

		if self.noUseDb:
			self.addstr(1,1,"Not using database (temporary run)")
		else:
			if self._cal.useServerStorage:
				self.addstr(1,1,"Using internet database")
			else:
				self.addstr(1,1,"Using local database")
		

	def drawCalendar(self):
		rows, cols = self.scr.getmaxyx()
		startx=cols-23
		ypos=6
		xpos=startx
		caltext=calendar.month(self._cal.viewtime[0],self._cal.viewtime[1]).split("\n")	
		self.addstr(4,startx,caltext[0])
		self.addstr(5,startx,caltext[1])
		for line in caltext[2:]:
			day=str(int(self._cal.viewtime[2]))
			offset=0
			for i in range(7):
				item=line[int(offset):int(offset+2)]
				offset+=3

				dayval=0
				try:
					dayval=int(item)
				except:
					pass
						
				if dayval==int(day): 
					self.addstr(ypos,xpos,item,curses.color_pair(4))
				else:
					if dayval!=0 and self._cal.hasItems(dayval,self._cal.viewtime[1],self._cal.viewtime[0]):
						self.drawEntry(ypos,xpos,item,True)
					else:
						self.drawEntry(ypos,xpos,item,False)

				xpos+=3
			xpos=startx
			ypos+=1

			
			
			

	def main(self):
		while 1:
			#render
			self.scr.clear()
			self.drawTitleBar()
			#self.drawFooter()
			self.drawEntries()
			self.drawMode()
			if self.mode!=2:
				self.drawCalendar()
				self.drawTodoSidebar()
			try:
				self.scr.move(23,0)
			except Exception,e:
				self.handleException(e)
			#refresh
			self.scr.refresh()
			
			#get and handle keypress
			char=-1
			rows, cols = self.scr.getmaxyx()
			prevrows=rows
			prevcols=cols
			while char==-1:
				char=self.scr.getch()
				if self._cal.readImports():
					char=1
				self._cal.updateCurrentTime()
			if self.handleKey(char)!=None:
				break
			
	def selectDOWN(self):
		entries=self._cal.getItems()
		if entries==None:
			return
		size=len(entries)
		if (self.selected+1)==size:
			return
		self.selected+=1

	def selectUP(self):
		entries=self._cal.getItems()
		if entries==None:
			return
		if self.selected==0:
			return
		self.selected-=1

	def deleteSelected(self):
		entries=self._cal.getItems()
		if entries==None:
			return
		try:
			self.pasteText=entries[self.selected]
			self._cal.deleteItem(self.selected)	
		except exception,e:
			pass
		self.selected-=1
		if self.selected<0:
			self.selected=0


#	Nick
	def friendlyDateTimeDelta(self, dateTimeDelta) :

		daysLimit = 1*7
		weeksLimit = 8*7

		# Calculate a friendly time delta string.
		friendlyTimeDelta = ""

		if dateTimeDelta.days == 0 :
			friendlyTimeDelta = "today"
		elif dateTimeDelta.days == 1 :
			friendlyTimeDelta = "tommorow"
		elif dateTimeDelta.days == 2 :
			friendlyTimeDelta = "day after tommorow"
		elif dateTimeDelta.days > 2 and dateTimeDelta.days < daysLimit :
			friendlyTimeDelta = "in " + str(dateTimeDelta.days) + " days"
		elif dateTimeDelta.days >= daysLimit and dateTimeDelta.days < weeksLimit :
			
			weeks = dateTimeDelta.days / 7
			days = dateTimeDelta.days - 7*weeks

			if weeks == 1 :
				friendlyTimeDelta = "in "+str(weeks)+" week"
			elif weeks > 1 :
				friendlyTimeDelta = "in "+str(weeks)+" weeks"
			
			if days == 1 :
				friendlyTimeDelta += " and "+str(days)+" day"
			elif days > 1 :
				friendlyTimeDelta += " and "+str(days)+" days"

		elif dateTimeDelta.days > weeksLimit :
			
			weeks = dateTimeDelta.days / 7
			friendlyTimeDelta = "in "+str(weeks)+" weeks"
			
		return friendlyTimeDelta

	def drawEntries(self) :

		if self.mode == 3 :
			self.drawNextUpEntries(120)
		else:
			self.drawTodaysEntries()



	
	def createEntriesPostscriptFile(self, nextNDays=360):
		# Check we have latex and dvips installed.
		# TODO: Maybe allow a simple text file to be written.
		if os.system("which latex &> /dev/null") > 1 or os.system("which dvips &> /dev/null") > 1 :
			self.errorMessage("Couldn't find latex and/or dvips")
			return

		# Set a temporary filename for the latex file.
		tempDiaryFile = "ccal-diary-temp"

		# Hardcoded latex template.
		latexTemplate = "\\documentclass[a4paper,10pt,twocolumn]{article}\n\
\\topmargin=-1.75cm\n\
\\textheight=25.5cm\n\
\\textwidth=13.7cm\n\
\\oddsidemargin=1cm\n\
\\evensidemargin=1cm\n\
\\date{Entries from: "+self._cal.currentdatestring+"}\n\
\\title{Diary Entries (produced by ccal\\footnote{ccal by Jamie Hillman}~)}\n\
\\begin{document}\n\
\\maketitle\n\
\\begin{scriptsize}\n\
\\begin{raggedright}\n\
<DIARY_ENTRIES>\n\
\\end{raggedright}\n\
\\end{scriptsize}\n\
\\end{document}"

		# Initialise diary entries.
		diaryEntries = ""

		# Add the diary entries to the Latex template.
		for i in range(nextNDays) :

			viewtime = (datetime.datetime(self._cal.viewtime[0],self._cal.viewtime[1],self._cal.viewtime[2])+datetime.timedelta(days=i)).timetuple()
			entries=self._cal.getItems(viewtime)
			
			if entries!=None and len(entries) > 0:

				dateString = time.strftime(self._cal.dateformat,viewtime)
				diaryEntries += "\\textbf{"+dateString+"\\\\}\n"
				
				for entry in entries:
					if not str(entry.__class__)=="__main__.ccalItem":
						entry=ccalItem(entry)

					diaryEntries += "~~"+entry.entry+"\\\\"

				diaryEntries += "\\ \\\\"

		# If there were no entries, say so.
		if diaryEntries == "" :
			diaryEntries = "No diary entries!"

		# Write the latex file.
		latexFile = open(tempDiaryFile+".tex", "w")
		latexFile.write(latexTemplate.replace("<DIARY_ENTRIES>", diaryEntries))
		latexFile.close()

		# Compile the latex file.
		os.system("latex "+tempDiaryFile+".tex &> /dev/null")
		
		# Generate postscript file in the user's home directory.
		os.system("dvips -f "+tempDiaryFile+".dvi 1> "+"~/"+tempDiaryFile[0:tempDiaryFile.rfind("-temp")]+".ps" " 2> /dev/null")

		# Test it with xdvi.
		#os.system("xdvi "+tempDiaryFile+".dvi &> /dev/null")

		# Delete temporary files.
		os.system("rm "+tempDiaryFile+"* &> /dev/null")
		
		#self.scr.getch()
		self.errorMessage("File written!")



	def drawNextUpEntries(self, nextNDays=0):
		rows, cols = self.scr.getmaxyx()
		xpos=2
		ypos=4

		for i in range(nextNDays) :

			
			if ypos > rows-5:
				break
			
			viewtime = (datetime.datetime(self._cal.viewtime[0],self._cal.viewtime[1],self._cal.viewtime[2])+datetime.timedelta(days=i)).timetuple()
			entries=self._cal.getItems(viewtime)
			
			if entries!=None and len(entries) > 0:

				dateString = time.strftime(self._cal.dateformat,viewtime)
				dateString += " ("+self.friendlyDateTimeDelta(datetime.datetime(viewtime[0], viewtime[1], viewtime[2]) - datetime.datetime(self._cal.localtime[0],self._cal.localtime[1],self._cal.localtime[2]))+")"
				if i==0:
					self.addstr(ypos,xpos,dateString+":",curses.color_pair(2))
				else:
					self.addstr(ypos,xpos,dateString+":",curses.color_pair(3))

				ypos+=1
				
				for entry in entries:

					print ypos,xpos+1,entry

					self.drawEntry(ypos,xpos+1,entry,False)
					
					ypos+=1

				ypos+=1
				
				if ypos > rows-5:
					break

	def drawEntry(self,ypos,xpos,entry,selected,maxEntryLength=0):
		rows, cols = self.scr.getmaxyx()

		if not str(entry.__class__)=="__main__.ccalItem":
			entry=ccalItem(entry)

		
		if maxEntryLength==0:
			maxEntryLength = cols - 30
		decoration=curses.A_NORMAL

		try:
			entryDisplay = entry.entry[0:maxEntryLength]
		except:
			entryDisplay=entry.entry

		if hasattr(entry,"fullentry") and entry.fullentry!="":
			entryDisplay+=" (e)"


		if len(entry.entry) > maxEntryLength :
			entryDisplay += ".."

		if selected:
			decoration=decoration+curses.A_BOLD
		if entry.type==1:
			decoration=decoration+curses.color_pair(1)
		elif entry.type==2:
			decoration=decoration+curses.color_pair(2)
		elif entry.type==3:
			decoration=decoration+curses.color_pair(3)
		elif entry.type==4:
			decoration=decoration+curses.A_BLINK

		self.addstr(ypos,xpos,str(entryDisplay),decoration)


	def drawTodaysEntries(self):
		rows, cols = self.scr.getmaxyx()
		if self.mode==2:
			dateString="ToDo"		
		else:
			dateString = time.strftime(self._cal.dateformat,self._cal.viewtime)
		self.addstr(4,2,dateString+":",curses.color_pair(2))	
		entries=self._cal.getItems()	
		xpos=2
		ypos=5
		maxEntryLength = cols - 30
		num=0
		if entries!=None:
			for entry in entries:

				tentry = entry.entry.split(" ",1); # try to isolate the cal. prepend
				colind = 10+int(self.prependsa[tentry[0]]) # gives us index based on prepend string
				xskip = len(tentry[0])
				ltime_str = time.strftime("%H:%M", entry.time)
				#print entry.time # no pself here
				# tlog = logging.getLogger("ccal-0.6.1") 

				# tlog.debug( "%s %s %s", "----- drawTodaysEntries", str(entry.entry), ltime_str ) 				
				
				selected=False
				if num==self.selected and self.mode!=0:
					selected=True
				
				self.addstr(ypos,xpos+1,tentry[0],curses.color_pair(colind))
				self.addstr(ypos,xpos+2+xskip,ltime_str,curses.color_pair(3))
				self.drawEntry(ypos,xpos+2+xskip+6,ccalItem(tentry[1]),selected)

				ypos+=1
				num+=1

	def drawTodoSidebar(self):
		rows, cols = self.scr.getmaxyx()
		entries=self._cal.getItems("todolist")	
		xpos=cols-23
		ypos=15
		self.addstr(ypos-1,xpos,"Todo:",curses.A_BOLD)
		if entries!=None:
			for entry in entries:
				self.drawEntry(ypos,xpos,entry,False,maxEntryLength=16)
				ypos+=1
				if (ypos==(rows-2)):
					return


		
	
	def handleKey(self,char):
		if self.mode==0 or self.mode ==3:
			if char==ord("/"):
				self.setNewDate()
			if char==ord("a"):
				self.addNewEntry()
			if char==ord("n"):
				self._cal.setViewTimeToCurrent()
			if char==ord("p"):
				if self.pasteText!="":
					if str(self.pasteText.__class__)=="__main__.ccalItem":
						self._cal.addItem(copy.deepcopy(self.pasteText))
					else:
						self._cal.addItem(ccalItem(self.pasteText))

		if self.mode==0:
			if char==curses.KEY_LEFT:
				self._cal.setViewToPreviousDay()
				self.selected=0
			if char==curses.KEY_RIGHT:
				self._cal.setViewToNextDay()
				self.selected=0
			if char==curses.KEY_PPAGE:
				self._cal.setViewToPreviousMonth()
				self.selected=0
			if char==curses.KEY_NPAGE:
				self._cal.setViewToNextMonth()
				self.selected=0
			if char==curses.KEY_UP:
				self._cal.setViewToPreviousWeek()
				self.selected=0
			if char==curses.KEY_DOWN:
				self._cal.setViewToNextWeek()
				self.selected=0

			if char==ord("t"):
				self.previousMode=self.mode
				self.mode=2
				self.selected=0
				self._cal.todoList()
			if char==ord("u"):
				self.mode=3
				self.previousMode=self.mode
		elif self.mode == 3:
			if char==curses.KEY_UP:
				self._cal.setViewToPreviousUsedDay()
				self.selected=0
			if char==curses.KEY_DOWN:
				self._cal.setViewToNextUsedDay()
				self.selected=0

			if char==ord("u"):
				self.mode=0
			if char==ord("t"):
				self.previousMode=self.mode
				self.mode=2
				self._cal.todoList()


		else:
			if char==curses.KEY_UP:
				self.selectUP()
			if char==ord("a"):
				self.addNewEntry()

			if char==curses.KEY_DOWN:
				self.selectDOWN()
			if char==ord("d"):
				self.deleteSelected()
			if char==ord("0"):
				self.setItemTypeForSelected(0)
			if char==ord("1"):
				self.setItemTypeForSelected(1)
			if char==ord("2"):
				self.setItemTypeForSelected(2)
			if char==ord("3"):
				self.setItemTypeForSelected(3)
			if char==ord("4"):
				self.setItemTypeForSelected(4)
			if char==ord("e"):
				self.editSelected()
			if char==ord("y"):
				curses.beep()
				entries=self._cal.getItems()
				self.pasteText=entries[self.selected]
			if char==ord("p"):

				if self.pasteText!="":
					if str(self.pasteText.__class__)=="__main__.ccalItem":
						self._cal.addItem(copy.deepcopy(self.pasteText))
					else:
						self._cal.addItem(ccalItem(self.pasteText))


			if self.mode==2 and char==ord("t"):
				self.mode=self.previousMode
				self._cal.restorePreviousDate()
				
			
		if char==ord("q"):
			self.destroy()
			return 1
		if char==ord("s"):
			self._cal.saveDatabase()
		if char==ord("l"):
			self._cal.loadDatabase()
		if char==ord("b"):
			self._cal.toggleStorage()
		if char==ord("?"):
			self.displayHelp()
		if char==ord("i"):
			curses.echo()	
			rows, cols = self.scr.getmaxyx()
			self.addstr(rows-2,1,"Enter filename of iCal to import:")
			try:
				curses.curs_set(1)
			except:
				pass
			filename=str(self.scr.getstr(rows-1,1,50))
			self.addstr(rows-2,1,"Enter string to prepend in front of entries:")
			self.addstr(rows-1,1,"                                                                     ")
			prepend=str(self.scr.getstr(rows-1,1,50))
			try:
				curses.curs_set(0)
			except:	
				pass
			curses.noecho()
			#try:
			self._cal.importIcal(prepend,filename)
			#except Exception,e:
			#	self.addstr(rows-3,1,"Error importing iCal file - "+str(e))
			#	curses.beep()
			#	self.scr.refresh()
			#	time.sleep(2)
				
		if char==ord("E"):
			curses.echo()	
			rows, cols = self.scr.getmaxyx()
			self.addstr(rows-2,1,"Enter filename to export to:")
			try:
				curses.curs_set(1)
			except:
				pass
			filename=str(self.scr.getstr(rows-1,1,50))
			result=self._cal.exportIcal(filename)	
			if result!=None:
				curses.beep()
				self.addstr(rows-3,1,str(result))
			try:
				curses.curs_set(0)
			except:
				pass
			curses.noecho()

		if char==ord("x"):
			self.createEntriesPostscriptFile()


				
			
		if char==10:
			if self.mode==1:
				self.mode=self.previousMode
			else:
				if self.mode==2:
					self.mode=0
					self.mode=self.previousMode
					self._cal.restorePreviousDate()
				else:	
					self.previousMode=self.mode
					self.mode=1
					
	
	def displayHelp(self):
		self.scr.clear()
		rows, cols = self.scr.getmaxyx()

		self.addstr(1,1,"Global commands:",curses.color_pair(2))
		self.addstr(2,1,"s - saves database")
		self.addstr(3,1,"l - loads database")
		self.addstr(4,1,"b - changes backing store")
		self.addstr(5,1,"i - imports external calendar")
		self.addstr(6,1,"E - exports calendar")
		self.addstr(7,1,"q - quits")

		self.addstr(1,40,"Mode switches:",curses.color_pair(2))
		self.addstr(2,40,"t - toggles todo mode")
		self.addstr(3,40,"u - toggles up next mode")
		self.addstr(4,40,"Enter - toggles Entry/date mode")

		self.addstr(9,1,"Date mode keys:",curses.color_pair(2))
		self.addstr(10,1,"left, right - previous,next day")
		self.addstr(11,1,"up, down - previous, next month")
		self.addstr(12,1,"n - move calendar to now")
		self.addstr(13,1,"/ - move to specific date")
		self.addstr(14,1,"a - add an entry to the current date")
		self.addstr(15,1,"p - paste to the current date")
		
		self.addstr(9,40,"Up-next mode keys:",curses.color_pair(2))
		self.addstr(10,40,"up,down - scroll up/down through entries")
		self.addstr(11,40,"enter - edit selected day's appointments")
		self.addstr(12,40,"n - move view to now")
		self.addstr(13,40,"/ - move to specific date")
		self.addstr(14,40,"a - add an entry to the current date")
		self.addstr(15,40,"p - paste to the current date")


		self.addstr(17,1,"Entry & Todo mode keys:",curses.color_pair(2))
		self.addstr(18,1,"p - paste")
		self.addstr(19,1,"y - copy selected entry")
		self.addstr(20,1,"d - cut/delete selected entry")
		self.addstr(20,40,"e - edit selected entry in editor")
		self.addstr(21,1,"a - add an entry")
		self.addstr(21,40,"0-3 - change colour of entry")
		self.addstr(rows-1,(cols/2)-13,"Press any key to continue")

		self.scr.refresh()
		char=self.scr.getch()


	def addNewEntry(self):
		curses.echo()	
		rows, cols = self.scr.getmaxyx()
		self.addstr(rows-2,1,"Please enter an item to add:")
		try:
			curses.curs_set(1)
		except:
			pass
		entry=str(self.scr.getstr(rows-1,1,50))
		fullentry=""	

		# if it's a longer editor-based entry then launch an editor
		import time
		temptime=str(int(time.time()))
		if entry=="e":
			try:
				curses.curs_set(0)
			except:
				pass

			os.system(self.editor+" "+self.temppath+"/"+temptime)
			tempfile=open(self.temppath+"/"+temptime)
			tempstring=tempfile.read()
			templines=tempstring.split("\n")
			entry=templines[0]
			
			#re-initialise stuff as vim seems to mess it up
			self.scr=curses.initscr()
			self.scr.keypad(1)
			self.scr.clear()
			self.drawTitleBar()
			self.drawEntries()
			self.drawMode()
			if self.mode!=2:
				self.drawCalendar()
				self.drawTodoSidebar()
			try:
				self.scr.move(23,0)
			except Exception,e:
				self.handleException(e)
			#refresh
			self.scr.refresh()
			fullentry=templines[1:]
		
		try:
			curses.curs_set(0)
		except:
			pass
		if entry!="":
			self._cal.addItem(ccalItem(entry,fullentry=fullentry))
		curses.noecho()
		

	def setNewDate(self):
		rows, cols = self.scr.getmaxyx()
		self.addstr(rows-2,1,"Enter date in DD/MM/YYYY Format")
		curses.echo()
		date=self.scr.getstr(rows-1,1,10)
		try:
			day=int(date[0:2])
			month=int(date[3:5])
			year=int(date[6:10])
			curses.noecho()
			self._cal.setViewTime(day,month,year)
		except Exception:
			pass

	def editSelected(self):
		#if it has text already then 
		try:
			entry=self._cal.getItems()[self.selected]
			if not str(entry.__class__)=="__main__.ccalItem":
				entry=ccalItem(entry)

			import time
			temptime=str(int(time.time()))
			tempfile=open(self.temppath+"/"+temptime,"w")
			tempfile.write(entry.entry+"\n")

			if hasattr(entry,"fullentry") and entry.fullentry!="":
				for line in entry.fullentry:
					tempfile.write(str(line)+"\n")
			tempfile.close()
			try:
				curses.curs_set(1)
			except:
				pass
			os.system(self.editor+" "+self.temppath+"/"+temptime)

			tempfile=open(self.temppath+"/"+temptime)
			tempstring=tempfile.read()
			templines=tempstring.split("\n")

			entry.entry=templines[0]

			if templines[len(templines)-1]=="":
				entry.fullentry=templines[1:-1]
			else:
				entry.fullentry=templines[1:]

			
			
			if entry.fullentry==[]:
				entry.fullentry=""
				
			self.scr=curses.initscr()
			try:	
				curses.curs_set(1)
				curses.curs_set(0)
			except:
				pass
			self.scr.keypad(1)
			self.scr.clear()
	
		except:
			self.errorMessage("Can't edit this entry!")

class ccalItem:
	def __init__(self,entry,time=0,duration=0,fullentry=""):
		self.entry=entry
		self.type=0
		self.time=time
		self.duration=0
		self.fullentry=fullentry
	



class Calendar:
	def __init__(self,parent):
		self.parent=parent
		self.path=os.path.expanduser("~")+"/.ccaldb"
		self.store={}
		self.dateformat="%A %d %b %Y"
		self.updateCurrentTime()
		self.setViewTimeToCurrent()
		self.previous=None
		self.useServerStorage=self.parent.useServerStorage

	def toggleStorage(self):
		self.useServerStorage=not self.useServerStorage

	def loadDatabase(self,withcurses=True):
		if self.parent.noUseDb:
			return

		if self.useServerStorage:
			if withcurses:
				self.parent.errorMessage("Loading remote database..")
			params = urllib.urlencode({'command':'get'})
			try:
				f=urllib2.urlopen(self.parent.cgiURL, params)
				data = f.read()
				pic=str(data).strip()
				if pic=="":
					self.store={}
				else:
					obj=pickle.loads(pic)
					self.store=obj
			except Exception:
				if withcurses:
					self.parent.errorMessage("Couldn't load remote database")
				else:
					print "Couldn't load remote database"
				self.toggleStorage()
				self.loadDatabase()
				return

		else:
			shelf=shelve.open(self.path)
			self.store={}
			for key in shelf.keys():
				self.store[key]=shelf[key]
			shelf.close()
				
	def importIcal(self,prepend,file):
		#dict=parseIcalFile("/home/hillman/dev/pdi/Bank32Holidays.ics")
		dict=parseIcalFile2(file, self)
		pself = self.parent
		oldlen = len(pself.prependsa)+1
		pself.prependsa[prepend] = oldlen # will serve as color index
		### if pself.dbglog: tlog = logging.getLogger("ccal-0.6.1") 
		### if pself.dbglog: tlog.debug( "%s %s", "----- start of importIcal", str(len(dict)) ) 
		i=1
		dlen = len(dict)
		for key in dict:
			### if pself.dbglog: tlog.debug(  i ) 
			preloadstr = "Loading " + prepend +": " + str(i) + "/" + str(dlen) + "\t\t\t\r" # 'preloader'
			# os.system("echo -e \"" + preloadstr + "\"")
			subprocess.call(['echo', '-n', '-e', preloadstr])
			self.viewtime=key
			#bprepend = chr(27)+"3"+str(icnum)+'m'+prepend+chr(27)+"[0m" #nope, cannot work
			try:
				# attempt also to colorize prepend based on i; for multiple icals - done elsewhere
				self.addItem(ccalItem(prepend + " " + (dict[key]), key)) # unicode here instead of str, else crashes
			except:
				### if pself.dbglog: tlog.debug( "%s %s", key, dict[key] ) 
				print key, dict[key] 
			i+=1
		### if pself.dbglog: tlog.debug( "%s %s %s", "end of importIcal: ", str(len(self.getItems() )), str(len(self.store)) ) 
		print "\r\n" # newline, for next preloader
		self.setViewTimeToCurrent()
	
	def exportIcal(self,filename):
		try:
			file=open(filename,"w")
		except Exception,e:
			return e
		ical=ICalendar()
		ical.addProperties([UnknownProperty('PRODID', '1234-50'), UnknownProperty('VERSION', '2.0'), UnknownProperty('CALSCALE', 'GREGORIAN')])

		for date in self.store:
			entry=self.store[date]
			date=date.strip("()")
			tuple=date.split(",")
			pos=0
			try:
				for item in tuple:
					item=item.strip()
					item=int(item)
					tuple[pos]=item
					pos+=1
				timestring=time.strftime("%Y%m%d",tuple)
			except Exception,e:
				pass
			for item in entry:
				event = ical.addComponent(VEvent())
				event.addProperties([UnknownProperty("DTSTART",timestring,value="DATE"),UnknownProperty("SUMMARY",item)])
		if self.store.has_key("todolist"):
			for todoitem in self.store["todolist"]:
				todo=ical.addComponent(VTodo())
				todo.addProperties([UnknownProperty("SUMMARY",todoitem),])
			
			
		ical.validate()	
		file.write(str(ical))
		file.close()
			

	def saveDatabase(self):
		if self.parent.noUseDb:
			return
		
		if self.useServerStorage:
			self.parent.errorMessage("Saving database remotely..")
			params = urllib.urlencode({'command':'store','pickle':pickle.dumps(self.store)})
			try:
				f=urllib2.urlopen(self.parent.cgiURL, params)
			except Exception:
				self.parent.errorMessage("Couldn't save remote database")
				self.toggleStorage()
				self.loadDatabase()
				return

			data = f.read()
			if data.strip()!="DONE":
				raise Exception("database wasn't saved by cgi script")
			self.parent.errorMessage("Saved ")
		else:
			shelf=shelve.open(self.path)
			for key in shelf.keys():
				del shelf[key]
			for key in self.store.keys():
				shelf[key]=self.store[key]
			shelf.close()


	def todoList(self):
		self.previous=self.viewtime
		self.viewdatestring="To-do list"
		self.viewtime="todolist"
		
	def addToImportList(self,item):
		shelf=shelve.open(self.path+"Imports")
		if shelf.has_key("importlist"):
			importlist=shelf["importlist"]
			importlist.append(item)
			shelf["importlist"]=importlist
		else:
			list=[item,]
			shelf["importlist"]=list
		shelf.close()


	
	def restorePreviousDate(self):
		self.viewtime=self.previous
		self.updateViewTimeString()

	def updateCurrentTime(self):
		self.localtime=time.localtime()
		self.currentdatestring=time.strftime(self.dateformat)

	def setViewTime(self,day,month,year):
		dt=datetime.datetime(year,month,day)
		self.viewtime=dt.timetuple()
		self.updateViewTimeString()
	
	def updateViewTimeString(self):
		self.viewdatestring=time.strftime(self.dateformat,self.viewtime)

	def setViewToNextDay(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])+datetime.timedelta(days=1)).timetuple()
		self.updateViewTimeString()

	def setViewToNextUsedDay(self):
		count=0
		viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])+datetime.timedelta(days=1)).timetuple()
		while not self.store.has_key(str(viewtime)) or len(self.store[str(viewtime)])==0:
			count+=1
			if count==100:
				curses.beep()
				break
			viewtime=(datetime.datetime(viewtime[0],viewtime[1],viewtime[2])+datetime.timedelta(days=1)).timetuple()
		if count!=100:
			self.viewtime=viewtime	
			self.updateViewTimeString()

	
	def setViewToPreviousUsedDay(self):
		count=0
		viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])-datetime.timedelta(days=1)).timetuple()
		while not self.store.has_key(str(viewtime)) or len(self.store[str(viewtime)])==0:
			count+=1
			if count==100:
				curses.beep()
				break
			viewtime=(datetime.datetime(viewtime[0],viewtime[1],viewtime[2])-datetime.timedelta(days=1)).timetuple()
		if count!=100:
			self.viewtime=viewtime	
			self.updateViewTimeString()
	
		
	def setViewToPreviousDay(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])-datetime.timedelta(days=1)).timetuple()
		self.updateViewTimeString()

	def setViewToNextMonth(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])+datetime.timedelta(days=30)).timetuple()
		self.updateViewTimeString()
		
	def setViewToPreviousMonth(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])-datetime.timedelta(days=30)).timetuple()
		self.updateViewTimeString()

	def setViewToNextWeek(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])+datetime.timedelta(days=7)).timetuple()
		self.updateViewTimeString()
		
	def setViewToPreviousWeek(self):
		self.viewtime=(datetime.datetime(self.viewtime[0],self.viewtime[1],self.viewtime[2])-datetime.timedelta(days=7)).timetuple()
		self.updateViewTimeString()

		
	def setViewTimeToCurrent(self):
		self.setViewTime(self.localtime[2],self.localtime[1],self.localtime[0])
		

	def destroy(self):
		self.saveDatabase()
		
	def update(self,viewtime=0):
		if viewtime==0:
			viewtime=self.viewtime
		self.store[str(viewtime)]=self.store[str(viewtime)]
		
	def readImports(self):
		path=os.path.expanduser("~")+"/.ccaldbImports"
		shelf=shelve.open(path)
		foundentry=False
		if shelf.has_key("importlist"):
			importlist=shelf["importlist"]
			while len(importlist)!=0:
				foundentry=True
				item=importlist.pop()	
				if not self.store.has_key("todolist"):
					self.store["todolist"]=[]

				list=self.store["todolist"]
				list.append(item)
				self.store["todolist"]=list
			shelf["importlist"]=importlist
			shelf.close()
		return foundentry

	def addItem(self,item):
		pself = self.parent
		### if pself.dbglog: tlog = logging.getLogger("ccal-0.6.1") 
		sviewtime = str(self.viewtime)
		frkeystr=self.getFirstRealKeyStr2(sviewtime) # all below were sviewtime
		if self.store.has_key(frkeystr):
			list=self.store[frkeystr]
			list.append(item)
			### if pself.dbglog: tlog.debug( "%s %s %s %s %s", "append", item[0:50], self.viewtime.tm_year, self.viewtime.tm_mon, self.viewtime.tm_mday )   #item,
			self.store[sviewtime]=list
		else:
			self.store[sviewtime]=[item,]
			### if pself.dbglog: tlog.debug( "%s %s %s %s %s", "not append", item[0:50], self.viewtime.tm_year, self.viewtime.tm_mon, self.viewtime.tm_mday ) 

	def getItems(self, viewtime=0):
		if viewtime == 0:
			viewtime = self.viewtime
		# print viewtime, type(viewtime)
		sviewtime= str(viewtime)
		if self.store.has_key(sviewtime):
			newlist=[]
			for item in self.store[sviewtime]:
				if str(item.__class__)!="__main__.ccalItem":
					item=ccalItem(item)
				newlist.append(item)	
			self.store[sviewtime]=newlist
			return self.store[sviewtime]
		else:
			if type (viewtime) == time.struct_time:
				frkeystr=self.getFirstRealKeyStr2(sviewtime) # was: viewtime instead of str(viewtime)
				if self.store.has_key(frkeystr):
					newlist=[]
					for item in self.store[frkeystr]:
						if str(item.__class__)!="__main__.ccalItem":
							item=ccalItem(item)
						newlist.append(item)	
					self.store[sviewtime]=newlist #was frkeystr
					return self.store[sviewtime]
			else:
				return None

	def timeTupleStringToDatetime(self, instring):
		return datetime.datetime.strptime(instring, "time.struct_time(tm_year=%Y, tm_mon=%m, tm_mday=%d, tm_hour=%H, tm_min=%M, tm_sec=%S, tm_wday=0, tm_yday=32, tm_isdst=-1)")
		
	def timeTupleStringToTimetuple(self, instring):
		# if there is difference in tm_yday=32, tm_isdst=-1, does not compute..
		inspl = instring.split( "tm_isdst" )

		tts = time.strptime(inspl[0], "time.struct_time(tm_year=%Y, tm_mon=%m, tm_mday=%d, tm_hour=%H, tm_min=%M, tm_sec=%S, tm_wday=%w, tm_yday=%j, ")
		
		# dsts = inspl[1].split("=")[1].split(")")[0]
		# tts.tm_isdst = int(dsts) # readonly attribute
		return tts 
		
	
	def getFirstRealKeyStr(self, intt):
		# intt is a generic key, a timetuple 
		# we convert back to timetuple, compare and we check for tm_year=, tm_mon=, tm_mday=,
		##intt = timeTupleStringToTimetuple(inkey)
		pself = self.parent
		### if pself.dbglog: tlog = logging.getLogger("ccal-0.6.1")  
		for skey in self.store:
			stt = self.timeTupleStringToTimetuple(skey)
			if intt.tm_year == stt.tm_year and intt.tm_mon == stt.tm_mon and intt.tm_mday == stt.tm_mday:
				### if pself.dbglog: tlog.debug( "%s %s %s %s %s %s %s" % ("getFirstRealKey", intt.tm_year, stt.tm_year, intt.tm_mon, stt.tm_mon, intt.tm_mday, stt.tm_mday ) ) 
				# since here stt.isdst may not be same from skey, do not return stt
				# return skey directly instead
				return skey
		return str(datetime.datetime(1000,01,01).timetuple()) #"not found"

	
	# however, getFirstRealKeyStr takes up resources; but the string is anyways:
	# time.struct_time(tm_year=2010, tm_mon=3, tm_mday=2, tm_hour=0, tm_min=0, tm_sec=0, tm_wday=1, tm_yday=61, tm_isdst=-1)
	# so just a substirng comparison up to third comma should do it
	def getFirstRealKeyStr2(self, inkey):
		# inkey is a generic key, a string representation of a timetuple 
		for skey in self.store:
			skeysub = skey[:skey.find(",", skey.find(",", skey.find(",")+1)+1)] #first substring
			inkeysub = inkey[:inkey.find(",", inkey.find(",", inkey.find(",")+1)+1)] #second substring
			if skeysub == inkeysub:
				# return skey directly instead
				return skey
		return str(datetime.datetime(1000,01,01).timetuple()) #"not found"
		
		
	def hasItems(self,day,month,year):
		# problem here; we check 
		# key = "time.struct_time(tm_year=2010, tm_mon=2, tm_mday=1, tm_hour=0, tm_min=0, tm_sec=0, tm_wday=0, tm_yday=32, tm_isdst=-1)"
		# but events are entered as key:
		# key = "time.struct_time(tm_year=2010, tm_mon=2, tm_mday=1, tm_hour=13, tm_min=0, tm_sec=0, tm_wday=0, tm_yday=32, tm_isdst=0)" Workshop
		# so of course events will not match - better to loop through keys of store, check substring, if match get actual key, then retrieve
		pself = self.parent
		### if pself.dbglog: tlog = logging.getLogger("ccal-0.6.1") 
		try:
			dt=datetime.datetime(year,month,day)
			key=dt.timetuple()
			frkeystr=self.getFirstRealKeyStr2(str(key))
		except Exception,e:
			print e
			sys.exit()
		ks=""
		if self.store.has_key(frkeystr):
			ks=str( len(self.store[frkeystr]) ) # this can cause KeyError, if key cannot be found
		# tlog.debug( "%s %s %s %s %s %s %s" % ("hasItems", day, month, year, str(frkey), self.store.has_key(str(frkey)), str(key), ks) ) # TypeError: not all arguments converted during string formatting
		### if pself.dbglog: tlog.debug( "%s %s %s %s %s %s %s" % ("hasItems", day, month, year, self.store.has_key(frkeystr), ks, self.store.has_key(str(key)) ) ) 
		return (self.store.has_key(frkeystr) and len(self.store[frkeystr])!=0)
		
	def deleteItem(self,pos):
		try:
			if not self.store.has_key(str(self.viewtime)):
				return
			list=self.store[str(self.viewtime)]
			del list[pos]
			self.store[str(self.viewtime)]=list
		except Exception:
			pass
		

	def setItemType(self,pos,type):
		try:
			if not self.store.has_key(str(self.viewtime)):
				return
			list=self.store[str(self.viewtime)]
			list[pos].type=type
			self.store[str(self.viewtime)]=list
		except Exception:
			pass



CRLF = "\n"
RULE_MUST = 10
RULE_MAY = 20
RULE_RECOMMENDED = 30
RULE_NOT = 40

class ParseError(Exception):
    """If a parse error occurs there's a real problem in the data."""

    def __init__(self, compName, message, lineNumber):
        """
        @type   compName: string
        @param  compName: A string describing in what component this error occured.
        @type   message: string
        @param  message: A brief message explaining what went wrong.
        @type   lineNumber: number
        @param  lineNumber: On what line number the problem occured. This value can be fetched from a L{pdi.core.ParseError}.
        """
        Exception.__init__(self, "Parse error, %s, in component '%s' starting on line %s"%(message, compName, lineNumber))
        self.lineNumber = lineNumber

class ComponentError(Exception):
    """General component error class."""

    def __init__(self, compName, message, lineNumber):
        """
        @type   compName: string
        @param  compName: A string describing in what component this error occured.
        @type   message: string
        @param  message: A brief message explaining what went wrong.
        @type   lineNumber: number
        @param  lineNumber: On what line number the problem occured. This value can be fetched from a L{pdi.core.ParseError}.
        """
        Exception.__init__(self, "%s '%s' on line %s"%(message, compName, lineNumber))
        self.lineNumber = lineNumber

class MissingComponentError(ComponentError):
    """A mandatory component is missing."""
    def __init__(self, compName, subCompName, lineStart, lineEnd):
        """
        @type   compName: string
        @param  compName: A string describing in what component this error occured.
        @param  lineStart: The component that raised this exception starts on this line number.
        @param  lineEnd: The component that raised this exception ends on this line number.
        """
        Exception.__init__(self, "Mandatory component '%s' is missing in component '%s' on line %s to %s"
                           %(subCompName, compName, lineStart, lineEnd)
                           )
        self.lineNUmber = lineStart

class InvalidComponentError(ComponentError):
    """A component has been placed where it's not allowed to be."""
    def __init__(self, compName, lineNumber):
        """
        @type   compName: string
        @param  compName: A string describing in what component this error occured.
        @type   lineNumber: number
        @param  lineNumber: On what line number the problem occured. This value can be fetched from a L{pdi.core.ParseError}.
        """
        ComponentError.__init__(self, compName, "Invalid component", lineNumber)

class PropertyError(Exception):
    """All property related errrors should inherit from this class."""
    def __init__(self, message):
        """
        @type   message: string
        @param  message: A brief message describing what went wrong.
        """
        Exception.__init__(self, message)

class MissingPropertyError(PropertyError):
    """A mandatory property is missing."""
    def __init__(self, propertyName, compName, lineStart, lineEnd):
        """
        @type   propertyName: string
        @param  propertyName: A string describing what property is missing.
        @type   compName: string
        @param  compName: A string describing in what component this error occured.
        """
        PropertyError.__init__(self, "Missing mandatory property '%s' in component '%s' on lines %s to %s"
                               %(propertyName, compName, lineStart, lineEnd))

class PropertyValueError(PropertyError):
    """The value of the property is malformed or of unknown type. Either way, the value is invalid."""
    def __init__(self, property):
        """
        @type   property: L{pdi.core.Property}
        @param  property: The property that raised this exception.
        """
        PropertyError.__init__(self, "Invalid value for property '%s' on line %s"%(property.name, property.lineNumber))

class InvalidPropertyError(PropertyError):
    """The property is not allowed in that component."""
    def __init__(self, property):
        """
        @type   property: L{pdi.core.Property}
        @param  property: The property that raised this exception.
        """
        PropertyError.__init__(self, "Invalid property '%s' on line %s"%(property.name, property.lineNumber))

class InvalidPropertyValueError(PropertyError):
    """You tried to set an invalid value for the property."""
    def __init__(self, property, value):
        """
        @type   property: L{pdi.core.Property}
        @param  property: The property that raised this exception.
        @type   value: string
        @param  value: The invalid value.
        """
        PropertyError.__init__(self, "Invalid value '%s' for property '%s' on line %s"%(value, property.name, property.lineNumber))

class InvalidComponentWarning(UserWarning):
    """The component is not mandatory, recommended nor presumed (may)."""

class MissingComponentWarning(UserWarning):
    """The component is when recommended components are not found."""

class MissingPropertyWarning(UserWarning):
    """A recommended property is missing."""

class InvalidPropertyWarning(UserWarning):
    """A property that is not mandatory, recommended nor presumed (may) has been found or it has invalid syntax."""

class InvalidPropertyTypeWarning(UserWarning):
    """A property has a defined type that isn't registered."""

class InvalidPropertyContentWarning(UserWarning):
    """The content of the property is invalid according to the property's validation method."""

class Property(object):
    """All properties must inherit from this class. An instance of this class should be treated as an unknown property."""

    def __init__(self, name, content, value="", encoding="", type="", lineNumber = None):
        """
        @type   name: string
        @param  name: The name of this property (not type).
        @type   content: string
        @param  content: The raw content fetched directly from the input data.
        @type   encoding: string
        @param  encoding: The encoding used to store the raw content.
        @type   type: string
        @param  type: Type of content.
        @type   lineNumber: number
        @param  lineNumber: The line on which this property was found.
        """
        self.name = name
        self.content = content
        self.encoding = encoding
        self.type = type
        self.value = value
        self.lineNumber = lineNumber
        self.validate()

    def _validate(self, content):
        """
        Internal method for validation. Override this for your own validation.
        You should issue warnings in this method. Exceptions are disliked, if your value is really out
        of whack you may set it to None.

        @type   content: string
        @param  content: The raw content fetched from data.
        @rtype: boolean
        @return: None or zero if invalid value.
        """
        return 1

    def validate(self):
        """
        Validates the property content. Issues warnings.

        @rtype: boolean
        @return: None or zero if invalid content.
        """
        return self._validate(self.content)

    def invalidContent(self, message, content):
        """
        Issue warning.
        @type   message: string
        @param  message: Explaining why the content is invalid.
        @type   content: string
        @param  content: The invalid content.
        """
        warnings.warn("Invalid content '%s' for type '%s' in property '%s' on line %s: %s"
                      %(content, self.getType(), self.name, self.lineNumber, message),
                      InvalidPropertyContentWarning)

    def getContent(self):
        """
        Use this to fetch the content.
        @return: The content in it's correct form and type.
        """
        return self.content

    def setContent(self, content):
        """
        Use this to set the content. The content will be validated.
        @type   content: string
        @param  content: The data string content.
        """
        if not self._validate(content):
            raise InvalidPropertyContentError(property, content)
        self.content = content

    def __str__(self):
        """Serializes a property back to raw data."""
        ret = self.name
        if self.encoding:
            ret += ";ENCODING=" + self.encoding
        if self.type:
            ret += ";TYPE=" + self.type
        if self.value:
            ret += ";VALUE=" + self.value
        ret += ":" + self.content
        return ret

class UnknownProperty(Property):
    """Unknown type. All properties that doesn't specify a VALUE=TYPE are instansiated as this object."""

class TextProperty(Property):
    """A text-type property."""

class DateProperty(Property):
    """A date-type property. It should be an 8 digit number."""

    def _validate(self, content):
        """Makes sure this is readable UTF-8 text."""
        if len(content) != 8:
            self.invalidContent("must be 8 digit number", content)
            return None
        try:
            timestamp = int(self.content)
        except ContentError:
            self.invalidContent("may only contain numbers", content)
            return None
        return 1

class Component(object):
    """
    The mama of all components. Inherit from this class only if you intend to create a completely new standard.
    @ivar   begin: The line number where this component started. None if it never was started == very bad!
    @ivar   end: The line number where this component ended. None if it never was ended == very bad, will raise an exception.
    @ivar   properties: A dictionary of all properties where the uppercased name is the key and an instance of the property is the value.
    @ivar   propertiesMay: Internal list for keeping track of properties that may occur.
    @ivar   propertiesMust: Internal list for keeping track of mandatory properties.
    @ivar   propertiesNot: Internal list for keeping track of disallowed properties.
    @ivar   components: A list of all subcomponents under this component.
    @ivar   componentsMust: Internal list for keeping track of mandatory components.
    @ivar   componentsMay: Internal list for keeping track components that may occur.
    @ivar   componentsRecommended: Internal list for keeping track of recommended compoennts.
    @ivar   componentsNot: Internal list for keeping track of disallowed components.
    @ivar   parent: Internal instance of a L{pdi.core.Component} for keeping track of the parent.
    @ivar   ignoreWarnings: Set this baby to true to supress warnings.
    @ivar   classes: Internal dictionary for keeping track valid classes for components and properties.
    @ivar   componentTracker: Internal dictionary for keeping track of what subcomponent classes has been added.
    @ivar   propertiesRecommended: Internal list for keeping track of recommended properties.
    """

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        self.begin = None
        self.end = None
        self.properties = {}
        self.propertiesMay = []
        self.propertiesMust = []
        self.propertiesRecommended = []
        self.propertiesNot = []
        self.components = []
        self.componentsMust = []
        self.componentsMay = []
        self.componentsRecommended = []
        self.componentsNot = []
        self.parent = parent
        self.ignoreWarnings = True
        self.classes = {}
        self.componentTracker = []
        self.registerPropertyTypes({'UNKNOWN' : UnknownProperty,
                                    'DATE' : DateProperty,
                                    'TEXT' : TextProperty})

    def getName(self):
        """
        Return the name of this component. This is the uppercased class name unless an unknown component.
        @rtype: string
        @return: The components name (usually the uppercased class name, but not always). It has to be uppercased.
        """
        return self.__class__.__name__.upper()

    def parseLine(self, data, lineNumber):
        """
        This parses one line of data.
        @type   data: string
        @param  data: A line of data.
        @type   lineNumber: number
        @param  lineNumber: The line we are currently parsing. Needed for exceptions, warnings and debugging in general.
        @rtype: L{pdi.core.Component}        
        @return: The next component that needs parsing. Can be a child, parent or self.
        @raise  ParseError: Raised if parsed data is whack!
        @raise  ComponentError: Raised if a component is invalid. This probably indicates an internal error.
        @raise  InvalidComponentError: Raised if a disallowed component is found.
        @raise  MissingComponentError: Raised if a mandatory component is not found.
        @raise  InvalidPropertyError: Raised if a disallowed property is found.
        @raise  MissingPropertyError: Raised if a mandatory property is not found.
        @raise  PropertyValueError: Raised if a property fails to validate itself.
        """
        if data[0] in ' \t':
           if self.lastProperty:
               self.properties[self.lastProperty.name].value = self.properties[self.lastProperty.name].getContent() + CRLF + data[0:-1]
               return self
           else:
               raise ParseError(self.getName(), "displaced content line", lineNumber)
        unpack = data.split(":") # data.split(":",1) 
        #if len(unpack) != 2:
        #    raise ParseError(self.getName(), "invalid data", lineNumber)
        if len(unpack) == 1: #definitely fake, ignore
            return None
	try:
	        key, value = unpack
	except Exception,e:
		print e, unpack
		try:
			key,value,other=unpack
		except Exception,e:
			print e, unpack	
			unpack = data.split(":",1) 
			key, value = unpack
			
        return self.interpret(key.upper().strip(), value.strip(), lineNumber)

    def interpret(self, key, value, lineNumber = -1):
        """Interprets a symbol and value."""
        if key == "BEGIN":
            if value.upper() == self.getName() and not self.begin:
                self.begin = lineNumber
                return self
            subcomponent = None
            for available in self.componentsMay + self.componentsMust + self.componentsRecommended:
                if value.upper() == available:
                    if self.classes.has_key(available):
                        subcomponent = self.classes[available](self)
                    else:
                        self.ComponentError("Internal error, component not found in class dictionary", available, lineNumber)
            if not subcomponent:
                subcomponent = VUnknown(value, self)
            subcomponent.interpret(key, value)
            self.addComponent(subcomponent, lineNumber)
            return subcomponent
        elif key == "END":
            if value.upper() == self.getName():
                self.end = lineNumber
                self._validate(None, lineNumber)
                return self.parent
            raise ParseError(self.getName(), "expected 'END:" + self.getName() + "', but found 'END:" + value + "'", lineNumber)
        else:
            unpack = key.split(";")
            propertyClass = UnknownProperty
            propertyName = key.upper()
            propertyType = None
            propertyValue = None
            propertyEncoding = None
            if len(unpack) > 1:
                propertyName = unpack[0].upper()
                del unpack[0]
                for unpacked in unpack:
                    unpack2 = unpacked.split("=")
                    if len(unpack2) == 2:
                        if unpack2[0].upper() == "VALUE":
                            if self.classes.has_key("TYPE_" + unpack2[1].upper()):
                                propertyClass = self.classes["TYPE_" + unpack2[1].upper()]
                                propertyValue = unpack2[1].upper()
                        elif unpack2[0].upper() == "ENCODING":
                            propertyEncoding = unpack2[1]
                        elif unpack2[0].upper() == "TYPE":
                            propertyType = unpack2[1]
                    else:
                        propertyName += ";" + unpacked.upper()
            self.addProperty(propertyClass(propertyName, value, propertyValue, propertyEncoding, propertyType, lineNumber), lineNumber)
        if self.begin:
            return self
        return self.parent

    def registerComponents(self, componentList, rule = RULE_MAY):
        """
        Register all valid (or invalid, depending on rule) components.
        All components that are supposed to be valid should be registered with this method, otherwise they
        become instances of UnknownComponent.
        
        @type   componentList: list
        @param  componentList: A list with L{pdi.core.Component} derived classes that are valid (or invalid).
        @type   rule: number
        @param  rule: A pdi.core.RULE_MUST, pdi.core.RULE_MAY, pdi.core.RULE_RECOMMEND or pdi.core.RULE_NOT.
        """
        for component in componentList:
            if rule != RULE_NOT:
                self.classes[component.__name__.upper()] = component
            if rule == RULE_MUST:
                self.componentsMust.append(component.__name__.upper())
            elif rule == RULE_MAY:
                self.componentsMay.append(component.__name__.upper())
            elif rule == RULE_RECOMMENDED:
                self.componentsRecommended.append(component.__name__.upper())
            elif rule == RULE_NOT:
                self.componentsNot.append(component.__name__.upper())
            else:
                raise ValueError("Second argument must be RULE_<?> value")

    def registerProperties(self, propertyList, rule = RULE_MAY):
        """
        Register valid (or invalid, depending on rule) properties.

        @type   propertyList: list
        @param  propertyList: A list of strings containing the uppercased names of the properties.
        @type   rule: number
        @param  rule: A pdi.core.RULE_MUST, pdi.core.RULE_MAY, pdi.core.RULE_RECOMMEND or pdi.core.RULE_NOT.
        """
        for property in propertyList:
            if rule == RULE_MUST:
                self.propertiesMust.append(property.upper())
            elif rule == RULE_MAY:
                self.propertiesMay.append(property.upper())
            elif rule == RULE_RECOMMENDED:
                self.propertiesRecommended.append(property.upper())
            elif rule == RULE_NOT:
                self.propertiesNot.append(property.upper())
            else:
                raise ValueError("Second argument must be RULE_<?> value")

    def registerPropertyTypes(self, propertyTypes):
        """
        Register available property types. Properties without a type or a type that has not been registered will
        be instansiated as UnknownProperty.

        @type   propertyTypes: list
        @param  propertyTypes: A list of L{pdi.core.Property} derived classes.
        """
        for propertyType in propertyTypes.keys():
            self.classes["TYPE_" + propertyType] = propertyTypes[propertyType]

    def addComponents(self, componentList):
        """
        Candy method for adding several components at one time.

        @type   componentList: list
        @param  componentList: A list of L{pdi.core.Component} instances.
        @raise  InvalidComponentError: If any subcomponent you tried to add is not valid for the component.
        """
        for comp in componentList:
            self.addComponent(comp)

    def addProperties(self, propertyList):
        """
        Candy method for adding several properties at one time.

        @type   propertyList: list
        @param  propertyList: A list of L{pdi.core.Property} instances.
        @raise  InvalidPropertyError: If any property you tried to add is not valid for the component.
        """
        for prop in propertyList:
            self.addProperty(prop)

    def addComponent(self, component, lineNumber = None):
        """
        Add a subcomponent to this component.

        @type   component: L{pdi.core.Component}
        @param  component: The subcomponent to add.
        @type   lineNumber: number
        @param  lineNumber: The line currently parsed. Used internally when parsing files. May be omitted or None.
        @rtype:  L{pdi.core.Component}
        @return: The subcomponent you just added.
        @raise  InvalidComponentError: If the subcomponent you tried to add is not valid for the component.
        """
        self.components.append(component)
        if not component.getName() in self.componentTracker:
            self.componentTracker.append(component.getName())
        for comp in self.componentsNot:
            if comp in self.componentTracker:
                raise InvalidComponentError(prop, lineNumber)
        return component

    def addProperty(self, property, lineNumber = None):
        """
        Add a property to this component. The property will also be validated and warnings issued
        as the property implementation sees fit.

        @type   property: L{pdi.core.Property}
        @param  property: The property to add.
        @type   lineNumber: number
        @param  lineNumber: The line currently parsed. Used internally when parsing files. May be omitted or None.
        @rtype:  L{pdi.core.Property}
        @return: The property you just added.
        @raise  InvalidPropertyError: If the property you tried to add is not valid for the component.
        """
        self.properties[property.name.upper()] = property
        property.validate()
        self.lastProperty = property
        for prop in self.properties.keys():
            if prop in self.propertiesNot:
                raise InvalidPropertyError(prop, lineNumber)
        return property

    def validate(self, lineNumber = None):
        """
        This will make sure that all mandatory components and properties are present.
        The validation is recursive, so you only need to call it for the top component.

        @type   lineNumber: number
        @param  lineNumber: The line currently parsed. Used internally when parsing files. May be omitted or None.
        @raise  MissingComponentError: A mandatory component is missing.
        @raise  MissingPropertyError: A mandatory property is missing.
        """
        self._validate(1, lineNumber)

    def _validate(self, recursive, lineNumber = None):
        """
        Internal method for validating components.

        @type   recursive: boolean
        @param  recursive: If true, itterate recursevly over subcomponents as well.
        @type   lineNumber: number
        @param  lineNumber: The line currently parsed. Used internally when parsing files. May be omitted or None.
        @raise  MissingComponentError: A mandatory component is missing.
        @raise  MissingPropertyError: A mandatory property is missing.
        """
        for comp in self.componentsMust:
            if not comp in self.componentTracker:
                raise MissingComponentError(self.getName(), comp, self.begin, self.end)
        for prop in self.propertiesMust:
            if not self.properties.has_key(prop):
                raise MissingPropertyError(prop, self.getName(), self.begin, self.end)
        if recursive:
            for comp in self.components:
                comp._validate(recursive, lineNumber)
        
    def __str__(self):
        """Serialize this component as well as it's properties and subcomponents."""
        ret = "BEGIN:" + self.getName() + CRLF
        for key in self.properties.keys():
            ret = ret + self.properties[key].__str__() + CRLF
        for child in self.components:
            ret = ret + child.__str__()
        ret = ret + "END:" + self.getName() + CRLF
        return ret

class VUnknown(Component):
    """
    This class is used for all components that do not have their own classes registered.
    """

    def __init__(self, name, parent = None):
        """
        @type   name: string
        @param  name: The name of the component is required since it doesn't provide it through the class name.
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(VUnknown, self).__init__(parent)
        self.name = name        

    def getName(self):
        """
        Returns the name provided on instansiation rather than the uppercased class name due to the fact
        that the component is of unknown type.
        @rtype: string
        @return: The components name (usually the uppercased class name, but not always).
        """
        return self.name






def fromFile(fileName, inObject, bufferSize = 4096):
    """
    Opens a file and parses it line by line.
    If nothing unexpected happens the inObject will be populated and returned.

    @param  fileName: The name of the file to read from.
    @param  inObject: An instance of a L{pdi.core.Component} to populate.
    @param  bufferSize: The read buffer and maximum size per line. Default is 4k.
    @rtype: L{pdi.core.Component}
    @return:    The same instance of pdi.core.Component passed in as the second argument, only populated.
    """
    currentObject = inObject
    fObj = open(fileName)
    line = fObj.readline(bufferSize)
    lineNum = 0
    while line and currentObject:   
        lineNum += 1
        currentObject = currentObject.parseLine(line, lineNum)
        line = fObj.readline(bufferSize)
    fObj.close()    
    return inObject

def fromStrings(list, inObject):
    """
    Itterates over a list of strings and parses them.
    If nothing unexpected happens the inObject will be populated and returned.

    @param  list: A list with strings.
    @param  inObject: An instance of a L{pdi.core.Component} to populate.
    @rtype: L{pdi.core.Component}
    @return:    The same instance of pdi.core.Component passed in as the second argument, only populated.
    """
    currentObject = inObject
    lineNum = 0
    for line in list:    
        lineNum += 1
        currentObject = currentObject.parseLine(line, lineNum)
    return inObject

def fromString(data, inObject, crlf = "\n"):
    """
    Splits a string on CRLF's and parses them.
    If nothing unexpected happens the inObject will be populated and returned.

    @type   data: string
    @param  data: A string containing the data.
    @type   inObject: L{pdi.core.Component}
    @param  inObject: An instance of a pdi.core.Component.
    @type   crlf: string
    @param  crlf: Split on this substring.
    @rtype: L{pdi.core.Component}
    @return:    The same instance of pdi.core.Component passed in as the second argument, only populated.
    """
    unpack = data.split(crlf)
    return fromStrings(unpack)



class VCalendar(Component):
    """The base of ICalendar component. Use ICalendar instead if you want RFC2445 compliancy!"""

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(VCalendar, self).__init__(parent)
        self.registerComponents([VEvent, VTodo, VJournal], RULE_MAY)
        self.registerComponents([VCalendar], RULE_NOT)
        self.registerProperties(['PRODID', 'VERSION'], RULE_MUST)

class VEvent(Component):
    """Event component, sub-component to VCalendar."""

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(VEvent, self).__init__(parent)
        #self.registerProperties(['UID', 'SUMMARY'], RULE_MUST)
        self.registerProperties(['SUMMARY'], RULE_MUST)
        self.registerComponents([VEvent], RULE_NOT)
        self.registerProperties(['DTSTAMP',
                                 'DTSTART',
                                 'RRULE',
                                 'DTEND'
                                 ], RULE_MAY)

class VTodo(Component):
    """Todo component, sub-component to VCalendar."""

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(VTodo, self).__init__(parent)
        self.registerComponents([VTodo], RULE_NOT)

class VJournal(Component):
    """Journal component, sub-component to VCalendar. This is not a stand-alone component!"""

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(VJournal, self).__init__(parent)
        self.registerComponents([VJournal], RULE_NOT)

class ICalendar(VCalendar):
    """This is supposed to be the RFC2445 compliant iCalendar component."""

    def __init__(self, parent = None):
        """
        @type   parent: L{pdi.core.Component}
        @param  parent: The parent component, if any. May be omitted or None if it is a top-level component.
        """
        super(ICalendar, self).__init__(parent)
        self.registerComponents([VJournal], RULE_MAY)
        self.registerComponents([ICalendar], RULE_NOT)
        self.registerProperties(['CALSCALE'], RULE_MAY) # was RULE_MUST
        self.registerProperties(['X-WR-CALNAME',
                                 'X-WR-RELCALID',
                                 'X-WR-TIMEZONE'
                                 ], RULE_MAY)

    def getName(self):
        """
        Because of the crappy iCalendar standard still uses VCALENDAR sections, pretend the name is VCALENDAR.
        @rtype: string
        @return: A constant string 'VCALENDAR'.
        """
        return "VCALENDAR"






def parseIcalFile(file):
	timetupledict={}
	calendar=fromFile(file,ICalendar())
	
	for event in calendar.components:
		if event.getName()=="VEVENT":
			try:
				start=event.properties["DTSTART"].getContent()
				print start
			except:
				print event
				start="20000101" # fake date

			#end=event.properties["DTEND"]
			summary=event.properties["SUMMARY"].getContent()

			timeparts=start.split("T")
			date=timeparts[0]
			if len(timeparts)==2:
				time=timeparts[1]
				summary+=" at "+time[0:4]
			year=int(date[0:4])
			month=int(date[4:6])
			day=int(date[6:8])
			timetupledict[datetime.datetime(year,month,day).timetuple()]=summary
	return timetupledict
			


def optimal_encode(st):
	for encoding in ['ascii','iso-8859-1','iso-8859-15','utf-8']:
		try:
			#return (encoding, st.encode(encoding))
			return st.encode(encoding)
		except UnicodeEncodeError:
			pass
		#print st
		raise UnicodeError, 'Could not find encoding'

# http://mxm-mad-science.blogspot.com/2008_03_01_archive.html
def parseIcalFile2(infile, rself):
	timetupledict={}
	pself = rself.parent
	### if pself.dbglog: tlog = logging.getLogger("ccal-0.6.1") 
	#calendar=fromFile(file,ICalendar())
	#f = resource_stream(__name__, infile) # seems resourcestream can only reference local files.. 
	f = open(infile)
	#vrc = vobject.readComponents(f)
	#print 'got icals: ' + str(len(vrc))
	#print "parse self", __name__ # here its main
	for ical in vobject.readComponents(f):
		### if pself.dbglog: tlog.debug( 'got vevents: ' + str(len(ical.vevent_list)) ) 
		i = 0       
		while i < len(ical.vevent_list):
			### if pself.dbglog: tlog.debug(  i  ) 
			vevent = ical.vevent_list[i]
			#print vevent, (vevent == None)
			if not hasattr(vevent, 'dtstart'):
				start= datetime.datetime(2000,01,01) # "20000101"
				### if pself.dbglog: tlog.debug( "%d %s",  i, 'no dtstart' ) 
			else:
				start = vevent.dtstart.value 
			if not hasattr(vevent, 'summary'):
				summary="NO-SUMMARY"
				### if pself.dbglog: tlog.debug( "%d %s", i, 'no summary' ) 
			else:
				summary = unicode(vevent.summary.value) #just in case
			
			# in vobject, start is already a datetime
			'''
			timeparts=start.split("T")
			date=timeparts[0]
			if len(timeparts)==2:
				time=timeparts[1]
				summary+=" at "+time[0:4]
			year=int(date[0:4])
			month=int(date[4:6])
			day=int(date[6:8])
			timetupledict[datetime.datetime(year,month,day).timetuple()]=summary
			'''
			timetupledict[start.timetuple()]=summary
			i += 1
	return timetupledict

#try:
c=CursesCal()
c.main()
#except Exception,e:
	#try:
		#curses.nocbreak()
		#curses.echo()
		#curses.endwin()
		#if str(e.__class__)!="exceptions.KeyboardInterrupt":
		#	print repr(e)
	#except:
	#	print repr(e)




