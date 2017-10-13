#!/usr/bin/env bash
################################################################################
# trace-minprog.sh                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# call w/
# bash trace-minprog.sh 2>&1 | tee trace.log

KDBGPATH="/sys/kernel/debug/tracing"
OUTDIR="data-out"
PRGEXEC="min.exe"

function main() {

  set -x
  STARTTS="`date +%F-%H-%M-%S`"
  {
    if [ -d "$OUTDIR" ]; then echo "$OUTDIR exists" ;
    else echo "$OUTDIR does not exist; creating" ; mkdir $OUTDIR ;
    fi
  } 2>/dev/null

  { echo "Compiling callmodule.ko"; } 2>/dev/null

  make

  { echo "Compiling $PRGEXEC"; } 2>/dev/null

  gcc -g -pg -O0 min.c -o $PRGEXEC

  { echo "Get assembly from $PRGEXEC"; } 2>/dev/null

  objdump -S $PRGEXEC > min.S

  { echo "Get first two machine instructions from main()"; } 2>/dev/null

  grep -A2 'int main' min.S

  ADDR1=$(awk '/int main/ {getline; match($1, /([^:]+)/, a); print a[1];} ' min.S)
  ADDR2=$(awk '/int main/ {getline; getline; match($1, /([^:]+)/, a); print a[1];} ' min.S)

  { ADDR1=$(printf "0x%08x" 0x$ADDR1) ; ADDR2=$(printf "0x%08x" 0x$ADDR2) ;
    echo "Addresses are: $ADDR1 $ADDR2"; } 2>/dev/null

  { echo "Getting default function_graph ftrace"
    run_prepcmds
    sudo bash -c "echo 1 > $KDBGPATH/tracing_on ;
      ./$PRGEXEC ;
      echo 0 > $KDBGPATH/tracing_on;"
  } 2>/dev/null
  sudo cat $KDBGPATH/trace > $OUTDIR/$STARTTS-$PRGEXEC-default.ftrace

  # Note: it seems that when physical addresses are obtained,
  # this version of the driver also makes a bug;
  # that doesn't influence tracing of assembly instructons via hw breakpoint,
  # so remove the condition for finding physical addresses at the same time
  { echo "Getting user assembly instruction in function_graph ftrace"
    CMDA="insmod ./callmodule.ko callmodule_userprog=\"$PWD/$PRGEXEC\" callmodule_useraddrs=$ADDR1,$ADDR2"
    echo $CMDA
    RET=1
    while [ $RET != 0 ] ; do
      run_prepcmds
      RET=$(sudo bash -c "$CMDA && sleep 0.01 && rmmod callmodule")
      #echo "return '$RET'"
      RETG=$(sudo grep -l 'hwbp hit:' $KDBGPATH/trace)
      if [ ! "$RETG" ] ; then
        RET=$(( RET + 100 ))
      fi
      #echo "check 1 '$RETG' '$RET'"
      tail -n22 /var/log/syslog | tee $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace
      # "BUG:" may not appear here - look for '>] ? ' of stacktrace
      RETG=$(grep -l '>] ? ' $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace)
      if [ "$RETG" ] ; then
        RET=$(( RET + 200 ))
      fi
      #echo "check 2 '$RETG' '$RET'"
      # extra condition
      ##RETG=$(grep 'start_code:' $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace | grep -l 'start_code: 0x00000000')
      #RETG=`grep '\->)' $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace | grep -l '\->) 0x00000000'`
      #if [ "$RETG" ] ; then
      #  RET=$(( RET + 300 ))
      #fi
      #echo "check 3 '$RETG' '$RET'"
      echo "Got return '$RET'"
    done
    sudo cat $KDBGPATH/trace >> $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace
  } 2>/dev/null

  { set +x; } 2>/dev/null

  du -b $OUTDIR/$STARTTS-*
  sudo bash -c "echo nop > $KDBGPATH/current_tracer" # do nop only on end?
  echo "All done; see $OUTDIR/$STARTTS- ... "

} # end function main()

function run_prepcmds() {

  PREPCMDS="echo function_graph > $KDBGPATH/current_tracer ;
  echo funcgraph-abstime > $KDBGPATH/trace_options ;
  echo funcgraph-proc > $KDBGPATH/trace_options ;
  echo 8192 > $KDBGPATH/buffer_size_kb ;
  echo 0 > $KDBGPATH/tracing_on ;
  echo > $KDBGPATH/trace"

  sudo bash -c "$PREPCMDS"

} # end function run_prepcmds()

# not called from anywhere - just for reference:
function clean() {
  make clean
  rm -rf data-out/ min.S min.exe gmon.out
}

# not called from anywhere - just for reference:
# get first and last timestamp of min.exe in the ftrace log:
function getstartend() {
  awk 'match($0, /^[[:space:]]+([[:digit:].]+) \|.*(min.exe).*/, a) {if (!st){st=1; print "st",a[1];}; ga=a[1];} END{print "en",ga;}' $OUTDIR/$STARTTS-$PRGEXEC-default.ftrace
  # 2014-03-01-01-00-08-min.exe-default.ftrace:
  #st 1311.684499
  #en 1311.708218
  # delta: 1311.708218-1311.684499 = 0.023719
  awk 'match($0, /^[[:space:]]+([[:digit:].]+) \|.*(min.exe).*/, a) {if (!st){st=1; print "st",a[1];}; ga=a[1];} END{print "en",ga;}' $OUTDIR/$STARTTS-$PRGEXEC-uainst.ftrace
  # 2014-03-01-01-00-08-min.exe-uainst.ftrace:
  #st 1312.367186
  #en 1312.403868
  # delta: 1312.403868-1312.367186 = 0.036682
  ## 1312.36-1311.68 = 0.68 ; 1312.39-0.68 = 1311.71
}

# execute main:
main
