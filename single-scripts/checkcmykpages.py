#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Sat May  9 21:01:57 CEST 2015 ; Python 2.7.1+

import sys
import os
import os.path
import argparse
import subprocess

#~ GSPROG="gs" # must be gs > 9.05 !
GSPROG="gs-916-linux_x86"

parser = argparse.ArgumentParser(description='Check CMYK content of pages in a PDF file.')
parser.add_argument("infile")

def printwrite(instr):
  with open('cmykpgreport.txt', 'a') as the_file:
    the_file.write('{0}\n'.format(instr))
  print(instr)

def main(argv):
  args = parser.parse_args() # will auto exit
  absflpath = os.path.abspath(args.infile)
  if not(os.path.isfile(absflpath) and os.access(absflpath, os.R_OK)):
    print("Cannot find requested PDF file: {0}".format(args.infile))
    sys.exit(2)

  printwrite("Processing PDF file: {0}".format(absflpath))

  datestart = subprocess.check_output(["date"])
  printwrite("GS started on: {0}".format(datestart))

  cmdA = [GSPROG, '-q', '-o', '-', '-sDEVICE=inkcov', absflpath]
  printwrite(" ".join(cmdA))

  numpg = 0
  allpgs = []
  colrpgs = []
  bwpgs = []
  blankpgs = []
  p = subprocess.Popen(cmdA, stdout=subprocess.PIPE)
  while p.poll() is None:
    l = p.stdout.readline() # This blocks until it receives a newline.
    if "CMYK" in l:
      la = l.split()
      numpg += 1
      la.insert(0, numpg)
      allpgs.append(la)
      bwORcolor = ""
      # if C,M,Y components are 0, then it is bw
      if len(la) >= 4:
        if (float(la[1])+float(la[2])+float(la[3]) == 0.0):
          if (float(la[4]) == 0.0):
            bwORcolor = "blank"
            blankpgs.append(la)
          else:
            bwORcolor = "b/w"
            bwpgs.append(la)
        else:
          bwORcolor = "color"
          colrpgs.append(la)
      #~ sys.stdout.write(l) # instead of print, which adds extra \n
      print("{0}; {1}".format(la,bwORcolor))
  # When the subprocess terminates there might be unconsumed output
  # that still needs to be processed.
  print p.stdout.read()

  dateend = subprocess.check_output(["date"])

  # extract pg number - column zero in both pgs (2D) arrays; using list comprehension
  idscolpgs = [item[0] for item in colrpgs]
  idsbwpgs = [item[0] for item in bwpgs]
  idsblankpgs = [item[0] for item in blankpgs]

  # can't just use ",".join(idscolpgs), because idscolpgs is list of ints;
  # and join needs strings!
  strout = """Stats:
  Num. CMYK color pages: {0}
  Color pages are: {1}
  Num. K b/w pages: {2}
  B/w pages are: {3}
  Num. blank pages: {4}
  Blank pages are: {5}
  """.format( len(idscolpgs), ",".join(map(str,idscolpgs)), len(idsbwpgs), ",".join(map(str,idsbwpgs)), len(idsblankpgs), ",".join(map(str,idsblankpgs)) )
  printwrite(strout)
  printwrite("GS ended on: {0}\n".format(dateend))

if __name__ == "__main__":
  main(sys.argv[1:])
