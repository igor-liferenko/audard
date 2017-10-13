#!/usr/bin/env perl

# for switch/case statements
use Switch;

# http://stackoverflow.com/questions/361752
# "@ARGV is a special variable that contains all the command line arguments. $ARGV[0] is the first argument" (not the script itself!)
# the script itself is $0 !

if (!$ARGV[0]) {
  print "Needs command line argument: \n";
  # die writes: "... at ./parseFile.pl line 12." = "Adding a newline to the die error message suppresses the added line number/scriptname verbage" :
  die "Usage: $0 [filename.txt]\n";
}

$myfile = $ARGV[0];

# http://perl.about.com/od/filesystem/a/perl_parse_tabs.htm
# chomp - "remove any newline character [$/ (the input record separator)] from the end of a string."

open (FILE, $myfile) or die "$!"; # open (FILE, 'mylist.txt');

$lineCount = 0;

$inBinarySection = 0;

$fsize = -s FILE;

print stderr "$myfile: $fsize bytes\n";

while (<FILE>) {
  # each line is read into a catchall variable $_  (which can be implied - left out)
  chomp;

  # increase line counter
  $lineCount = $lineCount + 1;

  #
  if (not($inBinarySection)) {
    if ("$_" eq "Binary:") {
      $inBinarySection = 1;
      last; # break
    }
  }
  #~ else {
    #~ print "else\n";
  #~ } # end if $inBinarySection
}

$loc = tell FILE;
print stderr "Header end, file loc is $loc\n";

#~ $bytechunksize = 8 + 4*2;
$bytechunksize = 8 + 4*8;
$chunkcount = 0;
# here have time + 4 voltage channels
# timestamp looks like 8 bytes - 64 bits - q/Q: quad
# Q. I get "Invalid type 'Q': You're not on a 64-bit box
# then must use "8-byte string" and convert
# "a,A" is "null/space padded string"; "b,B" is "bit (binary) string in ascending/descending bit order"
# +8 bytes remain (seemingly) - than means two per channel
while (read FILE, $incurrentbytes, $bytechunksize) {
  $chunkcount = $chunkcount+1;
  # print "$incurrentbytes"; # just raw bytes
  # unpack "C" is unsigned bytes; c is signed bytes

  @unpackedbytesarray = unpack( "C "x$bytechunksize, $incurrentbytes ); # ok
  #~ @unpackedbytesarray = unpack( "C$bytechunksize ", $incurrentbytes ); # also ok

  #~ $remain = $bytechunksize - 8;
  #~ @unpackedvalsarray = unpack( "A8 C$remain ", $incurrentbytes ); # also ok

  #~ @unpackedvalsarray = unpack( "A8 A2 A2 A2 A2 ", $incurrentbytes );
  #~ @unpackedvalsarray = unpack( "b8 b2 b2 b2 b2 ", $incurrentbytes );
  #~ @unpackedvalsarray = unpack( "B8 B2 B2 B2 B2 ", $incurrentbytes );
  #~ @unpackedvalsarray = unpack( "b8 s s s s ", $incurrentbytes );

  # actually, ./src/frontend/rawfile.c says - all values are double !?
  #~ @unpackedvalsarray = unpack( "b8 b8 b8 b8 b8 ", $incurrentbytes );
  # 'd' - "A double-precision float in native format."
  @unpackedvalsarray = unpack( "d d d d d ", $incurrentbytes );


  #~ print "$unpackedbytesarray\n"; # just an array, will not necesarilly print as expected

  #~ $unpackedarrsize = scalar (@unpackedvalsarray);
  #~ print "\n" . $unpackedarrsize . "\n"; # 5, ok


  #~ foreach $byteitem (@unpackedbytesarray){
    #~ printf "%u ", $byteitem;
  #~ }
  #~ print "\n";

  #~ foreach $byteitem (@unpackedbytesarray){
    #~ # printf "%u ", $byteitem;
    #~ # $byteitem = reverse($byteitem);
    #~ ## printf "%d ", scalar(@byteitem); # length($byteitem) ; # length of string? Not for bytes ?
    #~ printf "%d-", length($byteitem); # scalar(split("", $byteitem)); ? Variable numbers - iterates thrhough individual bytes?
  #~ }
  #~ print "\n";

  #~ for ($count = 0; $count <= $unpackedarrsize; $count++) {
    #~ $tmp = $unpackedvalsarray[$count];
    #~ print length($tmp) . " "; # variable again? it's because it shows the length of string representation of tmp...
  #~ }
  #~ print "\n";

  #~ printf "%02X "x$bytechunksize, @unpackedbytesarray ;
  #~ print "\n";
  printf "%e %e %e %e %e", @unpackedvalsarray;
  print "\n";

  # for limited preview
  #~ if ($chunkcount == 30) {
    #~ last; # break
  #~ }
}

close (FILE);
exit;







