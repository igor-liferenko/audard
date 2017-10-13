# http://www.imagemagick.org/script/montage.php
#

# delay 5 is decently fast
convert -delay 5 -loop 0 jit-comp/*.tiff -type grayscale animate.gif

#convert -delay 5 -loop 0 $(find ./images/ -type f | sort --version-sort -f) animate.gif
#gifsicle -O2 --colors 8 animate.gif -o animate-O2.gif

# also thumbnail inline works:
# strangely, thumbnail may be larger in size than the original above?
#~ convert -delay 5 -loop 0 jit-comp/*.tiff -type grayscale -thumbnail 600x animate-t.gif

# note: it is possible that:
# convert -size 303x282 -delay 5 -loop 0 /tmp/test{1,2}.png /tmp/testanim.gif
# ... for test{1,2}.png of size 303x282, to provide a gif which is 1024 x 600 in pixel size! To fix that, use thumbnail:
# convert -size 303x282 -delay 5 -loop 0 /tmp/test{1,2}.png -thumbnail 303x /tmp/testanim.gif

# portion to generate images:
# (from http://ubuntuforums.org/showthread.php?p=9697655#post9697655)
# generate source png image (gradient)
# formats: http://www.oc.nps.edu/~bird/web101/image/convert_doc.html
#~ convert -size 640x480 gradient:\#4b4-\#bfb $SRCIMG
#
# rotate
#~ convert $SRCIMG -rotate $ix tmp.png
#~ convert -size 640x480 -depth 8 -extract 640x480+0+0 tmp.png testgpngs/$fname
#
# and just plain text:
#~ convert -size 150x150 xc:white -pointsize 72 -draw "text 25,60 'test'" test.png && eog test.png

# the below generates image 1x1 pixel in size!
#~ convert -page A4 -density 300x300 xc:white -pointsize 72 -draw "text 25,60 'test'" test.png

# to convert frames from Processing into a gif, with some optimization for smaller size:
# convert -bordercolor black -border 1 -delay 5 -loop 0 -fuzz 5%  -deconstruct -layers OptimizeTransparency marbles-*.png -resize 300x marbles.gif

# helps reduce size:
# gifsicle -O2 test-tilde.gif -o test-tilde-O2.gif
