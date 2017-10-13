#!/usr/bin/env bash
################################################################################
# unpack-tshark.sh                                                             #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################
# Tue Jun 24 01:43:56 CEST 2014 ; GNU bash, version 4.2.8(1)-release (i686-pc-linux-gnu)
# unpack-tshark-usb.sh

if [ "$1" == "" ]; then # check argument
  echo "Need an input .pcap file argument; exiting." ;
  exit
fi

# http://stackoverflow.com/a/6309461/277826
makeargs() { while read line; do printf "%s " ${line//#*/}; done }

# NB: on Ubuntu Lucid, tshark 1.2.7 + libpcap 1.0.0 can dump -e usb.data
# on Ubuntu Natty, tshark 1.4.6 + libpcap 1.1.1 can NOT dump -e usb.data
# (checked with identical file - probably a bug.)
# so the use of tshark -Tfields -e... is shown now in OLDER_CODE below;
# else here we'll parse the output of tshark -V -x (more complicated as it's
# multiline, but at least has both decoded headers and data)

# EP 1 IN: 0x81 and EP 2 OUT 0x02
# tshark -G | grep -i usb | less # show all existing usb fields
# tshark needs -x to dump data; and "Raw packet hex data can only be printed as text or PostScript"
# format tshark like .csv:
# (for quicker, first output segments from multi-line, to build a single line per packet)
# note 01 60 doesn't always occur at offset 0040; also at 00c0, 0200
# note: bRequest, which is the GET DESCRIPTOR (6) or URB_BULK out, only shows in ~500 out of 7000 packets; will leave it out; also bDescriptorType: DEVICE (1) shows only up to frame 5/7000 ...
# can limit processing from the tshark command line:
# -R 'frame.number >= 1789 && frame.number <= 1812'
tshark -R 'frame.number >= 1789 && frame.number <= 1812' -r "$1" -V -x | #
  perl -ne ' # first perl: multi into single line (not all fields will be present)
  #( $first_capture, ) = $_ =~ /$some_pattern/;
  print "\nframe.number: $1, " if /Frame ([\d]+):/; # same as Frame Number
  print "frame.epoch_time: $1, " if /Epoch Time: ([\d\.]+)/;
  print "dtime: $1, " if /Time since reference or first frame: ([\d\.]+)/;
  print "frame.len: $1, " if /Frame Length: ([\d]+)/;
  print "frame.cap_len: $1, " if /Capture Length: ([\d]+)/;
  print "usb.urb_type: $1, " if /URB type: (.*)/;
  print "usb.transfer_type: $1, " if /URB transfer type: (.*)/;
  print "usb.endpoint_number: $1, " if /Endpoint: (.*)/;
  print "usb.device_address: $1, " if /^    Device: (.*)/; # harder cond; there is another bcdDevice: 0x0600 that may show
  print "usb.bus_id: $1, " if /URB bus id: (.*)/;
  print "usb.data_flag: $1, " if /Data: (.*)/;
  print "usb.urb_status: $1, " if /URB status: (.*)/;
  print "usb.urb_len: $1, " if /URB length \[bytes\]: ([\d]+)/;
  print "usb.data_len: $1, " if /Data length \[bytes\]: ([\d]+)/;
  print "reqid: $1 $2, " if /\[Request in: ([\d]+)\]/; # no "Response in" in this log!
  print "urbset.dir: $1 $2, " if /([\d])\..*Direction: (.*)/;
  print "urbset.recpnt: $1, " if /Recipient: (.*)/;
  print "urb.data: ".substr($1,0,42).", " if /0040  (.*)/;
  ' | # -MData::Dumper
  perl  -MText::CSV -e ' # second perl: read line by line; parse fields from a line, and output .csv with header
  $csvobj = Text::CSV->new({quote_char=>""}); #, always_quote=>1}) ;
  # chosen fields (w/ order):
  @CF = ( "frame.number", "dtime", "frame.epoch_time", "src", "dst",
  "usb.urb_type", "usbtyp", "reqid", "respid", "usb.data_flag", "usbdflg",
  "usb.transfer_type", "usbttyp", "usb.bus_id", "usb.device_address", "usb.endpoint_number" ,
  "frame.len" , "frame.cap_len" , "usb.urb_len" , "usb.data_len" ,
  "urbset.dir", "urbdir", "usb.urb_status", "urbstat",
  "urbset.recpnt", "urbrec", "urb.data"
  );
  # initialize master hash/dict from fields
  # (make init value distinct like -1111? better empty string)
  %hMentry = map { $_ => "" } @CF;
  ' -ne '
  %hentry = %hMentry; # copy dict
  if ( $. == 1 ) {  # if on first line
    #print($_);      # output header line verbatim? nah, does not match anymore
    $csvobj->print(STDOUT, \@CF); print("\n");
  }
  # and for all other lines:
  if ( $. >= 100 ) { exit; }; # limit num rows processed
  if (length($_)<2) { next; }; # skip empty lines
  # split line - has fields and data
  @FD = split(/[:,]/, $_); # with mText::CSV, now this includes quotes??
  #trim(@FD); # remove whitespace from each element (chomp only trailing!) # needs extra modules; do instead trim+compact inner spaces:
  # use grep to only keep non-whitespace entries
  @FD = grep { /\S/ } map {join(" ", split(" "))} @FD;
  # assing array to hash: should work, since there are consecutive keys and vals in array
  #%hentry = @FD; # this overwrites the old keys, though
  for(my $i=0; $i<scalar(@FD)-1; $i+=2) {
    my $key = $FD[$i]; my $val = $FD[$i+1];
    $hentry{$key} = $val;
  };
  #print "$_: $hentry{$_}," for (keys %hentry); print "\n"; #print(join("--",@FD)."\n");
  #print "$_: $hentry{$_}, " for (@CF); print "\n"; # prints in order!
  # post parse - get rid of trailing zeroes
  $hentry{"dtime"} = sprintf("%.6f", $hentry{"dtime"});
  $hentry{"frame.epoch_time"} = sprintf("%.6f", $hentry{"frame.epoch_time"});
  # here post-parse; "usb.urb_type", "usbtyp", "usb.transfer_type", "usbttyp", "usb.data_flag", "usbdflg", "urbset.dir", "urbdir", "usb.urb_status", "urbstat", "urbset.recpnt", "urbrec",
  # (note the damn bash escaping for single quotes inside perl)
  ( $usbtyp, $usbtyplet ) = $hentry{"usb.urb_type"} =~ /(.+) \('"'"'(.)'"'"'\)/;
  $hentry{"usb.urb_type"} = $usbtyplet; $hentry{"usbtyp"} = $usbtyp;
  ( $usbttyp, $usbttyphex ) = $hentry{"usb.transfer_type"} =~ /(.+) \((.+)\)/;
  $hentry{"usb.transfer_type"} = $usbttyphex; $hentry{"usbttyp"} = $usbttyp;
  ( $usbdflg, $usbdflglet ) = $hentry{"usb.data_flag"} =~ /(.+) \('"'"'*(.)'"'"'*\)/;
  $hentry{"usb.data_flag"} = $usbdflglet; $hentry{"usbdflg"} = $usbdflg;
  ( $urbdirlet, $urbdir ) = $hentry{"urbset.dir"} =~ /(\d) (.*)/;
  $hentry{"urbset.dir"} = $urbdirlet; $hentry{"urbdir"} = $urbdir;
  ( $urbstat, $urbstatcode ) = $hentry{"usb.urb_status"} =~ /(.+) \(([-\d]+)\)/;
  $hentry{"usb.urb_status"} = $urbstatcode; $hentry{"urbstat"} = $urbstat;
  ( $urbrec, $urbreccode ) = $hentry{"urbset.recpnt"} =~ /(.+) \((.+)\)/;
  $hentry{"urbset.recpnt"} = $urbreccode; $hentry{"urbrec"} = $urbrec;
  # post-parse - endpoint number address; src dest
  #$epnum=$F[7]; # here $hentry{"usb.endpoint_number"} 0x80; 0x81, 0x01, 0x02 - needs decoding
  $epnumd=hex($hentry{"usb.endpoint_number"}); # convert to int
  $epnumb=sprintf("%08b", $epnumd); # convert to binary
  #$epnumb7=substr($epnumb,0,1); $epnumb0=substr($epnumb,7,1); # extract ms and ls bits
  $epnumbA = substr($epnumb,4,4);
  $epnumA = sprintf("%d", oct("0b".$epnumbA)); #oct ok for conv. binary string
  $wshaddr=sprintf("%s.%s", $hentry{"usb.device_address"}, $epnumA); #wireshark address (source, dest)
  # if "URB_SUBMIT ("S")", there is no source address
  $srcaddr=""; $dstaddr="";
  if ($hentry{"usb.urb_type"} eq "S") {
    $srcaddr="host"; $dstaddr = $wshaddr;
  } else {
    $srcaddr=$wshaddr; $dstaddr = "host";
  }
  $hentry{"src"} = $srcaddr; $hentry{"dst"} = $dstaddr;
  #
  # finally, print as .csv
  @tout = map { $hentry{$_} } @CF; # ok, vals extracted in order
  #print Dumper(\@tout);
  $csvobj->print(STDOUT, \@tout); print("\n");
  ' | #
  perl  -MText::CSV -e ' # third perl: read line by line; calc. rel. time for the snippet that we get; hold onto lines until respid can be determined, and then output only determined lines....
  $csvobj = Text::CSV->new({quote_char=>""}); #, always_quote=>1}) ;
  #$tsstart=-1.0; # overrides value each loop! keeps it if instantiated via if(!defined()) (below)! same for @linebuffer; but can be done here!
  if (!defined(@linebuffer)) { @linebuffer=(); };
  # chosen fields (w/ order) - added rtime:
  @CF = ( "frame.number", "rtime", "dtime", "frame.epoch_time", "src", "dst",
  "usb.urb_type", "usbtyp", "reqid", "respid", "usb.data_flag", "usbdflg",
  "usb.transfer_type", "usbttyp", "usb.bus_id", "usb.device_address", "usb.endpoint_number" ,
  "frame.len" , "frame.cap_len" , "usb.urb_len" , "usb.data_len" ,
  "urbset.dir", "urbdir", "usb.urb_status", "urbstat",
  "urbset.recpnt", "urbrec", "urb.data"
  );
  ' -ne '
  if ( $. == 1 ) {  # if on first line
    #print($_);      # output header line verbatim? nah, does not match anymore
    $csvobj->print(STDOUT, \@CF); print("\n");
  } else {   # for all other lines:
    #if (!defined(@linebuffer)) { @linebuffer=(); }
    chomp($_);
    #print("$. -- $_\n");
    $status  = $csvobj->parse($_);           # parse a CSV string into fields
    my @columns = $csvobj->fields();         # get the parsed fields (must be my to push separate addresses into linebuffer)
    #if ( $. == 2 ) {  # if on second line (first data), remember tsstart
    if (!defined($tsstart) ) {  #
      $tsstart=$columns[1] + 0.0 ;
    };
    $dtime=$columns[1]; $rtime=sprintf("%.6f", $dtime-$tsstart); # calc rtime
    splice(@columns, 1, 0, $rtime); #insert into array 1 places after index 0
    # append/put into linebuffer
    push (@linebuffer, \@columns); # push @columns will extend! add refs!
    #print(@linebuffer, "\n");
    #print(scalar(@linebuffer), "::", join("--",@columns)."\n");
    # k, now traverse through @linebuffer, and whatever is complete, output it:
    # we start from the earliest first;
    my $reqind = 0; ++$reqind until $CF[$reqind] eq "reqid";
    my $respind = 0; ++$respind until $CF[$respind] eq "respid";
    my @indxstogo = ();
    my $lbufFnumStart = @{$linebuffer[0]}[0];
    my $lbufFnumEnd = $linebuffer[$#linebuffer][0];
    foreach $lind (0..$#linebuffer) { # foreach $line (@linebuffer) {
      my $line = $linebuffer[$lind];
      my @tmpa = @{$line};
      $creqid = $tmpa[$reqind]; $crespid = $tmpa[$respind]; # current reqid,respid
      my $cFnum = $tmpa[0];
      # reqid means "request in" == it is a response already, so it can go - but only if its reqid number is smaller than the smallest frame number in the buffer (else it has to wait)
      #print("> lind $lind, cfn $cFnum, lbfns $lbufFnumStart, lbfne $lbufFnumEnd creqid >$creqid< crespid >$crespid< \n"); #@tmpa
      if (not($creqid eq "")) {
        if ($lbufFnumStart > $creqid) {
          push (@indxstogo, $lind);
        } elsif ($creqid <=$lbufFnumEnd) {
          my $foundind = -1;
          foreach $tlind (0..$#linebuffer) {
            if ($tlind == $lind) { next; }; # skip same line
            $tline = $linebuffer[$tlind];
            @tmpt = @{$tline};
            $tlFnum = $tmpt[0];
            #print(">> lind $lind tlind $tlind tlfn $tlFnum cfn $cFnum crq $creqid \n");
            if ($tlFnum==$creqid) {
              $foundind = $tlind; last;
            }
          }
          # if found, then add $creqid? as "response in" at the found
          if ($foundind > -1) {
            $fline = $linebuffer[$foundind];
            #@tmpf = @{$fline}; $tmpf[$respind] = $cFnum;
            @$fline[$respind] = $cFnum;
            #print(">>> fi $foundind crq $creqid cfn $cFnum ", join(";",@{$fline}), "\n");
            # must add here the target, maybe it has already passed from this loop
            if (not( $foundind ~~ @indxstogo )) {
              push (@indxstogo, $foundind);
            }
            # but also this has to go, as it has creq, and it may not have
            # been handled by first condition yet; and "this" is lind:
            if (not( $lind ~~ @indxstogo )) {
              push (@indxstogo, $lind);
            }
          }
        }
      } # if not($creqid...
      # if the response is known, then definitely is index to go:
      if (not($respid eq "")) {
        # smart match ~~ - check if element is already in array:
        if (not( $lind ~~ @indxstogo )) {
          push (@indxstogo, $lind);
        }
      }
    };
    # togo: without sort, at end:
    # 0--1--3--2--5--4--6--7--9--8--11--10--12--13--15--14--17--16--18--19--21--20--23
    #print("togo: ", join("--",@indxstogo), " -> ");
    # sort numerically ascending
    @indxstogo = sort {$a <=> $b} @indxstogo;
    #print("idxtogo |", join("--",@indxstogo), "|\n");
    # this algo seems now to output properly sorted;
    # but it is possible it will not print all of the incoming packets!
    # (however, a lot of times, most of them pass); e.g. for this case
    #  frame.number >= 1789 && <= 1812, it output 1789-1812;
    # if we could find a signal to detect end of stdin, it may
    # be possible to dump them at end (but is not a pressing issue for now...)
    my $lastindtg = -1;
    my $realidlt = -1; my $realitglast=-1;
    foreach $indtg (0..$#indxstogo) {
      # first check if we are in a consecutive seq: delta must be <= 1
      my $indextopop = $indxstogo[$indtg];
      my $inddelt = $indextopop - $lastindtg;
      # for a stronger condition, we need to check real delta (of frame num) too..
      $tmpl = $linebuffer[$indextopop];
      my $realitgnow = @{$tmpl}[0]; # just this messes the algo? not if $tmpl is used
      if ($realitglast>-1) {
        #$realitglast = $linebuffer[$lastindtg][0];
        $realidlt = $realitgnow - $realitglast;
      }
      #print("> indtg $indtg idxtopop $indextopop lastindtg $lastindtg inddelt $inddelt rnow $realitgnow rlast $realitglast realidlt $realidlt\n");
      $cond =  ( ($inddelt <= 1) && ($realidlt <= 1) );  # ($lastindtg == -1) || .. ($lastindtg > -1) &&
      if ($cond) {
        # use `shift` to `pop`/remove and return the first element in Perl array?
        # nope, it will mess up removal process! we have $indtg; and indxstogo
        # will be rebuilt anew next run...
        #$firstindexpopped = shift @indxstogo;
        #my $indextopop = $indxstogo[$indtg];
        # now remove the corresponding index in @linebuffer - splice
        $linetogo = splice(@linebuffer, $indextopop, 1); # ARRAY, OFFSET, LENGTH
        $lastindtg = $indextopop;
        $realitglast = $realitgnow;
        my @alinetogo = @{$linetogo}; # csvobj needs array REF; so no need to "array"-ize
        #print(">> lintogo ", "$linetogo ", join("--",@{$linetogo}),"\n");
        # finally print; but getting: Expected fields to be an array ref at
        $csvobj->print(STDOUT, $linetogo); print("\n");
      }
    } # end foreach
    # at this point, re-sort also the linebuffer, since items are now removed
    # orig: >; trying <=> ?? numeric ascending?
    @linebuffer = sort { $a->[0] <=> $b->[0] } @linebuffer;
    #print("\n");
  }
  ' #| #
  #~ less
  #~ python csv-pygtk.py -


<<"OLDER_CODE"

tshark -r "$1" \
  -E separator=, -E header=y, -E quote=n \
  -T fields \
  $(makeargs <<EOF
  -e frame.number                       # 0
  -e frame.time                         # 1[ and 2]
  -e frame.epoch_time                   # 3
  -e usb.time                           # 4
  -e usb.bus_id                         # 5
  -e usb.device_address                 # 6
  -e usb.endpoint_number                # 7 # actually, endpoint adress!
  -e usb.urb_type                       # 8
  -e usb.urb_len                        # 9
  -e usb.data_len                       # 10
  -e usb.src.endpoint                   # 11 # empty, wireshark 1.4.6
  -e usb.dst.endpoint                   # 12 # empty, wireshark 1.4.6
  -e usb.bEndpointAddress.number        # 13 # empty, wireshark 1.4.6
  -e usb.bEndpointAddress.direction     # 14 # empty, wireshark 1.4.6
  -e usb.request_in                     # 15
  -e usb.response_in                    # 16
  -e frame.len                          # 17; this is paclen in wireshark
  -e usb.bString                        # 18 ; empty
  -e frame.protocols                    # 19 ; 'usb', or 'usb:ppp'
  -e usb.data_flag                      # 20 ; <, >, or 'present (0)'
  -e usb.transfer_type                  # 21 ; 0x03 is BULK OUT, etc
  -e usb.urb_id                         # 22 ;
  -e usb.urb_status                     # 23 ; -115: -EINPROGRESS; 0 Success
  #-e usb.capdata                       # 24 ; length 0
  -e usb.data                           # 24 ; length 0
EOF
) 2>&1 | #
  # use Text::CSV here, easier
  perl -mText::CSV -e '
  $csvobj = Text::CSV->new({quote_char=>""}); #, always_quote=>1}) ;
  # chosen fields:
  @CF = ( "frameno", "ts", "tso", "wshaddr", "urbtyp", "urblen", "urbid", "urbsts");
  ' -nE '
  if ( $. == 1 ) {  # if on first line
    #print($_);      # output header line verbatim? nah, does not match anymore
    $csvobj->print(STDOUT, \@CF); print("\n");
  } else {        # for all other lines:
    if ( $. >= 100 ) { exit; }; # limit
    chomp($_);
    @F = split(/,/, $_); # with mText::CSV, now this includes quotes?? nope, that was -E quote=d
    #@F = $csvobj->getline( STDIN ); # nope
    #$status  = $csvobj->parse($_); @F=$csvobj->fields();
    @DT = split(/:/, $F[2]);
    $tso=$DT[2];
    if(!defined($starttso)) {$starttso = $tso;};
    $ts = $tso-$starttso;
    #printf("%s ; %s ; %s ; %s ; %.6f ; \n", $F[0], $F[1], $F[2], $F[3], $ts);
    $usbdtime = ($F[4]>0) ? $F[4] : 0.0 ;
    $frameno = $F[0]; $busid = $F[5]; $devaddr=$F[6];
    $epnum=$F[7]; # 0x80; 0x81, 0x01, 0x02 - needs decoding
    $epnumd=hex($epnum); # convert to int
    $epnumb=sprintf("%08b", $epnumd); # convert to binary
    $epnumb7=substr($epnumb,0,1); $epnumb0=substr($epnumb,7,1); # extract ms and ls bits
    # http://www.beyondlogic.org/usbnutshell/usb5.shtml
    # bEndpointAddress: Bits 0..3b Endpoint Number; Bits 4..6b Reserved. Set to Zero Bits 7 Direction 0 = Out, 1 = In (Ignored for Control Endpoints)
    $epnumbA = substr($epnumb,4,4);
    #$epnumA = sprintf("%d", ""0b" . $epnumbA"); # works from terminal, but not here?
    $epnumA = sprintf("%d", oct("0b".$epnumbA)); #oct ok for conv. binary string
    $urbtyp = substr($F[8],0,1); # S\x10, C\x10 - only first char here
    $urblen = $F[9]; $datalen=$F[10];
    $srcep=$F[11]; $dstep=$F[12]; $beanum=$F[13]; $beadir=$F[14];
    $reqin=$F[15]; $respin=$F[16]; $frlen=$F[17]; $ubstr=$F[18]; $frprot=$F[19];
    $udflag=$F[20]; # can be "Data: not present (<) or (>)" in -V, present is 0
    $ttype=$F[21]; # "0x02" etc
    $urbid=$F[22]; # "0x00000000f3a9bc80"
    $urbsts=$F[23]; # "-115"
    #$capdat=$F[24]; # 0 length (is leftover capture)
    $appdat=$F[24];  # 0 length (application data)
    $wshaddr=sprintf("%s.%s", $devaddr, $epnumA); #wireshark address (source, dest)
    #~ printf("%d ; %.6f ; %.6f ; %s ; %s.%s (%s) %s-%s ;  %s ; %s ; %s ;  %s ; %s ; %s ; %s ;  %s ; %s ; %s ; %s ; %s ;  %s ; %s ; %s ; %s ;  %s ; %s\n",
      #~ $frameno, $ts, $tso, $busid,
      #~ $devaddr, $epnumA, $epnum, $epnumb7, $epnumb0, $urbtyp, $urblen, $datalen,
      #~ $srcep, $dstep, $beanum, $beadir, # these are empty!
      #~ $reqin, $respin, $frlen, $ubstr, $frprot,
      #~ $udflag, $ttype, $urbid, $urbsts,
      #~ length($appdat), $CF[0], #$usbdtime,
    #~ );
    @ta = (); foreach $ifd (@CF) {push (@ta, ${$ifd});}; #print($ifd."-${$ifd}\n");
    #print("$_\n");#print(join("--",@F)."\n");
    $csvobj->print(STDOUT, \@ta); print("\n");
  }
  ' | #
  #~ less
  python csv-pygtk.py -
OLDER_CODE


<<"MULTILINE_COMMENT"

# note, in wireshark there is:
# "Time delta from previous captured/displayed frame"
# but for `usb.time` from tshark -G:
# "F	Time from request	usb.time	FT_RELATIVE_TIME	usb	Time between Request and Response for USB cmds"

$ bash unpack-tshark.sh /media/disk/work/AudioFPGA_git/driver_pc/snd_ftdi_audard-an16s/captures03/outshark_arecplay_48_audacok.pcap

frame.number,frame.time,frame.epoch_time,usb.time,usb.bus_id,usb.device_address,usb.endpoint_number,usb.urb_type,usb.urb_len,usb.data_len,usb.src.endpoint,usb.dst.endpoint
0,1     ,2                       ,,4,5,6,7   ,8   ,9 ,10,11,12
1,May 31, 2013 22:25:09.842968000,,,2,2,0x80,S\x10,40,0,,,,,,
2,May 31, 2013 22:25:09.845600000,,0.002632000,2,2,0x80,C\x10,18,18,,,,,1,
3,May 31, 2013 22:25:09.846109000,,,2,1,0x80,S\x10,40,0,,,,,,
4,May 31, 2013 22:25:09.846117000,,0.000008000,2,1,0x80,C\x10,18,18,,,,,3,
5,May 31, 2013 22:25:12.020836000,,,2,2,0x00,S\x10,0,0,,,,,,
...
4676,May 31, 2013 22:25:20.030682000,,,2,2,0x81,S\x10
4677,May 31, 2013 22:25:20.030697000,,0.003461000,2,2,0x02,C\x10
4678,May 31, 2013 22:25:20.031254000,,,2,2,0x02,S\x10
4679,May 31, 2013 22:25:20.031601000,,0.000919000,2,2,0x81,C\x10
4680,May 31, 2013 22:25:20.031613000,,,2,2,0x81,S\x10
4681,May 31, 2013 22:25:20.032605000,,0.000992000,2,2,0x81,C\x10
4682,May 31, 2013 22:25:20.032643000,,,2,2,0x81,S\x10
4683,May 31, 2013 22:25:20.033603000,,0.000960000,2,2,0x81,C\x10
4684,May 31, 2013 22:25:20.033634000,,,2,2,0x81,S\x10
4685,May 31, 2013 22:25:20.034604000,,0.000970000,2,2,0x81,C\x10

MULTILINE_COMMENT




<<"MULTILINE_COMMENT"

frame.len, etc, on:
http://www.wireshark.org/docs/dfref/f/frame.html
http://www.wireshark.org/docs/dfref/u/usb.html

[http://www.wireshark.org/lists/wireshark-users/201004/msg00086.html Wireshark · Wireshark-users: Re: [Wireshark-users] USB filters and format ?]

> And those work.. However, if I want to filter by frame number, I have to
> use frame.number, which is in a different "class":

Yes, just as, for example, if you want to filter by IPv4 address, you'd use ip.src, ip.dst, or ip.addr, whereas if you want to filter by TCP port number, you'd use tcp.srcport, tcp.dstport, or tcp.port, which are in a different "class" from the ip.* field names.

> Now, in Wireshark GUI there are columns: "No.", "Time", "Source",
> "Destination", "Protocol" and "Info" ... For all others but "No." (which
> is, apparently, frame.number),

Yes, it is the frame number - for *all* protocols.

> I have no idea what the corresponding filters are for a USB packet!

"time" is the time stamp, which is "frame.time" or, if you want the time as "seconds since January 1, 1970, 00:00:00 UTC", "frame.epoch_time", at least in newer versions of Wireshark.  That's the case for *all* protocols.

> For example, "Source" for network traffic would be ip.src; but for usb,
> neither usb.src.endpoint nor usb.dst.endpoint show anything. And I am in
> particular interested in filtering by source and destination...

Unfortunately, there are no fields corresponding directly to source and destination.  There are fields "usb.endpoint_number", "usb.device_address", and "usb.bus_id".

For packets with an event type ("usb.urb_type") of "URB_SUBMIT ('S')", there is no source address, and the destination address is made from the device address and endpoint number; for all other packets, there is no destination address, and the source address is made from the device address and endpoint number.  There are also source and destination *port* columns that you can display; for URB_SUBMIT packets, there is no source port and the destination port is the endpoint number, and, for all other packets, there is no destination port and the source port is the endpoint number.  (No, I don't know why the address includes the endpoint, if the endpoint is also treated as a port.)


[http://www.wireshark.org/lists/wireshark-users/200806/msg00004.html Wireshark · Wireshark-users: Re: [Wireshark-users] Help needed controlling tshark output format]

1. I want to get data out in a delimited format to load into a
spreadsheet/database for custom reporting and analysis.
2. I would like to be able to get the data value and the decoded value.
eg
tcp.port value is 80, decoded value is http
3. I would like to see if the packets are marked by a specified analysis
flag, eg tcp.analysis.retransmission

>From what I can see there are 2 main formats
Example A. tshark.exe" -o column.format:""No.", "%m", "Time", "%t",
"Source", "%s", "Destination", "%d", "srcport", "%uS", "dstport", "%uD",
"len", "%L", "Protocol", "%p", "Info", "%i", "expert","%a"" -r
e:\temp\wstest\test.enc > e:\temp\wstest\testout.txt
using % values

Example B. "C:\Program Files\Wireshark\tshark.exe" -T text -E
separator=; -E
header=y -Tfields -e frame.number -e frame.time -e frame.time_delta -e
frame.pkt_len -e frame.protocols -e eth.src -e ip.src -e tcp.srcport -e
eth.dst -e ip.dst -e tcp.dstport -e tcp.seq -e tcp.nxtseq -e tcp.ack -e
tcp.window_size -e tcp.flags -e tcp.flags.push -e tcp.flags.ack -e
tcp.flags.syn -e tcp.flags.reset -r e:\temp\wstest\test.enc >
e:\temp\wstest\testout.txt

>From Example A
A1 bad: I understand from other threads that it is not possible to have
specified a delimiter using this format
A2 bad: I understand with this format it is possible to to add fields as
per display filter fields. The example I found is "Len", "%Cus:tcp.len".
unfortunatly I have not been able to get it work on this or any other
fields using dos window or cywin.
A3 good: decoded value is available for many fields

>From Example B
B1 good: output can have all fields as per normal display filters
B2 good: I can have a delimiter
B3 bad: no flag is set for tcp.analysis.retransmission field even whenyou
apply the tcp.analysis.retransmission filter to only get retransmitted
packets. If this flag had been set this way then I would OR this filter
with frame.number>0 to get all packets and have the flag set on the relevant frams.
B4 bad: I cannot find how to get the decodes value of the field.

for column.format: fields:
tshark -r $TFILE -o column.format:'"No.", "%m", "Time", "%t", "s", "%i", "As", "%p", "bt", "%B", "at", "%E"' | head -10
https://code.wireshark.org/review/gitweb?p=wireshark.git;a=blob;f=epan/column.c;h=5d3263d6ce0a814ae2480741e7233130cf0694e6;hb=HEAD

MULTILINE_COMMENT
