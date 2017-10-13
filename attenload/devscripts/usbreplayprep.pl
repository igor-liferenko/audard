#!/usr/bin/perl
#
# usbreplayprep.pl
# original from http://pvrusb2.dax.nu/latest/usbreplayprep.pl
# modded sdaau 2012 - 2012.10.29:
# * process_urb -> process_urb_wr (write extracted, read not)
# *       added  + process_urb_rw (read extracted, write not)
# *       added  + process_urb_both (both read and write extracted)
# if no command line argument, do process_urb_wr (as usual)
# if cmdline arg is '-i', do process_urb_rw (inverted from usual)
# if cmdline arg is '-b', do process_urb_both

# note:
# to output ASCII from the hex:
# http://stackoverflow.com/a/13083384/277826
# perl usbreplayprep.pl -b <usbdat.log | perl -ne 'print "$_"; print pack("(H2)*", split(/ /, $_))."\n";

# This perl script reads an usbsnoop log file from STDIN and extracts
# commands and output data buffers, and prints them out like this:
#
# w1 39
#     00000000: 01 00 00 00 00 00 00 4c 00 00 00 00 00 00 4d 00
#     00000010: 00 00 00 00 00 4e 00 00 00 00 00 00 4f 00 00 00
#     00000020: 00 00 00 50 00 00 00 00 00 00 51 00 00 00 00 00
#     00000030: 00 52 00 00 00 00 00 00 53
#
# r81 40
#
# The "w1 39" section means write a buffer of size 0x39 to Endpoint 1,
# and "r81 40" means read 0x40 bytes from Endpoint 0x81.
#
# I have only tried this program with logs from usbsnoop-1.8 and
# Windows XP. It probably needs adjustments for other cases.


my ($line,$urb);

sub print_bufstuff {
    my $text = shift;
    if ($text =~ m/TransferBufferMDL.*\n((    [0-9a-f]{8}:( [0-9a-f]{2})+\n)+)  UrbLink/) {
        print $1;
    }
}

sub process_urb_wr {
    my $text = shift;
    if (defined($text)) {
        if ($text =~ m/URB (\d+) (going down|coming back)/) {
            my $urbno = $1;
            my $dirtext = $2;
            if ($text =~ m/PipeHandle.*endpoint 0x([0-9a-f]+)/) {
                my $endpoint = hex($1);
                if ($text =~ m/TransferBufferLength\s+=\s+([0-9a-f]+)/) {
                    my $bufsize = hex($1);
                    if ($dirtext eq 'going down') {
                        if ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_IN/) {
                            printf "r%x %x\n", $endpoint, $bufsize;
                        } elsif ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_OUT/) {
                            printf "w%x %x\n", $endpoint, $bufsize;
                            &print_bufstuff($text);
                        }
                    }
                }
            }
        }
    }
}

sub process_urb_rw {
    my $text = shift;
    if (defined($text)) {
        if ($text =~ m/URB (\d+) (going down|coming back)/) {
            my $urbno = $1;
            my $dirtext = $2;
            if ($text =~ m/PipeHandle.*endpoint 0x([0-9a-f]+)/) {
                my $endpoint = hex($1);
                if ($text =~ m/TransferBufferLength\s+=\s+([0-9a-f]+)/) {
                    my $bufsize = hex($1);
                    if ($dirtext eq 'coming back') {
                        if ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_IN/) {
                            printf "r%x %x\n", $endpoint, $bufsize;
                            &print_bufstuff($text);
                        } elsif ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_OUT/) {
                            printf "w%x %x\n", $endpoint, $bufsize;
                        }
                    }
                }
            }
        }
    }
}

sub process_urb_both {
    my $text = shift;
    if (defined($text)) {
        if ($text =~ m/URB (\d+) (going down|coming back)/) {
            my $urbno = $1;
            my $dirtext = $2;
            if ($text =~ m/PipeHandle.*endpoint 0x([0-9a-f]+)/) {
                my $endpoint = hex($1);
                if ($text =~ m/TransferBufferLength\s+=\s+([0-9a-f]+)/) {
                    my $bufsize = hex($1);
                    if ($dirtext eq 'going down') {
                        if ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_OUT/) {
                            printf "w%x %x\n", $endpoint, $bufsize;
                            &print_bufstuff($text);
                        }
                    } elsif ($dirtext eq 'coming back') {
                        if ($text =~ m/TransferFlags.*_TRANSFER_DIRECTION_IN/) {
                            printf "r%x %x\n", $endpoint, $bufsize;
                            &print_bufstuff($text);
                        }
                    }
                }
            }
        }
    }
}


## MAIN

if ($#ARGV < 0) { # no cmdline arguments

  while (defined($line = <STDIN>)) {
      if ($line =~ m/ URB (\d+) (going down|coming back)/) {
          &process_urb_wr($urb);
          $urb = $line;
      } elsif (defined($urb)) {
          $urb .= $line;
      }
  }

  &process_urb_wr($urb);

} else { # have cmdline arguments

  if ($ARGV[0] eq "-i") {
    while (defined($line = <STDIN>)) {
        if ($line =~ m/ URB (\d+) (going down|coming back)/) {
            &process_urb_rw($urb);
            $urb = $line;
        } elsif (defined($urb)) {
            $urb .= $line;
        }
    }

    &process_urb_rw($urb);
  } elsif ($ARGV[0] eq "-b") {
    while (defined($line = <STDIN>)) {
        if ($line =~ m/ URB (\d+) (going down|coming back)/) {
            &process_urb_both($urb);
            $urb = $line;
        } elsif (defined($urb)) {
            $urb .= $line;
        }
    }

    &process_urb_both($urb);
  }
}

