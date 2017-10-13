#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


my $ts="";
my $dl="";
my @ats=[];

while(<>) {
  chomp;
  ($_ =~ /ms/) && do {
    @ats=split(/ /,$_);
    substr($ats[0], 0, 1) = "";
    $ts=$ats[0] . "," . $ats[5] . "," . $ats[6];
  };
  ($_ =~ "00000000:") && do {
    $dl=join(" ", splice( @{[split(/ /,$_)]},5) );
    $datstr = pack("(H2)*",split(/ /,$dl));   # create ASCII representation
    $datstr =~ s/[^[:print:]]+/./g; # replace non-printable chars
    print "$ts,$dl," . $ats[3] . "," . " " . $datstr . "\n" ;
  }
};


