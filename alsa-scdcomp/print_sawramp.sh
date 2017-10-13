#!/usr/bin/env bash
################################################################################
# print_sawramp.sh                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# see below at end of this file, for the
# expected output of this script

GPTERM="wx" # or "x11"


echo "Generating out16s.dat ... "

set -x
perl genbindata_sawramp_16s.pl > out16s.dat
{ set +x; } 2>/dev/null

echo "out16s.dat created; can be opened in Audacity via: File/Import/Raw Data; and then:
Encoding: Signed 16-bit PCM; Byte order: Little-endian; Channels: 2 Channels (Stereo)
"

echo "Generating out16s.wav ... "

set -x
perl prepend_wav_header.pl ./out16s.dat > out16s.wav
{ set +x; } 2>/dev/null

echo "out16s.wav created; can be opened directly via: audacity out16s.wav
"

set -x
du -b out16s.dat
# 262144	out16s.dat
du -b out16s.wav
# 262188	out16s.wav
{ set +x; } 2>/dev/null

echo -e "\nout16s.dat start as 8-bit \n"

# output first 12 bytes; with address in decimal format;
# in groups of four bytes: in hex format; as unsigned int; as signed int
hexdump -v -n 12 \
  -e '1/ "%08_ad: "' \
  -e '4/1 "0x%02x "' \
  -e '" -> "' \
  -e '4/1 "% 5u,"' \
  -e '" | "' \
  -e '4/1 "% 5d,"' \
  -e '"\n"' \
out16s.dat


# in perl - since hexdump has no binary format (and in xxd cannot control it)
# output first 12 bytes;
perl -e 'use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use Data::Dumper;
$nl=12; $sk=0; $gb=4;
$addrs=$sk; $addre=$addrs+$nl;
open IN, "<./out16s.dat";
binmode(IN);
for($addr=$addrs;$addr<$addre;$addr+=$gb){
  seek(IN,$addr,SEEK_SET);
  read IN, $temp, $gb;
  # unpack returns an array, must join to print it all!
  # print join(" ",unpack("(H2)*", $temp)) . "\n";
  print sprintf("%08d: ", $addr) ;
  @tmpu = unpack("(C1)*", $temp);
  foreach(@tmpu) {
    #print sprintf("0x%s", $_), " "; # %s for (H2)* (is string)!
    print sprintf("0x%02X", $_), " "; # %X for (C1)*!
  }
  print "->  ";
  foreach(@tmpu) {
    print sprintf("%4u,", $_), " ";
  }
  print "|  ";
  foreach(unpack("(c1)*", $temp)) {
    print sprintf("%4d,", $_), " "; # % (c1)* for %d (signed)!
  }
  print "\n";
  print sprintf("% 8s: ", "");
  foreach(@tmpu) {
    #print sprintf("%08b,", $_), " ";
    # like this, below is same as sprintf "%08b:
    # (join just formally because array, else it doesnt print since one elem only)
    # both B* and (B8)* work the same (B4 truncates!)
    print join("/", unpack("(B8)*", pack("C", $_))) . ", ";
  }
  print "\n";
}
close(IN);
'

echo -e "\nout16s.dat start as 16-bit \n"

# output first 12 bytes; with address in decimal format;
# in groups of two sint(16): in hex format; as unsigned int; as signed int
hexdump -v -n 12 \
  -e '1/ "%08_ad: "' \
  -e '2/2 "0x%04x "' \
  -e '" -> "' \
  -e '2/2 "% 7u,"' \
  -e '" | "' \
  -e '2/2 "% 7d,"' \
  -e '"\n"' \
out16s.dat

# in perl - since hexdump has no binary format (and in xxd cannot control it)
# output first 12 bytes; in groups of two sint(16):
perl -e 'use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use Data::Dumper;
$nl=12; $sk=0; $gb=4;
$addrs=$sk; $addre=$addrs+$nl;
open IN, "<./out16s.dat";
binmode(IN);
for($addr=$addrs;$addr<$addre;$addr+=$gb){
  seek(IN,$addr,SEEK_SET);
  read IN, $temp, $gb;
  # unpack returns an array, must join to print it all!
  # print join(" ",unpack("(H2)*", $temp)) . "\n";
  print sprintf("%08d: ", $addr) ;
  @tmpu = unpack("(S1)*", $temp);
  foreach(@tmpu) {
    print sprintf("0x%04X", $_), " "; # %X for (C1)*!
  }
  print "->  ";
  foreach(@tmpu) {
    print sprintf("%6u,", $_), " ";
  }
  print "|  ";
  foreach(unpack("(s1)*", $temp)) {
    print sprintf("%6d,", $_), " "; # % (c1)* for %d (signed)!
  }
  print "\n";
  print sprintf("% 8s: ", "");
  foreach(@tmpu) {
    #print sprintf("%08b,", $_), " ";
    # like this, below is same as sprintf "%08b:
    # (join just formally because array, else it doesnt print since one elem only)
    # here B* and (B16)* do NOT work the same (B4 truncates!)
    # here MUST specify > to enforce big-endian byte order?
    print join("/", unpack("(B16)*", pack("S>", $_))) . ", ";
  }
  print "\n";
}
close(IN);
'

echo -e "\nout16s.dat last as 8-bit \n"

# now last 12 bytes (using skip)
FSZB=$(du -b out16s.dat |cut -f1)
hexdump -v -n 12 \
  -s $(( $FSZB - 12)) \
  -e '1/ "%08_ad: "' \
  -e '4/1 "0x%02x "' \
  -e '" -> "' \
  -e '4/1 "% 5u,"' \
  -e '" | "' \
  -e '4/1 "% 5d,"' \
  -e '"\n"' \
out16s.dat

# in perl - since hexdump has no binary format (and in xxd cannot control it)
# output last 12 bytes;
perl -e 'use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use Data::Dumper;
$nl=12; $sk='"$(( $FSZB - 12 ))"'; $gb=4;
$addrs=$sk; $addre=$addrs+$nl;
open IN, "<./out16s.dat";
binmode(IN);
for($addr=$addrs;$addr<$addre;$addr+=$gb){
  seek(IN,$addr,SEEK_SET);
  read IN, $temp, $gb;
  # unpack returns an array, must join to print it all!
  # print join(" ",unpack("(H2)*", $temp)) . "\n";
  print sprintf("%08d: ", $addr) ;
  @tmpu = unpack("(C1)*", $temp);
  foreach(@tmpu) {
    #print sprintf("0x%s", $_), " "; # %s for (H2)* (is string)!
    print sprintf("0x%02X", $_), " "; # %X for (C1)*!
  }
  print "->  ";
  foreach(@tmpu) {
    print sprintf("%4u,", $_), " ";
  }
  print "|  ";
  foreach(unpack("(c1)*", $temp)) {
    print sprintf("%4d,", $_), " "; # % (c1)* for %d (signed)!
  }
  print "\n";
  print sprintf("% 8s: ", "");
  foreach(@tmpu) {
    #print sprintf("%08b,", $_), " ";
    # like this, below is same as sprintf "%08b:
    # (join just formally because array, else it doesnt print since one elem only)
    # both B* and (B8)* work the same (B4 truncates!)
    print join("/", unpack("(B8)*", pack("C", $_))) . ", ";
  }
  print "\n";
}
close(IN);
'

echo -e "\nout16s.dat last as 16-bit \n"

hexdump -v -n 12 \
  -s $(( $FSZB - 12)) \
  -e '1/ "%08_ad: "' \
  -e '2/2 "0x%04x "' \
  -e '" -> "' \
  -e '2/2 "% 7u,"' \
  -e '" | "' \
  -e '2/2 "% 7d,"' \
  -e '"\n"' \
out16s.dat

# in perl - since hexdump has no binary format (and in xxd cannot control it)
# output last 12 bytes; in groups of two sint(16):
perl -e 'use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use Data::Dumper;
$nl=12; $sk='"$(( $FSZB - 12 ))"'; $gb=4;
$addrs=$sk; $addre=$addrs+$nl;
open IN, "<./out16s.dat";
binmode(IN);
for($addr=$addrs;$addr<$addre;$addr+=$gb){
  seek(IN,$addr,SEEK_SET);
  read IN, $temp, $gb;
  # unpack returns an array, must join to print it all!
  # print join(" ",unpack("(H2)*", $temp)) . "\n";
  print sprintf("%08d: ", $addr) ;
  @tmpu = unpack("(S1)*", $temp);
  foreach(@tmpu) {
    print sprintf("0x%04X", $_), " "; # %X for (C1)*!
  }
  print "->  ";
  foreach(@tmpu) {
    print sprintf("%6u,", $_), " ";
  }
  print "|  ";
  foreach(unpack("(s1)*", $temp)) {
    print sprintf("%6d,", $_), " "; # % (c1)* for %d (signed)!
  }
  print "\n";
  print sprintf("% 8s: ", "");
  foreach(@tmpu) {
    #print sprintf("%08b,", $_), " ";
    # like this, below is same as sprintf "%08b:
    # (join just formally because array, else it doesnt print since one elem only)
    # here B* and (B16)* do NOT work the same (B4 truncates!)
    # here MUST specify > to enforce big-endian byte order?
    print join("/", unpack("(B16)*", pack("S>", $_))) . ", ";
  }
  print "\n";
}
close(IN);
'



# http://stackoverflow.com/questions/14472419/plotting-1d-binary-array-uint8-with-multiple-records-in-gnuplot
# http://stackoverflow.com/questions/5826701/plot-audio-data-in-gnuplot/17584953

gnuplot -p -e "set terminal $GPTERM ; set multiplot layout 2,1 ; \
set yrange [-32768:32767] ; \
unset xtics ; \
plot 0 ls 2, 'out16s.dat' binary format='%int16%int16' using 0:1 with lines ls 1; \
set xtics auto ; \
plot 0 ls 2, 'out16s.dat' binary format='%int16%int16' using 0:2 with lines ls 1; \
unset multiplot"



: <<"COMMENT"

$ bash print_sawramp.sh
Generating out16s.dat ...
+ perl genbindata_sawramp_16s.pl
out16s.dat created; can be opened in Audacity via: File/Import/Raw Data; and then:
Encoding: Signed 16-bit PCM; Byte order: Little-endian; Channels: 2 Channels (Stereo)
+ du -b out16s.dat
262144	out16s.dat

out16s.dat start as 8-bit

00000000: 0x00 0x80 0xff 0x7f ->     0,  128,  255,  127, |     0, -128,   -1,  127,
00000004: 0x01 0x80 0xfe 0x7f ->     1,  128,  254,  127, |     1, -128,   -2,  127,
00000008: 0x02 0x80 0xfd 0x7f ->     2,  128,  253,  127, |     2, -128,   -3,  127,
00000000: 0x00 0x80 0xFF 0x7F ->     0,  128,  255,  127, |     0, -128,   -1,  127,
        : 00000000, 10000000, 11111111, 01111111,
00000004: 0x01 0x80 0xFE 0x7F ->     1,  128,  254,  127, |     1, -128,   -2,  127,
        : 00000001, 10000000, 11111110, 01111111,
00000008: 0x02 0x80 0xFD 0x7F ->     2,  128,  253,  127, |     2, -128,   -3,  127,
        : 00000010, 10000000, 11111101, 01111111,

out16s.dat start as 16-bit

00000000: 0x8000 0x7fff ->   32768,  32767, |  -32768,  32767,
00000004: 0x8001 0x7ffe ->   32769,  32766, |  -32767,  32766,
00000008: 0x8002 0x7ffd ->   32770,  32765, |  -32766,  32765,
00000000: 0x8000 0x7FFF ->   32768,  32767, |  -32768,  32767,
        : 1000000000000000, 0111111111111111,
00000004: 0x8001 0x7FFE ->   32769,  32766, |  -32767,  32766,
        : 1000000000000001, 0111111111111110,
00000008: 0x8002 0x7FFD ->   32770,  32765, |  -32766,  32765,
        : 1000000000000010, 0111111111111101,

out16s.dat last as 8-bit

00262132: 0xfd 0x7f 0x02 0x80 ->   253,  127,    2,  128, |    -3,  127,    2, -128,
00262136: 0xfe 0x7f 0x01 0x80 ->   254,  127,    1,  128, |    -2,  127,    1, -128,
00262140: 0xff 0x7f 0x00 0x80 ->   255,  127,    0,  128, |    -1,  127,    0, -128,
00262132: 0xFD 0x7F 0x02 0x80 ->   253,  127,    2,  128, |    -3,  127,    2, -128,
        : 11111101, 01111111, 00000010, 10000000,
00262136: 0xFE 0x7F 0x01 0x80 ->   254,  127,    1,  128, |    -2,  127,    1, -128,
        : 11111110, 01111111, 00000001, 10000000,
00262140: 0xFF 0x7F 0x00 0x80 ->   255,  127,    0,  128, |    -1,  127,    0, -128,
        : 11111111, 01111111, 00000000, 10000000,

out16s.dat last as 16-bit

00262132: 0x7ffd 0x8002 ->   32765,  32770, |   32765, -32766,
00262136: 0x7ffe 0x8001 ->   32766,  32769, |   32766, -32767,
00262140: 0x7fff 0x8000 ->   32767,  32768, |   32767, -32768,
00262132: 0x7FFD 0x8002 ->   32765,  32770, |   32765, -32766,
        : 0111111111111101, 1000000000000010,
00262136: 0x7FFE 0x8001 ->   32766,  32769, |   32766, -32767,
        : 0111111111111110, 1000000000000001,
00262140: 0x7FFF 0x8000 ->   32767,  32768, |   32767, -32768,
        : 0111111111111111, 1000000000000000,

COMMENT

