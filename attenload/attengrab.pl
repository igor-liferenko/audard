#!/usr/bin/env perl

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

# # Call with superuser permission
# # (since attenload/libusb will need it):
# sudo perl attengrab.pl

package attengrab_pl;


=head1 Requirements:

$ sudo perl -MCPAN -e shell
...
cpan[1]> install Term::ReadKey
cpan[1]> install Number::FormatEng

---

... also need to be callable in OS terminal:

attenload
gnuplot
montage   # ImageMagick's
eog

=cut

use 5.10.1;
use warnings;
use strict;
use open IO => ':raw'; # no error

use feature qw/say switch state/;
use Term::ReadKey;
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

use Number::FormatEng qw(:all);

my ($acmd, $proc);
my $alprog = "${EXECDIR}attenload";

my $adscount = 1; # postincrement

sub exit_gracefully {
  ReadMode("restore");
  say "\n", "Ctrl-C pressed; exiting.\n";

  # do an atomized disconnect
  $acmd = "$alprog -d 2>&1";
  say $acmd;

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    print "$line";
  }
  close($proc);

  exit 0;
}
$SIG{'INT'} = \&exit_gracefully;




# for main

my ($char, $pause_time) = 0;
my (@sess_timestamp, $fn_tstamp);
my $awavpl = "${EXECDIR}adsparse-wave.pl";
my $abmppl = "${EXECDIR}adsparse-bitmap.pl";
my $asetpl = "${EXECDIR}adsparse-dvstngs.pl";

my ($fnbase, $fn_tmprawwav, $fn_tmprawbmp, $fn_tmprawset);


sub devset_holdoff_max {

  # now start with dev settings,
  # so adsparse-wave can read and parse the .ssf file
  # do atomized dev settings get

  $acmd = "$alprog 2>&1 -s 6>\"tmprawset\"";
  #~ say $acmd, "\n";
  say "\n";

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    if ($line =~ /^[><\*]/) { print "$line"; };
  }
  close($proc);


  #~ say "\n","Got response; parsing...";

  $acmd = "perl \"$asetpl\" \"tmprawset\" \"tmpraw\" 2>&1";
  #~ say "\n", $acmd;
  open($proc, '-|', $acmd) or die "Could not run $asetpl ... ($!)";
  while (my $line=<$proc>) {
    #~ print "$line";
  }
  close($proc);

  my $infilename = "tmpraw.ssf";
  open(my $fh,'<',$infilename) or die "Cannot open $infilename ($!)";
  binmode($fh);
  my $indata;sysread($fh,$indata,-s $fh);
  close($fh);
  # convert string $indata to array/list, for easier indexing
  # do NOT use split, not binary safe; use unpack instead
  my @aindata = unpack('C*',$indata);

  my $ssf_trig_holdoff_i = unpack("l", pack("C4", @aindata[0xcc..0xcc+3]));
  say "\nGot holdoff " . format_pref($ssf_trig_holdoff_i*10e-9) . "s; setting to 1.5s";
  # at least here we can return the same tmpraw.ssf without problems
  # (we couldn't have done that from attenload.c)
  # however, due to checksum/error correction; any
  # change of data here will be detected in scope with "Location Empty!" error

  # 0x42480000
  #~ @aindata[0x08..0x08+3] = (0x00, 0x00, 0x48, 0x42); #(0x42, 0x48, 0x00, 0x00);
  #~ print join("-",@aindata[0x08..0x08+3]) . "\n";

  # well, this seems to work - if holdoff is at 100ns,
  # and we want to set it to max 1.5s (80 d1 f0 08)?
  # first two bytes (checksum?) must be offset as well!
  # then it errs with "location empty" if it is already at 1.5s!
  # do modulus here too, else may get "Character in 'C' format wrapped in pack"
  @aindata[0xcc..0xcc+3] = (0x80, 0xd1, 0xf0, 0x08);
  $aindata[0] = ($aindata[0]-0x3f) & 255;
  $aindata[1] = ($aindata[1]-0x02) & 255;

  my $settingsOutput = pack("C*", @aindata);
  open($fh,'>',$infilename) or die "Cannot open $infilename ($!)";
  print { $fh } $settingsOutput;
  close($fh);


  #~ say "\n","Re-uploading settings...";

  $acmd = "$alprog 2>&1 -ss \"tmpraw.ssf\"";
  #~ say $acmd, "\n";
  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:512./>/s;
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    if ($line =~ /^[><\*]/) { print "$line"; };
  }
  close($proc);

  unlink "tmpraw.ssf" or warn "Could not delete tmpraw.ssf: $!";
  unlink "tmprawset" or warn "Could not delete tmprawset: $!";
}

sub devset_holdoff_min {

  $acmd = "$alprog 2>&1 -s 6>\"tmprawset\"";
  #~ say $acmd, "\n";
  say "\n";

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    if ($line =~ /^[><\*]/) { print "$line"; };
  }
  close($proc);


  #~ say "\n","Got response; parsing...";

  $acmd = "perl \"$asetpl\" \"tmprawset\" \"tmpraw\" 2>&1";
  #~ say "\n", $acmd;
  open($proc, '-|', $acmd) or die "Could not run $asetpl ... ($!)";
  while (my $line=<$proc>) {
    #~ print "$line";
  }
  close($proc);

  my $infilename = "tmpraw.ssf";
  open(my $fh,'<',$infilename) or die "Cannot open $infilename ($!)";
  binmode($fh);
  my $indata;sysread($fh,$indata,-s $fh);
  close($fh);
  # convert string $indata to array/list, for easier indexing
  # do NOT use split, not binary safe; use unpack instead
  my @aindata = unpack('C*',$indata);

  my $ssf_trig_holdoff_i = unpack("l", pack("C4", @aindata[0xcc..0xcc+3]));
  say "\nGot holdoff " . format_pref($ssf_trig_holdoff_i*10e-9) . "s; setting to 100ns";

  # min 100ns: 0a 00 00 00
  @aindata[0xcc..0xcc+3] = (0x0a, 0x00, 0x00, 0x00);
  $aindata[0] = ($aindata[0]+0x3f) & 255;
  $aindata[1] = ($aindata[1]+0x02) & 255;

  my $settingsOutput = pack("C*", @aindata);
  open($fh,'>',$infilename) or die "Cannot open $infilename ($!)";
  print { $fh } $settingsOutput;
  close($fh);

  #~ say "\n","Re-uploading settings...";

  $acmd = "$alprog 2>&1 -ss \"tmpraw.ssf\"";
  #~ say $acmd, "\n";
  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:512./>/s;
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    if ($line =~ /^[><\*]/) { print "$line"; };
  }
  close($proc);

  unlink "tmpraw.ssf" or warn "Could not delete tmpraw.ssf: $!";
  unlink "tmprawset" or warn "Could not delete tmprawset: $!";
}




#======= "main"

$| = 1; # $|++; # set flushing of output buffers ALREADY HERE; otherwise may end up having a problem with flushing when stdin kicks in;

ReadMode("restore"); # just in case

my $VERSION="[not found]";
if (open my $file, '<', "$EXECDIR/VERSION"){
  $VERSION = <$file>; chomp $VERSION;
  close $file;
}

say STDOUT __FILE__."; attenload version $VERSION";
#say "(program found in: $EXECDIR/)";
say "Called from path $CALLDIR; saving files there.", "\n";


print "Enter filename suffix for this session (or just [ENTER] for no suffix): ";
my $fn_sfx = <>; chomp $fn_sfx;
if ($fn_sfx eq "") {
  say "Not using filename suffix this session.";
} else {
  $fn_sfx = '_' . $fn_sfx;
  say "Using '$fn_sfx' as filename suffix.";
}
# some eog's will not show "image collection" bar if only one img in dir - so make two
# get pidof eog - if eog is running, assume it running in this dir, and do not start it again
if (not(-e "test.png")) {
  say "Creating init images for eog in this directory";
  system("convert -size 150x150 xc:white -pointsize 72 -draw \"text 25,60 'test'\" test.png");
  system("convert -size 150x150 xc:white -pointsize 72 -draw \"text 25,60 'test'\" test2.png");
}
my $eogpid;
chomp($eogpid = `pidof eog`); # remove newline at end (nb, this no good: #$eogpid = chomp $eogpid;)
if ($eogpid eq "") {
  say "Starting eog...";
  system("eog $CALLDIR 2>/dev/null &");
} else { say "Not starting eog [pid: $eogpid]" };

say "\n\n", "## Starting session, ", scalar localtime(), " ##";
say "   (exit with Ctrl-C)", "\n\n";

# do an atomized connect
$acmd = "$alprog -c 2>&1";
say $acmd;

open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
while (my $line=<$proc>) {
  $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
  $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
  print "$line";
}
close($proc);

while(1) { # loop forever;


  ReadMode("cbreak");
STARTWAIT:
  print "\n... waiting - press [SPACE] to start capture ([x]/[n] for holdoff max/min) ...";
  while ($char = ReadKey($pause_time)) {
    print ".";
    if ($char eq "x") { devset_holdoff_max(); goto STARTWAIT; };
    if ($char eq "n") { devset_holdoff_min(); goto STARTWAIT; };
    last if $char eq " ";
  }
  print "\n\n";
  ReadMode("restore");

  $| = 1; # $|++; # set flushing of output buffers (even if already set above)

  # damn it - note that localtime returns:
  # " $mon the month in the range 0..11"
  # so must add 1 to get correct month!
  @sess_timestamp = localtime();
  $fn_tstamp = sprintf("%04d%02d%02d-%02d%02d%02d",
    ($sess_timestamp[5]+1900), $sess_timestamp[4]+1,
    $sess_timestamp[3], $sess_timestamp[2],
    $sess_timestamp[1], $sess_timestamp[0]
  );


  $fnbase = "${fn_tstamp}$fn_sfx";
  say "Starting capture $fnbase (", scalar localtime(), ")\n";

  $fn_tmprawwav = "tmp_${fnbase}_wav";
  $fn_tmprawbmp = "tmp_${fnbase}_bmp";
  $fn_tmprawset = "tmp_${fnbase}_set";

  # now start with dev settings,
  # so adsparse-wave can read and parse the .ssf file
  # do atomized dev settings get

  $acmd = "$alprog 2>&1 -s 6>\"$fn_tmprawset\"";
  say $acmd, "\n";

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    print "$line";
  }
  close($proc);


  say "\n","Got response; parsing...";


  $acmd = "perl \"$asetpl\" \"$fn_tmprawset\" \"$fnbase\" 2>&1";
  say "\n", $acmd;
  open($proc, '-|', $acmd) or die "Could not run $asetpl ... ($!)";
  while (my $line=<$proc>) {
    print "$line";
  }
  close($proc);



  # do atomized wave get
  #~ $acmd = "$alprog 2>&1 4>\"$fn_tmprawwav\" 5>\"$fn_tmprawbmp\" 6>\"$fn_tmprawset\"";
WAVEGET:
  $acmd = "$alprog 2>&1 -w 4>\"$fn_tmprawwav\"";
  say $acmd, "\n";

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    print "$line";
  }
  close($proc);

  say "\n","Got response; parsing...";

  $acmd = "perl \"$awavpl\" \"$fn_tmprawwav\" \"$fnbase\" 2>&1";
  say "\n", $acmd;
  open($proc, '-|', $acmd) or die "Could not run $awavpl ... ($!)";
  while (my $line=<$proc>) {
    print "$line";
  }
  close($proc);

  my $wavfail = 0;
  if ($? != 0) { # awavpl returns 1 on error, 0 on OK
    $wavfail = 1;
    say "No data; repeat? [SPACE/[y] for yes; [n] for no and complete; any other key to skip rest to next]";
    ReadMode("cbreak");
    $char = ReadKey($pause_time); # only one char
    ReadMode("restore");
    if (($char eq " ") or ($char eq "y")) { goto WAVEGET; }
    elsif (($char eq "n")) {} # do nothing, finish as if OK
    else { next; }; # `next` - like C `continue` (skip rest of loop; restart)
  }

  # do atomized bitmap get

BITMAPGET:
  $acmd = "$alprog 2>&1 -b 5>\"$fn_tmprawbmp\"";
  say $acmd, "\n";

  open($proc, '-|', $acmd) or die "Could not run $alprog ... ($!)";
  while (my $line=<$proc>) {
    $line =~ s/bulk transfer \(out\): r:0, act:64./>/s;
    $line =~ s/bulk transfer \(in \): r:0, act:512./</s;
    print "$line";
  }
  close($proc);


  say "\n","Got response; parsing...";

  $acmd = "perl \"$abmppl\" \"$fn_tmprawbmp\" \"$fnbase\" 2>&1";
  say "\n", $acmd;
  open($proc, '-|', $acmd) or die "Could not run $abmppl ... ($!)";
  while (my $line=<$proc>) {
    print "$line";
  }
  close($proc);




  # gnuplot generates two pngs, _r, and _i - now three; and runs montage commands
  if ($wavfail == 0) {      # run gnuplot only if wav has not failed
    $acmd = "gnuplot $fnbase.gnuplot";
    say "\n", $acmd;
    system("$acmd");
    if( $? == -1 ) {
      print "command failed: $!\n";
    }
  } else { print ".csv failed - _not_ running gnuplot\n"; };

=head1 Not here anymore - running montage moved to gnuplot script! (except for bmp)

  my $fn_pngr = "${fnbase}_r.png";
  my $fn_pngi = "${fnbase}_i.png";
  my $fn_pngt = "${fnbase}_tmp.png";
  my $fn_pngo = "${fnbase}.png";

  $acmd = "montage \"$fn_pngi\" \"$fn_pngr\" -geometry +2+2 -tile 1x2 \"$fn_pngt\"";
  say $acmd;
  system("$acmd");
  if( $? == -1 ) {
    print "command failed: $!\n";
  }

  # alt: "montage \"$fn_bmp\" \"$fn_pngt\" -geometry '+2+2' -tile x1 -gravity NorthEast -border 5 \"$fn_pngo\""
  $acmd = "montage \"$fn_bmp\" \"$fn_pngt\" -mode Concatenate -tile x1 -border 5 \"$fn_pngo\"";
  say $acmd;
  system("$acmd");
  if( $? == -1 ) {
    print "command failed: $!\n";
  }

=cut

  { # check bitmap here
    say "\n(if gnuplot image available) Please check if bitmap matches the wave data!";
    say "If not - repeat bitmap acquisition? [y/n]";
    ReadMode("cbreak");
    $char = ReadKey($pause_time); # only one char
    ReadMode("restore");
    if ($char eq "y") { goto BITMAPGET; }
    # else { next; }; # else just proceed
  }


say "\n","Deleting temp files ...";
# delete raw bitmap file - since we probably have extracted it into .bmp
unlink $fn_tmprawbmp or warn "Could not delete $fn_tmprawbmp: $!";
# if wav failed, it doesn't matter if we keep $fn_tmprawwav;
# all valuable data will be anyways in the truncated .csv;
# so delete anyhow (unless keeping tmprawwav for compare test runs)
unlink $fn_tmprawwav or warn "Could not delete $fn_tmprawwav: $!";
unlink $fn_tmprawset or warn "Could not delete $fn_tmprawset: $!";

# would keep fn_bmp also, but no need, really - in adscompare.pl
# we just pipe convert's crop output to gnu`plot`
# BMP_fn = '<convert -crop 480x234+95+128 "${atgpngfile}" bmp:-'
# but, if failed, then keep the bitmap! (delete only on success)
my $fn_bmp = "${fnbase}.bmp";
if ( $wavfail == 0 ) { # not fail == success:
  unlink $fn_bmp or warn "Could not delete $fn_bmp: $!";
}




=head1 These not here anymore - deleting (gnuplot) temp files for montage moved to gnuplot script!

  unlink $fn_pngr or warn "Could not delete $fn_pngr: $!";
  unlink $fn_pngi or warn "Could not delete $fn_pngi: $!";
  unlink $fn_pngt or warn "Could not delete $fn_pngt: $!";

=cut

  my $fn_note = "${fnbase}.note";
  say "\n", "Enter one-line note for this capture (or just [ENTER] for empty note): ";

  # make a default first word (counter)
  # insert it via stdin, so user can modify the numbers if needed

  my $adsnums = sprintf("%05d", $adscount);
  system("sleep 0.05; perl -e '\$TIOCSTI = 0x5412;
\$tty = \"/dev/tty\";
\$word = \"ADS$adsnums\";
\@chars=split(\"\",\$word);
open(\$fh, \">\", \$tty);
foreach \$char ( \@chars ) {
  ioctl(\$fh, \$TIOCSTI, \$char);
  # select(undef,undef,undef,0.1); # just pauses, no need
}'");

  my $notetext = <>; # keep the newline, do not chomp $fn_sfx; (locks)

  my $nfh;
  open($nfh,'>',$fn_note) or die "Cannot open $fn_note ($!)";
  print { $nfh } $notetext;
  close($nfh);

  say "\n", "Saved note $fn_note";
  $adscount++; # postincrement

  say "\n", "Finished capture $fnbase (", scalar localtime(), ")\n\n";

} # end while...

exit 0; # should be by default - but keeping it anyways.. won't be able to reach it either, since Ctrl-C exits :)

