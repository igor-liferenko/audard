#!/usr/bin/env bash

# the below tried on ubuntu lucid, jul 2012

# source build instructions:
# http://podofo.sourceforge.net/download.html

  # svn co https://podofo.svn.sourceforge.net/svnroot/podofo/podofo/trunk podofo
  # svn co https://podofo.svn.sourceforge.net/svnroot/podofo podofo

#svn co https://podofo.svn.sourceforge.net/svnroot/podofo podofo_svn # too big, with all the branches

mkdir podofo_svn
svn co https://podofo.svn.sourceforge.net/svnroot/podofo/podofo/trunk podofo_svn/podofo_trunk
svn co https://podofo.svn.sourceforge.net/svnroot/podofo/podofobrowser/trunk/ podofo_svn/podofobrowser_trunk
# this is old, but pull anyways:
svn co https://podofo.svn.sourceforge.net/svnroot/podofo/example_helloworld podofo_svn/example_helloworld

cd podofo_svn
mkdir podofo-build
cd podofo-build

# first report cmake:
#~ Could NOT find LIBIDN  (missing:  LIBIDN_LIBRARY LIBIDN_INCLUDE_DIR)  OpenSSL's libCrypto or libidn not found. AES-256 Encryption support will be disabled
#~ Could NOT find TIFF  (missing:  TIFF_LIBRARY TIFF_INCLUDE_DIR) Libtiff not found. TIFF support will be disabled
#~ Ensure you cppunit installed version is at least 1.12.0 Cppunit not found. No unit tests will be built.
#~ -- Could NOT find Lua50  (missing:  LUA_LIBRARIES LUA_INCLUDE_DIR) -- Could NOT find Lua  (missing:  LUA_LIBRARIES LUA_INCLUDE_DIR) Lua not found - PoDoFoImpose and PoDoFoColor will be built without Lua support Building multithreaded version of PoDoFo.

sudo apt-get install libidn11-dev libtiff4-dev liblua5.1-dev
sudo apt-get install libcppunit-dev # cppunit no longer exist

cmake ../podofo_trunk
make
#~ su
#~ make install

# builds ok - list executables:
find .. -type f -executable -not -iwholename '*.svn*'
#~ ../podofo-build/examples/helloworld/helloworld
#~ ../podofo-build/examples/helloworld-base14/helloworld-base14
#~ ../podofo-build/test/VariantTest/VariantTest
#~ ...
#~ ../podofo-build/CMakeFiles/TestEndianess.bin
#~ ../podofo-build/tools/podofoimgextract/podofoimgextract
#~ ../podofo-build/tools/podofoencrypt/podofoencrypt
#~ ...
#~ $ ls -la ../podofo-build/tools/podofoimgextract/podofoimgextract
#~ -rwxr-xr-x 1 USER USER 2139400 2012-07-03 21:53 ../podofo-build/tools/podofoimgextract/podofoimgextract
#~ $ ls -la podofo_deb/usr/bin/podofoimgextract
#~ -rwxr-xr-x 1 USER USER 71236 2012-04-02 23:07 podofo_deb/usr/bin/podofoimgextract
# so these are statically built (as cmake notes!)
find .. -name '*.deb' -or -name '*.so' -or -name '*.a'
# ../podofo-build/src/libpodofo.a

# still in podofo-build dir:
#~ make -f debian/Makefile preinstall # don't do much
# ...
# -- Build files have been written to: ./podofo-build ?? not much otherwise..


#~ $ cmake -P cmake_install.cmake
#~ -- Install configuration: ""
#~ CMake Error at src/cmake_install.cmake:36 (FILE):
  #~ file cannot create directory: /usr/local/include/podofo.  Maybe need
  #~ administrative privileges.
#~ Call Stack (most recent call first):
  #~ cmake_install.cmake:37 (INCLUDE)

#~ $ cmake -DCMAKE_INSTALL_LOCAL_ONLY=1 -P cmake_install.cmake
#~ -- Install configuration: ""

# still in podofo-build dir:

# pkgversion=0.9.1 - read tag manually from svn;
# pkgrelease="svn-1505" from `svn up`
checkinstall -D --install=no --pkgname=libpodofo-utils --pkgversion=0.9.1 --pkgrelease="svn-1505" --maintainer=test@test.com --strip=no --stripso=no --addso=yes make

# note: http://unix.stackexchange.com/questions/53871/
# here `checkinstall` would have ran the local `make install`;
# so here all executables, etc are actually installed!
# at this point, do a `make uninstall` in the source folder
#  to have those removed - so can do a clean install with the new .deb!
## make uninstall # doublecheck

# !! debug: INSTW_EXCLUDE=/dev,/path/to/podofo_svn/podofo-build <- the same dir!! ,/proc,/tmp,/var/tmp,

# $ grep 'newfile ' `which checkinstall`
#	grep '^/home' ${TMP_DIR}/newfile > /${TMP_DIR}/unwanted

# after a make clean:
  # You probably don't want them to be included in the package,
  # especially if they are inside your home directory.
  # Do you want me to list them?  [n]: y -
# that shows both .o files and executables! so don't exclude! and then:
# "Building file list...OK"
# to find where the files will be installed from the new deb, use:
#~ dpkg --contents libpodofo-utils_0.9.1-svn-1505_i386.deb | less
# but still not quite right - includes also .o; and paths are not adapted!
## -rwxr-xr-x user/user 2306752 2012-07-03 23:19 ./path/to/podofo_svn/podofo-build/test/CreationTest/CreationTest

# nevermind - deb a bit too problematic for now..

# still in podofo-build; now go up - to build podofobrowser!
cd ..

mkdir podofobrowser-build
cd podofobrowser-build

# first report cmake:
# Qt qmake not found! then Could NOT find QtCore header

sudo apt-get install qt4-qmake libqt4-dev

cmake ../podofobrowser_trunk
# note:
# +++PoDoFo not found... building private copy
# ...
# Building static PoDoFo library
# +++Done setting up private PoDoFo copy

make
#~ su
#~ make install
#~ $ du -b ./src/podofobrowser
#~ 2335595	./src/podofobrowser

# go back
cd ..

# now in podofo_svn:

mkdir libpodofo-utils-lucid

# copy executable tools
set -x; for ix in $(find ./podofo-build/tools -type f -executable -not -iwholename '*.svn*'); do cp $ix ./libpodofo-utils-lucid/ ; done ; set +x

#~ $ for ix in $(find . -name '*.a'); do du -b $ix; done
#~ 5240388	./podofo-build/src/libpodofo.a
#~ 4929970	./podofobrowser-build/externals/required_libpodofo/src/libpodofo.a

cp ./podofo-build/src/libpodofo.a ./libpodofo-utils-lucid/

cp ./podofobrowser-build/src/podofobrowser ./libpodofo-utils-lucid/

mkdir ./libpodofo-utils-lucid/ext
set -x; for ix in $(find ./podofo-build/examples -type f -executable -not -iwholename '*.svn*'); do cp $ix ./libpodofo-utils-lucid/ext ; done ; set +x
set -x; for ix in $(find ./podofo-build/test -type f -executable -not -iwholename '*.svn*'); do cp $ix ./libpodofo-utils-lucid/ext ; done ; set +x


# done - remove extra installed packages:

sudo apt-get remove --purge libidn11-dev libtiff4-dev liblua5.1-dev libcppunit-dev  qt4-qmake libqt4-dev && sudo apt-get autoremove --purge

# pdfbrowser seems to work on my lucid even without these packages;
# podofocolor seems to work fine with lua, too...

# just pack the libpodofo-utils-lucid folder now

tar cjvf libpodofo-utils-lucid.tar.bz2 libpodofo-utils-lucid

#~ $ du -b libpodofo-utils-lucid.tar.bz2
#~ 19269320	libpodofo-utils-lucid.tar.bz2


