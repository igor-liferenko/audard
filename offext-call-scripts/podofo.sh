#!/usr/bin/env bash

# call with: ./podofo.sh podofocolor --help
# (below for lucid install notes)


OLDDIR=$PWD
echo "${BASH_SOURCE}[0]" 1>&2
echo "${BASH_SOURCE[0]}" 1>&2
SOURCE="${BASH_SOURCE[0]}"
echo $SOURCE
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#cd $DIR
echo $DIR, $OLDDIR

PATH=$DIR/usr/bin:$DIR/usr/sbin:$DIR/var/lib/ghostscript:$PATH
LD_PRELOAD_PATH=$DIR/usr/lib:$DIR/usr/lib/i386-linux-gnu:$LD_PRELOAD_PATH

#~ which gs
# there's many of these, with same prefix
# show them all via compgen:
ALLEXCS=$(compgen -c podofo)
# doing which for all worls - but is too much:
#~ for ix in $ALLEXCS ; do
  #~ which $ix;
#~ done
# just dump the filenames
echo $ALLEXCS


L1=$DIR/usr/lib/i386-linux-gnu/libstdc++.so.6
L2=$DIR/usr/lib/libpodofo.so.0.9.1
L3=$DIR/usr/lib/i386-linux-gnu/libjpeg.so.8
# due to path setting, no need to prefix
# $DIR/usr/bin/gs - gs is autofound as per changed PATH
#~ LD_PRELOAD=$L1:$L2:$L3 GS_LIB=$D4 gs $@
# since have to specify one of many programs, just go directly with args!
LD_PRELOAD=$L1:$L2:$L3 $@
ret=$?

#cd $OLDDIR

exit $ret




# off-tree (extern/custom folder) install (lucid)

#https://launchpad.net/~n-muench/+archive/calibre/+packages
#https://launchpad.net/~n-muench/+archive/calibre/+files/libpodofo0.9.1_0.9.1-0%7Eppa7_i386.deb
#needs libjpeg8 (>= 8c)
#http://packages.ubuntu.com/oneiric/i386/libjpeg8/download
#http://se.archive.ubuntu.com/ubuntu/pool/main/libj/libjpeg8/libjpeg8_8c-2ubuntu2_i386.deb
#libstdc++6 (>= 4.6) - I've got max libstdc++6-4.4  .. folder :/
# gcc-4.6-base (= 4.6.1-9ubuntu3) - this is installable on lucid..

#~ mkdir podofo
#~ cd podofo
#~ wget http://se.archive.ubuntu.com/ubuntu/pool/main/g/gcc-4.6/libstdc++6_4.6.1-9ubuntu3_i386.deb
#~ wget http://se.archive.ubuntu.com/ubuntu/pool/main/g/gcc-4.6/gcc-4.6-base_4.6.1-9ubuntu3_i386.deb
#~ wget http://se.archive.ubuntu.com/ubuntu/pool/main/libj/libjpeg8/libjpeg8_8c-2ubuntu2_i386.deb
#~ wget https://launchpad.net/~n-muench/+archive/calibre/+files/libpodofo0.9.1_0.9.1-0%7Eppa7_i386.deb # libpodofo0.9.1_0.9.1-0~ppa7_i386.deb, ok
#~ wget https://launchpad.net/~n-muench/+archive/calibre/+files/libpodofo-utils_0.9.1-0%7Eppa7_i386.deb

#~ for ix in *.deb; do dpkg -x $ix .; done

# for podofobrowser - no debs available;
# the winodze version can run under wine
# http://downloads.sourceforge.net/project/podofo/podofobrowser/0.5/podofobrowser-0.5-r1-win32-bin.zip?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fpodofo%2Ffiles%2Fpodofobrowser%2F0.5%2F&ts=1341341080&use_mirror=heanet

# to analyze colors, probably have to build own script based on this:
#~ http://podofo.svn.sourceforge.net/viewvc/podofo/podofo/trunk/tools/podofocolor/example.lua?revision=1383

# unfortunately, the debs above are not compiled with lua:

 	#ifdef PODOFO_HAVE_LUA
 	#~ std::cerr < < "\t[converter] can be one of: dummy|grayscale|lua [planfile]\n";
 	#else
 	#~ std::cerr < < "\t[converter] can be one of: dummy|grayscale\n";
 	#endif // PODOFO_HAVE_LUA

# and the debs give:
#~ Usage: podofocolor [converter] [inputfile] [outpufile]
	#~ [converter] can be one of: dummy|grayscale

