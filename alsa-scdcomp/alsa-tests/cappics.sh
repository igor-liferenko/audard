################################################################################
# cappics.sh                                                                   #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################


control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT


if [ "" ] ; then
for ix in {,captures-2013-08*} ; do
  echo $ix/;
  if [ -f "$ix/run-alsa-capttest.log" ] ; then
    echo $ix/run*.log ;
    montage -density 150 $ix/tra*.pdf -geometry +0+0 -tile 1x _cappics/$ix-both.png ;
    convert -background none \
      -pointsize 40 label:"$ix" \
      -pointsize 20 label:"$(awk '{if(/Results \(again\):/){flag=1;};if(flag){if(/Asked|start/){print;}}}' $ix/run-alsa-capttest.log)" \
      -append \
      text.png ;
    mogrify -draw 'image Over 200,550 0,0 "text.png"' _cappics/$ix-both.png ;
  fi ;
done ;
fi

# use \typeout instead of \input to debug shell commands (also set -x would work)
# note that if you want \( or \) as such to the shell - they must be escaped with \string!
# e.g -i "\input{|\"echo \string\( here \string\) \"}"
# calc position: (MynodeC) at (\$(current page.west)+(1,0)\$) - without: [,left=1], but doesn't work

if [ "" ] ; then
for ix in {,captures-2013-08*} ; do
  echo $ix/;
  if [ -f "$ix/run-alsa-capttest.log" ] ; then
    echo $ix/run*.log ;
    perl montikz-pdf.pl \
-i "$ix/trace-dummy.csv_.pdf:[inner sep=0] (MynodeA) at (0,0)" \
-i "$ix/trace-hda-intel.csv_.pdf:[inner sep=0,below=0mm of MynodeA] (MynodeB)" \
-i ":\begin{minipage}{1.5\linewidth}{\catcode\`_=12\obeylines \bf\ttfamily {\LARGE $ix}\\\\ \input{|\"awk '{if(/Results \string\(again\string\)/){flag=1;};if(flag){if(/Asked|start/){print;}}}' $ix/run-alsa-capttest.log\" }}\end{minipage}:[overlay,anchor=west] (MynodeC) at (\$(current page.west)+(1,1)\$)" \
-o "$ix/trace-both.pdf" ;
  #~ exit;
  fi ;
done ;
fi

# for the previous -- just pdf to png

if [ "" ] ; then
for ix in captures-2013-08*{bdum,bhda,or} ; do
  echo $ix/;
  if [ -f "$ix/run-alsa-capttest.log" ] ; then
    echo $ix/run*.log ;
    # `montage` or `convert` work here the same
    convert -density 150 $ix/trace-both.pdf -geometry +0+0 _cappics/$ix-both.png ;
    #~ exit ;
  fi ;
done ;
fi


# for animated gif:
#~ convert -resize 600x -delay 10 -loop 0 _cappics/*.png capttest.gif
