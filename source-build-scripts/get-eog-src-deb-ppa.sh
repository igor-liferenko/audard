
# http://ubuntuforums.org/showthread.php?t=49216&highlight=dh_make
# https://wiki.ubuntu.com/PackagingGuide/Python
# https://help.launchpad.net/Packaging/PPA/BuildingASourcePackage
# http://www.murrayc.com/blog/permalink/2006/04/21/building-modified-debian-packages/
# Eye of gnome eog-2.32 for Lucid 10.04
# still doesn't show inkscape svg properm though - transp background and bitmap..

mkdir eog-src
cd eog-src

# prereq
sudo apt-get install eog-dev
sudo apt-get build-dep eog

# get ubuntu sources
apt-get source eog
# creates dir: eog-2.30.0

# get latest sources 
wget http://download.gnome.org/sources/eog/2.32/eog-2.32.0.tar.gz
tar xzvf eog-2.32.0.tar.gz
# creates dir: eog-2.32.0

diff <(ls eog-2.30.0) <(ls eog-2.32.0)
# should just output debian 

# maybe not needed 
mv eog-2.32.0 eog-2.32.0-ppa

# copy debian dir
cp -a eog-2.30.0/debian eog-2.32.0-ppa

# go in new source
cd eog-2.32.0-ppa

# change version - edit debian/changelog
# new version, maintainer will be autoadded as first (latest) entry
# change the version to 2.32.0-ppa-0ubuntu1
# note, each call to dch will add yet a new version
dch -i

# problems with newer version - hack 
#~ grep -r --color 2.25.9 .
sed -n 's/2.25.9/2.24.1/gp' configure
sed -i 's/2.25.9/2.24.1/g' configure
sed -n 's/2.25.9/2.24.1/gp' configure.ac
sed -i 's/2.25.9/2.24.1/g' configure.ac

#~ debuild -b
#~ echo totem-screensaver fails - comment
nano configure

#~ debuild -b
#~ grep -r --color 'totem-screensaver' .
#~ grep -r --color 'screensaver_LIB' .
#~ echo should remove totem-screensaver, screensaver_LIB in Makefile, .in, .am
nano ./src/Makefile.in
nano ./src/Makefile.am
nano ./src/Makefile

#~ debuild -b
#~ grep -r --color 'totem-screensaver' .
#~ echo still totem-screensaver - comment
nano ./cut-n-paste/Makefile.in
nano ./cut-n-paste/Makefile
nano ./cut-n-paste/Makefile.am 

#~ debuild -b
#~ echo link undefined reference - comment totem-screensaver here
nano ./src/eog-application.c
#~ echo also _save_jpeg_as_jpeg undefined refs jcopy_markers_setup.. - comment all 
nano ./src/eog-image-jpeg.c

# build - creates also -dbg and -dev .debs:
debuild -b

# finally can install 
sudo dpkg -i ../eog_2.32.0-ppa-0ubuntu1_i386.deb

# clean up - use also apt-get remove --simulate to check dependencies
apt-cache showsrc eog | grep Build-Depends:

sudo apt-get remove --purge eog-dev libjpeg62-dev gtk-doc-tools libgnome-desktop-dev libgconf2-dev zlib1g-dev libexif-dev liblcms-dev libexempi-dev libjpeg62-dev libdbus-glib-1-dev libxml2-dev x11proto-core-dev 

#~ Note, selecting liblcms1-dev instead of liblcms-dev
#~ The following packages were automatically installed and are no longer required:
  #~ python-gtk2-doc libsigc++-2.0-dev libaudiofile-dev libaudio-dev x11proto-xinerama-dev libsysfs-dev libdirectfb-extra
  #~ libavahi-client-dev gnome-common x11proto-randr-dev libdrm-dev libdbus-1-dev libesd0-dev libasound2-dev libexpat1-dev jade
  #~ libpixman-1-dev docbook-dsssl orbit2 libavahi-common-dev
#~ Use 'apt-get autoremove' to remove them.
#~ The following packages will be REMOVED:
  #~ eog-dev* gtk-doc-tools* guile-cairo-dev* libaa1-dev* libatk1.0-dev* libcaca-dev* libcairo2-dev* libcairomm-1.0-dev*
  #~ libdbus-glib-1-dev* libdirectfb-dev* libexempi-dev* libexif-dev* libfontconfig1-dev* libfreetype6-dev* libgconf2-dev*
  #~ libgd2-xpm-dev* libgl1-mesa-dev* libglib2.0-dev* libglibmm-2.4-dev* libglu1-mesa-dev* libgnome-desktop-dev* libgtk2.0-dev*
  #~ libgtkmm-2.4-dev* libhdf5-serial-dev* libice-dev* libidl-dev* libjpeg62-dev* liblaunchpad-integration-dev* liblcms1-dev*
  #~ libmatio-dev* liborbit2-dev* libpango1.0-dev* libpangomm-1.4-dev* libpng12-dev* libpulse-dev* libsdl1.2-dev* libslang2-dev*
  #~ libsm-dev* libssl-dev* libstartup-notification0-dev* libx11-dev* libxau-dev* libxaw7-dev* libxcb-render-util0-dev*
  #~ libxcb-render0-dev* libxcb1-dev* libxcomposite-dev* libxcursor-dev* libxdamage-dev* libxdmcp-dev* libxext-dev*
  #~ libxfixes-dev* libxft-dev* libxi-dev* libxinerama-dev* libxml2-dev* libxmu-dev* libxmu-headers* libxpm-dev* libxrandr-dev*
  #~ libxrender-dev* libxss-dev* libxt-dev* mesa-common-dev* python-gobject-dev* python-gtk2-dev* tk8.5-dev*
  #~ x11proto-composite-dev* x11proto-core-dev* x11proto-damage-dev* x11proto-fixes-dev* x11proto-input-dev* x11proto-render-dev*
  #~ x11proto-scrnsaver-dev* x11proto-xext-dev* zlib1g-dev*
# autoremove --purge:
#~ The following packages will be REMOVED:
  #~ docbook-dsssl* gnome-common* jade* libasound2-dev* libaudio-dev* libaudiofile-dev* libavahi-client-dev* libavahi-common-dev*
  #~ libdbus-1-dev* libdirectfb-extra* libdrm-dev* libesd0-dev* libexpat1-dev* libpixman-1-dev* libpthread-stubs0*
  #~ libpthread-stubs0-dev* libsigc++-2.0-dev* libsysfs-dev* orbit2* python-gtk2-doc* x11proto-kb-dev* x11proto-randr-dev*
  #~ x11proto-xinerama-dev* xtrans-dev*

