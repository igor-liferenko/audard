#!/usr/bin/env bash

# Part of the attenload package
#
# Copyleft 2012, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


# call w:
# bash prep_csv_gvis.sh vis_usbsnoop.csv vis_usbmon.csv gvis_csv.gnuplot

USBSNOOPCSV=$1
USBMONCSV=$2
GPLOTSCT=$3

ARGC=$#  # Number of args, not counting $0
if ! [ "$ARGC" -eq 3 ] ; then
  echo "Need 3 arguments";
  exit 1;
fi

# from first line of each csv datafile
# get timestamps (first field)
# get packet index (third field)

F1ONE=$(head -n1 "$USBSNOOPCSV" | cut -d, -f1)
F3ONE=$(head -n1 "$USBSNOOPCSV" | cut -d, -f3)
F1TWO=$(head -n1 "$USBMONCSV" | cut -d, -f1)
F3TWO=$(head -n1 "$USBMONCSV" | cut -d, -f3)

echo "F1ONE $F1ONE, F3ONE $F3ONE, F1TWO $F1TWO, F3TWO $F3TWO"

# so indexes in gnuplot start at one:
let F3ONE-=1
let F3TWO-=1

echo "F1ONE $F1ONE, F3ONE $F3ONE, F1TWO $F1TWO, F3TWO $F3TWO"


# head -n1 command should output something like:
# 194278,URB,1,43 6f 6d 6d 07 00 40 00 14 00 00 00 00 00 00 00,>>>,Comm.@.
# the first number is the timestamp in ms ;
# third field is packet sequence number;
# it should be replaced as x offset in gvis_csv.gnuplot script
# (which uses vis_usbsnoop.csv and vis_usbmon.csv as datasets):

sed -n "s/TIMEOFFSA=\([0-9]*\)/TIMEOFFSA=$F1ONE/p" gvis_csv.gnuplot
sed -n "s/TIMEOFFSB=\([0-9]*\)/TIMEOFFSB=$F1TWO/p" gvis_csv.gnuplot
sed -n "s/INDXOFFSA=\([0-9]*\)/INDXOFFSA=$F3ONE/p" gvis_csv.gnuplot
sed -n "s/INDXOFFSB=\([0-9]*\)/INDXOFFSB=$F3TWO/p" gvis_csv.gnuplot

#~ exit 0 # for testing

sed -i "s/TIMEOFFSA=\([0-9]*\)/TIMEOFFSA=$F1ONE/" gvis_csv.gnuplot
sed -i "s/TIMEOFFSB=\([0-9]*\)/TIMEOFFSB=$F1TWO/" gvis_csv.gnuplot
sed -i "s/INDXOFFSA=\([0-9]*\)/INDXOFFSA=$F3ONE/" gvis_csv.gnuplot
sed -i "s/INDXOFFSB=\([0-9]*\)/INDXOFFSB=$F3TWO/" gvis_csv.gnuplot

# finally, visualise with gnuplot (generates a PDF):
#~ gnuplot gvis_csv.gnuplot     # do separately

