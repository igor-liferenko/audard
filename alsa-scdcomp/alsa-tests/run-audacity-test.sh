#!/usr/bin/env bash
################################################################################
# run-audacity-test.sh                                                         #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# run with:
# bash run-audacity-test.sh
# TYPE="adbg" bash run-audacity-test.sh reparseall



function adbg_parse() {
# preparse step 1 - collect syslog and ftrace into a single merged log
# syslog timestamps are all over the place anyway, will need sorting;
# first, extract and cut the start of syslog lines:
# (note, the "pa[" is custom output from hacked PA pa_linux_alsa.c)
# (remember to append >> !!)
echo > $CAPTDIR/syslftrc.log
grep 'kernel:' $CAPTDIR/tracing-$CURDTEST.syslog | sed 's/^.*kernel:/kernel:/' >> $CAPTDIR/syslftrc.log
grep 'pa\[' $CAPTDIR/tracing-$CURDTEST.syslog | sed 's/^.*pa\[/pa\[/' >> $CAPTDIR/syslftrc.log
grep 'snd_pcm_.*start\|snd_pcm_.*poll\|snd_pcm_mmap.*' $CAPTDIR/trace-o-$CURDTEST.txt >> $CAPTDIR/syslftrc.log
# preparse step 2 - reformat + sort all accordingly
# note here kernel tstamps could be '[  809.218299]' or '[12323.456543]' - must take that into account in the gawk splitter!
gawk '
/^kernel|^pa/ {
if($2=="["){
if (match($3,/([[:digit:]\.]+)\]/,m)) {
 ts=m[1]; a[ts]=sprintf("% 15s",$1);
 for(ix=4;ix<=NF;ix++) {a[ts] = (a[ts] " " $ix);}
 print ts,a[ts];
}; }else{
if (match($2,/.*\[([[:digit:]\.]+)\]/,m)) {
 ts=m[1]; a[ts]=sprintf("% 15s",$1);
 for(ix=3;ix<=NF;ix++) {a[ts] = (a[ts] " " $ix);}
 print ts,a[ts];
}; }; }
/snd_pcm_/ {
if (match($3,/([[:digit:]\.]+):/,m)) {
 ts=m[1]; a[ts]=sprintf("% 15s %s",$1,$2);
 for(ix=4;ix<=NF;ix++) {a[ts] = (a[ts] " " $ix);}
 print ts,a[ts];
}; }
' $CAPTDIR/syslftrc.log \
| sort -n -s -k 1,13 \
| awk 'BEGIN{o=0;} /snd_pcm_.*start/{o=1;}; {if(o==1){print $0;};}' \
| awk '{if(!sts){sts=$1;}; printf("%.06f %s\n",$1-sts,$0);}' \
> $CAPTDIR/syslftrc2.log

# parse - into space-separated, not .csv (so call it .dat)
awk '
{ts=$1;epstat=-1;fid=-1;fl="XXX";pos=-1;fra=-1;frg=-1;pofs=-1;pfr=-1;ptr=-1;dlt=-1;ohw=-1;nhw=-1;hwb=-1;hws=-1;}
/snd_pcm_.*start/ {fid=1;fl="STA";}
/start poll/ {fid=2;fl="Wsp";}
/end poll/ {fid=3;fl="Wep";epstat=$7;}
/CallbackThreadFunc/ {fid=4;fl="CTF";split($9,ta,/:/);fra=ta[2];split($10,ta,/[:,]/);frg=ta[2];}
/hwptr_update/ {fid=5;fl="hwu";split($6,ta,/[=\/,]/);pos=ta[2];psz=ta[3];bsz=ta[4];
split($7,ta,/[=\/,]/);dlt=ta[2];ohw=ta[3];nhw=ta[4];hwb=ta[5];hws=ta[6];}
/period_update/ {fid=6;fl="pdu";split($6,ta,/[=\/,]/);pos=ta[2];psz=ta[3];bsz=ta[4];
split($7,ta,/[=\/,]/);dlt=ta[2];ohw=ta[3];nhw=ta[4];hwb=ta[5];hws=ta[6];}
/psil/ {fid=7;fl="psl";pofs=$6;pfr=$8;ptr=$10;}
/sample_hbp_handler/ {fid=8;fl="shh";}
/snd_pcm_playback_poll/ {fid=9;fl="kpp";}
/PaAlsaStreamComponent_RegisterChannels/ {fid=12;fl="PRC";}
/PaUtil_EndBufferProcessing/ {fid=13;fl="PBE";}
{if(fid>-1){print ts,fid,fl,psz,bsz,pos,dlt,ohw,nhw,hwb,hws,epstat,fra,frg,pofs,pfr,ptr;}}
' $CAPTDIR/syslftrc2.log > $CAPTDIR/trace-$CURDTEST.dat
} # end function adbg_parse()



if [ ! "$TYPE" ] ; then  # make settable via extern env var
  TYPE="mirq"
  #TYPE="adbg" # with alsa-driver debug kernel modules (different parser)
fi

if [ "$1" == "reparseall" ]; then
  if [ "$TYPE" == "mirq" ] ; then
    for ix in $(ls -d c*/); do
      ix=${ix%%/}
      ic=$(basename `echo $ix/*.csv`)
      inf=$(basename `echo $ix/trace-o-*.txt`)
      echo $ix $ic $inf
      # parse into .csv (all pointers here):
      perl -ne '
if (!(defined($startts))) {
  if ($_ =~ /_start/) {
    @ss=split(" ",$_);
    $startts=( $ss[2] =~ /([\d\.]+)/ )[0];
    #$strm=( $_ =~ /\((\d)\)/ )[0];
    print "# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr,13_rdly,14_strm\n";
  }
}
if ($_ =~ /_pointer/) {
  @ss=split(" ",$_);
  @s1m=split("-",$ss[0]); $proc=$s1m[0]; $pid=$s1m[1];
  $strm=( $ss[6] =~ /\((\d)\)/ )[0]; # or $_
  $cpu=( $ss[1] =~ /\[(\d+)\]/ )[0] + 0; # or $_
  $ktime=( $ss[2] =~ /([\d\.]+)/ )[0];
  $time=sprintf("%.06f",$ktime-$startts);
  $ppos=$ss[5];
  $aptr=( $ss[7] =~ /a:(\d+)/ )[0]; # or $_
  $hptr=( $ss[8] =~ /h:(\d+)/ )[0]; # or $_
  $rdly=( $ss[9] =~ /d:(\d+)/ )[0]; # or $_
  $av=( $ss[10] =~ /av:(\d+)/ )[0]; # or $_
  $hav=( $ss[11] =~ /hav:(\d+)/ )[0]; # or $_
  $bufsize=$av+$hav;
  if ($_ =~ /_pointer.*_elapsed/) { $ftype=3; } else { $ftype=2; };
  #print join(" - ", $time,$ktime,$cpu,$proc,$pid,$strm,$ppos,$aptr,$hptr,$rdly,$av,$hav,$bufsize,@ss),"\n";
  print join(",", $time,$ktime,$cpu,$proc,$pid,0,$ftype,mIRQ,0,$ppos,$aptr,$hptr,$rdly,$strm) ,"\n";
}
' $ix/$inf > $ix/$ic
    done
    exit
  fi
  if [ "$TYPE" == "adbg" ] ; then
    for ix in $(ls -d c*/); do
      set -x
      CAPTDIR=${ix%%/}
      CURDTEST=$(basename `echo $CAPTDIR/*.dat` | sed 's/trace-\(.*\)\.dat/\1/')
      set +x
      adbg_parse
    done
    exit
  fi
fi


# START LOGFILE+TERMINAL REDIRECT
# do a redirect, to capture output of this script to log:
# backup the original filedescriptors, first
# stdout (1) into fd6; stderr (2) into fd7
exec 6<&1
exec 7<&2
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
#~ exec > >(stdbuf -i0 -o0 tee test.log)
exec > >(tee run-audacity-test.log)
# Redirect stderr (2) into stdout (1)
# (Without this, only stdout would be captured - i.e. your
# log file would not contain any error messages.)
exec 2>&1



# call as regular user - so as to have correct username for changing permissions!
# (then may be asked for sudo password later)
MESELF=`whoami`

KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system
PAPATH="/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19" # path to portaudio

# debug portaudio lib:
PALIB="$PAPATH/lib/.libs/libportaudio.so.2.0.0"

# playback file for full-duplex test
# note that even if specified on command line of Audacity, it
# still counts as an Import command, which can be undoed;
# and thus will trigger a warning, upon Audacity quit, for saving a project!
PLAYFILE="/media/disk2/tmp/out16s.wav"

control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  sudo bash -c "echo 0 > $KDBGPATH/tracing_on" # doesn't fire when it matters :/
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT


# test type - capture or duplex
if [ ! "$TEST" ]; then      # make settable via extern env var
  TEST="cap"     # capture only
  #~ TEST="dup"  # full-duplex
  #~ TEST="ply"  # playback only
fi

# card choice - actually, entry in Input and Output Device dropdowns
# card 0 - snd-hda-intel
# card 1 - dummy
if [ ! "$CARDNUM" ] ; then  # make settable via extern env var
  CARDNUM=0
fi

# curdtest settable only for cardnum 1 (if it is 'ftaudard' instead of dummy)
if [ $CARDNUM == 0 ]; then
  CURDTEST="hda-intel"
elif [ $CARDNUM == 1 ]; then
  if [ ! "$CURDTEST" ] ; then  # make settable via extern env var
    CURDTEST="dummy"
  fi
fi



# not using trace-cmd here - only printing out trace_printk's from pointer
# thus, will set nop tracing (not using function_graph)

if [ "$TYPE" == "mirq" ] ; then
PREPCMDS="
# increase ftrace buffer (was 1024, might need more for longer):
echo 2048 > $KDBGPATH/buffer_size_kb

# set for function_graph tracing
echo nop > $KDBGPATH/current_tracer

# local [default] clock - very fast and strictly per cpu, but maybe not monotonic
echo local > $KDBGPATH/trace_clock

# these have no effect for nop:
# have absolute timestamps in the function graph (disabled by default)
#echo funcgraph-abstime > $KDBGPATH/trace_options
# show TASK and PID in the function graph (disabled by default)
#echo funcgraph-proc > $KDBGPATH/trace_options

# make sure tracing is OFF at start (otherwise controlled by latency-mod.c)
echo 0 > $KDBGPATH/tracing_on

# reset anything previously in ftrace buffer
echo > $KDBGPATH/trace
"
fi

# get snd_pcm_playback_poll / snd_pcm_capture_poll (snd_pcm_start may not fire, pre_start will, and do_start seems it will)
# cat $KDBGPATH/available_filter_functions | grep snd_pcm | grep poll
# also for adbg, make sure xrun_debug is enabled
# sudo bash -c 'echo $((8+16+1+2)) > /proc/asound/card1/pcm0p/xrun_debug'
if [ "$TYPE" == "adbg" ] ; then
case $TEST in
  cap) TCSEL="c" ;;
  ply) TCSEL="p" ;;
  dup) TCSEL="{c,p}" ;;
  *) TCSEL="-" ;; # so it causes error
esac
PREPCMDS="
echo 0 > $KDBGPATH/tracing_on
echo > $KDBGPATH/trace
echo 2048 > $KDBGPATH/buffer_size_kb
echo function > $KDBGPATH/current_tracer
echo 0 > $KDBGPATH/options/func_stack_trace
echo global > $KDBGPATH/trace_clock
echo snd_pcm_do_start snd_pcm_playback_poll snd_pcm_capture_poll > $KDBGPATH/set_ftrace_filter
cat $KDBGPATH/set_ftrace_filter
for ix in $(eval echo /proc/asound/card*/pcm*$TCSEL/xrun_debug); do
  # note: dollar for ix MUST be escaped here (looped var inside a string!)
  echo $((8+16+1+2)) > \$ix ;
  echo \$ix \$(cat \$ix)
done
"
fi


# not much we can do with executable command;
# simply set up to run with debug portaudio lib,
# and add playfile on command-line if doing a full-duplex test
# (no need to run with sudo, as we don't manipulate ftrace from there)
EXECMD="LD_PRELOAD=$PALIB audacity"
if [ "$TEST" == "dup" -o "$TEST" == "ply" ]; then
  EXECMD="LD_PRELOAD=$PALIB audacity $PLAYFILE"
fi

# for hardware breakpoint; audacity needs to run with sudo;
# but that will mess up environment variables, audacity doesn't even run;
# this is the trick with gksu:
# (NB: sudo ls from the calling shell should make it skip asking)
#~ HWBP=1 # hardware breakpoint - set externally only
# do not eval here - does not work - see below
#~ if [ $HWBP == 1 ]; then
  #~ EXECMD="gksu \"bash -c '(LD_PRELOAD=/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19/lib/.libs/libportaudio.so.2.0.0 audacity 2>&1)'\""
  #~ if [ "$TEST" == "dup" -o "$TEST" == "ply" ]; then
    #~ EXECMD="gksu \"bash -c '(LD_PRELOAD=/media/disk/src/audacity-1.3.13/lib-src/portaudio-v19/lib/.libs/libportaudio.so.2.0.0 audacity /media/disk2/tmp/out16s.wav 2>&1)'\""
  #~ fi
#~ fi


function do_run {

# not really using syslog here - however, do copy it;
# because sometimes kernel can see a bug during trace,
# after which the traces are invalid.
# NOTE: due to changes of dropdowns in audacity;
# output from dummy may appear in syslog (without any hda-intel), even if we're using hda-intel!
sudo bash -c "echo 0 > /var/log/syslog"

# reset ftrace too:
sudo bash -c "echo > $KDBGPATH/trace"

#~ if [ $HWBP == 1 ]; then
  #~ set -x
  #~ gksu "bash -c '($EXECMD 2>&1) &> /dev/shm/trace$TEST-$CURDTEST.log'"
  #~ PID=$!
  #~ set +x
#~ else
# must have eval here - else the LD_PRELOAD is a problem!
  set -x
  eval "$EXECMD" &> /dev/shm/trace$TEST-$CURDTEST.log &
  PID=$!
  set +x
#~ fi

WINREP=""
while [[ ! "`echo $WINREP | grep -l 'Map State: IsViewable'`" ]] ; do
  WINREP=$(xwininfo -name 'Audacity')
  #echo $WINREP
  sleep 0.1
done

WINID=$(wmctrl -l | grep Audacity | awk '{print $1;}')
# also: xdotool search --onlyvisible --name 'Audacity' | printf "0x%08x\n" `cat`
# but it is case insensitive, so may catch extra windows with "audacity" in name (script editor)
echo "Audacity (pid $PID, window $WINID) loaded"

# must use -F here for case-insensitive, to ensure proper window targetting
# position and resize
wmctrl -v -F -r "Audacity" -e 0,0,0,800,600
sleep 0.5

# use xdotool getmouselocation --shell to find x/y locations of GUI widgets
# (the below are specific for GUI as it looks on my playtform)
# note the dropdown choices are relative to current selection! so use keys to navigate
# use `xev` to find key names (e.g. it is Prior, not page_up)

# x:92 y:73 - play
# x:142 y:69 - stop
# x:300 y:68 - record
# x:315 y:137 - Output Device dropdown (x:315 y:157 second entry); -20 pix titlebar
# x:475 y:137 - Input Device dropdown  (x:475 y:157 second entry); -20 pix titlebar
# key Space - toggle play/stop
# key r/R - record

# just in case, focus window (hex accepted):
xdotool windowactivate --sync $WINID
sleep 0.5

# window MUST be activated for keypress to work; from terminal, must do:
# xdotool windowactivate --sync 0x04c00587 ; xdotool key --window 0x04c00587 space

# set cardnum device
# NOTE, do NOT have heavy processes (eog with animated .gifs, firefox) in the background - then increasing CLISLP doesn't help much!
CLISLP=0.2 # 0.2 was too slow, but ok now; sometimes glitch, then increase
DROPYLOC=$(( 137 - 20 ))

# set output device: click on dropdown
xdotool mousemove --window $WINID --sync 315 $DROPYLOC
sleep $CLISLP
xdotool click --window $WINID 1
sleep $CLISLP
# set output device: move and choose in dropdown; don't click - use keys
#~ xdotool mousemove --window $WINID --sync 315 $(( 117 + CARDNUM*20 ))
#~ sleep $CLISLP
#~ xdotool click --window $WINID 1
#~ sleep $CLISLP
xdotool key --window $WINID Prior #page_up
sleep $CLISLP
for (( ix=0; ix<CARDNUM; ix++ )); do
  xdotool key --window $WINID Down #down
  sleep $CLISLP
done
xdotool key --window $WINID Return #return
sleep $CLISLP


# set input device: click on dropdown
xdotool mousemove --window $WINID --sync 475 $DROPYLOC
sleep $CLISLP
xdotool click --window $WINID 1
sleep $CLISLP
# set input device: move and choose in dropdown; don't click - use keys
#~ xdotool mousemove --window $WINID --sync 475 $(( 117 + CARDNUM*20 ))
#~ sleep $CLISLP
#~ xdotool click --window $WINID 1
#~ sleep $CLISLP
xdotool key --window $WINID Prior #page_up
sleep $CLISLP
for (( ix=0; ix<CARDNUM; ix++ )); do
  xdotool key --window $WINID Down #down
  sleep $CLISLP
done
xdotool key --window $WINID Return #return
sleep $CLISLP

# start trace here
sudo bash -c "echo 1 > $KDBGPATH/tracing_on"

# start record (or playback):
if [ "$TEST" == "ply" ]; then
  xdotool key --window $WINID space
else
  xdotool key --window $WINID r
fi

# wait 1 sec - records 320 ms on my platform, but now can do more (though less than 1s)
# even 0.5 seems fine now; also 0.3
# note - for sleep 0.3 here, dummy-fix reaches nearly 0.3, but hda_intel reaches only max 0.2; try make conditional
TESTSLP=0.3
if [ $CARDNUM == 0 ] ; then
  sleep $(echo $TESTSLP + 0.12 | bc) ;
else sleep $(echo $TESTSLP + 0.03 | bc) ; fi

# stop record
xdotool key --window $WINID space

# wait X sec
sleep 1

# stop trace here
sudo bash -c "echo 0 > $KDBGPATH/tracing_on"

# perform an undo of the record, so Audacity doesn't prompt to save project on exit
xdotool key --window $WINID ctrl+z

# wait X sec
sleep 0.5

# one more undo for the playback Import file in case of full-duplex (or playback)
if [ "$TEST" == "dup" -o "$TEST" == "ply" ]; then
  xdotool key --window $WINID ctrl+z

  # wait X sec
  sleep 0.5
fi

# kill audacity - exit rather; with kill Audacity will prompt for recover project at start
#kill $PID
xdotool key --window $WINID ctrl+q

# wait X sec
sleep 0.5

mv /dev/shm/trace$TEST-$CURDTEST.log trace$TEST-$CURDTEST.log

} # end function do_run

function get_run_logs {

set -x
# can't use trace_pipe here, as it blocks; use usual trace
sudo cat $KDBGPATH/trace > trace-o-$CURDTEST.txt # get ('original') trace first - that doesn't empty the buffer

# copy the syslog (to check for possible kernel bugs there)
cp /var/log/syslog tracing-$CURDTEST.syslog
set +x

} # end function get_run_logs





echo "Doing test: audacity $TEST $CURDTEST $TYPE"

# prepare kernel trace
sudo bash -c "$PREPCMDS"
sudo cat $KDBGPATH/current_tracer


#~ do_run
# actually, run until condition is NOT satisfied anymore:
# (do NOT use grep -lv, that inverts matching *lines*; use grep -L to negate detection per whole file!)

WCOND="grep -l '[Xx]run' trace$TEST-$CURDTEST.log" # [Xx]run stronger than 'Drop Input'; run until does not have...

while : ; do
  rm -f trac*{log,txt} # silently remove possible previous logfiles
  do_run
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


# collect all logs (from this run only) in a subfolder;
CAPTDIR="capt${TEST:0:3}-`date +%F-%H-%M-%S`"

# since now this is a single test, also add
# identifier (first three characters) to folder name:
CAPTDIR="${CMARK}${CAPTDIR}-${CURDTEST:0:3}"


set -x
mkdir $CAPTDIR
mv trac*{log,txt} $CAPTDIR/
set +x



# append buffer_size; period_size (calc. from avail/hw_avail) to *.log
# (reads from custom driver printout with caller!)
perl -ne '
if ($_ =~ /_pointer.*_elapsed/) {
  @ss=split(" ",$_);
  @s1m=split("-",$ss[0]); $proc=$s1m[0]; $pid=$s1m[1];
  $strm=( $ss[6] =~ /\((\d)\)/ )[0]; # or $_
  $cpu=( $ss[1] =~ /\[(\d+)\]/ )[0] + 0; # or $_
  $ktime=( $ss[2] =~ /([\d\.]+)/ )[0];
  $time=sprintf("%.06f",$ktime-$startts);
  $ppos=$ss[5];
  if (!(defined($firstppos))) {
    $firstppos = $ppos;
  }
  $aptr=( $ss[7] =~ /a:(\d+)/ )[0]; # or $_
  $hptr=( $ss[8] =~ /h:(\d+)/ )[0]; # or $_
  $rdly=( $ss[9] =~ /d:(\d+)/ )[0]; # or $_
  $av=( $ss[10] =~ /av:(\d+)/ )[0]; # or $_
  $hav=( $ss[11] =~ /hav:(\d+)/ )[0]; # or $_
  $bufsize=$av+$hav;
  $pperb = int(($bufsize/$firstppos) + 0.5); #round
  $prdsize = $bufsize/$pperb;
  #print join(" - ", $ppos,$av,$hav,$bufsize,$pperb,$prdsize),"\n";
  print "  buffer_size  : $bufsize
  period_size  : $prdsize
";
  exit; # print just based on first one
};
' $CAPTDIR/trace-o-$CURDTEST.txt | tee -a $CAPTDIR/trace$TEST-$CURDTEST.log


if [ "$TYPE" == "mirq" ] ; then
# parse into .csv (only mIRQs here):
perl -ne '
if (!(defined($startts))) {
  if ($_ =~ /_start/) {
    @ss=split(" ",$_);
    $startts=( $ss[2] =~ /([\d\.]+)/ )[0];
    #$strm=( $_ =~ /\((\d)\)/ )[0];
    print "# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr,13_rdly,14_strm\n";
  }
}
if ($_ =~ /_pointer.*_elapsed/) {
  @ss=split(" ",$_);
  @s1m=split("-",$ss[0]); $proc=$s1m[0]; $pid=$s1m[1];
  $strm=( $ss[6] =~ /\((\d)\)/ )[0]; # or $_
  $cpu=( $ss[1] =~ /\[(\d+)\]/ )[0] + 0; # or $_
  $ktime=( $ss[2] =~ /([\d\.]+)/ )[0];
  $time=sprintf("%.06f",$ktime-$startts);
  $ppos=$ss[5];
  $aptr=( $ss[7] =~ /a:(\d+)/ )[0]; # or $_
  $hptr=( $ss[8] =~ /h:(\d+)/ )[0]; # or $_
  $rdly=( $ss[9] =~ /d:(\d+)/ )[0]; # or $_
  $av=( $ss[10] =~ /av:(\d+)/ )[0]; # or $_
  $hav=( $ss[11] =~ /hav:(\d+)/ )[0]; # or $_
  $bufsize=$av+$hav;
  #print join(" - ", $time,$ktime,$cpu,$proc,$pid,$strm,$ppos,$aptr,$hptr,$rdly,$av,$hav,$bufsize,@ss),"\n";
  print join(",", $time,$ktime,$cpu,$proc,$pid,0,3,mIRQ,0,$ppos,$aptr,$hptr,$rdly,$strm) ,"\n";
}
' $CAPTDIR/trace-o-$CURDTEST.txt > $CAPTDIR/trace-$CURDTEST.csv
fi


if [ "$TYPE" == "adbg" ] ; then
adbg_parse
fi



echo -e "\nFinished run-audacity-test in $CAPTDIR/"

# STOP LOGFILE+TERMINAL REDIRECT
# close and restore backup; both stdout and stderr
exec 1<&6 6<&-
exec 2<&7 2<&-
# Redirect again stderr (2) into stdout (1); else echoes to stderr wouldn't show in terminal!
exec 2>&1
# **must** sleep here - allow tee to catch up and terminate:
sleep 0.01

set -x ; mv run-audacity-test.log $CAPTDIR/ ; set +x

if [ $HWBP == 1 ]; then # running under sudo; chown
  # under sudo, MESELF is root! $SUDO_USER worksforme to get original caller
  set -x ;  sudo chown -R $SUDO_USER:$SUDO_USER $CAPTDIR ; set +x
fi

echo -e "\n copy/paste if manual deletion is needed:"
echo -e "  rm -rf $CAPTDIR/"

