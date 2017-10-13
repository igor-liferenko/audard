#!/usr/bin/env bash

# sdaau, nov 2013, apr 2014

# must declare here all options - are returned for autocompletion:
# /etc/bash_completion.d/newfile
opts="gnuplot bash perl python svg tex tmp help dumpopts dumppat"
# here only those that require filename autocompletion as second arg:
optspat="gnuplot|bash|perl|python|svg|tex|tmp"

[ ! -f /etc/bash_completion.d/newfile ] &&
sudo -s <<-'EOM'
cat > /etc/bash_completion.d/newfile <<'EOF'
_newfile() 
{
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="$(newfile dumpopts)"
    optspat="$(newfile dumppat)"

    shopt -s extglob

    case $prev in
      @($(echo $optspat)))
        _filedir
        return 0
        ;;
    esac

    if [[ ${cur} == * ]] ; then
      COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
      return 0
    fi
}
complete -F _newfile newfile
EOF
EOM


# regex check of arguments - if contain "dump":
[[ "$@" =~ dumpopts ]]; REC=$?;
if [[ $REC == 0 ]] ; then
  echo "$opts"
  exit
fi
[[ "$@" =~ dumppat ]]; REC=$?;
if [[ $REC == 0 ]] ; then
  echo "$optspat"
  exit
fi



# first argument - operation; second (if any) path to filename
OP=$1
FPATH=$2

if [ "$OP" == "" ] ; then
  echo "Must have operation as first argument; one of:"
  echo "  $opts"
  echo "Exiting."
  exit
fi

if [ "$OP" == "help" ] ; then
  echo "$0 [operation] [./path/to/newfile]"
  exit
fi


if [ "$FPATH" == "" ] ; then
  echo "No filename specified, using current directory"
  FPATH=$(pwd)/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 8)
else
  FDIR=$(dirname $FPATH)
  if [ ! -d "$FDIR" ] ; then
    echo "Specified directory $FDIR doesn't exist, create it first; exiting."
    exit
  fi
  FDIR=$(dirname $(readlink -f $FPATH))
  FNAME=$(basename $FPATH)
  FPATH="$FDIR"/"$FNAME"
fi

#echo $FPATH
FDIR=$(dirname $FPATH)
FNAME=$(basename $FPATH)

# for all - add extension only if filename does not contain a dot
[[ "$FNAME" =~ \. ]]; REC=$?;
case $OP in
  gnuplot)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.gp" ; fi
    echo "Creating gnuplot skeleton file"
    cat > $FPATH <<EOF
#!/usr/bin/env gnuplot
# `date` ; `gnuplot --version`

EOF
    ;;
  bash)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.sh" ; fi
    echo "Creating bash skeleton file"
    cat > $FPATH <<EOF
#!/usr/bin/env bash
# `date` ; `bash --version | head -n1`

EOF
    ;;
  python)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.py" ; fi
    echo "Creating python skeleton file"
    cat > $FPATH <<EOF
#!/usr/bin/env python
# -*- coding: utf-8 -*-
# `date` ; `python --version 2>&1`

EOF
    ;;
  perl)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.py" ; fi
    echo "Creating python skeleton file"
    cat > $FPATH <<EOF
#!/usr/bin/env perl
# `date` ; `perl --version | awk 'NR==2 { print; exit }' 2>&1`
use 5.010;
use warnings;
use strict;
use utf8; # tell Perl that your script is written in UTF-8

EOF
    ;;
  svg)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.svg" ; fi
    echo "Creating svg skeleton file"
    cat > $FPATH <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg
  width="744.09448819pt"
  height="1052.3622047pt"
  viewBox="0 0 744.09448819 1052.3622047"
  version="1.1"
  id="svg2"
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
  xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
  xmlns="http://www.w3.org/2000/svg">
  <g
    inkscape:label="Layer 1"
    inkscape:groupmode="layer"
    id="layer1">
  </g>
</svg>
EOF
    ;;
  tex)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.tex" ; fi
    echo "Creating (La)Tex skeleton file"
    cat > $FPATH <<EOF
% `date` ; `pdflatex --version 2>&1 | head -1`
\documentclass{article}

\usepackage{tikz} %graphicx
\usepackage{xcolor} % \pagecolor
\pagecolor{yellow!15}

\begin{document}

  \title{Test title}
  \author{test}

  \maketitle

  \begin{abstract}
  The abstract text goes here.
  \end{abstract}

  \section{Test section}

  Test text.

\end{document}
EOF
    ;;
  *)
    if [ "$REC" == "1" ] ; then FPATH="$FPATH.tmp" ; fi
    echo "Creating default empty file (just touch)"
    touch $FPATH
    ;;
esac

echo "Created $FPATH"
