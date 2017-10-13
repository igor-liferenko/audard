#!/usr/bin/env bash
################################################################################
# getHZ.sh                                                                     #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# try find /boot/config

bcfiles=(/boot/config*)
numbcfiles=${#bcfiles[@]}
echo "Found $numbcfiles /boot/config candidates"

BCF=""
for f in "${bcfiles[@]}"
do
	if [[ "${f}" =~ "$(uname -r)" ]]; then
    # regex match must be in [[ ]]
    # (if it matches, it comes in here, even if $? is 0)
    BCF="${f}"
    echo "Using ${BCF}"
  fi
done

if [ "$BCF" == "" ] ; then
  echo "Cannot find proper /boot/config among:"
  echo "${bcfiles[@]}"
  exit
fi

HZmatches=("$(grep HZ "$BCF")")
echo "$HZmatches[@]"

echo
echo "Via /proc/timer_list:"
# http://stackoverflow.com/a/17371631/277826
awk '
/^now at/ { nsec=$3; }
/^jiffies/ { jiffies=$2; }
END {
      print nsec, jiffies;
      system("sleep 1");
}
' /proc/timer_list | awk '
NR==1 { nsec1=$1; jiffies1=$2; }
/^now at/ NR>1 { nsec2=$3; }
/^jiffies/ NR>1 { jiffies2=$2; }
END {
      dsec=(nsec2-nsec1)/1e9;
      djiff=(jiffies2-jiffies1);
      print int(djiff/dsec);
}
' - /proc/timer_list

<<COMMENT
# output of this script:

Found 1 /boot/config candidates
Using /boot/config-2.6.38-16-generic
CONFIG_RCU_FAST_NO_HZ=y
CONFIG_NO_HZ=y
# CONFIG_HZ_100 is not set
CONFIG_HZ_250=y
# CONFIG_HZ_300 is not set
# CONFIG_HZ_1000 is not set
CONFIG_HZ=250
CONFIG_MACHZ_WDT=m[@]

Via /proc/timer_list:
250

COMMENT


