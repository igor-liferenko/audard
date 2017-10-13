ATT="/media/nonos/sdaaubckp/attenload"
sudo bash -c "$ATT/attenload -c 2>/dev/null"
sudo bash -c "$ATT/attenload -s 6>usbout.dat 2>/dev/null"
sudo bash -c "$ATT/attenload -d 2>/dev/null"
# .ssf auto added
#~ perl "$ATT/adsparse-dvstngs.pl" usbout.dat usbout_${1} 2>&1
# so can do: get_ssf.sh /dev/null
perl "$ATT/adsparse-dvstngs.pl" usbout.dat 1>${1}
rm -f usbout.dat

# note: bash color diff:
# A=0; while true; do A=$((A+1)); B=$(printf "%06d" $A); bash attenload/devscripts/get_ssf.sh __$B.ssf; diff -s $prev __$B.ssf; dwdiff --color --wdiff-output -C1 <(hexdump -Cv $prev) <(hexdump -Cv __$B.ssf); prev=__$B.ssf; sleep 1; done 2>&1 | tee logrep_ssf.log

