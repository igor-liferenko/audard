#!/usr/bin/env bash

# to list available tags?:
# exiftool -list | grep -i 'source\|comment\|credit'
# URL, CreatorWorkURL
# Warning: Sorry, PublisherURL is not writable
# Warning: Sorry, SourceURL is not writable

# for .gif, URL does not work:
#    0 image files updated
#    1 image files unchanged
# it can work with -LastUrl= ... set both just in case

# list all tags in file:
# exiftool -f test.png

# set a tag 'comment'
# exiftool -comment=wow test.png

if [ ! "$1" ] ; then
  echo "need URL to image as first argument"
fi

# second argument - optional filename
OFN=""
WOFN=""
if [ "$2" ] ; then
  OFN="$2"
  WOFN="-O "
fi

# note: $WOFN"$OFN" will cause "http://: Invalid host name." when empty
# but it doesn't harm anything

wget "$1" $WOFN"$OFN" 2>&1 | tee wgetlog
# echo "Saving to: \`LXF130.audio.layers.png.1'" | sed "s/.*\`\(.*\)'/\1/"
OFN=$(sed -n "s/^Saving.*\`\(.*\)'/\1/p" wgetlog)
rm wgetlog

echo OFN: $OFN
echo Saving URL
exiftool -URL="$1" "$OFN"
exiftool -LastUrl="$1" "$OFN"

read -p "Paste page URL to save (or just [Enter] for none)? " PAGEURL

if [ "$PAGEURL" ]; then
  echo "Saving page url as CreatorWorkURL..."
  exiftool -CreatorWorkURL="$PAGEURL" "$OFN"
else
  echo "Not saving page url..."
fi

echo "Cleanup exiftool _original ..."
rm "$OFN"_original

echo "Check at end:"
echo
exiftool -f "$OFN" | grep 'Image\|File\|URL'
