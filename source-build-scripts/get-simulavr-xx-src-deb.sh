#~ l="http://www.mail-archive.com/simulavr-devel@nongnu.org/msg01218.html" t="[Simulavr-devel] Simulavr in GIT. HOWTO." d="Thu Aug 04 2011 02:52:32 GMT+0200 (CEST)"
#~ $ # note: URLs can be taken from http://git.savannah.gnu.org/cgit/simulavr.git/


# alt git clone git://git.savannah.nongnu.org/simulavr.git
git clone http://git.sv.gnu.org/r/simulavr.git
cd simulavr/
sudo apt-get install libtool
./bootstrap # needs libtool
#~ ./configure # libbfd fail; binutils-avr already latest version
#~ ./configure --with-bfd=/usr/i686-linux-gnu/avr/ # Could not locate libiberty.so/libiberty.a
sudo apt-get install binutils-dev # with this, passes
#~ make

#hwstack.cpp:274:11: error: ‘stderr’ was not declared in this scope
#l="http://lists.gnu.org/archive/html/simulavr-devel/2011-04/msg00008.html" t="[Simulavr-devel] [bug #33148] Modifications needed in to compile last si"
#irqsystem.cpp:294:13: error: 'stderr' was not declared in this scope
#To avoid it, I had to add the following includes to irqsystem.cpp:

sed -n 's!using\(.*\)!#include <typeinfo>  // first added line\n#include <stdio.h>   // second added line\nusing\1!gp' src/hwstack.cpp
sed -i 's!using\(.*\)!#include <typeinfo>  // first added line\n#include <stdio.h>   // second added line\nusing\1!' src/hwstack.cpp

#~ make # `makeinfo' is missing on your system.
#~ ./configure --with-bfd=/usr/i686-linux-gnu/avr/ --enable-doxygen-doc=no --disable-doxygen-html --enable-verilog


# doesn't matter, insists on makeinfo = so
sudo apt-get install texinfo
# make passes now

# also python for make check; then needs:
sudo apt-get install swig
# ; then Python.h: No such file or directory -
sudo apt-get install python-dev
./configure --with-bfd=/usr/i686-linux-gnu/avr/ --enable-doxygen-doc=no --disable-doxygen-html --enable-verilog --enable-python=/usr/bin/python
# ( and DO NOT ln -s /usr/include/python2.7/Python.h src/python/); instead:
#~ CPLUS_INCLUDE_PATH="/usr/include/python2.7/" make


# and then, some trouble with hwstack.h: AvrDevice & m_core needs to be static; but if so, usual compilation fails
# hwstack.h AvrDevice & m_core; -> AvrDevice * m_core; seems to pass?
# sed -n 's/AvrDevice & m_core/AvrDevice * m_core/gp' src/hwstack.h
# sed -i 's/AvrDevice & m_core/AvrDevice * m_core/' src/hwstack.h
# naah - fail usual compilation again
#~ pysimulavr_wrap.cpp:32586:37:
#~ if (arg1) (arg1)->m_ThreadList = ThreadList(arg2->m_core); //*arg2;

# well, the problem is:
# http://stackoverflow.com/questions/1832704/default-assignment-operator-in-inner-class-with-reference-members

# comment out that whole bloody function - now make passes:
sed -i "32564s,^,/* ,;32591s,$, */," src/pysimulavr_wrap.cpp
sed -i "47424s,^,/* ,;47424s,$, */," src/pysimulavr_wrap.cpp

CPLUS_INCLUDE_PATH="/usr/include/python2.7/" make

# FINALLY make passed...

#~ make check
#File "/path/to/src/simulavr/src/pysimulavr.py", line 1080, in HWStack
#AttributeError: 'module' object has no attribute 'HWStack_m_ThreadList_set

# sed -i "1080s,^,/* ,;1080s,$, */," src/pysimulavr.py  # nope, not c comments, python ones
sed -i "1080s,^,# ," src/pysimulavr.py
sed -i "1082s-get, _pysimulavr-get) #, _pysimulavr-" src/pysimulavr.py

make check

# make check seems to pass now..
# Ran 13850 tests in 60.710 seconds [228.134 tests/second].
#  Number of Passing Tests: 13850
#  Number of Failing Tests: 0

./src/simulavr --version
#~ SimulAVR 1.0rc0
#~ See documentation for copyright and distribution terms

#~ # old
#~ $ simulavr --version
#~ simulavr version 0.1.2.2
#~ Copyright 2001, 2002, 2003, 2004  Theodore A. Roth.
#~ $ apt-show-versions simulavr
#~ simulavr/natty uptodate 0.1.2.2-6.1ubuntu1

# to find dependencies for --requires for checkinstall
#~ apt-cache -f -a show simulavr | grep Depends
#~ Depends: libc6 (>= 2.7), libncurses5 (>= 5.6+20071006-3), dpkg (>= 1.15.4) | install-info

sudo apt-get install checkinstall

sudo checkinstall -D -y \
  --install=no \
  --fstrans=no \
  --reset-uids=yes \
  --pkgname=simulavr \
  --pkgversion=1.0 \
  --pkgrelease="git-2011.08.04rc0" \
  --arch=i386 \
  --pkglicense=GPL \
  --maintainer=FromSource \
  --pakdir=../.. \
  --requires=libc6,libncurses5,dpkg,install-info
# Done. The new package has been saved to ../../simulavr_1.0-git-2011.08.04rc0_i386.deb

# note: http://unix.stackexchange.com/questions/53871/
# here `checkinstall` would have ran the local `make install`;
# so here all executables, etc are actually installed!
# at this point, do a `make uninstall` in the source folder 
#  to have those removed - so can do a clean install with the new .deb!
## make uninstall # doublecheck



# to find installed files (of the vanilla Ubuntu ngspice package), use:
#~ dpkg --listfiles simulavr
# to find where the files will be installed from the new deb, use:
#~ dpkg --contents ../../simulavr_1.0-git-2011.08.04rc0_i386.deb

#~ Supported devices (new):
#~ at90can128
#~ at90can32
#~ at90can64
#~ at90s4433
#~ at90s8515
#~ atmega128  *
#~ atmega1284a
#~ atmega16   *
#~ atmega164a
#~ atmega168
#~ atmega32
#~ atmega324a
#~ atmega328
#~ atmega48
#~ atmega644a
#~ atmega8    *
#~ atmega88
#~ attiny2313

#~ the old:
  #~ at90s1200
  #~ at90s2313
  #~ at90s4414
  #~ at90s8515
  #~ atmega8   *
  #~ atmega16  *
  #~ atmega103
  #~ atmega128 *
  #~ at43usb351
  #~ at43usb353
  #~ at43usb355
  #~ at43usb320
  #~ at43usb325
  #~ at43usb326


# no atmega1280/ATmega2560 - but there is 1284a? probably similar to 1280, but with less pins..

# also, no simulavr-disp in this version (which is actually simulavrxx in oldspeak; as the old simulavr is discontinued):

#~ l="http://lists.gnu.org/archive/html/simulavr-devel/2005-09/msg00003.html" t="[Simulavr-devel] simulavr-disp with simulavrxx" d="Thu Aug 04 2011 07:19:57 GMT+0200 (CEST)"
#~ The original simulavr had simulavr-disp to display the contents of IO-registers. Can I get this information from simulavrxx too? This is probably possible from the python interface, but I didn't find out, which methods to use and probably I'd need to single step?

#~ l="http://www.mikrocontroller.net/topic/24350" t="AVR Programme unter Linux Debuggen - Mikrocontroller.net" d="Thu Aug 04 2011 07:27:05 GMT+0200 (CEST)"
#~ Simulavrxx seems to be better when it comes to attaching external virtual hardware, but I miss the simulavr-disp tool, and the 'info io_registers' GDB command on this one.

# nice tutorial (.de): http://www.mikrocontroller.net/articles/AVR-Simulation#Starten_des_GDB (0.1.2.X)

#~ * so will probably have to build for atmega128, to be able to observe in both...

# cleanup libraries needed for this build:
sudo apt-get remove --purge libtool binutils-dev texinfo swig python-dev checkinstall && sudo apt-get autoremove --purge


