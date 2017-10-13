#!/usr/bin/env perl
################################################################################
# montikz-pdf.pl                                                               #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

# montikz-pdf - interface to pdflatex/tikz/standalone for montaging pdf's
#
# Copyleft 2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

=note: allows to do something like:

  pdfjam -o out.pdf --templatesize '{1190pt}{722pt}' --nup 1x2 --fitpaper false --noautoscale false --paper "" --pagecommand "{\thispagestyle{empty}}" -- path/input1.pdf path/input2.pdf

... but through tikz nodes (allowing autosizing of output document, based on input sizes in the montage):

  perl montikz-pdf.pl -i 'path/input1.pdf:[inner sep=0] (MynodeA) at (0,0)' -i 'path/input2.pdf:[inner sep=0,below=0mm of MynodeA] (MynodeB)' -o out.pdf

... so if `pdfinfo path/input1.pdf | grep 'Page size'` for both input .pdfs is 1188 x 360 pts,
... the `pdfinfo out.pdf | grep 'Page size'` for above example will be 1188 x 720.397 pts

Also, note:
* it is overlay-ready (pdflatex called twice);
* pdflatex is called with -shell-escape, so we can pipe shell output in the document:

  perl montikz-pdf.pl \
  -i 'path/input1.pdf:[inner sep=0] (MynodeA) at (0,0)' \
  -i 'path/input2.pdf:[inner sep=0,below=0mm of MynodeA] (MynodeB)' \
  -i ':\begin{minipage}{\linewidth}{\catcode`_=12\obeylines \bf\ttfamily {\LARGE TEST} \\ \input{|"ls /usr" }}\end{minipage}:[overlay,anchor=north west] (MynodeC) at (-10,0)' \
  -o out.pdf

# use \typeout instead of \input to debug shell commands (also set -x would work)
# note that if you want \( or \) as such to the shell - they must be escaped with \string!
# e.g -i "\input{|\"echo \string\( here \string\) \"}"
# `calc`: (MynodeC) at (\$(current page.west)+(1,0)\$) - `positioning`: [,left=1] (but that doesn't work w/ current page.west)

Tested with Texlive 2011.
=cut

package montikz_pdf_pl;

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error
use utf8; # does not enable Unicode output - it enables you to type Unicode in your program.

use Getopt::Long;
use File::Copy qw(copy);
use Data::Dumper; # for debug

binmode(STDOUT, ":raw");
binmode(STDIN, ":raw");

$SIG{'INT'} = sub {print "Caught Ctrl-C - Exit!\n"; exit 1;};

sub usage()
{

print STDOUT << "EOF";
  montikz-pdf - interface to pdflatex/tikz(w/calc,positioning)/standalone for montaging pdf's

  usage: ${0} [-h] -i inputnodespec [-i inputnodespec] -o outfile
  -h            this help and exit
  -i inputspec: input tikz \\node specification, including input PDF path:
                * format: 'path:tikznodespec' is interpreted as path to graphics; examples:
                 -i '/path/to/input1.pdf:[inner sep=0] (MynodeA) at (0,0)'
                 -i '/path/to/input2.pdf:[inner sep=0,below=0mm of MynodeA] (MynodeB)'
                (can use above=,below=,left=,right= - see tikz/pgf manual [texdoc tikz] for more)
                * if format starts with the separator, as in ':blah blah:(MynodeA)'
                  then the content will be put inside the node verbatim
                  (without \\includegraphics)
  -o outfile:   output pdf file
  --sep CHAR:   separator char/string (default colon `:`) for -i inputspecs
  --no-tidy:    do not delete tmp Latex files
  --verbose:    output some Latex messages
EOF

exit 0;
};


my $TEXPREAMBLE = <<'EOF';
\batchmode % reduce console output
\documentclass{standalone}
\usepackage{graphicx}
\DeclareGraphicsRule{.csv_.pdf}{pdf}{*}{} % consider .csv_.pdf file extension as .pdf
\usepackage{tikz}
\usetikzlibrary{positioning,calc}
\renewcommand{\ttdefault}{pcr} % Using Courier font (has \bfseries)

EOF

my $TEXOPENING = <<'EOF';

\begin{document}
\scrollmode % start showing console output

  % [remember picture] requires building twice:
  \begin{tikzpicture}[remember picture]

EOF

my $TEXCLOSING = <<'EOF';

  \end{tikzpicture}

\batchmode % reduce console output again
\end{document}

EOF

my $exampleTikzNode = <<'EOF';
    % just for documenting:
    \node[inner sep=0] (Mynode) at (0,0){
      \includegraphics{\pathMynodePDF}
    };
EOF


# get original number of cmdline arguments (length)
my $arg_num = scalar @ARGV;
my $firstopt = $ARGV[0];

my $notidy = '';
my $verbose = '';
my $OPTSEP = ':'; # default colon
# get option arguments (will modify ARGV)
my %cmdopts=();
GetOptions( "h"=>\$cmdopts{h},
            "i=s@"=> \$cmdopts{i},
            "o=s"=> \$cmdopts{o},
            "no-tidy"=> \$notidy,
            "verbose"=> \$verbose,
            "sep=s"=> \$OPTSEP) or die($!);
usage() if defined $cmdopts{h};
if ( !($cmdopts{i}) or !($cmdopts{o}) or !($OPTSEP)) {
  if (!($cmdopts{i})) {
    print("At least one input nodespec (file) required!\n");
  }
  if (!($cmdopts{o})) {
    print("Output file required!\n");
  }
  if (!($OPTSEP)) {
    print("If --sep given, then separator charater required!\n");
  }
  usage();
}

#~ print Dumper(%cmdopts);


=note: must have @{ ... } here;
without it, $innodestr later holds 'ARRAY(0x965b078)'
instead of values!
=cut
my @innodes = @{$cmdopts{i}}; #print Dumper(@innodes);
my $outfn = $cmdopts{o};      #print Dumper($outfn);

my $TEXBODY="";
foreach my $innodestr (@innodes) {
  my $isGraphics = 1;
  if ( $innodestr =~ /^$OPTSEP/ ) {
    $isGraphics = 0;
    $innodestr =~ s/^$OPTSEP//s ; # remove the first colon/OPTSEP with regex (else substr)
  }
  my ($inPDFpath, $innodespec) = split($OPTSEP, $innodestr);
  if (!$innodespec) { $innodespec = ""; };
  my $TNODE = "";
  if ($isGraphics) {
    $TNODE = <<"EOF";
    \\node${innodespec}{
      \\includegraphics{${inPDFpath}}
    };
EOF
  } else {
    $TNODE = <<"EOF";
    \\node${innodespec}{
      ${inPDFpath}
    };
EOF
  }
  #print $TNODE;
  $TEXBODY .= $TNODE;
}

my $TEXDOC = $TEXPREAMBLE . $TEXOPENING . $TEXBODY . $TEXCLOSING;

=note: save .tex document as tmp.tex; ...
run pdflatex on it;
then copy (don't move) the tmp.pdf output to destination;
so e.g. evince can autoload changed PDF document!
at end, clean up tmp files
=cut

# remove .pdf extension if found:
(my $ofnbase = $outfn) =~ s/\.pdf//g; #print "$ofnbase\n";
# add .pdf extension if it wasn't there originally
my $ofnpdf = "$ofnbase.pdf";

#my $ofntex = "$ofnbase.tex";          #print "$ofntex\n";
my $TMPB="__tmp";
my $ofntex = "$TMPB.tex";

my $ofh;    # output file handle
open($ofh,'>',$ofntex) or die "Cannot open $ofntex ($!)";
print { $ofh } $TEXDOC;
close($ofh);

my $acmd;

$acmd = "pdflatex -shell-escape $TMPB.tex";
# tikzpicture [remember picture] requires building twice:
# (use backticks, or qx//, to capture output)
my $acmdout = "";
print "Running command `$acmd`...\n";
$acmdout = `$acmd`; #system("$acmd");
if ($verbose) { print "$acmdout"; };
if( $? == -1 ) {
  die "command failed: $!\n";
}
print "Running command `$acmd`...\n";
$acmdout = `$acmd`; #system("$acmd");
if ($verbose) { print "$acmdout"; };
if( $? == -1 ) {
  die "command failed: $!\n";
}

copy "$TMPB.pdf", $ofnpdf;

# delete: rm tmp.aux tmp.log tmp.tex
if ( $notidy ) {
  print "Not deleting $TMPB.* temporary files\n";
} else {
  unlink "$TMPB.pdf" or warn "Could not delete $TMPB.pdf: $!"; # delete it, since it's copied!
  unlink "$TMPB.aux" or warn "Could not delete $TMPB.aux: $!";
  unlink "$TMPB.log" or warn "Could not delete $TMPB.log: $!";
  unlink "$TMPB.tex" or warn "Could not delete $TMPB.tex: $!";
}

my $filesize = -s "$ofnpdf";
print "$0 finished; output is in $ofnpdf ($filesize)\n";

__END__

