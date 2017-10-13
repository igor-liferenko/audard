#!/usr/bin/env bash
################################################################################
# copylogs.sh                                                                  #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# call with
# bash copylogs.sh
# bash copylogs.sh "_suffix"

max=0;
for ix in arec_*.log; do
  aa=${ix#arec_};
  ab=${aa%.log} ;
  #echo $ab ;
  if (( $ab > $max )) ; then
    max=$((ab));
  fi;
done;
newm=$(($max+1));
# also use cmdline argument (if any) for filename marker
newms="${newm}${1}"
echo "$newm - $newms"
numLogfile2Csv="python /media/disk/sdaaubckp/numStepCsvLogVis/tools/numLogfile2Csv.py"
echo mv -v arec.log arec_${newm}.log
echo cp -v /var/log/syslog syslog_arec_${newms}
echo grep "'tmr_fnc_capt' syslog_arec_${newms} | cut -d' ' -f6- | $numLogfile2Csv - > syslog_arec_${newms}.csv"
echo mv -v outshark.pcap outshark_arecplay_${newms}.pcap
echo mv -v out.wav out_arecplay_${newms}.wav
echo mv -v audac.log audac_${newms}.log

USBA=( $(lsusb | grep FT232) )
USBBUSNUM=$((${USBA[1]}))
USBDEVNUM=$(( $(echo ${USBA[3]} | grep -oE "[[:digit:]]{1,}" ) ))

TSHMATCHWR="usb.device_address == $USBDEVNUM and usb.endpoint_number == 2 and usb.urb_type matches \"S\""
TSHMATCHRD="usb.device_address == $USBDEVNUM and usb.endpoint_number == 0x81 and usb.urb_type matches \"C\" and usb.data_len>2"

function setTsharkCmd()
{
TSHARKWR="tshark -r outshark_arecplay_${newms}.pcap -R '${TSHMATCHWR}' -x \
 | grep --invert-match '^0000\|0010\|0020\|0030' \
 | grep --invert-match 'host ->\|host.*USB\|Packet\|^\$' \
 | cut -d' ' -f 3-19 \
 | perl -ne 'chomp \$_; print pack(\"(H2)*\", split(/ /, \$_));' \
 > outshark_arecplay_binwrite_${newms}.dat"

# pipeline doesn't work in array...:
#TSHARKRD=("tshark -r outshark_arecplay_${newms}.pcap -R "\'"${TSHMATCHRD}"\'" -x")
#TSHARKRD+=("| grep --invert-match '^0000\|0010\|0020\|0030'")

TSHARKRD="tshark -r outshark_arecplay_${newms}.pcap -R '${TSHMATCHRD}' -x \
 | grep --invert-match '^0000\|0010\|0020\|0030' \
 | grep --invert-match 'host.*USB\|Packet\|^\$' \
 | cut -d' ' -f 1-19 \
 | sed 's/^\(0\w[48c0]0\)  01 [06][02] /\1  /' \
 | cut -d' ' -f 3- \
 | perl -ne 'chomp \$_; print pack(\"(H2)*\", split(/ /, \$_));' \
 > outshark_arecplay_binread_${newms}.dat"
}

# no () for bash function call!:
setTsharkCmd

echo "$TSHARKWR"
echo "$TSHARKRD"

read -p "Do this? " REPLY
if [ "$REPLY" == "y" ] ; then
  set -x
  #trap 'printf %s\\n "$BASH_COMMAND" >&2' DEBUG # no need with set -x
  mv -v arec.log arec_${newm}.log
  cp -v /var/log/syslog syslog_arec_${newms}
  grep 'tmr_fnc_capt' syslog_arec_${newms} | cut -d' ' -f6- | $numLogfile2Csv - > syslog_arec_${newms}.csv
  mv -v outshark.pcap outshark_arecplay_${newms}.pcap
  # if outshark move succeeds, run the extraction commands:
  # nb: eval works for $TSHARKWR; but messes up $TSHARKRD's `sed`!
  # (because eval escapes single quotes, and splits at spaces -
  #  and not even array helps, as it is a pipeline)
  # eval $(echo $TSHARKRD) - same as eval $TSHARKRD
  # try using bash -c instead of eval?
  # no - only thing I needed were double quotes:
  #  eval "$TSHARKRD" instead of eval $TSHARKRD !!
  if [ $? -eq 0 ] ; then
    eval "$TSHARKWR"
    eval "$TSHARKRD"
  fi
  mv -v out.wav out_arecplay_${newms}.wav
  mv -v audac.log audac_${newms}.log
  set +x
fi;

echo "To compare (but will need to adjust the 2c for start silence, maybe 5ac):"
echo "dhex -o1h 2c out_arecplay_${newms}.wav outshark_arecplay_binwrite_${newms}.dat"
echo "To delete:"
echo "rm -rf arec_${newm}.log syslog_arec_${newms} syslog_arec_${newms}.csv outshark_arecplay_${newms}.pcap outshark_arecplay_binwrite_${newms}.dat outshark_arecplay_binread_${newms}.dat out_arecplay_${newms}.wav"

