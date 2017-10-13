#!/usr/bin/env bash
################################################################################
# batch_traceLogFile.sh                                                        #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# call with:
# bash batch_traceLogFile.sh

# first automatic plot for all ;
#  after first run, go through images, and
#  set yrange manually in second run
#  edit the `if`s appropriately (use "" for false)

if [ "" ]; then
for ix in captures/*.csv ; do
  cmd="gnuplot -e \"filename='$ix';\" traceLogGraph.gp"
  echo $cmd
  eval $cmd
done
fi

if [ "1" ]; then
for ix in captures/*.csv ; do
  cmd="gnuplot -e \"filename='$ix';eyr='[-10:500000]';\" traceLogGraph.gp"
  echo $cmd
  eval $cmd
done
fi

# for close up (with suffix _01), enable this:

if [ "1" ]; then
for ix in captures/*.csv ; do
  cmd="gnuplot -e \"filename='$ix';fnnum='01';exr='[0:0.2]';eyr='[-10:10000]';\" traceLogGraph.gp"
  echo $cmd
  eval $cmd
done
fi

# for close up (with suffix _02), enable this:

if [ "1" ]; then
for ix in captures/*.csv ; do
  cmd="gnuplot -e \"filename='$ix';fnnum='02';exr='[0:0.1]';eyr='[-10:1000]';\" traceLogGraph.gp"
  echo $cmd
  eval $cmd
done
fi

# eog captures/*01.png
