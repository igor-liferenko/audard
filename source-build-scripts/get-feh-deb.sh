#!/usr/bin/env bash

# the below tried on ubuntu lucid, nov 2012

# determine location of bash script (http://stackoverflow.com/questions/59895/)
CALL_PATH="$PWD"
SCRIPT_PATH="${BASH_SOURCE[0]}"
if([ -h "${SCRIPT_PATH}" ]) then
  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null
echo script $SCRIPT_PATH .. call $CALL_PATH

set -x

if [ ! -d fehsrc ] ; then
  mkdir fehsrc
fi

cd fehsrc

# install dependencies:
sudo apt-get install libcurl3 libx11-dev libxt-dev libimlib2-dev giblib-dev libxinerama-dev libjpeg-progs
# (for me, only libgif-dev libtiff4-dev libtiffxx0c2 as extra packages currently -> giblib-dev libgif-dev libimlib2-dev libtiff4-dev libtiffxx0c2 as NEW)
# getting fatal error: curl/curl.h: No such file -> libcurl3-dev not in Ubuntu 11.04;
# http://packages.ubuntu.com/lucid/libcurl3-dev : Packages providing libcurl3-dev: libcurl4-openssl-dev
sudo apt-get install libcurl4-openssl-dev
# libcurl4-openssl-dev - EXTRA: comerr-dev krb5-multidev libgssrpc4 libidn11-dev libkadm5clnt-mit7 libkadm5srv-mit7 libkdb5-4 libkrb5-dev libldap2-dev
# `make` passes with this...

# get latest sources
# NB: there's also git:
## git clone git://derf.homelinux.org/feh ; cd feh #old
git clone https://github.com/derf/feh.git
cd feh
VERSION=$(git describe --dirty) # NOT `shell git describe --dirty`!!
echo "VERSION is $VERSION"

# going with .tar.bz2 for now:
#~ wget http://feh.finalrewind.org/feh-2.7.tar.bz2
#~ tar xjvf feh-2.7.tar.bz2
# creates dir feh-2.7

#~ cd feh-2.7
make

./src/feh --version
# may return:
# feh WARNING: The theme config file was moved from ~/.fehrc to ~/.config/feh/themes. Run
    #~ mkdir -p ~/.config/feh; mv ~/.fehrc ~/.config/feh/themes
# to fix this.
# feh version 2.7
# Compile-time switches: curl xinerama
mkdir -p ~/.config/feh ; cp ~/.fehrc ~/.config/feh/themes


# create a debian package
# we don't start from a .deb, so no need for `dch`/`debuild`
# use `checkinstall`; as this is direct from source

# to find dependencies (of the vanilla Ubuntu feh package), use:
# apt-cache -f -a show feh | grep Depends
## Depends: giblib1 (>= 1.2.4), libc6 (>= 2.7), libimlib2, libpng12-0 (>= 1.2.13-4), libx11-6, libxinerama1
# apt-cache -f -a show feh | grep Maintainer
## Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
## Original-Maintainer: Debian PhotoTools Maintainers <pkg-phototools-devel@lists.alioth.debian.org>


sudo checkinstall -D -y \
  --install=no \
  --fstrans=no \
  --reset-uids=yes \
  --pkgname=feh \
  --pkgversion=$VERSION \
  --pkgrelease="git" \
  --arch=i386 \
  --pkglicense=GPL \
  --maintainer="Debian PhotoTools Maintainers <pkg-phototools-devel@lists.alioth.debian.org>" \
  --pakdir=../.. \
  --requires=libc6,libice6,libsm6,libx11-6,libxaw7,libxext6,libxmu6,libxt6,dpkg,install-info

# check if binary from checkinstall's `make install` lingers (it should)
feh --version

# note: http://unix.stackexchange.com/questions/53871/
# here `checkinstall` would have ran the local `make install`;
# so here all executables, etc are actually installed!
# at this point, do a `make uninstall` in the source folder
#  to have those removed - so can do a clean install with the new .deb!
sudo make uninstall

# check if binary still lingers (it shouldn't [No such file or directory]):
feh --version

# check the path of the .deb
readlink -f ../../feh_$VERSION-git_i386.deb
# should be in $CALL_PATH

# clean up packages:
sudo apt-get remove --purge libx11-dev libxt-dev libimlib2-dev giblib-dev libxinerama-dev libjpeg-progs libcurl4-openssl-dev && sudo apt-get autoremove --purge
# keep libcurl3, needed
# for me: libgif-dev libtiff4-dev libtiffxx0c2 libcurl4-openssl-dev
# should probably keep libtiffxx0c2 - as it's not -dev? Nvm...

# all done, go back to orig dir
cd $CALL_PATH

set +x


