#!/usr/bin/env bash

# call note for remotely mounted ssh:
# (for ln, either escape space \ or use quotes ""; not both... and no ~ in quotes)
# ln -s "/path/to/Thun_Profile/Mail/Local Folders/" ~/loc
# ln -s ~/".gvfs/sftp for USERNAME on 192.168.1.123/path/to/Email Backup/" ~/rem
# then call w.
# ./dircompare.sh ~/loc ~/rem | tee output.txt

# this however can crash the server...
#  IF ctrl-C is pressed during a running command;
#  and UNLESS a Ctrl-C exit trap is made!
# note that the diff command can take a while for remote and big files;
# use the dot indicators to approximate progress

# alternatively, use rsync
# see also http://stackoverflow.com/questions/119788/6740823#6740823
#  in rsync, both quotes and \ to escape spaces for remote!
#  also, requires trailing slash on directories!
# --itemize-changes: the string YXcstpoguax, Y type of update (>,<,c,...) , X file type, other letters represent attributes
# rsync -ivr --dry-run /path/to/Thun_Profile/Mail/Local\ Folders/ 192.168.1.123:"/path/to/Email\ Backup/"


# these without / at end!
DIRONE="$1"
DIRTWO="$2"

# declare array ARR=(1,2)
declare -a D1FULL
declare -a D1ONLY
declare -a D2ONLY
declare -a DBOTH
declare -a BOTHNODIFF
declare -a BOTHDIFF
iD1FULL=0
iD1ONLY=0
iD2ONLY=0
iDBOTH=0
iBOTHNODIFF=0
iBOTHDIFF=0

# http://stas-blogspot.blogspot.com/2010/02/kill-all-child-processes-from-shell.html
kill_child_processes() {
    echo "Ctrl-C trapped; exiting" # has no effect
    local isTopmost=$1
    local curPid=$2
    local childPids=`ps -o pid --no-headers --ppid ${curPid}`
    for childPid in $childPids
    do
        kill_child_processes 0 $childPid
    done
    if [ $isTopmost -eq 0 ]; then
        kill -9 $curPid 2> /dev/null
    fi
}

# Ctrl-C trap. Catches INT signal (echo has no effect)
trap "echo \"AA\"; kill_child_processes 1 $$; exit 0" INT


#~ http://stackoverflow.com/questions/2634777/bash-recursive-listing-of-all-files-problem
# http://stackoverflow.com/questions/2154166/how-to-recursively-list-subdirectories-in-bash-without-using-find-or-ls-commands
# http://www.unix.com/shell-programming-scripting/129761-recursive-function-arrays.html
DBG=
DBG2=
DBG3=1
PRINTFILES=
PRINTPROGRDOTS=1
# Note: $* without "", so it can understand arguments;
# but then spaces at begining "   X" are not shown
function dbgtxt() {
  if [ $DBG ]; then echo $* ; fi
}
function dbg2txt() {
  if [ $DBG2 ]; then echo $* ; fi
}
function dbg3txt() {
  if [ $DBG3 ]; then echo $* ; fi
}
function fltxt() {
  if [ $PRINTFILES ]; then echo $* ; fi
}
function prdot() {
  if [ $PRINTPROGRDOTS ]; then echo -n . ; fi
}



function recurse_ls() {
  local TDIR="$1"
  local COMPDIR="$2"
  local np=$3 # num pass
  dbgtxt -e "\t\tRecurz $1"
  # -A - list almost all: hidden too, except . and ..
  for TFILE in $(ls -A --group-directories-first "$TDIR") ; do
    local TPATH="$TDIR/$TFILE"
    local RPATH=${TPATH##$rcDIR/}
    fltxt -n "$RPATH"
    prdot
    if [ -e "$COMPDIR/$RPATH" ]; then
      if [ $np -eq 1 ];  then
        DBOTH[$iDBOTH]="$RPATH"
        ((iDBOTH++))
      fi
    else # match not exist
      if [ $np -eq 1 ];  then
        D1ONLY[$iD1ONLY]="$RPATH"
        ((iD1ONLY++))
      fi
      if [ $np -eq 2 ];  then
        D2ONLY[$iD2ONLY]="$RPATH"
        ((iD2ONLY++))
      fi
    fi
    if [ -d "$TPATH" ]; then
      fltxt "   \ D"
      recurse_ls "$TPATH" "$COMPDIR" "$np"
      dbgtxt -e "\t\tOUT"
      #~ TDIR="$1" # must refresh the dir after recursion exits! but only if TDIR is not local !!
    #~ elif [ -f "$TDIR/$TFILE" ]; then
    else
      fltxt "   \ F"
    fi
  done
}

function textcomp() {
  if [ $1 -eq $2  ]; then
    echo "same"
  elif [ $1 -gt $2 ]; then
    echo "newr"
  else
    echo "oldr"
  fi
}

function tfcomp() {
  if [ "$1" -nt "$2"  ]; then
    echo "newr"
  elif [ "$1" -ot "$2" ]; then
    echo "oldr"
  else
    echo "same"
  fi
}

function numcomp() {
  if [ $1 -eq $2  ]; then
    echo -n "=equal"
  elif [ "$1" -gt "$2" ]; then
    echo -n ">biggr"
  else
    echo -n "<smalr"
  fi
}

function ftype() {
  if [ -d "$1" ]; then
    echo -n "D"
  elif [ -f "$1" ]; then
    echo -n "F"
  fi
}


### START

#~ set -x

rcDIR="$DIRONE" # global, but changes only once
echo -n "pass 1... "
recurse_ls "$DIRONE" "$DIRTWO" 1
echo
# reverse check
rcDIR="$DIRTWO"
echo -n "pass 2... "
recurse_ls "$DIRTWO" "$DIRONE" 2
echo

# now, go through DBOTH, and check if files pass diff

echo -n "diff... "
for ix in ${DBOTH[@]}; do
  fone="$DIRONE/$ix"
  ftwo="$DIRTWO/$ix"
  dbg2txt -e "\t $ix"
  resp=$(diff -q "$fone" "$ftwo")
  prdot
  if [ "$resp" ]; then
    dbg2txt $resp
    BOTHDIFF[$iBOTHDIFF]="$ix"
    ((iBOTHDIFF++))
  else
    dbg2txt NO
    BOTHNODIFF[$iBOTHNODIFF]="$ix"
    ((iBOTHNODIFF++))
  fi
done

echo


# echo "${DBOTH[@]}" # single line
#~ echo "DBOTH"
#~ for ix in ${DBOTH[@]}; do echo $ix; done
#~ echo "----------------------"
echo "D1ONLY: $DIRONE"
for ix in ${D1ONLY[@]}; do echo $ix; done
echo "----------------------"
echo "D2ONLY: $DIRTWO"
for ix in ${D2ONLY[@]}; do echo $ix; done
echo "----------------------"
#~ echo "BOTHDIFF:"
#~ for ix in ${BOTHDIFF[@]}; do echo $ix; done
echo "BOTHNODIFF:"
#~ for ix in ${BOTHNODIFF[@]}; do echo $ix; done
# now, from those that are BOTHNODIFF, go through and
# check timestamps
for ix in ${BOTHNODIFF[@]}; do
  fone="$DIRONE/$ix"
  ftwo="$DIRTWO/$ix"
  # %A     Access rights in human readable form
  # %X     Time of last access as seconds since Epoch
  # %Y     Time of last modification as seconds since Epoch
  # %Z     Time of last change as seconds since Epoch


  #~ fszone=$(stat -c "%s" $fone)
  #~ fsztwo=$(stat -c "%s" $ftwo)
  #~ fszonef=$(echo "$fszone" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d\", \$1 }" )
  #~ fsztwof=$(echo "$fsztwo" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d\", \$1 }" )
  #~ dbg3txt -e "\t $ix \n($fszonef $(numcomp $fszone $fsztwo) $fsztwof)"
  #~ fonea=$(stat -c "%X" $fone)
  #~ fonem=$(stat -c "%Y" $fone)
  #~ fonec=$(stat -c "%Z" $fone)
  #~ ftwoa=$(stat -c "%X" $ftwo)
  #~ ftwom=$(stat -c "%Y" $ftwo)
  #~ ftwoc=$(stat -c "%Z" $ftwo)

  #~ # note: -nt/ot follows 'last modification'
  #~ echo "$DIRONE: $(tfcomp "$fone" "$ftwo") (a:$(textcomp "$fonea" "$ftwoa") m:$(textcomp "$fonem" "$ftwom") c:$(textcomp "$fonec" "$ftwoc"))"
  #~ stat -c "%A %X %Y %Z" $fone | gawk ' { print "   " strftime("%c",$2) " | " strftime("%c",$3) " | " strftime("%c",$4) } '
  #~ echo "$DIRTWO: $(tfcomp "$ftwo" "$fone") (a:$(textcomp "$ftwoa" "$fonea") m:$(textcomp "$ftwom" "$fonem") c:$(textcomp "$ftwoc" "$fonec"))"
  #~ stat -c "%A %X %Y %Z" $ftwo | gawk ' { print "   " strftime("%c",$2) " | " strftime("%c",$3) " | " strftime("%c",$4) } '
  #~ echo "  --"

  # stats as array
  stO=( $(stat -c "%s %X %Y %Z" $fone) )
  stT=( $(stat -c "%s %X %Y %Z" $ftwo) )
  # gawk format as array too
  stOf=( $(echo "${stO[*]}" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d %s %s %s\n\", \$1, strftime(\"%d-%m%b-%Y_%H:%M\",\$2), strftime(\"%d-%m%b-%Y_%H:%M\",\$3), strftime(\"%d-%m%b-%Y_%H:%M\",\$4) }") )
  stTf=( $(echo "${stT[*]}" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d %s %s %s\n\", \$1, strftime(\"%d-%m%b-%Y_%H:%M\",\$2), strftime(\"%d-%m%b-%Y_%H:%M\",\$3), strftime(\"%d-%m%b-%Y_%H:%M\",\$4) }") )

  echo -e "-----
\t$ix ($(ftype "$fone"))
"
  echo -e "
 |$DIRONE|$DIRTWO
 |(${stOf[0]} $(numcomp ${stO[0]} ${stT[0]})| ${stTf[0]})
 |$(tfcomp "$fone" "$ftwo")
a:|$(textcomp "${stO[1]}" "${stT[1]}") ${stOf[1]}|$(textcomp "${stT[1]}" "${stO[1]}") ${stTf[1]}
m:|$(textcomp "${stO[2]}" "${stT[2]}") ${stOf[2]}|$(textcomp "${stT[2]}" "${stO[2]}") ${stTf[2]}
c:|$(textcomp "${stO[3]}" "${stT[3]}") ${stOf[3]}|$(textcomp "${stT[3]}" "${stO[3]}") ${stTf[3]}
  " | column -t -s"|"
done
echo "----------------------"

echo "BOTHDIFF:"

for ix in ${BOTHDIFF[@]}; do
  fone="$DIRONE/$ix"
  ftwo="$DIRTWO/$ix"
  # stats as array
  stO=( $(stat -c "%s %X %Y %Z" $fone) )
  stT=( $(stat -c "%s %X %Y %Z" $ftwo) )
  # gawk format as array too
  stOf=( $(echo "${stO[*]}" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d %s %s %s\n\", \$1, strftime(\"%d-%m%b-%Y_%H:%M\",\$2), strftime(\"%d-%m%b-%Y_%H:%M\",\$3), strftime(\"%d-%m%b-%Y_%H:%M\",\$4) }") )
  stTf=( $(echo "${stT[*]}" | LC_ALL=en_US.UTF-8 gawk "{ printf \"%'d %s %s %s\n\", \$1, strftime(\"%d-%m%b-%Y_%H:%M\",\$2), strftime(\"%d-%m%b-%Y_%H:%M\",\$3), strftime(\"%d-%m%b-%Y_%H:%M\",\$4) }") )

  echo -e "-----
\t$ix ($(ftype "$fone"))
"
  echo -e "
 |$DIRONE|$DIRTWO
 |(${stOf[0]} $(numcomp ${stO[0]} ${stT[0]})| ${stTf[0]})
 |$(tfcomp "$fone" "$ftwo")
a:|$(textcomp "${stO[1]}" "${stT[1]}") ${stOf[1]}|$(textcomp "${stT[1]}" "${stO[1]}") ${stTf[1]}
m:|$(textcomp "${stO[2]}" "${stT[2]}") ${stOf[2]}|$(textcomp "${stT[2]}" "${stO[2]}") ${stTf[2]}
c:|$(textcomp "${stO[3]}" "${stT[3]}") ${stOf[3]}|$(textcomp "${stT[3]}" "${stO[3]}") ${stTf[3]}
  " | column -t -s"|"
done






# http://www.astahost.com/info.php/Bash-Shell-Scripting-Comparing-Directories_t19548.html
#~ for file in $(ls -AR --group-directories-first $DIRONE) ; do
    #~ if [ ! -e $DIRTWO/$file ] ; then
      #~ echo ls -ld $DIRONE / $file
    #~ fi
#~ done

#~ for file in $(ls -a $DIRTWO) ; do
  #~ if [ ! -e $DIRONE/$file ] ; then
    #~ ls -ld $DIRTWO/$file
  #~ fi
#~ done

# http://stackoverflow.com/questions/119788/how-to-compare-files-with-same-names-in-two-different-directories-using-a-shell-s
# http://magazine.redhat.com/2008/02/07/python-for-bash-scripters-a-well-kept-secret/
# http://www.unix.com/shell-programming-scripting/53089-thousands-separator.html


