#!/usr/bin/env python

# Qt4WebKit_singleinst_stdin.py (QwkSisi)
# copyleft sdaau 2013
# developed in python 2.7
# call with:
## #open one instance with python Qt4WebKit_singleinst_stdin.py -
## #then, from (another) terminal, do:
## echo "<i>Hello World</i>" | python Qt4WebKit_singleinst_stdin.py -

import sys
import os
import errno
import tempfile
import logging

import urllib

# to (eventually) support Python3 (http://python3porting.com/stdlib.html)
try:
  from io import StringIO
except ImportError:
  from StringIO import StringIO

import pickle

# sudo apt-get install python-qt4
# (python-qt4 are python2.7 bindings, not python3)
from PyQt4.QtCore import *
from PyQt4.QtGui import *
try:
  from PyQt4.QtWebKit import QWebView, QWebPage
except:
  webkit_available = False
else:
  webkit_available = True

from multiprocessing.managers import SyncManager

class MyDictManager(SyncManager):
  pass


startcontent="<h1>QwkSisi started</h1><br/><i>Waiting for input</i>"

# http://stackoverflow.com/questions/1829116/how-to-share-variables-across-scripts-in-python/14700365#14700365
# http://stackoverflow.com/questions/2545961/how-to-synchronize-a-python-dict-with-multiprocessing/2556974#2556974
sharedict = {}
def get_dict():
  return sharedict


# single instance of program
# mod from http://pypi.python.org/pypi/tendo: singleton.py
# http://stackoverflow.com/questions/380870/python-single-instance-of-program
# http://stackoverflow.com/questions/82831/how-do-i-check-if-a-file-exists-using-python
# will create two tmp files: .lock (for single instance) and .pipe (socket for shared variables); auto-cleaned when master finally exits
class SingleInstance:
  """
  If you want to prevent your script from running in parallel just instantiate SingleInstance() class. If is there another instance already running it will exist the application with the message "Another instance is already running, quitting.", returning -1 error code.
  # (not directly exiting anymore - setting variable for further processing)

  >>> import tendo          # (now built in here)
  ... me = SingleInstance()

  This option is very useful if you have scripts executed by crontab at small amounts of time.

  Remember that this works by creating a lock file with a filename based on the full path to the script file.
  """
  def __init__(self, flavor_id=""):
    import sys
    self.initialized = False
    lfbase = os.path.normpath(tempfile.gettempdir() + '/' +
                     os.path.splitext(os.path.abspath(sys.modules['__main__'].__file__))[0].replace("/", "-").replace(":", "").replace("\\", "-") + '-%s' % flavor_id)
    self.lockfile = lfbase + '.lock'
    logger.debug("SingleInstance lockfile: " + self.lockfile)
    #mgraddress = '/tmp/mypipe' # if = me.lockfile: [Errno 98] Address already in use
    self.mgraddress = lfbase + '.pipe'
    self.isInstanceOpen = False
    if sys.platform == 'win32':
      try:
        # file already exists, we try to remove (in case previous execution was interrupted)
        if os.path.exists(self.lockfile):
          os.unlink(self.lockfile)
        self.fd = os.open(self.lockfile, os.O_CREAT | os.O_EXCL | os.O_RDWR)
      except OSError:
        type, e, tb = sys.exc_info()
        if e.errno == 13:
          #logger.error("Another instance is already running, quitting.")
          # sys.exit(-1)
          self.isInstanceOpen = True
        print(e.errno)
        raise
    else:  # non Windows
      import fcntl
#~ >       try:
#~ >         # the file gets deleted here the second time
#~ >         self.fp = open(self.lockfile, 'w')
#~ >         fcntl.lockf(self.fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
#~ >       except IOError:
#~ >         #logger.warning("Another instance is already running, quitting.")
#~ >         # sys.exit(-1)
#~ >         self.isInstanceOpen = True
      if not(os.path.isfile(self.lockfile)):
        logger.debug("SingleInstance - no lockfile")
        try:
          #self.fp = open(self.lockfile, 'w')
          self.fp = os.open (self.lockfile, os.O_TRUNC | os.O_CREAT | os.O_RDWR)
          fcntl.lockf(self.fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except IOError as e:
          logger.warning("Something wrong w/ lockfile: ", e)
      else: # lockfile should exist:
        logger.debug("SingleInstance - found lockfile")
        try:
          with open(self.lockfile) as f:
            fcntl.lockf(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            pass
        except IOError as e:
          self.isInstanceOpen = True
    #if self.isInstanceOpen:
    #  sys.exit(-1)
    self.initialized = True

  def __del__(self):
    import sys
    if not self.initialized:
      return
    if self.isInstanceOpen:
      logger.debug("SingleInstance - master already running, so not deleting lockfile at exit")
      # we do not want to delete self.fp if this is client;
      # because in that case, it doesn't even exist (since the lock will fail)
      return
    try:
      if sys.platform == 'win32':
        if hasattr(self, 'fd'):
          os.close(self.fd)
          os.unlink(self.lockfile)
      else:
        import fcntl
        fcntl.lockf(self.fp, fcntl.LOCK_UN)
        #os.close(self.fp)
        if os.path.isfile(self.lockfile):
          os.unlink(self.lockfile)
    except Exception as e:
      logger.warning(e)
      sys.exit(-1)


def openAnything(source):
  """URI, filename, or string --> stream

  http://diveintopython.org/xml_processing/index.html#kgp.divein

  This function lets you define parsers that take any input source
  (URL, pathname to local or network file, or actual data as a string)
  and deal with it in a uniform manner.  Returned object is guaranteed
  to have all the basic stdio read methods (read, readline, readlines).
  Just .close() the object when you're done with it.
  """
  if hasattr(source, "read"):
    return source

  if source == '-':
    #import sys
    return sys.stdin

  # try to open with urllib (if source is http, ftp, or file URL)
  #import urllib
  try:
    return urllib.urlopen(source)
  except (IOError, OSError):
    pass

  # try to open with native open function (if source is pathname)
  try:
    return open(source)
  except (IOError, OSError):
    pass

  # treat source as string
  #import StringIO
  return StringIO.StringIO(str(source))

# started from ReText: window.py
# see also http://stackoverflow.com/questions/8337129/qtextbrowser-or-qwebview
class QwkSisiWindow(QMainWindow):
  def __init__(self, parent=None):
    QMainWindow.__init__(self, parent)
    #super(QwkSisiWindow, self).__init__()
    self.resize(680, 480)

    #self.centralWidget = self.previewBox # with this, webview doesn't scale with window
    #self.mainLayout = QVBoxLayout(self) # avoid (self) as parent here, because:
    #'QLayout: Attempting to add QLayout "" to QwkSisiWindow "", which already has a layout'
    # see http://lists.trolltech.com/qt-interest/2008-06/thread00514-0.html

    # http://stackoverflow.com/questions/1508939/qt-layout-on-qmainwindow
    centwidgwindow = QWidget()
    self.mainLayout = QVBoxLayout(centwidgwindow)
    centwidgwindow.setLayout(self.mainLayout)

    #self.centralWidget.setLayout(self.mainLayout)
    self.setCentralWidget(centwidgwindow)

    if webkit_available:
      self.previewBox = self.getWebView(centwidgwindow)
    else:
      self.previewBox = QTextBrowser(centwidgwindow)

    self.mainLayout.addWidget(self.previewBox)
    self.mainLayout.addStretch()

    self.mgraddress = ""

    # see http://stackoverflow.com/questions/2727080/how-to-get-qwebkit-to-display-image
    # "dummy.html need not exist. It is just used to provide a proper baseUrl"
    # must use baseUrl in setHtml - else content not rendered!
    self.baseUrl = QUrl.fromLocalFile(QDir.current().absoluteFilePath("dummy.html"))
    self.myhtml = startcontent
    self.previewBox.setHtml(self.myhtml, self.baseUrl)

    # http://www.rkblog.rk.edu.pl/w/p/qtimer-making-timers-pyqt4/
    # http://stackoverflow.com/a/9812816/277826
    # QwkSisiWindow instantiates only once (as per lockfile)
    # so ok to start timer here; stops auto when window is closed
    self.ctimer = QTimer()
    QObject.connect(self.ctimer, SIGNAL("timeout()"), self.periodicUpdate)
    self.ctimer.start(1000)


  def getWebView(self, parent):
    # must specify (self) or the real parent as parent - else
    # the QWebView won't render in QMainWindow!
    webView = QWebView(parent)
    #~ if not self.handleLinks:
      #~ webView.page().setLinkDelegationPolicy(QWebPage.DelegateExternalLinks)
      #~ self.connect(webView.page(), SIGNAL("linkClicked(const QUrl&)"), self.linkClicked)
    return webView

  def periodicUpdate(self):
    """
    slot for constant timer timeout
    """
    logger.debug("periodicUpdate: " + self.mgraddress)
    # start up client
    manager = MyDictManager(address=(self.mgraddress), authkey='')
    manager.connect()
    # get shared dict
    sharedict = manager.sharedict()
    newhtml = sharedict.get('myHTML')
    if not(newhtml ==  self.myhtml):
      logger.debug("Old HTML: " + self.myhtml)
      logger.debug("New HTML: " + newhtml)
      rep = "Got new content; sizes: old: " + str(len(self.myhtml)) + " new: " + str(len(newhtml)) + " bytes"
      logger.warning(rep)
      self.myhtml = newhtml
      self.previewBox.setHtml(self.myhtml, self.baseUrl)



# http://sdaaubckp.svn.sourceforge.net/viewvc/sdaaubckp/single-scripts/testcurses-stdin.py?view=markup
def main(argv):
  global windowref

  logger.warning("Starting app...")

  # register first - regardless of instance
  MyDictManager.register("sharedict", get_dict)

  me = SingleInstance()

  if ( not(me.isInstanceOpen) ):
    logger.warning("Seems I'm the master instance - raising window...".center(76, "-"))
    logger.warning("(close the window from its titlebar X mark - not via Ctrl-C)".center(76, "-"))

    app = QApplication(sys.argv)
    app.setOrganizationName("QwkSisi project")
    app.setApplicationName("QwkSisi (Qt4WebKit_singleinst_stdin)")
    windowref = QwkSisiWindow()
    #~ window.previewBox.show()
    windowref.show()

    # start up server
    manager = MyDictManager(address=(me.mgraddress), authkey='')
    manager.start()
    windowref.mgraddress = me.mgraddress # copy for timer

    # set init values
    sharedict = manager.sharedict()
    # with logger.warning: TypeError: not all arguments converted during string formatting; -  but only if commas present - do string concat with + in separate variable, and it works
    #print("sharedict (master):", sharedict, "sharedict_tmp:", sharedict_tmp)

    ## windowref here causes: RuntimeError: underlying C/C++ object has been deleted
    #sharedict_tmp.update([('windowref', windowref)])
    ## me in client causes: I/O operation on closed file; Exception SystemExit: -1 in <bound method SingleInstance.__del__
    #sharedict.update([('me', me)])
    # .update() works directly - even if sharedict is <AutoProxy:
    sharedict.update([('myHTML', startcontent+"")])
    #print("B: sharedict (master): ", sharedict) #, "sharedict_tmp:", sharedict_tmp); if only sharedict, it's <AutoProxy

    # must have this, to have the QApplication start:
    sys.exit(app.exec_())

  else:
    logger.warning("Looks like the master instance is already running - piping to it...".center(76, "-"))
    #print me.lockfile

    # start up client
    manager = MyDictManager(address=(me.mgraddress), authkey='')
    manager.connect()

    # get shared dict
    sharedict = manager.sharedict()
    #print("sharedict (main): ", sharedict) #, "sharedict_tmp:", sharedict_tmp); if only sharedict, it's <AutoProxy

    # .get() works directly - even if sharedict is <AutoProxy:
    #print 'myHTML', sharedict.get('myHTML')

    #print argv, len(argv)
    fname = ""
    if len(argv):
      fname = argv[0]

    if fname != "":
      fobj = openAnything(fname)
      lineslist = fobj.readlines() # read all
      fobj.close()
      newstr = "".join(lineslist)
      rep = "Got " + str(len(newstr)) + " bytes; sending to master"
      logger.warning(rep)
      rep = "newstr: " + newstr
      logger.debug(rep) # also here logger.debug/warning makes problem: TypeError: not all arguments converted during string formatting - unless string is separate!
      if newstr:
        sharedict.update([('myHTML', newstr)])
    else:
      logger.error("Cannot find file to open - exiting");
      sys.exit(-1)




logger = logging.getLogger("QwkSisi")
logger.addHandler(logging.StreamHandler())

# run the main function - with arguments passed to script:
if __name__ == "__main__":
  logger.setLevel(logging.WARNING) #(logging.DEBUG)
  main(sys.argv[1:])

# shared vars:
# http://stackoverflow.com/questions/1829116/how-to-share-variables-across-scripts-in-python/14700365#14700365
# (http://mail.python.org/pipermail/tutor/2002-November/018353.html)
# http://stackoverflow.com/questions/3338283/python-sharing-global-variables-between-modules-and-classes-therein
# http://stackoverflow.com/questions/7839786/efficient-python-to-python-ipc
# http://stackoverflow.com/questions/6931342/system-wide-mutex-in-python-on-linux
# http://stackoverflow.com/questions/1268252/python-possible-to-share-in-memory-data-between-2-separate-processes
# http://stackoverflow.com/questions/1171767/comparison-of-the-multiprocessing-module-and-pyro
# http://stackoverflow.com/questions/2545961/how-to-synchronize-a-python-dict-with-multiprocessing
# [remote multiprocessing, shared object | Python | Python](http://www.gossamer-threads.com/lists/python/python/819363)
# http://stackoverflow.com/questions/11532654/python-multiprocessing-remotemanager-under-a-multiprocessing-process

# Perl's IPC::Shareable uses labeled data in shared memory - no such luck here;
# but since we anyways have to create/deal with a lockfile here,
# we may as well use it as target for pickle? CANNOT - bad

