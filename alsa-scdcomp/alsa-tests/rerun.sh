#!/usr/bin/env bash
################################################################################
# rerun.sh                                                                     #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# call with
# bash rerun.sh
# bash rerun.sh "drv"
# bash rerun.sh "usb"
# bash rerun.sh "drvusbslpacity"

PLAYFILE=/media/disk2/tmp/out16s.wav
#~ PLAYFILE=out16s_sh.wav
#~ PLAYFILE=out16s.wav
RECFILE=out.wav
#~ PALIB=""
PRELD="LD_PRELOAD=/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19/lib/.libs/libportaudio.so"
#~ PRELD=""
SLPSEC=1

#~ DRVLOC="."
#~ DRVLOC="/media/disk/work/AudioFPGA_git/driver_pc/snd_ftdi_audard-an16s"
DRVLOC="/media/disk/src/alsa-driver-1.0.24+dfsg/alsa-kernel/drivers"

set -x

# hardware watchdog to reboot upon lock
# (if [ 0 ] doesn't disable; "" does)
if [ "" ] ; then
  sudo modprobe iTCO_wdt
  sudo ./watchdog-daemon &
fi

#if [ "$1" == "drv" ] ; then
if [ "$1" != "${1/drv/}" ]; then
  logger "PRE:RMMOD AUDARD_16s"
  sleep 2
  sudo rmmod --verbose --wait --syslog snd_ftdi_audard_16s
  rret=$?
  logger "POST:RMMOD AUDARD_16s ($rret)"
  # if it crashes here, exit
  if [ ! $rret == 0 ] ; then
    exit 1
  fi
  sleep $SLPSEC
fi
sudo bash -c "echo 0 > /var/log/syslog"
sleep $SLPSEC
if [ "$1" != "${1/drv/}" ]; then
  sudo insmod "$DRVLOC"/snd_ftdi_audard_16s.ko
  sleep $SLPSEC
fi
stty 2000000 inpck -ixon -icanon -hupcl -isig -iexten -echok -echoctl -echoke min 0 -crtscts -echo -echoe -echonl -icrnl -onlcr cstopb -opost </dev/ttyUSB0
sleep 1
if [ "$1" != "${1/usb/}" ]; then
  USBA=( $(lsusb | grep FT232) )
  USBBUSNUM=$((${USBA[1]}))
  USBDEVNUM=$(( $(echo ${USBA[3]} | grep -oE "[[:digit:]]{1,}" ) ))
  touch outshark.pcap
  chmod 777 outshark.pcap
  # -q(uiet) here - so the tshark packet count doesn't interfere:
  (sudo tshark -q -i usbmon${USBBUSNUM} -w $(pwd)/outshark.pcap &)
  sleep 2
fi
if [ "$1" != "${1/acity/}" ]; then
  # start audacity here (fake arec.log)
  touch arec.log
  echo "Do a duplex recording in audacity, export it as out.wav in $PWD/out.wav - and close audacity."
  eval "$PRELD audacity $PLAYFILE &>audac.log"
else
  # -T 10 will initiate XRUNs which otherwise wouldn't be there:
  #(arecord -vvv -T 10 -Dhw:1,0 -d 2 -f S16_LE -c2 -r44100 out.wav 2>arec.log &) && aplay -Dhw:1,0 /media/disk2/tmp/out16s.wav
  # simply go without -T 10 for testing
  #~ (arecord -vvv -Dhw:1,0 -d 2 -f S16_LE -c2 -r44100 $RECFILE 2>arec.log &) && aplay -Dhw:1,0 $PLAYFILE
  #~ aplay -Dhw:1,0 $PLAYFILE
  ## &>file.log to redirect both stdout and stderr!
  #~ ./patest_recordB.bin
  #~ (./patest_recordB.bin &>patest.log &) && sleep 0.3 && aplay -Dhw:1,0 $PLAYFILE

  ## below (produces trace.dat; use kernelshark or pytimechart to view)
  ## could additionally use: -e sched:sched_wakeup -e sched:sched_wakeup_new -e sched:sched_switch
  #~ sudo /media/disk/src/trace-cmd/trace-cmd record -p function_graph -l ':mod:snd_ftdi_audard_16s' -l do_IRQ ./patest_duplex_wire.bin

  ## test with patest_duplex_wire (sudo because of trace_marker)
  ## get trace_pipe afterward (Ctrl-C to exit it) # actually before
  ## finally render captured wave
  touch /dev/shm/syslog_trace # have permissions as user
  sudo bash -c 'echo > /sys/kernel/debug/tracing/trace' # clear trace buffer
  sudo bash -c 'echo Start > /sys/kernel/debug/tracing/trace_marker'
  TPID=$(sudo bash -c 'cat /sys/kernel/debug/tracing/trace_pipe > /dev/shm/syslog_trace & echo $!')
  sleep 1
  #~ arecord -Dhw:1,0 -d 2 -f S16_LE -c2 -r44100 $RECFILE 2>arec.log
  #~ (arecord -Dhw:1,0 -d 2 -f S16_LE -c2 -r44100 $RECFILE 2>arec.log &) && aplay -Dhw:1,0 $PLAYFILE
  #~ sleep 3
  sudo ./patest_duplex_wire &>patest.log
  #~ sudo cat /sys/kernel/debug/tracing/trace_pipe | tee syslog_trace
  sleep 1
  sudo kill $TPID
  mv /dev/shm/syslog_trace syslog_trace
  du -b syslog_trace
  grep worth syslog_trace
  gnuplot -p -e "set terminal x11 ; set multiplot layout 2,1 ; plot 0 ls 2, 'duwrecorded.raw' binary format='%int16%int16' using 0:1 with lines ls 1; plot 0 ls 2, 'duwrecorded.raw' binary format='%int16%int16' using 0:2 with lines ls 1 ; unset multiplot"
fi
if [ "$1" != "${1/slp/}" ]; then
  # this was only needed in case of XRUN (when arecord would starts looping, restarting streams)
  sleep 3
  #killall arecord
fi
# just in case, so it doesn't lock (keeps the .wav, OK)
#~ killall patest_recordB #arecord
if [ "$1" != "${1/usb/}" ]; then
  # ok - even with plain killall (SIGKILL:9), tshark
  # prints out capture number here (as with SIGINT:2/Ctrl-C):
  sudo killall tshark
fi
set +x
