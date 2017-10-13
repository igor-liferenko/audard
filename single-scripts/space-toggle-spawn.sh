#!/bin/bash
# grab-vid-double.sh

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


# main 'loop'
while (true) ; do
	getkey
	if [ "${keyp}" == " " ] 
	then
		if [ "${PLAYSTATE}" == "STOPPED" ] 
		then
			PLAYSTATE="RUNNING"
			
			# spawn processes
			#~ (bash -c 'set -bm ; function finished() { echo "fin1 $0" ; } ; trap ''finished'' SIGKILL ; while [ 1 ] ; do sleep 1 ; done') & 	# trouble
			(bash -c 'while [ 1 ] ; do sleep 1 ; done') &
			pid1=$! # get pid of last spawned process
			echo $pid1 spawned
			
			(while [ 1 ] ; do sleep 1 ; done) &
			pid2=$! # get pid of last spawned process
			echo $pid2 spawned
			
		else
			PLAYSTATE="STOPPED"
			# kill -2: SIGINT == Ctrl-C - doesn't kill
			kill $pid1
			kill $pid2
		fi
		echo "State ${PLAYSTATE}"
	fi
done

echo "End"
