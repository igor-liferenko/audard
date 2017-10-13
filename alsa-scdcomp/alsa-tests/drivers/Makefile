CONFIG_MODULE_FORCE_UNLOAD=y

# debug build:
# "CFLAGS was changed ... Fix it to use EXTRA_CFLAGS."
override EXTRA_CFLAGS+=-g -O0 -DTRACE_DEBUG

obj-m += snd-hda-intel.o
obj-m += snd-dummy.o
obj-m += snd-dummy-fix.o


snd-hda-intel-objs  := hda_intel_2.6.38.o
snd-dummy-objs  := dummy-2.6.32-patest.o
#snd-dummy-objs  := dummy-2.6.32-orig.o
snd-dummy-fix-objs  := dummy-2.6.32-patest-fix.o

all:
	@echo EXTRA_CFLAGS = $(EXTRA_CFLAGS)
	#make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
	make -C /media/disk/src/alsa-driver-1.0.24+dfsg/alsa-kernel M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
