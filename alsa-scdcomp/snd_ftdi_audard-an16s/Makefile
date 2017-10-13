CONFIG_MODULE_FORCE_UNLOAD=y
# for oprofile:
DEBUG_INFO=y

# flags passed to gcc for compilation - -v:verbose, -H:show include files
# KBUILD_CFLAGS += -v
# for debugging make itself, use --debug=i in make command for targets

# debug build:
# "CFLAGS was changed ... Fix it to use EXTRA_CFLAGS."
#~ EXTRA_CFLAGS=-g -O0

obj-m += snd_ftdi_audard_16s.o
snd_ftdi_audard_16s-objs  := ftdi_sio-audard-16s.o

#~ obj-m += ftdi_profiler.o
#~ ftdi_profiler-objs  := ftdi_sio-audard-16s.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
#~ make -C /tmp/tmp-srcdir/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
#~ make -C /tmp/tmp-srcdir/build M=$(PWD) clean


# CFLAGS for visualisation: -da -dv -fdump-tree-original-raw -fdump-tree-all-all (but this fails)
#  with sudo make: make[2]: *** No rule to make target `kernel/bounds.c', needed by `kernel/bounds.s'.  Stop. same for -fdump-tree-vcg; nothing for -dv only
#  so actual kernel sources are needed for visualisation - not just headers

# For assembly inspection: "Use the -S (note: capital S) switch to GCC, and it will emit the assembly code to a file with a .s extension."
#  ... but, getting "file format not recognized; treating as linker script" ...
# so, use: objdump -S snd_ftdi_audard.ko | less

