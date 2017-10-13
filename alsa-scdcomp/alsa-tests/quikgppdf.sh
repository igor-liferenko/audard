#!/usr/bin/env bash
################################################################################
# quikgppdf.sh                                                                 #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# first argument (if present): capture directory

if [ ! "$1" ] ; then
CAPDIR="./captures-2013-07-31-05-20-17" ;
echo "didn't get"
else
CAPDIR="$1" ;
echo "got"
fi

echo "CAPDIR $CAPDIR"

CAPCSV="trace-hda-intel.csv"
#~ CAPCSV="trace-dummy.csv"

# note - in the pdflatex command, we concatenate "$CAPCSV" and "_.pdf"
# bash will choke on the underline after variable (will treat as varname)
# therefore the CAPCSV must be in curly braces: ${CAPCSV}_.pdf
# when concatenating with underscore after it!

function doCapture {

#~ gnuplot -e "dir='$CAPDIR';fname='$CAPCSV';" traceFGTXLogGraph.gp
gnuplot -e "dir='$CAPDIR';fname='$CAPCSV';mr=2.4e-3;" traceFGTXLogGraph.gp
pdflatex "\def\dirCapt{$CAPDIR}\def\fnCapt{${CAPCSV}_.pdf}\input{montagepdf.tex}"
rm montagepdf.aux montagepdf.log
# NOTE: here use copy (`cp`), NOT move (`mv`);
# when using `cp` - `evince` can detect a change in file,
# and autoloads the pdf (otherwise with `mv` it doesn't!!)
TSTAMP=$(echo $CAPDIR | sed 's/[^0-9]*//g')
NNAME=$(echo $CAPCSV | sed 's/trace-\|\.csv//g')
set -x
#~ cp montagepdf.pdf montage-${CAPCSV%%.csv}.pdf
cp montagepdf.pdf montage-${NNAME}-${TSTAMP}.pdf
rm montagepdf.pdf
set +x

} # end function doCapture

CAPCSV="trace-hda-intel.csv"
doCapture

CAPCSV="trace-dummy.csv"
doCapture



