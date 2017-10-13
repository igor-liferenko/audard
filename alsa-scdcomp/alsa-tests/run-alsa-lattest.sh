#!/usr/bin/env bash
################################################################################
# run-alsa-lattest.sh                                                          #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# run with:
# bash run-alsa-lattest.sh
# (bash run-alsa-lattest.sh 2>&1 | tee run-alsa-lattest.log ; sed -i '/Parsed line/d' run-alsa-lattest.log)

# START LOGFILE+TERMINAL REDIRECT
# do a redirect, to capture output of this script to log:
# backup the original filedescriptors, first
# stdout (1) into fd6; stderr (2) into fd7
exec 6<&1
exec 7<&2
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
#~ exec > >(stdbuf -i0 -o0 tee test.log)
exec > >(tee run-alsa-lattest.log)
# Redirect stderr (2) into stdout (1)
# (Without this, only stdout would be captured - i.e. your
# log file would not contain any error messages.)
exec 2>&1



# executable test name
EXECT="latency"

# call as regular user - so as to have correct username for changing permissions!
# (then may be asked for sudo password later)
MESELF=`whoami`

KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system
ALBTPATH="/media/disk/src/alsa-lib-1.0.24.1/test" # path to alsa-lib/test
# see below for construction of EXECMD: (was LATCMD)
#EXECMD="./latency -P hw:0,0 -C hw:0,0 -r 44100 -m 128 -M 128 -p --looplimit 512 --nosched"
PAPATH="/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19" # path to portaudio
PABPATH="$PAPATH/bin"         # script wrappers for compiled executables (calling build libs)
PABLPATH="$PAPATH/bin/.libs"  # compiled executables (using any loaded lib)
# chosen PortAudio path:
PACPATH="$PABPATH"

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
  touch hda_intel_2.6.38.c dummy-2.6.32-patest.c dummy-2.6.32-orig.c dummy-2.6.32-patest-fix.c
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
  #~ sudo insmod ./snd-dummy.ko        # card 1
  sudo insmod ./snd-dummy-fix.ko        # card 1
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


# commands to prepare kernel trace
#~ KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system
PREPCMDS="
# increase ftrace buffer (was 1024, 2048, need more for longer):
echo 8192 > $KDBGPATH/buffer_size_kb

# set for function_graph tracing
echo function_graph > $KDBGPATH/current_tracer

# have absolute timestamps in the function graph (disabled by default)
echo funcgraph-abstime > $KDBGPATH/trace_options

# show TASK and PID in the function graph (disabled by default)
echo funcgraph-proc > $KDBGPATH/trace_options

# make sure tracing is OFF at start (otherwise controlled by latency-mod.c)
echo 0 > $KDBGPATH/tracing_on

# delete/reset previous ftrace filter (works for both function & function_graph)
echo > $KDBGPATH/set_ftrace_filter

# reset anything previously in ftrace buffer
echo > $KDBGPATH/trace
"

# "emphasized" report - repeat at end
# actually no need to echo here;
# the input strings are under set -x, so
# are echoed to log
EREP=""
function echo_and_append_erep {
  echo "$1"
  EREP="${EREP}\n$1"
}

# do a reset via trace-cmd
#~ sudo trace-cmd reset
#~ sudo trace-cmd start -p function_graph
#~ sudo trace-cmd stop



function do_run {

# not really using syslog here - however, do copy it;
# because sometimes kernel can see a bug during trace,
# after which the traces are invalid.
sudo bash -c "echo 0 > /var/log/syslog"

# reset ftrace too:
sudo bash -c "echo > $KDBGPATH/trace"

set -x

# run latency as sudo (due to ftrace); collect its output
#LATCMD="./latency -P hw:0,0 -C hw:0,0 -r 44100 -m 128 -M 128 -p --looplimit 512 --nosched"
sudo $EXECMD &> /dev/shm/trace$EXECT-$CURDTEST.log
mv /dev/shm/trace$EXECT-$CURDTEST.log trace$EXECT-$CURDTEST.log
set +x
} # end function do_run

function get_run_logs {
# show these frames got result only:
gotstr=$(grep 'frames\|state' trace$EXECT-$CURDTEST.log)

#~ echo -e "\nNote - here the program will block a bit, as we're reading from trace_pipe;"

# get traces (4 secs should be more than enough for trace_pipe)
set -x
#~ sudo trace-cmd stop
sudo cat $KDBGPATH/trace > trace-o-$CURDTEST.txt # get ('original') trace first - that doesn't empty the buffer
sudo trace-cmd extract -o trace-cmd-$CURDTEST.dat  # this empties the buffer, like trace-pipe!
sudo chown $MESELF:$MESELF trace-cmd-$CURDTEST.dat
# obtain a "regular" trace
trace-cmd report -i trace-cmd-$CURDTEST.dat > trace-cmd-$CURDTEST.txt
# not using trace-pipe anymore, as the ftrace buffer is empty by now (due to trace-cmd extract)
#~ sudo timeout 4 cat $KDBGPATH/trace_pipe > tracepipe-$CURDTEST.txt
dubstr=$(du -b trace-o-$CURDTEST.txt trace-cmd-$CURDTEST.dat trace-cmd-$CURDTEST.txt)  #tracepipe-$CURDTEST.txt
awkstr=$(awk 'NR==5{ts1=$1;print} END{ts2=$1;print;print "start",ts1,"end",ts2,"duration",ts2-ts1}' trace-o-$CURDTEST.txt) #tracepipe-$CURDTEST.txt
# obtain a trace format suitable for parsing using `exitprint`:
$TRACECMDP report -O fgraph:exitprint -i trace-cmd-$CURDTEST.dat > trace-cmdX-$CURDTEST.txt
# copy the syslog (to check for possible kernel bugs there)
cp /var/log/syslog tracing-$CURDTEST.syslog
set +x

echo_and_append_erep "$gotstr"
echo_and_append_erep "$dubstr"
echo_and_append_erep "$awkstr"
echo_and_append_erep "\n"
} # end function get_run_logs



echo "Doing test: $EXECT"

# prepare kernel trace
sudo bash -c "$PREPCMDS"
sudo cat $KDBGPATH/current_tracer

# just one test run in this script:
# card 0 - snd-hda-intel
# card 1 - dummy
if [ ! "$CARDNUM" ] ; then
  CARDNUM=1
fi
if [ "$EXECT" == "latency" ] ; then
  if [ ! "$LATLF" ] ; then # allow for extern setting...
    LATLF=256 #128 # latency (min==max; =buffer_size) in frames
  fi
  # duration 512/44100 = 0.01161 = 11.6 ms
  # duration 256/44100 = 0.00580499 = 5.8 ms
  if [ ! "$LATDF" ] ; then
    LATDF=512 #256 # duration of latency test in frames
  fi
  LATDEV="hw:$CARDNUM,0" # latency playback and capture device
  LATRATE=44100 # sampling rate
  LP="" # "-p"/""                   # latency use poll (poll with ftrace for latency tends to fail)
  LPT="" # "--polltime 1"/""        # latency poll time (default is 1000 ms) ; also "-t 1"
  LPTA=($LPT)                       # cast $LPT to array, to split at string
  LS="--nosched" # "--nosched"/""   # latency do not use Round Robin scheduler
  LB="-b" # "-b"/""                 # latency use block
  if [ ! "$LATPF" ] ; then # allow for extern setting... (just noting)
    LATPF=""  # period_size in frames; set as (with space at end):
              # LATPF="--period 256 --skipsizecheck "
  fi

  #LATCMD="./latency -P hw:0,0 -C hw:0,0 -r 44100 -m 128 -M 128 -p --looplimit 512 --nosched"
  EXECMD="$ALBTPATH/$EXECT -P $LATDEV -C $LATDEV -r $LATRATE -m $LATLF -M $LATLF --looplimit $LATDF $LP $LPT $LB ${LATPF}${LS}"
fi
if [ "$EXECT" == "patest_duplex_wire" ] ; then
  if [ ! "$PATBF" ] ; then
    PATBF=256   # frames_per_buffer/callback
  fi
  if [ ! "$PATDF" ] ; then
    PATDF=512   # duration of test in frames
  fi
  PATUSEPRC=0 # use_playrec_callbacks 0/1
  PATWI=0     # wire_callback_interleaved 0/1
  PATMSLP=1   # msleep 1..1000..
  #~ EXECMD="./bin/.libs/patest_duplex_wire -c 0 -w 0 -b 256 -i 1 -o 1 -f 512 -m 1"
  EXECMD="$PACPATH/$EXECT -c $PATUSEPRC -w $PATWI -b $PATBF -i $CARDNUM -o $CARDNUM -f $PATDF -m $PATMSLP"
fi


if [ $CARDNUM == 0 ]; then
  CURDTEST="hda-intel"
elif [ $CARDNUM == 1 ]; then
  CURDTEST="dummy"
fi

#~ do_run
# actually, run until condition is NOT satisfied anymore:
# (do NOT use grep -lv, that inverts matching *lines*; use grep -L to negate detection per whole file!)
#~ WCOND="" # empty condition - do once, regardless of result
#~ WCOND="grep -l 'Failure' trace$EXECT-$CURDTEST.log" # condition: failure detected
WCOND="grep -l 'XRUN' trace$EXECT-$CURDTEST.log" # condition: XRUN detected (stronger than Failure)
#~ WCOND="awk 'BEGIN{a=0;b=0;}/frames = 192/{a=\$0;};/frames = 128/{b=\$0;};{if(a!=0 && b!=0){exit;}};END{{if(!(a!=0 && b!=0)){print a,b;}}}' trace$EXECT-$CURDTEST.log" # condition: specific XRUN detected? - need inverse of `if(a!=0 && b!=0){print a,b;exit;}` - so this: a!=0 && b!=0 just exit; else print something at end - so it saves just that specific xrun.. and MUST escape the $0 - since the enveloping quotes are double!
# patest_duplex_wire PA debug specific:
#~ WCOND="grep -l 'Drop input' trace$EXECT-$CURDTEST.log" # test fail condition: 'Drop input' detected (run until capturelog does not have 'Drop input')
#~ WCOND="grep -l '[Xx]run' trace$EXECT-$CURDTEST.log" # [Xx]run stronger than 'Drop Input'; run until does not have...
#~ WCOND="grep -L 'Drop input' trace$EXECT-$CURDTEST.log" # test fail condition: 'Drop input' *not* detected (run until capturelog does have 'Drop input')
#~ WCOND="awk 'BEGIN{a=0;b=0;} /Drop input/{a=1;} /Xrun/{b=1;} END{if(!(a==1 && b==0)){print \"invalid\";}}' trace$EXECT-$CURDTEST.log" # test fail condition: 'Drop input' *not* detected or Xrun detected (run until capturelog does have 'Drop input' and doesn't have Xrun)

# for collectmirq.sh: fail if xrun detected in log - or if snd_pcm_pre_start not detected in the trace!
# COLMIRQ is intended to be only set externally, from a collectmirq.sh script:
if [ "$COLMIRQ" == "1" ] ; then
  WCOND="grep -li 'xrun' trace$EXECT-$CURDTEST.log ; sudo cat /sys/kernel/debug/tracing/trace | grep -L snd_pcm_.*start" # was snd_pcm_pre_start
fi

while : ; do
  rm -f trac*{log,txt,dat} # silently remove possible previous logfiles
  do_run
  grep '\[rd wr\]\|[Xx]run' trace$EXECT-$CURDTEST.log
  EWC=$( eval $WCOND )
  echo EWC: "$EWC"
  if [[ "$EWC" ]] ; then
    echo "### Test failed; repeating run ...."
  else
    echo "### Test OK; keeping run"
    break
  fi
done

# here if loop exited (test ok) obtain debug logs
get_run_logs

# after we're done, set back the nop tracer:
sudo bash -c "echo nop > $KDBGPATH/current_tracer"



# collect all logs (from this run only) in a subfolder;
# finally run python script to generate .csv;
CAPTDIR="capt${EXECT:0:3}-`date +%F-%H-%M-%S`"
if [ "$EXECT" == "latency" ] ; then
  CEXT="$LATLF-$LATDF"
  if [ "$LP" ] ; then
    CEXT="$CEXT-yp" ;
    if [ "$LPT" ] ; then
      CEXT="$CEXT-${LPTA[1]}" ;
    else
      CEXT="$CEXT-1000" ; # default is 1000 ms
    fi
  else CEXT="$CEXT-np-0" ; fi
  if [ "$LS" ] ; then CEXT="$CEXT-ns" ; else CEXT="$CEXT-ys" ; fi
  if [ "$LB" ] ; then CEXT="$CEXT-yb" ; else CEXT="$CEXT-nb" ; fi
fi
if [ "$EXECT" == "patest_duplex_wire" ] ; then
  CEXT="$PATBF-$PATDF"
  if [ $PATUSEPRC == 0 ] ; then
    CEXT="$CEXT-wc" ;
    if [ $PATWI == 0 ] ; then CEXT="$CEXT-i" ; else CEXT="$CEXT-n" ; fi
  else CEXT="$CEXT-pr" ; fi
  CEXT="$CEXT-${PATMSLP}m"
fi

# since now this is a single test, also add
# identifier (first three characters) to folder name:
CURDTX="${CURDTEST:0:3}"
if [ "$CURDTEST" == "dummy" ] ; then
  if [ "`aplay -l | grep -l fix`"  ]; then
    CURDTX="duF"
  fi
  if [ "`aplay -l | grep -l mod`"  ]; then
    CURDTX="duM"
  fi
fi

CAPTDIR="${CMARK}${CAPTDIR}-${CURDTX}-${CEXT}"

set -x
mkdir $CAPTDIR
mv trac*{log,txt,dat} $CAPTDIR/
if [ "$COLMIRQ" == "1" ] ; then
  python traceFGLatLogfile2Csv.py -s -c 'snd_pcm_pre_start();' $CAPTDIR ;
else
  python traceFGLatLogfile2Csv.py -s $CAPTDIR ;
fi
# ;mr=7e-3;mf=390.0;  ;mr=6e-3;mf=256.0;
# mr: max range shown (time); mf: max frames range for plots
if [ ! "$NOGP" ]; then # extern - set NOGP=1 to skip gnuplot step
  if [ "$EXECT" == "latency" ] ; then
    GMR="7e-3"
    GMF="390.0"
  fi
  if [ "$EXECT" == "patest_duplex_wire" ] ; then
    GMR="14.5e-3"
    GMF="1025.0"
  fi
  gnuplot -e "dir='$CAPTDIR';fname='trace-$CURDTEST.csv';exect='$EXECT';mr=$GMR;mf=$GMF;" traceFGLatLogGraph.gp
fi
set +x

echo -e "\nResults (again):\n ${EREP}"
echo -e "\nFinished run-alsa-lattest in $CAPTDIR/"



# STOP LOGFILE+TERMINAL REDIRECT
# close and restore backup; both stdout and stderr
exec 1<&6 6<&-
exec 2<&7 2<&-
# Redirect again stderr (2) into stdout (1); else echoes to stderr wouldn't show in terminal!
exec 2>&1
# **must** sleep here - allow tee to catch up and terminate:
sleep 0.01



sed -i '/Parsed line/d' run-alsa-lattest.log
set -x ; mv run-alsa-lattest.log $CAPTDIR/ ; set +x

echo -e "\n copy/paste if manual deletion is needed:"
echo -e "  rm -rf $CAPTDIR/"

