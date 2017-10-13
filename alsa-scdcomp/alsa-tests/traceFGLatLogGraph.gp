#!/usr/bin/env gnuplot
################################################################################
# traceFGLatLogGraph.gp                                                        #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# script works on gnuplot 4.6 patchlevel 1

# if this script is called with a filename (fname - dir also implied) argument:
# $ gnuplot -e "fname='somefile.csv';" traceFGTXLogGraph.gp
# then it will automatically plot a .pdf file
# if it called inside gnuplot interpreter, via
# gnuplot> load 'traceFGTXLogGraph.gp'
# it will load whatever filename (below) is uncommented;
# and show it in wxt terminal
# (to re-load from wxt terminal, first
# issue `undefine fname` before `load 'traceFGTXLogGraph.gp'`)

# other options:
# (if dir is unspecified with fname specified, it defaults to '.')
# gnuplot -e "dir='captures';fname='somefile.csv';fnext='02';mr=2e-3" traceFGTXLogGraph.gp
# gnuplot -e "dir='captures';fname='somefile.csv';anct=0.0;anhr=300e-6;" traceFGTXLogGraph.gp

# string/number extension for output filename
if (! exists("fnext")) \
  fnext='' ;

if (! exists("dir")) \
  dir='.' ;

# cfast=1: card faster than rt faster than PC ; 0: card slower than rt slower than PC

if (! exists("cfast")) \
  cfast=1 ;


# do not call reset/clear if filename (for batch .pdf) is passed!
# set terminal pngcairo size 1000,500 ;
# set terminal pdf size 10,3 # pdf size defaults to 5x3 in
# (pdf size to match my PDF header: 41.5953,12.4786 in - but it messes up a lot of things;)
# wxt default size - 640x384 pixels; 640/384 = 5/3 = 1.66667
# font: LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"

# svg output works - unfortunately, the layout tuning
# for PDF does not translate exactly to SVG layout, so
# SVG is a bit off (thicker strokes, etc)
#~ set terminal svg size 11,5 ; \
#~ set output dir . "/" . fname . "_" . fnext . ".svg" ; \


# are we rendering a pdf output?
doPdf=0

# are we doing a pdf output as frame for animation?
doAnim=0
if (exists("anct")) \
  doAnim = 1 ;

if (! exists("fname")) \
  reset ; \
  clear ; \
  rep="no filename argument - using wxt terminal and hardcoded input: " ; \
  set terminal wxt ; \
  set termoption font 'Latin Modern Sans Demi Cond,9.5' ; \
else \
  rep=sprintf("got filename argument (anim %d) - using pdf terminal: ", doAnim) ; \
  doPdf=1 ; # must set these after the filename is determined; because we may read the .csv for total duration, and thus pdflength! \
  set terminal pdf size pdflength,5 ; \
  set output dir . "/" . fname . "_" . fnext . ".pdf" ; \
  set termoption font 'Latin Modern Sans Demi Cond,9.5' ; \
  #~ show output



# new style "if" here; which supports multiline if{} - gnuplot > 4.4
# so the hardcoded values can be easily (un)commented if browsing in wxt

# you should first run `run-alsa-lattest.sh`; to obtain .csv captures;
# then paste them below, (un)comment accordingly;

if (! exists("fname")) {
  dir = "./captures-2013-07-31-05-20-17" ;
  fname = "trace-hda-intel.csv" ;
#  fname = "trace-dummy.csv" ;
}

if (! exists("exect")) \
  exect = "latency" ;

# fname/filename => .csv; lfname => .log
filename = dir . "/" . fname ;
lfname = fname[:5] . exect . fname[6:strstrt(fname,".csv")] . "log"
lfilename = dir . "/" . lfname

# max range (x):
# read from file, round to next 100 microseconds (0.0066097 -> 0.0067)
if (! exists("mr")) \
  mr = system("awk -F, 'BEGIN{td=0;} NR!=1 {ot=$1+$6;if(ot>td){td=ot;}} END{print (int(ot*10000)+1)/10000}' " . filename) #2e-3

pdflength = 11*(mr/2e-3)

# anhr: animation (half) range in seconds
# for animation frame, it sets xrange to 2*anhr; (in "real time" scale)
# mr is then limit for overall time in plot (last anim frame)
if (! exists("anhr")) \
  anhr = 500e-6

# anct: animation (current) time  (in "card time" scale)
# ants: animation time step ? not needed - controlled via extern, ends up as anct!
# anctCPU: what is the time in "cpu time" scale, for this "card time" anct
# setting anct from args is a trigger to start doing animation frame output;
# so do not set anct, if it's not passed as argument!
anctCPU = 0.0 ; anctRT = 0.0
if (doAnim) \
  pdflength = 11*(2*anhr/2e-3) ;
  #anctCPU = anct-2*rsf*anct # later

# now that pdflength finally decided, set pdf terminal
if (doPdf) \
  set terminal pdf size pdflength,5 ; \
  set output dir . "/" . fname . "_" . fnext . ".pdf" ; \
  set termoption font 'Latin Modern Sans Demi Cond,9.5' ; \


# max frames for pointers (relates to y spacing for pointer data):
# apparently, when coming in from system, it is treated as a float!
# find and return the biggest hw or appl _ptr!
# round (ceiling) mf to nearest next ten (e.g. 385->390)
if (! exists("mf")) \
  mf=system("awk -F, 'BEGIN{rm=0;} /,_pointer/ {if($11>rm){rm=$11;};if($12>rm){rm=$12;};} END{print rm}' " . filename ) ; mf=ceil(mf/10)*10.0 #mf = 64.0
# assuming full duplex latency test - where both playback and capture have same period/buffer sizes!
# period size in frames: (just for cardIRQ period for now)
if (! exists("psf")) \
  psf = system("awk '/period_size  :/{print $3;exit}' " . lfilename)+0.0 # 64.0
# period size quantize in frames: (just for cardIRQ period for now) aid for easier visualization
if (! exists("psq")) \
  psq = 32.0;
# buffer size in frames: (to wrap anim pointers)
if (! exists("bsf")) \
  bsf = system("awk '/buffer_size  :/{print $3;exit}' " . lfilename)+0.0 # 128.0


rep = rep . filename . " (_" . fnext . ")"
print rep

# CSV data; must set:
set datafile separator ","

# colors - see:
# http://www.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

# blueish hues
set style line 1 linetype 1 linewidth 1 pointtype 3 linecolor rgb "aquamarine"
set style line 2 linetype 1 linewidth 1 pointtype 3 linecolor rgb "blue"
set style line 3 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8A2BE2" #"blueviolet"
set style line 4 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#5F9EA0" #"cadetblue"
set style line 5 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#6495ED" #"cornflowerblue"
set style line 6 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#00008B" #"darkblue"
set style line 7 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#ADD8E6" #"lightblue"

# reddish hues
set style line 11 linetype 1 linewidth 1 pointtype 3 linecolor rgb "coral"
set style line 12 linetype 1 linewidth 1 pointtype 3 linecolor rgb "red"
set style line 13 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#DC143C" #"crimson"
set style line 14 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8B0000" #"darkred"
set style line 15 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FF8C00" #"darkorange"

# greenish hues
set style line 21 linetype 1 linewidth 1 pointtype 3 linecolor rgb "green"
set style line 22 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#006400" #"darkgreen"
set style line 23 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8FBC8F" #"darkseagreen"
set style line 24 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#556B2F" #"darkolivegreen"

# yellowish hues
set style line 31 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#AAAA00" # darkish yellow
set style line 32 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FFD700" #"gold"

# black/gray
set style line 41 linetype 1 linewidth 1 pointtype 3 linecolor rgb "black"
set style line 42 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#AAAAAA" # gray

# magentaish
set style line 51 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FF00FF" # magenta
set style line 52 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#BA55D3" # mediumorchid

# if pdf - keep colors, modify pointsizes;
if (doPdf) {
# blueish hues
set style line 1 pointsize 0.25
set style line 2 pointsize 0.25
set style line 3 pointsize 0.25
set style line 4 pointsize 0.25
set style line 5 pointsize 0.25
set style line 6 pointsize 0.25

# reddish hues
set style line 11 pointsize 0.25
set style line 12 pointsize 0.25
set style line 13 pointsize 0.25 linewidth 0.5
set style line 14 pointsize 0.25
set style line 15 pointsize 0.25

# greenish hues
set style line 21 pointsize 0.25
set style line 22 pointsize 0.25
set style line 23 pointsize 0.25
set style line 24 pointsize 0.25

# yellowish hues
set style line 31 pointsize 0.25
set style line 32 pointsize 0.25

# black/gray
set style line 41 pointsize 0.25
set style line 42 pointsize 0.25

# magentaish
set style line 51 pointsize 0.25
set style line 52 pointsize 0.25
} # if(doPdf)

# set clip two makes "drawing and clipping lines between two outrange points"
# default is otherwise noclip two "not drawing lines between two outrange points"
# (more important for animation frames, where there is zoom)
set clip two

# reminder for columns:
# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr
# line after mIRQ match: awk -F, '{if($7 == 3){getline; print $0}}'
fnUserspace = "<awk -F, '{if($7 == 1){print $0}}' " . filename
fnmIRQ      = "<awk -F, '{if($7 == 3){print $0}}' " . filename
fnKernFtsw   = "<awk -F, '{if($7 == 4){if(match($8, \"finish_task_switch()\")){print $0}}}' " . filename
# now using separate fnPointer for playback (0) and capture (1)
#~ fnPointer   = "<awk -F, '{if($7 == 2){print $0}}' " . filename
fnPointer0   = "<awk -F, '{if(($7 == 2) && ($14 == 0)){print $0}}' " . filename
fnPointer1   = "<awk -F, '{if(($7 == 2) && ($14 == 1)){print $0}}' " . filename


# since there are too many kernel functions,
# we'd want to filter them here - some depending on the filename!
# in either case - besides the custom functions we want -
# we'd also want the interrupts that are closest to
# the mIRQ - which is the line after ($7==3) ...
# NB: awk treats parenthesis () as regex expressions!
# In bash awk needs parentheses escaped twice
# with double quotes: "\\(\\)", so it treats them as regular chars!
# In here, that means we have to escape them *four* times;
# so we match e.g. snd_pcm_lib_read(), but not snd_pcm_lib_read1() !

# snd_pcm (ALSA) kernel functions (same for either filename)

fnKernSndPcm  = "<awk -F, '{ \
if($7 == 4){ \
if(\
  match($8, \"snd_pcm_capture_ioctl\\\\(\\\\)\") \
|| match($8, \"snd_pcm_playback_ioctl\\\\(\\\\)\") \
|| match($8, \"snd_pcm_lib_read\\\\(\\\\)\") \
|| match($8, \"snd_pcm_lib_write\\\\(\\\\)\") \
|| match($8, \"snd_pcm_start()\") \
|| match($8, \"snd_pcm_playback_hw_avail()\") \
|| match($8, \"snd_pcm_capture_hw_avail()\") \
|| match($8, \"snd_pcm_drain()\") \
|| match($8, \"snd_timer_notify()\") \
|| match($8, \"snd_pcm_update_hw_ptr\\\\(\\\\)\") \
|| match($8, \"snd_pcm_period_elapsed()\") \
|| match($8, \"snd_pcm_playback_poll\") \
|| match($8, \"snd_pcm_capture_poll\") \
) {print $0}; \
}; \
}' " . filename

# "other" kernel functions (same for either case)
# (here we capture closest to mIRQ)

fnKernFunc  = "<awk -F, '{ \
if($7 == 3){getline; print $0}; \
if($7 == 4){ \
if(\
 match($8, \"sys_ioctl()\") \
|| match($8, \"sys_poll()\") \
|| match($8, \"hrtick_update()\") \
) {print $0}; \
}; \
}' " . filename

# sound (ALSA) driver kernel functions (depends on capture filename)
fnKernSndDrv = ""

if (fname eq "trace-hda-intel.csv") {
fnKernSndDrv  = "<awk -F, '{ \
if($7 == 4){ \
if(\
 match($8, \"azx_pcm_trigger()\") \
|| match($8, \"azx_stream_start()\") \
|| match($8, \"azx_pcm_pointer()\") \
|| match($8, \"azx_interrupt()\") \
|| match($8, \"azx_position_ok()\") \
) {print $0}; \
}; \
}' " . filename
}
if (fname eq "trace-dummy.csv") {
fnKernSndDrv  = "<awk -F, '{ \
if($7 == 3){getline; print $0}; \
if($7 == 4){ \
if(\
 match($8, \"dummy_pcm_trigger()\") \
|| match($8, \"dummy_hrtimer_start()\") \
|| match($8, \"dummy_hrtimer_pointer()\") \
|| match($8, \"dummy_hrtimer_callback()\") \
|| match($8, \"dummy_hrtimer_pcm_elapsed()\") \
) {print $0}; \
}; \
}' " . filename
}




# multiple X axes ;
#  xtics scale refers to the size of tics!
#  xtics mirror refers to tics on the "other" (top) side!
#  set format x means the format of xtics (as in gprintf!)
#  for some reason, here set xlabel rotate by 90 does NOT work?!
#  also, forget xlabel, difficult to position it in a corner

# clock domain - crystal oscillator mismatch; typ: 100Hz for 10MHz: 100/10e6 = 1e-05; *100 = 0.001%
# here we could take 0.1% = 0.1/100 = 0.001 (timescalefactor)
# default time (x) maxrange = 2ms ;  delta = mr*(tsf/100) = '2*(0.1/100)' = 0.002
# but that is too small to be visible on graph -
# keep the values as float, and experiment below:
# (mr moved up - needed for PDF size calc)
tsfp = 0.2          # as percent; was 1.5
#if (! exists("mr")) \
#  mr = 2e-3
dlt = mr*(tsfp/100)
tsf=tsfp/100 #; tsfh=tsf/2.0 ;
rsf=tsf # finally decided range scale factor ; should use tsf, NOT the half (tsfh)! (since we work with half range (anhf)?)
if (doAnim) anctCPU = anct-2*rsf*anct ; anctRT = anct - rsf*anct ;


# NOTE: tried to split the below "plot" command into
# multiple "replot", for easier debugging; however,
# that tries to replot each line cumulatively, and
# the process takes a lot longer - and the PDF has
# multiple copies of tics, labels etc.
# Thus - here, do not use multiple "replot" where a
# single plot rendering is intended!


# "At first, make the figure height smaller, set the bottom margin zero, then enter the multiplot mode."
# cannot manipulate multiplot title - use a label instead
set size 1.0,0.60
set bmargin 0
set yrange [0:20]
set format x "%.2s%c"  #"%.3se%S"
set xtics rotate by 90 offset 0,graph -0.01 right
#set key off # make 'notitle' redundant for all plots
set key spacing 0.6 samplen 2 right font ",8"
set multiplot # title fname
set label 1 fname at graph 0.999, graph 0.999 right

set label 2 "CPU0" rotate by 90 at graph 0.0, first 2.5 center
set label 3 "CPU1" rotate by 90 at graph 0.0, first 7.5 center
set label 4 "(playback)" rotate by 90 at graph 0.0, first 12.5 center
set label 5 "(capture)" rotate by 90 at graph 0.0, first 17.5 center

c0o = 0.2   # cpu0 offset
c1o = 5.0   # cpu1 offset
th = 5.0    # "third of height" (yrange[0:15]) - same as "cpu1 offset"; now actually "quarter"
uso = 10.0  # userspace offset
isc = 0.09  # function indent scale
#~ mf = 64.0   # max frames for pointers # above, also via arg

# PLOT 01 (TOP) ##############
# "Raise the figure slightly, and plot the first (top) graph."
xlxofs=-0.46; if (doPdf) xlxofs=-0.493
xlyofs=0.05; if (doPdf) xlyofs=0.03;
kfxofs=0.8; if (doPdf) kfxofs=-0.25
kfyofs=1.1; if (doPdf) kfyofs=0.22
kfsz=",3"; if (doPdf) kfsz=",4"
usxofs=-0.8; if (doPdf) usxofs=-1.0
usyofs=2.0; if (doPdf) usyofs=2.2

# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr,13_dlay,14_strm
set origin 0,0.40
# zeros are synced, anct on card axis II center ; SLOWER
if (doAnim) {
  if (cfast) {  # PC slower
    set xrange [(1-rsf)*(anct-anhr)-rsf*anct:(1-rsf)*(anct+anhr)-rsf*anct] ;
  } else {      # PC faster
    set xrange [(1+rsf)*(anct-anhr)+rsf*anct:(1+rsf)*(anct+anhr)+rsf*anct] ;
  }
} else {
  if (cfast) {  # PC slower
    set xrange [0:mr-dlt] ; # x unit - tsfp% bigger (slower)
  } else {      # PC faster
    set xrange [0:mr+dlt] ;
  }
}
set border 1 # bitmask - only bottom border (x axis)
unset ytics # with ytics, all alignment is screwed!
set xtics nomirror 100e-6
#set xlabel "(PC) Time [s]" offset graph xlxofs,graph xlyofs
set label 10 "(PC) Time [s]" at graph 0, graph 0 offset character 0.6, character -0.5

# anim main time line - must be here, otherwise "behind" (goes behind ticks)/"back" (goes above ticks of current plot) don't work from second plot!
if (doAnim) \
  set object 1 rect center first anctCPU,screen 0.4+0.15+0.025 size screen 0.006,(1-0.15) back fc rgb "gray" fs transparent solid 0.5 noborder

plot \
  uso ls 2 notitle, \
  uso+th ls 2 notitle, \
  c1o ls 51 notitle, \
  fnKernFtsw using ($1):(0.5+c1o*$3):($1):($1+$6):(0.5+c1o*$3):(th+c1o*$3) with boxxyerrorbars \
    ls 15 fs solid 0.25 notitle, \
  fnmIRQ using ($1):(c0o+c1o*$3):($1):($1+$6) with xerrorbars ls 12 lw 2 notitle, \
  fnUserspace using ($1):(uso-0.1+$14*0.3) with impulses ls 2 notitle, \
  "" using ($1):(uso+$14*th):(stringcolumn(8)) with labels \
    point ls 2 pt 7 tc rgb "#6699FF" font ",8" \
    offset character usxofs,character usyofs rotate by 90 notitle, \
  fnKernFunc using ($1):(0.5+c1o*$3+isc*$9):($1):($1+$6) with xerrorbars ls 12 notitle, \
  "" using ($1):(0.5+c1o*$3+isc*$9):(stringcolumn(8)) with labels left \
    tc rgb "red" font kfsz \
    offset character kfxofs,character kfyofs rotate by 90 notitle, \
  fnKernSndPcm using ($1):(0.5+c1o*$3+isc*$9):($1):($1+$6) with xerrorbars ls 11 notitle, \
  "" using ($1):(0.5+c1o*$3+isc*$9):(stringcolumn(8)) with labels left \
    tc rgb "coral" font kfsz \
    offset character kfxofs,character kfyofs rotate by 90 notitle, \
  fnKernSndDrv using ($1):(0.5+c1o*$3+isc*$9):($1):($1+$6) with xerrorbars ls 13 notitle, \
  "" using ($1):(0.5+c1o*$3+isc*$9):(stringcolumn(8)) with labels left \
    tc rgb "#DC143C" font kfsz \
    offset character kfxofs,character kfyofs rotate by 90 notitle, \
  fnPointer0 using ($1):(1+c1o*$3) with impulses ls 3 lw 2 notitle, \
  "" using ($1):(uso-0.1+$14*0.3) with impulses ls 3 lw 1 notitle, \
  "" using ($1):(1+c1o*$3):(stringcolumn(8)) with labels \
    point ls 3 pt 7 tc rgb "#8A2BE2" font ",8" \
    offset character -1.0,character 1.0 rotate by 90 notitle, \
  "" using ($1):(uso+th*($10/mf+$14)) with linespoints ls 3 title "pointer_ pos", \
  "" using ($1):(uso+th*($10/mf+$14)):($10) with labels \
    tc rgb "#8A2BE2" font ",8" \
    offset character 0.0,character 0.7 rotate by 90 notitle, \
  "" using ($1):(uso+th*($11/mf+$14)) with linespoints ls 6 title "cl->appl_ptr", \
  "" using ($1):(uso+th*($11/mf+$14)):($11) with labels \
    tc rgb "#00008B" font ",8" \
    offset character 0.0,character -0.5 rotate by 90 notitle, \
  "" using ($1):(uso+th*($12/mf+$14)) with linespoints ls 14 title "stat->hw_ptr", \
  "" using ($1):(uso+th*($12/mf+$14)):($12) with labels \
    tc rgb "#8B0000" font ",8" \
    offset character 0.0,character 0.5 rotate by 90 notitle, \
  fnPointer1 using ($1):(1+c1o*$3) with impulses ls 3 lw 2 notitle, \
  "" using ($1):(uso-0.1+$14*0.3) with impulses ls 3 lw 1 notitle, \
  "" using ($1):(1+c1o*$3):(stringcolumn(8)) with labels \
    point ls 3 pt 7 tc rgb "#8A2BE2" font ",8" \
    offset character -1.0,character 1.0 rotate by 90 notitle, \
  "" using ($1):(uso+th*($10/mf+$14)) with linespoints ls 3 notitle, \
  "" using ($1):(uso+th*($10/mf+$14)):($10) with labels \
    tc rgb "#8A2BE2" font ",8" \
    offset character 0.0,character 0.7 rotate by 90 notitle, \
  "" using ($1):(uso+th*($11/mf+$14)) with linespoints ls 6 notitle, \
  "" using ($1):(uso+th*($11/mf+$14)):($11) with labels \
    tc rgb "#00008B" font ",8" \
    offset character 0.0,character -0.5 rotate by 90 notitle, \
  "" using ($1):(uso+th*($12/mf+$14)) with linespoints ls 14 notitle, \
  "" using ($1):(uso+th*($12/mf+$14)):($12) with labels \
    tc rgb "#8B0000" font ",8" \
    offset character 0.0,character 0.5 rotate by 90 notitle


set label 1 "" # reset for the other plots :/
set label 2 ""
set label 3 ""
set label 4 ""
set label 5 ""

unset object 1

round(x) = x - floor(x) < 0.5 ? floor(x) : ceil(x)
roundd(x,dec) = round(x*10**dec)/10.0**dec

# AXIS 02 & PLOT (MID) ##############
# "Now, lower the figure, and draw the X-axis only (middle graph)."
set origin 0,0.15
# zeros are synced, anct on card axis II center; FASTER
if (doAnim) {
  if (cfast) {  # card faster
    set xrange [(1+rsf)*(anct-anhr)-rsf*anct:(1+rsf)*(anct+anhr)-rsf*anct] ;
  } else {      # card slower
    set xrange [(1-rsf)*(anct-anhr)+rsf*anct:(1-rsf)*(anct+anhr)+rsf*anct] ;
  }
} else {
  if (cfast) {  # card faster
    set xrange [0:mr+dlt] ; # x unit - tsfp% smaller (faster)
  } else {      # card slower
    set xrange [0:mr-dlt] ;
  }
}
set yrange [0:4]
set xtics nomirror 100e-6
set noytics
xlyofs=0.25; if (doPdf) xlyofs=0.15;
#set xlabel "(Card) Time [s]" offset 0.0,graph xlyofs right
set label 10 "(Card) Time [s]" at graph 0, graph 0 offset character 0.6, character -0.5
set border 1
# Here, select only those mIRQ, which contain the
# hardware IRQ (azx_interrupt); and plot them
# in the card clock domain (which here is a bit faster)
# use floor to also simulate they happened a bit early:
# (floor($1*100000)/100000.0):(1)
# (last microsecond will be truncated);
# however, even without the floor(), because the x-axis time
# units differ, increasing lag is visible!
# expected card IRQ period: 32/44100 (in frames) = 0.000725624;
# rounded to microsecond: 0.000726 or 726 us;
# assume our first fake card IRQ is "correct",
# and then - plot next two "expected" IRQ as per IRQ period
# (in this clock domain) for comparison ..
# For hda-intel we have actual hardware interrupt, while
# for dummy we don't - we take the dummy_hrtimer_callback
# as a "virtual" representation of an interrupt in that case...
# (not used anymore - now in python script, via $14-stream dir); but keep
if (fname eq "trace-hda-intel.csv") {
cardIRQf = "azx_interrupt";
}
if (fname eq "trace-dummy.csv") {
cardIRQf = "dummy_hrtimer_callback";
}

# function to colorcode fakeCardIRQ
#  (use `lc variable` to set)
# undefined (-1): violet
# playback   (0): red
# capture    (1): blue
# NOTE: CANNOT return direct RGB here; must use 'a linetype index'!
#~ getcIRQColor(x) = (x==-1)?"violet":((x==0)?"#FF0000":"blue");
getcIRQColor(x) = (x==-1)?3:((x==0)?12:2);

# here the 'lc variable' color gets messed up for labels, use palette (SO:18368307)
# something is buggy here; without 2.9 "#8A2BE2" - then 3 is not actual "#8A2BE2"??!
# probably due to gradient calculation; with 2.9 & 4, apparently discontinuity is inserted
# also maxcolors 3 adds a fifth color before the red, also mixed! so keep like this:
set palette model RGB maxcolors 2
#~ set palette defined (2 "blue", 3 "#8A2BE2", 12 "red")
set palette defined (2 "blue", 2.9 "#8A2BE2", 4 "#8A2BE2", 12 "red")
unset colorbox

#~ psf = 64.0; # period size in frames (above); just for cardIRQ period for now
#~ psq = 32.0; # period size quantize in frames (above); aid for easier visualization
if (psq > psf) psq = psf

rate = 44100
# as float:
irqper = psf/rate
# as float - w/ rounded decimals
irqrper = round(irqper*1e6)/1e6

# for the "quant" period (easier visualization)
qirqper = psq/rate
qirqrper = round(qirqper*1e6)/1e6

# calculate needed number of periods - steps - to cover log capture x-axis
npf = round(mr/irqper)
# also calculate number of quantized periods
npq = round(npf*(psf/psq))

#~ fnFakeCardIRQ = "<awk -F, '{if($7==3){tl=$0};if($7==4){if(match($8,\"" . cardIRQf . "\")){print tl;}}}' " . filename # old
fnFakeCardIRQ = "<awk -F, '{if($7==3 && $14>=-1){print;}};' " . filename

# fakeCardIRQStart = fCIRQS
#~ fCIRQS = system("awk -F, '{if($7==3){tl=$1};if($7==4){if(match($8,\"" . cardIRQf . "\")){print tl;exit}}}' " . filename) # old
fCIRQS = system("awk -F, '{if($7==3 && $14>=-1){print $1; exit}};' " . filename)
# also, take the first time play/capt IRQs have .pointer, and subtract period from that, for a tentative start comparison
# get actual timestamps first
fCIRQpts = system("awk -F, '{if($7==3){if($14==0){print $1;exit}}}' " . filename)
fCIRQcts = system("awk -F, '{if($7==3){if($14==1){print $1;exit}}}' " . filename)
#~ print "AA ", fCIRQpts, " - ", fCIRQcts, " - " , irqper
# fakeCardIRQStart playback(0) = fCIRQSp
fCIRQSp = fCIRQpts - irqper
# fakeCardIRQStart capture(1) = fCIRQSc
fCIRQSc = fCIRQcts - irqper

fnThreeSteps = '<echo -e "\n0\n1\n2"'

fnPqSteps = '<seq 0 1 ' . sprintf("%d", npq-1)
qplabel = sprintf("%d", psq) . "/" . sprintf("%d", rate) . " = " . sprintf("%d", round(qirqper*1e6)) . " us"


plot \
  fnPqSteps using (fCIRQS+$1*qirqper):(0.4) with impulses ls 42 lw 6 notitle, \
  "" using (fCIRQS+$1*qirqper):(0.2):(fCIRQS+$1*qirqper):(fCIRQS+($1+1)*qirqper) with xerrorbars \
    ls 42 lw 2.5 pointtype 3 pointsize 1 notitle, \
  "" using (fCIRQS+($1+0.5)*qirqper):(0.2):(qplabel) with labels center \
    tc rgb "#AAAAAA" font ",6" \
    offset character 0,character 0.3 notitle, \
  "" using (fCIRQSp+$1*qirqper):(0.5):(fCIRQSp+$1*qirqper):(fCIRQSp+($1+1)*qirqper) with xerrorbars \
    ls 12 lw 2.0 pointtype 3 pointsize 1 notitle, \
  "" using (fCIRQSc+$1*qirqper):(0.7):(fCIRQSc+$1*qirqper):(fCIRQSc+($1+1)*qirqper) with xerrorbars \
    ls 2 lw 2.0 pointtype 3 pointsize 1 notitle, \
  fnFakeCardIRQ using ($1):(1):(getcIRQColor($14)) with impulses ls 12 lw 2 lc variable notitle,\
  "" using ($1):(1):("CardIRQ?"):(getcIRQColor($14)) with labels \
    point ls 12 pt 7 lc palette textcolor palette font ",6" \
    offset character -0.8,character 1.0 rotate by 90 notitle


# AXIS 03 (BOTTOM) ##############
# Now, lower the figure again, and draw the X-axis only (bottom graph).
set origin 0,0.05
 # zeros are synced, anct on card axis II center
if (doAnim) {
  if (cfast) { # sync with card faster time
    set xrange [anct-anhr-rsf*anct:anct+anhr-rsf*anct] ;
  } else {     # sync with card slower time
    set xrange [anct-anhr+rsf*anct:anct+anhr+rsf*anct] ;
  }
} else {
  set xrange [0:mr] ; # x unit == 1
}
set format x "" # disable tics labels
set xtics nomirror 100e-6 offset 0,graph 0.08 left
set noytics
xlyofs=0.5; if (doPdf) xlyofs=0.05;
#set xlabel "('Real') Time [s]" offset graph xlxofs,graph xlyofs
set label 10 "('Real') Time [s]" at graph 0, graph 0 offset character 0.6, character -0.5
set border 1

if (doAnim) {
  # get _pointer values for current time (anct) - but in PC time (anctCPU)
  # for playback (0) and capture (1):
  anctCPUs=sprintf("%.6f",anctCPU)
  playvars = system("awk -F, 'BEGIN{p=h=a=d=0;} {if($7==2 && $14==0){p=$10;a=$11;h=$12;d=$13;}}{if($1>=".anctCPUs."){print p,a,h,d;exit}}' " . filename)
  captvars = system("awk -F, 'BEGIN{p=h=a=d=0;} {if($7==2 && $14==1){p=$10;a=$11;h=$12;d=$13;}}{if($1>=".anctCPUs."){print p,a,h,d;exit}}' " . filename)
  # split space-separated string results in gnuplot
  tstr=playvars; i=0;
  i=strstrt(tstr," "); pp=tstr[1:i]; tstr=tstr[i+1:];   # .pointer is already wrapped
  i=strstrt(tstr," "); oap=tstr[1:i]; tstr=tstr[i+1:];
  i=strstrt(tstr," "); ohp=tstr[1:i]; tstr=tstr[i+1:];
  odp=tstr[1:];
  pp=int(pp); ap= int(oap) % int(bsf); hp= int(ohp) % int(bsf); # wrap appl_ and hw_ ptr
  tstr=captvars; i=0;
  i=strstrt(tstr," "); pc=tstr[1:i]; tstr=tstr[i+1:];   # .pointer is already wrapped
  i=strstrt(tstr," "); oac=tstr[1:i]; tstr=tstr[i+1:];
  i=strstrt(tstr," "); ohc=tstr[1:i]; tstr=tstr[i+1:];
  odc=tstr[1:];
  pc=int(pc); ac= int(oac) % int(bsf); hc= int(ohc) % int(bsf); # wrap appl_ and hw_ ptr

  #~ GRAPH_X(x) = (x - GPVAL_X_MIN) / (GPVAL_X_MAX - GPVAL_X_MIN)
  #~ GRAPH_Y(y) = (y - GPVAL_Y_MIN) / (GPVAL_Y_MAX - GPVAL_Y_MIN)
  #~ SCREEN_X(x) = GPVAL_TERM_XMIN + GRAPH_X(x) * (GPVAL_TERM_XMAX - GPVAL_TERM_XMIN)
  #~ SCREEN_Y(y) = GPVAL_TERM_YMIN + GRAPH_Y(y) * (GPVAL_TERM_YMAX - GPVAL_TERM_YMIN)
  #~ FRAC_X(x) = SCREEN_X(x) / GPVAL_TERM_XSIZE
  #~ FRAC_Y(y) = SCREEN_Y(y) / GPVAL_TERM_YSIZE
  set object 2 rect center first anctRT,screen 0.075 size screen 0.15,screen 0.125
  set object 2 rect front fc rgb "gray" fs transparent solid 0.8 noborder
  set label 20 "(Card) Time:\n".gprintf("%.2s%c",anct) at first anctRT,first 0 left
  set label 20 rotate by 90 front offset character -2, character -0.5
  nbx=8         # num boxes in buffer visualization
  tsz=0.224/nbx # size of box via total/num
  #~ set for [i=1:16] object 10+i rect at screen 0.4,screen 0.7+tsz*i size graph tsz,graph tsz fs empty border rgb "blue"
  ##print tsz, "---", GRAPH_Y(tsz), FRAC_Y(tsz), SCREEN_Y(tsz), GRAPH_Y(0.0), FRAC_Y(0.0), FRAC_Y((1+nbx/2)*tsz)
  #fcy=FRAC_Y((nbx/2)*tsz)
  xp = 0.398 ;
  ybA= 0.697 ; # bottom edge in y coord - rotated it's left edge
  #ygff=GRAPH_Y(1.0)/FRAC_Y(1.0) # y graph/frac factor - not always consistent!
  gfs(y)=y*0.59 # graph/frac factor size ; trial-error :/
  lofy=0.005 # label offset y
  bgys=0.142          # big gray y size
  bgoy=bgys/2-0.003   # big gray offset y
  scy=nbx*gfs(tsz)    # y size of white bckg, and scale for the pointers
  aln=0.03  # ponter arrow length

  # (playback)
  # gray big bckg
  set object 10 rect center screen xp,screen ybA+bgoy size screen 0.15,screen bgys
  set object 10 rect fc rgb "gray" fs transparent solid 0.8 noborder
  # white small bckg
  set object 11 rect center screen xp,screen ybA+lofy+nbx*gfs(tsz)/2 size graph tsz,screen scy
  set object 11 rect fc rgb "white"
  # label marker
  set label 21 "P" at screen xp-0.002,screen ybA-0.0042 rotate by 90 tc rgb "red"
  # label buffer size
  lbpo=0.002
  set label 22 sprintf("%d",bsf) at screen xp-0.002,screen ybA+nbx*gfs(tsz)+lbpo
  set label 22 font ",5" center tc rgb "dark-grey"
  # label period size
  set label 23 sprintf("%d",psf) at screen xp-0.002,screen ybA+(psf/bsf)*nbx*gfs(tsz)+lbpo
  set label 23 font ",5" center tc rgb "dark-grey"
  # for playback, appl_ptr on top; .pointer/hw_ptr on bottom
  # appl_ptr
  apy=ybA+lofy+(ap/bsf)*scy
  apx=xp-tsz/2
  if (ap/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 24 from screen apx-aln,screen apy to screen apx,screen apy
  set arrow 24 ls 6 lw 2
  eval 'set label 24 "a:".oap at screen apx-aln,screen apy ' . algn
  set label 24 font ",6" rotate by 90 tc ls 6
  set object 14 rect from screen apx,screen ybA+lofy to screen apx+tsz/3, screen apy
  set object 14 rect fc ls 6 fs transparent solid 0.4 noborder
  # .pointer
  ppy=ybA+lofy+(pp/bsf)*scy
  ppx=xp+tsz/2
  if (pp/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 25 from screen ppx+aln,screen ppy to screen ppx,screen ppy
  set arrow 25 ls 3 lw 2
  eval 'set label 25 sprintf("p:%d",pp) at screen ppx+aln*0.69,screen ppy ' . algn
  set label 25 font ",6" rotate by 90 tc ls 3
  set object 15 rect from screen apx+tsz/3,screen ybA+lofy to screen apx+2*tsz/3, screen ppy
  set object 15 rect fc ls 3 fs transparent solid 0.4 noborder
  # hw_ptr
  hpy=ybA+lofy+(hp/bsf)*scy
  hpx=xp+tsz/2+aln
  if (hp/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 26 from screen hpx+aln,screen hpy to screen hpx,screen hpy
  set arrow 26 ls 14 lw 2
  eval 'set label 26 "h:".ohp at screen hpx+aln*.69,screen hpy ' . algn
  set label 26 font ",6" rotate by 90 tc ls 14
  set object 16 rect from screen apx+2*tsz/3,screen ybA+lofy to screen apx+tsz, screen hpy
  set object 16 rect fc ls 14 fs transparent solid 0.4 noborder
  # runtime delay label
  set label 27 "d:".odp at screen xp-0.45*bgys,screen ybA
  set label 27 font ",6" rotate by 90
  # boxes - front so they're over the arrows (16+16 = 32)
  set for [i=1:nbx] object 16+i rect at screen xp,screen ybA+lofy+(i-0.5)*gfs(tsz) \
    size graph tsz,graph tsz front fs empty border rgb "black"


  # (capture)
  ybB= 0.843 ; # bottom edge in y coord - rotated it's left edge

  # gray big bckg
  set object 40 rect center screen xp,screen ybB+bgoy size screen 0.15,screen bgys
  set object 40 rect fc rgb "gray" fs transparent solid 0.8 noborder
  # white small bckg
  set object 41 rect center screen xp,screen ybB+lofy+nbx*gfs(tsz)/2 size graph tsz,screen scy
  set object 41 rect fc rgb "white"
  # label marker
  set label 51 "C" at screen xp-0.002,screen ybB-0.0042 rotate by 90 tc rgb "blue"
  # label buffer size
  set label 52 sprintf("%d",bsf) at screen xp-0.002,screen ybB+nbx*gfs(tsz)+lbpo
  set label 52 font ",5" center tc rgb "dark-grey"
  # label period size
  set label 53 sprintf("%d",psf) at screen xp-0.002,screen ybB+(psf/bsf)*nbx*gfs(tsz)+lbpo
  set label 53 font ",5" center tc rgb "dark-grey"
  # for capture, appl_ptr on bottom; .pointer/hw_ptr on top
  # appl_ptr
  acy=ybB+lofy+(ac/bsf)*scy
  acx=xp+tsz/2
  if (ac/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 54 from screen acx+aln,screen acy to screen acx,screen acy
  set arrow 54 ls 6 lw 2
  eval 'set label 54 "a:".oac at screen acx+aln*0.69,screen acy ' . algn
  set label 54 font ",6" rotate by 90 tc ls 6
  set object 44 rect from screen acx-tsz/3,screen ybB+lofy to screen acx, screen acy
  set object 44 rect fc ls 6 fs transparent solid 0.4 noborder
  # .pointer
  pcy=ybB+lofy+(pc/bsf)*scy
  pcx=xp-tsz/2-aln #xp-tsz/2
  if (pc/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 55 from screen pcx-aln,screen pcy to screen pcx,screen pcy
  set arrow 55 ls 3 lw 2
  eval 'set label 55 sprintf("p:%d",pc) at screen pcx-aln*.8,screen pcy ' . algn
  set label 55 font ",6" rotate by 90 tc ls 3
  set object 45 rect from screen pcx+aln,screen ybB+lofy to screen pcx+aln+tsz/3, screen pcy #pcx+tsz/3,screen ybB+lofy to screen pcx+2*tsz/3, screen pcy
  set object 45 rect fc ls 3 fs transparent solid 0.4 noborder
  # hw_ptr
  hcy=ybB+lofy+(hc/bsf)*scy
  hcx=xp-tsz/2 #xp-tsz/2-aln
  if (hc/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 56 from screen hcx-aln,screen hcy to screen hcx,screen hcy
  set arrow 56 ls 14 lw 2
  eval 'set label 56 "h:".ohc at screen hcx-aln*0.8,screen hcy ' . algn
  set label 56 font ",6" rotate by 90 tc ls 14
  set object 46 rect from screen hcx+tsz/3,screen ybB+lofy to screen hcx+2*tsz/3, screen hcy #hcx+aln,screen ybB+lofy to screen hcx+aln+tsz/3, screen hcy
  set object 46 rect fc ls 14 fs transparent solid 0.4 noborder
  # runtime delay label
  set label 57 "d:".odc at screen xp+0.45*bgys,screen ybB
  set label 57 font ",6" rotate by 90
  # boxes - front so they're over the arrows (46+16 = 62)
  set for [i=1:nbx] object 46+i rect at screen xp,screen ybB+lofy+(i-0.5)*gfs(tsz) \
    size graph tsz,graph tsz front fs empty border rgb "black"

  # (card fifo/buffers)
  ybC= 0.168 ;

  # as start of interpolation, get .pointer frames at first definitely known playback/capture mIRQs (fake card)
  # as it may be .pointer is wrapped here, get also hw_ptr frames to see if that is the case
  # (must add comma to awk print; else no space is printed!)
  fCIRQpfs = system("awk -F, 'BEGIN{i=0;} {if($7==3 && $14==0){i=1;}} {if(i==1 && $7==2 && $14==0){print $10,$12;exit;}}' " . filename)
  fCIRQcfs = system("awk -F, 'BEGIN{i=0;} {if($7==3 && $14==1){i=1;}} {if(i==1 && $7==2 && $14==1){print $10,$12;exit;}}' " . filename)

  # split space-separated string results in gnuplot
  tstr=fCIRQpfs; i=0;
  i=strstrt(tstr," "); fCIRQpf=tstr[1:i]+0; tstr=tstr[i+1:];
  fCIRQphf=tstr[1:]+0;
  tstr=fCIRQcfs; i=0;
  i=strstrt(tstr," "); fCIRQcf=tstr[1:i]+0; tstr=tstr[i+1:];
  fCIRQchf=tstr[1:]+0;
  #print fCIRQpf, "-", fCIRQphf, "-", fCIRQcf, "-", fCIRQchf;

  # (p,c)fs - frames start "string"
  # (p,c)f  - _pointer frames start
  # (p,c)hf - hw_ptr frames start
  # (p,c)ts - actual timestamp of start
  prd = 1.0/rate
  anctf = anct / prd;
  icpcum = 0; icccum = 0; # cumulative - in respect to first proper IRQ timestamp
  if (anct >= fCIRQpts) {
    fCpf = fCIRQpts/prd;
    fCpadd = (fCIRQpf >= fCIRQphf) ? int(fCIRQphf/bsf)*bsf+fCIRQpf : int(fCIRQphf/bsf+1)*bsf+fCIRQpf;
    icpcum = int(anctf)-int(fCpf)+int(fCpadd); #int(anctf-fCpf+fCpadd); # separate int() for synchronous interp. p&c update
  }
  if (anct >= fCIRQcts) {
    fCcf = fCIRQcts/prd;
    fCcadd = (fCIRQcf >= fCIRQchf) ? int(fCIRQchf/bsf)*bsf+fCIRQcf : int(fCIRQchf/bsf+1)*bsf+fCIRQcf;
    icccum = int(anctf)-int(fCcf)+int(fCcadd); #int(anctf-fCcf+fCcadd); # separate int() for synchronous interp. p&c update
  }
  icp = int(icpcum)%int(bsf) ; icc = int(icccum)%int(bsf); # (interpolated) card pointers
  #print sprintf("f %s anctf %.6f:  fCIRQcf %.3f fCIRQchf %.3f  fCcf %.3f fCcadd %.3f icccum %d icc %d",fnext,anctf,fCIRQcf,fCIRQchf,fCcf,fCcadd,icccum,icc)
  #print sprintf("f %s anctf %.6f:  fCIRQpf %.3f fCIRQphf %.3f  fCpf %.3f fCpadd %.3f icpcum %d icp %d",fnext,anctf,fCIRQpf,fCIRQphf,fCpf,fCpadd,icpcum,icp)

  # modify xp position due changing gray big bckg size
  xp = xp-1.5*aln
  wx= 0.15+3*aln
  # gray big bckg
  set object 70 rect center screen xp,screen ybC+bgoy size screen wx,screen bgys
  set object 70 rect fc rgb "gray" fs transparent solid 0.8 noborder

  # (playback)
  xpCp= xp-aln;

  # white small bckg
  set object 71 rect center screen xpCp,screen ybC+lofy+nbx*gfs(tsz)/2 size graph tsz,screen scy
  set object 71 rect fc rgb "white"
  # label marker
  set label 81 "P" at screen xpCp-0.002,screen ybC-0.0042 rotate by 90 tc rgb "red"
  # label buffer size
  set label 82 sprintf("%d",bsf) at screen xpCp-0.002,screen ybC+nbx*gfs(tsz)+lbpo
  set label 82 font ",5" center tc rgb "dark-grey"
  # label period size
  set label 83 sprintf("%d",psf) at screen xpCp-0.002,screen ybC+(psf/bsf)*nbx*gfs(tsz)+lbpo
  set label 83 font ",5" center tc rgb "dark-grey"
  # (interpolated) card playback ptr
  cppy=ybC+lofy+(icp/bsf)*scy
  cppx=xpCp-tsz/2
  clo=0.004 # label offset
  if (icp/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 84 from screen cppx-aln,screen cppy to screen cppx,screen cppy
  set arrow 84 lw 2 lc rgb "red"
  eval 'set label 84 sprintf("p:%d",icpcum) at screen cppx-aln+clo,screen cppy ' . algn
  set label 84 font ",6" rotate by 90 tc rgb "red"
  set object 74 rect from screen cppx,screen ybC+lofy to screen cppx+tsz/3, screen cppy
  set object 74 rect fc rgb "red" fs transparent solid 0.4 noborder
  # playback .pointer (cumulative)
  chpy=ybC+lofy+(pp/bsf)*scy
  chpx=cppx
  if (pp/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 86 from screen chpx+2*aln,screen chpy to screen chpx+aln,screen chpy
  set arrow 86 ls 3 lw 2
  ppcum= (pp>=hp) ? int(ohp/bsf)*bsf+pp : int(ohp/bsf+1)*bsf+pp; # calculate cumulative .pointer
  eval 'set label 86 sprintf("p:%d",ppcum) at screen chpx+2*(aln-1.1*clo),screen chpy ' . algn
  set label 86 font ",6" rotate by 90 tc ls 3
  set object 76 rect from screen chpx+2*tsz/3,screen ybC+lofy to screen chpx+tsz, screen chpy
  set object 76 rect fc ls 3 fs transparent solid 0.4 noborder
  # boxes - front so they're over the arrows (76+16 = 92)
  set for [i=1:nbx] object 76+i rect at screen xpCp,screen ybC+lofy+(i-0.5)*gfs(tsz) \
    size graph tsz,graph tsz front fs empty border rgb "black"

  # (capture)
  xpCc= xp+2*aln;

  # white small bckg
  set object 101 rect center screen xpCc,screen ybC+lofy+nbx*gfs(tsz)/2 size graph tsz,screen scy
  set object 101 rect fc rgb "white"
  # label marker
  set label 111 "C" at screen xpCc-0.002,screen ybC-0.0042 rotate by 90 tc rgb "blue"
  # label buffer size
  set label 112 sprintf("%d",bsf) at screen xpCc-0.002,screen ybC+nbx*gfs(tsz)+lbpo
  set label 112 font ",5" center tc rgb "dark-grey"
  # label period size
  set label 113 sprintf("%d",psf) at screen xpCc-0.002,screen ybC+(psf/bsf)*nbx*gfs(tsz)+lbpo
  set label 113 font ",5" center tc rgb "dark-grey"
  # (interpolated) card capture ptr
  cpcy=ybC+lofy+(icc/bsf)*scy
  cpcx=xpCc+tsz/2
  if (icc/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 114 from screen cpcx+aln,screen cpcy to screen cpcx,screen cpcy
  set arrow 114 lw 2 lc rgb "blue"
  eval 'set label 114 sprintf("c:%d",icccum) at screen cpcx+0.5*aln+clo,screen cpcy ' . algn
  set label 114 font ",6" rotate by 90 tc rgb "blue"
  set object 104 rect from screen cpcx,screen ybC+lofy to screen cpcx-tsz/3, screen cpcy
  set object 104 rect fc rgb "blue" fs transparent solid 0.4 noborder
  # capture .pointer
  chcy=ybC+lofy+(pc/bsf)*scy
  chcx=xpCc-tsz/2
  if (pc/bsf < 0.5) { algn="left" ; } else { algn="right" ; } ;
  set arrow 106 from screen chcx-aln,screen chcy to screen chcx,screen chcy
  set arrow 106 ls 3 lw 2
  pccum= (pc>=hc) ? int(ohc/bsf)*bsf+pc : int(ohc/bsf+1)*bsf+pc; # calculate cumulative .pointer
  eval 'set label 106 sprintf("p:%d",pccum) at screen chcx-aln+clo,screen chcy ' . algn
  set label 106 font ",6" rotate by 90 tc ls 3
  set object 116 rect from screen chcx,screen ybC+lofy to screen chcx+tsz/3, screen chcy
  set object 116 rect fc ls 3 fs transparent solid 0.4 noborder
  # boxes - front so they're over the arrows (116+16 = 132)
  set for [i=1:nbx] object 116+i rect at screen xpCc,screen ybC+lofy+(i-0.5)*gfs(tsz) \
    size graph tsz,graph tsz front fs empty border rgb "black"

  # (delta labels)
  ppcdelta = ppcum-pccum;
  set label 130 sprintf("Δpc:%d",ppcdelta) at screen xp-wx/2+1.5*clo,screen ybC
  set label 130 font ",6" rotate by 90 tc ls 3
  ipcdelta = icpcum-icccum;
  set label 131 sprintf("Δpc:%d",ipcdelta) at screen xp-wx/2+5.5*clo,screen ybC
  set label 131 font ",6" rotate by 90 tc rgb "black"
}

plot -1 notitle

# exit multiplot
set nomultiplot

