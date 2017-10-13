#!/usr/bin/env python 

# execfile(filename)

# http://stackoverflow.com/questions/88613/how-do-i-split-a-string-into-a-list-python
# http://pyparsing.wikispaces.com/ (sourceforge)
# http://www.php2python.com/wiki/function.explode/ = split by string
# http://www.wellho.net/solutions/python-python-list-python-tuple-python-dictionary.html
# http://effbot.org/zone/python-list.htm
# http://docs.python.org/library/string.html#format-examples
#~ >>> sf = string.Formatter()
#~ >>> sfi = sf.parse('as ; %d { ew }') ; a1 = sfi.next() ; print a1; a2 = sfi.next() ; print a2
#~ ('as ; %d ', ' ew ', '', None)
#~ Traceback (most recent call last):   File "<stdin>", line 1, in <module> StopIteration 
# dictionary:
#~ st = {"name1":0, "name2":0}; 
#~ >>> print st
#~ {'name2': 0, 'name1': 0}
#~ >>> print st.keys()
#~ ['name2', 'name1']
#~ >>> print st.keys()[0]
#~ name2
# regex
#~ >>> print re.compile(r'.*b').match('    baba [ _ : , -').group(0)
	#~ bab


import sys
import os
import atexit


# SO 88613: parse tokenizer..  - per character; but maybe, per word too? 
# for tokentype, literal in tokenize(st): print tokentype, "----", literal
# print re.compile('\W+').match(st).group(0)
import re

#~ patterns = [
	#~ ('number', re.compile('\d+')),
	#~ ('*', re.compile(r'\*')),
	#~ ('/', re.compile(r'\/')),
	#~ ('+', re.compile(r'\+')),
	#~ ('-', re.compile(r'\-')),
#~ ]
patterns = [
	('timestamp', re.compile(r'''.*\[ (.*)\]'''), 1),
	('tmr_fnc', re.compile(r'.*?tmr_fnc:(\d*)'), 1), # .*? non-greedy.. , don;t use (.*?) - ? misses
	('bWr', re.compile(r'''.*?bWr:(\d*)'''), 1),
	('bsl', re.compile(r'.*?bsl:(\d*)'), 1),
	('pbpos', re.compile(r'.*?pbpos:\W*(\d*)'), 1), # again, no \W* here..
	('irqps', re.compile(r'.*?irqps:\W*(\d*)'), 1),
	('hd', re.compile(r'.*?hd:\W*(\d*)'), 1),
	('tl', re.compile(r'.*?tl:\W*(\d*)'), 1),
	('sz', re.compile(r'.*?sz:\W*(\d*)'), 1),
	('tlR', re.compile(r'.*?tlR:\W*(\d*)'), 1),
	('Wrp', re.compile(r'.*?Wrp:\W*(\d*-\d*)'), 1),
]
whitespace = re.compile('\W+')

def tokenize(string):
	
	#~ while string:
		
		# strip off whitespace - only at start, don't need it, strips my [
		#~ m = whitespace.match(string)
		#~ if m:
			#~ string = string[m.end():]
		
		#~ print m
		
		for tokentype, pattern, grp in patterns:
			m = pattern.match(string)
			#~ print tokentype, pattern, grp, m
			#~ print string
			if m:
				yield tokentype, m.group(grp)
				string = string[m.end():] # if the string is cut, less work next loop 


# both dictionary of words to be parsed - and also a holder for values
# line is:  
st="[ 1644.672042] :  tmr_fnc: bWr:0 bsl:176 pbpos: 176, irqps: 176, hd: 0, tl: 0, sz: 131072, tlR: 0, hdW: 0, Wrp: 0-0"
# initword = "tmr_fnc" # consider dict ordered, will be holder for string values
wordictobj = {
	"tmr_fnc":"",
	"bWr":"",
	"bsl":"",
	"pbpos":"",
	"irqps":"",
	"hd":"",
	"tl":"",
	"sz":"",
	"tlR":"",
	"Wrp":"",
}

# curval - parsed values; last entry will be timestamp
curval = {
	"tmr_fnc":0,
	"bWr":0,
	"bsl":0,
	"pbpos":0,
	"irqps":0,
	"hd":0,
	"tl":0,
	"sz":0,
	"tlR":0,
	"WrpA":0,
	"WrpB":0,
	"timestamp":0,
}


# ### ENTRY

for tokentype, literal in tokenize(st): 
	print tokentype, "----", literal

print st 
