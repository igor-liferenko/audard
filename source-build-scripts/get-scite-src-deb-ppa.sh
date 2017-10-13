
# http://ubuntuforums.org/showthread.php?t=49216&highlight=dh_make
# https://wiki.ubuntu.com/PackagingGuide/Python
# https://help.launchpad.net/Packaging/PPA/BuildingASourcePackage

# if needed
# sudo apt-get install mercurial

# actually, just get the Ubuntu bazaar branch for scite in Launchpad
# unfortunately, it just contains the debian dir - so no good.. for everything
#~ bzr branch lp:~mvo/scite/debian-sid

mkdir scite-2.22-ppa
cd scite-2.22-ppa

# get sources to act as orig
# wget http://sourceforge.net/projects/scintilla/files/SciTE/2.22/scite222.tgz/download
# wget http://sourceforge.net/projects/scintilla/files/scintilla/2.22/scintilla222.tgz/download

# instead of grabbing source tgzs, we will grab release by tag, 
# and then pack that

#~ hg clone -r rel-2-22 http://scintilla.hg.sourceforge.net:8000/hgroot/scintilla/scintilla
#~ hg clone -r rel-2-22 http://scintilla.hg.sourceforge.net:8000/hgroot/scintilla/scite

hg clone http://scintilla.hg.sourceforge.net:8000/hgroot/scintilla/scintilla 
hg clone http://scintilla.hg.sourceforge.net:8000/hgroot/scintilla/scite 

# dpkg-source: error: cannot represent change to .. - binary file contents changed
rm scite/.hg/dirstate
rm scintilla/.hg/dirstate

# don't necesarilly have to apply patches here, 
# can build once direct, then apply patch.. 

dh_make -b --createorig # creates ./debian; ../scite-2.22-ppa.orig/
#~ cd debian
#~ rm *ex *EX
#~ cd ..
#~ # this copied from debian/control of scite 2.03
#~ cat > debian/control <<EOF
#~ Source: scite
#~ Section: editors
#~ Priority: optional
#~ Maintainer: Michael Vogt <mvo@debian.org>
#~ Build-Depends: debhelper (>= 5.0.0), libgtk2.0-dev, libglib2.0-dev, dpatch
#~ Standards-Version: 3.7.2
#~ Package: scite
#~ Architecture: any
#~ Depends: ${shlibs:Depends}, ${misc:Depends}
#~ Description: Lightweight GTK-based Programming Editor
 #~ GTK-based Programming with syntax highlighting support for
 #~ many languages. Also supports folding sections, exporting 
 #~ highlighted text into colored HTML and RTF. 
 #~ .
#~ Homepage: http://scintilla.org/SciTE.html
#~ EOF


# actually, grab the deb setup from Ubuntu ppa
#~ rm -rf debian
#~ rm -rf debian/*ex debian/*EX debian/dirs debian/docs
#~ rm -rf debian/*ex debian/*EX 
bzr branch lp:~mvo/scite/debian-sid
#~ mv debian-sid/debian . 
cp debian-sid/debian/rules debian/ # this needed for correct build!
cp debian-sid/debian/control debian/
cp debian-sid/debian/menu debian/
cp debian-sid/debian/*xpm debian/
cp debian-sid/debian/*desktop debian/
cp debian-sid/debian/watch debian/
rm -rf debian-sid

#~ dpgk-buildpackage # if I just want to build the deb.. 
# instead of that, for binary deb, can do:
debuild -b
# but:
#~ dpkg-buildpackage: binary only upload (no source included) ... 
#~ debsign: gpg error occurred!  Aborting....
# still -- can run: sudo dpkg -i ../scite_2.22-ppa-1_i386.deb from this location after debuild -b finished.. 

# but for upload to ppa w source: "brand new package with no existing version in Ubuntu's repositories (will be uploaded with the .orig.tar.gz file)"
# sudo apt-get install devscripts # if you need debuild
# sudo apt-get install dpatch # 
# note the process could end with "debsign: gpg error occurred!"/"clearsign failed: secret key not available"
# if do not have a key, https://launchpad.net/+help/openpgp-keys.html#publish
# if do have, maybe https://answers.launchpad.net/ubuntu/+question/47357
debuild -S -sa #-k<GPG_keyid>

# finally when have the source signed, can be uploaded with dput.. 








# easier, go default? Don't need it.. 

#~ wget http://downloads.sourceforge.net/project/scintilla/SciTE/2.22/scite222.tgz
#~ wget http://downloads.sourceforge.net/project/scintilla/scintilla/2.22/scintilla222.tgz

#~ # rename according to deb
#~ mv scite222.tgz scite-2.22.tar.gz
#~ mv scintilla222.tgz scintilla-2.22.tar.gz

#~ # unpack
#~ tar xzvf scite-2.22.tar.gz
#~ tar xzvf scintilla-2.22.tar.gz

#~ # rename so unpacked folders conform to deb
#~ mv scintilla scintilla-2.22
#~ mv scite scite-2.22

