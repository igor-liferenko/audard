################################################################################
# prepend_wav_header.pl                                                        #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################


# call with:
# perl prepend_wav_header.pl ./out16s.dat > out16s.wav

# via [https://ccrma.stanford.edu/courses/422/projects/WaveFormat/ Microsoft WAVE soundfile format]
$filename = $ARGV[0] || die("Need filename as first argument");

$Format         = "WAVE";
$Subchunk1ID    = "fmt ";
$Subchunk1Size  = 16; # 16 for PCM
$AudioFormat    =  1; # PCM = 1 (i.e. Linear quantization)
$NumChannels    =  2; # Stereo = 2
$SampleRate     = 44100;
$BitsPerSample  = 16;
$ByteRate       = $SampleRate*$NumChannels*$BitsPerSample/8;
$BlockAlign     = $NumChannels * $BitsPerSample/8;
$Subchunk2ID    = "data";
#$ExtraParamSize # if PCM, then doesn't exist
#$ExtraParams    #
open IN, "<$filename";
binmode(IN);
{
local $/;     # undef $/; is global
$Data = <IN>; # slurp in one go
}
close(IN);
$Subchunk2Size  = length($Data); #number of bytes in the data.
#print { STDERR } "Subchunk2Size $Subchunk2Size\n";
$ChunkID        = "RIFF";
$ChunkSize      = 4 + (8 + $SubChunk1Size) + (8 + $SubChunk2Size);

# will use symbolic reference to get to vars values;
# enforce array reference by using [] instead of ()
# v  An unsigned short (16-bit) in "VAX" (little-endian) order. (2 bytes)
# V  An unsigned long (32-bit) in "VAX" (little-endian) order. (4 bytes)
@order = (
 [ "ChunkID"        , "A*" ],
 [ "ChunkSize"      , "V" ],
 [ "Format"         , "A*" ],
 [ "Subchunk1ID"    , "A*" ],
 [ "Subchunk1Size"  , "V" ],
 [ "AudioFormat"    , "v" ],
 [ "NumChannels"    , "v" ],
 [ "SampleRate"     , "V" ],
 [ "ByteRate"       , "V" ],
 [ "BlockAlign"     , "v" ],
 [ "BitsPerSample"  , "v" ],
#[ "ExtraParamSize" , "" ],
#[ "ExtraParams"    , "" ],
 [ "Subchunk2ID"    , "A*" ],
 [ "Subchunk2Size"  , "V" ],
 [ "Data"           , "a*" ]
);

$output = "";

foreach my $oitem (@order) {
  $varid = @{$oitem}[0];
  $varval = ${$varid}; # symbolic reference
  $varfmt = @{$oitem}[1];
  if ($varid ne "Data") {
    print { STDERR } "- $oitem $varid - $varfmt - $varval\n";
  }
  $output .= pack ($varfmt, $varval);
}

binmode(STDOUT);
print $output;
