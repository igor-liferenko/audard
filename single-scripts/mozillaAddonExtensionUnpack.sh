#!/usr/bin/env bash

# mozillaAddonExtensionUnpack.sh
# notes re: modifying mozilla addons packed in jars.

# example:
# ./mozillaAddonExtensionUnpack.sh /path/to/profile/extensions/{1c530060-b0ae-11d9-9669-0800200c9a66} ~/Desktop/unpack_addon
function usage() {
  echo "Usage:"
  echo "$0 </full/path/to/extensions/extension_dir> </full/path/to/unpack_dir>"
}

EXTEPATH="$1"
DESTPATH="$2"

CALLDIR=$(pwd) #THISDIR, ORIGDIR..
THISSCRIPTDIR=$(dirname $(readlink -f "$0"))

#~ echo -e "$CALLDIR\n$THISSCRIPTDIR"

# http://stackoverflow.com/questions/2172352/in-bash-how-can-i-check-if
if [ -z "$EXTEPATH" -o -z "$DESTPATH" ] ; then
  usage
  exit 0
fi

# we try to look for the .jar inside the extension dir
# NOTE that there may be multiple .jars (e.g. imageshack.jar + uploadlibrary.jar)
# but here we assume there's only one!

# references to the originally installed .jar file
JARFPATH="$(find "$EXTEPATH" -name *.jar)"
JARDIR="$(dirname "$JARFPATH")"             # most likely, "chrome" - but NOT always
JARFNAME="$(basename "$JARFPATH")"

echo -e "Found:\n$JARDIR\n$JARFNAME\n"


# check if destpath exists;
# if not, create it? just direct with -p?
#~ mkdir -p "$DESTPATH"
# nah - will do that through copy:...
# unfortunately, since we rename directory as a file,
# complications arise if the script is called twice in a row!
# so make sure it is empty
if [ -d "$DESTPATH" ]; then
  echo "Cleaning $DESTPATH"
  rm -rf "$DESTPATH"/*
else
  echo "Making new $DESTPATH"
  mkdir -p "$DESTPATH"
fi
echo

# first copy the installed plugin elsewhere
cp -a "$EXTEPATH" "$DESTPATH" # ~/Desktop/addon_extension.orig


# find reference to copied .jar file
CJARFPATH="$(find "$DESTPATH" -name *.jar)"
CJARDIR="$(dirname "$CJARFPATH")"           # most likely, "chrome" - but NOT always
#~ CJARFNAME="$(basename "$CJARFPATH")"     # same as JARFNAME
JARFNBASE=${JARFNAME%%.jar}

echo -e "Found:\n$CJARDIR\n$CJARFNAME\n"


# cd to the copied chrome dir, unpack and backup jar
cd "$CJARDIR" #~ cd ~/Desktop/addon_extension.orig/chrome
echo "Inside $(readlink -f "$CJARDIR")"


# rename jar file, so we can make dir of same name
CJARFNMOVED="$JARFNAME.origj"
mv "$JARFNAME" "$CJARFNMOVED" #~ mv addon_extension.jar addon_extension.jar.origj
echo "Moved $JARFNAME to $CJARFNMOVED"

# make directory for unpack, same (originally) name as jar
mkdir "$JARFNAME" #addon_extension.jar

# unzip unzips only into current directory
cd "$JARFNAME" # addon_extension.jar

unzip ../"$CJARFNMOVED" # ../addon_extension.jar.origj

# go back
cd ..
echo "Unpacked $CJARFNMOVED into $JARFNAME directory"


# backup unpacked directory of .jar (for later diff)
CJARBPCKDIR="$JARFNAME.orig"
cp -a "$JARFNAME" "$CJARBPCKDIR" # addon_extension.jar addon_extension.jar.orig
echo "Backed up $JARFNAME dir to $CJARBPCKDIR dir"

# get directory for DIFF - typically the parent is 'chrome' (not always)
CJARPARENT="$(dirname $(readlink -f "$JARFNAME"))"

echo "
 ### DONE UNPACKING

  You can now edit the unpacked jar files in (the *directory*):
$(readlink -f "$JARFNAME")/

  Then, to pack them back in a jar that replace the extension one,
  note that for relative dirs, zip must be in the directory which is packed;
  and use (mind the * at end of zip):
# cd $(readlink -f "$JARFNAME")/    # so zipping refers to correct relative paths:
zip -sd -r "$JARFPATH" *

  To check the zip:
file-roller "$JARFPATH"

  Then, to test, Firefox may have to be closed down and started again;
  /path/to/firefox/profile/extensions.{sqlite,sqlite-journal,ini,cache,rdf}
    may need to be removed;
  When changing about:config addon stuff,
    must re-save preferences too (with OK, not cancel)

  Finally, to take a diff betwixt the .jars:
# cd "$CJARPARENT"/ # for correct relative paths
diff -Naur "$CJARBPCKDIR" "$JARFNAME" > "$JARFNBASE"-jar.patch
"

#~ # note, the below sets the directories from /home!!:
#~ #$ zip -sd -r test.zip ~/Desktop/addon_extension.orig/chrome/addon_extension.jar/
#~ # for relative dirs, must be in the directory which is packed
#~ Then, with unpacked .jar - can directly replace the original jar..


#~ also
#~ [http://kb.mozillazine.org/Unable_to_install_themes_or_extensions_-_Firefox#Corrupt_extension_files Unable to install themes or extensions - MozillaZine Knowledge Base]
#~ "Exit Firefox completely, then open your Firefox profile folder (read the linked article for its location) and delete or rename these files:
    #~ extensions.ini
    #~ extensions.cache
    #~ extensions.rdf ..."

#~ $ ls -la /path/to/firefox/profile/extensions.sqlite* # big files!
#~ -rw-r--r-- 1 USER USER 393216 2011-10-22 19:22 /path/to/firefox/profile/extensions.sqlite
#~ -rw-r--r-- 1 USER USER 229944 2011-10-22 19:22 /path/to/firefox/profile/extensions.sqlite-journal

#~ $ mv /path/to/firefox/profile/extensions.sqlite /path/to/firefox/profile/___extensions.sqlite
#~ $ mv /path/to/firefox/profile/extensions.sqlite-journal /path/to/firefox/profile/___extensions.sqlite-journal


#~ # Links:
#~ # [http://colonelpanic.net/2010/08/browser-plugins-vs-extensions-the-difference/ Browser Plugins vs Extensions – the difference | ColonelPanic]
#~ # [https://developer.mozilla.org/en/XUL_Questions_and_Answers XUL Questions and Answers - MDN]

