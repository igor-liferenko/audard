#!/usr/bin/env gnuplot
################################################################################
# traceFGTXLogGraph.gp                                                         #
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

if (! exists("fnext")) \
  fnext='' ;

if (! exists("dir")) \
  dir='.' ;

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


doPdf=0

# max range (x):
if (! exists("mr")) \
  mr = 2e-3

if (! exists("fname")) \
  reset ; \
  clear ; \
  rep="no filename argument - using wxt terminal and hardcoded input: " ; \
  set terminal wxt ; \
  set termoption font 'Latin Modern Sans Demi Cond,9.5' ; \
else \
  rep="got filename argument - using pdf terminal: " ; \
  doPdf=1 ; \
  set terminal pdf size 11*(mr/2e-3),5 ; \
  set output dir . "/" . fname . "_" . fnext . ".pdf" ; \
  set termoption font 'Latin Modern Sans Demi Cond,9.5' ; \
  #~ show output


# new style "if" here; which supports multiline if{} - gnuplot > 4.4
# so the hardcoded values can be easily (un)commented if browsing in wxt

# you should first run `run-alsa-capttest.sh`; to obtain .csv captures;
# then paste them below, (un)comment accordingly;

if (! exists("fname")) {
  dir = "./captures-2013-07-31-05-20-17" ;
  fname = "trace-hda-intel.csv" ;
#  fname = "trace-dummy.csv" ;
}

filename = dir . "/" . fname ;

rep = rep . filename . " (_" . fnext . ")"
print rep

# CSV data; must set:
set datafile separator ","

# colors - see: gnuplot -e "show colornames" 2>&1 | less
# http://www.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

# blueish hues
set style line 1 linetype 1 linewidth 1 pointtype 3 linecolor rgb "aquamarine"
set style line 2 linetype 1 linewidth 1 pointtype 3 linecolor rgb "blue"
set style line 3 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8A2BE2" #"blueviolet"
set style line 4 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#5F9EA0" #"cadetblue"
set style line 5 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#6495ED" #"cornflowerblue"
set style line 6 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#00008B" #"darkblue"

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



# reminder for columns:
# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr
# line after mIRQ match: awk -F, '{if($7 == 3){getline; print $0}}'
fnUserspace = "<awk -F, '{if($7 == 1){print $0}}' " . filename
fnPointer   = "<awk -F, '{if($7 == 2){print $0}}' " . filename
fnmIRQ      = "<awk -F, '{if($7 == 3){print $0}}' " . filename
fnKernFtsw   = "<awk -F, '{if($7 == 4){if(match($8, \"finish_task_switch()\")){print $0}}}' " . filename


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

# clock domain - crystal oscillator mismatch; typ: 100Hz for 10MHz: 100/10e6 = 1e-05; *100 = 0.001%
# here we could take 0.1% = 0.1/100 = 0.001 (timescalefactor)
# default time (x) maxrange = 2ms ;  delta = mr*(tsf/100) = '2*(0.1/100)' = 0.002
# but that is too small to be visible on graph -
# keep the values as float, and experiment below:
# (mr moved up - needed for PDF size calc)
tsfp = 1.5          # as percent
#if (! exists("mr")) \
#  mr = 2e-3
dlt = mr*(tsfp/100)


# "At first, make the figure height smaller, set the bottom margin zero, then enter the multiplot mode."
# cannot manipulate multiplot title - use a label instead
set size 1.0,0.45
set bmargin 0
set yrange [0:15]
set format x "%.2s%c"  #"%.3se%S"
set xtics rotate by 90 offset 0,graph -0.01 right
#set key off # make 'notitle' redundant for all plots
set key spacing 0.6 samplen 2 right font ",8"
set multiplot # title fname
set label 1 fname at graph 0.999, graph 0.999 right

c0o = 0.2   # cpu0 offset
c1o = 5.0   # cpu1 offset
th = 5.0    # "third of height" (yrange[0:15]) - same as "cpu1 offset"
uso = 10.0  # userspace offset
isc = 0.09  # function indent scale

# PLOT 01 (TOP) ##############
# "Raise the figure slightly, and plot the first (top) graph."
xlxofs=-0.46; if (doPdf) xlxofs=-0.477
xlyofs=0.05; if (doPdf) xlyofs=0.03;
kfxofs=0.8; if (doPdf) kfxofs=-0.25
kfyofs=1.1; if (doPdf) kfyofs=0.22
kfsz=",3"; if (doPdf) kfsz=",4"
usxofs=-0.8; if (doPdf) usxofs=-1.0
usyofs=2.0; if (doPdf) usyofs=2.2

# 1_time,2_ktime,3_cpu,4_proc,5_pid,6_durn,7_ftype,8_func,9_findent,10_ppos,11_aptr,12_hptr
set origin 0,0.55
set xrange [0:mr-dlt] # x unit - tsfp% bigger (slower)
set border 1 # bitmask - only bottom border (x axis)
unset ytics # with ytics, all alignment is screwed!
set xtics nomirror 100e-6
set xlabel "(PC) Time [s]" offset graph xlxofs,graph xlyofs
plot \
  uso ls 2 notitle, \
  c1o ls 51 notitle, \
  fnKernFtsw using ($1):(0.5+c1o*$3):($1):($1+$6):(0.5+c1o*$3):(th+c1o*$3) with boxxyerrorbars \
    ls 15 fs solid 0.25 notitle, \
  fnmIRQ using ($1):(c0o+c1o*$3):($1):($1+$6) with xerrorbars ls 12 lw 2 notitle, \
  fnUserspace using ($1):(uso) with impulses ls 2 notitle, \
  "" using ($1):(uso):(stringcolumn(8)) with labels \
    point ls 2 pt 7 tc rgb "blue" font ",8" \
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
  fnPointer using ($1):(1+c1o*$3) with impulses ls 3 lw 2 notitle, \
  "" using ($1):(9.9) with impulses ls 3 lw 1 notitle, \
  "" using ($1):(1+c1o*$3):(stringcolumn(8)) with labels \
    point ls 3 pt 7 tc rgb "#8A2BE2" font ",8" \
    offset character -1.0,character 1.0 rotate by 90 notitle, \
  "" using ($1):(uso+th*($10/64.0)) with linespoints ls 3 title "pointer_ pos", \
  "" using ($1):(uso+th*($10/64.0)):($10) with labels \
    tc rgb "#8A2BE2" font ",8" \
    offset character 0.0,character 0.7 rotate by 90 notitle, \
  "" using ($1):(uso+th*($11/64.0)) with linespoints ls 6 title "cl->appl_ptr", \
  "" using ($1):(uso+th*($11/64.0)):($11) with labels \
    tc rgb "#00008B" font ",8" \
    offset character 0.0,character -0.5 rotate by 90 notitle, \
  "" using ($1):(uso+th*($12/64.0)) with linespoints ls 14 title "stat->hw_ptr", \
  "" using ($1):(uso+th*($12/64.0)):($12) with labels \
    tc rgb "#8B0000" font ",8" \
    offset character 0.0,character 0.5 rotate by 90 notitle


set label 1 "" # reset for the other plots :/

round(x) = x - floor(x) < 0.5 ? floor(x) : ceil(x)

# AXIS 02 & PLOT (MID) ##############
# "Now, lower the figure, and draw the X-axis only (middle graph)."
set origin 0,0.32
set xrange [0:mr+dlt] # x unit - tsfp% smaller (slower)
set yrange [0:4]
set xtics nomirror 100e-6
set noytics
xlyofs=0.25; if (doPdf) xlyofs=0.15;
set xlabel "(Card) Time [s]" offset graph xlxofs,graph xlyofs
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
if (fname eq "trace-hda-intel.csv") {
cardIRQf = "azx_interrupt";
}
if (fname eq "trace-dummy.csv") {
cardIRQf = "dummy_hrtimer_callback";
}

irqper = 32.0/44100
irqrper = round(irqper*1e6)/1e6
# fakeCardIRQStart = fCIRQS
fCIRQS = system("awk -F, '{if($7==3){tl=$1};if($7==4){if(match($8,\"" . cardIRQf . "\")){print tl;exit}}}' " . filename)
fnFakeCardIRQ = "<awk -F, '{if($7==3){tl=$0};if($7==4){if(match($8,\"" . cardIRQf . "\")){print tl;}}}' " . filename
fnThreeSteps = '<echo -e "\n0\n1\n2"'
plot \
  fnThreeSteps using (fCIRQS+$1*irqper):(0.9) with impulses ls 42 lw 6 notitle, \
  "" using (fCIRQS+$1*irqper):(0.2):(fCIRQS+$1*irqper):(fCIRQS+($1+1)*irqper) with xerrorbars \
    ls 42 lw 1.5 pointtype 3 pointsize 1 notitle, \
  "" using (fCIRQS+($1+0.5)*irqper):(0.2):("32/44100 = 726 us") with labels center \
    tc rgb "#AAAAAA" font ",6" \
    offset character 0,character 0.3 notitle, \
  fnFakeCardIRQ using ($1):(1) with impulses ls 12 lw 2 notitle,\
  "" using ($1):(1):("CardIRQ?") with labels \
    point ls 12 pt 7 tc rgb "red" font ",6" \
    offset character -0.8,character 1.0 rotate by 90 notitle

# AXIS 03 (BOTTOM) ##############
# Now, lower the figure again, and draw the X-axis only (bottom graph).
set origin 0,0.05
set xrange [0:mr] # x unit == 1
set xtics nomirror 100e-6 offset 0,graph 0.08 left
set noytics
xlyofs=0.5; if (doPdf) xlyofs=0.25;
set xlabel "('Real') Time [s]" offset graph xlxofs,graph xlyofs
set border 1
plot -1 notitle

# exit multiplot
set nomultiplot

