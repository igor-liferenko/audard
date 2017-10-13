
# tested on Ubuntu 11.04 (with bash shell)
# these were needed for me:
# sudo apt-get install git-buildpackage
# sudo apt-get install dh-autoreconf

LOCDIR=remake-git

git clone git://github.com/rocky/remake.git $LOCDIR
cd $LOCDIR

set -x

# list all tags
git tag

# when building for debian, there seems to be no problem with
# http://git.yoctoproject.org/cgit.cgi/poky/plain/meta/recipes-devtools/remake/remake/version-remake.texi.patch ??
git checkout debian

# list all branches - local and remote
git branch -a
# * debian
#   master
#   remotes/origin/HEAD -> origin/master
#   remotes/origin/debian
#   remotes/origin/make-master
#   remotes/origin/make-releases
#   remotes/origin/master
#   remotes/origin/master-dfsg
#   remotes/origin/remake-3.81
#   remotes/origin/remake-3.82

# [http://ubuntuforums.org/showthread.php?t=1876417 [SOLVED] building using git-buildpackage. creating orig.tar.gz help]
# master-dfsg must show in this list - else later we cannot build!
# simply check it out once, and then check out debian again

git checkout master-dfsg
git checkout debian

git branch -a
# * debian
#   master
#   master-dfsg
#   remotes/origin/HEAD -> origin/master
#   remotes/origin/debian
#   remotes/origin/make-master
#   remotes/origin/make-releases
#   remotes/origin/master
#   remotes/origin/master-dfsg
#   remotes/origin/remake-3.81
#   remotes/origin/remake-3.82

# for Ubuntu 11.04:
# dpkg-checkbuilddeps: Unmet build dependencies: debhelper (>= 9)
sed -i 's/debhelper (>= 9)/debhelper (>= 8)/' ./debian/control

autoreconf -i
# ./configure --enable-maintainer-mode # ?? Not needed? debuild will eventually run it?

# [http://honk.sigxcpu.org/projects/git-buildpackage/manual-html/gbp.intro.html Building Debian Packages with git-buildpackage: Introduction]
git-buildpackage --git-ignore-new

set +x

# out here, git-buildpackage would probably fail at:
# `debuild -i\.git/ -I.git -> which calls:
#  dpkg-source -i.git/ -I.git -b remake-git -> fails at dir, coz we're in it
# if so - can continue with:

echo "If build failed with: "
echo "  `error: dpkg-source -i.git/ -I.git -b remake-git gave error exit status 2`"
echo "  `gbp:error: debuild -i\\.git/ -I.git returned 29`"
echo "... then try the following command - to build only the binary:"
echo "cd $LOCDIR ; debuild -i\\.git/ -I.git -b"
echo "(after that, look for $LOCDIR/../remake*.deb  )"


#~ debuild -i\.git/ -I.git -b # only binary - passes

# should get:
# dpkg-deb: building package `remake' in `../remake_3.82+dbg0.9+dfsg-1_i386.deb'.

# also expect this:
## gpg: skipped "Yaroslav Halchenko <debian@onerussian.com>": secret key not available
## debsign: gpg error occurred!  Aborting....
## running debsign failed
# not a problem - for local use, package still installs


# ... otherwise .deb is created - Ubuntu 11.04:

## $ sudo dpkg -i remake_3.82+dbg0.9+dfsg-1_i386.deb
## Preparing to replace remake 3.81+dbg0.2#dfsg.1-1 (using remake_3.82+dbg0.9+dfsg-1_i386.deb) ...

## $ remake --version
## GNU Make 3.82+dbg0.9

## $ apt-show-versions remake
## remake 3.82+dbg0.9+dfsg-1 newer than version in archive



