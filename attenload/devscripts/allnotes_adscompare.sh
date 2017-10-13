#!/usr/bin/env bash

# call with:
# bash allnotes_adscompare.sh 2>&1 | tee allnotes.log

for ix in *.note; do
  base=${ix%%.note};
  # first word
  adsbase=$(cut --delimiter=' ' -f 1 < $ix)
  echo perl adscompare.pl ${base}.csv ${adsbase}.CSV ${adsbase}.DAV
  perl adscompare.pl ${base}.csv ${adsbase}.CSV ${adsbase}.DAV 2>&1 | grep -i 'warn\|err\|line\|Gnuplot returned\|^ Ch'
  # gnuplot called auto; move files
  mv adscompare.gnuplot CMP_${base}.gnuplot
  mv adscompare.png CMP_${base}.png
  echo # just newline
done
