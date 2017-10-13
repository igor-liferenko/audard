# http://blog.shuva.in/index.php?entry=entry090322-073532    
# "explicity mention that it is a base 10 number, which can be quite cumbersome"
## y=081
## let x=10#$y*7; #Treat 08 as a base 10 digit.

# note, if you have img%05d.png format, but the sequence
# starts with, say, 'img00687.png', ffmpeg2theora will not recognize
# it as valid sequence - it wants the seq to start at 00000, and it keeps 
# going as long as it grows by one; i.e. img00000, img00001, img00200
#  will stop rendering after img00001!

# hence the filenames must be changed; here is a bash method for seq that starts at 536:
# for ix in render/* ; do ifn=$(basename $ix) ; ibn=${ifn%%.png} ; inb="$(echo $ibn | sed 's/img\(.*\)/\1/')" ; let inbb=10#$inb-536 ; newn=$(printf "%05d" $inbb) ; echo "mv render/$ifn render/_apd${newn}.png" ; done
# delete the echo to have it actually perform.

for ix in render/*
do 
	ifn=$(basename $ix) 
	ibn=${ifn%%.png}
	inb="$(echo $ibn | sed 's/img\(.*\)/\1/')"
	let inbb=10#$inb-536
	newn=$(printf "%05d" $inbb)
	echo "mv render/$ifn render/_apd${newn}.png"
done

# once the seq starts at 00000 (or the matching ammount of digits), 
# can call ffmpeg2theora, piping to ogvtranscode (to make sure we have ok vid for firefox)

/path/to/ffmpeg2theora-0.24-2b -F 5 -V 5000 render/img%05d.png -o /dev/stdout | oggTranscode -rv /dev/stdin pngexport-tx.ogv

