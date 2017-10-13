#!/usr/bin/perl -w

# based on Word Count Script+ http://www.perlmonks.org/?node_id=168456
# perl /path/to/wcp.pl /path/to/file.txt && less results.txt

use strict;
#~ print "Enter a filename to analyze: ";
#~ my $file_read = <STDIN>;
my $file_read = $ARGV[0];
chomp $file_read;
my %w_counter = ();
my %c_counter = ();
my $totalcount = 0;
my $charcount = 0;
my $p_val = 0;
my $var;
my $avglen;

my @histog;
my @histogc;

open(FILE, "$file_read") or die "Could not open file: $!\n";
my @array = <FILE>;
close FILE;

foreach (@array) {
    if (/\b\w+\-\w+\-$/) {
      s/\n/ /sg;
      $var .= $_;
    }
    elsif (/\b-$/) {
      s/\b\-\n+/ /sg;
      $var .= $_;
    }
    else {
      s/\n/ /sg;
      $var .= $_;
    }
}
$var =~ s/-{2}/ /g;
$var =~ tr/[A-Z]/[a-z]/;
my $expr = q/([\w]+[-]?[']?(?:\w*)?[-]?(?:\w*)?)/;
my $subexpr = qr/$expr/;
while ($var =~ /$subexpr/g) {
    $w_counter{$1}++;
}

sub sort_byval_w {
    $w_counter{$b} <=> $w_counter{$a};
}
open(RESULTS, ">results.txt");
foreach my $key (sort sort_byval_w(keys %w_counter)) {
    my $tlen = length($key);
    print RESULTS "The word $key ($tlen chars) was seen $w_counter{$key} times\n";
    $histog[$tlen]++;
    $histogc[$tlen] += $w_counter{$key};
    $totalcount += $w_counter{$key};
}

open(FILE, "$file_read") or die "Could not open file: $!\n";

while (<FILE>) {
    while(/(.)/sg) {
            $c_counter{$1}++;
    }
}
close FILE;

sub sort_byval_c {
    $c_counter{$b} <=> $c_counter{$a};
}

foreach my $key (sort sort_byval_c(keys %c_counter)) {
my $space = " ";
        if ($key =~ /\t/) {
            $p_val = $c_counter{$key};
            delete $c_counter{$key};
            $key = "<TAB>";
            $c_counter{$key} = "$p_val";
        }
        elsif ($key eq "$space") {
            $p_val = $c_counter{$key};
            delete $c_counter{$key};
            $key = "<SPACE>";
            $c_counter{$key} = "$p_val";
        }
        elsif ($key =~ /\n/) {
            $p_val = $c_counter{$key};
            delete $c_counter{$key};
            $key = "<NEWLINE>";
            $c_counter{$key} = "$p_val";
        }
        elsif ($key =~ /\r/) {
            $key = "<RETURN>";
            $p_val = $c_counter{$key};
            delete $c_counter{$key};
            $c_counter{$key} = "$p_val";
        }
        print RESULTS "The char $key was seen $c_counter{$key} times\n
+";
        $charcount += $c_counter{$key};
}

## Get avg numb words per sentance

if ( !($c_counter{"."}) ) { $c_counter{"."} = 0; }
if ( !($c_counter{"?"}) ) { $c_counter{"?"} = 0; }
if ( !($c_counter{"!"}) ) { $c_counter{"!"} = 0; }

my $sentences = $c_counter{"."} + $c_counter{"?"} + $c_counter{"!"};
my $avgwords_sent = $totalcount / $sentences;
my $avgwords_tot = $charcount / $totalcount;

my $histrep = "";
my $histrep2 = "";
my $tmph = 0;
my $tmpc = 0;

for my $i (0 .. $#histog) {
  if ( !($histog[$i]) ) { $histog[$i] = 0; }
  if ( !($histogc[$i]) ) { $histogc[$i] = 0; }
  $tmph += $histog[$i];
  $tmpc += $histogc[$i];
  $histrep .= " of " . sprintf("%3d", $i) . "-ltrs: " . sprintf("%3d", $histog[$i]) . " words; cmlt: " .  sprintf("%3d", $histogc[$i]) . " (tot uniqwrds: " . sprintf("%3d", $tmph) . "; tot clmt: " . sprintf("%3d", $tmpc) . "),\n";
  #~ $histrep2 .= " $i: $tmph, ";
}

print RESULTS "\n";
print RESULTS "-----------------------------\n";
print RESULTS "histog:\n$histrep \n";
#~ print RESULTS "histog: $histrep2 \n";
print RESULTS "-----------------------------\n";
print RESULTS "Total characters are: $charcount\n";
print RESULTS "Total words: $totalcount\n";
print RESULTS "Average words per sentence is: $avgwords_sent\n";
print RESULTS "Average length of words is: $avgwords_tot\n";
close RESULTS;
print "See results.txt for your results\n";

