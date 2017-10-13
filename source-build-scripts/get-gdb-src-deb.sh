#!/usr/bin/env bash

CALL_PATH="$PWD"
# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in/179231#comment-8308686
# copy from ~/getpath
SCRIPT_PATH="${BASH_SOURCE[0]}";
if([ -h "${SCRIPT_PATH}" ]) then
  while([ -h "${SCRIPT_PATH}" ]) do SCRIPT_PATH=`readlink "${SCRIPT_PATH}"`; done
fi
pushd . > /dev/null
cd `dirname ${SCRIPT_PATH}` > /dev/null
SCRIPT_PATH=`pwd`;
popd  > /dev/null

set -x # no need for "echo" below, as the line is output w/ -x; just comment? is skipped; > /dev/null works (though too much typing) :)
echo $SCRIPT_PATH $CALL_PATH > /dev/null

cd $SCRIPT_PATH
set +x



# http://www.gnu.org/s/gdb/current/
#~ http://electrons.psychogenic.com/modules/arms/art/6/SimulatingandDebuggingAVRprograms.php#installgdb
#~ http://www.tutorialspoint.com/gnu_debugger/installing_gdb.htm
#~ [http://www.chemie.fu-berlin.de/chemnet/use/info/gdb/gdb_toc.html#TOC151 Compiling GDB in another directory]
if [ ! -d gdbsrc ] ; then
  mkdir gdbsrc
fi

set -x
cd gdbsrc
set +x

if [ ! -d src ] ; then
  cvs -z3 -d :pserver:anoncvs@sourceware.org:/cvs/src co gdb
fi

if [ ! -d avr-gdb ] ; then
  mkdir avr-gdb
fi

set -x
cd avr-gdb
set +x

# [http://code.google.com/p/open-mc13224v/wiki/ArmSuite ArmSuite - open-mc13224v - Instructions to build the GNU compilation, linking and debugging suite for ARM. - Set of test programs for the Freescale MC13224V chipset - Google Project Hosting]
# needed
#~ sudo apt-get install texinfo #makeinfo
#~ sudo apt-get install libncurses5-dev # error: no termcap library found
#~ sudo apt-get install python-dev # WARNING: python/expat is missing or unusable; some features may be unavailable.; installs libexpat1-dev python-dev python2.7-dev
#~ sudo apt-get install flex # ada-lex.c missing and flex not available.
#~ sudo apt-get install bison # WARNING: `bison' missing on your system.; error: `YACC' has changed since the previous run: error: run `make distclean' and/or `rm ./config.cache' and start over
#~ sudo apt-get install checkinstall


# actually, don't set prefix here - on Ubuntu should be /usr/local so it can be found..
# ../src/configure --target=avr --prefix=/usr/local/AVR
../src/configure --target=avr
make

#~ $ gdbsrc/avr-gdb/gdb/gdb --version
#~ GNU gdb (GDB) 7.3.50.20110806-cvs

# DO AFTER BUILD TO GET RIGHT VERSION:

# to find dependencies for --requires for checkinstall
#~  apt-cache -f -a show gdb-avr | grep Depends
#~ Depends: libc6 (>= 2.8), libncurses5 (>= 5.6+20071006-3)

#~ sudo checkinstall -D -y \
  #~ --install=no \
  #~ --fstrans=no \
  #~ --reset-uids=yes \
  #~ --pkgname=gdb-avr \
  #~ --pkgversion=7.3 \
  #~ --pkgrelease="50.20110806-cvs" \
  #~ --arch=i386 \
  #~ --pkglicense=GPL \
  #~ --maintainer=FromSource \
  #~ --pakdir=../.. \
  #~ --requires=libc6,libncurses5,dpkg,install-info

#~ Done. The new package has been saved to (pkgrelease="7.3.50.20110806-cvs")
#~ ../../gdb-avr_7.3-7.3.50.20110806-cvs_i386.deb   # in CALL_PATH
#~ ../../gdb-avr_7.3-50.20110806-cvs_i386.deb

# to find installed files (of the vanilla Ubuntu gdb-avr package), use:
#~ dpkg --listfiles gdb-avr
# to find where the files will be installed from the new deb, use:
#~ dpkg --contents ../../gdb-avr_7.3-50.20110806-cvs_i386.deb
# automatically calls them ./usr/local/AVR/bin/avr-gdb - nice!

# now build for local PC...

set -x
cd ..
if [ ! -d loc-gdb ] ; then
  mkdir loc-gdb
fi
cd loc-gdb
set +x

../src/configure
make

#~ $ gdbsrc/loc-gdb/gdb/gdb --version
#~ GNU gdb (GDB) 7.3.50.20110806-cvs
#~  apt-cache -f -a show gdb | grep Depends
#~ Depends: libc6 (>= 2.11), libexpat1 (>= 1.95.8), libncurses5 (>= 5.5-5~), libpython2.7 (>= 2.7), libreadline6 (>= 6.0), zlib1g (>= 1:1.1.4)

#~ sudo checkinstall -D -y \
  #~ --install=no \
  #~ --fstrans=no \
  #~ --reset-uids=yes \
  #~ --pkgname=gdb \
  #~ --pkgversion=7.3 \
  #~ --pkgrelease="50.20110806-cvs" \
  #~ --arch=i386 \
  #~ --pkglicense=GPL \
  #~ --maintainer=FromSource \
  #~ --pakdir=../.. \
  #~ --requires=libc6,libncurses5,libexpat1,libpython2.7,libreadline6,zlib1g,dpkg,install-info

# note: http://unix.stackexchange.com/questions/53871/
# here `checkinstall` would have ran the local `make install`;
# so here all executables, etc are actually installed!
# at this point, do a `make uninstall` in the source folder 
#  to have those removed - so can do a clean install with the new .deb!
##make uninstall # doublecheck


#~ Done. The new package has been saved to
#~ ../../gdb_7.3-50.20110806-cvs_i386.deb

#~ dpkg --listfiles gdb
# to find where the files will be installed from the new deb, use:
#~ dpkg --contents ../../gdb_7.3-50.20110806-cvs_i386.deb

# sudo apt-get remove --purge gdb gdb-avr
# sudo dpkg -i gdb_7.3-50.20110806-cvs_i386.deb gdb-avr_7.3-50.20110806-cvs_i386.deb

# note, when these two are in the same prefix path, may get:
# # dpkg: error processing gdb-avr_7.3-50.20110806-cvs_i386.deb (--install):
# # trying to overwrite '/usr/local/lib/libiberty.a', which is also in package gdb 7.3-50.20110806-cvs
#   also for locales, and /usr/local/share/gdb/python/gdb/__init__.py....
# then force overwrite - it is the same file anyway
# sudo dpkg -i --force-overwrite gdb-avr_7.3-50.20110806-cvs_i386.deb

sudo apt-get remove --purge texinfo libncurses5-dev python-dev flex bison checkinstall && sudo apt-get autoremove --purge

set -x
cd $CALL_PATH
set +x





