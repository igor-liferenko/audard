CONFIG_MODULE_FORCE_UNLOAD=y
# for oprofile:
DEBUG_INFO=y
# EXTRA_CFLAGS=-g -O0
EXTRA_CFLAGS=-g -O0

# output compile command line:
# make KBUILD_VERBOSE=1

obj-m += callmodule.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
