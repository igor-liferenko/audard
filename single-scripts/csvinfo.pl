use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

use feature qw/say switch state/;
use File::Basename;
use Cwd qw/chdir abs_path getcwd/;
my $script_fullpath = abs_path(__FILE__);
my $EXECDIR = dirname($script_fullpath);
my $CALLDIR = getcwd;
my $PS="/"; # path separator
$EXECDIR .= $PS;
$CALLDIR .= $PS;

# use Tie::CSV_File; # install fails
use Text::CSV;
use List::Util qw/max min/;

binmode(STDIN);
binmode(STDOUT);

$| = 1; # $|++; # set flushing of output buffers ALREADY HERE;

if ($#ARGV < 0) {
 print STDERR "usage:
perl csvinfo.pl filename.csv
\n";
 exit 1;
}

my $csvfile = $ARGV[0];
print "Parsing $csvfile ...\n";

# only comments or numbers expected in .csv data


my $csv = Text::CSV->new( { binary => 1 } );

open (CSV, "<", $csvfile) or die $!;

my @rows;
my @anumcols;
my $rowcount = 0;

while (<CSV>) {
    #~ next if ($. == 1); # $. - line number
    # skip comments
    next if ($_ =~ /^#/);
    if ($csv->parse($_)) {
        my @columns = $csv->fields();
        push @rows, \@columns;
        my $numcol = scalar(@columns);
        my $notfound = 1;
        foreach my $nc ( @anumcols ) {
          if ($numcol == $nc) { $notfound = 0; last; } # break if found
        }
        if ($notfound == 1) { push @anumcols,$numcol; }
        $rowcount++;
    } else {
        my $err = $csv->error_input;
        print "Failed to parse line: $err\n";
    }
}
close CSV;

my $numcols = max( @anumcols );

print "Numrows: $rowcount; anumcols: @anumcols; numcols: $numcols \n";

for(my $icol=0; $icol<$numcols; $icol++) {
  #~ my @colarray = @rows->[$_]->[$icol],$/ for (0..$rowcount-1);
  my @colarray = ();
  push @colarray,$rows[$_][$icol] for (0..$rowcount-1);
  print "Col $icol: min ", min(@colarray), ", max ", max(@colarray), "\n";
}
