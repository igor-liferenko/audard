#!/usr/bin/env python
# -*- coding: utf-8 -*- # must specify, else 2.7 chokes even on Unicode in comments

"""
checkimap.py - sdaau 2014
quickly check IMAP inbox email messages (titles) from the command line
"""

# http://stackoverflow.com/questions/11804225/check-for-new-email-using-command-line
# http://yuji.wordpress.com/2011/06/22/python-imaplib-imap-example-with-gmail/
# http://stackoverflow.com/questions/13210737/get-only-new-emails-imaplib-and-python
# http://stackoverflow.com/questions/5259601/how-convert-email-subject-from-utf-8-to-readable-string
# http://stackoverflow.com/questions/7331351/python-email-header-decoding-utf-8
# http://stackoverflow.com/questions/18678827/undoing-marked-as-read-status-of-emails-fetched-with-imaplib

import sys, os
scriptdir = os.path.dirname(os.path.realpath(__file__))
calldir = os.getcwd()

if sys.version_info[0] < 3:
  def b(x):
    return x
  def utt(x):
    return x.encode("utf-8")
  def utd(x): # works if x str
    return x.decode("utf-8")
  def uttc(x):
    return x
  def utte(x):
    return x.encode("utf-8")
  def uttf(x):
    return x
else:
  def b(x):
    return bytes(x, 'UTF-8')
  def utt(x):
    return str(x)
  def utd(x): # if x is bytes
    return x.decode("utf-8")
  def uttc(x):
    return x.decode("utf-8")
  unicode = str
  def utte(x):
    return x
  # may get: `... charset="utf-8"\r\n ... Du har f\xe5et `
  # lone \xe5 is invalid utf-8; it is latin1
  # http://stackoverflow.com/questions/5552555/unicodedecodeerror-invalid-continuation-byte
  # so here try handle exceptions:
  def uttf(x):
    try:
      return x.decode("utf-8")
    except:
      return x.decode('latin-1') #.encode("utf-8") # works only without this extra encode!


import argparse # python 2.7/3.2
import getpass
import imaplib
import email
import base64
import re
from email.header import decode_header

COLOROUT = True

if COLOROUT:
  STP = '\033[31m' # red
  BTP = '\033[1m'  # bold
  EDP = '\033[0m'
else:
  STP = ''
  BTP = ''
  EDP = ''


# http://stackoverflow.com/questions/1112343/how-do-i-capture-sigint-in-python
#import signal
#def signal_handler(signal, frame):
#  print('You pressed Ctrl+C!')
#  sys.exit(0)
#signal.signal(signal.SIGINT, signal_handler)

if (getpass.getpass == getpass.unix_getpass):
  # a hack in case the below patch is not implemented
  # [http://bugs.python.org/issue11236 Issue 11236: getpass.getpass does not respond to ctrl-c or ctrl-z - Python tracker]
  # using python3/getpass.py
  def unix_getpass(prompt='Password: ', stream=None):
    import os, termios # needed for the getpass hack
    """Prompt for a password, with echo turned off.
    Args:
      prompt: Written on stream to ask for the input.  Default: 'Password: '
      stream: A writable file object to display the prompt.  Defaults to
          the tty.  If no tty is available defaults to sys.stderr.
    Returns:
      The seKr3t input.
    Raises:
      EOFError: If our input tty or stdin was closed.
      GetPassWarning: When we were unable to turn echo off on the input.
    Always restores terminal settings before returning.
    """
    fd = None
    tty = None
    try:
      # Always try reading and writing directly on the tty first.
      fd = os.open('/dev/tty', os.O_RDWR|os.O_NOCTTY)
      tty = os.fdopen(fd, 'w+', 1)
      input = tty
      if not stream:
        stream = tty
    except EnvironmentError as e:
      # If that fails, see if stdin can be controlled.
      try:
        fd = sys.stdin.fileno()
      except (AttributeError, ValueError):
        passwd = fallback_getpass(prompt, stream)
      input = sys.stdin
      if not stream:
        stream = sys.stderr
    if fd is not None:
      passwd = None
      try:
        old = termios.tcgetattr(fd)   # a copy to save
        new = old[:]
        #new[3] &= ~(termios.ECHO|termios.ISIG)  # 3 == 'lflags'
        new[3] &= ~termios.ECHO  # 3 == 'lflags'; is like (~termios.ECHO)|termios.ISIG
        tcsetattr_flags = termios.TCSAFLUSH
        if hasattr(termios, 'TCSASOFT'):
          tcsetattr_flags |= termios.TCSASOFT
        try:
          termios.tcsetattr(fd, tcsetattr_flags, new)
          passwd = getpass._raw_input(prompt, stream, input=input) #
        finally:
          termios.tcsetattr(fd, tcsetattr_flags, old)
          stream.flush()  # issue7208
      except termios.error:
        if passwd is not None:
          # _raw_input succeeded.  The final tcsetattr failed.  Reraise
          # instead of leaving the terminal in an unknown state.
          raise
        # We can't control the tty or stdin.  Give up and use normal IO.
        # fallback_getpass() raises an appropriate warning.
        del input, tty  # clean up unused file objects before blocking
        passwd = fallback_getpass(prompt, stream)
    stream.write('\n')
    return passwd
  #print(getpass.getpass, getpass.unix_getpass, unix_getpass)
  getpass.unix_getpass = unix_getpass
  getpass.getpass = unix_getpass
  #print(getpass.getpass, getpass.unix_getpass, unix_getpass)

parser = argparse.ArgumentParser(description='Check IMAP mails.')
parser.add_argument('server_addr', nargs=1, help='server address')
parser.add_argument('username', nargs=1, help='user name')

args = parser.parse_args()
server_addr = args.server_addr[0]
username = args.username[0]
#print(server_addr, username)

try:
  #pw = getpass.getpass()
  pw = getpass.getpass('Password for {0} (@ {1})? '.format(username, server_addr) )
except KeyboardInterrupt:
  print("\nCtrl-C interrupted password, exiting...")
  sys.exit(1)


mail = imaplib.IMAP4_SSL(server_addr)
#mail.debug = 4
mail.login(username, pw)

print("")
print("  List of folders on {0}:".format(server_addr))
statuslist, listlist = mail.list()
print("    Status: {0}".format(statuslist))
#~ print("  List: {0}".format("\n".join(map(utd, listlist)))) # entire list, too much space on terminal
print("    List: `{0}` ... [{1} entries]".format(utd(listlist[0]), len(listlist)))

# list the inbox here;
foldername = "INBOX"
# on my servers, readonly=1 *still* sets the \Seen flag!
#~ mail.select(foldername, readonly=1) # connect to inbox.
# so, must connect non-readonly, to modify the flag back
mail.select(foldername) # connect to inbox.

uidresult, uiddata = mail.uid('search', None, "ALL") # search and return uids instead
muids = uttc(uiddata[0]).split()
NUMMAILS=10
print("  Getting max {4} latest mails in {3} (data: {1} ... {2}); result: {0}".format(uidresult, muids[:5], muids[-5:], foldername, NUMMAILS))

# http://yuji.wordpress.com/2011/06/22/python-imaplib-imap-example-with-gmail/
# note that if you want to get text content (body) and the email contains
# multiple payloads (plaintext/ html), you must parse each message separately.
# use something like the following: (taken from a stackoverflow post)
def get_first_text_block(email_message_instance):
  maintype = email_message_instance.get_content_maintype()
  if maintype == 'multipart':
    for part in email_message_instance.get_payload():
      if part.get_content_maintype() == 'text':
        return part.get_payload()
  elif maintype == 'text':
    return email_message_instance.get_payload()

print("")
# loop through all uids, retrieve, print
# reversed order - so its latest first!
ic = 0
#  =?UTF-8?B? -> UTF-8, binary; =?UTF-8?Q? -> UTF-8, quoted (printable)
# use decode_header for this
#~ utfrx = r"^=?(UTF|utf)-8?B?";
utfrx = r"(=\?[^\?]*\?.\?)";
st_utfrx = ".*" + utfrx
default_charset = 'ASCII'
for myuid in list(reversed(muids))[:NUMMAILS]:
  typ, data = mail.uid('fetch', myuid, '(FLAGS)') #conn.fetch(num,'(FLAGS)')
  isSeen = ( "Seen" in uttc(data[0]) )
  #~ print('Got flags: {2}: {0} .. {1}'.format(typ,data, # NEW: OK .. ['1 (FLAGS ())']
          #~ "Seen" if isSeen else "NEW"))
  #
  fresult, fdata = mail.uid('fetch', myuid, '(RFC822)')
  raw_email = fdata[0][1]
  #print(uttc(raw_email))
  #exc_type, exc_value, exc_traceback = sys.exc_info()
  email_message = email.message_from_string(uttf(raw_email))
  ic+=1;
  #print(email_message.items()) # print all headers
  tsubj = email_message['Subject']
  if re.match(st_utfrx, tsubj):
    result = decode_header(tsubj)
    tsubj = utte(''.join([ unicode(t[0], t[1] or default_charset) for t in result]))
  tfrom = email_message['From']
  if re.match(st_utfrx, tfrom):
    result = decode_header(tfrom)
    tfrom = utte(''.join([ unicode(t[0], t[1] or default_charset) for t in result]))
  print("[{3}] ({4}) Date: {0}\n  From: {1}\n  Subj: {2}".format(email_message['Date'], STP+tfrom+EDP, BTP+tsubj+EDP, ic, "Seen" if isSeen else "NEW"))
  # there are some \r without \n here, which may screw up, so strip
  # for Python3 map must be inside a list
  try:
    bodylines = list(map(lambda it: it.strip("\r"), get_first_text_block(email_message).split("\n")))
  except:
    bodylines = ["(exc/None?)"]
  print("  Body: {0} ... [{1} lines]".format(bodylines[0], len(bodylines)))
  print("")
  # restore New/UNSEEN if it wasn't originally seen:
  if not(isSeen):
    # this gives `UID STORE 23884 -FLAGS "\\Seen"`: BAD Error in IMAP command UID STORE: Flags list contains non-atoms.:
    #~ ret, data = mail.uid('store', myuid, '-FLAGS', '\\Seen') #conn.store(num,'-FLAGS','\\Seen')
    # this works - has to have parenthesis:
    ret, data = mail.uid('store', myuid, '-FLAGS', '(\\Seen)')
    if ret != 'OK':
      print("restored {0}: {1}, {2}".format(myuid, ret, data))
    # this sets one by one, else can set in one go (if at start
    # querying for (UNSEEN)); see: http://stackoverflow.com/a/11239068/277826
    # but this seems to work, even if somewhat slow, so keeping it.

#~ mail.close() # only for mail.select() ? But I have .select()?!
print("")
print("Listed {0}/{1} mails, of total {2} in {3}".format(ic, NUMMAILS, len(muids), foldername))
print("{0}".format(mail.logout()))
print("Logged off from server; ... done.")
