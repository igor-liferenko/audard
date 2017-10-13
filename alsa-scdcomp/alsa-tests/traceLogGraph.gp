#!/usr/bin/env gnuplot
################################################################################
# traceLogGraph.gp                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# script works on gnuplot 4.6 patchlevel 1

# if this script is called with a filename argument:
# $ gnuplot -e "filename='somefile.csv'" traceLogGraph.gp
# then it will automatically plot a .png file
# if it called inside gnuplot interpreter, via
# gnuplot> load 'traceLogGraph.gp'
# it will load whatever filename (below) is uncommented;
# and show it in wxt terminal

# other options
# gnuplot -e "filename='somefile.csv';fnnum='02';exr='[2:3]';eyr='[2:3]';" traceLogGraph.gp

if (! exists("fnnum")) \
  fnnum='' ;

# do not call reset/clear if filename (for batch .png) is passed!

if (! exists("filename")) \
  reset ; \
  clear ; \
  rep="no filename argument - using wxt terminal and hardcoded input: " ; \
  set terminal wxt font 'Arial,10' ; \
else \
  rep="got filename argument - using png terminal: " ; \
  set terminal pngcairo font 'Arial,10' size 1000,500 ; \
  set output filename . "_" . fnnum . ".png" ; \
  #~ show output


# new style "if" here; which supports multiline if{} - gnuplot > 4.4
# so the hardcoded values can be easily (un)commented if browsing in wxt

# you should first run `run-alsa-pa-tests.sh`; to obtain .csv captures;
# then paste them below, (un)comment accordingly;
# and edit below in the conditional plots, so captures with drops are plotted correctly

if (! exists("filename")) {
#~ filename = "captures/trace_patest__01_xA_pr_0.csv" ;
#~ filename = "captures/trace_patest__02_xA_pr_512.csv" ;
#~ filename = "captures/trace_patest__03_xA_w_0_drop.csv" ;
#~ filename = "captures/trace_patest__04_xA_w_512.csv" ;
#~ filename = "captures/trace_patest__05_DA_pr_0.csv" ;
#~ filename = "captures/trace_patest__06_DA_pr_512.csv" ;
#~ filename = "captures/trace_patest__07_DA_w_0_drop.csv" ;
filename = "captures/trace_patest__08_DA_w_512.csv" ;
#~ filename = "captures/trace_patest__09_xF_pr_0.csv" ;
#~ filename = "captures/trace_patest__10_xF_pr_512.csv" ;
#~ filename = "captures/trace_patest__11_xF_w_0_drop.csv" ;
#~ filename = "captures/trace_patest__12_xF_w_512.csv" ;
#~ filename = "captures/trace_patest__13_DF_pr_0.csv" ;
#~ filename = "captures/trace_patest__14_DF_pr_512.csv" ;
#~ filename = "captures/trace_patest__15_DF_w_0_drop.csv" ;
#~ filename = "captures/trace_patest__16_DF_w_512_drop.csv" ;
}

rep = rep . filename . " (_" . fnnum . ")"
print rep

# CSV data; must set:
set datafile separator ","

# colors - see:
# http://www.uni-hamburg.de/Wiss/FB/15/Sustainability/schneider/gnuplot/colors.htm

# blueish hues for playback driver (driver - timer/tasklet)
set style line 1 linetype 1 linewidth 1 pointtype 3 linecolor rgb "aquamarine"
set style line 2 linetype 1 linewidth 1 pointtype 3 linecolor rgb "blue"
set style line 3 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8A2BE2" #"blueviolet"
set style line 4 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#5F9EA0" #"cadetblue"
set style line 5 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#6495ED" #"cornflowerblue"

# reddish hues for capture (driver - timer/tasklet)
set style line 11 linetype 1 linewidth 1 pointtype 3 linecolor rgb "coral"
set style line 12 linetype 1 linewidth 1 pointtype 3 linecolor rgb "red"
set style line 13 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#DC143C" #"crimson"
set style line 14 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8B0000" #"darkred"
set style line 15 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FF8C00" #"darkorange"

# greenish hues for CallbackThreadFunc (frgbtc, frgbtp, frabCC, frabPC)
set style line 21 linetype 1 linewidth 1 pointtype 3 linecolor rgb "green"
set style line 22 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#006400" #"darkgreen"
set style line 23 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#8FBC8F" #"darkseagreen"
set style line 24 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#556B2F" #"darkolivegreen"

# yellowish hues for PaAlsaStream_WaitForFrames (frabCW, frabPW)
set style line 31 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#AAAA00" # darkish yellow
set style line 32 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FFD700" #"gold"

# black/gray for PaAlsaStream_WaitForFrames drop-inputs (pawDropIn)
set style line 41 linetype 1 linewidth 1 pointtype 3 linecolor rgb "black"
set style line 42 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#AAAAAA" # gray

# magentaish for PACallbacks:
set style line 51 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#FF00FF" # magenta
set style line 52 linetype 1 linewidth 1 pointtype 3 linecolor rgb "#BA55D3" # mediumorchid


# must call extern script (awk) to split data at runtime,
# so the lines are fully rendered between respective points!
# awk -F, '{if($3 == 1){print $0}}' file.csv

filename1 = "<awk -F, '{if($3 == 1){print $0}}' " . filename # hrtlC
filename2 = "<awk -F, '{if($3 == 2){print $0}}' " . filename # hrtlP
filename3 = "<awk -F, '{if($3 == 3){print $0}}' " . filename # cbthC
filename4 = "<awk -F, '{if($3 == 4){print $0}}' " . filename # cbthP
filename5 = "<awk -F, '{if($3 == 5){print $0}}' " . filename # pawfC
filename6 = "<awk -F, '{if($3 == 6){print $0}}' " . filename # pawfP
filename7 = "<awk -F, '{if($3 == 7){print $0}}' " . filename # pawDropIn
filename8 = "<awk -F, '{if($3 == 8){print $0}}' " . filename # PAcbC
filename9 = "<awk -F, '{if($3 == 9){print $0}}' " . filename # PAcbP


set title filename
set xtics rotate by -45

# change legend location; ; and column breaking
# "outside" for outside plotting area (including plot boundaries)
# note: "You can't add information directly to the key/legend", so
# "plot a line which will not appear" to insert extra space/text
#~ set key left top maxrows 5
set key left top maxrows 6 maxcols 3


if (exists("exr")) \
  eval "set xrange " . exr ; \
  #~ show xrange

if (exists("eyr")) \
  eval "set yrange " . eyr ; \
  #~ show yrange


# conditional plotting: not every variable is present in every .csv capture;
# so we must tell gnuplot which files belong where;

# wire callbacks (full duplex) only have one PA callback, which registers as capture (play/rec callbacks have one playback and one capture callback)
# if drop occured, those also need special handling
# if the driver doesn't produce traces ('x'), then also special handling (program always produces traces)


# here if driver produces traces, play/rec callbacks, no drop

if ((filename eq 'captures/trace_patest__05_DA_pr_0.csv') \
|| (filename eq 'captures/trace_patest__06_DA_pr_512.csv') \
|| (filename eq 'captures/trace_patest__13_DF_pr_0.csv') \
|| (filename eq 'captures/trace_patest__14_DF_pr_512.csv') \
) \
plot filename1 using 1:15 \
  with linespoints ls 11 title "15_cbtot" \
  ,\
  filename1 using 1:12 \
  with linespoints ls 12 title "12_cav" \
  ,\
  filename1 using 1:13 \
  with linespoints ls 13 title "13_chwav" \
  ,\
  filename1 using 1:17 \
  with linespoints ls 14 title "17_aptbC" \
  ,\
  filename1 using 1:18 \
  with linespoints ls 15 title "18_hptbC" \
  ,\
  filename8 using 1:16 \
  with linespoints ls 51 title "16_cdfib" \
  ,\
  filename2 using 1:10 \
  with linespoints ls 1 title "10_plyb" \
  ,\
  filename2 using 1:6 \
  with linespoints ls 2 title "6_pav" \
  ,\
  filename2 using 1:7 \
  with linespoints ls 3 title "7_phwav" \
  ,\
  filename2 using 1:17 \
  with linespoints ls 4 title "17_aptbP" \
  ,\
  filename2 using 1:18 \
  with linespoints ls 5 title "18_hptbP" \
  ,\
  filename9 using 1:11 \
  with linespoints ls 52 title "11_ppib" \
  ,\
  filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename4 using 1:9 \
  with linespoints ls 22 title "9_frgbtp" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  filename4 using 1:8 \
  with linespoints ls 24 title "8_frabPC" \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \
  ,\
  filename6 using 1:8 \
  with linespoints ls 32 title "8_frabPW"


# here if driver does not produce traces, play/rec callbacks, no drop

if ((filename eq 'captures/trace_patest__01_xA_pr_0.csv')\
|| (filename eq 'captures/trace_patest__02_xA_pr_512.csv')\
|| (filename eq 'captures/trace_patest__09_xF_pr_0.csv')\
|| (filename eq 'captures/trace_patest__10_xF_pr_512.csv')\
) \
plot filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename4 using 1:9 \
  with linespoints ls 22 title "9_frgbtp" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  filename4 using 1:8 \
  with linespoints ls 24 title "8_frabPC" \
  ,\
  "<echo '-1 -1'" lc rgb 'white' with points title '---' \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \
  ,\
  filename6 using 1:8 \
  with linespoints ls 32 title "8_frabPW"


# here if driver produces traces, wire callbacks, no drop

if ((filename eq 'captures/trace_patest__08_DA_w_512.csv') \
) \
plot filename1 using 1:15 \
  with linespoints ls 11 title "15_cbtot" \
  ,\
  filename1 using 1:12 \
  with linespoints ls 12 title "12_cav" \
  ,\
  filename1 using 1:13 \
  with linespoints ls 13 title "13_chwav" \
  ,\
  filename1 using 1:17 \
  with linespoints ls 14 title "17_aptbC" \
  ,\
  filename1 using 1:18 \
  with linespoints ls 15 title "18_hptbC" \
  ,\
  filename8 using 1:16 \
  with linespoints ls 51 title "16_cdfib" \
  ,\
  filename2 using 1:10 \
  with linespoints ls 1 title "10_plyb" \
  ,\
  filename2 using 1:6 \
  with linespoints ls 2 title "6_pav" \
  ,\
  filename2 using 1:7 \
  with linespoints ls 3 title "7_phwav" \
  ,\
  filename2 using 1:17 \
  with linespoints ls 4 title "17_aptbP" \
  ,\
  filename2 using 1:18 \
  with linespoints ls 5 title "18_hptbP" \
  ,\
  filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \


# here if driver does not produce traces, wire callbacks, no drop

if ((filename eq 'captures/trace_patest__03_xA_w_0.csv')\
|| (filename eq 'captures/trace_patest__04_xA_w_512.csv')\
|| (filename eq 'captures/trace_patest__12_xF_w_512.csv')\
) \
plot filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  "<echo '-1 -1'" lc rgb 'white' with points title '---' \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \



# here if driver produces traces, wire callbacks, drop

if ((filename eq 'captures/trace_patest__07_DA_w_0_drop.csv')\
|| (filename eq 'captures/trace_patest__15_DF_w_0_drop.csv')\
|| (filename eq 'captures/trace_patest__16_DF_w_512_drop.csv')\
) \
plot filename1 using 1:15 \
  with linespoints ls 11 title "15_cbtot" \
  ,\
  filename1 using 1:12 \
  with linespoints ls 12 title "12_cav" \
  ,\
  filename1 using 1:13 \
  with linespoints ls 13 title "13_chwav" \
  ,\
  filename1 using 1:17 \
  with linespoints ls 14 title "17_aptbC" \
  ,\
  filename1 using 1:18 \
  with linespoints ls 15 title "18_hptbC" \
  ,\
  filename2 using 1:10 \
  with linespoints ls 1 title "10_plyb" \
  ,\
  filename2 using 1:6 \
  with linespoints ls 2 title "6_pav" \
  ,\
  filename2 using 1:7 \
  with linespoints ls 3 title "7_phwav" \
  ,\
  filename2 using 1:17 \
  with linespoints ls 4 title "17_aptbP" \
  ,\
  filename2 using 1:18 \
  with linespoints ls 5 title "18_hptbP" \
  ,\
  filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  "<echo '-1 -1'" lc rgb 'white' with points title '---' \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \
  ,\
  filename7 using 1:(1e6) \
  with impulses ls 42 title "8_frabDI" \
  ,\
  filename7 using 1:8 \
  with impulses ls 41 title "" \
  ,\
  "" using 1:8 \
  with points ls 41 title ""


# here if driver does not produce traces, wire callbacks, drop

if ((filename eq 'captures/trace_patest__03_xA_w_0_drop.csv')\
|| (filename eq 'captures/trace_patest__11_xF_w_0_drop.csv')\
) \
plot filename3 using 1:14 \
  with linespoints ls 21 title "14_frgbtc" \
  ,\
  filename3 using 1:8 \
  with linespoints ls 23 title "8_frabCC" \
  ,\
  "<echo '-1 -1'" lc rgb 'white' with points title '---' \
  ,\
  filename5 using 1:8 \
  with linespoints ls 31 title "8_frabCW" \
  ,\
  filename7 using 1:(1e6) \
  with impulses ls 42 title "8_frabDI" \
  ,\
  filename7 using 1:8 \
  with impulses ls 41 title "" \
  ,\
  "" using 1:8 \
  with points ls 41 title ""


replot




