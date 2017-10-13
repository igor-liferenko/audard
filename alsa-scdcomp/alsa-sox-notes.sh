################################################################################
# alsa-sox-notes.sh                                                            #
# Part of the {alsa-}scdcomp{-alsa} collection                                 #
#                                                                              #
# Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 #
# This program is free software, released under the GNU General Public License.#
# NO WARRANTY; for license information see the file LICENSE                    #
################################################################################

#~ : || {}

<<"COMMENT"
Note about `play` from `sox`:
possible it cannot figure out the driver by itself, if pulseaudio is not
running:

[https://bugs.archlinux.org/task/29524 FS#29524 : [sox] play does not work anymore.]
[http://sourceforge.net/p/sox/mailman/message/29024431/ [SoX-devel] Test whether PulseAudio is actually present (Debian bug #664301)]

# nowork:
$ play /path/to/test_s16.wav
ALSA lib pcm_hw.c:1401:(_snd_pcm_hw_open) Invalid value for card
play FAIL formats: can't open output file `default': snd_pcm_open error: No such file or directory

# work:
$ AUDIODEV=hw:0,0 play /path/to/test_s16.wav
/path/to/test_s16.wav:
 File Size: 235k      Bit Rate: 706k
  Encoding: Signed PCM
  Channels: 1 @ 16-bit
...

# work:
$ AUDIODRIVER=alsa AUDIODEV=hw:0,0 play /path/to/test_s16.wav
/path/to/test_s16.wav:
 File Size: 235k      Bit Rate: 706k
...

similar also for alsa's aplay:

$ aplay -v -D default
ALSA lib pcm_hw.c:1401:(_snd_pcm_hw_open) Invalid value for card
aplay: main:660: audio open error: No such file or directory

$ aplay -v -D hw:0,0
^CAborted by signal Interrupt...


Note it may also have problems with different sound formats, even if:
"When playing a file with a sample rate that is not supported by the audio  output
device,  SoX  will  automatically invoke the rate effect to perform the necessary
sample rate conversion."

$ AUDIODEV=hw:0,0 play /path/to/test_u8.wav
play WARN alsa: can't encode 8-bit Unsigned Integer PCM
play FAIL formats: can't open output file `hw:0,0': snd_pcm_hw_params_set_format error: Invalid argument

This may depend on the soundcard capabilities:
[http://comments.gmane.org/gmane.comp.audio.sox/4202 sox-users: WARN alsa: can't encode 24-bit Signed Integer PCM (Part 2)]

$ aplay -v -D hw:0,0 /path/to/test_u8.wav
Playing WAVE '/path/to/test_u8.wav' : Unsigned 8 bit, Rate 44100 Hz, Mono
aplay: set_params:1059: Sample format non available
Available formats:
- S16_LE
- S32_LE

The plughw device would help for such conversions:

# works:
$ aplay -v -D plughw:0,0 /path/to/test_u8.wav

# works (but hard to Ctrl-C):
$ AUDIODEV=plughw:0,0 play -V /path/to/test_u8.wav

# previous is equivalent to:
$ sox -V /path/to/test_u8.wav -t alsa plughw:0,0


# now this works too:
$ AUDIODEV=plughw:0,0 play -n synth 0.5 sine 200-500 synth 0.5 sine fmod 700-100
$ sox -n -t alsa plughw:0,0 synth 0.5 sine 200-500 synth 0.5 sine fmod 700-100


also:
[http://sox.10957.n7.nabble.com/Multiple-sound-cards-on-windows-td3685.html SoX - Multiple sound cards on windows]

COMMENT

