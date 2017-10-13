## batchVidConvUpl.sh

# local loc of ffmpeg2theora
# don't use dblquotes here, let the shell expand the home '~'
FF2T=~/path/to/ffmpeg2theora-0.27.linux32.bin
# server for upload (including ssh username)
SERV="USER@ssh-server.com"
# destination upload directory on (ssh) server
SLOC="~/path/to/dest-folder"

# get ssh password (shell shows this in cleartext!)
read -p "pass" RpasS;

for IFN in *.AVI
do
	AA=${IFN%.*}
	#~ echo $AA
	$FF2T -v 7 -a 3 -o /dev/stdout $AA.AVI | tee $AA.ogv | sshpass -p $RpasS ssh $SERV "cat > $SLOC/$AA.ogv"
	# once done, move both in parent dir
	mv -v $IFN ../
	mv -v $AA.ogv ../
done
