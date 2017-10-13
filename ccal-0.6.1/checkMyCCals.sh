#!/usr/bin/env bash
#  Ccal 0.6.1 user script  	/sdaau

# to have the script work, do previously:
# cp checkMyCCals.sh checkMyCals.sh   # and edit as needed
# sudo ln -s /path/to/ccal-0.6.1/checkMyCals.sh /usr/bin/checkMyCals
# sudo ln -s /path/to/ccal-0.6.1/ccal-0.6.1.py /usr/bin/ccal-0.6.1

CAL1URL="http://path/to/FileA.ics"
CAL1FIL="file1.ics"
CAL1PSI="1A" # prepend string identifier

CAL2URL="https://otherpath/towards/FileB.ics"
CAL2USR="userlogin"
CAL2FIL="file2.ics"
CAL2PSI="2B" # prepend string identifier

# ANSI color start and end chars
CSA=$(echo -e "\033[0;31m")
CSB=$(echo -e "\033[0;34m")
CE=$(echo -e "\033[0m")

OLDDIR=$(pwd)
# change CALDIR as desired - where calendar files will be saved
CALDIR=`dirname \`readlink -f \\\`which ccal-0.6.1\\\`\``
echo "olddir: $OLDDIR ; changing to:"
echo "caldir: $CSA$CALDIR$CE"
cd $CALDIR

# the wgets should also overwrite previously existing ones
wget $CAL1URL -O $CAL1FIL
wget-1.12 --no-check-certificate --http-user=$CAL2USR --ask-password $CAL2URL -O $CAL2FIL

# symlink before: sudo ln -s ccal-0.6.1.py /usr/bin/ccal-0.6.1

echo "caldir: $CSB$CALDIR$CE"
CMD="ccal-0.6.1 -n -i $CAL1FIL,$CAL1PSI,$CAL2FIL,$CAL2PSI"

# print out command in color
echo $CSA$CMD$CE
echo
# execute command
$CMD

echo "go back to: $OLDDIR .."
cd $OLDDIR


