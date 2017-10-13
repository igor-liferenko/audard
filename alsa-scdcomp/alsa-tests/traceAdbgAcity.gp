#!/usr/bin/env gnuplot
################################################################################
# traceAdbgAcity.gp                                                            #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# Mon Nov 11 16:13:12 CET 2013 ; gnuplot 4.6 patchlevel 1

# call with (from shell; remember - at end instead of persist):
# gnuplot -e "fph='./path';fpd='./path';" traceAdbgAcity.gp -
# or
# gnuplot -e "fo='png';fph='./path';fpd='./path';" traceAdbgAcity.gp

# gnuplot -e "show colornames" 2>&1 | less

if (! exists("fph")) \
  fph='c001captply-2013-11-11-18-37-54-hda' ;
if (! exists("fpd")) \
  fpd='c001captply-2013-11-11-18-39-31-dum' ;

#ffh=fph . '/trace-hda-intel.dat' ;
#ffd=fpd . '/trace-dummy.dat' ;
# glob here (assuming there's only one .dat file in subdir):
ffh=system("echo " . fph . "/*.dat" ) ;
ffd=system("echo " . fpd . "/*.dat" ) ;

if (! exists("fo")) \
  fo="wxt"

# works for wxt - now all lines dashed, instead of solid with differing point types
# `test` gnuplot command to output dashes/linetypes
# png dashed does not exist, but pngcairo dashed does

if (fo eq "wxt") \
  set terminal wxt dashed ;

if (fo eq "png") \
  set terminal pngcairo dashed transparent truecolor background rgb "white" size 600,400; \
  ofh=fph[1:31] . ".png"; \
  set output ofh ; \
  print "output to " . ofh;



set clip two

ho = 2;
po = 1;


# must get 6-column format for boxxyerrorbars, so as to position them arbitrarily
# we need just xlow and xhigh on the same line though
fnPlBoxesD = "<awk '/Wsp/{tss=$1;} /Wep/{tse=$1;if(tss){print tss,tse}}'  " . ffd
fnPlBoxesH = "<awk '/Wsp/{tss=$1;} /Wep/{tse=$1;if(tss){print tss,tse}}'  " . ffh

# NB: MUST have two backslashes here to escape the pipe, else problems!:

fn_hwud = "<grep hwu " . ffd
fn_hwuh = "<grep hwu " . ffh
fn_pdud = "<grep pdu " . ffd
fn_pduh = "<grep pdu " . ffh
fn_Wspd = "<grep Wsp " . ffd
fn_Wsph = "<grep Wsp " . ffh
fn_Wepd = "<grep Wep " . ffd
fn_Weph = "<grep Wep " . ffh
fn_shhd = "<grep shh " . ffd
fn_hpud = "<grep 'hwu\\|pdu' " . ffd
fn_hpuh = "<grep 'hwu\\|pdu' " . ffh
fn_kpph = "<grep kpp " . ffh
fn_kppd = "<grep kpp " . ffd
fn_pslh = "<grep psl " . ffh
fn_psld = "<grep psl " . ffd
fn_PBEh = "<grep PBE " . ffh
fn_PBEd = "<grep PBE " . ffd



# make y=yhigh for yerrorbars - so can scroll close to yhigh without lines dissapearing (for a small range)

plot \
  fnPlBoxesD using ($1):(0):($1):($2):(0):(0.85) with boxxyerrorbars fs solid 0.25 lc rgb "light-blue" notitle, \
  fnPlBoxesH using ($1):(0):($1):($2):(ho):(ho+0.85) with boxxyerrorbars fs solid 0.25 lc rgb "light-blue" notitle, \
  fn_hwud using ($1):(0.9):(0):(0.9) with yerrorbars notitle lt 1 lc rgb "green", \
  fn_pdud using ($1):(0.9):(0):(0.9) with yerrorbars notitle lt 1 lc rgb "red", \
  fn_hwuh using ($1):(ho+0.9):(ho):(ho+0.9) with yerrorbars notitle lt 1 lc rgb "green", \
  fn_pduh using ($1):(ho+0.9):(ho):(ho+0.9) with yerrorbars notitle lt 1 lc rgb "red", \
  fn_kppd using ($1):(0.6):(0):(0.6) with yerrorbars notitle lt 1 lc rgb "purple" lw 1.1, \
  fn_kpph using ($1):(ho+0.6):(ho):(ho+0.6) with yerrorbars notitle lt 1 lc rgb "purple" lw 1.1, \
  fn_psld using ($1):(0.7):(0):(0.7) with yerrorbars notitle lt 1 lc rgb "dark-orange", \
  fn_pslh using ($1):(ho+0.7):(ho):(ho+0.7) with yerrorbars notitle lt 1 lc rgb "dark-orange", \
  fn_PBEd using ($1):(0.7):(0):(0.7) with yerrorbars notitle lt 1 lc rgb "black" lw 1.3, \
  fn_PBEh using ($1):(ho+0.7):(ho):(ho+0.7) with yerrorbars notitle lt 1 lc rgb "black" lw 1.3, \
  fn_Wspd using ($1):(0.85):(0):(0.85) with yerrorbars notitle lt 1 lc rgb "light-blue", \
  fn_Wepd using ($1):(0.4+$12*0.4):(0):(0.4+$12*0.4) with yerrorbars notitle lt 1 lc rgb "blue", \
  fn_Wsph using ($1):(ho+0.85):(ho):(ho+0.85) with yerrorbars notitle lt 1 lc rgb "light-blue", \
  fn_Weph using ($1):(ho+(1+$12)*0.4):(ho):(ho+(1+$12)*0.4) with yerrorbars notitle lt 1 lc rgb "blue", \
  fn_pdud using ($1):(po+$6/4408.0) with linespoints t "ppos" lt 1 lc rgb "red" , \
  fn_pdud using ($1):(po+$6/4408.0):(stringcolumn(6)) with labels   left font ",8" tc rgb "red" notitle, \
  fn_hpud using ($1):(po+$6/4408.0) with steps t "upos" lt 1 lc rgb "green" lw 1.6, \
  fn_hpud using ($1):(po+int($9)%4408/4408.0) with steps t "new_" lt 3 lc rgb "dark-green" lw 1.4, \
  fn_hpud using ($1):(po+int($8)%4408/4408.0) with steps t "old_" lt 4 lc rgb "sea-green" lw 1.2, \
  fn_pduh using ($1):(ho+po+$6/4416.0) with linespoints notitle lt 1 lc rgb "red" , \
  fn_pduh using ($1):(ho+po+$6/4416.0):(stringcolumn(6)) with labels   left font ",8" tc rgb "red" notitle, \
  fn_hpuh using ($1):(ho+po+$6/4416.0) with steps notitle lt 1 lc rgb "green" lw 1.6, \
  fn_hpuh using ($1):(ho+po+int($9)%4416/4416.0) with steps notitle lt 3 lc rgb "dark-green" lw 1.4, \
  fn_hpuh using ($1):(ho+po+int($8)%4416/4416.0) with steps notitle lt 4 lc rgb "sea-green" lw 1.2

#  fn_shhd using ($1):(0.7):(0):(0.7) with yerrorbars notitle lt 1 lc rgb "black" lw 1.5, \




