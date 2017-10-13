# http://www.imagemagick.org/script/montage.php

# note: to get preview, output to stdout and pipe into `display`:
# montage 1.bmp 2.png 3.png 4.png -geometry +2+2 -tile 2x2 bmp:- | display

for fn in jit/*
do
	fn1=${fn%%.tiff} ;
	fn1b=$(basename $fn1) ;

	# do a bit of cleanup first - copy paste over
	#~ convert $fn \( -clone 0 -crop 45x15+380+19 \) -geometry +380+34 -composite tmp2/$fn1b.tiff
	#~ convert jit-zoom/$fn1b-zoom.tiff \( -clone 0 -crop 45x15+380+19 \) -geometry +380+34 -composite tmp2/$fn1b-zoom.tiff

	#~ echo montage $fn jit-zoom/$fn1b-zoom.tiff -mode concatenate -tile x1 -type GrayScale jit2/$fn1b.png ;
	montage $fn jit-zoom/$fn1b-zoom.tiff -mode concatenate -tile x1 jit-comp/$fn1b.tiff ;
done

# NOTE: sometimes montage may produce a thumbnail out of big imagesl if using:
# montage tmpa.png tmpb.png -tile 1x2 out.png
# in that case, add geometry argument - size will be preserved:
# montage tmpa.png tmpb.png -geometry +2+2 -tile 1x2 out.png

# for pdfs:
# montage "My Doc.pdf"[4] "My Doc.pdf"[5] -density 72 -border 1 -bordercolor lime -geometry +2+2 -tile 1x2 out.png

# to generate multiline text on transparent background:
# convert -background none -density 150 -pointsize 20 label:"$(awk '{if(/Results \(again\):/){flag=1;};if(flag){if(/Asked|start/){print;}}}' captures-2013-08-02-23-55-34/run-alsa-capttest.log)" overlaytext.png

# multiline text AND header with different size;
# -append: one below other; +append: one next to other:
convert -background none -pointsize 40 label:"AAAA" -pointsize 20 label:"$(awk '{if(/Results \(again\):/){flag=1;};if(flag){if(/Asked|start/){print;}}}' captures-2013-08-02-23-55-34/run-alsa-capttest.log)" -append text.png

# to overlay that on existing image:
# mogrify -draw 'image Over 0,0 0,0 "overlaytext.png"' anim_%d.gif

# to montage all pages in a pdf on single image, with padding (border):
# montage -density 75 -mode concatenate -tile x1 -border 3 minitest.pdf bmp:-
