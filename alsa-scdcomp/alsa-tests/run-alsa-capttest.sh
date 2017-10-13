#!/usr/bin/env bash
################################################################################
# run-alsa-capttest.sh                                                         #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# run with:
# bash run-alsa-capttest.sh 2>&1 | tee run-alsa-capttest.log ; sed -i '/Parsed line/d' run-alsa-capttest.log


# choose executable test
#~ EXECT="captmini"
EXECT="playmini"

# call as regular user - so as to have correct username for changing permissions!
# (then may be asked for sudo password later)
MESELF=`whoami`

KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system

control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  sudo bash -c "echo 0 > $KDBGPATH/tracing_on" # doesn't fire when it matters :/
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT

# on Ubuntu 11.04, packaged trace-cmd is version 1.0.3
# a later version is needed, which supports "plugin options": the fgraph tailprint option
# on to that version, a patch should be applied (see this dir),
# that will implement `fgraph exitprint`.
# The `exitprint` plugin will simply format the function graph
# more suitably for .csv conversion parsing.
# Note that both version on this PC have a problem (NO FORMAT FOUND) obtaining
# data via trace_printk (however the usual `cat ...tracing/trace` is OK)
# I got the source from .git, and it built version 2.2.0 - the path
# to that version (which has patched 'fgraph exitprint') should be
# in TRACECMDP below (however, I'm still using the default version
# to do the extract here)
TRACECMDP="/media/disk/src/trace-cmd/trace-cmd"


# to build modules, (note, snd-hda-intel needs also hda_codec.h in this directory!)
# use this one (just modify `if [ "" ]` to `if [ "1" ]` to activate; modify back to [ "" ] to deactivate):
if [ "" ]; then
  echo "Doing module rebuild!"
  # to force module rebuild:
  touch hda_intel_2.6.38.c dummy-2.6.32-patest.c dummy-2.6.32-orig.c
  # reset syslog
  sudo bash -c "echo 0 > /var/log/syslog"
  # build both modules:
  make | tee makemodules.log
  # kill pulseaudio before loading modules
  pulseaudio --kill
  # remove hda_intel if autoloaded
  if [ "`lsmod | grep -l snd_hda_intel`" ] ; then
    sudo modprobe -r snd_hda_intel
  fi
  # remove dummy if it has been loaded
  if [ "`lsmod | grep -l snd_dummy`" ] ; then
    sudo rmmod snd_dummy
  fi
  # check
  aplay -l 2>&1 | tee -a makemodules.log
  # load the local modules:
  sudo insmod ./snd-hda-intel.ko    # card 0
  sudo insmod ./snd-dummy.ko        # card 1
  # list the current soundcards
  # (sleep first, to ensure detection of both;
  # else "no soundcards found..." is possible!):
  sleep 1
  aplay -l 2>&1 | tee -a makemodules.log
  # append syslog to makemodules.log:
  cat /var/log/syslog >> makemodules.log
  # exit if using this section
  exit
fi

# in this case, card 0 is snd-hda-intel (hardware); card 1 is dummy (virtual)
## $ aplay -l
## **** List of PLAYBACK Hardware Devices ****
## card 0: Intel [HDA Intel], device 0: ALC269 Analog [ALC269 Analog]
##   Subdevices: 1/1
##   Subdevice #0: subdevice #0
## card 1: Dummy [Dummy], device 0: Dummy PCM [Dummy PCM]
##   Subdevices: 8/8
##   Subdevice #0: subdevice #0 [...]

echo "Doing test: $EXECT"

# commands to prepare kernel trace
#~ KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system
PREPCMDS="
# increase ftrace buffer:
echo 1024 > $KDBGPATH/buffer_size_kb

# set for function_graph tracing
echo function_graph > $KDBGPATH/current_tracer

# have absolute timestamps in the function graph (disabled by default)
echo funcgraph-abstime > $KDBGPATH/trace_options

# show TASK and PID in the function graph (disabled by default)
echo funcgraph-proc > $KDBGPATH/trace_options

# make sure tracing is OFF at start
echo 0 > $KDBGPATH/tracing_on

# reset anything previously in ftrace buffer
echo > $KDBGPATH/trace
"
# do a reset via trace-cmd
#~ sudo trace-cmd reset
#~ sudo trace-cmd start -p function_graph
#~ sudo trace-cmd stop

# prepare kernel trace
sudo bash -c "$PREPCMDS"
sudo cat $KDBGPATH/current_tracer


# "emphasized" report - repeat at end
# actually no need to echo here;
# the input strings are under set -x, so
# are echoed to log
EREP=""
function echo_and_append_erep {
  echo "$1"
  EREP="${EREP}\n$1"
}


function do_run {

# not really using syslog here - however, do copy it;
# because sometimes kernel can see a bug during trace,
# after which the traces are invalid.
sudo bash -c "echo 0 > /var/log/syslog"

# reset ftrace too:
sudo bash -c "echo > $KDBGPATH/trace"

set -x
# compile captmini.c/playmini.c
gcc -DCARDNUM=$CARDNUM -Wall -g -finstrument-functions $EXECT.c -lasound -o $EXECT

# run captmini/playmini as sudo (due to ftrace); collect its output
sudo ./$EXECT &> trace$EXECT-$CURTEST.log
#~ set +x

# show the frames got result only:
gotstr=$(grep 'got:' trace$EXECT-$CURTEST.log)

#~ echo -e "\nNote - here the program will block a bit, as we're reading from trace_pipe;"

# get traces (4 secs should be more than enough for trace_pipe)
#~ set -x
#~ sudo trace-cmd stop
sudo cat $KDBGPATH/trace > trace-o-$CURTEST.txt # get ('original') trace first - that doesn't empty the buffer
sudo trace-cmd extract -o trace-cmd-$CURTEST.dat  # this empties the buffer, like trace-pipe!
sudo chown $MESELF:$MESELF trace-cmd-$CURTEST.dat
# obtain a "regular" trace
trace-cmd report -i trace-cmd-$CURTEST.dat > trace-cmd-$CURTEST.txt
# not using trace-pipe anymore, as the ftrace buffer is empty by now (due to trace-cmd extract)
#~ sudo timeout 4 cat $KDBGPATH/trace_pipe > tracepipe-$CURTEST.txt
dubstr=$(du -b trace-o-$CURTEST.txt trace-cmd-$CURTEST.dat trace-cmd-$CURTEST.txt)  #tracepipe-$CURTEST.txt
awkstr=$(awk 'NR==5{ts1=$1;print} END{ts2=$1;print;print "start",ts1,"end",ts2,"duration",ts2-ts1}' trace-o-$CURTEST.txt) #tracepipe-$CURTEST.txt
# obtain a trace format suitable for parsing using `exitprint`:
$TRACECMDP report -O fgraph:exitprint -i trace-cmd-$CURTEST.dat > trace-cmdX-$CURTEST.txt
# copy the syslog (to check for possible kernel bugs there)
cp /var/log/syslog tracing-$CURTEST.syslog
set +x

echo_and_append_erep "$gotstr"
echo_and_append_erep "$dubstr"
echo_and_append_erep "$awkstr"
echo_and_append_erep "\n"
} # end function do_run


# card 0 - snd-hda-intel
CURTEST="hda-intel"
CARDNUM=0

do_run

# check - tracepipe seems to have extra scheduling information,
# and keeps the trace_printk's from driver (trace drops them?)
# and better? timestamps (trace occasinally will give the same timestamp for two commands; trace-pipe may have those different)
# also - there are more discrepancies for snd-hda-intel if pulseaudio is NOT started!
# (there are a more messages in the trace log if pulseaudio is started, though: 120k without, 680k with! although its mostly i915_* (X windows).. - and doesn't always happen)
# but if pulseaudio IS started, then "got: 32 then 17 frames" is possible; although it's not always like that (but even without!)
#~ meld trace-o-$CURTEST.txt tracepipe-$CURTEST.txt

# try add sleep? seems to help with dummy getting proper capture... but not always..
sleep 1

# card 1 - dummy
CURTEST="dummy"
CARDNUM=1

do_run

#~ meld trace-o-$CURTEST.txt tracepipe-$CURTEST.txt

# after we're done, set back the nop tracer:
sudo bash -c "echo nop > $KDBGPATH/current_tracer"

# collect all logs (from this run only) in a subfolder;
# finally run python script to generate .csv;
# after that, run `sed` to replace `readi_func` with `snd_pcm_readi`/`writei` (the actual in this case)
# after that, also run `gnuplot` to generate .pdf plots of captures!
CAPTDIR="captures-`date +%F-%H-%M-%S`"
set -x
mkdir $CAPTDIR
mv trac*{log,txt,dat} $CAPTDIR/
python traceFGTXLogfile2Csv.py -s $CAPTDIR
MR=""
if [ "$EXECT" == "captmini" ]; then
  sed -i 's/readi_func/snd_pcm_readi/' $CAPTDIR/*.csv
  MR="" # max range (x): implied mr=2e-3
else
  sed -i 's/readi_func/snd_pcm_writei/' $CAPTDIR/*.csv
  MR="mr=3e-3;"
fi
gnuplot -e "dir='$CAPTDIR';fname='trace-hda-intel.csv';$MR" traceFGTXLogGraph.gp
gnuplot -e "dir='$CAPTDIR';fname='trace-dummy.csv';$MR" traceFGTXLogGraph.gp
set +x

echo -e "\nResults (again):\n ${EREP}"

echo -e "\n Do manually as a final step (after script completes):"
echo -e "  mv run-alsa-capttest.log $CAPTDIR/"

echo -e "\nFinished run-alsa-capttest"

