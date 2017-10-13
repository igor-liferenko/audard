// gcc testTimeSyslogBuffer.c -o testTimeSyslogBuffer -lrt

/* Circular buffer example, keeps one slot open */
/* code from: Example implementation, 'C' language, */
/* http://en.wikipedia.org/wiki/Circular_buffer#Always_Keep_One_Slot_Open */
/* sdaau, 2013: modified to log timestamped messages via syslog, */
/* as part of an example for `numStepCsvLogVis` application */

#include <stdio.h>
#include <malloc.h>

#include <stdarg.h>   // variable argument list
#include <syslog.h>   // syslog
#include <sys/time.h> // struct timeval
#include <time.h>     // clock_gettime
#include <string.h>   // strcat


/* Opaque buffer element type.  This would be defined by the application. */
typedef struct { int value; } ElemType;
/* Circular buffer object */
typedef struct {
  int         size;   /* maximum number of elements           */
  int         start;  /* index of oldest element              */
  int         end;    /* index at which to write new element  */
  ElemType   *elems;  /* vector of elements                   */
} CircularBuffer;
void cbInit(CircularBuffer *cb, int size) {
  cb->size  = size + 1; /* include empty elem */
  cb->start = 0;
  cb->end   = 0;
  cb->elems = (ElemType *)calloc(cb->size, sizeof(ElemType));
}
void cbFree(CircularBuffer *cb) {
  free(cb->elems); /* OK if null */
}
int cbIsFull(CircularBuffer *cb) {
  return (cb->end + 1) % cb->size == cb->start;
}
int cbIsEmpty(CircularBuffer *cb) {
  return cb->end == cb->start;
}
/* Write an element, overwriting oldest element if buffer is full. App can
   choose to avoid the overwrite by checking cbIsFull(). */
void cbWrite(CircularBuffer *cb, ElemType *elem) {
  cb->elems[cb->end] = *elem;
  cb->end = (cb->end + 1) % cb->size;
  if (cb->end == cb->start)
    cb->start = (cb->start + 1) % cb->size; /* full, overwrite */
}
/* Read oldest element. App must ensure !cbIsEmpty() first. */
void cbRead(CircularBuffer *cb, ElemType *elem) {
  *elem = cb->elems[cb->start];
  cb->start = (cb->start + 1) % cb->size;
}


/* We use this to log messages, instead of a bare printf. */
void logMsg(const char *informat, ...) {
  va_list arguments_list;
  struct timespec ts_stamp; // has tv_nsec (nano)
  char tsformat[] = "[%5lu.%06lu] %s";
  char informatted[1024];

  clock_gettime(CLOCK_MONOTONIC, &ts_stamp); // get timestamp

  va_start(arguments_list, informat);
  vsprintf(informatted, informat, arguments_list);
  va_end(arguments_list);

  syslog(LOG_INFO, tsformat, ts_stamp.tv_sec, ts_stamp.tv_nsec / 1000, informatted);
}


int main(int argc, char **argv) {
  CircularBuffer cb;
  ElemType elem = {0};
  int ecount;
  int delaycount;

  int testBufferSize = 10; /* arbitrary size */
  int tbshalf = testBufferSize / 2 ;
  cbInit(&cb, testBufferSize);

  openlog("testTimeSyslogBuffer", LOG_CONS | LOG_PID | LOG_NDELAY | LOG_PERROR, LOG_LOCAL0);

  /* Fill buffer with test elements 3 times */
  /* Use logMsg to log, instead of a bare printf (printk) */
  /* generate small for-loop delay, when cb.end is 4 */
  for (elem.value = 0; elem.value < 3 * testBufferSize; ++ elem.value) {
    if (cb.end == 4) {
      for(delaycount = 100000; delaycount > 0; delaycount--) {;}
    }
    logMsg("start %d-%d end: %d,%d size: %d ; value %d %d\n", cb.start, cb.start % tbshalf, cb.end, cb.end % tbshalf, cb.size, elem.value, elem.value % tbshalf);
    cbWrite(&cb, &elem);
  }

  closelog();

  /* Remove and print all elements */
  ecount = 0;
  while (!cbIsEmpty(&cb)) {
    cbRead(&cb, &elem);
    ecount++;
    printf("Output (elem %d): %d\n", ecount, elem.value);
  }

  cbFree(&cb);
  return 0;
}

