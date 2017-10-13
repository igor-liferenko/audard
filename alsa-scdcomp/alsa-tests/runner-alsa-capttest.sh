#!/usr/bin/env bash
################################################################################
# runner-alsa-capttest.sh                                                      #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# i=0; while (( $i<8 )) ; do ((i++)); echo $i; done   # prints 1-8
# hide details: redirect (not tee) > *.log
# rm -rf entire mv command - non-existence of a file 'mv' will be silently ignored
# run with: bash runner-alsa-capttest.sh

control_c() {
  # run if user hits control-c
  echo -en "\n*** $0: Ctrl-C => Exiting ***\n"
  exit $?
}

# trap keyboard interrupt (control-c)
trap control_c SIGINT

ok=0; pass=0;
while (( $ok<4 )) ; do
  #bash run-alsa-capttest.sh 2>&1 > run-alsa-capttest.log ; # leaks to terminal
  echo Running pass $(( ++pass ))
  cmdrep=$(bash run-alsa-capttest.sh 2>&1 > run-alsa-capttest.log) ;
  sed -i '/Parsed line/d' run-alsa-capttest.log ;
  smry=$(awk '{if(/Results \(again\)/){flag=1;};if(flag){if(/Asked|start/){print;}}}' run-alsa-capttest.log) ;
  mvcmd=$(awk '{if(/Results \(again\)/){flag=1;};if(flag){if(/mv /){print;}}}' run-alsa-capttest.log);
  # any problem happened?:
  #isbroke=$(echo "$smry" | grep 'Asked' | grep 'Broken') ;
  # first is card 0 - hda-intel
  isbroke0=$(echo "$smry" | grep 'Asked' | head -1 | grep 'Broken') ;
  # second (last) is card 1 - dummy (also awk 'NR==2')
  isbroke1=$(echo "$smry" | grep 'Asked' | tail -1 | grep 'Broken') ;
  echo "$smry" ;
  # OK acquire condition: if both are ok: (8 collections for this)
  #~ if [ "$isbroke" == "" ] ; then
  # OK acquire condition: if 0 (hda-intel) is ok, and 1 (dummy) is broke (4 collections for this):
  if [ "$isbroke0" == "" -a "$isbroke1" != "" ] ; then
    echo -e "Capture OK - doing:\n $mvcmd" ;
    eval "$mvcmd";
    (( ok++ )) ;
  else
    echo -e "Capture bad - removing:\n rm -rf $mvcmd" ;
    eval " rm -rf $mvcmd";
  fi ;
  echo -e "ok: $ok (pass: $pass)\n";
done
