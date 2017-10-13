#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

package _adscompare_run_table_pl;

=head1 README:

call:
perl adscompare_run_table.pl mydir/20130103-*.note > outtable.html

* Assume capture run: succeful:
** both with attengrab.pl - and .DAV/.CSV files from scope

* Get a list of *.note files (from attengrab capture run) on command line
* Iterate through them, find ADS* labels and open corresponding ADS* files
* for each 20*.csv/ADS*.CSV combo:
** parse and get data;
** output data as a line for HTML table

* Output HTML table

=cut

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::Bytes::Human
cpan[2]> install HTML::Entities
cpan[3]> install Number::FormatEng

=cut


use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

#~ use Data::Section -setup; # install Data::Section
# to have hashes of Data::Section in order of appearance:
use Tie::IxHash;

use HTML::Entities;

use feature qw/say switch state/;
use File::Basename;
use Cwd qw/chdir abs_path getcwd/;
my $script_fullpath = abs_path(__FILE__);
my $EXECDIR = dirname($script_fullpath);
my $CALLDIR = getcwd;
my $PS="/"; # path separator
$EXECDIR .= $PS;
$CALLDIR .= $PS;

binmode(STDIN);
binmode(STDOUT);

use Number::Bytes::Human qw(format_bytes);
use Number::FormatEng qw(:all);


# ====================
# do manually without Data::Section, Data::Section::Simple or Inline::Files

# Tie::IxHash will guarantee iterating hash
# in "order of appearance" without need
# for explicit sorting
tie my %sections, "Tie::IxHash"
  or die "could not tie %sections";

my @array = <DATA>;
my $content = join '', @array;
$content =~ s/^.*\n__DATA__\n/\n/s; # for win32
$content =~ s/\n__END__\n.*$/\n/s;
my @data = split /^__\[\s+(.+?)\s*\]__\r?\n/m, $content;
shift @data; # trailing whitespaces

while (@data) {
  my ($name, $content) = splice @data, 0, 2;
  #print $name."\n";
  $sections{$name} = $content;
}
# ====================

# http://rosettacode.org/wiki/CSV_to_HTML_translation#Perl
sub trrow {
  my $elem = shift;
  my @cells = map {"<$elem>$_</$elem>"} split ',', shift;
  print '<tr>', @cells, "</tr>\n";
}

#~ > my ($first, @rest) = map
#~ >     {my $x = $_; chomp $x; encode_entities $x}
#~ >     <STDIN>;

sub trrowa {
  #my $elem = shift;   my @edats = shift; # no, like this:
  #my $indent = "  ";
  my($elem, $indent, @edats) = @_ ;
  my @cells = map {"${indent}${indent}<$elem>$_</$elem>\n"} @edats;
  return "${indent}<tr>\n", @cells, "${indent}</tr>\n";
}

sub elemrowa {
  my($elem, $indent, @edats) = @_ ;
  my @cells = map {"${indent}<$elem>$_</$elem>\n"} @edats;
  return @cells;
}

sub trim {
  $_ = shift; # must shift!
  $_ =~ s/^\s+//; $_ =~ s/\s+$//;
  return $_;
}

sub rtrim {
  $_ = shift; # must shift!
  $_ =~ s/\s+$//;
  return $_;
}

# kill_decimals_engineering_notation
sub kden {
  $_ = shift;
  # two decimals precision: \d{2}
  my $prec = 1;
  # without e - so it handles those that don't have it:
  $_ =~ s/\.(\d{$prec})(\d*)/.$1/; # s/\.(\d{$prec})(.*)e/.$1e/;
  # now also format_pref the e- part:
  $_ =~ s/(e.*)/substr(format_pref("1".$1),1)/e;
  return $_;
}

sub usage()
{
print STDOUT << "EOF";
  usage: perl ${0} *.note > outtable.html
EOF
exit 0;
};


#======= "main"

my @notefiles = @ARGV;
my $files_num = scalar @notefiles;
if (not($files_num)) {
  say "Need at least one file to process";
  usage();
}

my $table_capt = "$0";
my $table_foot = "Table footer";
# th entries - only th, all in one string (via th_template)
my $table_th_entries = "  <th scope='col'>HONE</th>\n  <th scope='col'>HTWO</th>... ";
# table content - tr and td, all in one string
my $table_content = "  <tr>\n  <td>TD1</td>\n  <td>TD2</td>\n  <td>TD2</td>\n  <td>TD2</td>\n  </tr> ...";

# array of arrays (list) for table content
my @tabledata = ();

# first row - table headers
my @tableentryarr = (
  "attengrab filebase", # [0]
  "ADS filebase",       # [1]
  ".csv file size",     # [2]
  ".CSV file size",     # [3]
  ".DAV file size",     # [4]
  ".csv num samples",   # [5]
  ".CSV num samples",   # [6]
  ".DAV num samples",   # [7]
  "mACQ perd [srate]",  # [8] scope Acquire menu,2CH RealTime
  ".CSV sint [srate]",  # [9] Sample Interval from .CSV file
  ".csv sint [srate]",  # [10] trange/num_samples
  ".csv osf [orig]",           # [11] oversample factor from .csv
  ".csv Tdiv",          # [12]
  ".CSV Tdiv",          # [13]
  ".csv Vdiv1",         # [14]
  ".CSV Vdiv1",         # [15]
  ".csv Vdiv2",         # [16]
  ".CSV Vdiv2",         # [17]
  ".csv Voff1",         # [18]
  ".CSV Voff1",         # [19]
  ".csv Voff2",         # [20]
  ".CSV Voff2"          # [21]
);

my $indent = "    ";
my $th_template = rtrim( $sections{'th_template'} );
my $table_template = rtrim( $sections{'table_template'} );

# add header
push (@tabledata, \@tableentryarr); # must push ARRAY ref here, for 2D index!

=head1 teststuff:
print $sections{'th_template'};
print $th_template;
print "\n";
# [http://www.perlmonks.org/?node_id=613264 Using regex in Map function]
# print map {s/($th_template)/${1}/eeg . "\n"} @tableentryarr; # no
# print map { s/$_/$_,hi/; $_ } @tableentryarr; # start
#~ print map { my $a = $_; $a = $th_template; "$a\n"; } @tableentryarr; #nope
# below is the one - note in templ, $_ is actually '$_', so we have to escape

# tester:

my @table_th_entra = map { my $a; ($a = $th_template) =~ s/\$_/"$_"/e; "$a"; } @tableentryarr;
$table_th_entries = join("\n", @table_th_entra);
#print $table_th_entries;

$table_content = "$indent<tr>\n"
  . join("", elemrowa("td", "$indent", @tableentryarr))
  . "$indent</tr>\n";

$table_content .= $table_content;
$table_content .= $table_content;

# chomp only removes one last "\n";
# do in table_content for last tr
chomp($table_content);

# expand variables
my $table_out;
($table_out = $table_template) =~ s/(\${\w+})/${1}/eeg;
$table_out .= "\n";
print $table_out;

=cut

# loop and populate main table array/list
my ($atgfilebase, $adsfilebase, $notepath);
my ($csvfilesize, $CSVfilesize, $DAVfilesize);

# .CSV related
my ($CSVreclen, $CSVsampintch1, $CSVsampintch2, $CSVvuch1, $CSVvuch2, $CSVvscch1, $CSVvscch2, $CSVvoffch1, $CSVvoffch2, $CSVhu, $CSVhs);
# .csv related
my ($atgcsvreclen, $atgsampint, $rtsamprate, $atgcsvfinalts, $osf, $origosf, $atgtoffs, $atghs, $atghu, $atgvscch1, $atgvuch1, $atgvscch2, $atgvuch2, $atgvoffch1, $atgvoffch2);

foreach my $notefile ( @notefiles ) {
  # mark loop w/ label: next like continue - but also like break (with label)
  NOTELOOP: {
    #@tableentryarr = (); # reinit - can't work with master var, as we store refs; go local:
    my @tabentarr = ();

    # get file basename
    # # get match in one line (http://stackoverflow.com/a/3653232/277826):
    # # () provides list context, "m// in list context returns a list"
    # ($filebase) = $notefile =~ /(.*)\.note/;
    # better with check though
    if ( $notefile =~ /\.note/ ) {
      ($atgfilebase) = $notefile =~ /(.*)\.note/;
    } else {
      say "Seems $notefile not a .note file; skipping";
      next NOTELOOP; # or last!
    }

    # extract path from notefile (to prepend to ADS filebase):
    $notepath = dirname($notefile);

    # attengrab now will autoinsert ADS0000X as first word of note
    # get that word as index of files saved by scope on USB flash/key
    open my $file, '<', "$notefile" or die "Can't open $notefile: $!";
    my $firstLine = <$file>;
    close $file;

    # get first word (http://stackoverflow.com/questions/4973229)
    my ($firstword, $rest) = split /\s+/, $firstLine, 2;

    # (TODO: possibly check $firstword)
    # get adsfilebase with path
    $adsfilebase = $notepath . $PS . $firstword;

    # here we have a legal *.note file; add
    $tabentarr[0] = $atgfilebase; # "attengrab filebase"
    $tabentarr[1] = $adsfilebase; # "ADS filebase"

    # get file sizes (bytes)
    $DAVfilesize = -s $adsfilebase . ".DAV";
    $CSVfilesize = -s $adsfilebase . ".CSV";
    $csvfilesize = -s $atgfilebase . ".csv";

    # populate
    $tabentarr[2] = format_bytes($csvfilesize) . "B"; #".csv file size"
    $tabentarr[3] = format_bytes($CSVfilesize) . "B";
    $tabentarr[4] = format_bytes($DAVfilesize) . "B";

    # nusamples, etc - we need to parse CSV, csv; except:
    $tabentarr[7] = 0x4000; # [7] ".DAV num samples",

    # first CSV
    process_CSV();

    $tabentarr[6] = $CSVreclen; #[6]   ".CSV num samples",
    $tabentarr[9] = kden(format_eng($CSVsampintch1)) ." [" . kden(format_eng(1/$CSVsampintch1)) ."]" ; #[9] Sample Interval from .CSV file   ".CSV sint[srate]",
    # ($CSVhu) is always 's' for seconds, so:
    $tabentarr[13] = kden(format_eng($CSVhs)); #[13]   ".CSV Tdiv",
    # $CSVvuch1, $CSVvuch2 always 'V' for volts, so:
    $tabentarr[15] = kden(format_eng($CSVvscch1)); #[15]   ".CSV Vdiv1",
    $tabentarr[17] = kden(format_eng($CSVvscch2)); #[17]   ".CSV Vdiv2",
    $tabentarr[19] = kden(format_eng($CSVvoffch1)); #[19]   ".CSV Voff1",
    $tabentarr[21] = kden(format_eng($CSVvoffch1)); #[21]   ".CSV Voff2"

    # then .csv
    process_csv();

    $tabentarr[5] = $atgcsvreclen; #[5] = ;   ".csv num samples",
    my $rtsamp_period = 1/$rtsamprate;
    $tabentarr[8] = kden(format_eng($rtsamp_period)) ." [" . kden(format_eng($rtsamprate)) ."]"; #[8] = ;   "mACQ perd[srate] = ;", scope Acquire menu,2CH RealTime
    $tabentarr[10] = kden(format_eng($atgsampint)) ." [" . kden(format_eng(1/$atgsampint)) ."]"; #[10] = ;   ".csv sint[srate] = ;", trange/num_samples
    $tabentarr[11] = $osf ." [" . $origosf ."]"; #[11] = ;   ".csv osf",          oversample factor from .csv
    # ($atghu) is always 's' for seconds, so:
    $tabentarr[12] = $atghs; #[12] = ;   ".csv Tdiv",
    # $atgvuch1, $atgvuch2 always 'V' for volts, so:
    $tabentarr[14] = $atgvscch1; #[14] = ;   ".csv Vdiv1",
    $tabentarr[16] = $atgvscch2; #[16] = ;   ".csv Vdiv2",
    $tabentarr[18] = $atgvoffch1; #[18] = ;   ".csv Voff1",
    $tabentarr[20] = $atgvoffch1; #[20] = ;   ".csv Voff2",

    my $relerr_period = ($rtsamp_period-$CSVsampintch1)/$rtsamp_period;
    my $period_factor = $rtsamp_period/$CSVsampintch1;
    #print STDERR kden(format_eng($CSVhs)) ." -- ". $relerr_period ." -- ". $period_factor ." -- ". ( ($osf - int($osf) > 0) ? "osf_frac" : "osf_int" ) ."\n";
    # add data
    push (@tabledata, \@tabentarr); # must push ARRAY ref here, for 2D index!

  } # /NOTELOOP
}

# output HTML table

$table_content = "";

#~ foreach my $row (@tabledata) {
for (my $ix = 0; $ix< scalar(@tabledata); $ix++) {
  my $row = $tabledata[$ix];
  my @tentry = @{$row};

  if ($ix == 0) { # header
    my @table_th_entra = map { my $a; ($a = $th_template) =~ s/\$_/"$_"/e; "$a"; } @tentry;
    $table_th_entries = join("\n", @table_th_entra);
  } else { # data
    $table_content .= "$indent<tr>\n"
      . join("", elemrowa("td", "$indent", @tentry))
      . "$indent</tr>\n";
  }
}

# chomp only removes one last "\n";
# do in table_content for last tr
chomp($table_content);

# expand variables
my $table_out;
($table_out = $table_template) =~ s/(\${\w+})/${1}/eeg;
$table_out .= "\n";

# output
print $table_out;





#======= "main" end

# more subs

# process_adsCSV
sub process_CSV {
  # read in entire file, parse lines and collect data
  # (note: substr goes to end of string iff third arg is omitted!)
  my $adsfnamecsv = "$adsfilebase.CSV";
  my $dopack = 0;
  my $rest;
  open(my $fh,'<',$adsfnamecsv) or die "Cannot open $adsfnamecsv ($!)";
  binmode($fh);
  while (<$fh>) {
    if ($dopack) {
      # we don't need values here as in reparse.pl
      # exit this loop
      last;
    } else {
      if ($_ =~ /Record Length/) {
        ($rest, $CSVreclen) = split /,/, $_, 2;
        chomp($CSVreclen);
      }
      if ($_ =~ /Sample Interval/) {
        # NOTE: Sample interval refers to time domain; NOT voltage!
        my $siboth="";
        ($rest, $siboth) = split /,/, $_, 2;
        chomp($siboth);
        my ($s1h, $s2h) = split / /, $siboth, 2;
        $CSVsampintch1 = substr($s1h,index($s1h,":")+1);
        $CSVsampintch2 = substr($s2h,index($s2h,":")+1);
      }
      if ($_ =~ /Vertical Units/) {
        # NOTE: Voltage
        my $vuboth="";
        ($rest, $vuboth) = split /,/, $_, 2;
        chomp($vuboth);
        $vuboth =~ s/,,//g; # remove ,,
        my ($vu1h, $vu2h) = split / /, $vuboth, 2;
        $CSVvuch1 = substr($vu1h,index($vu1h,":")+1);
        $CSVvuch2 = substr($vu2h,index($vu2h,":")+1);
      }
      if ($_ =~ /Vertical Scale/) {
        # NOTE: Voltage
        my $vscboth="";
        ($rest, $vscboth) = split /,/, $_, 2;
        chomp($vscboth);
        $vscboth =~ s/,,//g; # remove ,,
        my ($vsc1h, $vsc2h) = split / /, $vscboth, 2;
        $CSVvscch1 = substr($vsc1h,index($vsc1h,":")+1);
        $CSVvscch2 = substr($vsc2h,index($vsc2h,":")+1);
      }
      if ($_ =~ /Vertical Offset/) {
        # NOTE: Voltage
        my $vofboth="";
        ($rest, $vofboth) = split /,/, $_, 2;
        chomp($vofboth);
        $vofboth =~ s/,,//g; # remove ,,
        my ($vof1h, $vof2h) = split / /, $vofboth, 2;
        $CSVvoffch1 = substr($vof1h,index($vof1h,":")+1);
        $CSVvoffch2 = substr($vof2h,index($vof2h,":")+1);
      }
      if ($_ =~ /Horizontal Units/) {
        # NOTE: time
        ($rest, $CSVhu) = split /,/, $_, 2;
        chomp($CSVhu);
        $CSVhu =~ s/,,//g; # remove ,,
      }
      if ($_ =~ /Horizontal Scale/) {
        # NOTE: time; == timebase
        ($rest, $CSVhs) = split /,/, $_, 2;
        chomp($CSVhs);
        $CSVhs =~ s/,,//g; # remove ,,
      }
      if ($_ =~ /Second,Volt,Volt/) {
        $dopack = 1;
      }
    }
  }
  close($fh);
}

# process_atgcsv
sub process_csv {

my $atgcsvfile = "$atgfilebase.csv";
my $dopack = 0;
my $rest;

open(my $fh,'<',$atgcsvfile) or die "Cannot open $atgcsvfile ($!)";
binmode($fh);

while (<$fh>) {
  if ($dopack) {
      # we don't need values here as in reparse.pl
      # exit this loop
      last;
  } else {
    if ($_ =~ /Number of samples in data/) {
      # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
      chomp($_);
      my @resp = split / /, $_;   #say "resp:", join("--",@resp);
      my $atgreclen1 = $resp[8];
      # digits only; return match with () capture:
      my $atgreclen2 = ($resp[11] =~ m/(\d+)/)[0];
      if ($atgreclen2 > $atgreclen1) { $atgcsvreclen = $atgreclen2; }
      else { $atgcsvreclen = $atgreclen1; }
    }
    if ($_ =~ /Sampling interval \(screen_range\/num_samples\)/) {
      # NOTE: Sample interval refers to time domain; NOT voltage!
      # (sampling period)
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling interval \(screen_range\/num_samples\)   : //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgsampint = $resp[0];
    }
    if ($_ =~ /Sampling rate \(scope Acquire menu,2CH RealTime\):/) {
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling rate \(scope Acquire menu,2CH RealTime\): //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $rtsamprate = $resp[0];
    }
    if ($_ =~ /final timestep:/) {
      chomp($_);
      # clean up a bit - easier parse:
      $_ =~ s/#  { final timestep: //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgcsvfinalts = $resp[0];
    }
    if ($_ =~ /Oversample factor:/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $osf = $resp[3];
      $origosf = $resp[6];
    }
    if ($_ =~ /Time offset:/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgtoffs = $resp[3];
    }
    if ($_ =~ /Timebase/) {
      # NOTE: time; == timebase
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atghs = $resp[5];
      $atghu = $resp[6];
    }
    if ($_ =~ /Ch1 V\/DIV/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch1 = $resp[5];
      $atgvuch1 = $resp[6];
    }
    if ($_ =~ /Ch2 V\/DIV/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch2 = $resp[5];
      $atgvuch2 = $resp[6];
    }
    # $atgvoffch1 $atgvoffch2
    if ($_ =~ /Ch1 Voffset/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvoffch1 = $resp[3];
    }
    if ($_ =~ /Ch2 Voffset/) {
      # NOTE: Voltage
      chomp($_);
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvoffch2 = $resp[3];
    }
    if ($_ =~ /------------------------/) {
      # there are two of these, but are commented
      # so should be skipped by the engine
      $dopack = 1;
    }
  }
}
close($fh);


}





__DATA__

__[ th_template ]__
    <th scope="col">$_</th>

__[ table_template ]__
<!DOCTYPE html>
<html>

<head>
<style type="text/css">
  table {
    font-family: "Lucida Sans Unicode", "Lucida Grande", Sans-Serif;
    font-size: 12px;
    /*note need for div for right margin
    [http://csscreator.com/node/33404 MARGIN-RIGHT and my TABLE are not getting along. What's the deal? | CSS Creator]*/
    /*margin: 10px;*/
    width: 100%;
    text-align: left;
    border-collapse: collapse;
  }

  /* even rows (1, _2_, 3, _4_) */
  tbody tr:nth-child(2n) {
    background-color: #e8edff;
    background-color: rgba(232,237,255, 0.5);
    white-space:nowrap;
  }
  /* even child (1, _2_, 3, _4_) of even rows */
  /* overrides even rows spec */
  tbody tr:nth-child(2n) td:nth-child(2n) {
    background-color: #e0e4f5;
    background-color: rgba(224,228,245, 0.5);
  }
  /* odd rows (_1_, 2, _3_, 4) */
  tbody tr:nth-child(2n-1) {
    background-color: #eff2ff;
    background-color: rgba(239,242,255, 0.5);
    white-space:nowrap;
  }
  /* even child (1, _2_, 3, _4_) of odd rows */
  /* overrides odd rows spec */
  tbody tr:nth-child(2n-1) td:nth-child(2n) {
    background-color: #e6e9f5;
    background-color: rgba(230,233,245, 0.5);
  }

  /*th row (no work, unless "tbody tr" is spec'd above) */
  thead tr {
    background-color: #d0dafd;
    background-color: rgba(208,218,253, 0.5);
  }
  /* even child (1, _2_, 3, _4_) of th row */
  /* overrides th row spec */
  thead tr th:nth-child(2n) {
    background-color: #cad3f3;
    background-color: rgba(202,211,243, 0.5);
  }

  /* hover mouseover on tr */
  tbody tr:hover {
    color: #a0a;          /*#009;*/
    font-style: italic;
    background-color: #eee;
    background-color: rgba(238,238,238, 0.5);
  }
  /* hover mouseover on tr - bckg colors even columns separate */
  tbody tr:hover td:nth-child(2n) {
    background-color: #eee;
    background-color: rgba(238,238,238, 0.5);
  }

  /* hover mouseover on (tr/)td */
  tbody tr:hover td:hover {
    font-weight: bold;
    font-style: normal;
    /*font-style: italic;*/
  }

  /* bottom borders etc: */

  th {
    color: #039;
    padding: 4px 4px;
    border-bottom: 2px solid #6678b1;
    border-right: 1px solid #9baff1;
    border-left: 1px solid #9baff1;
  }

  td {
    border-bottom: 1px solid #ccc;
    border-right: 1px solid #aabcfe;
    border-left: 1px solid #aabcfe;
    padding-right: 10px;
  }

  tfoot {
    font-size: 11px;
    font-style: italic;
  }

  table caption {
    font-size: 14px;
    font-weight: bold;
    padding: 4px 0px;
  }

th:hover::before, td:hover::before {
  background-color: #ffffaa; /*fallback*/
  /*background-color: rgba(255,255,170,0.3); /* no need anymore, under */
  content: '*\00a0' ;
  height: 150%; /* 100% percent of _initial_ page! ; cannot inherit table min-height here */
  /*left: 0;*/ /*not this:*/
  position: absolute;
  top: 8px; /*y coord of page!*/
  min-width: 5%;  /*inherit of td/th! (but must be explicitly set in CSS); % of _initial_ page, NOT of table! */
  z-index: -1;
}
</style>
</head>

<body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0">

<div style="padding-right: 20pt;">
<table id="mytable">
  <caption>${table_capt}</caption>
  <thead>
    <tr>
${table_th_entries}
    </tr>
  </thead>
  <tfoot>
    <tr>
    <td colspan="100">${table_foot}</td>
    </tr>
  </tfoot>
  <tbody>
${table_content}
  </tbody>
</table>
</div>

</body>

</html>

__END__
