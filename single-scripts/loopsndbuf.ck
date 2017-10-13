

// copyleft sdaau, Apr 2012; based on
// http://chuck.cs.princeton.edu/doc/examples/basic/sndbuf.ck
// http://chuck.cs.princeton.edu/doc/examples/basic/valueat.ck

// sound file
// initialize empty string variable for filename
"" => string filename;

// set a default filename to be loaded
"/path/to/freesound.nat/100391__dobroide__20100627-creek.wav" => filename;

// if arguments are passed to the script,
// use the first argument as filename instead
if( me.args() ) me.arg(0) => filename;

// initialize a float variable for volume
0.5 => float myvolume;

// if arguments are passed to the script,
// use the second argument as volume instead (parse float)
if( me.args() ) if (me.arg(1) != "") Std.atof(me.arg(1)) => myvolume;

// debug log: print out volume we parsed
<<< "myvolume: " + myvolume >>>;


// declare sndbuf variable - but don't patch it to dac as usual, as in (*c1)
SndBuf buf;

// load the file and set reproduction rate
filename => buf.read;
myvolume => buf.gain;
1.0 => buf.rate;


// time loop - for usual loop, see (*c1); but
// this time-loop should loop with sample accuracy the entire file
// but needs direct impulse generator - not SndBuf buf => dac;
// the patch (no `sndbuf => dac` involved)
Impulse i => dac;
while( true )
{
    // declare position index variable
    int pos;

    // repeat this many times (for all samples in buffer?)
    repeat( buf.samples() )
    {
        // set next sample
        buf.valueAt( pos ) => i.next;
        // increment index
        pos++;
        // advance time by one samp
        1::samp => now;
    }
}



/*

notes & comments:

(*c1)

//~ // the patch
//~ SndBuf buf => dac;
//~ // ...
//~ // time loop - the below simply loops first second ( 100 ms may even be silence and not heard )
//~ while( true )
//~ {
    //~ 0 => buf.pos; // reset buffer position...
    //~ Std.rand2f(.2,.9) => buf.gain;
    //~ Std.rand2f(.5,1.5) => buf.rate;
    //~ advance time for 1000 ms
    //~ 1000::ms => now;
//~ }


--------------------------

https://lists.cs.princeton.edu/pipermail/chuck-users/2008-February/002668.html
> There are three versions of ChucK for Linux for the three types of audio
> system. (OSS, ALSA, JACK). These are different executables. Could you verify
> which one you have? Typing "chuck --version" at your terminal should tell
> you this between brackets.


$ chuck --version
chuck version: 1.2.0.8 (dracula)
  exe target: linux (jack)
  http://chuck.cs.princeton.edu/

# so first:
jackd -r -dalsa -dhw:0 -r44100 -p1024 -n2

# then http://t-a-w.blogspot.com/2007/05/using-ddr-dance-mat-as-musical.html

chuck --srate44100 loopsndbuf.ck

no work? from above link "did you notice there is a chuck.alsa command"

chuck.alsa --probe  - a bit different
[chuck]: ------( chuck -- dac1 )---------------
[chuck]: device name = "hw:SB,0"
[chuck]: # output channels = 6

[chuck]: ------( chuck -- dac2 )---------------
[chuck]: device name = "hw:SB,1"
[chuck]: # output channels = 2

command for me is however ( and after that can leave out the srate and dac, and without verbose seems a bit more stable when mixing a lot as well... )
chuck.alsa --srate44100 --dac1 --verbose loopsndbuf.ck

also http://chuck.cs.princeton.edu/doc/examples/

unit conversion, string to float http://chuck.cs.princeton.edu/doc/program/stdlib.html

http://chuck.cs.princeton.edu/doc/language/spork.html#arguments
cmdline arguments with colon :
chuck.alsa --srate44100 --dac1 --verbose loopsndbuf.ck:~/Desktop/freesound.nat/15528__ch0cchi__domestic-cat-purr.wav // cannot do home ~, must full or rel path
chuck.alsa --dac1 --verbose loopsndbuf.ck:... or just
chuck.alsa loopsndbuf.ck:/path/to/freesound.nat/15528__ch0cchi__domestic-cat-purr.wav:1.0 loopsndbuf.ck:/path/to/freesound.nat/100391__dobroide__20100627-creek.wav:0.05 loopsndbuf.ck:/path/to/freesound.nat/23222__erdie__thunderstorm2.wav:0.4 loopsndbuf.ck:/path/to/freesound.nat/2519__rhumphries__rbh-rain-01.wav:0.4 loopsndbuf.ck:/path/to/freesound.nat/18766__reinsamba__chimney-fire.wav:0.4 loopsndbuf.ck:/path/to/freesound.nat/53380__eric5335__meadow-ambience.wav:0.4

however, note the above may take a bit of CPU horsepower!
and may react on GUI events!!
(however, it will do independent seamless loop of samples uneven in length!)

[https://lists.cs.princeton.edu/pipermail/chuck-users/2011-June/006220.html [chuck-users] ChucK and Pulseaudio (Ubuntu 10.04)]
http://disjunkt.com/jd/2010/en/multiseat-linux/multiseat-linux-system-wide-pulseaudio-for-routing-sounds-109/
http://0pointer.de/lennart/projects/padevchooser/
sudo apt-get install pavucontrol padevchooser
none of that works - chuck shows nowhere on those

only with qjackctrl - enough to start server norealtime (no neet for transport)
it automaticall figures from RtApiJack to system/playback_1/2
but doesn't interact with pulseaudio - http://jackaudio.org/pulseaudio_and_jack
says to use two soundcards? jack needs card - aloop-kernel.c?
there is portaudio driver for jack - but doesn't work, and not pulse
trying with pasuspender -- jack start? nope, nothing much...
in fact, after that, have to run pulseaudio --kill to have vlc working!
turn off realtime in qjackctrl also
note also: http://0pointer.de/blog/projects/when-pa-and-when-not.html
this, but for fedora: http://www.harald-hoyer.de/linux/pulseaudio-and-jackd
sudo apt-get install pulseaudio-module-jack

ok to make vlc and chuck go together with this:
qjackctrl: chuck: RtApiJack/outport 0:1 => system/playback_1:2
then play vlc - open pavucontrol, under Playback it will say

"audio stream on" "Simultaneous output"; change that to "Jack sink (PulseAudio JACK Sink)"
then go back to
qjackctrl: PulseAudio JACK Sink/front-left:right => system/playback_1:2
note: it goes *AGAIN* into system/playback_1:2!
this means effectively, that we route the pulseaudio through jack;
jack being the final arbiter of the "speakers" device
(and mixing the direct-to-jack with the pulseaudio-to-jack part)


--------------------------

$ usermod -a -G pulse-rt,jackuser "administrator"
usermod: group 'pulse-rt' does not exist
usermod: group 'jackuser' does not exist

after install pulseaudio-module-jack, then just
create~/jack.pa as per harald-hoyer.de  // module-stream-restore instead of module-volume-restore

#!/usr/bin/pulseaudio -nF
#
load-module module-jack-sink
load-module module-jack-source

load-module module-native-protocol-unix
#load-module module-volume-restore
load-module module-stream-restore
load-module module-default-device-restore
load-module module-rescue-streams
load-module module-suspend-on-idle
.ifexists module-gconf.so
.nofail
load-module module-gconf
.fail
.endif
.ifexists module-x11-publish.so
.nofail
load-module module-x11-publish
.fail
.endif

then just
pulseaudio --kill # instead of killall pulseaudio
# start jack from qjackctrl # instead of from cmdline; nonrt is ok, only server, no transport start
pulseaudio -nF ~/jack.pa # finally, a "Writable Clients/Input ports"
# called "PulseAudio JACK source" appears in JACK connections!
# and "PulseAudio JACK sink" in the "Readable Clients/Output Ports"
## so no need for this useradd to groups here..
but this overrides the card completely (in main volume, only jack in/out remain)



// this works fine // from http://chuck.cs.princeton.edu/doc/learn/tutorial.html

  // impulse to filter to dac
      Impulse i => BiQuad f => dac;
      // set the filter's pole radius
      .99 => f.prad;
      // set equal gain zero's
      1 => f.eqzs;
      // initialize float variable
      0.0 => float v;

      // infinite time-loop
      while( true )
      {
          // set the current sample/impulse
          1.0 => i.next;
          // sweep the filter resonant frequency
          Std.fabs(Math.sin(v)) * 4000.0 => f.pfreq;
          // increment v
          v + .1 => v;
          // advance time
          100::ms => now;
      }

// http://chuck.cs.princeton.edu/doc/examples/basic/valueat.ck

// (see loopsndbuf.ck or otf_01.ck for non-insane usage of sndbuf)
SndBuf buf;
"../data/kick.wav" => buf.read;

// the patch (no sndbuf involved)
Impulse i => dac;

// infinite time-loop
while( true )
{
    // index
    int pos;

    // repeat this many times
    repeat( buf.samples() )
    {
        // set next sample
        buf.valueAt( pos ) => i.next;
        // increment index
        pos++;
        // advance time by one samp
        1::samp => now;
    }
}

*/


