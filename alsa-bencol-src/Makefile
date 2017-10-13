CONFIG_MODULE_FORCE_UNLOAD=y

# debug build:
# "CFLAGS was changed ... Fix it to use EXTRA_CFLAGS."
EXTRA_CFLAGS=-g -O0

obj-m += snd-bencol.o

#~ note: 
#~ bencol-alsa-orig-comts doesn't produce a waveform
#~ bencol-alsa-orig-strip doesn't produce a waveform
#~ bencol-alsa-timer produces a waveform

#~ snd-bencol-objs  := bencol-alsa-orig-comts.o
#~ snd-bencol-objs  := bencol-alsa-orig-strip.o
snd-bencol-objs  := bencol-alsa-timer.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
