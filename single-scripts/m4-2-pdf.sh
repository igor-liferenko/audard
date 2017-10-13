#!/usr/bin/env bash
# $1 - path to .m4 file

M4FILEPATH=$(readlink -f $1)
M4FILEDIR=$(dirname $M4FILEPATH)
M4FILENAME=$(basename $M4FILEPATH)
M4FNBASE=${M4FILENAME%%.m4}

# detect if dpic is here...
# use type for bash - and subprocess ()
#   instead of {}, which crash bash as first arg;
# but must be {} for second arg, else just the subprocess will exit (not the script, which we want)
type -P dpic &>/dev/null \
  && ( echo "dpic found, continuing..." ; continue; ) \
  || { echo "dpic not found. EXITING [Have you mounted the drive where it is?]"; exit 1; }

# for debug, use "m4 -d --debug=V --debugfile=m4dbg ... "
echo "m4 ~/.kde/share/apps/cirkuit/circuit_macros/libcct.m4 ~/.kde/share/apps/cirkuit/circuit_macros/pstricks.m4 $M4FILEPATH | dpic -p > $M4FILEPATH.pstex"
m4 ~/.kde/share/apps/cirkuit/circuit_macros/libcct.m4 ~/.kde/share/apps/cirkuit/circuit_macros/pstricks.m4 $M4FILEPATH | dpic -p > $M4FILEPATH.pstex

# from ~/.kde/share/apps/cirkuit/circuit_macros/examples
# quote the heredoc label to escape evaluation (string literal)
cat > $M4FILEDIR/boxdims.sty <<"EOF"
%
% boxdims.sty, for use with m4 preprocessors.  Last modified 30 Apr 2004.
%
% \boxdims{arg1}{arg2} expands to arg2, but writes into file \jobname.dim
% the m4 definitions for macros arg1_h, arg1_w, arg1_d, the height, width
% and depth of \hbox{arg2}.
%
% \defboxdim{arg1}{arg2} writes the definitions but expands to nothing.
%
% \boxdimfile{filename} sets the output file to filename, default \jobname.dim
%
\ProvidesPackage{boxdims}
         [2004/04/30 v2.0 Macros: boxdimfile, boxdims, defboxdim (DA)]

\newwrite\@dimensionfile
\newif\if@dimfile
\newbox\dimbox

\def\boxdimfile#1{\immediate\openout\@dimensionfile=#1\global\@dimfiletrue%
  \typeout{ boxdims.sty v2.0: Writing dimension file #1 }}%

\def\boxdims#1#2{\defboxdim{#1}{#2}#2}

\def\defboxdim#1#2{\if@dimfile\else%
    \immediate\openout\@dimensionfile=\jobname.dim\global\@dimfiletrue%
    \typeout{ boxdims.sty v2.0: Writing dimension file \jobname.dim }\fi%
  \setbox\dimbox=\hbox{#2}%
  \begingroup\@sanitize\edef\@tempa{\write\@dimensionfile{%
  \@defboxdim{#1}}}\expandafter\endgroup\@tempa}
\def\@defboxdim#1{%
define(`#1_w',\the\wd\dimbox__)%
define(`#1_h',\the\ht\dimbox__)%
define(`#1_d',\the\dp\dimbox__)dnl}
EOF

TEXTXT="\documentclass[11pt]{article}
\usepackage{times,boxdims,pstricks,pst-grad}
%\usepackage[dvips]{lscape}
%\usepackage[dvips]{graphicx}
\usepackage{lscape}
\usepackage{graphicx}
\usepackage{color}
\usepackage{auto-pst-pdf} % pstricks don't work w/ pdflatex (tlmgr install auto-pst-pdf ifplatform pst-pdf environ); needs write18 enabled

\newcommand{\src}[1]{{\tt [#1]}}
\newcommand{\makepic}{\box\graph} % Required only for gpic -t
\newbox\graph

\newif\ifmpost
\newif\ifpst
\newif\ifpdfl
\newif\ifpgf
\newif\ifpostscript

\newcommand{\getpic}[1]{%
  \ifpst
    \input #1 \makepic
  \else\ifpgf
    \input #1
  \else\ifmpost
    \includegraphics[trim=1 1 1 1]{#1.1}%
  \else\ifpdfl
    \includegraphics[trim=1 1 1 1]{#1}
  \else\ifpostscript%
    \includegraphics{#1.eps}%
  \fi\fi\fi\fi\fi}

% Left-justified captions to be used in parbox
\makeatletter
\def\caption#1{%
  \vskip\abovecaptionskip
  \refstepcounter{figure}
  \sbox\@tempboxa{{Figure \arabic{figure}: #1}}%
  \ifdim \wd\@tempboxa >\hsize
    {Figure \arabic{figure}: #1}\par
  \else
    \global \@minipagefalse
    \hb@xt@\hsize{\box\@tempboxa\hfil}%
  \fi
  \vskip\belowcaptionskip}
\makeatother

\newcommand{\bfig}[1]{\vspace{5ex}\noindent\parbox{\textwidth}{#1}}

%%%%

\begin{document}

%\bfig{
%    \centerline{\getpic{$M4FILEDIR/$M4FNBASE}}
%    \caption{A binary tree
    %\src{$M4FILEDIR/$M4FNBASE.m4}.
%	}
%  }

% must have \makepic here..
\begin{figure}[hbt]
\input{$M4FILEPATH.pstex}\makepic
\end{figure}

\end{document}
"

# from /cirkuit/src/templates/cm_latex.ckt
TEXTXTB="\documentclass{article}

\usepackage{pstricks,pst-eps,graphicx,ifpdf,pst-grad}
\usepackage{amsmath}
\usepackage{amsfonts,amssymb}
\usepackage{boxdims,mathptmx}
\usepackage{auto-pst-pdf} %
\usepackage{textgreek}
\pagestyle{empty}
\thispagestyle{empty}


\begin{document}


\newbox\graph
\begin{TeXtoEPS}
% <!CODE!>
\input{$M4FILEPATH.pstex}%\makepic
\box
\graph
\end{TeXtoEPS}
\end{document}
"

echo "$TEXTXTB" > $M4FILEPATH.inctex

# enable write18 for auto-pst-pdf / pstricks
# still, pdflatex fails :(
# with proper sinclude(\jobname.dim) in m4 file;
# (and apparently running latex twice);
latex -shell-escape $M4FILEPATH.inctex

# build m4 second time - for boxdims? Must!
m4 ~/.kde/share/apps/cirkuit/circuit_macros/libcct.m4 ~/.kde/share/apps/cirkuit/circuit_macros/pstricks.m4 $M4FILEPATH | dpic -p > $M4FILEPATH.pstex

latex -shell-escape $M4FILEPATH.inctex

# results with dvi that fails in evince;
# but with dvips -E - results with .ps file which is correctly cropped to image size
echo dvips...
dvips -E $M4FILEPATH.dvi

# note that dvipdf with -dEPSCrop still shows a big page..
#~ dvipdf -dEPSCrop $M4FILEPATH.dvi

# so must use ps2pdf - and it MUST have -dEPSCrop !
# and finally getting pdf which is cropped ok
# note that -dAutoRotatePages=/None, because
# when using text with rput to rotate, the
# algorithm will look for longest actual text (spaces are ignored)
# and take that side to be horizontal...
echo ps2pdf...
ps2pdf -dEPSCrop -dAutoRotatePages=/None $M4FILEPATH.ps

# clean up
rm $M4FILEDIR/missfont.log $M4FILEPATH.ps $M4FILEPATH.dvi $M4FILEPATH.inctex $M4FILEPATH.pstex $M4FILEPATH.aux $M4FILEPATH.dim $M4FILEPATH.log $M4FILEDIR/boxdims.sty

#~ echo pdflatex -shell-escape $M4FILEPATH.inctex
# NOTE: MUST have DENSITY - *just* size doesn't work!
convert -density 200x200 $M4FILEPATH.pdf $M4FILEPATH.png

# NOTE - there is also option to use m4 somehow with tikz - and thereby get direct pdflatex out?? Try eventually...
