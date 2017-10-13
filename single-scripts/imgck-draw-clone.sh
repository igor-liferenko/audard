# ImageMagick - View topic - Copy-paste an image region - http://www.imagemagick.org/discourse-server/viewtopic.php?f=1&t=13859

# works with tiff:

convert test1.tiff \( -clone 0 -crop 45x15+380+19 \) -geometry +380+34 -composite tmpout.tiff

