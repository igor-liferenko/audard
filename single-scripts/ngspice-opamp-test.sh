#!/usr/bin/env bash

SIGN="sdaau, Nov 2011"
# call with: ./ngspice-opamp-test.sh (no arguments)

# demonstration of:
## (gschem to generate appropriate circuit schematic)
## gnetlist to create netlist for ngspice
## ngspice to simulate the circuit
## gnuplot to generate plots from ngspice data
# to clean, with: ./ngspice-opamp-test.sh -clean

# some tests regarding opamps
#  (in gschem schematic ( -> gnetlist ) -> ngspice simulation)

# there are these opamps:

# https://wiki.ubuntu.com/From_PSpice_to_ngspice-gEDA
# "ideal opamp which works as a comparator"
#~ * USE: E_SRC N_plus 0 vol='LIMIT(V(N_input,0)*1E6,-15V,15V)'

# ../ngspice-cvs/ngspice/ng-spice-rework/src/xspice/examples/mixed_mode.deck
# also in http://ngspice.sourceforge.net/docs/ngspice-manual.pdf
#~ * USE: xlpf  plus minus out  NGopamp
# .subckt  NGopamp  plus minus out

# [http://archives.seul.org/geda/user/Mar-2005/msg00243.html Re: gEDA-user: newbie opamp blues]
#~ * USE: X_AMP in+ in- V+ V- Out  OP07
# SPICE-opamp-1.sym = given in post;
# .subckt OP07 3 2 7 4 6 - relates to nodes inside; however schematic sym has also (pinnumber=3 ; pinseq=1; IN+), (pinnumber=7; pinseq=3; V+) - relates to both: the first pos (pinseq) should be pin number 3 == internal subckt net number 3

# from http://www.brorson.com/gEDA/SPICE/
# http://www.brorson.com/gEDA/SPICE/OpticalReceiver.tar.gz
# "Transimpedance amplifier project: This is an archive of a simple, wide-bandwidth transimpedance amplifier based upon an Analog Devices AD8009 op amp."
#~ * USE: X_AMP i+ i- Vcc+ Vcc- Vout AD8009an
# original 'file=.../AD8009AN.CIR' - is the netlist itself (here .sub) :)
# ad8009-1.sym (given in zip, /sym/ subdir)
# .SUBCKT AD8009an 1 2 99 50 28 - sym: (pinnumber=7, pinseq=3, pinlabel=V+) - what is pin number 7 (V+) should match the 3rd net of subckt - which is internally to subckt, net 99

# for single-supply test:
# set VCC_M5V: value=5 to value=0; (remember, its not value=-5 here!)
# and in NGopamp, set ".model lim limit ( out_lower_limit = -4.9" to 'out_lower_limit = 0'

# see also notes [dev] at bottom


NGOPAMP_SUB="NGopamp.sub"
OP07_SUB="OP07.sub"
AD8009AN_SUB="AD8009an.sub"
GAFRC_FILE="gafrc"
SPICE_OPAMP_1_SYM="SPICE-opamp-1.sym"
AD8009_1_SYM="ad8009-1.sym"
VCVS_1_2PIN_SYM="vcvs-1-2pin.sym"

BASENM="ngspice_opamp_test" # shouldn't be the same as name of script, for easy deletion ${BASENM}*
SCHFILE="${BASENM}.sch"
NETFILE="${BASENM}.net"
SIMCMDS="${BASENM}_ngspice-sim.cmds"

# note: `hardcopy ${NGSIMPSFILE}` enforces lowercase!
# (choose all lowecase letters here)
NGSIMPSFILE="${BASENM}_sim.ps"
NGSIMPNGFILE="${BASENM}_sim.png"

# for gnuplot related
# gnuplot cmd creates ${BASENM}.{data,eps,plt} # keep same basenm there
BASENMGP="${BASENM}_gp"
# our custom gnuplot script
GPSCRIPT="${BASENMGP}.gnuplot"
GPIMG="${BASENMGP}.png"

# list of all files to clean:
ALLFCLEAN="${NGOPAMP_SUB} ${OP07_SUB} ${AD8009AN_SUB} ${GAFRC_FILE} ${SPICE_OPAMP_1_SYM} ${AD8009_1_SYM} ${VCVS_1_2PIN_SYM} ${BASENM}*"

SIMTIME="22ms"


# succeeds if there is something in $1
#~ echo "1: $1"
if [ -n "${1:+x}" ] ; then
if [ "${1}" == "-clean" ] ; then
echo "DOCLEAN"
DOCLEAN="1"
fi
fi


cleanup() {
  echo "  RM ${ALLFCLEAN}"
  for ix in "${ALLFCLEAN}" ; do
    #~ echo rm ${ix}
    rm ${ix}
  done
} # end cleanup()


main() {

  if [ "${DOCLEAN}" == "1" ] ; then
    # just cleanup and exit
    cleanup
    exit
  fi

  create_spice_subckt_files   # also creates $SIMCMDS
  create_gschem_symbol_files  # also creates main gschem .sch

  set -x
  # generate ngspice .net netlist from gschem .sch schematic
  gnetlist -v -O sort_mode -g spice-sdb -o "${NETFILE}" "${SCHFILE}"

  # run simulation with netspace - generates .ps file
  # (if it will also generate gnuplot data, at the same time,
  #   it will also raise gnuplot terminal - ngspice will however exit)
  # (however, direct export w/ 'wrdata' is readable in gnuplot,
  #   so no need to call gnuplot from ngspice)
  ngspice -b "${NETFILE}"

  # convert (ImageMagick) ngspice generated .ps file to .png
  convert "${NGSIMPSFILE}" "${NGSIMPNGFILE}"

  # file for gnuplot transparency? Doesn't work, no need:
  #~ convert -size 100x100 xc:white "${BASENM}_white.png"

  # run the gnuplot script for multiplot (stacked individual signal graphs/diagrams) - will generate ${GPIMG}
  gnuplot "${GPSCRIPT}"
  set +x

  echo -e "\n"
  echo "----- ${0} FINISHED ----  "
  echo "----- (you can view the ${NGSIMPNGFILE}; ${GPIMG} images now) ----  "

} # end main()

dumpversions() {
  cat /etc/issue
  uname -a
  gschem --version | grep '[[:digit:]]'
  gnetlist --version | grep '[[:digit:]]'
  ngspice --version | grep '[[:digit:]]'
  convert --version | grep '[[:digit:]]'
  gnuplot --version

  # dev output:
  #~ Ubuntu 11.04 \n \l
  #~ Linux ljutntcol 2.6.38-12-generic #51-Ubuntu SMP Wed Sep 28 14:25:20 UTC 2011 i686 i686 i386 GNU/Linux
  #~ gEDA 1.7.0 (gdc5914e)
  #~ Copyright (C) 1998-2011 gEDA developers
  #~ gEDA 1.7.0 (gdc5914e)
  #~ Copyright (C) 1998-2011 gEDA developers
  #~ ngspice compiled from ngspice revision 22
  #~ Copyright (C) 1985-1996,  The Regents of the University of California
  #~ Copyright (C) 1999-2008,  The NGSpice Project
  #~ Version: ImageMagick 6.6.2-6 2011-03-16 Q16 http://www.imagemagick.org
  #~ Copyright: Copyright (C) 1999-2010 ImageMagick Studio LLC
  #~ gnuplot 4.4 patchlevel 2
} # end dumpversions()




create_spice_subckt_files() {
echo "create_ ${NGOPAMP_SUB}"
cat > ${NGOPAMP_SUB} <<EOF
* NGopamp.sub
* ../ngspice-cvs/ngspice/ng-spice-rework/src/xspice/examples/mixed_mode.deck
* also in http://ngspice.sourceforge.net/docs/ngspice-manual.pdf
* USE: xlpf  plus minus out  NGopamp
* changed out_lower_limit = -12 out_upper_limit = 12 to -/+4.9
*****************
.subckt  NGopamp  plus minus out
*
r1 plus minus 300k
a1 %vd (plus minus) outint lim
.model lim limit (out_lower_limit = -4.9 out_upper_limit = 4.9
*~ .model lim limit (out_lower_limit = 0 out_upper_limit = 4.9
+             fraction = true  limit_range = 0.2  gain=300e3)
*~ r4 plus outint 100k # debug; but it seems to be needed not to fail tran!
* put it big, then...
r4 plus outint 10M
r3 outint out 50.0
r2 out 0 1e12
*
.ends NGopamp
EOF
# end NGopamp.sub

echo "create_ ${OP07_SUB}"
cat > ${OP07_SUB} <<EOF
* OP07.sub
* [http://archives.seul.org/geda/user/Mar-2005/msg00243.html Re: gEDA-user: newbie opamp blues]
* USE: XAMP in+ in- V+ V- Out  OP07
*****************
* Linear Technology OP07 op amp model
* Written: 08-24-1989 12:35:59 Type: Bipolar npn input, internal comp.
* Typical specs:
* Vos=3.0E-05, Ib=1.0E-09, Ios=4.0E-10, GBP=6.0E+05Hz, Phase mar.= 70
* deg,
* SR(+)=2.5E-01V/us, SR(-)=2.4E-01V/us, Av= 114 dB, CMMR= 126 dB,
* Vsat(+)=2.00V, Vsat(-)=2.00V, Isc=+/-25.0mA, Iq=2500uA
* (input differential mode clamp active)
*
* Connections: + - V+V-O
.subckt OP07 3 2 7 4 6
* input
rc1 7  80 8.842E+03
rc2 7  90 8.842E+03
q1  80 102 10 qm1
q2  90 103 11 qm2
rb1  2   102 5.000E+02
rb2  3   103 5.000E+02
ddm1 102 104 dm2
ddm3 104 103 dm2
ddm2 103 105 dm2
ddm4 105 102 dm2
c1  80 90 5.460E-12
re1 10 12 1.948E+03
re2 11 12 1.948E+03
iee 12 4  7.502E-06
re  12 0  2.666E+07
ce  12 0  1.579E-12
* intermediate
gcm 0  8  12 0  5.668E-11
ga  8  0  80 90 1.131E-04
r2  8  0  1.000E+05
c2  1  8  3.000E-11
gb  1  0  8  0  1.294E+03
* output
ro1 1  6  2.575E+01
ro2 1  0  3.425E+01
rc  17 0  6.634E-06
gc  0  17 6  0  1.507E+05
d1  1  17 dm1
d2  17 1  dm1
d3  6  13 dm2
d4  14 6  dm2
vc  7  13 2.803E+00
ve  14 4  2.803E+00
ip  7  4  2.492E-03
dsub 4  7  dm2
* models
.model qm1 npn (is=8.000E-16 bf=3.125E+03)
.model qm2 npn (is=8.009E-16 bf=4.688E+03)
.model dm1 d   (is=1.486E-08)
.model dm2 d   (is=8.000E-16)
.ends OP07
*
* - - - - - * fini OP07 * - - - - - * [oamm vn1 8/89]
**
*         (C) COPYRIGHT LINEAR TECHNOLOGY CORPORATION 1990
*                       All rights reserved.
*
*   Linear Technology Corporation hereby grants the users of this
* macromodel a non-exclusive, nontransferrable license to use this
*            macromodel under the following conditions:
*
* The user agrees that this macromodel is licensed from Linear
* Technology and agrees that the macromodel may be used, loaned,
* given away or included in other model libraries as long as this
* notice and the model in its entirety and unchanged is included.
* No right to make derivative works or modifications to the
* macromodel is granted hereby.  All such rights are reserved.
*
* This model is provided as is.  Linear Technology makes no
* warranty, either expressed or implied about the suitability or
* fitness of this model for any particular purpose.  In no event
* will Linear Technology be liable for special, collateral,
* incidental or consequential damages in connection with or arising
* out of the use of this macromodel.  It should be remembered that
* models are a simplification of the actual circuit.
*
* Linear Technology reserves the right to change these macromodels
* without prior notice.  Contact Linear Technology at 1630 McCarthy
* Blvd., Milpitas, CA, 95035-7487 or telephone 408/432-1900 for
* datasheets on the actual amplifiers or the latest macromodels.
*
*
EOF
# end OP07.sub

echo "create_ ${AD8009AN_SUB}"
cat > ${AD8009AN_SUB} <<EOF
* AD8009an.sub
* http://www.brorson.com/gEDA/SPICE/OpticalReceiver.tar.gz
* Documentation at http://www.brorson.com/gEDA/SPICE/
* USE: XU2 Vout1 5 V2+ V2- Vout2 AD8009an
***** AD8009 SPICE model       Rev B SMR/ADI 8-21-97

* Copyright 1997 by Analog Devices, Inc.

* Refer to "README.DOC" file for License Statement.  Use of this model
* indicates your acceptance with the terms and provisions in the License Statement.

* rev B of this model corrects a problem in the output stage that would not
* correctly reflect the output current to the voltage supplies

* This model will give typical performance characteristics
* for the following parameters;

*     closed loop gain and phase vs bandwidth
*     output current and voltage limiting
*     offset voltage (is static, will not vary with vcm)
*     ibias (again, is static, will not vary with vcm)
*     slew rate and step response performance
*     (slew rate is based on 10-90% of step response)
*     current on output will be reflected to the supplies
*     vnoise, referred to the input
*     inoise, referred to the input

*     distortion is not characterized

* Node assignments
*                non-inverting input
*                | inverting input
*                | | positive supply
*                | | |  negative supply
*                | | |  |  output
*                | | |  |  |
.SUBCKT AD8009an 1 2 99 50 28

* input stage *

q1 50 3 5 qp1
q2 99 5 4 qn1
q3 99 3 6 qn2
q4 50 6 4 qp2
i1 99 5 1.625e-3
i2 6 50 1.625e-3
cin1 1 98 2.6e-12
cin2 2 98 1e-12
v1 4 2 0

* input error sources *

eos 3 1 poly(1) 20 98 2e-3 1
fbn 2 98 poly(1) vnoise3 50e-6 1e-3
fbp 1 98 poly(1) vnoise3 50e-6 1e-3

* slew limiting stage *

fsl 98 16 v1 1
dsl1 98 16 d1
dsl2 16 98 d1
dsl3 16 17 d1
dsl4 17 16 d1
rsl  17 18 0.22
vsl  18 98 0

* gain stage *

f1 98 7 vsl 2
rgain 7 98 2.5e5
cgain 7 98 1.25e-12
dcl1 7 8 d1
dcl2 9 7 d1
vcl1 99 8 1.83
vcl2 9 50 1.83

gcm 98 7 poly(2) 98 0 30 0 0 1e-5 1e-5

* second pole *

epole 14 98 7 98 1
rpole 14 15 1
cpole 15 98 2e-10

* reference stage *

eref 98 0 poly(2) 99 0 50 0 0 0.5 0.5

ecmref 30 0 poly(2) 1 0 2 0 0 0.5 0.5

* vnoise stage *

rnoise1 19 98 4.6e-3
vnoise1 19 98 0
vnoise2 21 98 0.53
dnoise1 21 19 dn

fnoise1 20 98 vnoise1 1
rnoise2 20 98 1

* inoise stage *

rnoise3 22 98 8.18e-6
vnoise3 22 98 0
vnoise4 24 98 0.575
dnoise2 24 22 dn

fnoise2 23 98 vnoise3 1
rnoise4 23 98 1

* buffer stage *

gbuf 98 13 15 98 1e-2
rbuf 98 13 1e2

* output current reflected to supplies *

fcurr 98 40 voc 1
vcur1 26 98 0
vcur2 98 27 0
dcur1 40 26 d1
dcur2 27 40 d1

* output stage *

vo1 99 90 0
vo2 91 50 0
fout1 0 99 poly(2) vo1 vcur1 -9.27e-3 1 -1
fout2 50 0 poly(2) vo2 vcur2 -9.27e-3 1 -1
gout1 90 10 13 99 0.5
gout2 91 10 13 50 0.5
rout1 10 90 2
rout2 10 91 2
voc 10 28 0
rout3 28 98 1e6
dcl3 13 11 d1
dcl4 12 13 d1
vcl3 11 10 -0.445
vcl4 10 12 -0.445

.model qp1 pnp()
.model qp2 pnp()
.model qn1 npn()
.model qn2 npn()
.model d1  d()
.model dn  d(af=1 kf=1e-8)
.ends
EOF
# end AD8009an.sub


echo "create_ ${SIMCMDS}"
cat > ${SIMCMDS} <<EOF
.control
echo ...........

* define function for the E source model which uses LIMIT
.func LIMIT(x,y,z) { min(max(x,y),z) }

* set color for postscript output
set hcopypscolor=1

* perform transient sim
tran 100us ${SIMTIME}

* show all accessible vectors
display

* save the plot of node voltage V(1)
* in a ${NGSIMPSFILE} file (note: capital letters in .ps filename get changed to lowercase!)
set hcopywidth=1000
set hcopyheight=500
hardcopy ${NGSIMPSFILE} V(N_Vin) V(N_E_LIMIT_out) V(N_NGopamp_FLW_out) V(N_OP07_FLW_out) V(N_AD8009_FLW_out)

* gnuplot cmd creates ${BASENM}.{data,eps,plt}; and opens gnuplot terminal
* (no way to suppress the opening of gnuplot terminal, it seems
* , however, ngspice is exited at that point).
* the eps is more-less the same image as in hardcopy's ps.
* .plt is the gnuplot script; data is ascii data in columns -
** though the time as column is repeated
** (so if 5 data vectors selected here - then
**  5 copies of time vector for each in .data, meaning 10 columns in all).
*~ gnuplot ${BASENM} V(N_Vin) V(N_E_LIMIT_out) V(N_NGopamp_FLW_out) V(N_OP07_FLW_out) V(N_AD8009_FLW_out)

* NOTE: the data format that gnuplot outputs, is the same as wrdata [ file ] [ vecs ] !! (see 17.4.78 Wrdata, pg 287 manual)
* So just use wrdata instead, and call gnuplot separately...
* don't add ".data" extension (${BASENM}.data) - it is added automatically
wrdata ${BASENM} V(N_Vin) V(N_E_LIMIT_out) V(N_NGopamp_FLW_out) V(N_OP07_FLW_out) V(N_AD8009_FLW_out)

.endc
EOF
# end ${SIMCMDS}

echo "create_ ${GPSCRIPT}"
cat > ${GPSCRIPT} <<EOF
# start by copying the autogenerated ${BASENM}.plt
# then here, stacked plots - from: [http://old.nabble.com/Getting-more-plots-on-one%21-tt26230858.html Old Nabble - Getting more plots on one!]
# output from this - via ${BASENMGP}
# to see linetypes, from bash execute 'test' command:
# gnuplot -e "set terminal pngcairo ; test" > test.png

# first set the terminal, so we don't raise prompt
# note, 'png' terminal defaults in gnuplot 4.4 are:
# Options are 'nocrop font /usr/share/fonts/truetype/ttf-liberation/LiberationSans-Regular.ttf 12 size 640,480 '
# there is also 'pngcairo'; 'pdfcairo' makes pdf (regardless of filename)
set terminal pngcairo nocrop truecolor size 1200,900
#~ set terminal pdfcairo nocrop size 6.80in, 4.80in
set output '${GPIMG}'

# for "ghost" input line
set style line 2 linetype 1 linecolor rgb "#AF7070" linewidth 0.5
unset colorbox

# the title here ends up on all plots!
#~ set title "* ${BASENM}.net sim"
# this xlabel don't matter anyway; it gets unset
#~ set xlabel "t [s]"
set ylabel "U [V]"    # valid for all (sub)plots
set grid
unset logscale x
set xrange [0.000000e+00:2.200000e-02]
unset logscale y
set yrange [-6.000000e+00:6.000000e+00]
#set xtics 1
#set x2tics 1
#set ytics 1
#set y2tics 1

##Defining variables
NPLOTS=5
#~ SX = 0.5; SY = 0.2
OX = 0.05; OY = 0.05
#  - 0.02 seems bare minimum? same as (1.0/NPLOTS)/10.0
# it shows all five graphs, but crops the top title! /8.0 shows it..
SX = 0.8; SY = 1.0/NPLOTS - (1.0/NPLOTS)/8.0
NX = 1; NY = NPLOTS-2
#~ PY = 0.198
PY = SY

##Setting margins
set bmargin OX; set tmargin OX; set lmargin OY; set rmargin OY
set size SX*NX+OX*1.5, SY*NY+OY*1.5
show size

## reserve some space for x- and y-labels by shifting
## the plots a little bit
OX=1.7*OX
OY=1.5*OY

set multiplot
## First plot from bottom------------------------------------
# the '0 with lines linewidth 1 .. ' is a plot of a horizontal line (the abscissa indication)
set origin OX,OY
set size SX,SY      # sets local plot size! of subsequent ones too
set xlabel "t [s]"
#~ set xtics format "%3.0em" # naah, doesn't preserve
set xtics format "%.03f"
plot '${BASENM}.data' using 9:10 with lines linewidth 2 linecolor rgb "pink" title "v(n_ad8009_flw_out)", \
0 with lines linewidth 1.5 linecolor rgb "black" title "", \
'${BASENM}.data' using 1:2 with lines linestyle 2 title ""

## Second plot from bottom------------------------------------
set origin OX,PY+OY
unset xlabel        # unsets xlabel of subsequent ones too
#unset xtics         # ditto? no, just unset the xtics labels!
# manual: "If the empty string "" is given, tics will have no labels, although the tic mark will still be plotted."
set xtics format ""
plot '${BASENM}.data' using 7:8 with lines lw 2 lc rgb "green" title "v(n_op07_flw_out)", \
0 with lines linewidth 1.5 linecolor rgb "black" title "", \
'${BASENM}.data' using 1:2 with lines ls 2 title ""

## Third plot from bottom-------------------------------------
set origin OX,PY*2 + OY
plot '${BASENM}.data' using 5:6 with lines lw 2 lc rgb "orange" title "v(n_ngopamp_flw_out)", \
0 with lines linewidth 1.5 linecolor rgb "black" title "", \
'${BASENM}.data' using 1:2 with lines ls 2 title ""

## Fourth plot from bottom------------------------------------
set origin OX,PY*3 + OY
plot '${BASENM}.data' using 3:4 with lines lw 2 lc rgb "#0000ff" title "v(n_e_limit_out)", \
0 with lines linewidth 1.5 linecolor rgb "black" title "", \
'${BASENM}.data' using 1:2 with lines ls 2 title ""

# "${BASENM}_white.png" with... nevermind, image transparency doesn't really work with lines
## First plot at top
## Fifth plot from bottom------------------------------------
set title "* ${BASENM}.net sim"   # now shows only on top
set origin OX,PY*4 + OY
plot '${BASENM}.data' using 1:2 with lines lw 2 lc rgb "red" title "v(n_vin)", \
0 with lines linewidth 1.5 linecolor rgb "black" title ""

# http://old.nabble.com/transparent-lines-and-points-td25285912.html
# not possible (as of 2009)
# (http://xy-27.pythonxy.googlecode.com/hg-history/1928b66dcf0272dd1d082b65535cae825cf99f22/src/python/gnuplot/DATA/gnuplot/demo/lena.rgb)
#~ f(x)=75.0
#~ set samples 128, 128
#
# can add at end of plot, for transparency:
# , 'lena.rgb' binary array=(128,128) format="%uchar" flipy using 1:2:3:(f(column(0))) with rgbalpha title ""
# but that simply makes the image transparent, apparently - not the line
# so just fake transparency for now with 'whiter' colors..

unset multiplot

EOF
# end ${GPSCRIPT}




} # end create_spice_subckt_files


create_gschem_symbol_files(){

# for gschem to find symbols in current directory
# , we need gschemrc (then gnetlistrc etc) - or:
# for all of them, we can use gafrc - only one line:
echo "create_ ${GAFRC_FILE}"
cat > ${GAFRC_FILE} <<EOF
(component-library "./")
EOF

echo "create_ ${SPICE_OPAMP_1_SYM}"
cat > ${SPICE_OPAMP_1_SYM} <<EOF
# ---------------  SPICE-opamp-1.sym  ---------------
# [http://archives.seul.org/geda/user/Mar-2005/msg00243.html Re: gEDA-user: newbie opamp blues]
v 20050313 1
L 200 0 200 800 3 0 0 0 -1 -1
L 200 800 800 400 3 0 0 0 -1 -1
L 800 400 200 0 3 0 0 0 -1 -1
T 825 150 5 8 0 0 0 0 1
device=OP177
P 200 600 0 600 1 0 1
{
T 50 625 5 8 1 1 0 0 1
pinnumber=3
T 50 625 5 8 0 0 0 0 1
pinseq=1
T 200 600 5 10 0 1 0 0 1
pinlabel=IN+
}
P 200 200 0 200 1 0 1
{
T 50 225 5 8 1 1 0 0 1
pinnumber=2
T 50 225 5 8 0 0 0 0 1
pinseq=2
T 200 200 5 10 0 1 0 0 1
pinlabel=IN-
}
P 800 400 1000 400 1 0 1
{
T 875 425 5 8 1 1 0 0 1
pinnumber=6
T 875 425 5 8 0 0 0 0 1
pinseq=5
T 800 400 5 10 0 1 0 0 1
pinlabel=OUT
}
P 500 200 500 0 1 0 1
{
T 525 50 5 8 1 1 0 0 1
pinnumber=4
T 525 50 5 8 0 0 0 0 1
pinseq=4
T 500 200 5 10 0 1 0 0 1
pinlabel=V-
}
P 500 600 500 800 1 0 1
{
T 525 650 5 8 1 1 0 0 1
pinnumber=7
T 525 650 5 8 0 0 0 0 1
pinseq=3
T 500 600 5 10 0 1 0 0 1
pinlabel=V+
}
T 225 350 9 6 1 0 0 0 1
Op amp
T 200 900 8 10 1 1 0 0 1
refdes=U?
T 400 500 9 6 1 0 0 0 1
V+
T 400 200 9 6 1 0 0 0 1
V-
T 247 533 9 12 1 0 0 0 1
+
T 250 127 9 12 1 0 0 0 1
-
EOF
# end SPICE-opamp-1.sym

echo "create_ ${AD8009_1_SYM}"
cat > ${AD8009_1_SYM} <<EOF
# ad8009-1.sym
# http://www.brorson.com/gEDA/SPICE/OpticalReceiver.tar.gz/sym
v 20030223
L 200 0 200 800 3 0 0 0 -1 -1
L 200 800 800 400 3 0 0 0 -1 -1
L 800 400 200 0 3 0 0 0 -1 -1
T 825 150 5 8 0 0 0 0
device=AD8009
P 200 600 0 600 1 0 1
{
T 50 625 5 8 1 1 0 0
pinnumber=3
T 50 625 5 8 0 0 0 0
pinseq=1
T 200 600 5 10 0 1 0 0
pinlabel=IN+
}
P 200 200 0 200 1 0 1
{
T 50 225 5 8 1 1 0 0
pinnumber=2
T 50 225 5 8 0 0 0 0
pinseq=2
T 200 200 5 10 0 1 0 0
pinlabel=IN-
}
P 800 400 1000 400 1 0 1
{
T 875 425 5 8 1 1 0 0
pinnumber=6
T 875 425 5 8 0 0 0 0
pinseq=5
T 800 400 5 10 0 1 0 0
pinlabel=OUT
}
P 500 200 500 0 1 0 1
{
T 525 50 5 8 1 1 0 0
pinnumber=4
T 525 50 5 8 0 0 0 0
pinseq=4
T 500 200 5 10 0 1 0 0
pinlabel=V-
}
P 500 600 500 800 1 0 1
{
T 525 650 5 8 1 1 0 0
pinnumber=7
T 525 650 5 8 0 0 0 0
pinseq=3
T 500 600 5 10 0 1 0 0
pinlabel=V+
}
T 225 350 9 6 1 0 0 0
AD8009
T 200 900 8 10 1 1 0 0
refdes=U?
T 400 500 9 6 1 0 0 0
V+
T 400 200 9 6 1 0 0 0
V-
T 247 533 9 12 1 0 0 0
+
T 250 127 9 12 1 0 0 0
-
EOF
# end ad8009-1.sym

echo "create_ ${VCVS_1_2PIN_SYM}"
cat > ${VCVS_1_2PIN_SYM} <<EOF
v 20110116 2
L 1000 600 800 400 3 0 0 0 -1 -1
L 800 400 1000 200 3 0 0 0 -1 -1
L 1200 400 1000 200 3 0 0 0 -1 -1
L 1200 400 1000 600 3 0 0 0 -1 -1
L 1000 600 1000 700 3 0 0 0 -1 -1
L 1000 700 1300 700 3 0 0 0 -1 -1
L 1300 100 1000 100 3 0 0 0 -1 -1
L 1000 200 1000 100 3 0 0 0 -1 -1
P 1300 700 1500 700 1 0 1
{
T 1400 750 5 8 0 1 0 0 1
pinnumber=1
T 1400 650 5 8 0 1 0 2 1
pinseq=1
T 1250 700 9 8 0 1 0 6 1
pinlabel=N+
T 1250 700 5 8 0 1 0 8 1
pintype=pas
}
P 1300 100 1500 100 1 0 1
{
T 1400 150 5 8 0 1 0 0 1
pinnumber=2
T 1400 50 5 8 0 1 0 2 1
pinseq=2
T 1250 100 9 8 0 1 0 6 1
pinlabel=N-
T 1250 100 5 8 0 1 0 8 1
pintype=pas
}
L 1300 0 1300 800 3 0 0 0 -1 -1
L 500 100 200 100 3 0 0 0 -1 -1
L 200 700 500 700 3 0 0 0 -1 -1
L 200 800 200 0 3 0 0 0 -1 -1
L 200 800 1300 800 3 0 0 0 -1 -1
L 1300 0 200 0 3 0 0 0 -1 -1
L 1000 600 1000 200 3 0 0 0 -1 -1
T 600 850 8 10 1 1 0 0 1
refdes=E?
T 200 1850 5 10 0 0 0 0 1
description=voltage controlled voltage source
T 200 1450 5 10 0 0 0 0 1
numslots=0
T 200 1250 5 10 0 0 0 0 1
symversion=0.1
T 200 1650 5 10 0 0 0 0 1
documentation=http://newton.ex.ac.uk/teaching/CDHW/Electronics2/userguide/sec3.html#3.2.2
T 900 600 9 10 1 0 0 0 1
+
T 900 100 9 10 1 0 0 0 1
-
T 500 600 9 10 1 0 0 0 1
+
T 500 100 9 10 1 0 0 0 1
-
T 700 -50 8 10 1 0 0 5 1
value=1
EOF
# end vcvs-1-2pin.sym



# finally, create also the gschem schematic file here:

echo "create_ ${SCHFILE}"
cat > ${SCHFILE} <<EOF
v 20110116 2
C 40000 40000 0 0 0 title-B.sym
C 43100 49100 1 0 0 vpwl-1.sym
{
T 43800 49850 5 10 1 1 0 0 1
refdes=VSRC_IN
T 43800 49050 5 10 1 0 0 0 1
device=vpwl
T 43800 50150 5 10 0 0 0 0 1
footprint=none
T 43800 49550 5 10 1 0 0 0 1
value=pwl( 0 0 10ns -1 10ms 1 11ms -6 20ms 6 )
T 43800 49300 5 10 1 0 0 0 1
symname=vpwl-1.sym
}
C 43200 47900 1 0 0 ground.sym
N 43400 48200 43400 49100 4
{
T 43400 48300 5 10 1 1 0 0 1
netname=0
}
N 43400 50300 43400 50500 4
N 43400 50500 44500 50500 4
{
T 43700 50500 5 10 1 1 0 0 1
netname=N_Vin
}
N 40300 46300 41400 46300 4
{
T 40600 46400 5 10 1 1 0 0 1
netname=N_Vin
}
N 42900 46300 44000 46300 4
{
T 43000 46400 5 10 1 1 0 0 1
netname=N_E_LIMIT_out
}
C 41400 45600 1 0 0 vcvs-1-2pin.sym
{
T 41800 46450 5 10 1 1 0 0 1
refdes=E_LIMIT
T 41600 46850 5 10 0 0 0 0 1
symversion=0.1
T 42100 45550 5 10 1 0 0 5 1
value=vol='LIMIT(V(N_Vin,0)*1E6,-5V,5V)'
T 40900 45200 5 10 1 0 0 0 1
symname=vcvs-1-2pin.sym
}
N 44000 45400 44000 45700 4
{
T 44000 45500 5 10 1 1 0 0 1
netname=0
}
C 43800 45100 1 0 0 ground.sym
N 44000 45700 42900 45700 4
C 41200 48600 1 0 0 ground.sym
{
T 41400 48700 5 10 1 0 0 0 1
symname=ground.sym
}
N 41400 48900 40400 48900 4
{
T 40800 48900 5 10 1 1 0 0 1
netname=0
}
C 40200 50000 1 270 0 voltage-3.sym
{
T 40100 49900 5 8 1 0 270 0 1
device=VOLTAGE_SOURCE
T 40700 49700 5 10 1 1 0 0 1
refdes=VCC_P5V
T 40700 49200 5 10 1 0 0 0 1
symname=voltage-3.sym
T 40700 49400 5 10 1 0 0 0 1
value=5
}
C 45900 45600 1 0 0 SPICE-opamp-1.sym
{
T 45425 46750 5 8 1 0 0 0 1
device=OP177
T 46100 46500 5 10 1 1 0 0 1
refdes=XU_OP07_FLW
T 43800 46900 5 10 1 0 0 0 1
symname=SPICE-opamp-1.sym
T 44800 47100 5 10 1 0 0 0 1
model-name=OP07
}
C 40200 48700 1 270 0 voltage-3.sym
{
T 40900 48500 5 8 0 0 270 0 1
device=VOLTAGE_SOURCE
T 40700 48400 5 10 1 1 0 0 1
refdes=VCC_M5V
T 40700 47900 5 10 1 0 0 0 1
symname=voltage-3.sym
T 40700 48100 5 10 1 0 0 0 1
value=5
}
C 40200 50100 1 0 0 vcc-2.sym
{
T 40500 50200 5 10 1 0 0 0 1
symname=vcc-2.sym
T 40500 50400 5 8 1 0 0 0 1
net=Vcc+:1
}
C 40100 47000 1 0 0 vcc-minus-1.sym
{
T 40500 47400 5 10 1 0 0 0 1
symname=vcc-minus-1.sym
T 40550 47200 5 10 1 0 0 0 1
net=Vcc-:1
}
N 40400 50000 40400 50100 4
N 40400 48700 40400 49100 4
N 40400 47800 40400 47600 4
C 46200 47000 1 0 0 vcc-2.sym
{
T 46500 47100 5 10 0 0 0 0 1
symname=vcc-2.sym
T 46500 47300 5 8 0 0 0 0 1
net=Vcc+:1
}
C 46100 44700 1 0 0 vcc-minus-1.sym
{
T 46500 45100 5 10 0 0 0 0 1
symname=vcc-minus-1.sym
T 46550 44900 5 10 0 0 0 0 1
net=Vcc-:1
}
N 46400 47000 46400 46400 4
N 46400 45600 46400 45300 4
N 44800 46200 45900 46200 4
{
T 45100 46300 5 10 1 1 0 0 1
netname=N_Vin
}
N 46900 46000 48300 46000 4
{
T 47000 46100 5 10 1 1 0 0 1
netname=N_OP07_FLW_out
}
N 47300 46000 47300 45400 4
N 45400 45400 47300 45400 4
N 45400 45400 45400 45800 4
N 45400 45800 45900 45800 4
C 45000 47700 1 0 0 spice-model-1.sym
{
T 45100 48400 5 10 0 1 0 0 1
device=model
T 45100 48300 5 10 1 1 0 0 1
refdes=M1
T 46300 48000 5 10 1 1 0 0 1
model-name=OP07
T 45500 47800 5 10 1 1 0 0 1
file=OP07.sub
T 45000 48600 5 10 1 0 0 0 1
symname=spice-model-1.sym
}
C 49900 45600 1 0 0 ad8009-1.sym
{
T 49225 46750 5 8 1 0 0 0 1
device=AD8009
T 50100 46500 5 10 1 1 0 0 1
refdes=XU_AD8009_FLW
T 48200 46900 5 10 1 0 0 0 1
symname=ad8009-1.sym
T 48200 47100 5 10 1 0 0 0 1
model-name=AD8009an
}
C 50200 47000 1 0 0 vcc-2.sym
{
T 50500 47100 5 10 0 0 0 0 1
symname=vcc-2.sym
T 50500 47300 5 8 0 0 0 0 1
net=Vcc+:1
}
C 50100 44700 1 0 0 vcc-minus-1.sym
{
T 50500 45100 5 10 0 0 0 0 1
symname=vcc-minus-1.sym
T 50550 44900 5 10 0 0 0 0 1
net=Vcc-:1
}
N 50400 47000 50400 46400 4
N 50400 45600 50400 45300 4
N 50900 46000 52300 46000 4
{
T 51000 46100 5 10 1 1 0 0 1
netname=N_AD8009_FLW_out
}
N 51300 46000 51300 45400 4
N 49400 45400 51300 45400 4
N 49400 45400 49400 45800 4
N 49400 45800 49900 45800 4
N 48800 46200 49900 46200 4
{
T 49100 46300 5 10 1 1 0 0 1
netname=N_Vin
}
C 48900 47700 1 0 0 spice-model-1.sym
{
T 49000 48400 5 10 0 1 0 0 1
device=model
T 49000 48300 5 10 1 1 0 0 1
refdes=M2
T 50200 48000 5 10 1 1 0 0 1
model-name=AD8009an
T 49400 47800 5 10 1 1 0 0 1
file=AD8009an.sub
T 48900 48600 5 10 1 0 0 0 1
symname=spice-model-1.sym
}
C 53800 47700 1 0 0 spice-model-1.sym
{
T 53900 48400 5 10 0 1 0 0 1
device=model
T 53900 48300 5 10 1 1 0 0 1
refdes=M3
T 55100 48000 5 10 1 1 0 0 1
model-name=NGopamp
T 54300 47800 5 10 1 1 0 0 1
file=NGopamp.sub
T 53800 48600 5 10 1 0 0 0 1
symname=spice-model-1.sym
}
C 54000 45800 1 0 0 amp-diff.sym
{
T 53600 45400 5 10 1 0 0 0 1
symname=amp-diff.sym
T 54100 45600 5 10 1 1 0 0 1
refdes=XU_NGopamp
T 52300 46800 5 8 1 0 0 0 1
value=N_Vin N_NGopamp_FLW_out N_NGopamp_FLW_out NGopamp
}
N 52900 46400 54000 46400 4
{
T 53200 46500 5 10 1 1 0 0 1
netname=N_Vin
}
N 55200 46200 56600 46200 4
{
T 55100 46300 5 10 1 1 0 0 1
netname=N_NGopamp_FLW_out
}
N 55700 46200 55700 44800 4
N 53500 44800 53500 46000 4
N 53500 46000 54000 46000 4
C 53100 49400 1 0 0 spice-directive-1.sym
{
T 52800 50300 5 10 1 0 0 0 1
device=directive
T 53200 49800 5 10 1 1 0 0 1
refdes=AF1
T 53200 49500 5 10 1 0 0 0 1
file=ngspice_opamp_test_ngspice-sim.cmds
T 52800 50100 5 10 1 0 0 0 1
value=unknown
T 52800 50500 5 10 1 0 0 0 1
symname=spice-directive-1.sym
}
N 53500 44800 55700 44800 4

EOF
# end ${SCHFILE}

} # end create_gschem_symbol_files



## ----------- file creation code END

## ----------- call main
main

## ----------- SCRIPT END



# notes [dev]

# http://geda.seul.org/wiki/geda:master_attributes_list
# pinseq - "SPICE backend), gnetlist will output pins in the order of increasing pin sequence. This attribute is not the pin number"
# pinnumber - "This attribute is the pin number (i.e. like GND is 7 on 74 TTL)."
# "Symbols which have no electrical or circuit significance need a graphical=1 attribute. Symbols like titleboxes"
# "device= is the device name of the symbol ... Do not confuse this attribute with just having a text label which the device name." (in ghdl2ngspice, it is not used, except in the built in spice model symbol.)

# note differing PWL syntax [ PWL(t v t v t v) ... ] from the default given in gschem [pwl 100n 0 200n 1] for vpwl-1.sym!
# note vcvs (default, with four pins):
#~ * begin vcvs expansion, e<name>
#~ E_LIMIT N_E_LIMIT_out unconnected_pin-1 N_Vin unconnected_pin-2 N_E_LIMIT_out 0 vol='LIMIT(V(N_Vin,0)*1E6,-5V,5V)'
#~ Isense_E_LIMIT N_Vin unconnected_pin-2 dc 0
#~ IOut_E_LIMIT N_E_LIMIT_out unconnected_pin-1 dc 0
#~ * end vcvs expansion
# Edit/"Show/Hide Inv Text" when editing .sym, to be able to erase built-in attributes
# (also need to restart to reload symbol each time - unless Edit/Update Component?).
# with removal of device - gnetlist uses only the two pins, and the value verbatim
# do not use -Vcc as net name for ngspice: "Error on line 270 : vcc_-5v 0 -vcc 5  unknown parameter (-vcc) ........... #: no such command available in ngspice" - but Vcc- (also Vcc+) is ok? NO:
#    also: "Error on line 270 : vcc_-5v 0 vcc- 5 unknown parameter (vcc) .. VCC_M5V/P5V naming seems to solve that
# #value=pwl( (0 0.0) (2 0.0) (2.0000000001 1.0) (3 1.0) ) # pg 369 manual no work

# note: pwl source apparently breaks at "10.001ms" time specification!?
# coz finishes early - but:
#~ doAnalyses: TRAN:  Timestep too small; time = 0.0106733, timestep = 1.25e-16: trouble with node "a.xu_ngopamp.a1#branch_1_0" - tran simulation(s) aborted
# added Rf_NG 1 ohm - now OP07 seems a bit more accurate ?! But again: doAnalyses: TRAN:  Timestep too small; time = 0.0182125, timestep = 1.25e-16: trouble with node "a.xu_ngopamp.a1#branch_1_0"
# Rf_NG 10 ohm - doAnalyses: TRAN:  Timestep too small; time = 0.0182125, timestep = 1.25e-16: trouble with node "a.xu_ngopamp.a1#branch_1_0"
# ahh indeed 'a1 %vd (plus minus) outint lim' breaks somehow; replacing it with resistors internally completes without a problem. - and so adding "r4 plus outint 10M" seems to fix it..


# note: [http://archives.seul.org/geda/user/Mar-2005/msg00277.html Re: gEDA-user: newbie opamp blues]
# "The model-name attribute which gets dumped onto the above line must match the model's name exactly.  The model's name appears in the SPICE file after the .subckt declaration:"
# U_OP07_FLW gets renamed by gnetlist to XU_OP07_FLW if model-name OP07 matches 'model' attr of "spice model" object
