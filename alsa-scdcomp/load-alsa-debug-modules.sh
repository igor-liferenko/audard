#!/usr/bin/env bash
################################################################################
# load-alsa-debug-modules.sh                                                   #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

BLACKLISTFILE="/etc/modprobe.d/blacklist-snd.conf"
ALSADBGPATH="/media/disk/src/alsa-driver-1.0.24+dfsg"

# http://stackoverflow.com/a/4025065/277826
vercomp () {
  if [[ $1 == $2 ]]
  then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
  do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++))
  do
    if [[ -z ${ver2[i]} ]]
    then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]}))
    then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]}))
    then
      return 2
    fi
  done
  return 0
}

echo "
***
Note that this script has been written around the particular behavior of
development (netbook) PCs with on-board 'hda-intel' soundcard, running
 Ubuntu 11.04 w/ kernel 2.6.38
 Ubuntu 10.04 w/ kernel 2.6.32
For any other systems, it may behave unexpectedly; please review and modify
the code as appropriate in that case.
***
"

# get kernel release version: uname -r: "2.6.38-16-generic"
# also, cut off anything after first '-', so we get "2.6.38" only
KERNELVERSION=$(uname -r | cut -d'-' -f1)
echo "Kernel version is: $KERNELVERSION"
# lsb_release -s -i: "Ubuntu"
DISTROID=$(lsb_release -s -i)
echo "Distro ID is: $DISTROID"
echo

# these are the modules on our 2.6.38 platform, in unload order:
# (spacings indicate unload groups, as detected by the unload call)
ALSAMODULES_2_6_38="
snd_hda_intel
snd_seq_midi
snd_hrtimer

snd_hda_codec_realtek
snd_rawmidi
snd_seq_midi_event

snd_hda_codec
snd_seq

snd_pcm
snd_hwdep
snd_seq_device

snd_page_alloc
snd_timer

snd

soundcore
"

# these are the modules on our 2.6.32 platform, in unload order:
# for 2.6.32, the last five would be claimed by the OS,
# (primarily because snd_seq is claimed; but not by a module, eg):
#   $ lsmod | grep snd
#   snd_seq                47263  1
#   snd_timer              19130  1 snd_seq
#   snd_seq_device          5700  1 snd_seq
#   snd                    54244  4 snd_seq,snd_timer,snd_seq_device
#   soundcore               6620  1 snd
#   $ sudo rmmod --force snd_seq
#   ERROR: Removing 'snd_seq': Resource temporarily unavailable
# ... and thus unremovable, since we cannot really know what
# claims the snd_seq driver (see );
# unless all are blacklisted from loading at boot
ALSAMODULES_2_6_32="
snd_hda_intel
snd_pcm_oss
snd_seq_dummy
snd_seq_oss
snd_seq_midi

snd_hda_codec_realtek
snd_mixer_oss
snd_rawmidi
snd_seq_midi_event

snd_hda_codec

snd_hwdep
snd_pcm

snd_page_alloc

snd_timer
snd_seq
snd_seq_device
snd
soundcore
"

# vanilla modules - with modprobe (based on 2.6.38):
ALLVANMODS="\
soundcore \
snd \
snd_timer \
snd_page_alloc \
snd_seq_device \
snd_hwdep \
snd_pcm \
snd_seq \
snd_hda_codec \
snd_seq_midi_event \
snd_rawmidi \
snd_hda_codec_realtek \
snd_hrtimer \
snd_seq_midi \
snd_hda_intel
"

LOADEDALSAMODS=$(lsmod | grep 'snd\|sound')

if [[ $(vercomp $KERNELVERSION 2.6.38; echo $?) == 0 ]]; then
  # override ALLVANMODS by removing empty lines from the unload module order,
  # and reversing that order (via `tac`);
  # print in both alphabetic and load order using `pr` (not `paste`)
  # and add line numbers via cat -n
  ALLVANMODS=$(echo "$ALSAMODULES_2_6_38" | grep -v '^$' | tac)
  echo "Expecting for 2.6.38:"
  MODSR1=$(echo "Sorted alpha:" ; echo "$ALLVANMODS" | sort | cat -n)
  MODSR2=$(echo "Load order:" ; echo "$ALLVANMODS")
  MODSR3=$(echo "Current loaded:" ; echo "$LOADEDALSAMODS")
  pr -m -T -e <(echo "$MODSR1") <(echo "$MODSR2") <(echo "$MODSR3")
elif [[ $(vercomp $KERNELVERSION 2.6.32; echo $?) == 0 ]] ; then
  ALLVANMODS=$(echo "$ALSAMODULES_2_6_32" | grep -v '^$' | tac)
  echo "Expecting for 2.6.32:"
  MODSR1=$(echo "Sorted alpha:" ; echo "$ALLVANMODS" | sort | cat -n)
  MODSR2=$(echo "Load order:" ; echo "$ALLVANMODS")
  MODSR3=$(echo "Current loaded:" ; echo "$LOADEDALSAMODS")
  pr -m -T -e <(echo "$MODSR1") <(echo "$MODSR2") <(echo "$MODSR3")
else
  echo "Unexpected kernel version"
fi

# note - module filenames with minus -, module names with underscore _
#~ ALLDBGMODS="\
#~ modules/soundcore.ko \
#~ modules/snd.ko \
#~ modules/snd-seq-device.ko \
#~ modules/snd-timer.ko \
#~ modules/snd-seq.ko \
#~ modules/snd-hrtimer.ko \
#~ modules/snd-seq-midi-event.ko \
#~ modules/snd-rawmidi.ko \
#~ modules/snd-page-alloc.ko \
#~ modules/snd-seq-midi.ko \
#~ modules/snd-hwdep.ko \
#~ modules/snd-pcm.ko \
#~ modules/snd-hda-codec.ko \
#~ modules/snd-hda-codec-realtek.ko \
#~ modules/snd-hda-intel.ko \
#~ "

# alsa-kernel/pci/hda/snd-hda-intel.ko - default
# alsa-kernel/pci/hda/snd_hda_intel.ko - my mod w/ extra printouts
# alsa-kernel/drivers/snd-dummy-fix.ko - my mod

# alldbgmods based on
ALLDBGMODS="\
alsa-kernel/soundcore.ko \
alsa-kernel/core/snd.ko \
alsa-kernel/core/seq/snd-seq-device.ko \
alsa-kernel/core/snd-timer.ko \
alsa-kernel/core/seq/snd-seq.ko \
alsa-kernel/core/snd-hrtimer.ko \
alsa-kernel/core/seq/snd-seq-midi-event.ko \
alsa-kernel/core/snd-rawmidi.ko \
alsa-kernel/core/snd-page-alloc.ko \
alsa-kernel/core/seq/snd-seq-midi.ko \
alsa-kernel/core/snd-hwdep.ko \
alsa-kernel/core/snd-pcm.ko \
alsa-kernel/pci/hda/snd-hda-codec.ko \
alsa-kernel/pci/hda/snd-hda-codec-realtek.ko \
alsa-kernel/pci/hda/snd_hda_intel.ko \
alsa-kernel/drivers/snd-dummy-fix.ko \
"


# this is also based on 2.6.38:
if [ "$1" == "blacklist" ] ; then
  sudo bash -c "
cat > $BLACKLISTFILE <<EOF
# Do not load these modules on boot
blacklist soundcore
blacklist snd
blacklist snd_seq_device
blacklist snd_timer
blacklist snd_seq
blacklist snd_hrtimer
#
blacklist snd_seq_midi_event
blacklist snd_rawmidi
#
blacklist snd_page_alloc
blacklist snd_seq_midi
blacklist snd_hwdep
#
blacklist snd_pcm
blacklist snd_hda_codec
blacklist snd_hda_codec_realtek
blacklist snd_hda_intel
EOF
"
  echo ALSA snd_ modules blacklisted in $BLACKLISTFILE;
  echo reboot to effectuate
fi

if [ "$1" == "unblacklist" ] ; then
  set -x
  sudo rm $BLACKLISTFILE
  set +x
  echo ALSA snd_ modules blacklist $BLACKLISTFILE removed;
  echo reboot to effectuate
fi

if [ "$1" == "unload" ] ; then
  echo Attempting to unload ALSA snd_ modules
  ix="a";
  while [ "$ix" != ""  ]; do
    ix=$(lsmod | grep 'snd\|sound' | grep ' 0');
    echo "$ix";
    ixn=$(echo "$ix"| awk '{print $1;}');
    for ixnx in $ixn; do
      set -x; sudo rmmod $ixnx; set +x;
    done;
    sleep 0.5;
  done
  # one more check, after all is done:
  ix=$(lsmod | grep 'snd\|sound' )
  if [ "$ix" == "" ] ; then
    echo No more snd_ modules loaded
  else
    echo snd_ modules remaining:
  fi
  echo "$ix"
  exit
fi

# without arguments, automatically is "load", which is debug:
if [ "$1" == "" -o "$1" == "load" ] ; then
  echo Attempting to load debug ALSA snd_ modules
  for ix in $ALLDBGMODS; do
    set -x
    sudo insmod $ALSADBGPATH/$ix
    if [ $? != 0 ] ; then exit ; fi
    set +x
    sleep 0.5
  done
  echo Loaded modules:
  ix=$(lsmod | grep 'snd\|sound' )
  echo "$ix"
fi

# load vanilla modules
if [ "$1" == "loadvan" ] ; then
  echo Attempting to load vanilla ALSA snd_ modules
  for ix in $ALLVANMODS; do
    set -x
    sudo modprobe $ix
    if [ $? != 0 ] ; then exit ; fi
    set +x
    sleep 0.5
  done
  echo Loaded modules:
  ix=$(lsmod | grep 'snd\|sound' )
  echo "$ix"
fi


