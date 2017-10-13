#!/usr/bin/env bash
################################################################################
# collectmirq.sh                                                               #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  sudo bash -c "echo 0 > $KDBGPATH/tracing_on" # doesn't fire when it matters :/
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT


if [ "$1" == "run" ]; then
NUMRUNSTEST=10
LOGFILE="collectmirq.log"
STARTTS="`date +%F-%H-%M-%S`"

echo "Starting collectmirq.sh at $STARTTS" | tee -a $LOGFILE


pass=0;
NOGP=1;
if [ ! "$CARDNUM" ] ; then
  CARDNUM=1; # also specify cardnum
fi
for BSZ in {128,256,512,1024,2048}; do # buffer size; don't use 64,
  for EXECT in {latency,patest_duplex_wire}; do
    for (( ix=1; ix<=$NUMRUNSTEST; ix++ )); do
      # LATLF=256 #128 # latency (min==max; =buffer_size) in frames - period size is half that: buffer_size  : 256; period_size  : 128
      # PATBF=256   # frames_per_buffer/callback - this ends up being period size! buffer_size  : 512; period_size  : 256
      PREP="Running pass $(( ++pass ))" # global var assignment doesn't work in pipe; must like this
      echo $PREP | tee -a $LOGFILE
      # to skip with cmark numbering intact (comment if unneeded)
      # (must have space after the negation `!` !!)
      #if [[ ! ( ($BSZ -eq 256) && ($EXECT == "latency") ) ]] ; then
      #if [[ ! ( ($BSZ -eq 128) && ($EXECT == "latency") ) ]] ; then
      #~ if [[ ! ( ($BSZ -eq 2048) ) ]] ; then
        #~ continue
      #~ fi
      CMARK=$(printf "c%03d" $pass)
      PSZ=$((BSZ/2)) # period size half buffer size
      DDF=$((BSZ*2)) # duration in frames twice buffer size
      if [ "$EXECT" == "latency" ]; then
        set -x
        EXECT=$EXECT CMARK=$CMARK NOGP=$NOGP LATLF=$BSZ LATDF=$DDF CARDNUM=$CARDNUM COLMIRQ=1 bash run-alsa-lattest.sh | tee -a $LOGFILE
        set +x
      fi
      if [ "$EXECT" == "patest_duplex_wire" ]; then
        set -x
        EXECT=$EXECT CMARK=$CMARK NOGP=$NOGP PATBF=$PSZ PATDF=$DDF CARDNUM=$CARDNUM COLMIRQ=1 bash run-alsa-lattest.sh | tee -a $LOGFILE
        set +x
      fi
    done
  done
done

echo "Ended collectmirq.sh at `date +%F-%H-%M-%S`" | tee -a $LOGFILE

# remove "Parsed line" from python script
sed -i '/Parsed line/d' collectmirq.log
fi # "$1" == "run"



# for audacity

if [ "$1" == "acityrun" ]; then
NUMRUNSTEST=1 #10
LOGFILE="collectmirq-acity.log"
STARTTS="`date +%F-%H-%M-%S`"

echo "Starting collectmirq.sh (audacity) at $STARTTS" | tee -a $LOGFILE

pass=0;
#CARDNUM=1; # also specify cardnum
# better to specify a test, and to iterate cardnum (because those are we comparing)
# cap: capture only; dup: full-duplex
if [ ! "$TEST" ]; then      # make settable via extern env var
  TEST="cap"     # capture only
  #~ TEST="dup"  # full-duplex
  #~ TEST="ply"  # playback only
fi

if [ ! "$TYPE" ] ; then  # make settable via extern env var
  TYPE="mirq"
  #TYPE="adbg" # with alsa-driver debug kernel modules (different parser)
fi

# hardware breakpoint - set externally only
# run gksu once, so it remembers the password in this shell as parent
# NOTE - there is bug on Natty with gksu;
# [https://bugs.launchpad.net/ubuntu/+source/gksu/+bug/783129 Bug #783129 “gksu doesn't remember password on Natty” : Bugs : “gksu” package : Ubuntu]
# try this:
#~ sudo bash -c "echo 'Defaults:ALL timestamp_timeout=5' >> /etc/sudoers" # nope
# note gksu will be/is removed; http://askubuntu.com/questions/284306/why-is-gksu-no-longer-installed-by-default-in-13-04
# for a command line case like this, sudo -H audacity will work (just sudo audacity messes up)!
# sudo -E makes problem with audacity - so will have to use env inside (note - no quotes there!)

if [ $HWBP == 1 ]; then
  sudo echo "HWBP is $HWBP"
fi

#~ for TEST in {cap,dup}; do
for CARDNUM in {0,1}; do
  for (( ix=1; ix<=$NUMRUNSTEST; ix++ )); do
    PREP="Running pass $(( ++pass ))" # global var assignment doesn't work in pipe; must like this
    echo $PREP | tee -a $LOGFILE
    CMARK=$(printf "c%03d" $ix) # $pass)
    if [ $HWBP == 1 ]; then
      set -x
      sudo -H env CARDNUM=$CARDNUM CMARK=$CMARK TEST=$TEST TYPE=$TYPE HWBP=$HWBP CURDTEST=$CURDTEST bash run-audacity-test.sh | tee -a $LOGFILE
      set +x
    else
      set -x
      CARDNUM=$CARDNUM CMARK=$CMARK TEST=$TEST TYPE=$TYPE HWBP=$HWBP CURDTEST=$CURDTEST bash run-audacity-test.sh | tee -a $LOGFILE
      set +x
    fi
  done
done

fi # "$1" == "acityrun"


# for latency - p/c delay calc with different period sizes per buffer

if [ "$1" == "dltpszrun" ]; then
NUMRUNSTEST=1
LOGFILE="collectmirq.log"
STARTTS="`date +%F-%H-%M-%S`"

echo "Starting collectmirq.sh (dltpszrun) at $STARTTS" | tee -a $LOGFILE

pass=0;

#~ for BSZ in {1024,2048,4096,8192}; do # buffer size; audacity typ. 4096
  #~ for (( PSZ=256;PSZ<BSZ;PSZ*=2 )); do
for BSZ in {4416,}; do # buffer size; audacity typ. 4096
  for (( PSZ=1104;PSZ<BSZ;PSZ*=2 )); do
    for (( ix=1; ix<=$NUMRUNSTEST; ix++ )); do
      PREP="Running pass $(( ++pass ))" # global var assignment doesn't work in pipe; must like this
      echo $PREP | tee -a $LOGFILE
      CMARK=$(printf "c%03d" $ix) # $pass)
      DDF=22050 # duration in frames - half second
      EXECT="latency" # only latency can change buffer+period sizes (with LATPF)
      CARDNUM=0 # only interested in hda-intel here
      LATPF="--period $PSZ --skipsizecheck "
      set -x
      EXECT=$EXECT CMARK=$CMARK NOGP=$NOGP LATLF=$BSZ LATDF=$DDF LATPF="$LATPF" CARDNUM=$CARDNUM COLMIRQ=1 bash run-alsa-lattest.sh | tee -a $LOGFILE
      set +x
    done
  done
done

sed -i '/Parsed line/d' collectmirq.log
fi # "$1" == "dltpszrun"




# part II: extract mIRQs:


if [ "$1" == "exm1" ]; then
for ix in c*capt*/; do
  echo -n $ix,;                                                           # name
  echo -n `awk '/buffer_size  :/{print $3; exit}' $ix/trace*.log`,;       # buffer size
  echo -n `awk '/period_size  :/{print $3; exit}' $ix/trace*.log`,;       # period size
  awk -F, '{if($7==3 && $14>=-1){printf("%s,%s,",$1,$14);}}' $ix/*.csv ;  # mIRQ time and type
  echo;
done > collectmirq.csv

# gnuplot -p collectmirq.gp
fi # "$1" == "exm1"


# with pointers
if [ "$1" == "exm2" ]; then
for ix in c*capt*/; do
  echo -n $ix,;                                                           # name
  echo -n `awk '/buffer_size  :/{print $3; exit}' $ix/trace*.log`,;       # buffer size
  echo -n `awk '/period_size  :/{print $3; exit}' $ix/trace*.log`,;       # period size
  awk -F, '{if($7==3 && $14>=-1){printf("%s,%s,",$1,$14);};if($7==2){printf("%s,%s,",$1,$14+3);}}' $ix/*.csv ;  # mIRQ time and type
  echo;
done > collectmirqp.csv

awk -F, '{print NF;}' collectmirq.csv | sort -n -r | head -n 1 # number of columns

# gnuplot -p -e 'fname="collectmirqp.csv";mcol=80;ptype=2;' collectmirq.gp

awk -F, 'BEGIN{fn="";fi=0;n=0;dsum=0;ct=0;pt=0;dt=0;o=0;} {if(fn!=FILENAME){fn=FILENAME;fi++;ct=0;pt=0;dt=0;o=0;print fn;}; if(fi==11){n=0;dsum=0;}; if($7==3 && $14==0 && ct==0){ct=$1;}; if($7==3 && $14==1 && pt==0){pt=$1;}; if(o==0 && ct!=0 && pt!=0){o=1; dt=ct-pt; n++; dsum+=dt; avg=dsum/n; printf("c%03d: c: %.06f p: %.06f deltac-p: %.06f [s] %.02f [f] avg %.06f [s] %.02f [f]\n",fi,ct,pt,dt,dt*44100,avg,avg*44100);}; }' c*capt*/*.csv >> collectmirq.log
fi # "$1" == "exm2"


if [ "$1" == "cut" ]; then
  for ix in c*capt*/; do python traceFGLatLogfile2Csv.py -s -c 'snd_pcm_pre_start();' ${ix%%/}; done
fi # "$1" == "cut"


# for ppos extraction
if [ "$1" == "exm3" ]; then

for ix in c*capt*/; do
  echo -n $ix,;                                                           # name
  echo -n `awk '/buffer_size  :/{print $3; exit}' $ix/trace*.log`,;       # buffer size
  echo -n `awk '/period_size  :/{print $3; exit}' $ix/trace*.log`,;       # period size
  awk -F, '{if($7==3 && $14>=-1){printf("%s,%s,%s,",$1,$14,$10);}}' $ix/*.csv ;  # mIRQ time, type, ppos
  echo;
done > collectmirq.csv

awk -F, '{print NF;}' collectmirq.csv | sort -n -r | head -n 1 # number of columns

# gnuplot -p -e 'fname="collectmirq.csv";mcol=37;pltt=2;' collectmirq.gp # also pltt=3
fi # "$1" == "exm3"

# for playback-capture (pc) delta calc (oldcapt05 to oldcapt10, mostly)
# outputs directly to stdout (and takes a while)
if [ "$1" == "dlt1" ]; then

DIRCHOICE="oldcapt*"
if [ "$2" != "" ] ; then # second arg, so can set DIRCHOICE to .
  DIRCHOICE="$2"
fi

for ido in $(eval echo "$DIRCHOICE"); do
  echo "#$ido"
  # filter per hda/dummy
  for filt in {dummy,hda-intel}; do
    for ifc in $(find $ido -name '*.csv' | sort | grep $filt) ; do #-printf '%h\n' | sort -u
      idc=$(dirname $ifc)
      ibc=$(basename $ifc)
      echo "# $idc"
      bsz=""; psz="";
      for ilg in $idc/trace*.log; do
        ilog="$(echo $ilg | grep $filt)"
        if [[ -n "$ilog" ]] ; then
          ilog=$(basename $ilog)
          bsz=$(awk '/buffer_size  :/{print $3; exit}' $idc/$ilog)
          psz=$(awk '/period_size  :/{print $3; exit}' $idc/$ilog)
          break
        fi
      done
      if [[ ! -z "$ilog" && ! -z "$bsz" && ! -z "$psz" ]] ; then
        echo "#  $psz $bsz $ilog $ibc"
        # actually not - playback is $14 zero, capture is 1! so this gives opposite..
        # was $7==3, but having problems with python tracer
        retawk=$(awk -F, 'BEGIN{fn="";fi=0;n=0;dsum=0;ct=0;pt=0;dt=0;o=0;}
        {
          if($7==3 && $14==0 && ct==0){ct=$1;};
          if($7==3 && $14==1 && pt==0){pt=$1;};
          if(ct!=0 && pt!=0){
            dt=ct-pt; n++; dsum+=dt; avg=dsum/n;
            printf("c%03d: c: %.06f p: %.06f deltac-p: %.06f [s] %.02f [f] avg %.06f [s] %.02f [f]\n",
              fi,ct,pt,dt,dt*44100,avg,avg*44100);
            ct=0; pt=0;
          };
        }
        END{if(avg!=0.000000){printf("avg % 10.6f [f] % 10.6f [s]\n",avg*44100,avg);}}' $idc/$ibc)
        if [[ ! -z "$retawk" ]] ; then
          echo "$retawk" # debug
          retawkl=$(echo "$retawk" | tail -1)
          printf "% 5d % 5d %s %s %s %s\n" "$psz" "$bsz" "$retawkl" "$ibc" "$ilog" ${idc:0:12}...
        fi
      fi
    done
  done
done

# pipe this output, e.g. bash collectmirq.sh dlt1 | tee dlt1_dat.txt
# then to browse: grep -v '^#\|^c0\|^avg' dlt1_dat.txt | grep hda | less
# to printout summary:
# grep -v '^#\|^c0\|^avg' dlt1_dat.txt | grep hda | awk '{a[$1,$2,0]+=1;a[$1,$2,1]+=$4;a[$1,$2,2]=a[$1,$2,1]/a[$1,$2,0];} END{for(comb in a){split(comb,sep,SUBSEP);if(sep[3]==2){printf("% 5d % 5d avg % 10.6f [f]\n", sep[1], sep[2], a[sep[1],sep[2],2]);}}}' | sort -n -k 1
# try also: | sort -n -k 1 | gnuplot -e 'plot "-" using 1:4 with lines' -p  ;; | sort -n -k 2 | gnuplot -e 'plot "-" using 2:4 with lines' -p
fi # "$1" == "dlt1"


if [ "$1" == "dlt2" ]; then

DIRCHOICE="oldcapt*"
if [ "$2" != "" ] ; then # second arg, so can set DIRCHOICE to .
  DIRCHOICE="$2"
fi

for ido in $(eval echo "$DIRCHOICE"); do
  echo "#$ido"
  # filter per hda/dummy
  for filt in {dummy,hda-intel}; do
    for ifc in $(find $ido -name '*.csv' | sort | grep $filt) ; do #-printf '%h\n' | sort -u
      idc=$(dirname $ifc)
      ibc=$(basename $ifc)
      echo "# $idc"
      bsz=""; psz="";
      for ilg in $idc/trace*.log; do
        ilog="$(echo $ilg | grep $filt)"
        if [[ -n "$ilog" ]] ; then
          ilog=$(basename $ilog)
          bsz=$(awk '/buffer_size  :/{print $3; exit}' $idc/$ilog)
          psz=$(awk '/period_size  :/{print $3; exit}' $idc/$ilog)
          break
        fi
      done
      if [[ ! -z "$ilog" && ! -z "$bsz" && ! -z "$psz" ]] ; then
        echo "#  $psz $bsz $ilog $ibc"
        # actually not - playback is $14 zero, capture is 1! so this gives opposite..
        # was $7==3, but having problems with python tracer
        retawk=$(awk -F, '
        {
          if($7==2 && $14==0){print "first play ppos",$10;exit;};
        }
        ' $idc/$ibc)
        if [[ ! -z "$retawk" ]] ; then
          echo "$retawk" # debug
          retawkl=$(echo "$retawk" | tail -1)
          printf "% 5d % 5d %s %s %s %s\n" "$psz" "$bsz" "$retawkl" "$ibc" "$ilog" ${idc:0:12}...
        fi
      fi
    done
  done
done
fi # "$1" == "dlt2"



