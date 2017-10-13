
# build process on Ubuntu Natty (11.04)
# go to a directory where you'll build the code; then:

git clone git://github.com/vslavik/diff-pdf.git

cd diff-pdf/

# needed for bootstrap:
sudo apt-get install libwxgtk2.8-dev wx-common

./bootstrap

# needed for configure:
sudo apt-get install libcairo2-dev
sudo apt-get install libpoppler-glib-dev

./configure
make

# needed for running
sudo apt-get install poppler-data

# test:
./diff-pdf

# when calling, make sure either the "--output-diff=diff.pdf" option, or the "--view" option is set; example:
#~ ./diff-pdf --output-diff=diff.pdf /path/to/d1.pdf /path/to/d2.pdf
#~ ./diff-pdf --view /path/to/d1.pdf /path/to/d2.pdf


# note:
# libcairo2-dev:
#~ The following NEW packages will be installed:
  #~ libcairo-script-interpreter2 libcairo2-dev libexpat1-dev libfontconfig1-dev
  #~ libfreetype6-dev libglib2.0-dev libice-dev libpixman-1-dev libpng12-dev
  #~ libpthread-stubs0 libpthread-stubs0-dev libsm-dev libx11-dev libxau-dev
  #~ libxcb-render0-dev libxcb-shm0-dev libxcb1-dev libxdmcp-dev libxrender-dev
  #~ x11proto-core-dev x11proto-input-dev x11proto-kb-dev x11proto-render-dev
  #~ xtrans-dev
#
# libpoppler-glib-dev
#~ The following NEW packages will be installed:
  #~ debhelper html2text libatk1.0-dev libgdk-pixbuf2.0-dev libgtk2.0-dev
  #~ libmail-sendmail-perl libpango1.0-dev libpoppler-dev libpoppler-glib-dev
  #~ libsys-hostname-long-perl libxcomposite-dev libxcursor-dev libxdamage-dev
  #~ libxext-dev libxfixes-dev libxft-dev libxi-dev libxinerama-dev libxrandr-dev
  #~ po-debconf x11proto-composite-dev x11proto-damage-dev x11proto-fixes-dev
  #~ x11proto-randr-dev x11proto-xext-dev x11proto-xinerama-dev
  #~ xorg-sgml-doctools
