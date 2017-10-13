#!/bin/bash
# grab-deskcap-vid-double.sh

#~ set -x # for debug

function getkey() {
	OFS=$IFS ; 
	IFS=$'\n' ; # default IFS is $' \t\n', replace
	read -s -N 1 -d '' keyp ; # suppress terminal; one char read; no delimiter
	echo -${keyp}- ; 
	IFS=$OFS
}


#~ function finished() { echo "fin1 $0" ; }

# global vars
PLAYSTATE="STOPPED"
# below, either dbl quotes + no escape space  == ("  ") 
# or no quotes and escape space == (\ \ ) ... - but not both!
# AND - if spaces in dir; then "$DIR/$FILE" arg must be enclosed in dbl quotes!
AVIDIR=$HOME/.gvfs/_test\ on\ 192.168.1.100/myvid # "."
VNCDIR="$HOME/myvid"
VNCSERV="192.168.1.20:5900"

echo "Started... press SPACE to toggle."

# main 'loop'
while (true) ; do
	getkey
	if [ "${keyp}" == " " ] 
	then
		if [ "${PLAYSTATE}" == "STOPPED" ] 
		then
			echo
			PLAYSTATE="RUNNING"
			fname=MVI-`date +"%a_%b-%d_%H-%M-%S_%Y"`
			# spawn processes
			#~ (bash -c 'set -bm ; function finished() { echo "fin1 $0" ; } ; trap ''finished'' SIGKILL ; while [ 1 ] ; do sleep 1 ; done') & 	# trouble
			#~ (bash -c 'while [ 1 ] ; do sleep 1 ; done') &
			(mencoder -tv norm=PAL-BG:input=2:width=720:height=576:fps=25 -nosound -ovc lavc -lavcopts vcodec=mjpeg -o "$AVIDIR/$fname.avi" tv://) &
			pid1=$! # get pid of last spawned process
			echo $pid1 spawned
			
			#~ (while [ 1 ] ; do sleep 1 ; done) &
			(~/vncrec-twibright/binout/vncrec -depth 8 -bgr233 -viewonly -record $VNCDIR/$fname.vncrec $VNCSERV) &
			pid2=$! # get pid of last spawned pr ocess
			echo $pid2 spawned
			
			# "show desktop" - minimize all windows
			sleep 0.5
			wmctrl -k on
			
			echo
		else
			PLAYSTATE="STOPPED"
			# kill -2: SIGINT == Ctrl-C - doesn't kill
			kill $pid1
			kill $pid2
		fi
		echo "State ${PLAYSTATE}"
	elif [ "${keyp}" == "d" ] ; then
		echo 
		echo "Deleting last takes:"
		echo "$AVIDIR/$fname.avi"
		rm "$AVIDIR/$fname.avi"
		echo "$VNCDIR/$fname.vncrec"
		rm "$VNCDIR/$fname.vncrec"
		echo 
	fi
done

echo "End"
