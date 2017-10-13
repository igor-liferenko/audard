# makeOgvXspfPlaylist.sh
# usage: ./makeOgvXspfPlaylist.sh /dir/with/ogv > mylist.xspf

# generate/create XSPF playlist, along with thumbnails and ogv video durations, 
# given a directory with .ogv video files

# see also http://www.londatiga.net/it/programming/how-to-get-video-thumbnail-and-duration-using-mplayer-and-php/
#~ set -x

# note - never add single quote ' in ##VIDTITLE## - it breaks itheora playlist! 

TDIR=.
if [ -n "$1" ]; then
	TDIR="$1"
fi

FDIR=$(readlink -f "$TDIR")
#~ echo $FDIR

# video URL - change manually
vURL="##URL##"

# thumbnail frame capture subdir
# note - on server, this subdit and its contents must be at least 755 (r-x) !! 
# also note - thumbnail must be in same dir as ovg ( so, no vthumbs ) for the
# 'main' video of playlist, which is specified in the call: 
# <object data="https://server.com/vids/itheora/index.php?v=http://server.com/vids/MOVIE.ogv&amp;n=My Playlist&amp;x=http://server.com/vids/my_playlist.xspf&amp;t=29&amp;xpt=r,200px&amp;d=st" 
# i.e. at least for MOVIE.ogv, thumbnail must be MOVIE.ogv.jpg in same dir. 
# hmmm... nope, apparently, it has to have an entry in https://server.com/vids/itheora/cache... 
# seems if a cache file on server (/itheora/cache/http---server.com-vids-MOVIE.ogv.cache) is deleted, it can only be re-created by calling: 
# https://server.com/vids/itheora/index.php?v=http://server.com/vids/MOVIE.ogv
# cache should contain:	s:10:"picturable";b:0;s:1:"b";s:0:"";s:1:"f";s:0:"";s:1:"p";s:71:"http://server.com/vids/MOVIE.ogv.jpg";
# but else its just: 		s:10:"picturable";b:0;s:1:"b";s:0:"";s:1:"f";s:0:"";
# that could be because cortado on server cannot parse the file.. if old, needs rebuild.. 
# itheora's index.php uses $image=get_jpg .. and $Ogg->GetPicture..
# itheora/lib/fonctions.php: get_jpg: problems with $ihost = $_SERVER['SERVER_NAME']; and $document_root is wrong for multi user.. 
# note that for ihost given, (ithera sees local) - the jpg link calced is: /htdocs/...MOVIE.ogv.jpg ; 
# but for "Video distante" (empy ihost): it is by default just: http://.../MOVIE.jpg  
# nope - seems there's a problem with url_exists.. yup, for JPG, there was a missed signature; so this hack is needed:
# case "jpg" : $tfile = @fread ($handle, 4); $file = ($tfile=="ÿØÿà"); if (!$file) $file = ($tfile=="ÿØÿþ"); break; 
THSD="$FDIR"/vthumbs
# empty and recreate folder
rm -rf "$THSD"
mkdir "$THSD"

echo '<?xml version="1.0" encoding="UTF-8" ?>
<playlist version="1" xmlns="http://xspf.org/ns/0/">\
  <title>##PLAYLISTTITLE##</title>\
  <trackList>
'

IVb=""
for IV in "$TDIR"/*.ogv; do 
	#~ echo AA +$IV+ +$TDIR+ +$FDIR+
	if [ "$IV" == "$TDIR/*.ogv" ]; then 
		echo "$IV" - nothing found";" exiting
		break
	fi
	IVb=$(basename "$IV")
	IVbb=${IVb%.ogv}
	IVfs="${IVbb}.ogv.jpg" # or "${IVbb}.jpg" - frame shot capture; png's too big
	
	# get screenshot of first frame of current video 
	# (has to be uploaded separately)
	# also: mplayer -ss 0 "$IV" â€“frames <numofthumb> -nosound -vo jpeg<:outdir="THSD">.
	# mplayer autonames captures in a given dir; ffmpeg works with given filename.. 
	ffmpeg -v 0 -i "$IV" -ss 0 -vframes 1 "$THSD"/"$IVfs" 2>/dev/null
	# get duration of .ogv video - xspf duration is in milliseconds
	# ogginfo "$IV" (oggzinfo) will scan through the entirety of my files to get to the duration
	# mplayer seems a bit faster... 
	# ogginfo 3m:58.097s/3m:58.099s = 3*60+58.099 = 238.099 -> mplayer 238.10
	LENTOT=$(mplayer -vo null -ao null -frames 0 -identify "$IV" 2>&1 | grep ID_LENGTH)
	LENSEC=$(echo "$LENTOT" | sed -n 's/ID_LENGTH=\(.*\)/\1/p') # i.e. 238.10
	LSEC=${LENSEC%.*} # 238
	LMSC=${LENSEC#*.} # 10
	MSEC=$(wcalc --quiet $LENSEC*1000) # convert to millisec using wcalc
	echo "<track>
<location>${vURL}/${IVbb}.ogv</location>
<!--
<image>${vURL}/vthumbs/${IVbb}.ogv.jpg</image>
-->
<title>##VIDTITLE##</title>
<creator>Sdaau</creator>
<duration>${MSEC}</duration>
</track>
"
	
done

echo '</trackList>
</playlist>
'

