#!/usr/bin/env python
################################################################################
# csv_normalize_cols.py                                                        #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

"""
# Copyleft 2014, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE
"""

# test w:
# python code/alsa-tests/csv_normalize_cols.py /media/disk/tmp/alsa-capttest/collectmirq_both.csv > code/alsa-tests/data/collectmirq_both_n.csv

import sys, os, os.path
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

import csv

# first command line argument is .csv file name to open
if len(sys.argv) > 1:
  infilename = os.path.realpath(sys.argv[1])
else:
  print("Need the first command line option to be a path to a file; exiting\n")
  sys.exit(1)

if not(os.path.isfile(infilename)):
  print("The file {0} is not a valid file\n".format(infilename))
  sys.exit(1)

"""
don't use print (complication with __future__);
a custom function based on sys.stdout.write works
for both Python 2.7 and 3.x
"""
def printso(*inargs):
  outstr = ""
  #for inarg in inargs:
  #  outstr += str(inarg) + " "
  #outstr += "\n"
  outstr = " ".join(list(map(str, inargs)))
  sys.stdout.write(outstr)
  sys.stdout.flush()

def printse(*inargs):
  outstr = ""
  #for inarg in inargs:
  #  outstr += str(inarg) + " "
  #outstr += "\n"
  outstr = " ".join(list(map(str, inargs)))
  sys.stderr.write(outstr)
  sys.stderr.flush()

printse("Input file: {0}\n".format(infilename))

ifile  = open(infilename, "rb")
csvreader = csv.reader(ifile) #, delimiter=',', quotechar='"')

rownum = 0
colnums = []
for row in csvreader:
  colnum = 0
  for col in row:
      #print '%-8s: %s' % (header[colnum], col)
      colnum += 1
  if colnum not in colnums: colnums.append(colnum)
  #printse("row {0} col {1}\n".format(rownum, colnum))
  rownum += 1

rownums = rownum
maxnumcols = max(colnums)
printse("Parsed {0} rows; normalizing columns to max cols {1}; \n\
  unique number of columns: {2} ({3})\n"
  .format(rownums, maxnumcols, colnums, sorted(colnums))
)

# second pass: extend (not append) empty entries where they are missing:
# print [""]*3 --> ['', '', '']
# and write out to stdout

csvwriter = csv.writer(sys.stdout)

ifile.seek(0) # "reset" the CSV iterator
rownum = 0
for row in csvreader:
  colnum = 0
  for col in row:
      colnum += 1
  misscols = maxnumcols - colnum
  row.extend([""]*misscols) # here extend, not append!
  # re-check
  #~ colnum = 0
  #~ for col in row:
      #~ colnum += 1
  #~ printse("row {0} col {1}\n".format(rownum, colnum))
  csvwriter.writerow(row)
  rownum += 1


