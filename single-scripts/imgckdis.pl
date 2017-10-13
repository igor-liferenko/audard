#!/usr/bin/perl

# imgckdis.pl
# copyleft sdaau 2012

# single instance image displayer;
# call from any terminal:
# perl imgckdis.pl file.png
# .. and that file will be loaded in master instance

use warnings;
use strict;
use Image::Magick; # sudo apt-get install perlmagick # debian/ubuntu
use Tk;
use MIME::Base64;

use Carp;
use Fcntl ':flock';

# only for debugging:
#use Data::Printer;
#use Class::Inspector;

use IPC::Shareable;


my $amMaster = 1;
my $file_read;

open my $self, '<', $0 or die "Couldn't open self: $!";
flock $self, LOCK_EX | LOCK_NB or $amMaster = 0;

if ($amMaster == 1) {
  print "We are master single instance as per flock\n";
  IPC::Shareable->clean_up_all;
}

if (!$ARGV[0]) {
  $file_read = "xc:white";
} else {
  $file_read = $ARGV[0];
}
chomp $file_read;


my %options = (
  create    => 1,
  exclusive => 0,
  mode      => 0644,
  destroy   => 0,
);

my $glue1 = 'dat1';
my $glue2 = 'dat2';

my $refcount;
my $reffname;
my $lastreffname;

my $refcount_handle = tie $refcount, 'IPC::Shareable', $glue1 , \%options ;
if ($amMaster == 1) {
  $refcount = undef;
}

my $reffname_handle = tie $reffname, 'IPC::Shareable', $glue2 , \%options ;
if ($amMaster == 1) {
  $reffname = undef;
}

my ($image, $blob, $content, $tkimage, $mw);


if ($amMaster == 1) { # if (not(defined($refcount))) {
  # initialize the assigns
  $lastreffname = "";

  $reffname_handle->shlock(LOCK_SH|LOCK_NB);
  $reffname = $file_read; #
  $reffname_handle->shunlock();

  $refcount_handle->shlock(LOCK_SH|LOCK_NB);
  $refcount = 1; #
  $refcount_handle->shunlock();
}

# mainly from http://objectmix.com/perl/771215-how-display-image-magick-image-tk-canvas.html
sub generateImageContent() {
  #fake a PGM then convert it to gif
  $image = Image::Magick->new(
    size => "400x400",
  );
  $image->Read($file_read); #("xc:white");
  $image->Draw(
    primitive => 'line',
    points => "300,100 300,500",
    stroke => '#600',
  );
  # set it as PGM
  $image->Set(magick=>'pgm');

  #your pgm is loaded here, now change it to gif or whatever
  $image->Set(magick=>'gif');
  $blob = $image->ImageToBlob();

  # Tk wants base64encoded images
  $content = encode_base64( $blob ) or die $!;
}

sub loadImageContent() {
  #fake a PGM then convert it to gif
  $image = Image::Magick->new(
    size => "400x400",
  );
  $image->Read($lastreffname); #("xc:red") for test

  # set it as PGM
  $image->Set(magick=>'pgm');

  #your pgm is loaded here, now change it to gif or whatever
  $image->Set(magick=>'gif');
  $blob = $image->ImageToBlob();

  # Tk wants base64encoded images
  $content = encode_base64( $blob ) or die $!;

  #~ $tkimage->read($content); # expects filename
  $tkimage->put($content); # works!
}


sub CleanupExit() {
  # only one remove() passes - the second fails: "Couldn't remove shared memory segment/semaphore set"
  (tied $refcount)->remove();
  IPC::Shareable->clean_up;
  $mw->destroy();
  print "Exiting appliction!\n";
  exit;
}

sub updateVars() {
  if ( not($reffname eq $lastreffname) ) {
    print "Change: ", $lastreffname, " -> ", $reffname, "\n";
    $lastreffname = $reffname;
    loadImageContent();
  }
}

if ( not($amMaster == 1) ) {
  # simply set the shared variable to cmdarg variable
  # (master's updateVars should take care of update)
  $reffname_handle->shlock(LOCK_SH|LOCK_NB);
  $reffname = $file_read;
  $reffname_handle->shunlock();

  # and exit now - we don't want a second instance
  print "Main instance of this script is already running\n";
  croak "Loading new file: $file_read";
}


$mw = MainWindow->new();
$mw->protocol(WM_DELETE_WINDOW => sub { CleanupExit(); } );

generateImageContent();
$tkimage = $mw->Photo(-data => $content);

$mw->Label(-image => $tkimage)->pack(-expand => 1, -fill => 'both');
$mw->Button(-text => 'Quit', -command => sub { CleanupExit(); } )->pack;

# polling function for sharable - 100 ms
$mw->repeat(100, \&updateVars);


MainLoop;



__END__


#####################

use warnings;
use strict;
use Image::Magick; # sudo apt-get install perlmagick # debian/ubuntu
use Tk;
#use Tk::JPEG;
#use Tk::PNG;
use MIME::Base64;

#~ use Storable;

use B; # core module providing introspection facilities

#~ use Tk::Canvas; # also possible
#~ my $img = $mw->Canvas(-background=>'black',-width=>640,-height=>480)->pack();

# syntax error at imgpl.pl line 18, near "croak "This script is already running""
# (Do you need to predeclare croak?)
# perl -WMCarp imgpl.pl # OK
use Carp; # use Carp; fixes, so now again can just call perl imgpl.pl
use Fcntl ':flock';

#~ use Data::Inspect; # sudo perl -MCPAN -e shell ; install Data::Inspect
#~ my $insp = Data::Inspect->new;

use Data::Printer; # sudo perl -MCPAN -e shell ; install Data::Printer (may install a ton of dependencies); install Test::Output manually; maybe Algorithm::C3? module 'SUPER'; Class::Load::XS has problems here.. ->   '/usr/bin/perl Build.PL --installdirs site' returned status 2304, won't make ; running manual: Module::Build version 0.3601 required--this is only version 0.340201 at Build.PL line 5. ; running install Module::Build - installs 0.4 (+ deps) .. OK ; install Class::Load::XS - ExtUtils::CBuilder not installed; install ? ExtUtils::CBuilder is up to date (0.280205)? ; sudo /usr/bin/perl Build.PL --installdirs site # manually - now OK, "Creating new 'Build' script for 'Class-Load-XS'" ; install Class::Load::XS # now it works ; again install Data::Printer : OK.. ; install Tk to update as well? Takes a while, test failed - leave it..

use Class::Inspector;  # sudo perl -MCPAN -e shell ; install Class::Inspector

use IPC::Shareable;  # sudo perl -MCPAN -e shell ; install IPC::Shareable (error, not updated - fix: http://www.perlmonks.org/?node_id=879713); note two locs in ~/.cpan/build/IPC-Shareable-0.60-py03La/ : lib/IPC/Shareable.pm and blib/lib/IPC/Shareable.pm (change the blib) ; IPC::Shareable::SharedMem is up to date

my $refcount;

my $amMaster = 1;

open my $self, '<', $0 or die "Couldn't open self: $!";
#~ flock $self, LOCK_EX | LOCK_NB or croak "This script is already running";
flock $self, LOCK_EX | LOCK_NB or $amMaster = 0; #reloadImage();

p($refcount); # dbg, Data::Printer

if ($amMaster == 1) {
  print "We are master single instance as per flock\n";
  IPC::Shareable->clean_up_all;
}


my $file_read;
if (!$ARGV[0]) {
  $file_read = "xc:white";
} else {
  $file_read = $ARGV[0];
}
chomp $file_read;

#~ my @refvars = ($image, $blob, $content, $tkimage, $mw);

#~ tie $image, 'IPC::Shareable', 'timg';
my $glue1 = 'dat1';
my $glue2 = 'dat2';
my $glue3 = 'dat3';
my %options = (
  create    => 1, #'yes',
  exclusive => 0,
  mode      => 0644, #0644,
  destroy   => 0, #1 # 'yes', # with 0, disables autodestroy! handle manually
);

#~ my $image_handle = tie  $resource, 'IPC::Shareable', undef , { destroy => 1 };
#~ my $image_handle = tie  \$image, 'IPC::Shareable', $glue , { %options } or die "tie failed";
#~ my $blob_handle = tie  \$blob, 'IPC::Shareable', $glue , { %options };
#~ my $content_handle = tie  \$content, 'IPC::Shareable', $glue , { %options };
#~ my $tkimage_handle = tie  \$tkimage, 'IPC::Shareable', $glue , { %options };
#~ my $mw_handle = tie  \$mw, 'IPC::Shareable', $glue , { %options };

# correct syntax:
# note, two array vars connected to same $glue would have same values (be connected!)
my ($image, $blob, $content, $tkimage, $mw);
#~ my $refvars; # = [$image, $blob, $content, $tkimage, $mw];
#~ my @refvars; # = [$image, $blob, $content, $tkimage, $mw];
my @refvars; # = ( "1", "2", "", "", ""); # this one is already a ARRAY(0xa035a18) when second instance kicks in; so do NOT tie it? and its the wrong address...

print 'a ', @refvars, \@refvars, "\n";
my $refvar_handle = tie @refvars, 'IPC::Shareable', $glue1 , \%options ; # don't store this as array?; Store it, but don't try showing it - just there to keep memory shared? But again, it becomes SCALAR - handle reinit for master..
# AND: note now in client:
#  DB<1> p @refvars
#
#  DB<2> p \@refvars
#ARRAY(0xa303a18)


#~ print 'b ', @refvars, "\n"; # if previous runs, here @refvars: Can't use string ("SCALAR(0x9eb49e0)") as a SCALAR ref
#~ print 'b1 ', $refvar_handle, "\n"; #
if ($amMaster == 1) {
@refvars = undef;
}

print 'b2 ', \@refvars, "\n"; #
#~ print 'b ', (${@refvars}[1]), "\n"; #

my $refcount_handle = tie $refcount, 'IPC::Shareable', $glue2 , \%options ; #
p ($refcount_handle);
p ($refcount);

my $refvarstr= "A";
p($refvarstr);
print \$refvarstr, "\n";
my $refvarstr_handle = tie $refvarstr, 'IPC::Shareable', $glue3 , \%options ;
# here $refvarstr somehow becomes "ARRAY(0x88417c8)" instead of undef; reset
# but reset ONLY in master - else the clients inherit an undef too!
print "1 ";  p($refvarstr_handle);
if ($amMaster == 1) {
$refvarstr = undef;
}
print "2 "; p($refvarstr_handle);
p($refvarstr);


p($refcount); # dbg, Data::Printer

if (not(defined($refcount))) {
  # we are master, set
  print "We are master single instance; marking\n";
  #~ $refvars = [$image, $blob, $content, $tkimage, $mw]; # anonymous; ref unkept?!
  #~ $refvars = \($image, $blob, $content, $tkimage, $mw); # cant store CODE items
  #~ $refvars = \(\$image, \$blob, \$content, \$tkimage, \$mw); # passes... but still

  # the lowercase trick - no need here, just for direct vars?
  my $refi = \$image;   my $srefi = "" . $refi;
  my $refb = \$blob;    my $srefb = "" . $refb;
  my $refc = \$content; my $srefc = "" . $refc;
  my $reft = \$tkimage; my $sreft = "" . $reft;
  my $refm = \$mw;      my $srefm = "" . $refm;

  #~ $refvar_handle->shlock(LOCK_SH|LOCK_NB);
  #~ $refvars = ($srefi, $srefb, $srefc, $sreft, $srefm); # not a ref; plain ... but Can't use string ("SCALAR(0x98c1570)") as a SCALAR ref while "strict refs" in use
  # NOTE: @a = (...) with ref \@ .. anonymous: $b = [] with $b already a ref !!
  #~ @refvars = ($srefi, $srefb, $srefc, $sreft, $srefm);
  @refvars = ( "$srefi", "$srefb", "$srefc", "$sreft", "$srefm" );
  #~ my $rrefvars = \$refvars;
  #~ $refvar_handle->shunlock();


  my $rrefvars = \@refvars;

  $refvarstr_handle->shlock(LOCK_SH|LOCK_NB);
  # lowercase trick - must be there since we store a reference! strict will complain!
  $refvarstr = lc "" . $rrefvars;
  #~ $refvarstr = "" . $rrefvars;
  $refvarstr_handle->shunlock();

  $refcount_handle->shlock(LOCK_SH|LOCK_NB);
  $refcount = 1; # must come after setting $refvars - else it gets mixed up!
  $refcount_handle->shunlock();
  print "3 "; p($refvarstr_handle);
  print "init: $refvarstr ~ \n"; # $refvar_handle ; no print @refvars here
} else {
  print "Master single instance already running; marked: $refcount\n";
  if ($amMaster == 1) {
    print "Something bad - we should be master; trying to clean up";
    print "(Rerun once more after this)";
    IPC::Shareable->clean_up_all;
    die "Exiting";
  }
  # if refcount=1 - master running - retrieve vars;
  #~ $refvar_handle->shlock(LOCK_SH|LOCK_NB);
  ## refresh variables through dereferenced array
  # eh, for this damn extract hex address to work - we do need lowercase :S
  # so don't move it back to uppercase; needs $yyy =~ s/array/ARRAY/;
  #~ my $refrest = uc $refvarstr;
  #~ print "refrest", lc $refrest;
  # extract the hex address
  my ($addr) = $refvarstr =~ /.*(0x\w+)/; #  was via $refrest
  # fake up a B object of the correct class for this type of reference
  # and convert it back to a real reference
  print "\n addr $addr\n";
  my $treal_refvars = bless(\(0+hex $addr), "B::AV")->object_2svref;
  $treal_refvars =~ s/SCALAR/ARRAY/; # in-place regex replace
  my @lref = @$treal_refvars; # Bizarre copy of ARRAY in aassign at imgpl.pl line 172. with the regex: Segmentation fault
  # $treal_refvars: SCALAR(0x88777b0);  =~ s/SCALAR/ARRAY/ - nothing; memory not shared?
  print "lref @lref\n";

  #~ my @lref = @refvars;
  my $strrep = "";
  $strrep .= "image: "; $image = $lref[0]; if ($image) { $strrep .= $image . ", "; };
  $strrep .= "blob: "; $blob = $lref[1]; if ($blob) { $strrep .= $blob . ", "; };
  $strrep .= "content: "; $content = $lref[2]; if ($content) { $strrep .= $content . ", "; };
  $strrep .= "tkimage: "; $tkimage = $lref[3]; if ($tkimage) { $strrep .= $tkimage . ", "; };
  $strrep .= "mw: "; $mw = $lref[4]; if ($mw) { $strrep .= $mw . ", "; };
  #~ $refvar_handle->shunlock();
  print "non-master: $strrep\n";
  print "non-master: $refvarstr ~ @refvars\n"; # $refvar_handle
}

p($refcount); # dbg, Data::Printer

#~ Master: IPC::Shareable=HASH(0xa42fdb8) 2
#~ non-master: IPC::Shareable=HASH(0x8a47eb8) 2


sub loadImage() {
  # function arguments - like this:
  p($refcount); # dbg, Data::Printer

  my $invar = $_[0];
  my $doInitLoad = 0;
  if ($refcount) { #if ($invar) {
    if ($refcount == 1) { #if ($invar == 1) {
      $doInitLoad = 1;
      $refcount = 2;
    }
  } ;

  #fake a PGM then convert it to gif
  $image = Image::Magick->new(
    size => "400x400",
  );
  $image->Read($file_read); #("xc:white");
  $image->Draw(
    primitive => 'line',
    points => "300,100 300,500",
    stroke => '#600',
  );
  # set it as PGM
  $image->Set(magick=>'pgm');

  #your pgm is loaded here, now change it to gif or whatever
  $image->Set(magick=>'gif');
  $blob = $image->ImageToBlob();

  # Tk wants base64encoded images
  $content = encode_base64( $blob ) or die $!;

  #~ $tkimage = $mw->Photo(-data => $content);
  #~ $tkimage->read($content);
  #~ $tkimage->put($content); # undefined?

  if ($doInitLoad == 1) {
    $tkimage = $mw->Photo(-data => $content);
    print "Master: $image \n- $blob \n- $content \n- $tkimage \n- $mw\n";
    #~ $refvar_handle->shlock(LOCK_SH|LOCK_NB);
    print "Master: ~ \n"; #  $refvar_handle # no print @refvars
    #~ $refvar_handle->shunlock();
  } else {
    # $tkimage undefined for ghost here..
    # the second instance is already a fork - no shared vars
    $tkimage->read($content);

    # retrieve refs? use shlock...
  } ;


  #~ $insp->p(%$tkimage); # #<Tk::Photo {}>
  #~ print($insp->inspect($tkimage) . "\n");

  #~ no strict 'refs';
  #~ for(keys %Tk::) { # All the symbols in Tk's symbol table; confess carp exit tkinit MainLoop DoOneEvent Exists croak Ev
    #~ print "$_\n" if defined &{$_}; # check if symbol is method
  #~ }
  #~ use strict 'refs';

  #~ p($tkimage);
    #~ Tk::Photo  {
      #~ Parents       Tk::Image
      #~ Linear @ISA   Tk::Photo, Tk::Image, DynaLoader, Tk, Exporter
      #~ public methods (1) : Tk_image
      #~ private methods (0)
      #~ internals: {}
  #~ }
  #~ Segmentation fault

  #~ p($tkimage->Tk_image()); # "photo"
  #~ p( Tk::Photo ); # no

  my $funcs = Class::Inspector->functions( 'Tk::Photo' );
  #~ my $funcs = Class::Inspector->methods( 'Tk::Photo' );
  #~ print @$funcs;
  print Class::Inspector->filename( 'Tk::Photo' ) . "\n"; # Tk/Photo.pm
  print "$_\n" for @$funcs;
  # functions: Tk_image blank copy data formats get put read redither transparency transparencyGet transparencySet write
  # methods: ACTIVE_BG ALL_EVENTS AUTOLOAD AddErrorInfo BLACK BackTrace BackgroundError CLONE CheckHash ClassInit ClearErrorInfo ColorDialog Construct CreateGenericHandler DESTROY DISABLED DONT_WAIT Debug DebugHook DialogWrapper DirDialog DoOneEvent DoWhenIdle Ev Exists FDialog FILE_EVENTS Fail GetFILE GetFocusWin GetPointerCoords IDLE_EVENTS INDICATOR InitClass Install IsParentProcess MainLoop MessageBox Methods MotifFDialog NORMAL_BG NeedPreload NoOp OldEnterMethods Preload SELECT_BG SELECT_FG SelectionClear SelectionExists SelectionHandle SelectionOwn SelectionOwner SplitString SystemEncoding TIMER_EVENTS TROUGH Time_So_Far Tk_image TranslateFileName WHITE WINDOW_EVENTS WidgetMethod __DIE__ _adapt_path_to_os _backTrace _menu abort after as_heavy backtrace bell bind bindtags blank boot_DynaLoader bootstrap bootstrap_inherit button bytes2str carp catch cget checkbutton chooseColor chooseDirectory clipboard clipboardAppend clipboardClear clone_encoding confess configure copy croak data decode decode_utf8 delete destroy die_with_trace dl_error dl_find_symbol dl_install_xsub dl_load_file dl_load_flags dl_undef_symbols dl_unload_file encode encode_utf8 encodings event exit export export_fail export_ok_tags export_tags export_to_level fileevent findINC find_encoding focus font form formats frame get getOpenFile getSaveFile grab grid height idletasks image import itemstyle label labelframe lower message messageBox new option optionAdd optionClear optionGet optionReadfile pack panedwindow place property put radiobutton raise read redither require_version selection send str2bytes tainted tainting timeofday tk tk_chooseColor tk_chooseDirectory tk_getOpenFile tk_getSaveFile tk_messageBox tkinit tkwait toplevel transparency transparencyGet transparencySet type update width winfo wm write

}

sub reloadImage() {
  if (!$ARGV[0]) {
    $file_read = "xc:white";
  } else {
    $file_read = $ARGV[0];
  }
  loadImage();
  croak "This script is already running";
}

sub CleanupExit() {
  # only one remove() passes - the second fails: "Couldn't remove shared memory segment/semaphore set"
  #~ (tied @refvars)->remove(); # $refvar_handle->remove();  #~ $refvars->remove;
  (tied $refcount)->remove(); # $refcount_handle->remove();  #~ $refcount->remove;
  IPC::Shareable->clean_up;
  #~ IPC::Shareable->clean_up_all;
  $mw->destroy();
  print "Exiting appliction!\n";
  exit;
}

if (not($amMaster == 1)) {
  reloadImage();
}



$mw = MainWindow->new();
$mw->protocol(WM_DELETE_WINDOW => sub { CleanupExit(); } );


#~ $tkimage = $mw->Photo(-data => $content);
#~ $tkimage = $mw->Photo(-data => $content);
# call function with argument 1
&loadImage(1);

$mw->Label(-image => $tkimage)->pack(-expand => 1, -fill => 'both');
#~ $mw->Button(-text => 'Quit', -command => [destroy => $mw])->pack;
$mw->Button(-text => 'Quit', -command => sub { CleanupExit(); } )->pack;
MainLoop;

__END__

# mainly from:
[How to display an Image::Magick image in a Tk::Canvas?](http://objectmix.com/perl/771215-how-display-image-magick-image-tk-canvas.html)

[Installing the Perl Image::Magick module on CentOS 5.2 (Fourmilog: None Dare Call It Reason)](http://www.fourmilab.ch/fourmilog/archives/2008-12/001099.html)

[perl - How do I install Image::Magick on Debian etch? - Stack Overflow](http://stackoverflow.com/questions/1260663/how-do-i-install-imagemagick-on-debian-etch)

[[magick-users] PerlMagick 6.0.0 Composite -opacity doesn't work](http://studio.imagemagick.org/pipermail/magick-users/2004-May/012679.html)

[Ensuring only one copy of a perl script is running at a time](http://www.perlmonks.org/?node_id=590619)

[Re: Limiting a program to a single running instance - nntp.perl.org](http://www.nntp.perl.org/group/perl.beginners/2007/10/msg95773.html)

[Sys::RunAlone - search.cpan.org](http://search.cpan.org/~elizabeth/Sys-RunAlone-0.12/lib/Sys/RunAlone.pm)

[What's the best way to make sure only one instance of a Perl program is running? - Stack Overflow](http://stackoverflow.com/questions/455911/whats-the-best-way-to-make-sure-only-one-instance-of-a-perl-program-is-running)

[reinstall PERL - PERL Beginners (Do you need to predeclare croak?)](http://www.justskins.com/forums/reinstall-perl-16399.html)

[Image in Perl TK?](http://www.perlmonks.org/?node_id=731610)

[Perl Tk::Photo help](http://x10hosting.com/forums/programming-help/92296-perl-tk-photo-help.html)

[introspection - How do I list available methods on a given object or package in Perl? - Stack Overflow](http://stackoverflow.com/questions/910430/how-do-i-list-available-methods-on-a-given-object-or-package-in-perl)

[Can't install IPC:Shareable](http://www.perlmonks.org/?node_id=879713)

[Share variables between Child processes in perl without IPC::Shareable - Stack Overflow](http://stackoverflow.com/questions/4879797/share-variables-between-child-processes-in-perl-without-ipcshareable)

[IPC::Shareable - search.cpan.org](http://search.cpan.org/~bsugars/IPC-Shareable-0.60/lib/IPC/Shareable.pm)

[perl - Checking IPC Shareable lock - Stack Overflow](http://stackoverflow.com/questions/8166063/checking-ipc-shareable-lock)

[Storing complex data structures using Storable](http://www.perlmonks.org/?node_id=819999)

[using tie on two arrays on IPC::Shareable makes array1 and array2 both same even though array2 is not updated.](http://www.perlmonks.org/?node_id=799539)

[Dereferencing in perl](http://perlmeme.org/howtos/using_perl/dereferencing.html)

[Shared Memory using IPC::Shareable - Can't use an undefined value as an ARRAY reference](http://www.perlmonks.org/?node_id=823756)

[Re: Handling child process and close window exits in Perl/Tk](http://www.perlmonks.org/?node_id=578304)

[How can I convert the stringified version of array reference to actual array reference in Perl? - Stack Overflow](http://stackoverflow.com/a/1671495/277826)

[Re: IPC::Shareable Problem with multidimentional hash](http://coding.derkeiler.com/Archive/Perl/comp.lang.perl.misc/2005-09/msg00667.html)

[perl - IPC::Shareable variables, "Can't use string ... as a SCALAR ref.." and memory address - Stack Overflow](http://stackoverflow.com/questions/10668453/ipcshareable-variables-cant-use-string-as-a-scalar-ref-and-memory-ad)

---

better idea: since this IPC::Shareable wont work as inended (to retrieve reference of master, and call its methods) - maybe we can just toss the filename directly.... but then have to have Tk poll for a variable..

$MW->repeat($MILLISECOND_DELAY, \&modo);

[Perl/Tk App and Interprocess Communication](http://www.perlmonks.org/?node_id=470827)

[Re: Antw: Re: Perl/Tk + Thread - nntp.perl.org](http://www.nntp.perl.org/group/perl.beginners/2003/05/msg47199.html)


