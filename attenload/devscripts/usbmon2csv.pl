#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


$i = 0;
$urbcount = 0;
$outline = "";
$timestampms = 0;
$dirtag = "";
@datarr = [];
$datstr = "";

while($line = <STDIN>) {
	$i++;

	if($line =~ m/Bo|Bi/) {
    my @words = split(/ /, $line);
    my $numwords = @words; # $#words+1;
    my @startwords = splice(@words,0,6);
    # note: after splice, @startwords has first 6 elements; @words has the rest!

    # we expect start with type USB submit (S); conclude with event USB complete (C)
    # ("Event Type. This type refers to the format of the event, not URB type.")
    # only then do we have the info to output entire vis log line
    my ($urbtagaddr,$timestampus,$eventtype,$addrwordpipe, $urbstatus, $datalength)
      = @startwords;

    @addrwordspipe = split(/:/, $addrwordpipe);
    my ($typedirectn,$busnum,$devnum,$epnum) = @addrwordspipe;

    my $datatag = chr(ord($words[0])); # first_letter; for Bi,Bo is either >, <, or =

=cut
    print "urbtagaddr $urbtagaddr
    timestampus $timestampus
    eventtype $eventtype
    addrwordpipe $addrwordpipe
      typedirectn $typedirectn
      busnum $busnum
      devnum $devnum
      epnum $epnum
    urbstatus $urbstatus
    datalength $datalength
    datatag $datatag
    XTRA @words
";
=cut

    if ($eventtype eq "S") {         # URB submit
      $urbcount++; # increase
      $outline = ""; # reset

      # remember timestamp if data is here
      if (($datatag eq ">") or ($datatag eq "<")) {
        $dirtag = $datatag x3;  # > or < - not always?
      } else  {                 # so unconditionally do this, even for those without = !
        $timestampms = int( $timestampus/1000 );
        my @firstout = splice(@words,0,1); # removing previous first elem (the '=')
        $xtradat = join("", @words);
        @datarr = unpack("(a2)*", $xtradat); # usually 32 bytes;
      }
    } elsif ($eventtype eq "C") {    # URB complete
      # remember timestamp if data is here
      if (($datatag eq ">") or ($datatag eq "<")) {
        $dirtag = $datatag x3;          # > or < - not always?
      } else  {                         # so unconditionally do this, even for those without = !
        $timestampms = int( $timestampus/1000 );
        my @firstout = splice(@words,0,1); # removing previous first elem (the '=')
        $xtradat = join("", @words);
        @datarr = unpack("(a2)*", $xtradat); # usually 32 bytes;
      }

      @dat16 = splice(@datarr,0,16);  # get first 16 bytes
      $dat16s = join(" ",@dat16);     # concatenate 16 hex bytes, space separated
      $datstr = pack("(H2)*", @dat16);   # create ASCII representation of first 16 bytes
      $datstr =~ s/[^[:print:]]+/./g; # s/[:^print:]/./g;
      $outline = "$timestampms,URB,$urbcount,$dat16s,$dirtag,$datstr";
      print "$outline\n";
    }
  }
}

