#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE


package attengrab_repair_pl;

=head1 Requirements:

sudo perl -MCPAN -e shell
...
cpan[1]> install Number::FormatEng
cpan[2]> install File::Copy
cpan[3]> install Term::ReadKey

=cut

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

=head1 note:

call with:
perl attengrab-repair.pl *.note

If attengrap/adsparse-wave fails, we expect:
* ok files: *.bmp, *.ssf and *.note
* bad files: *.csv (truncated, no size/record length info, bad osf factor); *.gnuplot (same)

Thus, we need the record length info (and possibly osf) externally!
* From hash/dict in attenScopeIncludes.pm ...

So this script should:
* read ADS* first word from a *.note file;
* check if ADS*.CSV or ADS*.DAV exist in same directory
* if .CSV exists - parse it, and re-create .csv/.gnuplot based on its data
* if .DAV exists - parse it, and re-create .csv/.gnuplot based on its data
* if both exist - prefer DAV? or "multiplex" samples if possible?
** preferring DAV for now, easier...


=cut


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


# %timediv_srate_map: map between time/DIV and sample rates on (ADS1202CL+) scope
# via Acquire: SaRate infobox on scope (ovserve when changing time/DIV [S/Div] switch)
# [0] - time/div, real, s; [1] - sampling rate, real, Hz(Sa/s)
# now in attenScopeIncludes; include it:
use lib dirname (abs_path(__FILE__));
use attenScopeIncludes;
# declare from attenScopeIncludes
our $adsFactor;
our %timediv_srate_map;
our %timediv_sint_map;
our $scope_hdivs; # 18
our $scope_vdivs; # 8
our %timediv_move_map;
our %timediv_length_map;

use Number::FormatEng qw(:all);
use File::Copy qw/copy move/;
use Term::ReadKey;
use List::Util qw/max min/;


sub usage()
{
print STDOUT << "EOF";
  usage: perl ${0} *.note
  *.note     list of .note files to process

  (only those files with ADS* first word,
   and with an ADS*.CSV or ADS*.DAV file
   present in same directory, will be processed)

EOF
exit 0;
};


#======= "main"

# script filename (but still path leaks in gnuplot file? basename)
my $scrfn = basename(__FILE__);

# if ($#ARGV < 0) {
#  usage();
# }
# my $inscopecaptdir = abs_path($ARGV[0]);
# $inscopecaptdir .= $PS;
# say "Scope captures dir is $inscopecaptdir";
# # assuming we're in attengrab captures directory
# # get all *.note files in this directory
# my @notefiles = glob '*.{note}';
# my @notefwords = ();

# or rather:
# get number of cmdline arguments
# these will be our filenames
my $files_num = scalar @ARGV;
if (not($files_num)) { say "Need at least one .note file to process"; usage(); }

my @notefiles = ();

# validate inputs:
# check first for legal .note/.csv, .CSV/.DAV files
for my $infilestr (@ARGV) {
  say "Processing $infilestr";

  my @tentry = ();

  my $infiledir = dirname($infilestr);

  if (not($infilestr =~ m/\.note/)) {
    say "  No .note in filename = not a .note file; skipping";
    next; # skip rest of loop
  }

  open my $file, '<', "$infilestr";
  my $firstLine = <$file>;
  close $file;

  # attengrab now will autoinsert ADS0000X as first word of note
  # get that word as index of files saved by scope on USB flash/key
  my ($firstword, $rest) = split /\s+/, $firstLine, 2;
  my $adsword = $firstword;
  say "  $infilestr first word: $adsword";

  (my $infilebase = $infilestr) =~ s/\.note//;
  my $infilecsv = "$infilebase.csv";

  if (not(-e $infilecsv)) {
    say "  $infilecsv doesn't exist; skipping";
    next; # skip rest of loop
  } else {
    my $numlines = 0;
    open my $csvfile, '<', "$infilecsv";
    while (<$csvfile>) { $numlines++ }
    close $csvfile;
      say "  found $infilecsv ($numlines lines)";
  }

  # TODO: maybe here eventually do a numlines check;
  # if==26 then really corrupt (else not corrupt - so skip?)

  my ($inDAVfile, $inCSVfile);
  $inDAVfile = "$adsword.DAV";
  $inCSVfile = "$adsword.CSV";

  my ($doesDAVexist, $doesCSVexist);
  $doesDAVexist = (-e $inDAVfile);
  $doesCSVexist = (-e $inCSVfile);

  if (not($doesDAVexist or $doesCSVexist) ) {
    say "  both $inDAVfile and $inCSVfile not found; skipping";
    next; # skip rest of loop
  } else {
    if ($doesDAVexist) {
      say "  found $inDAVfile";
    }
    if ($doesCSVexist) {
      say "  found $inCSVfile";
    }
  }

  # ok, here we have something - populate array...
  push(@tentry, $infilecsv);

  # prefer DAV
  if ($doesDAVexist) {
    push(@tentry, $inDAVfile);
  } elsif ($doesCSVexist) {
    push(@tentry, $inCSVfile);
  }

  push (@notefiles , \@tentry);
}

say ""; # empty line

my $numnotefiles = scalar(@notefiles);
if ($numnotefiles == 0) {
  say "No valid .csv<->(.DAV/.CSV) combinations found; exiting.";
  exit 1;
}

##########################################
say "Overview: $numnotefiles entries:";

for my $noteentry (@notefiles) {
  my @notea = @{$noteentry};
  say "  *) repairing " .$notea[0]. " with " . $notea[1] ;
}

say ""; # empty line
say "Please review if OK, and press [y] to continue";
my ($char, $pause_time) = 0;

ReadMode("cbreak");
$char = ReadKey($pause_time); # only one char
ReadMode("restore");
if (not($char eq "y")) {
  say "Will not proceed - exiting.";
  exit 0;
}


##########################################
say "Proceeding with repair ...";

# read data section, only to __END__ token
my $gpstr;
while (<DATA>) {
  last if ($_ =~ /^__END__/);
  $gpstr .= $_;
}

# check if _repair backup directory exists;
# if not, create it
if (not(-d "_repair")) {
  say "_repair backup folder not found, creating";
  mkdir("_repair");
} else {
  say "_repair backup folder found";
}



my $fh;

my $dsz = 0x4000;
my @adavdata;
my $adsdavfile;

my $atgcsvfile;
my @atgcsvdata;
my $dopack = 0;
my ($atgreclen1, $atgreclen2) = (0)x2;
my ($atgcsvreclen, $atgcsvdatlen) = (0)x2;
my ($atgsampint) = (0)x1;
my ($rtsamprate) = (0)x1;
my ($atgcsvfinalts) = (0)x1;  # use this instead of $atgsampint
my ($atgvuch1, $atgvuch2) = (0)x2; # "Vertical Units" (V) V/DIV
my ($atgvscch1, $atgvscch2) = (0)x2; # "Vertical Scale" (1) V/DIV
my ($atgvoffch1, $atgvoffch2) = (0)x2; # "Vertical Offset" (1)
my ($atghu, $atghs, $atgtrange, $atgtoffs) = (0)x4; # "Horizontal Units" (s), "Horizontal Scale" (0.0050000000), time range, time offset
my (@atgch1valsi,@atgch2valsi);
my (@atgch1valsr,@atgch2valsr,@atgtimevals);

my ($osf, $usf, $Dmove, $Cmove, $cmove, $toffssmp);

my @atgcsvheader;


my @adsCSVdata;
my ($adsCSVreclen, $adsCSVdatlen) = (0)x2;
my ($adssampintch1, $adssampintch2,$adssampint) = (0)x3;
my ($adsvuch1, $adsvuch2) = (0)x2; # "Vertical Units" (V)
my ($adsvscch1, $adsvscch2) = (0)x2; # "Vertical Scale" (1)
my ($adsvoffch1, $adsvoffch2) = (0)x2; # "Vertical Offset" (1)
my ($adshu, $adshs, $adstrange) = (0)x3; # "Horizontal Units" (s), "Horizontal Scale" (0.0050000000), time range
my (@adsch1vals,@adsch2vals,@adstimevals);
my $rest;
my $Ctf;
my $adsCSVfile;
my $csvi_offs_ch2;

# now frSizes has meaning of "actual samples"
my @frSizes = (0)x3;

# as in adscompare.pl:
# must also handle per-channel delay for .csv - via argument
# turns out, .CSV also needs per-channel delay - via argument
# (these must be placed after the variables are declared!):
sub DAVi { return int(($_[0]-($dsz/2))*$osf+$toffssmp+$Dmove); }
sub CSVi { return int(($_[0]-($adsCSVdatlen/2))*$osf+$toffssmp+$Cmove+$_[1]); }
sub csvi { return int(($_[0]-($atgcsvdatlen/2))+$toffssmp+$cmove+$_[1]); }

sub iDAVi { return ($_[0]-$toffssmp-$Dmove)/$osf+($dsz/2); }
sub iCSVi { return ($_[0]-$toffssmp-$Cmove-$_[1])/$osf+($adsCSVdatlen/2); }
sub icsvi { return (($_[0]-$toffssmp-$cmove-$_[1])+($atgcsvdatlen/2)); }

sub get_realval_ch1 { return ($_[0]-128)*$adsFactor*8*$atgvscch1/256 - $atgvoffch1; }
sub get_realval_ch2 { return ($_[0]-128)*$adsFactor*8*$atgvscch2/256 - $atgvoffch2; }
sub get_uint8val_ch1 { return ($_[0]+ $atgvoffch1)*256/($adsFactor*8*$atgvscch1) + 128; }
sub get_uint8val_ch2 { return ($_[0]+ $atgvoffch2)*256/($adsFactor*8*$atgvscch2) + 128; }




# @outa - array of arrays:
# :[csvfilebase, csv(repaired)headerstring, csv(repaired)rowsarray ]
# ... or maybe not?? (just go entry by entry)
my @outa;
my $repairfile;

my $sperd;
my $srate;
my $tfoi;

# start loop ##################################
for my $noteentry (@notefiles) {
  my @notea = @{$noteentry};
  #~ say "  *) repairing " .$notea[0]. " with " . $notea[1] ;
  $atgcsvfile = $notea[0];
  my $filebase;
  ($filebase = $atgcsvfile) =~ s/\.csv//;
  #(my $adsbase = $notea[1]) =~ s/\.CSV|\.DAV//; # don't need it
  $repairfile = $notea[1];

  # ## read through .csv, get data which is possible
  say "\nProcessing $atgcsvfile";
  &process_atgcsv_repair();
  &printout_atgcsv();

  # ## re-calc final timestep, based on osf for this T/DIV
  &recalculate_atgcsv_osf();

  # ## see if we have .DAV or .CSV attached:
  # ##  get length of snippet, and data (as int)
  # here we're interested in snippet overlapping .csv
  # sometimes .CSV or .DAV (or both) go over (or under)
  # but simply go along the .csv indexes, and update those that exist
  # those that don't - leave empty, it's ok w/ gnuplot (or use "NaN")
  @outa = ();
  &populate_out();
  say "  --> Got out array population: " .scalar(@outa). " (in finalts steps)";

  # ## change those values in .csv header that need updating
  # now frSizes has meaning of "actual samples"
  # my $numsamples = $atgcsvdatlen
  $atgcsvheader[0] .= " [" . basename(__FILE__) . "]"; # mark
  $atgcsvheader[22] = "# Number of samples in data: " .scalar(@outa). " (ch1: $frSizes[1] ; ch2: $frSizes[2]) (:: $atgcsvdatlen)";

  # ## re-calc snippet real values
  # from adsparse-wave.pl
  my $outdat = "";
  # careful - set mins to big ones initially
  my ($amxp1,$amxn1,$amxp2,$amxn2) = (-1e6,1e6)x2; # max positive and negative

  for ( my $i = 0; $i < scalar(@outa); $i++ ) {
    # remember both "zero" (128) and "byte" offset here before scaling:
    my @tdat = @{$outa[$i]};
    #$tdat[1] = $adatch1[$i]; $tdat[2] = $adatch2[$i]
    #$atgvoffch1 = $ch1Vcoeff
    #$voff1_ic = 132-$voff1_i; better with get_realval_ch1/2
    # # my $aval1 = ($tdat[1]-128-$voff1_ic)*$atgvoffch1;
    # # my $aval2 = ($tdat[2]-128-$voff2_ic)*$atgvoffch2;
    # now we could have "empty" samples as well, handle:
    my ($aval1,$aval2,$fe1,$fe2) = ("")x4;
    if ( not($tdat[1] eq "") ) {
      $aval1 = get_realval_ch1($tdat[1]);
      $fe1 = format_eng($aval1);
      $amxp1 = $aval1 if ($aval1 > $amxp1);
      $amxn1 = $aval1 if ($aval1 < $amxn1);
    }
    if ( not($tdat[2] eq "") ) {
      $aval2 = get_realval_ch2($tdat[2]);
      $fe2 = format_eng($aval2);
      $amxp2 = $aval2 if ($aval2 > $amxp2);
      $amxn2 = $aval2 if ($aval2 < $amxn2);
    }
    $outdat .=  $i .",". $tdat[1] .",". $tdat[2] .",".
                $i*$atgcsvfinalts .",". $fe1 .",". $fe2 ."\n";
  }
  $atgcsvheader[20] = "Real volt ranges: ch1 (". format_eng($amxn1) .",". format_eng($amxp1) .") ; ch2 (". format_eng($amxn2) .",". format_eng($amxp2) .")";

  # just debug:
  #~ say join("\n", (@atgcsvheader, $outdat));

  # ## move old .csv in _repair
  move $atgcsvfile, "_repair$PS$atgcsvfile" or warn "Cannot move $atgcsvfile ($!)";
  say "  --> Moved to _repair: $atgcsvfile";

  # ## dump new .csv
  my $output = join("\n", (@atgcsvheader, $outdat));
  my $ofh; # $ofncsv = $ofnb.csv = $atgcsvfile
  open($ofh,'>',$atgcsvfile) or die "Cannot open $atgcsvfile ($!)";
  say "  --> Writing to $atgcsvfile";
  print { $ofh } $output;
  close($ofh);
  say "  --> Saved $atgcsvfile";

  # ## dump new .gnuplot (and call gnuplot)
  # vars needed in gnuplot:
  # $ofngps , $scrfn , $ofnb , $tbase , $toffs , $vdiv1 , $vdiv2 , $voff1 , $voff2 , $sperd , $srate , $osf , $adsFactor , $scope_hdivs , $scope_vdivs , $voff1_ic , $voff2_ic , $frDatSize , $final_timestep , $toffs_i , $tfoi
  my $ofnb = $filebase;
  my $scrfn = basename(__FILE__);
  my $ofngps = "$ofnb.gnuplot";
  my $tbase = $atghs+0;
  my $toffs = $atgtoffs;
  # my $toffs = $atgtoffs + $csvi_offs_ch2*$atgcsvfinalts; # nowork
  my $vdiv1 = $atgvscch1;
  my $vdiv2 = $atgvscch2;
  my $voff1 = $atgvoffch1;
  my $voff2 = $atgvoffch2;
  #present: $sperd , $srate , $osf , $adsFactor , $scope_hdivs , $scope_vdivs , $tfoi
  my $voff1_ic = get_uint8val_ch1($voff1);
  my $voff2_ic = get_uint8val_ch1($voff2);
  my $frDatSize = scalar(@outa);
  my $final_timestep = $atgcsvfinalts;
  # $timecoeff = $final_timestep
  my $toffs_i = int($toffs/$final_timestep);
  my $repair_str = "repair: $repairfile";
  # expand Perl variables in the DATA section template via regex
  # protect them as ${} when concatenating ${a}_b
  # we have multiple outputs here, must keep gpstr as template!
  my $outgpstr;
  ($outgpstr = $gpstr) =~ s/(\${\w+})/${1}/eeg;
  die if $@;                  # needed on /ee, not /e

  # just debug:
  #~ say $gpstr;

  # ## move old .gnuplot in _repair
  # there is possibly old .gnuplot hanging in failed; move it
  move $ofngps, "_repair$PS$ofngps" or warn "Cannot move $ofngps ($!)";
  say "  --> Moved to _repair: $ofngps";


  my $ofhgps;
  open($ofhgps,'>',"$ofngps") or die "Cannot open $ofngps ($!)";
  print { $ofhgps } $outgpstr;
  close($ofhgps);
  say "Saved $ofngps";
  # call also gnuplot (we're not within attengrab, to call for us)
  say "Calling gnuplot $ofngps ... ";
  my $gpstatus = system("gnuplot", "$ofngps");
  if (($gpstatus >>=8) != 0) {
    die "Failed to run gnuplot!";
  } else {
    # on success, move bitmap
    my $fn_bmp = $ofnb . ".bmp";
    move $fn_bmp, "_repair$PS$fn_bmp" or warn "Cannot move $fn_bmp ($!)";
    say "  --> Moved to _repair: $fn_bmp";
  }

} # end for my $noteentry (@notefiles)

say "All done; exiting.";
exit 0; # should be by default - but keeping it anyways..



## END MAIN ################################


# slightly different from process_atgcsv in adscompare.pl:
# here we know there's no data as .csv is corrupt;
# we simply extract variables from (and copy) the header
sub process_atgcsv_repair {

open($fh,'<',$atgcsvfile) or die "Cannot open $atgcsvfile ($!)";
binmode($fh);
@atgcsvheader = ();
$dopack = 0; # re-initialize!

while (<$fh>) {
  if ($dopack) { # out of header
    # skip any potential commented lines (#) remaining
    if ($_ =~ "^#") {
      chomp($_);
      push(@atgcsvheader, $_);
    } else {
      # we entered what should have been data,
      # which is now corrupt - do not process:
      # # chomp($_);
      # # $_ = # s/^\s+//; #ltrim
      # # $_ = # s/\s+$//; #rtrim
      # ... just exit loop:
      last;
    }
    # now data is invalid, don't have this:
    # $atgcsvdatlen++;
  } else { # in header:
    chomp($_);
    push(@atgcsvheader, $_);

    if ($_ =~ /Number of samples in data/) {
      # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
      my @resp = split / /, $_;   #say "resp:", join("--",@resp);
      $atgreclen1 = $resp[8];
      # digits only; return match with () capture:
      $atgreclen2 = ($resp[11] =~ m/(\d+)/)[0];
      if ($atgreclen2 > $atgreclen1) { $atgcsvreclen = $atgreclen2; }
      else { $atgcsvreclen = $atgreclen1; }
    }
    if ($_ =~ /Sampling interval \(screen_range\/num_samples\)/) {
      # NOTE: Sample interval refers to time domain; NOT voltage!
      # (sampling period)
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling interval \(screen_range\/num_samples\)   : //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgsampint = $resp[0];
    }
    if ($_ =~ /Sampling rate \(scope Acquire menu,2CH RealTime\):/) {
      # clean up a bit - easier parse:
      $_ =~ s/# Sampling rate \(scope Acquire menu,2CH RealTime\): //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $rtsamprate = $resp[0];
    }
    if ($_ =~ /final timestep:/) {
      # clean up a bit - easier parse:
      $_ =~ s/#  { final timestep: //;
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgcsvfinalts = $resp[0];
    }
    if ($_ =~ /Oversample factor:/) {
      # NOTE: time; == timebase
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $osf = $resp[3];
    }
    if ($_ =~ /Time offset:/) {
      # NOTE: time; == timebase
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgtoffs = $resp[3];
    }
    if ($_ =~ /Timebase/) {
      # NOTE: time; == timebase
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atghs = $resp[5];
      $atghu = $resp[6];
    }
    if ($_ =~ /Ch1 V\/DIV/) {
      # NOTE: Voltage
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch1 = $resp[5];
      $atgvuch1 = $resp[6];
    }
    if ($_ =~ /Ch2 V\/DIV/) {
      # NOTE: Voltage
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvscch2 = $resp[5];
      $atgvuch2 = $resp[6];
    }
    # $atgvoffch1 $atgvoffch2
    if ($_ =~ /Ch1 Voffset/) {
      # NOTE: Voltage
      my @resp = split / /, $_; #say "resp:", join("--",@resp);
      $atgvoffch1 = $resp[3];
    }
    if ($_ =~ /Ch2 Voffset/) {
      # NOTE: Voltage
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

# slightly different from adscompare.pl.
# since here .csv is expected corrupt
sub printout_atgcsv {
  say "$atgcsvfile: Record Length=$atgcsvreclen ($atgreclen1;$atgreclen2); csv length:", $atgcsvdatlen;
  say " Sampl.int. (scope_hdivs/len) ",$atgsampint, " ; final timestep: ", $atgcsvfinalts;
  say " minmaxi 1:[INVALID] 2:[INVALID] ";
  say " mrnmaxr 1:[INVALID] 2:[INVALID]";
  say "  t:[INVALID] (INVALID)";
  say "  t offset: $atgtoffs";
  say " Vertical Units: $atgvuch1 $atgvuch2 ; Vert.Scale: $atgvscch1 $atgvscch2 ; Vert. Offset: $atgvoffch1 $atgvoffch2";
  say " Horizontal Units: $atghu; Horizontal Scale (timebase): $atghs";
  say " RealTime (Acq Menu) Sample Rate: $rtsamprate";
  say " (got ".scalar(@atgcsvheader)." lines header)";
}

# as in adsparse-wave.pl:
sub recalculate_atgcsv_osf {

  # note: adsparse-wave $tbase calc'ed, in attengrab-repair it is read!
  # p sprintf("%.50f", $tbase):
  # -repair is same as p sprintf("%.50f", 250e-9);
  # 0.00000025000000000000004162658715986533586317364097 # adsparse-wave
  # 0.00000024999999999999998868702795647156467140348468 # attengrab-repair
  #  .1234567890123456789012 # 22 decimals precision
  # sprintf("%.22f", $tbase): 0.0000002500000000000000
  # p sprintf("%.50f", sprintf("%.22f", $tbase)+0); is same for both (same as -repair) - so, handle!
  # (that also forces $tprd_range_tbase = sprintf("%.22f", for correct results!)
  my $tbase = $atghs+0;
  $tbase = sprintf("%.22f", $tbase)+0;
  my $tmpstr;

  my $range_tbase = $scope_hdivs*$tbase;
  my $tbasestr = "Timebase (time/DIV)  : " . format_eng($tbase) . " s ( " . format_pref($tbase) . "s )";
  $tmpstr = "#  { screen range $scope_hdivs*(t/DIV)= ". format_pref($range_tbase) . "s }";
  #println $tbasestr;
  $atgcsvheader[6] = "# ".$tbasestr;
  $atgcsvheader[7] = $tmpstr;
  $tbasestr .= "\n".$tmpstr;

  # since here the .csv is corrupt, we don't have numsamples of it!
  # so get the expected num samples for this T/DIV
  $atgcsvdatlen = $timediv_length_map{$tbase}[1]; # instead of $atgcsvreclen
  $adsCSVdatlen = $timediv_length_map{$tbase}[0]; # instead of $adsCSVreclen
  my $numsamples = $atgcsvdatlen; # instead of $atgcsvreclen


  # here can get sampling rate - from table (written from scope menu for a given TIME/DIV)
  $srate = $timediv_srate_map{$tbase};
  my $tprd_srate = 1/$srate;
  my $range_srate = $numsamples*$tprd_srate;
  my $sratestr = "Sampling rate (scope Acquire menu,2CH RealTime): " . format_eng($srate) . " Hz [Sa/s] ( " . format_pref($srate) . "Hz )";
  $tmpstr = "#  {eqv.period: ".format_pref($tprd_srate)."s range: ".format_pref($range_srate)."s }";
  #println $sratestr;
  $atgcsvheader[8] = "# ".$sratestr;
  $atgcsvheader[9] = $tmpstr;
  $sratestr .= "\n".$tmpstr;

  # here can get sampling interval,
  #  as they are written by scope in .CSV for a given TIME/DIV
  # so again from a (different) table:
  $sperd = $timediv_sint_map{$tbase};
  my $fsam_sperd = 1/$sperd;
  my $range_sperd = $numsamples*$sperd;
  my $sperdstr = "Sampling interval (scope USB FlashDrive .CSV)  : " . format_eng($sperd) . " s ( " . format_pref($sperd) . "s )";
  $tmpstr = "#  {eqv.freq: ".format_pref($fsam_sperd)."Hz range: ".format_pref($range_sperd)."s }";
  #println $sperdstr;
  $atgcsvheader[10] = "# ".$sperdstr;
  $atgcsvheader[11] = $tmpstr;
  $sperdstr .= "\n".$tmpstr;


  my ($tprd_range_tbase,$srate_range_tbase) = (-1)x2;
  if ($numsamples > 0) {
    $tprd_range_tbase = $range_tbase/$numsamples;
    $tprd_range_tbase = sprintf("%.22f", $tprd_range_tbase)+0;
    $srate_range_tbase = 1/$tprd_range_tbase;
  }
  my $tprdrangestr = "Sampling interval (screen_range/num_samples)   : " . format_eng($tprd_range_tbase) . " s ( " . format_pref($tprd_range_tbase) . "s )";
  $tmpstr = "#  {eqv.freq: ".format_pref($srate_range_tbase)."Hz }";
  #println $tprdrangestr ;
  $atgcsvheader[12] = "# ".$tprdrangestr;
  $atgcsvheader[13] = $tmpstr;
  $tprdrangestr .= "\n".$tmpstr;


  # check ranges
  my $final_timestep;
  my $checkrangestr = "Time Ranges";
  if ($range_srate > $range_tbase) { #($range_tbase > $range_sperd) { # range_div>range_csv {
    $checkrangestr .= " ".format_pref($range_srate)."s > ".format_pref($range_tbase)."s: assume resample +recalc;";
    $final_timestep = $tprd_range_tbase;
  } else { # <=
    $checkrangestr .= " $range_srate <= $range_tbase: assume portion +keep;";
    $final_timestep = $tprd_srate; # $sperd;
  }

  # oversample factor: real rate period/chosen xrange period
  my $origosf = $tprd_srate/$tprd_range_tbase;

  $tfoi = 0;

  # check osf fractional part
  my $origosfractional = $origosf - int(sprintf("%f",$origosf));
  my $smallosf = "--";
  if ($origosfractional > 0) {
    if ($origosf >= 1) {
      # set $osf to 1.0
      $osf = "1.0"; # as string, so we can see it's modded in printout
      $final_timestep = $tprd_srate;
      #~ $tfoi = -164;
    } else { # $origosf < 1
      $final_timestep = $sperd;
      #$osf = $tprd_srate/$sperd;
      #~ $tfoi = -164;
      $smallosf = $tprd_srate/$sperd;
      $osf = "1.00"; # as string, so we can see it's modded in printout
    }
  } else { # integer - no change
    $osf = $origosf;
  }

  # we don't need $osf for $cmove/$tfoi - but nonetheless,
  # put the command here - after $osf is known:
  $tfoi = eval ( $timediv_move_map{$tbase}[2] ); # $tbase == $atghs

  # tested with "%.50f", looks OK
  my $osfstr = "Oversample factor: " . $osf ." ( $smallosf ". sprintf("%.6f", $origosf) ." ". int($origosf) ." ". $origosfractional ." )";
  #println $osfstr;


  my $range_final = $numsamples*$final_timestep;
  my $srate_final = 1/$final_timestep;
  $tmpstr = "#  { final timestep: ".format_eng($final_timestep)." / ".format_pref($final_timestep)."s {eqv.freq: ".format_pref($srate_final)."Hz range ".format_pref($range_final)."s }}";
  #println $checkrangestr;
  $atgcsvheader[14] = "# ".$checkrangestr;
  $atgcsvheader[15] = $tmpstr;
  $checkrangestr .= "\n".$tmpstr;

  $atgcsvheader[16] = "# ".$osfstr;

  $atgcsvfinalts = $final_timestep;

  # for testing:
  #~ say join("\n", ("--> recalc", @atgcsvheader));

  say "
  --> recalc:
  --> (expected .csv length $numsamples)
  > $tbasestr
  > $sratestr
  > $sperdstr
  > $tprdrangestr
  > $checkrangestr
  > $osfstr
";

}

sub process_adsCSV_repair {

  @adsCSVdata = ();
  @adsch1vals = ();
  @adsch2vals = ();
  $adsCSVdatlen = 0;
  $dopack = 0;

  open(my $fh,'<',$adsCSVfile) or die "Cannot open $adsCSVfile ($!)";
  binmode($fh);
  #my @csvlines = <$fh>;
  while (<$fh>) {
    if ($dopack) {
      chomp($_);
      $_ =~ s/^\s+//; #ltrim
      $_ =~ s/\s+$//; #rtrim
      my @csvline = split(",", $_);
      push(@adsCSVdata, \@csvline); # must push ARRAY ref here, for 2D index!
      #push(@adsch1vals, $csvline[1]);
      #push(@adsch2vals, $csvline[2]);
      $adsCSVdatlen++;
    } else {
      if ($_ =~ /Record Length/) {
        # note: for the same capture, attenload may return 16000 samples, while Record Length may say 11250!
        # note: csvdatlen and csvreclen should match!
        ($rest, $adsCSVreclen) = split /,/, $_, 2;
        chomp($adsCSVreclen);
      }
      if ($_ =~ /Sample Interval/) {
        # NOTE: Sample interval refers to time domain; NOT voltage!
        my $siboth="";
        ($rest, $siboth) = split /,/, $_, 2;
        chomp($siboth);
        my ($s1h, $s2h) = split / /, $siboth, 2;
        $adssampintch1 = substr($s1h,index($s1h,":")+1);
        $adssampintch2 = substr($s2h,index($s2h,":")+1);
      }
      if ($_ =~ /Vertical Units/) {
        # NOTE: Voltage
        my $vuboth="";
        ($rest, $vuboth) = split /,/, $_, 2;
        chomp($vuboth);
        $vuboth =~ s/,,//g; # remove ,,
        my ($vu1h, $vu2h) = split / /, $vuboth, 2;
        #say "vu1h, vu2h $vu1h, $vu2h";
        $adsvuch1 = substr($vu1h,index($vu1h,":")+1);
        $adsvuch2 = substr($vu2h,index($vu2h,":")+1);
      }
      if ($_ =~ /Vertical Scale/) {
        # NOTE: Voltage
        my $vscboth="";
        ($rest, $vscboth) = split /,/, $_, 2;
        chomp($vscboth);
        $vscboth =~ s/,,//g; # remove ,,
        my ($vsc1h, $vsc2h) = split / /, $vscboth, 2;
        $adsvscch1 = substr($vsc1h,index($vsc1h,":")+1);
        $adsvscch2 = substr($vsc2h,index($vsc2h,":")+1);
      }
      if ($_ =~ /Vertical Offset/) {
        # NOTE: Voltage
        my $vofboth="";
        ($rest, $vofboth) = split /,/, $_, 2;
        chomp($vofboth);
        $vofboth =~ s/,,//g; # remove ,,
        my ($vof1h, $vof2h) = split / /, $vofboth, 2;
        $adsvoffch1 = substr($vof1h,index($vof1h,":")+1);
        $adsvoffch2 = substr($vof2h,index($vof2h,":")+1);
      }
      if ($_ =~ /Horizontal Units/) {
        # NOTE: time
        ($rest, $adshu) = split /,/, $_, 2;
        chomp($adshu);
        $adshu =~ s/,,//g; # remove ,,
      }
      if ($_ =~ /Horizontal Scale/) {
        # NOTE: time; == timebase
        ($rest, $adshs) = split /,/, $_, 2;
        chomp($adshs);
        $adshs =~ s/,,//g; # remove ,,
      }
      if ($_ =~ /Second,Volt,Volt/) {
        $dopack = 1;
      }
    }
  }
  close($fh);

} # end sub

sub process_adsDAV_repair {
  # [ADS0000x].DAV (bin)
  # read in entire file / slurp in one go
  #~ say "\nProcessing $adsdavfile";

  my ($fh, $indavdata);
  open($fh,'<',$adsdavfile) or die "Cannot open $adsdavfile ($!)";
  binmode($fh);
  sysread($fh,$indavdata,-s $fh);
  close($fh);

  # convert string $indata to array/list, for easier indexing
  # full size here - even if we'll use only one channel
  # do NOT use split, not binary safe; use unpack instead
  my @tadavdata = unpack('C*',$indavdata);
  # how many bytes in @adavdata (length)?
  my $tadavsize = scalar (@tadavdata);

  #~ say "$adsdavfile: $tadavsize bytes (expecting 0x4000 = 16384 samples (per ch))";
  @adavdata = ();
  # extract 1st channel
  @adavdata[0..$dsz-1] = @tadavdata[0..$dsz-1];
  # extract 2nd channel - we use both from same array
  @adavdata[$dsz..2*$dsz-1] = @tadavdata[$dsz..2*$dsz-1];

} # end sub

sub populate_out {

  @outa = ();
  @frSizes = (0)x3;

  $Dmove = eval ( $timediv_move_map{$atghs+0}[0] ); # Dmove .. '-2*$osf-31'
  $Cmove = eval ( $timediv_move_map{$atghs+0}[1] ); # Cmove .. '1*$osf-12'
  # cmove (needed only for full size (16000) .csv?)
  $cmove = eval ( $timediv_move_map{$atghs+0}[2] ); # cmove == tfoi

  $toffssmp= int($atgtoffs/$atgcsvfinalts+0.5); # quick round()-ing

  # apparently, offsetting ch2 .csv (and .CSV?) is needed too:
  $csvi_offs_ch2 = eval ( $timediv_move_map{$atghs+0}[3] ); #-($osf-1);

  # prepare itmin, itmax
  my @modrgimin1 = ( DAVi(0),
                    CSVi(0,0),
                    csvi(0,0) );
  my @modrgimax1 = ( DAVi($dsz-1),             # by last index
                    CSVi($adsCSVdatlen-1,0),
                    csvi($atgcsvdatlen-1,0) );
  my @modrgimin2 = ( DAVi(0+$dsz),
                    CSVi(0,$csvi_offs_ch2),
                    csvi(0,$csvi_offs_ch2) );
  my @modrgimax2 = ( DAVi($dsz-1+$dsz),             # by last index
                    CSVi($adsCSVdatlen-1,$csvi_offs_ch2),
                    csvi($atgcsvdatlen-1,$csvi_offs_ch2) );

  my $trunc_min = min(
    $modrgimin1[2],$modrgimin2[2]
    );
  my $trunc_max = max(
    $modrgimax1[2],$modrgimax2[2]
    );

  # was $xhrg = 20; but it seems its best
  # to truncate at 0 here..
  my $xhrg = 0; # half x range (in [smallest: $ix] samples) to be seen (for zoom&printout)

  my $printmin = $trunc_min-$xhrg;
  my $printmax = $trunc_max+$xhrg;

  my ($do_CSV, $do_DAV) = (0)x2;
  #my @repairdata = ();
  if ($repairfile =~ m/\.CSV/) {
    $do_CSV = 1; $do_DAV = 0;
    $adsCSVfile = $repairfile;
    say "  --> Processing $adsCSVfile";
    &process_adsCSV_repair();
    #@repairdata = @adsCSVdata;
  } elsif ($repairfile =~ m/\.DAV/) {
    $do_CSV = 0; $do_DAV = 1;
    $adsdavfile = $repairfile;
    say "  --> Processing $adsdavfile";
    &process_adsDAV_repair();
    #@repairdata = @adavdata;
  }

  say "  --> Partial process [or printout]: ( ", $printmin, " <= ix <= ", $printmax, " )";

  my $mainIndex = 0;
  my $tind;
  for (my $ix = $printmin; $ix <= $printmax; $ix++) {
    # in this loop, only interested in ch1 and ch2 int values;
    # that is outa[0] and outa[1]
    # we loop by final timestep - but insert only where samples exist
    # either CSV or DAV - as needed
    my @to = ($mainIndex, '', '');

    if ($do_CSV) {
      $tind = iCSVi($ix,0);
      if (($tind >= 0) and ($tind < $adsCSVdatlen)) {
        if ($tind==int($tind)) {
          my @adsCSVline = @{$adsCSVdata[$tind]};
          $to[1] = get_uint8val_ch1($adsCSVline[1]);
          $frSizes[1]++;
        }
      }
      $tind = iCSVi($ix,$csvi_offs_ch2);
      if (($tind >= 0) and ($tind < $adsCSVdatlen)) {
        if ($tind==int($tind)) {
          my @adsCSVline = @{$adsCSVdata[$tind]};
          $to[2] = get_uint8val_ch2($adsCSVline[2]);
          $frSizes[2]++;
        }
      }
    } elsif ($do_DAV) {
      $tind = iDAVi($ix);
      if (($tind >= 0) and ($tind < $dsz)) {
        if ($tind==int($tind)) {
          $to[1] = $adavdata[$tind];
          $frSizes[1]++;
          $to[2] = $adavdata[$tind+$dsz];
          $frSizes[2]++;
        }
      }
    }

    push(@outa, \@to); # must push ARRAY ref here, for 2D index!
    $mainIndex++;
  }
}




=head1 temp


=cut



# almost same as in adsparse-wave.pl,
# except for added label (additional wrap convert call)
# the DATA section is the gnuplot script for the data:
__DATA__

# ${ofngps} [generated by ${scrfn}]
# single gnuplot file, with two potentially independent scripts
# generates three plots: one based on integer, other based on real (SI) values
# and one bitmap overlay - and then montages them using ImageMagick

# attengrab .csv can just be centered (over t)
# -> the x=0 (t=0) will correspond to scope center
# (but .DAV/.CSV will also need extra sample alignment)

print "Gnuplotting..."

## "master settings" (shared between both parts of script)

# line color - specified by linestyles
set style line 1 linetype 1 linecolor rgb "red"
set style line 2 linetype 1 linecolor rgb "green"
set style line 3 linetype 1 linecolor rgb "orange"
set style line 4 linetype 1 linecolor rgb "aquamarine"
set style line 5 linetype -1 linecolor rgb "black"
set style line 6 linetype -1 linecolor rgb "gray"
set style line 7 linetype 1 linecolor rgb "blue"


# VARIABLES ########### ########### ###########

# -repair related:
repair_str="${repair_str}"
csvi_offs_ch2=${csvi_offs_ch2}

fnbase="${ofnb}"
fn_bmp = fnbase . ".bmp"
fn_pngr = fnbase . "_r.png"
fn_pngi = fnbase . "_i.png"
fn_pngov = fnbase . "_ov.png"
fn_pngt = fnbase . "_tmp.png"
fn_pngo = fnbase . ".png"

# scope screen(shot) properties
tdiv = ${tbase}          # T/DIV (50e-9)
toffs = ${toffs}        # time offset (scope) (200e-9)
vdiv1 = ${vdiv1}        # V/DIV CH1 (500e-3)
vdiv2 = ${vdiv2}         # V/DIV CH2 (50e-3)
voffs1 = ${voff1}         # volt offset CH1 (-1.5)
voffs2 = ${voff2}       # volt offset CH2 (100e-3)
sampintp  = ${sperd}    # (500e-12)
sampintf  = 1/sampintp
sratacqf  = ${srate}      # (250e6)
sratacqp  = 1/sratacqf
#osf = ${osf}    # oversample factor (multiplies .CSV and .DAV time domain) # unused here
adsFactor = ${adsFactor}

# (edges of current capture and divisions)
scope_hdiv=${scope_hdivs}
scope_vdiv=${scope_vdivs}
# enforce floating point (see below)
scope_trange = scope_hdiv*tdiv*1.0    # (900e-9)
scope_left=toffs-(scope_trange/2)     # (-250e-9)
scope_right=toffs+(scope_trange/2)    # (650e-9)
scope_bottom=-voffs1-(scope_vdiv*vdiv1/2) # -500e-3
scope_top=-voffs1+(scope_vdiv*vdiv1/2)    # 3.5

totalch1Vspan=scope_vdiv*vdiv1
totalch2Vspan=scope_vdiv*vdiv2
ch1Vcoeff = adsFactor*totalch1Vspan/(2**8)
ch2Vcoeff = adsFactor*totalch2Vspan/(2**8)

voffs1int = voffs1/ch1Vcoeff  # ${voff1_ic}
voffs2int = voffs2/ch2Vcoeff  # ${voff2_ic}

acsv_fn = fnbase . '.csv' # '20130020-013902.csv' # from attenload tmp_wav
acsz=${frDatSize}         # tmp_wav/.csv size (900)
fts=${final_timestep}         # final timestep (sampling period)
# here scope_trange could be 18*1, with acsz 16000;
# if as integer, 18/16000 would be 0 - enforce floating point
# above enforcing scope_trange to float doesn't work,
# must again here:
tdivp = 1.0*scope_trange/acsz   # sampling rate, based on scope range and numsamples in tmp (1ns)
tdivf = 1/tdivp             # freq based on that sampling rate

toffsamp = toffs/fts		# ${toffs_i}
# time finetune offset - int (samples) (depends on range)
tfoi = ${tfoi}

##################################
###### plot directly with unsigned byte data

set terminal png size 840,480
set termoption enhanced
set termoption font "Helvetica, 12"

set output fn_pngi
set datafile separator ","

# set axis label
set xlabel "index" offset 0.0,0.8
set ylabel "byte unsigned value" offset 1.0,0.0


# horizontal line as functions
zeroline(x)=128
ch1offs(x)=128+voffs1int # (${voff1_ic})
ch2offs(x)=128+voffs2int # (${voff2_ic})

# vertical line - headless arrow
# "y" scope axis in middle:
ymI = acsz/2
set arrow from ymI,0 to ymI,255 nohead ls 5
# time offset:
toI = ymI - toffs/fts
set arrow from toI,0 to toI,255 nohead ls 6


# must use multiplot here, to have two x-axes
# and thus, must set lmargin, so both graphs match

set size 1.0,0.9      # 0.1/2 = 0.05
set bmargin 0
set lmargin 10
set yrange [0:255] # 8-bit


set multiplot

set origin 0,0.1
set xrange [0:acsz]
set xtics in
set xtics offset 0,graph 0.08
plot \
  zeroline(x) with lines notitle ls 5,\
  acsv_fn using 1:2 with lines title "ch1" ls 1, \
  "" using 1:3 with lines title "ch2" ls 2, \
  ch1offs(x) with lines notitle ls 3, \
  ch2offs(x) with lines notitle ls 4

unset arrow # if big offset, line from prev. can 'leak' in next at diff place, so reset

set origin 0,0.1
set xtics out
set xtics offset 0,graph 0.02
set xrange [-acsz/2:acsz/2-1]
#set xtics nomirror 500
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot 0 notitle

set nomultiplot


### reset previous settings
#unset border # no work for default
set border    # Draw default borders:
set ytics
unset yrange


##################################
###### plot with converted real SI units

# reset # resets set style line!

set terminal png size 840,480
set termoption enhanced
set termoption font "Helvetica, 12"

set output fn_pngr
set datafile separator ","

# set axis label
set xlabel "t [s]" offset 0.0,0.1
set ylabel "U [V]" offset 1.0,0.0

# axis tics format
set format y "%.1s%c"
set format x "%.1s%c"


# horizontal line as functions
zerolineR(x)=0
# don't show real offsets; they could be way off depending on V/DIV
#ch1offsR(x)=0+(${voff1})
#ch2offsR(x)=0+(${voff2})

# "y" scope axis in middle (the +1 added to ymI so it snaps at 0):
ymR=(ymI+1)*fts
set arrow from ymR,graph 0 to ymR,graph 1 nohead ls 5
# time offset:
toR=toI*fts
set arrow from toR,graph 0 to toR,graph 1 nohead ls 6
# indicate scope range here too
set arrow from scope_left+toR,graph 0 to scope_left+toR,graph 1 nohead ls 7
set arrow from scope_right+toR,graph 0 to scope_right+toR,graph 1 nohead ls 7


# must use multiplot here, to have two x-axes
# and thus, must set lmargin, so both graphs match

set size 1.0,0.9      # 0.1/2 = 0.05
set bmargin 0
set lmargin 10
set yrange [] writeback # since we don't set explicity, must save autorange
set autoscale y

set multiplot

set origin 0,0.13
set xrange [0:acsz*fts]
set xtics out
set xtics offset 0,graph -0.03
plot \
  zerolineR(x) with lines notitle ls 5,\
  acsv_fn using ($4+tfoi*fts):5 with lines title "ch1" ls 1, \
  "" using ($4+tfoi*fts):6 with lines title "ch2" ls 2

set yrange restore # this saves the found yrange after `plot`
unset arrow # if big offset, line from prev. can 'leak' in next at diff place, so reset

set origin 0,0.13
set xtics out
set xtics offset 0,graph 0.02
set xrange [(-acsz/2)*fts:(acsz/2-1)*fts]
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot GPVAL_Y_MIN notitle

set origin 0,0.13
set xtics in
set xtics offset 0,graph 0.08
# wrong to put xrange [scope_left:scope_right] here;
# as [scope_left:scope_right] could be a snippet,
# and this graph shows entire capture!
# simply move the previous scale for toffset
toRR=(acsz/2.)*fts-toR
set xrange [(-acsz/2)*fts+toRR:(acsz/2-1)*fts+toRR]
set noytics
set noylabel
unset xlabel # set xlabel ""
set border 1
plot GPVAL_Y_MIN notitle

set nomultiplot


##################################
###### plot with bitmap and data overlay

# here 840,480 remains as output png size,
# even if not set explicitly; also, make
# the height smaller - so can have gravity North in montage

set terminal png truecolor size 640,305 # size 840,480
set termoption enhanced
myfont="LMSansDemiCond10-Regular"   # LMSansDemiCond10-Regular or "Latin Modern Sans Demi Cond"
# cannot do concatenation direct in termoption line, so in separate string
myfontb="".myfont.", 12"
set termoption font myfontb

set output fn_pngov
set datafile separator ","


set autoscale
unset xtics
unset ytics
unset border
unset arrow # delete all arrows
unset object # (hopefully) delete objects?

set xrange [scope_left:scope_right]
xticstep=(scope_right-scope_left)/scope_hdiv
set xtics in scope_left,xticstep,scope_right scale 1
set yrange [scope_bottom:scope_top]
yticstep=(scope_top-scope_bottom)/scope_vdiv
set ytics in scope_bottom,yticstep,scope_top scale 1
set grid xtics ytics back linecolor rgb "magenta"
set xtics rotate by -45 offset 2.5,-1.50 right format "%+.1s%c" font myfont.',10'

# dimensions of scope screenshot bitmap
bmp_w=480
bmp_h=234

# alpha bmp transparency [0:255]
bmp_alpha = 150
# boxes fillstyle transparent solid 0.10
box_transp = (1.-(acsz/16384.))*0.9 + 0.10

# plot string for data in transparent bitmap:
# for some reason, matches at csvi_offs_ch2/2. ??
plot1au = "(($0-acsz/2.+tfoi+csvi_offs_ch2/2.)*fts+toffs):($5)"

# bmp_w=480 bmp_h=234 ; inside 451x201+15+14
# on plot: scope_left:scope_right and scope_bottom:scope_top!
# (so toffset is built in!)

bdx = scope_trange/(451.0-1)  # [s/pixel] /451: 1.99557e-09 vs 2.000e-9 manually
bdy = totalch1Vspan/(201.0-1) # [V/pixel] /201: 0.0199005 vs 0.02005 manually
bofx = -((scope_trange/2.0)-toffs+(15.0+0)*bdx) #-15.0*bdx # -2.8e-7
bofy = -((totalch1Vspan/2.0)+voffs1+(14.0+5)*bdy) #-14.0*bdy # -0.88

# seems `boxes fillstyle transparent solid 0.40` makes some seethroughs
# or something with bmp alpha overlay; but even without, all the same?
# because the red + blue (somehow inverted) creates a gray.. better green or orange

_plot_str = "zerolineR(x) with lines notitle ls 1,\
acsv_fn \
  using ".plot1au." with boxes fillstyle transparent solid box_transp noborder linestyle 3\
  title 'BITMAP+DATA OVERLAY: '.acsv_fn.' (CH1 only)',\
fn_bmp \
  binary array=(bmp_w,bmp_h) skip=54 format='%uchar' \
  dx=bdx dy=bdy origin=(bofx,bofy) \
  using 1:2:3:(bmp_alpha) \
  with rgbalpha t ''"

# seems actual plot in screenshot bitmap (480 × 234)
#  is at: 451x201+15+14; aspect ratio 201/451 = 0.445676
set size ratio 0.445676

eval("plot " . _plot_str)




##################################
###### montage commands

# used to be in attengrab; now here
# call ImageMagick montage via system
# and montage in `gnuplot` (easier to separate)
# text 95,470 - left align w/ plain bitmap

print "Montaging images..."

cmdstr = 'convert \
  <(montage \
    <(montage \
      <(convert \
        '.fn_bmp.' -gravity Center -crop 640x480-10+0! -flatten  \
        bmp:-) \
      <(convert \
        '.fn_pngov.' -gravity Center -extent x480  \
        bmp:-) \
    -tile 1x -geometry +0+0  \
    bmp:-) \
    <(montage \
      '.fn_pngi.' \
      '.fn_pngr.' \
    -tile 1x -geometry +0+0  \
    bmp:-) \
  -geometry +0+0 -border 5 \
  bmp:-) \
  -pointsize 24 -draw \"text 150,470 ' ."'". repair_str ."'". '\" \
'.fn_pngo

print cmdstr
print system('bash -c "'. cmdstr .'" 2>&1')

print "Deleting temp files ..."

delcmd = "rm"

# leave the bitmap for now
# actually, let attengrab handle it - since
# it may need to be re-taken!
# #cmdstr = delcmd ." ". fn_bmp
# #print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngr
print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngi
print cmdstr . "  " . system(cmdstr . " 2>&1")

cmdstr = delcmd ." ". fn_pngov
print cmdstr . "  " . system(cmdstr . " 2>&1")




# note:
# set terminal png size 840,480 # size defaults to 640x480 px
# set terminal pdf size 10,3 # size defaults to 5x3 in
# enhanced text: set termoption enhanced

# vertical line - headless arrow
# need ymin and ymax; gnuplot gives them only after plot -
# - and even then they do not correspond to end ticks
# - and even then, cannot get the arrow to show, after the second `plot`
# .. nor can I edit it anyhow; it must run before the first `plot`
# so instead of that, position y coordinates relative to graph (0 to 1)
#set arrow 1 from graph 0.5,0 to graph 0.5,1 nohead ls 5

# in multiplot, yrange should be after the size command
# note: xrange could be 2250 or 450
# so leave it to autoscale here? will be accurate since it's integer index...
# now set explicitly by script # below in multiplot

# axis tics format
# for engineering notation - 'help format specifiers':
# "A 'scientific' power is one such that the exponent is a multiple of three."

# print "Montaging images..."

# "The 'tile' size is then set to the largest dimentions
# of all the resized images, and the size actually specified."
# "by removing the 'size' component, non of the images will
# be resized, and the 'tile' size will be set to the largest
# dimensions of all the images given"
# not so simple: http://unix.stackexchange.com/questions/4046/
# can be done in one command with bash subprocess pipes (bash only)
# was: .fn_bmp.' -gravity NorthWest ; fn_pngov.' -gravity North
# can pad with -gravity Center -extent 640x480;
# but also with crop! -flatten - there have offset too!
# -geometry +2+2 can also mess up the last -border 5 !

# bmp scale worked for:
# bmp_w=480 bmp_h=234 ; inside 451x201+15+14
# tdiv = 5e-08,  toffs = 2e-07,  vdiv1 = 0.5,   voffs1 = -1.5,
# dx=2.000e-9 dy=0.02005 origin=(-2.8e-7,-0.88) for
# tspan = 18*tdiv = 18*5e-08 = 9e-07s
# vspan1 = 8*vdiv1 = 8*0.5 = 4V
# tspan/451 = 9e-07/451 = 1.99557e-09 s/pixel
# vspan1/201 = 4/201 = 0.0199005 V/pixel
# bdx=tspan/(451-1) = '9e-07/(451-1)' = 2e-09
# bdy=vspan1/(201-1) = '4/(201-1)' = 0.02
# 15*bdx = 15*2e-9 = 3e-08
# 14*bdy = 14*0.02 = 0.28
# 15*1.99557e-09 = 2.99335e-08
# 14*0.0199005 = 0.278607

__END__


