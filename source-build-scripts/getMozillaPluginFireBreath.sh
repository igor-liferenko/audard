#!/usr/bin/env bash

# getMozillaPluginFireBreath.sh
# sdaau Oct 2011, tested on Ubuntu 11.04
# http://www.firebreath.org/display/documentation/Building+on+Linux
# http://www.firebreath.org/display/documentation/Download

# no "goto" in bash; http://www.murga-linux.com/puppy/viewtopic.php?t=3983&
# "you can disable a block of code something like this":
DOINSTALL=true # change: true,false
if $DOINSTALL ; then # START JUMP

# Requirements
# cmake, git - already the newest version.
# libgtk2.0-dev: 47 newly installed, 20,3 MB of archives; 60,5 MB of additional disk space
sudo apt-get install cmake libgtk2.0-dev git

# "First thing is first; get the source code."
# Checkout latest source from GitHub
git clone git://github.com/firebreath/FireBreath.git firebreath-dev

cd firebreath-dev


## "For those users who do not have boost already installed or who wish to use firebreath-boost anyway, you will need the latest FireBreath-boost archive as well. This should be installed automatically when you run the prep script for the first time! (Versions 1.4 and later).  If that doesn't work, you may need to install it using the instructions below."
## ./prepmake.sh did find and build: "Boost not found; downloading latest FireBreath-boost from GitHub (http://github.com/firebreath/firebreath-boost)"

# "Generate the example project files"
# "The project build files will all be generated into the buildex/ directory under the project root"
./prepmake.sh examples

# "Build the Plugin"
# "The example plugin can be built by changing to the directory buildex and executing:"
# ... (build takes a while) ... "Success: 24 tests passed."
cd buildex
make

# go back to firebreath-dev directory
cd ..

# "Make the plugin accessible"
# "Most browsers on Linux look for NPAPI plugins in either "/usr/lib/mozilla/plugins" or "~/.mozilla/plugins"; copy the plugin file to one of those locations "
# about:plugins confirms
# note: symlink may be more problematic to overwrite (ln: creating symbolic link,
#  File exists) so use -sfn
echo cp buildex/bin/FBTestPlugin/npFBTestPlugin.so ~/.mozilla/plugins/.
ln -sfn $(readlink -f buildex/bin/FBTestPlugin/npFBTestPlugin.so) ~/.mozilla/plugins/

# "Open in your browser and play with it"
# "Open the file buildex/projects/FBTestPlugin/gen/FBControl.htm in your preferred browser
# Use Jash or firebug (or whatever) to make calls on the plugin."
# firefox buildex/projects/FBTestPlugin/gen/FBControl.htm

fi # END JUMP

# http://stackoverflow.com/questions/7869546/single-file-app-with-xulrunner-possible ... not :(
# make a test xul app - https://developer.mozilla.org/en/Getting_started_with_XULRunner
mkdir fbxultestapp
mkdir -p fbxultestapp/chrome/content
mkdir -p fbxultestapp/defaults/preferences
cat > fbxultestapp/application.ini <<"EOF"
[App]
Vendor=XULTest
Name=FBxulTestApp
Version=1.0
BuildID=20111024
ID=fbxultestapp@xultest.org

[Gecko]
MinVersion=1.8
MaxVersion=2.*
EOF
# "The chrome manifest file is used by XULRunner to define specific URIs which in turn are used to locate application resources. This will become clearer when we see how the “chrome://” URI is used."
cat > fbxultestapp/chrome/chrome.manifest <<"EOF"
content fbxultestapp content/
EOF
# "As mentioned in Step 3, the default location of the chrome.manifest has changed in XULRunner 2.0, so we also need a simple chrome.manifest in the application root which will include the the manifest in our chrome root. "
cat > fbxultestapp/chrome.manifest <<"EOF"
manifest chrome/chrome.manifest
EOF
# "The prefs.js file tells XULRunner the name of the XUL file to use as the main window. "
# https://developer.mozilla.org/en/Debugging_a_XULRunner_Application
# note: for some reason, the plugin shows (and dumps mouseover data) *only after*
#  the debugging preferences are set!
# AND - the data dump goes to stdout - even if -console is not specified, and -jsconsole is!
cat > fbxultestapp/defaults/preferences/prefs.js <<"EOF"
pref("toolkit.defaultChromeURI", "chrome://fbxultestapp/content/main.xul");
/* debugging prefs */
pref("browser.dom.window.dump.enabled", true);
pref("javascript.options.showInConsole", true);
pref("javascript.options.strict", true);
pref("nglayout.debug.disable_xul_cache", true);
pref("nglayout.debug.disable_xul_fastload", true);
EOF
# "Finally, we need to create a simple XUL window, which is described in the file main.xul. Nothing fancy here ... "
# also: http://old.nabble.com/including-Flash-in-XUL-td9424724.html
# http://old.nabble.com/Calling-NPAPI-plugin-from-an-extension-td30462832.html
# note also - even in js comment: < JSAPI-Auto Javascript Object > raises "not well formed" XML!
cat > fbxultestapp/chrome/content/main.xul <<"EOF"
<?xml version="1.0"?>

<?xml-stylesheet href="chrome://global/skin/" type="text/css"?>

<window id="main" title="FBxulTestApp" width="300" height="300" xmlns="http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul"
xmlns:html="http://www.w3.org/1999/xhtml">

  <script type="application/javascript">
    function bump() {
      document.getElementById("more-text").hidden = !(document.getElementById("more-text").hidden);
      // the plugin should be: [JSAPI-Auto Javascript Object]
      alert(document.getElementById('plugin0'));//("sdf");
    }
  </script>

  <caption label="Hello World"/>
  <separator/>
  <groupbox id="someexistingelement" style="background-color:red;border-style:dashed;border-width:2px;border-color:green;">
    <html:object id="plugin0" type="application/x-fbtestplugin" width="50px" height="50px" style="background-color:blue;border-style:solid;border-width:2px;"> <!-- insert my object into
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
xulrunner fbxultestapp/application.ini -jsconsole


# goes back to call dir when script exits.
