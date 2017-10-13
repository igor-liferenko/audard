## to be used as cron; has to be run as sudo .. 
## note - first time on server: 
## $ sudo crontab -e
## [sudo] password for USER: 
## no crontab for root - using an empty one


# http://stackoverflow.com/questions/296536/urlencode-from-a-bash-script
# echo "$encodedurl" below for newline ... 
url_encode() {
 [ $# -lt 1 ] && { return; }

 encodedurl="$1";

 # make sure hexdump exists, if not, just give back the url
 [ ! -x "/usr/bin/hexdump" ] && { return; }

 encodedurl=`
   echo "$encodedurl" | hexdump -v -e '1/1 "%02x\t"' -e '1/1 "%_c\n"' |
   LANG=C awk '
     $1 == "20"                    { printf("%s",   "+"); next } # space becomes plus
     #$1 ~  /0[adAD]/               {                      next } # strip newlines
     $1 ~  /0[adAD]/               { printf("%s",   "%0A"); next } # transform newline
     $2 ~  /^[a-zA-Z0-9.*()\/-]$/  { printf("%s",   $2);  next } # pass through what we can
                                   { printf("%%%s", $1)        } # take hex value of everything else
   '`
   echo "$encodedurl" # return
}


# server address to check 
SRVADDR="server-to-check.com"

# link to a file on server to check (via download test) 
SRVLINK="http://${SRVADDR}/favicon.ico"

# link to php email bridge on server: 
MBRDG="http://server-with-php-email.com/mailbridge.php" 

#~ echo $SRVADDR $SRVLINK $MBRDG

# get own IP address: wget -qO- whatismyip.org
# also: curl -s checkip.dyndns.org | grep -Eo '[0-9\.]+'
# checkip.dyndns.org: "<html><head><title>Current IP Check</title></head><body>Current IP Address: XX.XX.XX.XX</body></html>"
OWNIPSRV="checkip.dyndns.org" # "whatismyip.org" 
OWNIPREP=$(wget --timeout=2 -qO- $OWNIPSRV 2>&1)
OWNIP=$(echo $OWNIPREP | grep -Eo '[0-9\.]+')
#~ echo "$OWNIPREP"
#~ echo "$OWNIP"

# ping first - count of 4 pings, timeout 2 secs
PINGREP=$(ping -c 4 -W 2 $SRVADDR 2>&1)

#~ echo "$PINGREP"

# test file download; timeout=2 seconds
# --no-verbose is just "2011-01-10 09:59:22 URL:$SRVLINK [10000/10000] -> "/dev/null" [1]"
FDOWREP=$(wget --tries=1 --timeout=2 $SRVLINK -O /dev/null 2>&1)

#~ echo "$FDOWREP"

# try set to current address, if OWNIP not empty 
SETREP=""
if [ ! -n "$OWNIP" ]
then
	SETREP=$(sudo noip2 -i $OWNIP 2>&1)
fi

# get DUC status
DUCREP=$(sudo noip2 -S 2>&1)

# got it all, prepare report and send mail

POSTMSG="Report from server test: 

Own public IP: $OWNIP
---
$PINGREP
---
$FDOWREP
---
$SETREP
---
$DUCREP
"

DATE=$(date +%c)
POSTSUBJ="Check: $DATE for $SRVADDR"

# newlines in wget POST: http://www.mail-archive.com/wget@sunsite.dk/msg05718.html

PM=$(url_encode "$POSTMSG")
PS=$(url_encode "$POSTSUBJ")

#~ echo "$POSTMSG"
#~ echo "$PM"

POSTSTR="sub=$PS&msg=$PM"

# don't include dblquotes in \"$POSTSTR\"! 
MAILCMD="wget --timeout=2 --post-data=$POSTSTR --no-verbose $MBRDG -O -"
MAILREP=$($MAILCMD 2>&1)

#~ echo $MAILCMD
echo "$0: $MAILREP" | tee -a /var/log/syslog


