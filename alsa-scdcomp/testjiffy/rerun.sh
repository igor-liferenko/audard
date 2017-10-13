#!/usr/bin/env bash
################################################################################
# rerun.sh                                                                     #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

RUNTEST=""
CAPTDIR="captures"

# parse command line argument:
# "2" or "testjiffy_hr" for "testjiffy_hr"
# "1" or "testjiffy" (or anything else) for "testjiffy"
case "$1" in
  "2" | "testjiffy_hr")
    RUNTEST="testjiffy_hr"
    ;;
  *)
    RUNTEST="testjiffy"
    ;;
esac

if [ ! -d "$CAPTDIR" ]; then
  echo "Subfolder '$CAPTDIR' does not exist, creating"
  mkdir "$CAPTDIR"
else
  echo "Subfolder '$CAPTDIR' found"
fi

echo "Running $RUNTEST"

set -x
make clean
make
# blank syslog first
sudo bash -c 'echo "0" > /var/log/syslog'
#~ sleep 1   # MUSTHAVE 01! (not anymore must)
# reload kernel module/driver
sudo insmod ./${RUNTEST}.ko
sleep 0.9   # MUSTHAVE 02! (not anymore must - but need to have it if MAXRUNS say 200 - then that would take 0.8 sec @ 4 ms period)
sudo rmmod ${RUNTEST}
{ set +x; } 2>/dev/null

# copy & process syslog

max=0;
for ix in ${CAPTDIR}/_${RUNTEST}_*.syslog; do
  ao=$(basename "$ix")
  aa=${ao#_${RUNTEST}_};
  ab=${aa%.syslog} ;
  case $ab in
    *[!0-9]*) ab=0;;          # reset if non-digit obtained; else
    *) ab=$(echo $ab | bc);;  # remove leading zeroes (else octal)
  esac
  if (( $ab > $max )) ; then
    max=$((ab));
  fi;
done;
newm=$( printf "%05d" $(($max+1)) );
PLPROC='chomp $_;
if (!$p) {$p=0;}; if (!$f) {$f=$_;} else {
  $a=$_-$f; $d=$a-$p;
  print "$a $d\n" ; $p=$a;
};'


set -x
grep "testjiffy" /var/log/syslog | cut -d' ' -f6- > _${RUNTEST}_${newm}.syslog
grep "testjiffy_timer_function" _${RUNTEST}_${newm}.syslog \
  | sed 's/\[\(.*\)\].*/\1/' \
  | perl -ne "$PLPROC" \
  > _${RUNTEST}_${newm}.dat
{ set +x; } 2>/dev/null


cat > _${RUNTEST}_${newm}.gp <<EOF
set terminal pngcairo font 'Arial,10' size 900,500
set output '_${RUNTEST}_${newm}.png'
set style line 1 linetype 1 linewidth 3 pointtype 3 linecolor rgb "red"
set multiplot layout 1,2 title "_${RUNTEST}_${newm}.syslog"
set xtics rotate by -45
set title "Time positions"
set yrange [0:1.5]
set offsets graph 50e-3, 1e-3, 0, 0
plot '_${RUNTEST}_${newm}.dat' using 1:(1.0):xtic(gprintf("%.3se%S",\$1)) notitle with points ls 1, '_${RUNTEST}_${newm}.dat' using 1:(1.0) with impulses ls 1
binwidth=0.05e-3
set boxwidth binwidth
bin(x,width)=width*floor(x/width) + width/2.0
set title "Delta diff histogram"
set style fill solid 0.5
set autoscale xy
set offsets graph 0.1e-3, 0.1e-3, 0.1, 0.1
plot '_${RUNTEST}_${newm}.dat' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes ls 1
unset multiplot
EOF
set -x; gnuplot _${RUNTEST}_${newm}.gp ; set +x

set -x
mv _${RUNTEST}_* ${CAPTDIR}/
feh ${CAPTDIR}/_${RUNTEST}_${newm}.png &
{ set +x; } 2>/dev/null
