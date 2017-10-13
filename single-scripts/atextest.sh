#!/bin/bash

# copyleft sdaau 2012

# to force exit loop:
#~ trap 'echo Control-C trap caught; cleanup; exit 1' 2 #traps Ctrl-C (signal 2)
trap 'echo Control-C trap caught; exit 1' 2 #traps Ctrl-C (signal 2)

MYFN="atest"
MYFNIMG="${MYFN}_img"
MYFNTEX=${MYFN}.tex
MYFNIN="${MYFN}-input"
MYFNINTEX=${MYFNIN}.tex

function cleanup() {
  echo rm ${MYFNTEX} ${MYFNINTEX} -rf ${MYFN} -rf ${MYFNIMG}
  rm ${MYFNTEX} ${MYFNINTEX}
  rm -rf ${MYFN}
  rm -rf ${MYFNIMG}
}



mkdir ${MYFN}
mkdir ${MYFNIMG}

cat > ${MYFNTEX} <<EOF
\documentclass[10pt,a4paper]{article}
\providecommand{\myparam}{0.0pt}% fallback definition
\tracingonline=0 % suppress stdout (still dumps start)

% tex.se: 47576
\usepackage{ifxetex,ifluatex}
\newif\ifxetexorluatex
\ifxetex
  \xetexorluatextrue
\else
  \ifluatex
    \xetexorluatextrue
  \else
    \xetexorluatexfalse
  \fi
\fi

\ifluatex
  \usepackage{lua-visual-debug} % tlmgr install lua-visual-debug
\fi
\ifxetexorluatex
  %\usepackage{fontspec}
  %\defaultfontfeatures{Ligatures=TeX}
  %\setmainfont[Scale=1.0]{Junicode}
  %\newfontfamily\myfontfam[Scale=1.0]{Junicode}
\fi

\usepackage[a4paper]{geometry}
\geometry{twoside,inner=2.5cm,outer=3.5cm,top=2.5cm,bottom=2.5cm}

\makeatletter
\renewcommand{\section}{\@startsection
{section}%                   % the name
{1}%                         % the level
{\z@}%                       % the indent / 0mm
{-\baselineskip}%            % the before skip / -3.5ex \@plus -1ex \@minus -.2ex
{2pt}%          % the after skip / 2.3ex \@plus .2ex
{\centering\fontsize{11}{12}\selectfont\bfseries}} % the style
\makeatother

\usepackage{lipsum}


\newlength{\mylen}
\setlength{\mylen}{0pt}
\setlength{\mylen}{\myparam}

\begin{document}

\ifxetexorluatex
  %\myfontfam
\fi
  \fontsize{10}{12.3}\selectfont

\title{Testing Title}
\date{October 31, 1000}
\author{John Doe\\\\ Somewhereland}

\maketitle

\clearpage

\input{${MYFNINTEX}}
\clearpage

\end{document}
EOF


cat > ${MYFNINTEX} <<EOF

%\raggedbottom
%\flushbottom

\section*{Introductory words of introduction}

\vspace{\baselineskip}
\vspace{2pt}
{ %\begin{center}
\makebox[\textwidth][c]{
\centering\textbf{Something else here, some other words}
}
} %\end{center}


\vspace{\mylen}
%\ \\\\[\mylen]

\makebox[2cm][r]{\the\mylen}, \lipsum[1-10] %[1-2]


\bigskip


\bigskip

EOF

MYPARAM="2.0pt"
JOBNAME="atest1"

# use this to obtain CROPPARAMS:
#   display -density 150 atest/atest000.pdf
# then click, ImageMagick menu/"Image Edit"/"Region of Interest...":
# click and drag in the image to select a region of interest box;
# a box appears in upper left corner with geometry settings (but cannot select and copy-paste its text);
# ImageMagick menu/"Dismiss" to exit;
# (also see http://stackoverflow.com/questions/10663246/)
#
#~ CROPPARAMS=320x240+100+400
# [[magick-users] Convert with multiple crop/appends](http://studio.imagemagick.org/pipermail/magick-users/2009-August/022809.html)
CROPPARAMS=400x400+150+100 # top left
CROPPARAMSB=200x400+115+1315 # bottom left

#~ BRDR=""
BRDR="-bordercolor LimeGreen -border 1"

CMDNAME="pdflatex"
#~ CMDNAME="xelatex"
#~ CMDNAME="lualatex"

FULLBUILD=1
#~ FULLBUILD=

#~ for ix in $(seq 0 1 0); do # only once
for ix in $(seq 0 1 100); do
  iy=$(wcalc -EE -q \($ix-50\)/50*30);
  INDEX=$(printf "%03d" $ix) ;
  JOBNAME="${MYFN}${INDEX}" ;
  MYPARAM="${iy}pt"
  echo -n "
        $CMDNAME - $JOBNAME - $MYPARAM" ;
  (${CMDNAME} -output-directory="${MYFN}" -jobname="${JOBNAME}" "\def\myparam{${MYPARAM}}\tracingonline=0\input{${MYFNTEX}}" 2>&1 1>/dev/null);

  if [ ! -z ${FULLBUILD} ] ; then # if fullbuild == if not zero f....
    # this with two crops can be performed in one command line:
    #~ convert -density 150 ${BRDR} -crop ${CROPPARAMS} +repage ${MYFN}/${JOBNAME}.pdf[1] ${MYFNIMG}/${JOBNAME}_A.png ;
    #~ convert -density 150 ${BRDR} -crop ${CROPPARAMSB} +repage ${MYFN}/${JOBNAME}.pdf[1] ${MYFNIMG}/${JOBNAME}_B.png ;
    #~ montage ${MYFNIMG}/${JOBNAME}_A.png ${MYFNIMG}/${JOBNAME}_B.png -geometry +1+1 -tile 2x1 ${MYFNIMG}/${JOBNAME}_O.png
    # or as single (src no work, src-over yes; '-border 1' need to be individual - -bordercolor LimeGreen can stand after '-compose src-over'):
    # see also
    echo -n " convert.. "
    convert -density 150 -compose src-over \
      \( ${MYFN}/${JOBNAME}.pdf[1] -crop ${CROPPARAMS} ${BRDR} +repage +append \) \
      \( ${MYFN}/${JOBNAME}.pdf[1] -crop ${CROPPARAMSB} ${BRDR} +repage +append \) \
    +append +repage ${MYFNIMG}/${JOBNAME}.png ;
  fi # end if fullbuild

  echo
done


GRAY=""
#~ GRAY="-type grayscale"

if [ ! -z ${FULLBUILD} ] ; then # if fullbuild == if not zero f....

  echo convert -delay 5 -loop 0 ${MYFNIMG}/\*.png ${GRAY} ${MYFN}_animate.gif
  convert -delay 5 -loop 0 ${MYFNIMG}/*.png ${GRAY} ${MYFN}_animate.gif

  #~ convert -delay 5 -loop 0 ${MYFNIMG}/*_O.png ${GRAY} ${MYFN}_animate.gif


  # view results
  #~ evince ${MYFN}/${JOBNAME}.pdf
  #~ display ${MYFNIMG}/${JOBNAME}.png
  eog atest_animate.gif 2>/dev/null

fi # end if fullbuild

#~ cleanup # remove tmp files

