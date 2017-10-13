
# make a dir, say 'ngspice-cvs' ($ODIR)
# copy this script (get-ngspice-src-deb.sh) inside it;
# make script executable 'chmod +x get-ngspice-src-deb.sh' ;
# do 'cd ngspice-cvs' and execute './get-ngspice-src-deb.sh'

# build uses about 177M	total

# need cvs
# sudo apt-get install cvs
# for checkinstall ...
sudo apt-get install bison checkinstall

# to get cvs patchsets
sudo apt-get install cvsps
# NOTE about cvsps:
#~ :ngspice$ cvsps -q | grep PatchSet | tail --lines=1
#~ PatchSet 2292
#~ :ngspice$ cd ng-spice-rework/
#~ :ng-spice-rework$ cvsps -q | grep PatchSet | tail --lines=1
#~ PatchSet 2066
# so for correct patchset number (as shown by sourceforge),
#   make sure you call cvsps from the ngspice dir!!
# ALSO, must have 'cvsps -q -x' to "ignore (and rebuild) ~/.cvsps/cvsps.cache file"
# .. or  'cvsps -q -u' to "date ~/.cvsps/cvsps.cache file" -
# .. else, cvsps just reports the old patchset number!!!

# to build xspice, need flex
# READ THE CONFIG.LOG AFTER ./configure: if getting:
# "configure:15532: error: Flex is required for building XSPICE"
# then in spite of --enable-xspice, xspice will not work ! And then will
# get errors for analog models (s_xfer) like:
#~ Model issue on line 50 : .model amp gain(in_offset=0.1 gain=5.0 out_offset=-0.01) ...
#~ unknown model type gain - ignored
#~ Error on line 65 : a_lopass1 n_0015 n_0016 amp
sudo apt-get install flex

# prerequisite for ngspice (Ubuntu 10.04):
# .. also installs libxmu-headers libxmu-dev (autoremove for them)
# 11.04:
#~ The following NEW packages will be installed:
#~  libice-dev libpthread-stubs0 libpthread-stubs0-dev libsm-dev libx11-dev
#~  libxau-dev libxaw7-dev libxcb1-dev libxdmcp-dev libxext-dev libxmu-dev
#~  libxmu-headers libxpm-dev libxt-dev x11proto-core-dev x11proto-input-dev
#~  x11proto-kb-dev x11proto-xext-dev xtrans-dev
sudo apt-get install libxaw7-dev

# 11.04: You must have libtool installed to compile ngspice.
# 11.04: auto-installs libltdl-dev
sudo apt-get install libtool

ODIR=$(pwd)

# no need for login
#~ cvs -d:pserver:anonymous@ngspice.cvs.sourceforge.net:/cvsroot/ngspice login

cvs -z3 -d:pserver:anonymous@ngspice.cvs.sourceforge.net:/cvsroot/ngspice co -P ngspice/ng-spice-rework

# NOTE ABOUT CVS:
# the above checkout command will NOT replace locally modified files;
# to have them replaced, run 'cvs update -C' to Overwrite locally modified files
cd ngspice/ng-spice-rework
cvs update -C
cd ../..

# rearrange dirs - no need
#~ mv ngspice/ng-spice-rework ./ng-spice-rework
#~ rm -rf ngspice

# get revision (cvs patchset) number
cd ngspice
CVSPSETREV=$(cvsps -q  -u | grep PatchSet | tail --lines=1 | cut -d' ' -f2)
cd ..

cd ngspice/ng-spice-rework
# get package version, maintainer
# seems to have changed from 'configure.in' to 'configure.ac'
K1=$(grep AC_INIT configure.ac | tr ',()' ' ')
CVSPKNAME=$(echo $K1 | cut -d' ' -f2)
CVSVERSION=$(echo $K1 | cut -d' ' -f3)
CVSMAINT=$(echo $K1 | cut -d' ' -f4)

echo "

STARTING:
$CVSPKNAME
$CVSVERSION
cvs-${CVSPSETREV}
$CVSMAINT

"

./autogen.sh
# --enable-stepdebug generates a bit too much data, and cannot be controlled
./configure --enable-maintainer-mode --enable-xspice --enable-checker --enable-debug  --enable-ftedebug --enable-cpdebug --enable-stepdebug --with-x --enable-readline
make

# to create .deb - use checkinstall

#~ --fstrans Enable/disable filesystem translation. Filesystem translation enabled causes the install to proceed in a  temporary  direc‐ tory, thus not actually touching your system.
#~ -y   --default Accept default answers to all questions.
#~ --pakdir  Where to save the new package.
#~ -D        Create a Debian package.
#~ --reset-uids 	Reset perms for all files/dirs to 755 and the owner/group for all dirs to root.root

# to find dependencies (of the vanilla Ubuntu ngspice package), use:
#~ apt-cache -f -a show ngspice | grep Depends
#~ Depends: libc6 (>= 2.7), libice6 (>= 1:1.0.0), libsm6, libx11-6, libxaw7, libxext6, libxmu6, libxt6, dpkg (>= 1.15.4) | install-info
# same info for uninstalled .deb package:
#~ dpkg --info ngspice_21plus-cvs-2292_i386.deb

# to find installed files (of the vanilla Ubuntu ngspice package), use:
#~ dpkg --listfiles ngspice
# to find where the files will be installed from the new deb, use:
#~ dpkg --contents ngspice_21plus-cvs-2292_i386.deb

# 11.04: --fstrans=no: https://bugs.launchpad.net/ubuntu/+source/checkinstall/+bug/307799
sudo checkinstall -D -y \
					--install=no \
          --fstrans=no \
					--reset-uids=yes \
					--pkgname=$CVSPKNAME \
					--pkgversion=$CVSVERSION \
					--pkgrelease="cvs-${CVSPSETREV}" \
					--arch=i386 \
					--pkglicense=GPL \
					--maintainer=$CVSMAINT \
					--pakdir=../.. \
					--requires=libc6,libice6,libsm6,libx11-6,libxaw7,libxext6,libxmu6,libxt6,dpkg,install-info

# check if binary from checkinstall's `make install` lingers (it should)
ngspice --version

# note: http://unix.stackexchange.com/questions/53871/
# here `checkinstall` would have ran the local `make install`;
# so here all executables, etc are actually installed!
# at this point, do a `make uninstall` in the source folder
#  to have those removed - so can do a clean install with the new .deb!
make uninstall

# check if binary still lingers (it shouldn't [No such file or directory]):
ngspice --version


# to just copy ecutables after make; check `which ngspice`
#~ ng-spice-rework$  find src -maxdepth 1 -executable -type f -name 'ng*' -exec echo sudo cp {} $(dirname $(which ngspice)) \;


echo "

FINISHED:
$CVSPKNAME
$CVSVERSION
cvs-${CVSPSETREV}
$CVSMAINT

INDIR: $PWD

sudo checkinstall -D -y \
					--install=no \
          --fstrans=no \
					--reset-uids=yes \
					--pkgname=$CVSPKNAME \
					--pkgversion=$CVSVERSION \
					--pkgrelease=\"cvs-${CVSPSETREV}\" \
					--arch=i386 \
					--pkglicense=GPL \
					--maintainer=$CVSMAINT \
					--pakdir=../.. \
					--requires=libc6,libice6,libsm6,libx11-6,libxaw7,libxext6,libxmu6,libxt6,dpkg,install-info

"

# the newly created .deb should be in $ODIR
# install with 'sudo dpkg -i ngspice_21plus-cvs-2292_i386.deb'
# (that installation will replace Ubuntu vanilla package)
cd $ODIR
ls -la ngspice*.deb
dpkg --info ngspice*.deb

# ok, remove packages we only needed for the build
sudo apt-get remove --purge libtool
sudo apt-get remove --purge libxaw7-dev libxmu-headers libxmu-dev
sudo apt-get remove --purge flex
sudo apt-get remove --purge cvsps
sudo apt-get remove --purge bison checkinstall
sudo apt-get autoremove --purge

# default from ubuntu vanilla
#~ $ ngspice --version
#~ ngspice compiled from ngspice revision 20
#~ Written originally by Berkeley University
#~ Currently maintained by the NGSpice Project
#~ Copyright (C) 1985-1996,  The Regents of the University of California
#~ Copyright (C) 1999-2008,  The NGSpice Project
# man ngspice shows "20 March 1986"

# from the new deb:
#~ $ ngspice --version
#~ ngspice compiled from ngspice revision 21plus
#~ Written originally by Berkeley University
#~ Currently maintained by the NGSpice Project
#~ Copyright (C) 1985-1996,  The Regents of the University of California
#~ Copyright (C) 1999-2008,  The NGSpice Project
# man ngspice shows "6 June 2010"


