#!/bin/bash
# http://www.linuxquestions.org/questions/linux-newbie-8/what-are-ps1-ps2-ps4-variables-for-610061/
# http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_02_03.html
# http://forums.devshed.com/linux-help-33/bash-execute-string-as-command-363272.html
# http://wiki.bash-hackers.org/scripting/terminalcodes

# ANSI color start and end chars
CSA=$(echo -e "\033[0;31m")
CSB=$(echo -e "\033[0;32m")
CSC=$(echo -e "\033[0;33m")
CE=$(echo -e "\033[0m")


# "PS4 is the symbol that marks executed lines in a traced script."
# "$CSB+ " 		- colors everything
# "$CSB+ $CE" 	- colors '+' prompt only 
# "$CE+ $CSB" 	- colors everything but '+' prompt 
PS4="$CSC++ $CE" 

function ec()
{
        echo "${CSA}$1${CE}"
        eval "$1"
}



########## start

echo "Testing xtrace:"
echo 

set -x		# set -o xtrace; we're going to trace/debug execution of this script 

pwd
uname -a

set +x		# stop debug

echo -e "\nTesting single:\n"

ec "echo 'aaa' > /dev/stdout"

echo -e "\nDone. Bye!"

