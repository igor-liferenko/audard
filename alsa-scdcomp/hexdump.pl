#!/usr/bin/perl
################################################################################
# hexdump.pl                                                                   #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# perl hexdump.pl --offset 120 --group 4 --add '(H2)*' --add '(B8)*' test.file

use strict;
use warnings;
use Getopt::Long;
use Fcntl qw(SEEK_CUR SEEK_SET);
my $offset = 0;
my $groupsize = 1;
my $length = 128;
my @list=();
my $result = GetOptions (
  "offset=i" => \$offset,
  "group=i"   => \$groupsize,
  "length=i"   => \$length,
  "add=s" => \@list,
);
my $inputfname="";
my $inputfh;
$inputfname = $ARGV[0] if defined $ARGV[0];
if (($inputfname eq "") || ($inputfname eq "-")) {
  printf(STDERR "Opening '%s' STDIN\n", $inputfname);
  $inputfh = *STDIN;
} else {
  printf(STDERR "Opening '%s'\n", $inputfname);
  open ($inputfh, "<$inputfname");
}

binmode($inputfh);
my $startaddr=0;
if( not(defined($startaddr = sysseek($inputfh, $offset, SEEK_SET))) ) {
  printf(STDERR "Cannot seek!\n");
  #~ $startaddr = sysseek($inputfh, 0, 0); // cannot reset like this
  $startaddr = 0; # just avoid errors
}
print(STDERR $startaddr . "\n");

my $buffer=undef;
my $nread;
my $total=0;
while (($nread=sysread($inputfh, $buffer, $groupsize)) > 0) { # , $startaddr
  #~ printf("%08X: nr: %d, buf '%s'\n",$startaddr,$nread,$buffer);
  printf("%08X: ", $startaddr);
  foreach my $tformat (@list) {
    foreach my $tentry (unpack($tformat, $buffer)) {
      printf("%s ", $tentry);
    }
  }
  (my $newbuf = $buffer) =~ s/[^[:print:]]/./g; # make non-printable into '.'
  printf(" '%s'", $newbuf);
  print("\n");
  $startaddr += $nread;
  $total += $nread;
  if ($total > $length) { last; }
}

close($inputfh);

