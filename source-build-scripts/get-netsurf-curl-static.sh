
# tested on Ubuntu 11.04 (with bash shell)
# here we want to statically link libssl in netsurf, so that
# netsurf built on Ubuntu 11.04 (kernel 2.6) can run on say
# PartedMagic (kernel 3.x);
# but we also want to build out-of-tree ...

# following is needed for building netsurf:

# sudo apt-get install libnsgif0-dev # nope; should get from git below
# sudo apt-get install libcurl4-openssl-dev # nope - should get from git, since we want it statically linked;
# but libcurl-dev also pulls libidn11-dev; keep that:
sudo apt-get install libidn11-dev
sudo apt-get install libmng-dev # also pulls libjpeg62-dev liblcms1-dev
sudo apt-get install libpng12-dev

# for building libcurl:
sudo apt-get install libssl-dev

# for netsurf framebuffer:
sudo apt-get install libsdl1.2-dev libxcb1-dev libxcb-image0-dev libxcb-icccm1-dev libxcb-keysyms1-dev  # 25 newly installed

# for netsurf gtk:
sudo apt-get install libgtk2.0-dev # 26 newly installed,



# -------------------------------------------------
# get netsurf repo first:
git://git.netsurf-browser.org/netsurf.git netsurf-git

# go into that directory; create _BUILD folder
cd netsurf-git
mkdir _BUILD

# remember the path to _BUILD folder - we'll need it later
TP=$PWD/_BUILD

# clone all other netsurf dependencies from git as subfolders here:
git clone git://git.netsurf-browser.org/buildsystem buildsystem-git
git clone git://git.netsurf-browser.org/libwapcaplet libwapcaplet-git
git clone git://git.netsurf-browser.org/libparserutils libparserutils-git
git clone git://git.netsurf-browser.org/libhubbub libhubbub-git
git clone git://git.netsurf-browser.org/libcss libcss-git
git clone git://git.netsurf-browser.org/libdom libdom-git
git clone git://git.netsurf-browser.org/libnsbmp libnsbmp-git
git clone git://git.netsurf-browser.org/libnsgif libnsgif-git

# get the netsurf framebuffer library part too
git clone git://git.netsurf-browser.org/libnsfb libnsfb-git

# get curl from git:
git clone git://github.com/bagder/curl.git curl-git

# build all netsurf dependencies, install into _BUILD
for ix in buildsystem-git libwapcaplet-git libparserutils-git libhubbub-git libcss-git libdom-git libnsbmp-git libnsgif-git libnsfb-git; do
  cd $ix;
  make install PREFIX=$TP;
  cd .. ;
done

# -------------------------------------------------

# now build libcurl as much as "a static library" as possible
cd curl-git/

git branch -a
#~ > * master
#~ >   remotes/origin/HEAD -> origin/master
#~ >   remotes/origin/gh-pages
#~ >   remotes/origin/master
#~ >   remotes/origin/multi-always

git log --tags --simplify-by-decoration --pretty="format:%ai %d" | head -1
#~ > curl-7_30_0 # sorted - latest

# run buildconf to generate configure
./buildconf
#~ > buildconf: autoconf version 2.67 (BAD)
#~ >             Unpatched version generates broken configure script.
#~ > ...

# curl's Makefile doesn't use PREFIX - must specify
# local install dir via --prefix in ./configure;
# must run the build process once - so (curl/)lib/Makefile gets generated;
# run ./configure for static build:
./configure --disable-shared --enable-static --prefix=$TP --disable-ldap --disable-sspi
# passed
make
# passed
make install # does not have PREFIX=$TP var in Makefiles!
# installed in _BUILD/lib; also there is _BUILD/lib/pkgconfig/libcurl.pc;
# (so netsurf build can find it later)

# Curl cannot be statically linked anymore - not supported in upstream
# http://stackoverflow.com/questions/5426420/linker-warnings-while-building-application-against-mysql-connector-c-libmysqlcli
# http://stackoverflow.com/questions/9648943/static-compile-of-libcurl-apps-linux-c-missing-library
# http://curl.haxx.se/dev/howto.html
#
# we cannot actually build libssl statically into libcurl here either;
# (we might, but that requires ar packing and unpacking with `ar` on linux;
#  else: "*** Warning: Linking the shared library libcurl.la against the static library /usr/lib/libssl.a is not portable!"
# http://stackoverflow.com/questions/2157629/linking-static-libraries-to-other-static-libraries
# http://stackoverflow.com/questions/8170450/combine-static-libraries
# http://stackoverflow.com/questions/11344547/how-do-i-compile-a-static-library/16070483#16070483
# tedious, so we skip that...
# )
# see also:
# http://curl.haxx.se/mail/lib-2007-05/0155.html Curl: Re: Error with Static Linking
# http://curl.haxx.se/mail/lib-2007-12/0002.html Curl: Re: static linking SSL with libcurl for PowerPC
# http://www.mail-archive.com/curl-library@cool.haxx.se/msg11352.html Failure to compile curl 7.23.1 with static ssl on Darwin
# http://lists.gnupg.org/pipermail/gnupg-devel/2006-August.txt
# http://lists.gnu.org/archive/html/libtool/2012-02/msg00013.html Re: Single static library from multiple Libtool .a files
# http://www.adp-gmbh.ch/cpp/gcc/create_lib.html Creating a shared and static library with the gnu compiler [gcc]


# so best we can do - rerun build, and do "as much static" :) as possible:

# NB: to repeat just the linking step of curl make,
# after a build, just do:
# rm -rf lib/libcurl.la lib/.libs
# else make rebuilds all from source when makefiles change...

# edit lib/Makefile - replace LIBCURL_LIBS line;

sed -n 's/^LIBCURL_LIBS .*/LIBCURL_LIBS = -all-static -B,static -lidn -lssl -lcrypto -lz -lrt -ldl/p' lib/Makefile
sed -i 's/^LIBCURL_LIBS .*/LIBCURL_LIBS = -all-static -B,static -lidn -lssl -lcrypto -lz -lrt -ldl/' lib/Makefile

# this doesn't seem to do much - but temporarily move
# the shared *.so versions on libssl and libcrypto;
# first check if both *.a and *.so are present
# for libssl on the system
ls /usr/lib/libcrypto* | grep '.so$\|.a$'
ls /usr/lib/libssl* | grep '.so$\|.a$'

# now temporarily move - needs sudo:
# (will keep this until netsurf build is done)
sudo mv /usr/lib/libcrypto.so /usr/lib/__libcrypto.so
sudo mv /usr/lib/libssl.so /usr/lib/__libssl.so

# now repeat curl build
make
make install # does not have PREFIX=$TP var in Makefiles!

# now, the static curl library _still_ doesn't have SSL symbols:
nm -a lib/.libs/libcurl.a | grep eay
#~ >          U SSLeay
# ... but the curl executable seems statically built:
du -b src/curl
#~ > 1734135	src/curl
nm -a src/curl | grep eay
#~ > 08142270 T RAND_SSLeay
#~ > 0813b880 T RSA_PKCS1_SSLeay
# ... all are defined; and this curl works fine on other machine!

# quick check SSL static library:

cat > testssl.c <<"EOF"
// via http://savetheions.com/2010/01/16/quickly-using-openssl-in-c/
// orig: gcc -Wall -lssl -lcrypto -o testssl.exe testssl.c

#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/err.h>

SSL *sslHandle;
SSL_CTX *sslContext;

// Very basic main:
int main (int argc, char **argv)
{
  // Register the error strings for libcrypto & libssl
  SSL_load_error_strings ();
  // Register the available ciphers and digests
  SSL_library_init ();

  sslContext = SSL_CTX_new (SSLv23_client_method ());
  printf ("sslContext 0x%p\n", (void*)sslContext);
  if (sslContext == NULL)
    ERR_print_errors_fp (stderr);

  SSL_CTX_free (sslContext);
  return 0;
}

EOF

# test build using static libssl (system) libraries:
gcc -Wall -Wl,--trace -static -o testssl.exe testssl.c /usr/lib/libcrypto.a /usr/lib/libssl.a /usr/lib/libcrypto.a -lz -ldl 2>&1
# note, here we get:
# (.text+0x6c6): warning: Using 'dlopen' in statically linked applications requires at runtime the shared libraries from the glibc version used for linking
# but executable seems to work fine (also on other machine)
./testssl.exe


# quick check CURL static library:

cat << EOF > testcurl.c
#include <curl/curl.h>
# via http://stackoverflow.com/questions/9648943/static-compile-of-libcurl-apps-linux-c-missing-library
int main() {
printf("%s\n", curl_version());
return 0;
}
EOF

# test build using static libcurl (built) libraries:

gcc -Wl,--trace testcurl.c -static-libgcc $($TP/bin/curl-config --static-libs --cflags) -ldl -o testcurl.exe
./testcurl.exe

# we should be done with libcurl now; go back up:
cd ..


# -------------------------------------------------
# for the netsurf makefile:
# use PKG_CONFIG_PATH to cheat pkgconfig (which returns linker switches for build)
# for some reason, it uses `cc` on Ubuntu 11.04 as CC? set also CC=gcc
# set Q= VQ= for verbose: to see build commands in stdout
# also possible problems:
# http://stackoverflow.com/questions/9449241/where-is-path-max-defined-in-linux # /usr/include/limits.h
# http://stackoverflow.com/questions/7950259/restrict-qualifier-compilation-error

# here we need to change Makefile.config for static build;
# (netsurf Makefile is not adjusted to override of
# variables from command line)

cp Makefile.config.example Makefile.config
echo "
CFLAGS := -static-libgcc
LDFLAGS := -all-static -static-libgcc -lidn /usr/lib/libcrypto.a /usr/lib/libssl.a $TP/lib/libcurl.a -ldl -lz -lrt
\$(eval \$(info A: CFLAGS here is \$(CFLAGS)))
\$(eval \$(info A: LDFLAGS here is \$(LDFLAGS)))
" >> Makefile.config

# build/make the gtk version
PKG_CONFIG_PATH=$TP/lib/pkgconfig make PREFIX=$TP TARGET=gtk
PKG_CONFIG_PATH=$TP/lib/pkgconfig make install PREFIX=$TP TARGET=gtk

# rename the gtk installed version (locally named nsgtk)
mv $TP/bin/netsurf $TP/bin/netsurf-gtk

# build/make the framebuffer version
PKG_CONFIG_PATH=$TP/lib/pkgconfig make PREFIX=$TP TARGET=framebuffer
PKG_CONFIG_PATH=$TP/lib/pkgconfig make install PREFIX=$TP TARGET=framebuffer

# rename the framebuffer installed version (locally named nsfb)
mv $TP/bin/netsurf $TP/bin/netsurf-fb


# -----------------------------------------------
# should be done - now can bring back the system shared libs:

sudo mv /usr/lib/__libcrypto.so /usr/lib/libcrypto.so
sudo mv /usr/lib/__libssl.so /usr/lib/libssl.so

# create a shell runner script for gtk version

cat > $TP/run-netsurf-gtk.sh <<"EOF"
#!/usr/bin/env bash

# this script is in _BUILD / netsurf dir;

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "MYDIR: $MYDIR"

# use netsurf -v for verbose log

NETSURFRES="$MYDIR/share/netsurf" nice -n 10 "$MYDIR/bin"/netsurf-gtk

# NOTE: /etc/ssl/certs/ca-certificates.crt may be missing on system;
# in which case netsurf won't be able to look up https ;
# in that case, just copy some system's ca-certificates.crt to
# /etc/ssl/certs (running update-ca-certificates is not needed)

EOF


# notes current netsurf gtk:
# has a problem with links, if not prepended with http or www (or file:///)...
# Global history items always open in new window (no way to make it tab, but OK, it's fast); and there is no "GO" button, if copypasting with mouse (have to click Enter on virtual keyboard to effectuate links); else as expected (without javascript and plugins). and the history dropdown when typing in address bar seems not to work...

# notes about netsurf framebuffer:

# # switch into a single-user terminal with Ctrl-Alt-F2
# # then do:
#~ sudo modprobe vesafb      # in Ctrl-Alt-F2 terminal
#~ #sudo modprobe -r vesafb   # couldn't -r in Ctrl-Alt-F2 terminal
#~ sudo modprobe vga16fb     # the last
# #(and when I loaded the last, it dumped some data to terminal; that dump doesn't happen if I load from gnome - but still works)
# # then check drivers:
#~ lsmod | grep fb
#~ > vga16fb                21674  0
#~ > vgastate               16865  1 vga16fb
#~ > vesafb                 13476  0
#
# # test framebuffer with the `fbi` program (apt-get install it):
# sudo fbi /path/image.png
# sudo fbi /path/image.png -d /dev/fb0
#
# # then, for netsurf-fb, in single user terminal, call:
# sudo ./nsfb -v -f linux -b 32     # also -b 8, -b 16 - but not -b 24
# # test netsurf w/ gdb (src has script):
# # allows to see NSFB_SURFACE_LINUX, NSFB_SURFACE_RAM ...
# sudo PREFIX=$TB ./test-netsurf --gdb -f /dev/fb0 -b 8 www.yahoo.com

# like this, there are problems with keyboard presses, and mouse
# tried also with virtual framebuffer (xvfb), but apparently it doesn't mix well with real FB driver loaded; maybe could use VNC too?

# see also:
# http://blog.gmane.org/gmane.comp.web.netsurf.user/month=20101101 "LibNSFB depends.."
# http://meadowstalk.com/post/drawing-to-the-linux-framebuffer
# http://superuser.com/questions/143898/framebuffer-not-available-how-to-install-the-device-dev-fb-0-on-ubuntu
# http://squeezehead.com/b/2010/10/disabling-the-ubuntu-framebuff.html
# http://anarsoul.blogspot.dk/2011/04/netsurf-on-zipit-z2.html
# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=684028#5 #684028 - /usr/bin/netsurf-fb: Mouse initialisation failed in tty - Debian Bug report logs





