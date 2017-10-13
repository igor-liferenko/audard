#!/bin/bash

# http://bash.cyberciti.biz/file-management/read-a-file-line-by-line/
# http://www.linuxquestions.org/questions/programming-9/bash-read-entire-file-line-in-for-loop-240016/
# http://www.kilala.nl/Sysadmin/index.php?id=741 - The scope of variables in shell scripts: 1 3 6 10 Total is 0. 
# http://www.computing.net/answers/unix/finding-consecutive-lines-in-a-file/3996.html
# http://www.linuxforums.org/forum/programming-scripting/65874-bash-scripting-use-regex-case-pattern.html
#~ A case command first expands word, and tries to match it against
#~ each pattern in turn, using the same matching rules as for path-
#~ name  expansion (see Pathname Expansion below). 

# simpler one-liner grep - but cannot find one line with one condition, and subsequent lines with others
#~ for ix in $(find . -name '*.c' -or -name '*.h') ; do ax=`grep --color=always -H 'static' $ix` ; bx=`grep --color=always -H 'int\|char\|void' $ix`; if [ "$ax" -a "$bx" ]; then echo -e "\n\n$ax\n$bx" ; fi ; done | less -R


# note - below takes a while to exec, even for just 3K lines!
let COUNT=1;
FILE=/usr/src/linux/include/config/sparsemem/static.h
echo "$FILE"
while read line
do
	PATTERN="static*"	# function declaration word pattern
	case "$line" in
		$PATTERN) {
			OLDFLINE="$CFLINE"
			CFLINE="$line"
			if [[ "$GOTRES" == "y" ]] ; then
				echo "$OLDFLINE"
				echo -e "$RESCHUNK"
				# echo
				unset GOTRES
				unset RESCHUNK
			fi
			} 
			;;
		*) {	# else... note, -H -n dont help here w grep, stdin
			GRS=$(echo "$line" | grep "int\|char\|void")
			if [ "$GRS" ] ; then
				tline="\t$COUNT:  $GRS\n"
				RESCHUNK="$RESCHUNK$tline"
				GOTRES="y"
			fi
		} 
			;;
	esac
	
	let COUNT=$COUNT+1
done < $FILE 2>&1
echo $COUNT 
