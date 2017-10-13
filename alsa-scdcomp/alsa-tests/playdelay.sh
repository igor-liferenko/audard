#!/usr/bin/env bash
################################################################################
# playdelay.sh                                                                 #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# call with:
# bash playdelay.sh | tee playdelay.log

control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT

for (( nd=100000; nd<1000000; nd+=10000 )); do
  set -x
  gcc -DCARDNUM=0 -DNSDLY=${nd}L -Wall -g -finstrument-functions playmini.c -lasound -o playmini
  set +x
  for (( nt=1; nt<101; nt+=1 )); do
    rep=$(./playmini 2>&1)
    repg=$(echo "$rep" | grep 'Asked')
    printf "%d: % 3d, %s\n" $nd $nt "$repg"
  done
done

### for doPlayback_v02:

# num errors:
# awk '{ if(aa!=$1){print(substr(aa,1,length(aa)-1),er);aa=$1;er=0;};if(match($9,"\\(-32\\)")){er++;}; }' playdelay_v02.log

# also mean of avail:
# awk '{ if(aa!=$1){print(substr(aa,1,length(aa)-1),er,ok,(ok==0?0:acc/ok));aa=$1;er=0;ok=0;acc=0;};if(match($9,"\(-32\)")){er++;}else{acc+=substr($7,7,8);ok++;}; }' playdelay.log | less
# gnuplot> fn="<awk '{ if(aa!=$1){print(substr(aa,1,length(aa)-1),er,ok,(ok==0?0:acc/ok));aa=$1;er=0;ok=0;acc=0;};if(match($9,\"\\\\(-32\\\\)\")){er++;}else{acc+=substr($7,7,8);ok++;}; }' playdelay.log"
# gnuplot> plot fn using 1:2 with linespoints, '' using 1:4 with linespoints

# with median:
# awk 'function med(ia,  tl){tl=asort(ia);if(tl%2){return ia[(tl+1)/2];}else{return (ia[(tl/2)]+ia[(tl/2)+1])/2.0};}; { if(!aa){aa=$1};if(aa!=$1){print(substr(aa,1,length(aa)-1),er,ok,(ok==0?0:acc/ok),med(am));aa=$1;er=0;ok=0;acc=0;split("",am);};if(match($9,"\\(-32\\)")){er++;}else{val=substr($7,7,8);acc+=val;ok++;am[ok]=val;}; }' playdelay.log 2>&1 | less
# gnuplot> fn="<awk 'function med(ia,  tl){tl=asort(ia);if(tl%2){return ia[(tl+1)/2];}else{return (ia[(tl/2)]+ia[(tl/2)+1])/2.0};}; { if(!aa){aa=$1};if(aa!=$1){print(substr(aa,1,length(aa)-1),er,ok,(ok==0?0:acc/ok),med(am));aa=$1;er=0;ok=0;acc=0;split(\"\",am);};if(match($9,\"\\\\(-32\\\\)\")){er++;}else{val=substr($7,7,8);acc+=val;ok++;am[ok]=val;}; }' playdelay.log"
# ((cannot do "t [μs]" like this in console;))
# gnuplot> set xlabel "NSDeLaY t [us]" ; plot fn using ($1/1000.0):2 with histeps t "num errors in 100 runs", fn using ($1/1000.0):4 with linespoints t "mean pb_avail frames (from ok runs)", fn using ($1/1000.0):5 with steps t "median pb_avail frames (from ok runs)"

# (( DCARDNUM=0 is for me hda-intel ))
# gnuplot> set terminal png size 800,480 ; set output 'playdelay-hda-intel.png' ; replot
# gnuplot> set terminal wxt ; replot

# (the median pb_avail frames values are: 37, 33, 41, 49, 57, [0])

### for doPlayback_v03:

# awk '{ if(!aa){aa=$1};if(aa!=$1){print(substr(aa,1,length(aa)-1),er);aa=$1;er=0;};if(match($0,"Broken")){er++;}; }' playdelay_v03.log | less

# gnuplot> fn="<awk '{ if(!aa){aa=$1};if(aa!=$1){print(substr(aa,1,length(aa)-1),er);aa=$1;er=0;};if(match($0,\"Broken\")){er++;}; }' playdelay_v03.log"
# gnuplot> set yrange [0:100] ; set xlabel "NSDeLaY t [us]"
# gnuplot> plot fn using ($1/1000.0):2 with histeps t "num errors in 100 runs"

# gnuplot> set terminal png size 800,480 ; set output 'playdelay-hda-intel_v03.png' ; replot
# gnuplot> set terminal wxt ; replot

