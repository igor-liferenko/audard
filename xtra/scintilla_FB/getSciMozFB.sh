#!/usr/bin/env bash

# getSciMozFB.sh;
# sdaau Oct 2011, tested on Ubuntu 11.04

# NOTE: note: building of plugin depends on platform: LoadPlugin: failed to initialize shared library /path/to/profile/extensions/SciMozFB@scimozfbdev.team/plugins/npSciMozFB.i386.so [/usr/lib/libstdc++.so.6: version `GLIBCXX_3.4.14' not found (required by /path/to/profile/extensions/SciMozFB@scimozfbdev.team/plugins/npSciMozFB.i386.so)]


CALLDIR=$(pwd) #THISDIR, ORIGDIR..
THISSCRIPTDIR=$(dirname $(readlink -f "$0"))
FBROOT=${CALLDIR}/firebreath-dev

SLNK="http://sdaaubckp.svn.sf.net/svnroot/sdaaubckp"

DOINST=true # change: true,false (false to jump)
if $DOINST ; then # START JUMP/goto on false


# some prerequisites
# install expect-dev to have autoexpect program
set -x # view commands
sudo apt-get install subversion expect mercurial


# first, get the getMozillaPluginFireBreath.sh in this dir;
#   run it, so it builds the examples

# do not put . at end for export
svn export ${SLNK}/source-build-scripts/getMozillaPluginFireBreath.sh

# should be chmodded already - just in case
chmod +x getMozillaPluginFireBreath.sh
set +x


# K, now run - get the FireBreath code, build example
./getMozillaPluginFireBreath.sh

#~ fi # END JUMP; cleanup for here, see [[2]]

set -x # view commands

# when it exits, we should be back in this directory
# so go into firebreath-dev first - and keep ref to it
cd firebreath-dev
#~ FBROOT=$(pwd) # hardcoded now, for jump/goto

# first, we need to create scintilla directory
#  add the scintilla Cmake files, so scintilla
#  is treated as a 'FireBreath Library'
cd src/libs
mkdir scintilla
cd scintilla
svn export ${SLNK}/xtra/scintilla_FB/CMakeLists.txt
svn export ${SLNK}/xtra/scintilla_FB/FindScintilla.cmake

# go back
cd ${FBROOT}

# now we need to create the SciMozFB project
# for that, we use fbgen.py from FireBreath
# fbgen.py can be used non-interactively - but does not have all arguments
# so we use an `expect` script, to simulate the typing of data
#  (this script was recorded using `autoexpect` [in expect-dev], with:
#   autoexpect -f fbgen_SciMozFB.exp ./fbgen.py       #)

# first, get the expect script:
svn export ${SLNK}/xtra/scintilla_FB/fbgen_SciMozFB.exp

# should be chmodded already - just in case
chmod +x fbgen_SciMozFB.exp

set +x

# run expect script - which will automatically run fbgen.py
#  and input the metadata values in the script (as if typed)
./fbgen_SciMozFB.exp

# at the end a window (or two) of example should show here;
# just close it (both of 'em) to continue

# we should be back in ${FBROOT} now
# here we should now have a ${FBROOT}/projects/SciMozFB project dir made by fbgen
# time to patch values for scintilla dependencies into project...


set -x # view commands
# as recommended in http://www.firebreath.org/display/documentation/Using+Libraries#UsingLibraries-Linux
# "Using FireBreath Libraries with CMake: Place the following at the bottom of your project's PluginConfig.cmake":
echo -e "\nadd_firebreath_library(scintilla)" >> projects/SciMozFB/PluginConfig.cmake

# "For example to link to the Foo library on Linux we'd add to projects/YourPlugin/X11/projectDef.cmake"
# however, the add_dependencies reference MUST be right
#  after add_x11_plugin(...) - but before the end!
#  sed: printout first, then replace inline
sed -n 's/add_x11_plugin\(.*\)/add_x11_plugin\1\n\nadd_dependencies(${PROJECT_NAME} scintilla.a)\n/p' projects/SciMozFB/X11/projectDef.cmake
sed -i 's/add_x11_plugin\(.*\)/add_x11_plugin\1\n\nadd_dependencies(${PROJECT_NAME} scintilla.a)\n/' projects/SciMozFB/X11/projectDef.cmake

# that should handle the scintilla library patching

# ok, now get the online modified project files
cd projects/SciMozFB
svn export ${SLNK}/xtra/scintilla_FB/SciMozFB.cpp
svn export ${SLNK}/xtra/scintilla_FB/SciMozFB.h
svn export ${SLNK}/xtra/scintilla_FB/SciMozFBAPI.cpp
svn export ${SLNK}/xtra/scintilla_FB/SciMozFBAPI.h
svn export ${SLNK}/xtra/scintilla_FB/MScintilla.h

cd X11
svn export ${SLNK}/xtra/scintilla_FB/MScintillaX11.cpp

# that should handle getting the online SciMozFB files

fi # END JUMP;
# go back - for jump
cd ${FBROOT}

set -x
# now try to build
# first, as this is Linux, we need to run prepmake.sh to generate makefiles
./prepmake.sh

# the first time, prepmake will download scintilla, and still keep dirs notfound
# run prepmake once more, but note - that doesn't help w/ finding SCINTILLA_LIBRARY,
#  as it is not built yet, so it cannot be "found" (must be explicitly set)
./prepmake.sh


# at this point, we should have makefiles in build/projects/SciMozFB/
#  so cd there and build
# NOTE: we could also have called `make SciMozFB` from ${FBROOT}
#  but those don't get built at same location as below
cd build/projects/SciMozFB
make

# if make succeeds, we should have a shared object plugin file in
#  ${FBROOT}/build/bin/SciMozFB/npSciMozFB.so
# if make fails, exit
if [ "$?" -ne 0 ] ; then
  exit 0
fi

# go back
cd ${FBROOT}

# copy the .so plugin so its accessible Mozilla apps (or symlink)
# note: symlink may be more problematic to overwrite (ln: creating symbolic link,
#  File exists) so use -sfn
#~ cp build/bin/SciMozFB/npSciMozFB.so ~/.mozilla/plugins/
ln -sfn $(readlink -f build/bin/SciMozFB/npSciMozFB.so) ~/.mozilla/plugins/

if [ -d smfbxultestapp ] ; then # re-clean
  rm -rf smfbxultestapp
fi

set +x

# now time to generate XUL based on this plugin, and run it

# make a test xul app - https://developer.mozilla.org/en/Getting_started_with_XULRunner
mkdir smfbxultestapp
mkdir -p smfbxultestapp/chrome/content
mkdir -p smfbxultestapp/defaults/preferences
cat > smfbxultestapp/application.ini <<"EOF"
[App]
Vendor=XULTest
Name=SMFBxulTestApp
Version=1.0
BuildID=20111025
ID=smfbxultestapp@xultest.org

[Gecko]
MinVersion=1.8
MaxVersion=2.*
EOF
cat > smfbxultestapp/chrome/chrome.manifest <<"EOF"
content smfbxultestapp content/
EOF
cat > smfbxultestapp/chrome.manifest <<"EOF"
manifest chrome/chrome.manifest
EOF
cat > smfbxultestapp/defaults/preferences/prefs.js <<"EOF"
pref("toolkit.defaultChromeURI", "chrome://smfbxultestapp/content/main.xul");
/* debugging prefs */
pref("browser.dom.window.dump.enabled", true);
pref("javascript.options.showInConsole", true);
pref("javascript.options.strict", true);
pref("nglayout.debug.disable_xul_cache", true);
pref("nglayout.debug.disable_xul_fastload", true);
EOF
cat > smfbxultestapp/chrome/content/main.xul <<"EOF"
<?xml version="1.0"?>

<?xml-stylesheet href="chrome://global/skin/" type="text/css"?>

<window id="main" title="SMFBxulTestApp" width="300" height="300" xmlns="http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul"
xmlns:html="http://www.w3.org/1999/xhtml">

  <script type="application/x-javascript">
    // tis without code evaluate!!! only -jsconsole has code eval..
    function openJavaScriptConsole() {
      var wwatch = Components.classes["@mozilla.org/embedcomp/window-watcher;1"]
                           .getService(Components.interfaces.nsIWindowWatcher);
      wwatch.openWindow(null, "chrome://global/content/console.xul", "_blank",
                      "chrome,dialog=yes,all", null);
    }

    function jsdump(str)
    {
      Components.classes['@mozilla.org/consoleservice;1']
                .getService(Components.interfaces.nsIConsoleService)
                .logStringMessage(str);
    }

    // NOTE: from xulrunner code eval; plugin0() is not defined!
    function plugin0() {
      return document.getElementById('plugin0');
    }
    //var plugin = plugin0; // like this, plugin has the text of the function of plugin0! Add parenthesis!
    var plugin = plugin0();

    //openJavaScriptConsole(); // no code eval anyways..

    // use this to raise about:config in xulrunner:
    // window.open("chrome://global/content/config.xul", "", "chrome")

    // "global"? 123456789012345678901234567890
    var mystr = "Waiting/a two+by_four-plank:is";
    //var mystr = "Waitинг/a тwo+бу_foур-пlaнk:is"; // note: unicode seems to arrive well in the plugin (stdout) - and also in scintilla, if it is set to unicode / utf-8 ..

    function bump() {
      document.getElementById("more-text").hidden = !(document.getElementById("more-text").hidden);
      // the plugin should be: [JSAPI-Auto Javascript Object]
      //alert(document.getElementById('plugin0'));//("sdf");
      //alert(plugin0().echo("echo this string!") + " " + plugin0().valid); // ok
      //alert(plugin); // null!
      var lplugin = plugin0();
      //alert(lplugin); // ok...
      jsdump(lplugin);
      //plugin0().SciSendMessageIS(SCI_INSERTTEXT, 0, "Hello there!\n");

      var sTR = "";
      // this loop seems to REALLY screw things up?
      // too big of a window? Not too much; maybe just the iterating.. or 's' a bad var name..?
      // NO - too many "\n" at end of line, so window was too big..
      // fine now..
      //for (ix in lplugin) {sTR += " " + ix + " " + " "; };
      //alert(sTR);

      // #defines in Scintilla.h:
      var SCI_INSERTTEXT = 2003;
      var SCI_REPLACESEL = 2170;
      var SCI_ADDTEXT = 2001;
      var SCI_APPENDTEXT = 2282;
      var SCI_SETSEL = 2160;
      var SCI_SETTEXT = 2181;
      var SCI_GETLENGTH  = 2006;
      var SCI_GETTEXT = 2182;
      //lplugin.SciSendMessageIS(SCI_INSERTTEXT, "0", "Hello there!\n"); // all the same for "0", string or number..
      //lplugin.SciSendMessageIS(SCI_INSERTTEXT, 0, "Hello there!\n"); // 0 inserts at start of doc, view doesn't move
      //jsdump("after SciSendMessageIS"); // alert("2");

      // note: SCI_INSERTTEXT(int pos, const char *text) - at specific position (above is at start of doc)
      // options
      // SCI_REPLACESEL([unused], const char *text)
      // "The currently selected text between the anchor and the current position is replaced by the 0 terminated text string. If the anchor and current position are the same, the text is inserted at the caret position."
      // SCI_ADDTEXT(int length, const char *s)
      // This inserts the first length characters from the string s at the current position. This will include any 0's in the string that you might have expected to stop the insert operation. The current position is set at the end of the inserted text, but it is not scrolled into view.
      // SCI_APPENDTEXT(int length, const char *s)
      // This adds the first length characters from the string s to the end of the document. This will include any 0's in the string that you might have expected to stop the operation. The current selection is not changed and the new text is not scrolled into view.
      // SCI_SETSEL(int anchorPos, int currentPos)
      // This message sets both the anchor and the current position. If currentPos is negative, it means the end of the document. If anchorPos is negative, it means remove any selection (i.e. set the anchor to the same position as currentPos). The caret is scrolled into view after this operation.

      // ok, so for appending, easiest (and actually, also safest) -
      //  SCI_APPENDTEXT strlen(str), str; then SCI_SETSEL -1 -1
      //var ps1 = mystr.substring(0,9);
      // slice(0) to return a copy of substring
      var ps1 = mystr.substr(0,10).slice(0);
      var ps2 = mystr.substr(10,10).slice(0);
      var ps3 = mystr.substr(20,10).slice(0);

      var strToSend = ps1 + "\n" + ps2 + "\n" + ps3 + "\n";
      // and shuffle a bit too..
      //mystr = ps2.substring(0,4) + ps3.substring(5,9) + ps1.substring(0,4) + ps1.substring(5,9) + ps3.substring(0,4) + ps2.substring(5,9);
      mystr = ps2.substr(0,5).slice(0) + ps3.substr(5,5).slice(0) + ps1.substr(0,5).slice(0) + ps1.substr(5,5).slice(0) + ps3.substr(0,5).slice(0) + ps2.substr(5,5).slice(0);

      lplugin.SciSendMessageIS(SCI_APPENDTEXT, strToSend.length, strToSend);
      lplugin.SciSendMessageII(SCI_SETSEL, -1, -1);

      // this to check the js interface of plugin: but it just shows:
      // SciSendMessageII -> SciSendMessageII()
      // SciSendMessageIS -> SciSendMessageIS()
      // iSciSendMessage -> iSciSendMessage()
      // sSciSendMessageI -> sSciSendMessageI()
      //var iss = "--------------\n"; for (ix in lplugin) {var str1="" ; try { str1 = eval("lplugin."+ix); } catch (ex) {str1 = ex; } ;  iss += " " + ix + " -> " + str1 + "\n"; }; jsdump("_"+iss);

      var textlen = lplugin.iSciSendMessage(SCI_GETLENGTH);
      var tlen = textlen + 1;
      var textcontent = "";
      // lplugin.SciSendMessageIS(SCI_GETTEXT, textlen+1, textcontent); // apparently cannot work
      try {
      //textcontent = lplugin.sSciSendMessageI(SCI_GETTEXT, textlen+1); // ?? sSciSendMessageI Too many arguments, expected 1. // that was due to wrong registerMethod
      textcontent = lplugin.sSciSendMessageI(SCI_GETTEXT, tlen);
      } catch (ex) {jsdump("sSciSendMessageI " + ex);} ;
      alert(textlen + "\n" + textcontent);
    }
  </script>

  <caption label="Hello World"/>
  <separator/>
  <groupbox id="someexistingelement" style="background-color:red;border-style:dashed;border-width:2px;border-color:green;">
    <html:object id="plugin0" type="application/x-scimozfb" width="100px" height="100px" style="background-color:blue;border-style:solid;border-width:2px;"> <!-- insert my object into
"someexistingelement" -->
    </html:object>
  </groupbox>
  <separator/>
  <button label="More >>" oncommand="bump();" />
  <separator/>
  <description id="more-text" hidden="true">This is a simple XULRunner application. XUL is simple to use and quite powerful and can even be used on mobile devices.</description>

</window>
EOF

# and now can call:
# NOTE: MAKE SURE FIREFOX IS CLOSED WHEN DOING THIS TEST, TO ENSURE THE LATEST .SO IS READ!!
# (ELSE IT MAY KEEP A REFERENCE IN MEMORY!!)
xulrunner smfbxultestapp/application.ini -jsconsole


# goes back to call dir when script exits.









# notes:

# change `cmake --trace` in prepmake.sh to debug

# reset cache - from ${FBROOT}:
## cmake -U SCINTILLA_INCLUDE_DIR -U SCINTILLA_LIBRARY ./
## cmake -U SCINTILLA_INCLUDE_DIR -U SCINTILLA_LIBRARY ./build
# or alternatively, something like:
## cmake -D SCINTILLA_INCLUDE_DIR:PATH=SCINTILLA_INCLUDE_DIR-NOTFOUND ./build

# cleanups
## rm -rf src/libs/scintilla/scintilla
## rm -rf build/projects/SciMozFB
## rm -rf build/bin/SciMozFB
## rm -rf projects/SciMozFB # also? NOOOOOOOOO - this was with fbgen

# this fbgen.cfg hidden file populates missing values,
# if fbgen.py is called non-interactively (via cmdline options)
# but it can only get created from an interactive session
## rm ./.fbgen.cfg

# also check ~/.mozilla/plugins/

# cleanup [[2]]
#~ rm -rf firebreath-dev/src/libs/scintilla
#~ rm firebreath-dev/fbgen_SciMozFB.exp
#~ rm -rf firebreath-dev/build/projects/SciMozFB
#~ rm -rf firebreath-dev/build/bin/SciMozFB
#~ rm -rf firebreath-dev/projects/SciMozFB
#~ rm firebreath-dev/.fbgen.cfg

# to debug with gdb:
## A) must rebuild (at least) npSciMozFB as debug;
## add `SET(CMAKE_BUILD_TYPE DEBUG)` at start in projects/SciMozFB/CMakeLists.txt
# (note, that CMakeLists file is not the same, as the one that is
#   exported in this script - which is src/libs/scintilla/CMakeLists.txt)
# ... but that doesn't help much with scintilla, so also:
## B) must rebuild scintilla as debug;
## run `DEBUG=1 make` in ${FBROOT}/src/libs/scintilla/scintilla/gtk
## (its probably easier to do it manually.. instead of via CMAKE)
# ... but this still doesn't allow setting of breakpoints in gdb,
# while the .so hasn't been loaded/instantiated yet... so also:
## C) use the #define BREAKPOINT() asm("   int $3"); to
## trigger a breakpoint from the source file.
# and finally:
## D) use xulrunner to slide into gdb:
## `xulrunner -g smfbxultestapp/application.ini`
## instead of calling gdb manually, i.e.:
## `gdb --args sh -c "xulrunner smfbxultestapp/application.ini"`
# since even with debug build, and `symbol-file`, manual gdb
# still has trouble finding symbols..
## *) also, if a problem doesn't really happen at load;
## then can just go into gdb (via xulrunner), and while
## still running OK, hit Ctrl-C to make interrupt and set breakpoint
# (and then continue after in gdb with c)


