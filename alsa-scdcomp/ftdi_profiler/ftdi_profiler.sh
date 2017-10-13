################################################################################
# ftdi_profiler.sh                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# driver:
# sudo modprobe usbserial
# sudo insmod ./ftdi_profiler.ko

PARAMDIR="/sys/module/ftdi_profiler/parameters"
KDBGPATH="/sys/kernel/debug/tracing" # path to ftrace kernel debug system
MESELF=`whoami`

# do NOT escape spaces, etc when setting KSTCMD like this!
# KSTCMD="/home/$MESELF/.wine/dosdevices/c\:/Program\ Files/Kst\ 2.0.7/bin/kst2.exe"
# but then, have to call this quoted:
KSTCMD="/home/$MESELF/.wine/dosdevices/c:/Program Files/Kst 2.0.7/bin/kst2.exe"

KSTFILE="/media/disk/path/ftdi_profiler.kst"
MTUPFILE="/media/disk/path/multitrack_user.py"
# this kernel only has local and global clock (no uptime);
# usbmon apparently provides uptime in milliseconds;
# so we have to assume milliseconds are proper, and adjust the whole seconds? Or just pipe directly to ftrace
# 16384 seems ok for just trace; but not ok with usbmon added..
PREPCMDS="
# increase ftrace buffer (was 1024, might need more for longer):
echo 32768 > $KDBGPATH/buffer_size_kb

# set for function_graph tracing
echo nop > $KDBGPATH/current_tracer

# local [default] clock - very fast and strictly per cpu, but maybe not monotonic
echo local > $KDBGPATH/trace_clock

# reset anything previously in ftrace buffer
echo > $KDBGPATH/trace
"
# 84128/ 84145
arate=$((44100*4))
durnf=30.532001589
durnf_s=$(wcalc -q -P0 "floor($durnf)")
durnf_ns=$(wcalc -q -EE -P0 "($durnf-$durnf_s)*1E9")

# for DIRNAME in `ls -d ftdi*/` ; do DIRNAME=${DIRNAME%%/}; cd $DIRNAME; DIRNAME=$DIRNAME bash ../ftdi_profiler.sh parse_data ; wine /home/$MESELF/.wine/dosdevices/c\:/Program\ Files/Kst\ 2.0.7/bin/kst2.exe rep.kst ; cd .. ; done
# note: kst png export from command line is always fixed size (seems 640x480? or 1280x540)!
# for DIRNAME in `ls -d ftdi*/` ; do DIRNAME=${DIRNAME%%/}; cd $DIRNAME; wine /home/$MESELF/.wine/dosdevices/c\:/Program\ Files/Kst\ 2.0.7/bin/kst2.exe --png rep.png rep.kst ; cd .. ; done
# note awk concatenation for double quotes: $ echo aaa | awk "BEGIN{a=0; print \$0\"X\";}"' END {print "Z"a;}'
# awk now requires bpw in reparse:
# for DIRNAME in `ls -d ftdi*/` ; do DIRNAME=${DIRNAME%%/}; cd $DIRNAME; DIRNAME=$DIRNAME bpw=${DIRNAME##*_} bash ../ftdi_profiler.sh parse_data ; wine /home/$MESELF/.wine/dosdevices/c\:/Program\ Files/Kst\ 2.0.7/bin/kst2.exe --png rep.png rep.kst ; cd .. ; done

function parse_data() {
  echo $DIRNAME
  #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt"]
  #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt", "wrdlt", "wbps", "rbps"]
  # terminate last of these with return to zero for fillcurve style? Doesn't really work for gnuplot/chaco; kst is ok
  # first make a big calculated table - then cut from it only columns we care for
  #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt", "wrdlt", "wbps", "rbps", "wftq"]
  # check choice via bash (so [[ ]]) regex
  DOSTEP="ab" # "a" "b" "ab" "abc" ; "" for none

  if [[ "$DOSTEP" =~ [a] ]]; then
  awk 'BEGIN{sbot=0;cbit=0;ocstmp=0;ooct=0;} /^[^#]/ {
  if(!sts){sts=substr($3,1,length($3)-1);}
  cpu=substr($2,2,length($2)-2)+0;ts=substr($3,1,length($3)-1);
  if (/ftdi_profiler_proc_show/){ # fid=0
    sts=substr($3,1,length($3)-1);
    printf("%.6f %.6f %d %d %s %s %d %d %d %d\n", ts-sts,ts,cpu,0,-1,-1,-1,-1,-1,-1);
  }
  if (/ftdi_profiler_wrtasklet_func/){ # fid=1
    printf("%.6f %.6f %d %d %s %s %d %d %d %d\n", ts-sts,ts,cpu,$5,$6,$7,$8,$9,$10,$11);
  }
  if (/ftdi_read_bulk_callback/){      # fid=2
    # nb: profiler now picks up ALL data from ftdi.. limit by length
    if($8>2) {
    printf("%.6f %.6f %d %d %s %s %d %d %d %d\n", ts-sts,ts,cpu,$5,$6,$7,$8,$9,$10,$11);
  }}
  if (/ S Bo/){                        # fid=3
    # len is $10; count here == usbmon tstamp ($6)
    sbot+=$10;
    cstmp=sprintf("%12.06f",$6/1000000);
    if(!ocstmp) {ocstmp=cstmp;}
    printf("%.6f %.6f %d %d %s %s %d %s %d %.6f\n", ts-sts,ts,cpu,3,"-1",$9,$10,cstmp,sbot,cstmp-ocstmp+ooct);
  }
  if (/ C Bi/){                       # fid=4
    # len is $10 here too - check for plain status
    if($10>2) {
    cbist0=substr($12,1,2);
    cbist1=substr($12,3,2);
    cbit+=$10;
    cstmp=sprintf("%12.06f",$6/1000000);
    if(!ocstmp){ocstmp=cstmp;}
    printf("%.6f %.6f %d %d %s %s %d %s %d %.6f\n", ts-sts,ts,cpu,4,cbist0,cbist1,$10,cstmp,cbit,cstmp-ocstmp);
  }}
  }' reptrace.txt > rep.txt
  fi
  if [[ "$DOSTEP" =~ [b] ]]; then #
    # now repz - only events 1 and 2 (else time vectors tend to screw up for kst as it is?)
    awk "BEGIN{bpw=$bpw;fbps=200000;ftpd=bpw/fbps;abps=$arate;apd=bpw/abps;ftq=0;tsp=0;}"\
' /^[^#]/ {if($4==1){wrtot=$9;tsd=$1-tsp;tsdb=(tsd/ftpd)*bpw; ftqh=ftq-tsdb; ftqhb=bpw-tsdb; ftqhh= (ftqh<0)?0+bpw:( (ftqhb<0)?ftqh+bpw:ftq+ftqhb); ftq=ftqhh; tsp=$1;} if($4==2){rdtot=$9;} if(($4>0) && ($4<3)) {ts=$1;ots=$2; printf("%s %d %d %d %d\n",$0,int(wrtot)-int(rdtot), wrtot/$1, rdtot/$1, ftq); }} END{printf("%.6f %.6f 0 0 0 0 0 0 0 0 0 0 0 0\n", ts+0.000001, ots+0.000001)}' rep.txt > repz.txt
    echo "Checking repz.txt counts:"
    awk 'BEGIN{cnt[1]=0;cnt[2]=0;cntk[1]=0;cntk[2]=0;} { if(($4==1) || ($4==2)){dlt=$8-cnt[$4]; if(dlt!=1){print "f",$4,"d",dlt,"c",$8,"k",cntk[$4];cntk[$4]+=1;};}; cnt[$4]=$8; } END{print "f1",cntk[1],"f2",cntk[2];}' repz.txt
    echo "Checking overruns:"
    awk '{n=strtonum("0x" $6);if(and(rshift(n,1),1)){print;};}' repz.txt > rep2o.txt
    cat rep2o.txt
  fi
  if [[ "$DOSTEP" =~ [c] ]]; then #
    # put both timestamps and req.d value in "channel" files:
    awk '{print $1, $11;}' repz.txt > rep_wrdlt_z.txt
    # now adding $14 to this file as col 6 - but won't change the filename
    awk '{if($4==1){print $1, $9, int($9)%2048, $10, $12, $14;}}' repz.txt > rep_wtot_wtmd_wdlt_wbps_1.txt
    # adding delays as col 6 - but won't change the filename
    awk '{if($4==2){ if(!p){dl=0;p=$1;}else{dl=$1-p;p=$1;} print $1, $9, int($9)%2048, $7, $13, sprintf("%.6f",dl);}}' repz.txt > rep_rtot_rtmd_rlen_rbps_2.txt
  fi
  # both / as end of subpath and " as end of attribute must go in the sed!:
  #cat $KSTFILE | sed "s|ftdiprof\-[^/\"]*|${DIRNAME}|g" > rep.kst
  # try to figure out the directory to replace in rep.kst - full path
  # we're either in parent dir, if called from capture - or inside the dir, if reparsing
  # get the full path of current dir - then if it doesn't contain DIRNAME; append it
  if [[ "$PWD" =~ "$DIRNAME" ]]; then CDIR="$PWD"
  else CDIR="$PWD/$DIRNAME" ; fi
  # | sed 's/ count="[^"]*"/ count="200000"/g'
  cat $KSTFILE \
    | sed 's/ count="[^"]*"/ count="200000"/g' \
    | sed "s|file=\(\"[^/]*\)/\([^\"]*\)/|file=\1${CDIR}/|g" > rep.kst
}

function parse_data_oldA {

  awk '/^[^#]/ {if($4==1){ts=$1;ots=$2;print;}} END{printf("%.6f %.6f 0 0 0 0 0 0 0 0\n", ts+0.000001, ots+0.000001)}' rep.txt > rep1.txt
  awk '/^[^#]/ {if($4==2){ts=$1;ots=$2;print;}} END{printf("%.6f %.6f 0 0 0 0 0 0 0 0\n", ts+0.000001, ots+0.000001)}' rep.txt > rep2.txt
  awk '/^[^#]/ {if($4==1){wrtot=$9;} if($4==2){rdtot=$9;} ts=$1;ots=$2; print $1,$2,int(wrtot),int(rdtot),int(wrtot)-int(rdtot); } END{printf("%.6f %.6f 0 0 0 0 0 0 0 0\n", ts+0.000001, ots+0.000001)}' rep.txt > repd.txt
  # check with bitmask here, if ftdi overrun happened
  awk '// {if($10>maxd){maxd=$10;}} END{print "# max rep1 " maxd;}' rep1.txt > rep2o.txt
  awk '// {if($5>maxd){maxd=$5;}} END{print "# max repd " maxd;}' repd.txt >> rep2o.txt
  awk '{n=strtonum("0x" $6);if(and(rshift(n,1),1)){print;};}' rep2.txt >> rep2o.txt

}

function do_grab() {
for ((ib=1;ib<=1;ib++)); do
  stty 2000000 inpck -ixon -icanon -hupcl -isig -iexten -echok -echoctl -echoke min 0 -crtscts -echo -echoe -echonl -icrnl -onlcr cstopb -opost </dev/ttyUSB0
  bpw=$((ib*64)) # 128 256
  per_nsec=$(( bpw*1000000000 / arate ))
  echo bytes_per_write $bpw write_period_ns $per_nsec dur_s $durnf_s dur_ns $durnf_ns
  sudo bash -c "$PREPCMDS"
  sudo bash -c "echo $bpw > $PARAMDIR/bytes_per_write"
  sudo bash -c "echo $per_nsec > $PARAMDIR/write_period_ns"
  sudo bash -c "echo $durnf_s > $PARAMDIR/test_duration_s"
  sudo bash -c "echo $durnf_ns > $PARAMDIR/test_duration_ns"
  echo `cat $PARAMDIR/bytes_per_write` `cat $PARAMDIR/write_period_ns` `cat $PARAMDIR/test_duration_s` `cat $PARAMDIR/test_duration_ns`
  STARTTS="`date +%F-%H-%M-%S`"
  #~ usbpid=$(sudo bash -c 'cat /sys/kernel/debug/usb/usbmon/2u > /sys/kernel/debug/tracing/trace_marker & echo $!')
  usbpid=$(sudo bash -c 'cat /sys/kernel/debug/usb/usbmon/2u > repusbmon.txt & echo $!')
  cat /proc/ftdi_profiler | tee rep.txt
  sleep $(wcalc -q $durnf+1)
  sudo kill $usbpid
  sudo chown $MESELF:$MESELF repusbmon.txt
  #sudo cat /sys/kernel/debug/tracing/trace | awk '/^[^#]/ {if(!sts){sts=substr($3,1,length($3)-1);}else{cpu=substr($2,2,length($2)-2)+0;ts=substr($3,1,length($3)-1);printf("%.6f %.6f %d %d %d %d %d %d %d %d\n", ts-sts,ts,cpu,$5,$6,$7,$8,$9,$10,$11);} }' >> rep.txt
  #names=["ts", "ots", "cpu", "fid", "st0", "st1", "len", "count", "tot", "dlt"]
  sudo cat /sys/kernel/debug/tracing/trace > reptrace.txt
  DIRNAME=ftdiprof-${STARTTS}_${bpw}
  parse_data
  mkdir $DIRNAME
  mv rep*.{txt,kst} $DIRNAME/
  #echo "gnuplot -e \"fdir='$DIRNAME';\" ftdi_profiler.gp -"
  echo 'wine "'"$KSTCMD"'"' $DIRNAME/rep.kst
  echo 'or use '"$MTUPFILE"
done
}

$1

