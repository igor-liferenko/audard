PDPATH="/DISKPATHTO/pd-extended_0.43.4-1"
#~ PDPATCH="turntable_audioloop_s.pd"
#~ PDPATCH="turntable_audioloop_dbl_s.pd"
#~ PDPATCH="seqinterface_s.pd"
#~ PDPATCH="turntable_seqinterface_s.pd"
PDPATCH="turntable_seqinterface_dbl_s.pd"

# SO:59895
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  THISDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
THISDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# NOTE: to record, since writesf~ may be buggy and truncate the .wavs, need to use snd-aloop driver, and set up loopbacks in .asoundrc - and then, use the PD switch `-alsaadd default` to be able to use PCM devices from ALSA in PD; and then change the Audio Settings in PD to use this device; then arecord can record from a 'looprec' device, etc... switch with this variable:
#~ USEALSAADD=""
USEALSAADD="-alsaadd default"

$PDPATH/usr/bin/pdextended \
  -font 10 \
  -path $THISDIR \
  -lib cyclone \
  -lib ext13 \
  -path $PDPATH/usr/lib/pd-extended/extra/Gem \
  -lib Gem \
  -lib maxlib \
  -lib iemlib \
  -path $PDPATH/usr/lib/pd-extended/extra/iemlib_R1.17 \
  -lib iemlib1 \
  -lib iemlib2 \
  -lib iem_t3_lib \
  -lib iem_mp3 \
  -lib mjlib \
  -lib motex \
  -lib OSC \
  -path $PDPATH/usr/lib/pd-extended/extra/PeRColate \
  -lib percolate \
  -lib pdogg \
  -lib xeq \
  -path $PDPATH/usr/lib/pd-extended/extra/xsample \
  -lib xsample \
  -lib zexy \
  -listdev \
  -path $PDPATH/usr/lib/pd-extended/extra/gripd \
  -lib gripd \
  -path $PDPATH/usr/lib/pd-extended/extra/pdlua \
  -lib pdlua \
  -path $PDPATH/usr/lib/pd-extended/extra/py \
  -path $PDPATH/usr/lib/pd-extended/extra/py/scripts \
  -lib py \
  $USEALSAADD \
$PDPATCH
  #~ -stderr -d 4 \
#~ $PDPATCH 2>&1 | tee /tmp/pdlog.txt

