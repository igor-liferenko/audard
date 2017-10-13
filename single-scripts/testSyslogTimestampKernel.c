// gcc testSyslogTimestampKernel.c -o testSyslogTimestampKernel -lrt

// in /usr/include/:
#include <syslog.h>
#include <sys/time.h> // struct timeval
#include <time.h>     // clock_gettime
#include <stdio.h>    // FILE

#ifndef NULL
#define NULL (void *)0
#endif

int main() {
  struct timeval tv_stamp;  // has tv_usec (micro)
  struct timespec ts_stamp; // has tv_nsec (nano)
  FILE *fp;
  float upts1, upts2;

  openlog("MyProgram", LOG_CONS | LOG_PID | LOG_NDELAY | LOG_PERROR, LOG_LOCAL0);

  gettimeofday(&tv_stamp, NULL);
  syslog(LOG_INFO, "[%ld.%ld]  <--- gettimeofday", tv_stamp.tv_sec, tv_stamp.tv_usec);

  // CLOCK_REALTIME - same as gettimeofday (1368301662.773086 sec)
  // CLOCK_MONOTONIC - closest to printk timestamp; but about half from /proc/uptime? (18898.438720 vs. 29729.77), possibly because of clock skew on suspend (see correlating-var-log-timestamps)
  // CLOCK_PROCESS_CPUTIME_ID - starts from 0 - for this process only

  clock_gettime(CLOCK_REALTIME, &ts_stamp);
  syslog(LOG_INFO, "[%5lu.%06lu] <-- clock_gettime[CLOCK_REALTIME]", ts_stamp.tv_sec, ts_stamp.tv_nsec / 1000);

  clock_gettime(CLOCK_MONOTONIC, &ts_stamp);
  syslog(LOG_INFO, "[%5lu.%06lu] <-- clock_gettime[CLOCK_MONOTONIC]", ts_stamp.tv_sec, ts_stamp.tv_nsec / 1000);

  clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts_stamp);
  syslog(LOG_INFO, "[%5lu.%06lu] <-- clock_gettime[CLOCK_PROCESS_CPUTIME_ID]", ts_stamp.tv_sec, ts_stamp.tv_nsec / 1000);

  // # cat /proc/uptime
  // Wiki: "The first number is the total number of seconds the system has been up. The second number is how much of that time the machine has spent idle, in seconds"

  if( (fp = fopen("/proc/uptime", "r")) == NULL) {
    printf("Cannot open file\n");
    return(1);
  }
  while(fscanf(fp,"%f %f",&upts1,&upts2) == 2) {
    syslog(LOG_INFO, "[%f] <-- /proc/uptime[0] ; [%f] <-- /proc/uptime[1] ; ", upts1, upts2);
  }

  closelog();
}


/*
// To simulate actual printk timestamps:
// the following compiles from userspace - but cannot be linked:

#include <stdint.h>         // uint32_t
#include <linux/sched.h>    // cpu_clock
// #include <linux/kernel.h> // UINT_MAX; cannot
// in /usr/src/linux-headers-2.6.38-16/include/:
#include <asm-generic/bitsperlong.h>    // BITS_PER_LONG
#define BITS_PER_LONG __BITS_PER_LONG
#include <asm-generic/div64.h>          // do_div

#define UINT_MAX        (~0U)
static volatile unsigned int printk_cpu = UINT_MAX;

unsigned long long t;
unsigned long nanosec_rem;

// kernel/printk.c?v=2.6.39:
t = cpu_clock(printk_cpu);
nanosec_rem = do_div(t, 1000000000L);
tlen = sprintf(tbuf, "[%5lu.%06lu] ", (unsigned long) t, nanosec_rem / 1000);

// to check: tail -f /var/log/syslog in one terminal
// plug out, then in USB mouse - then run this program;
// results:

* May 12 05:16:50 mypc kernel: [21244.100111] usb 3-1: new full speed USB device using uhci_hcd and address 3
* May 12 05:16:50 mypc kernel: [21244.299464] generic-usb 0003:046D:C526.0005: input,hiddev0,hidraw1: USB HID v1.11 Device [Logitech USB Receiver] on usb-0000:00:1d.1-1/input1
  May 12 05:16:55 mypc MyProgram[13539]: [1368328615.23872]  <--- gettimeofday
  May 12 05:16:55 mypc MyProgram[13539]: [1368328615.024235] <-- clock_gettime[CLOCK_REALTIME]
* May 12 05:16:55 mypc MyProgram[13539]: [21248.649768] <-- clock_gettime[CLOCK_MONOTONIC]
  May 12 05:16:55 mypc MyProgram[13539]: [    0.002232] <-- clock_gettime[CLOCK_PROCESS_CPUTIME_ID]
  May 12 05:16:55 mypc MyProgram[13539]: [56751.640625] <-- /proc/uptime[0] ; [37399.058594] <-- /proc/uptime[1] ;

// .. that is; clock_gettime[CLOCK_MONOTONIC] is closest to printk clock
// caveat: clock skew on suspend: http://unix.stackexchange.com/questions/5804/correlating-var-log-timestamps

*/



