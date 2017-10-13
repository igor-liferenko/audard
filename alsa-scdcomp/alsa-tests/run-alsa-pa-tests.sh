#!/usr/bin/env bash
################################################################################
# run-alsa-pa-tests.sh                                                         #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# PortAudio dev folder location
PADEVDIR="/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19"
# TESTDIR is "this" (current) folder - the test directory
TESTDIR=`pwd`

echo -e "Running $0 in $TESTDIR ...\n"

set -x
# build dummy driver - no driver debug traces
make

# load dummy driver
# (expecting default soundcard to be card 0;
#  so after load, dummy driver will be card 1)
sudo insmod ./snd-dummy.ko

# check presence
lsmod | grep dummy
aplay -l

if [ ! -d captures ] ; then
  mkdir captures
fi

# increase ftrace buffer size (my defaults: "7 (expanded: 1408)")
sudo bash -c 'echo 1024 > /sys/kernel/debug/tracing/buffer_size_kb'
set +x

echo -e "\nMake sure you've symlinked:"
echo     "ln -s $TESTDIR/patest_duplex_wire.c $PADEVDIR/test/"
echo     "... and added \\ \\n bin/patest_duplex_wire under TESTS "
echo     "... in $PADEVDIR/Makefile "
echo     ", and after a first make, symlinked: "
echo -e  "ln -s $PADEVDIR/bin/patest_duplex_wire $TESTDIR/ \n"

read -p "Press [Enter] key to start tests..."

run_test() {
  set -x
  # build patest_duplex_wire:
  cd "$PADEVDIR"
  # touch, to force rebuild without changing sourcecode
  touch ./test/patest_duplex_wire.c
  eval "make $PRGOPT"

  cd "$TESTDIR"
  # build dummy driver - with driver debug traces
  eval "make $DRVOPT"

  sudo rmmod snd_dummy
  sudo bash -c "echo 0 > /var/log/syslog"
  sudo insmod ./snd-dummy.ko
  # pipe into RAM (/dev/shm/) for (hopefully) faster performance
  touch /dev/shm/syslog_trace # have permissions as user
  touch duwrecorded.raw       # have permissions as user
  sudo bash -c 'echo > /sys/kernel/debug/tracing/trace' # clear trace buffer
  #~ sudo bash -c 'echo Start > /sys/kernel/debug/tracing/trace_marker'
  TPID=$(sudo bash -c 'cat /sys/kernel/debug/tracing/trace_pipe > /dev/shm/syslog_trace & echo $!')
  sleep 1
  sudo ./patest_duplex_wire &>patest.log
  sleep 1
  sudo kill $TPID
  mv /dev/shm/syslog_trace syslog_trace
  du -b syslog_trace
  grep worth syslog_trace
  # if drop found via grep, mark the filename
  if [ $? == 0 ] ; then ISDROP="_drop" ; else ISDROP=""; fi
  # to show the capture:
  #~ gnuplot -p -e "set terminal x11 ; set multiplot layout 2,1 ; plot 0 ls 2, 'duwrecorded.raw' binary format='%int16%int16' using 0:1 with lines ls 1; plot 0 ls 2, 'duwrecorded.raw' binary format='%int16%int16' using 0:2 with lines ls 1 ; unset multiplot"
  mv duwrecorded.raw captures/duwrecorded_${POSTFIX}.raw
  mv syslog_trace captures/trace_patest_${POSTFIX}.txt
  cp /var/log/syslog captures/syslog_${POSTFIX}
  mv patest.log captures/patest_${POSTFIX}.log
  python traceLogfile2Csv.py -s captures/trace_patest_${POSTFIX}.txt > captures/trace_patest_${POSTFIX}${ISDROP}.csv
  set +x
}

# driver snd_dummy defaults are:
# no -DTRACE_DEBUG, no -DFIXED_BYTES_PER_PERIOD
# EXTRA_CFLAGS+="-DTRACE_DEBUG -DFIXED_BYTES_PER_PERIOD"

# patest_duplex_wire.c defaults are:
# -DUSE_PLAYREC_CALLBACKS=1 -DFRAMES_PER_BUFFER=512
# CFLAGS+="-DUSE_PLAYREC_CALLBACKS=1 -DFRAMES_PER_BUFFER=512"

NUMTEST=0

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: no traces; adaptive bytes per period (default, empty options)
DRVDBG="x" ; DRVBPP="A"
DRVOPT=''
# program: use play/rec callbacks; frames per buffer 0
CBTYPE="pr" ; FPB="0"
PRGOPT='CFLAGS+="-DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use play/rec callbacks; frames per buffer 512 (default, empty options)
CBTYPE="pr" ; FPB="512"
PRGOPT=''
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 0
CBTYPE="w" ; FPB="0"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0 -DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 512
CBTYPE="w" ; FPB="512"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test



echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: traces; adaptive bytes per period
DRVDBG="D" ; DRVBPP="A"
DRVOPT='EXTRA_CFLAGS+="-DTRACE_DEBUG"'
# program: use play/rec callbacks; frames per buffer 0
CBTYPE="pr" ; FPB="0"
PRGOPT='CFLAGS+="-DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use play/rec callbacks; frames per buffer 512 (default, empty options)
CBTYPE="pr" ; FPB="512"
PRGOPT=''
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 0
CBTYPE="w" ; FPB="0"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0 -DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 512
CBTYPE="w" ; FPB="512"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test



echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: no traces; fixed bytes per period
DRVDBG="x" ; DRVBPP="F"
DRVOPT='EXTRA_CFLAGS+="-DFIXED_BYTES_PER_PERIOD"'
# program: use play/rec callbacks; frames per buffer 0
CBTYPE="pr" ; FPB="0"
PRGOPT='CFLAGS+="-DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use play/rec callbacks; frames per buffer 512 (default, empty options)
CBTYPE="pr" ; FPB="512"
PRGOPT=''
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 0
CBTYPE="w" ; FPB="0"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0 -DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 512
CBTYPE="w" ; FPB="512"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test



echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: traces; fixed bytes per period
DRVDBG="D" ; DRVBPP="F"
DRVOPT='EXTRA_CFLAGS+="-DTRACE_DEBUG -DFIXED_BYTES_PER_PERIOD"'
# program: use play/rec callbacks; frames per buffer 0
CBTYPE="pr" ; FPB="0"
PRGOPT='CFLAGS+="-DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use play/rec callbacks; frames per buffer 512 (default, empty options)
CBTYPE="pr" ; FPB="512"
PRGOPT=''
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 0
CBTYPE="w" ; FPB="0"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0 -DFRAMES_PER_BUFFER=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test

echo -n Test $((++NUMTEST))
NTS=$(printf "%02d" $NUMTEST)
# driver: same as previous
# program: use wire callback; frames per buffer 512
CBTYPE="w" ; FPB="512"
PRGOPT='CFLAGS+="-DUSE_PLAYREC_CALLBACKS=0"'
#
POSTFIX="_${NTS}_${DRVDBG}${DRVBPP}_${CBTYPE}_${FPB}"
echo ... postfix ${POSTFIX}
run_test


echo "Here is where full duplex drops may have occured:"

for ix in captures/trace_patest_*.txt; do
  echo $ix:
  grep worth $ix
done

echo
echo "Done. You can now generate plots of the captures/*.csv files,"
echo "using the gnuplot script traceLogGraph.gp,"
echo " or in a batch job, using the script batch_traceLogFile.sh"
echo -e "\nTest run complete.\n"

