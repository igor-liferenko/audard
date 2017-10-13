#!/usr/bin/env perl
# call w.
# cat something | ./grabFormatLinks.pl > fmtLinks.txt

#~ use re "debug" ;
use Switch; # switch/case

use URI::Title qw( title );
use URI::Find::Simple qw( list_uris );

#~ my $REGEX="http.*?://([^\s)\"](?!ttp:))+"; # as in cmdline; \s fails in double quotes in script! so like below:
my $REGEX='http.*?://([^\s)"](?!ttp:))+';

my @hrefs = ();

$text="";
while ( my $string = <> ) {
  $text .= $string;  # append
  while ( $string =~ m/($REGEX)/g ) {
    #~ print "@- $&\n";
    push @hrefs, ("$&");
    #~ print "$#hrefs: @hrefs[$#hrefs] \n";
  }
}

#~ print "$text";

# via URI::Find::Simple
my @hreflist = list_uris($text);
#~ my $html = change_uris($text, sub { "<a href=\"$_[0]\">$_[0]</a>" } );
# it seems change_uris cannot deal with individual titles..

# my REGEX seems a bit more robust?
print "\n";
printf ("%d -- %d\n", $#hrefs+1, $#hreflist+1);
print "@hrefs \n";
print "@hreflist \n";

print "\nParse done. Formatting... \n\n";

#~ return # for debug

# formatted arrays - first item is name
my @MarkdownLinks = ("Markdown");
my @HtmlLinks = ("Html"); # TODO

# collection of all formatted arrays
my @formats = (@MarkdownLinks);


my @hreftitles = ();


# have to retrieve titles - in sync

#~ for my $link (@hrefs) {
foreach my $linkid (0..$#hrefs) {
  $link=$hrefs[$linkid];

  my $title = title($link);
  push @hreftitles, ("$title");
  print "$link: $title\n";
} # end for

#~ print "@hreftitles\n";
print "\n";

for my $format (@formats) {
  print "FF: $format ... ${formats[0]} \n";

  switch ($formats[0]) {
    case /^Markdown/ {
      foreach my $linkid (0..$#hrefs) {
        my $frmtdlink="[${hreftitles[$linkid]}](${hrefs[$linkid]})";
        push @MarkdownLinks, ("$frmtdlink");
        #~ print "$frmtdlink\n";
      }
    }
  } # end switch
} # end for


print "\n";

# concatenate items in array
my $MarkdownLinksTxt = join "\n", @MarkdownLinks;
# ... and print out
print "$MarkdownLinksTxt\n";

