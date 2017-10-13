# phone paired via (apparently) bluez menu (Ubuntu GUI)
# added debs: http://www.hendrik-sattler.de/debian/ (keys are old; sudo apt-get update will complain - but can still install)

echo "Script not done yet; notes only"
exit 0


# see also:
How to download files from cellular using Bluetooth - http://go2linux.garron.me/transfer-files-with-bluetooth-Linux
Klings.NoWires() - OBEX over Bluetooth How-To for Linux - http://wireless.klings.org/HowTo/OBEX/
Brainboxes BlueTooth hardware and Linux - http://www.hpl.hp.com/personal/Jean_Tourrilhes/bt/
[SOLVED] Bluetooth again- cannot open /dev/rfcomm0 - http://www.linuxquestions.org/questions/linux-wireless-networking-41/bluetooth-again-cannot-open-dev-rfcomm0-941721/
Sony Ericsson T630 and Linux - http://ale.shouldshave.org/t630_linux.html



  501  sudo apt-get install openobex-apps
  502  obex_test --help
  503  ls /etc/apt/sources.list.d/
  506  sudo cp /etc/apt/sources.list.d/dominik-stadler-ppa-lucid.list /etc/apt/sources.list.d/openobex-hsattler.list
  507  sudo nano /etc/apt/sources.list.d/openobex-hsattler.list
  508  sudo apt-get update
  509  sudo apt-get upgrade
  510  sudo apt-get update
  511  gpg --recv-keys F6369E05
  512  sudo gpg --recv-keys F6369E05
  516  ls -la ~/.gnupg/
  517  sudo chown THISUSER\:THISUSER ~/.gnupg/pubring.gpg*
  518  ls -la ~/.gnupg/
  519  gpg --recv-keys F6369E05
  520  gpg --export --armor F6369E05 --output - | apt-key add -
  523  gpg --export --armor F6369E05 --output - | sudo apt-key add -
  524  gpg --recv-keys 58902265
  525  gpg --export --armor 58902265 --output - | sudo apt-key add -
  526  gpg --recv-keys B36C92CA
  528  sudo apt-get update
  529  sudo apt-get install obextool
  530  obextool
  531  obextool --help
  532  echo $OBEXTOOL
  533  lspci
  534  ls /sys/class/bluetooth/
  535  ls -la /sys/class/bluetooth/
  539  obexftp -i -l
  540  obexftp --help
  548  sudo apt-get install bluez-utils
  549  sudo apt-get install bluez
  550  bluetooth-properties
  551  bluetooth-properties --help
  552  bluetooth-properties -d
  553* obexftp -
  554  sudo obexftp -b /org/bluez/1216/hci0/dev_00_0F_DE_BD_42_77 --probe
  555  sudo obexftp -d /org/bluez/1216/hci0/dev_00_0F_DE_BD_42_77 --probe
  556  hcitool scan
  557  sdptool OPUSH 00:0X:XX:XX:XX:XX
  558  sdptool search OPUSH 00:0X:XX:XX:XX:XX
  559  obexftp -d 00:0X:XX:XX:XX:XX --probe
  560  obexftp -b 00:0X:XX:XX:XX:XX --probe
  561  history 100 | xsel -b

$ obexftp -b -Y

=== Probing with FBS uuid.
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
couldn't connect.
.....

$ bluetooth-properties
** Message: adding killswitch idx 0 state 1
** Message: killswitch 0 is 1
** Message: killswitches state 1
** (bluetooth-properties:5051): DEBUG: Unhandled UUID 0000111b-0000-1000-8000-00805f9b34fb (0x111b)


$ bluetooth-properties -d
** (bluetooth-properties:5053): DEBUG: Unhandled UUID 0000111b-0000-1000-8000-00805f9b34fb (0x111b)
Adapter: MYPC-0 (00:09:DD:50:1A:13)
	Default adapter
	Discoverable: True
	Is powered

Device: MyPhoneT630 (00:0X:XX:XX:XX:XX)
	D-Bus Path: /org/bluez/1216/hci0/dev_00_0F_DE_BD_42_77
	Type: Phone Icon: phone
	Paired: True Trusted: True Connected: False
	UUIDs: SerialPort DialupNetworking IrMCSync OBEXObjectPush OBEXFileTransfer Headset_-_AG HandsfreeAudioGateway


$ obexftp --help
ObexFTP 0.23
Usage: obexftp [ -i | -b <dev> [-B <chan>] | -U <intf> | -t <dev> | -N <host> ]
[-c <dir> ...] [-C <dir> ] [-l [<dir>]]
[-g <file> ...] [-p <files> ...] [-k <files> ...] [-x] [-m <src> <dest> ...]
Transfer files from/to Mobile Equipment.
Copyright (c) 2002-2004 Christian W. Zuckschwerdt

 -i, --irda                  connect using IrDA transport (default)
 -b, --bluetooth [<device>]  use or search a bluetooth device
 [ -B, --channel <number> ]  use this bluetooth channel when connecting
 [ -d, --hci <no/address> ]  use source device with this address or number
....

$ obexftp -b /org/bluez/1216/hci0/dev_00_0F_DE_BD_42_77 --probe

=== Probing with FBS uuid.
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Invalid argument
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Invalid argument
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Invalid argument
Still trying to connect
couldn't connect.

$ hcitool scan
Scanning ...
	00:0X:XX:XX:XX:XX	MyPhoneT630

$ sdptool search OPUSH 00:0X:XX:XX:XX:XX
Inquiring ...
Failed to connect to SDP server on 00:0X:XX:XX:XX:XX: Host is down

$ sdptool search OPUSH 00:0X:XX:XX:XX:XX
Inquiring ...
Searching for OPUSH on 00:0X:XX:XX:XX:XX ...
Service Name: OBEX Object Push
Service RecHandle: 0x10005
Service Class ID List:
  "OBEX Object Push" (0x1105)
Protocol Descriptor List:
  "L2CAP" (0x0100)
  "RFCOMM" (0x0003)
    Channel: 10
  "OBEX" (0x0008)
Profile Descriptor List:
  "OBEX Object Push" (0x1105)
    Version: 0x0100

$ obexftp -d 00:0X:XX:XX:XX:XX --probe        # NOWORK

=== Probing with FBS uuid.
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
Connecting...failed: connect
Tried to connect for 0ms
error on connect(): Success
Still trying to connect
couldn't connect.

$ obexftp -b 00:0X:XX:XX:XX:XX --probe        # WORK

=== Probing with FBS uuid.
Connecting..\done
Tried to connect for 433ms
getting null object without type
response code 20
getting empty object without type
Receiving "".../done
response code 20
getting null object with x-obex/folder-listing type
Receiving "(null)"...-done
response code 20
getting empty object with x-obex/folder-listing type
Receiving ""...\done
response code 20
getting null object with x-obex/capability type
Receiving "(null)"...|failed: (null)
response code 44
getting empty object with x-obex/capability type
Receiving ""...-done
response code 20
getting null object with x-obex/object-profile type
Receiving "(null)"...\failed: (null)
response code 44
getting empty object with x-obex/object-profile type
Receiving "".../done
response code 20
getting telecom/devinfo.txt object
Receiving "telecom/devinfo.txt"...-done
response code 20
getting telecom/devinfo.txt object with setpath
Receiving "telecom/devinfo.txt"... Sending ""...\done
|done
response code 20
=== response codes === 20 20 20 20 44 20 44 20 20 20
Disconnecting../done

=== Probing with S45 uuid.
...
=== response codes === 20 20 20 20 44 20 44 20 20 20
Disconnecting..|done

=== Probing without uuid.
...
=== response codes === 20 20 20 20 44 20 44 20 20 20
Disconnecting..\done

End of probe.

$ obextool --help
Define OBEXCMD environment variable to disable this scan!
Scanning for Irda devices
Scanning for bluetooth devices
Using obexftp command: /usr/bin/obexftp -t /dev/ttyS0
ObexTool 0.35
  (c) Gerhard Reithofer, Techn EDV Reithofer, 2003-2008
  ObexTool is licensed using the GNU General Public Licence,
  see http://www.gnu.org/copyleft/gpl.html
Usage: obextool.tk [opt arg]...
 --help
 --version
 --obexcmd obexftp-wrapper-command
 --obexdir obextool-main-directory
 --obexcfg obextool-config-directory
 --setconf key value
 --memstat 0|1
 --debug level
 Use the environment value:
 OBEXTOOL to define an ObexTool main default directory (--obexdir),
 OBEXCMD to define an obexftp default command string (--obexcmd) and
 OBEXTOOL_CFG to define a default config directory (--obexcfg).


$ obextool --obexcmd obexftp -b 00:0X:XX:XX:XX:XX         # NOWORK
Define OBEXCMD environment variable to disable this scan!
Scanning for Irda devices
Scanning for bluetooth devices
Using obexftp command: /usr/bin/obexftp -t /dev/ttyS0
Found ObexTool version 0.35 ...
Found configuration file /etc/obextool/obextool.cfg version 0.35 ...
Error: Invalid option '-b'
....

# QUOTE!

$ obextool --obexcmd 'obexftp -b 00:0X:XX:XX:XX:XX'       # WORK
Define OBEXCMD environment variable to disable this scan!
Scanning for Irda devices
Scanning for bluetooth devices
Using obexftp command: /usr/bin/obexftp -t /dev/ttyS0
Found ObexTool version 0.35 ...
Found configuration file /etc/obextool/obextool.cfg version 0.35 ...
Found configuration file /etc/obextool/obextool.typ version 0.35 ...
Found configuration file /etc/obextool/obextool.ext version 0.35 ...

# GUI WORKS, but NO MULTISELECTION FOR FILE DOWNLOAD

$ cd ~/Desktop/blue/

$ obexftp -b 00:0X:XX:XX:XX:XX -l Pictures
Browsing 00:0X:XX:XX:XX:XX ...
Connecting..\done
Tried to connect for 62ms
Receiving "Pictures"...-<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE folder-listing SYSTEM "obex-folder-listing.dtd">
<!--
Generated by XML Coder.
xml_coder.c (Apr  6 2004 23:42:29)
(C) 2001 Sony Ericsson Mobile Communications AB, Lund, Sweden
-->
<folder-listing version="1.0"><parent-folder/>
<file name="Picture(13).jpg" size="13418"/>
<file name="Picture(12).jpg" size="8715"/>
<file name="Picture(11).jpg" size="13858"/>
<file name="Picture(1).jpg" size="9986"/>
<file name="Picture(10).jpg" size="12009"/>
<file name="Picture(9).jpg" size="18491"/>
<file name="Picture(8).jpg" size="10516"/>
<file name="Picture(7).jpg" size="16850"/>
<file name="Picture(6).jpg" size="13359"/>
<file name="Picture(5).jpg" size="11715"/>
<file name="Picture(4).jpg" size="11824"/>
<file name="Picture(3).jpg" size="14831"/>
<file name="Picture(2).jpg" size="11433"/>
<file name="Fish in phone.jpg" size="5666"/>
<file name="For you.gif" size="3887"/>
<file name="Heart.wbmp" size="134"/>
</folder-listing>
done
Disconnecting..\done

obexftp -b 00:0X:XX:XX:XX:XX -g Pictures # NOWORK

# below work, but still breaks on spaces in filenames!
for ix in $(obexftp -b 00:0X:XX:XX:XX:XX -l Pictures 2>&1 | grep jpg | sed 's/.*name="\([^"]*\)".*/\1/g') ; do \
  echo obexftp -b 00:0X:XX:XX:XX:XX -c /Pictures -g $ix ; \
  obexftp -b 00:0X:XX:XX:XX:XX -c /Pictures -g $ix ; \
done

# with while can capture whole line - and spaces in names:
#
# but fails with exact quotes, actually
#
$ obexftp -b 00:0X:XX:XX:XX:XX -l Pictures | while read LINE ; do ix=$(echo $LINE | grep jpg | sed 's/.*name="\([^"]*\)".*/\1/g'); if [ ! -z "$ix" ] ; then echo obexftp -b 00:0X:XX:XX:XX:XX -c Pictures -g \"$ix\" ; fi ; done

# but this works fine:

$ obexftp -b 00:0X:XX:XX:XX:XX -l Pictures | while read LINE ; do ix=$(echo $LINE | grep jpg | sed 's/.*name="\([^"]*\)".*/\1/g'); if [ ! -z "$ix" ] ; then obexftp -b 00:0X:XX:XX:XX:XX -c Pictures -g "$ix" ; fi ; done
Connecting..\done
Tried to connect for 40ms
Sending "Pictures"...|done
Receiving "Fish in phone.jpg"...|done
Disconnecting../done


Did rotation in F-Spot - that is not enough for firefox;

imagemagick:

(mogrify changes the file - convert converts to another)

for ix in *.jpg; do mogrify -auto-orient $ix; done


