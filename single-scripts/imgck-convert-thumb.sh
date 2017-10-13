# http://www.imagemagick.org/Usage/thumbnails/
for ix in *.png
do
	nm=${ix%%.png}
	echo $nm
	convert $ix -thumbnail 400x -unsharp 0x.5  $nm-t400.png
done

# http://www.linuxquestions.org/questions/linux-software-2/pdf-to-png-converter-57142/
# pdf2png conversion:
# NOTE: for pdf, MUST have DENSITY - *just* size doesn't work!
#
#~ gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pnggray -r300-sOutputFile=out.png in.pdf
#
#~ convert -density 300x300 -resize 1000x1000 in.pdf out.png
#

# note, sometimes convert gives crappy render of PDF (SO653380/converting-a-pdf-to-png)
# then, use ghostscript ....
# note - the gs above, for some reason could fail; the below is OK:
#~ gs -dBATCH -dNOPAUSE -sDEVICE=pnggray -sOutputFile=my.png -r200 ./my.pdf
#~ gs -dBATCH -dNOPAUSE -sDEVICE=pngalpha -sOutputFile=my.png -r200 ./my.pdf
#~ gs -dBATCH -dNOPAUSE -sDEVICE=png16m -sOutputFile=my.png -r200 ./my.pdf
#~ gs -dBATCH -dNOPAUSE -dGraphicsAlphaBits=1 -dTextAlphaBits=4 -sDEVICE=png16m -sOutputFile=my.png -r200 ./my.pdf
# bitmap devices gs:
# http://stat.ethz.ch/R-manual/R-patched/library/grDevices/html/dev2bitmap.html
# antialias gs:
# http://pages.cs.wisc.edu/~ghost/doc/cvs/Devices.htm
# note: sometimes can get crappy PDF line rendering for dGraphicsAlphaBits=2; 1 should work fine there;
# usually no problem with text, so can anti-alias text with more, e.g. -dTextAlphaBits=4

#
# OR - scale only by width (proportionally) - blur and apply contrast:
# order of parameters seems to matter:
# http://studio.imagemagick.org/pipermail/magick-users/2005-December/016896.html
#
#~ convert -density 300x300 -blur 3x5 -normalize +contrast +contrast -resize 1000x write-process.pdf write-process.png
#
#
# OR also with gamma after resize:
# convert -density 300x300  -normalize -auto-gamma +contrast +contrast +contrast -resize 1000x -gamma 0.7 write-sizes.pdf write-sizes.png
#

# for TRANSPARENT png/pdf etc:
#~ convert -channel rgba -fill white -opaque none -density 150x150 file.ps outfile.png
#
# see Controlling background color of transparent PNG?
# http://www.imagemagick.org/discourse-server/viewtopic.php?f=1&t=11398

# for big svg plots out from kicad:
# svg 1.6 MB -> png 2.6 MB -> png quant 300 K
# convert -density 300x300 x.svg x.png && pngquant -nofs -verbose -force 16 x.png && mv x-or8.png x.png

# multi page pdf to png:
# convert -density 300x300 "my_multipage.pdf[5]" my_multipage_pg6.png

# generate text - notes:
## xc:white is the "input file" (the background) - without it, imagemagick says "missing an image filename" (which should be, and was earlier, "Empty input file")
## size of input must be specified for both dimensions - else it defaults to one pixel
## pointsize means "font size"
#
# convert -size 150x150 xc:white -pointsize 72 -draw "text 25,60 'test'" test.png && eog test.png

# to grab screenshot (of remote PC) remotely via ssh (command typed on local PC):
# http://www.linuxquestions.org/questions/linux-general-1/commanding-the-x-server-to-take-a-png-screenshot-through-ssh-459009/
# import -window root -display :0.0 screenshot.png

# debug fx expressions:
# convert -density 300x300 rose_A4.pdf -pointsize 72 -draw "text 25,235 'test'" -fx 'debug(w)' rose_A4.png
# convert -density 300x300 myout.pdf -format "%[fx:w]x%[fx:h]" info:

# http://tex.stackexchange.com/questions/17762/cmyk-poster-example-fitting-pdf-page-size-to-bitmap-image-size
####
#~ convert xc:white -page A4 myout.pdf
#~ TSIZE=$(convert -density 300x300 myout.pdf -format "%[fx:w]x%[fx:h]" info:)
#~ convert -density 300x300 -size $TSIZE myout.pdf gradient:\#4b4-\#bfb -pointsize 72 -draw "text 25,235 'test'" -flatten myout.png
#~ # convert RGB png to CMYK tiff:
#~ convert myout.png -depth 8 -colorspace cmyk -alpha Off myout-cmyk.tiff
#~ # convert CMYK tiff to CMYK eps
#~ gs -r300x300 -g$TSIZE -dNODISPLAY -- tif2eps.ps myout-cmyk.tiff -v2 -d300x300 -r1 -o1 myout-cmyk.eps
#~ # convert CMYK eps to CMYK pdf:
#~ gs -o myout-cmyk.pdf -sDEVICE=pdfwrite -dPDFFitPage -r300x300 -g$TSIZE myout-cmyk.eps
####

# convert small images as one page each of an A4 pdf; not scaled, centered
#~ convert -size 100x100 xc:red red.png
#~ convert -size 100x100 xc:green green.png
#~ convert *.png -page A4 -gravity center out.pdf
# but for .jpg - use without gravity ?!

# A4 scans 300 dpi: identify -units pixelsperinch -verbose scan.png
# #doesn't change size in pixels - only changes dpi (and print size):
# convert -units pixelsperinch scan.png -density 150 out.png
# #changes size in pixels and the dpi (but not print size):
# convert -units pixelsperinch scan.png -resample 150 out.png
# #resample and jpeg quality in one go:
# convert -units pixelsperinch scan.png -resample 150 -quality 30 out.jpg
# BUT, sometimes need to be explicit about ppi (density) of input, if info not present:
# convert -units pixelsperinch -density 300 scan.png -resample 150 -quality 30 out.jpg
