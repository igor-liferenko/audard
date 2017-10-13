obj-m += testjiffy.o
obj-m += testjiffy_hr.o

# no need for these, "Circular dependency dropped."
# only needed if .c filenames differ
#testjiffy-objs := testjiffy.o
#testjiffy_hr-objs := testjiffy_hr.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
