/*
	writeread.c - based on writeread.cpp
	[SOLVED] Serial Programming, Write-Read Issue - http://www.linuxquestions.org/questions/programming-9/serial-programming-write-read-issue-822980/
	// sdaau 2010, GPL

	build with: gcc -o writeread_bonus -lpthread -lm -Wall -g writeread_bonus.c
*/

#include <stdio.h>
#include <string.h>
#include <stddef.h>

#include <stdlib.h>
#include <sys/time.h>

#include <pthread.h>

#include "serial.h"
#include <sys/ioctl.h>

#include <math.h> // floor


int serport_fd;

pthread_mutex_t    mutex = PTHREAD_MUTEX_INITIALIZER; //http://cs.pub.ro/~apc/2003/resources/pthreads/uguide/users-62.htm

// chunk for write; "global"
int chunksize = 4096;
int gaugeRate = 200000; // gauge the write rate to this value, in Bytes/sec
float gaugeBPeriod=0.0f; // 1.0/gaugeRate later

//POSIX Threads Programming - https://computing.llnl.gov/tutorials/pthreads/#PassingArguments
struct write_thread_data{
   int  fd;
   char* comm; //string to send
   int bytesToSend;
   int writtenBytes;
   int writeWrongs;
   int writeFails;
   int tiocout;
   int outBufSize;
   float wrBps;
};

void usage(char **argv)
{
	fprintf(stdout, "Usage:\n");
	fprintf(stdout, "%s port baudrate file/string [chunksize] [gaugerateBps] \n", argv[0]);
	fprintf(stdout, "Examples:\n");
	fprintf(stdout, "%s /dev/ttyUSB0 115200 /path/to/somefile.txt 4096 11520\n", argv[0]);
	fprintf(stdout, "%s /dev/ttyUSB0 115200 \"some text test\"\n", argv[0]);
}

// POSIX threads explained - http://www.ibm.com/developerworks/library/l-posix1.html
// instead of writeport
// How to implement sleep in threads - Linux Forums - http://www.linuxforums.org/forum/programming-scripting/73944-how-implement-sleep-threads.html#post779338
void *write_thread_function(void *arg) {
	int lastBytesWritten=0;
	struct write_thread_data *my_data;
	//int chunksize = 4096; //4096;

	struct timespec sleepTime;
	struct timespec remainingSleepTime;

	int rc;
	int locWrittenBytes, locbytesToSend, locTiocout, locSerFd, locOutBufSize; // avoiding mutex problems
	int hasWrongedYet=0;
	int doWrite=1;
	int locbytesToWrite, locFullRemain=0;

	struct timeval tswrNow, tswrPrev, tswrDelta;
	float deltasec;
	float sleepdelta;
	//int gaugeRate=200000; // gauge the write rate to this value, in Bytes/sec
	//float gaugeBPeriod=1.0/gaugeRate; // duration in time of 1 byte as per gauge Rate.. i.e.
	float chunkperiod;
	//~ float chunknsleep;

	//~ fprintf(stderr, "write_thread_function spawned\n");

	rc = pthread_mutex_lock(&mutex);
	my_data = (struct write_thread_data *) arg;

	my_data->writtenBytes = locWrittenBytes = 0;
	my_data->writeWrongs = 0;
	my_data->writeFails = 0;
	my_data->outBufSize = -1;
	locSerFd = my_data->fd;
	locbytesToSend = my_data->bytesToSend;
	rc = pthread_mutex_unlock(&mutex);

	// handle files smaller than chunksize:
	if (locbytesToSend < chunksize) chunksize = locbytesToSend;
  fprintf(stdout, "write_thread_function spawned - chunksize %d; locbytesToSend %d... \n", chunksize, locbytesToSend);

	gettimeofday( &tswrPrev, NULL );
	sleepTime.tv_sec=0;

	// main while loop for writing..
	while (locWrittenBytes < locbytesToSend)//(my_data->writtenBytes < my_data->bytesToSend)
	{
		// below will render cmdline display of wrBps more correctly,
		// but it also increases probability of drops:
		//~ rc = pthread_mutex_lock(&mutex);
		//~ my_data->wrBps = 0;
		//~ rc = pthread_mutex_unlock(&mutex);

		// get num of bytes in output buffer.
		if (ioctl(locSerFd, TIOCOUTQ, &locTiocout) == -1) {
			perror("TIOCOUTQ()");
			//return 0;
		}

		// if we can - decide here whether to write at all
		// if the buffer is at max = pause and skip (or exhaust buffer in its own while loop)
		doWrite = 1; // ... do the write , if we don't have buffer size
		locbytesToWrite = chunksize; // .. and write entire chunksize...
		if (locFullRemain) if (locFullRemain < chunksize) { // ... except in a case when approaching end of transmittion
			locbytesToWrite = locFullRemain;
			//~ fprintf(stderr, "   writing: %d (%d)\n", locbytesToWrite, locTiocout);
		}
		if (hasWrongedYet) { // ... but, if we have buffer size, decide
			// only if locTiocout has been emptied below max size - chunksize, then write; so don't change the above ...

			if (!(locTiocout <= locOutBufSize - chunksize)) { // else, locTiocout has NOT been emptied, skip
				// take a break;
				//~ sleepTime.tv_sec=0;
				sleepTime.tv_nsec=1000;
				nanosleep(&sleepTime,&remainingSleepTime);

				continue; // this should pass over the rest of the while loop...
				doWrite = 0; // ... but if not - just in case, this one should skip too
			}
		}

		// gauge - move after

		if (!doWrite) continue;

		// DO THE WRITE
		// not locking mutex yet here - since we only read from my_data here, and it cannot be written in another thread
		if (doWrite) lastBytesWritten = write( my_data->fd, my_data->comm + my_data->writtenBytes, locbytesToWrite );	// my_data->bytesToSend - my_data->writtenBytes
		chunkperiod = lastBytesWritten*gaugeBPeriod;
    my_data->writtenBytes += lastBytesWritten; // do it here quickly, for better printout
    fprintf(stderr, "   write: %d * \n", lastBytesWritten);

		// gauge
		if (lastBytesWritten > 0) {
			gettimeofday( &tswrNow, NULL );
			timeval_subtract(&tswrDelta, &tswrNow, &tswrPrev);
			deltasec = tswrDelta.tv_sec+tswrDelta.tv_usec*1e-6;
			// chunkperiod = lastBytesWritten*gaugeBPeriod; // calc it only when lastBytesWritten is set
      sleepdelta = chunkperiod - deltasec;
			if (sleepdelta > 0) {
				// no need for skip now, if after?
        // doWrite = 0; // skip, if we have not waited the time that corresponds to last ammount of written bytes

        // and sleep a bit - else may spin too fast, and use too much CPU;
				//~ sleepTime.tv_sec=0;
				// sleep for 25% of chunkperiod
				//~ chunknsleep = 0.25*(chunkperiod/1e-9);
				// 256/200000 = 1.28 ms; more for others
        sleepTime.tv_sec = floor(sleepdelta);
				sleepTime.tv_nsec=1e9*(sleepdelta - floor(sleepdelta));//(int)chunknsleep; //1000;
				nanosleep(&sleepTime,&remainingSleepTime);
				// instead of nanosleep - maybe while loop sleep?? NO - not safe..
				//~ doWrite = 1000; while (doWrite--) __asm__("nop;nop;nop");
      }
		}



		//timestamp
		gettimeofday( &tswrNow, NULL );
		timeval_subtract(&tswrDelta, &tswrNow, &tswrPrev);
		deltasec = tswrDelta.tv_sec+tswrDelta.tv_usec*1e-6;
		tswrPrev = tswrNow;

		// now lock:
		rc = pthread_mutex_lock(&mutex);
		//~ my_data->writtenBytes += lastBytesWritten; // only execute if OK !
		my_data->tiocout = locTiocout;

		//~ fprintf(stderr, "   write: %d - %d :: %d / %d * \n", lastBytesWritten, locWrittenBytes, locTiocout, locFullRemain); // only lastBytesWritten is accurate here
		//~ fprintf(stderr, "   write: %d * \n", lastBytesWritten);
		fflush(stderr);

		if ( lastBytesWritten < 0 )
		{
			fprintf(stderr, "write failed: %d = %s / %d - %d\n", errno , strerror(errno), lastBytesWritten, my_data->writtenBytes); // too much data

			//my_data->writtenBytes -= lastBytesWritten; // ACTUALY, DO NOTHING HERE - DO NOT DECREASE!!?
			my_data->writeFails++;
			locWrittenBytes = my_data->writtenBytes;
			rc = pthread_mutex_unlock(&mutex);

			// sleep more
			//~ sleepTime.tv_sec=0;
			sleepTime.tv_nsec=40000;
			nanosleep(&sleepTime,&remainingSleepTime);

			//return 0;
		}
		else {
			//my_data->writtenBytes += lastBytesWritten; //moved up
			locWrittenBytes = my_data->writtenBytes;
			locFullRemain = locbytesToSend - locWrittenBytes;
			my_data->wrBps = lastBytesWritten/deltasec;

			//~ fprintf(stderr, "   writeB: %d - %d :: %d / %d :: B/s %.02f * \n", lastBytesWritten, locWrittenBytes, locTiocout, locFullRemain, my_data->wrBps);
			if (locFullRemain < chunksize) fprintf(stderr, "\n\n\n"); // don't miss the last parts

			if ( ( lastBytesWritten != chunksize ) && (locFullRemain) ) // if locFullRemain == 0, then we're done, so wronged don't matter
			{
				//~ fprintf(stderr, "write wrong! %d = %s / %d - %d\n", errno , strerror(errno), lastBytesWritten, my_data->writtenBytes); // errno can repeat last error here - else it is 0 - too much data...
				if (!(hasWrongedYet)) {
					// at this moment, my_data->writtenBytes is as big
					// as the implied output buffer size
					locOutBufSize = my_data->writtenBytes;
					my_data->outBufSize = locOutBufSize;
					hasWrongedYet = 1;
				}
				my_data->writeWrongs++;


				rc = pthread_mutex_unlock(&mutex);

				// we have bumped into PC buffer limit
				// put the thread to sleep for a while,
				// and get buffer emptied
				// lets try 20 us
				//~ sleepTime.tv_sec=0;
				sleepTime.tv_nsec=20000;
				nanosleep(&sleepTime,&remainingSleepTime);
			}
			else{ //  'else' just to avoid unlocking thread twice
				rc = pthread_mutex_unlock(&mutex);
			}
		}
	}
	return NULL; //pthread_exit(NULL)
}

int main( int argc, char **argv )
{

	if(( argc < 4 ) || (argc > 6)) {
		usage(argv);
		return 1;
	}

	char *serport;
	char *serspeed;
	speed_t serspeed_t;
	char *serfstr;
	int serf_fd; // if < 0, then serfstr is a string
	int sentBytes;
	int readChars;
	int recdBytes, totlBytes, deltaBytes;
	int eagain_count=0;

  char *chunksize_s;
  char *gaugerate_s;

	char* sResp;
	char* sRespTotal;

	struct timeval timeStart, timeEnd, timeDelta;
	float deltasec, expectBps, measReadBps, measWriteBps;
	struct timeval tsrdNow, tsrdPrev, tsrdDelta;
	float rddeltasec;

	struct write_thread_data wrdata;
	pthread_t myWriteThread;
	int locBytesToSend;

	struct timespec sleepTime;
	//~ struct timespec remainingSleepTime;

	int ser_status;
	int rc;
	int count_fionread;
	//~ int count_get;

	/* Re: connecting alternative output stream to terminal -
	* http://coding.derkeiler.com/Archive/C_CPP/comp.lang.c/2009-01/msg01616.html
	* send read output to file descriptor 3 if open,
	* else just send to stdout
	*/
	fprintf(stdout, "Got %d arguments.\n", argc);
	FILE *stdalt;
	if(dup2(3, 3) == -1) {
		fprintf(stdout, "stdalt not opened; ");
		stdalt = fopen("/dev/tty", "w");
	} else {
		fprintf(stdout, "stdalt opened; ");
		stdalt = fdopen(3, "w");
	}
	fprintf(stdout, "Alternative file descriptor: %d\n", fileno(stdalt));

	fflush(stdout);

	// Get the PORT name
	serport = argv[1];
	fprintf(stdout, "Opening port %s;\n", serport);

	// Get the baudrate
	serspeed = argv[2];
	serspeed_t = string_to_baud(serspeed);
	fprintf(stdout, "Got serial speed %s baud (%d/0x%x);\n", serspeed, serspeed_t, serspeed_t);

	//Get file or command;
	serfstr = argv[3];
	serf_fd = open( serfstr, O_RDONLY );
	fprintf(stdout, "Got file/string '%s'; ", serfstr);
	if (serf_fd < 0) {
		wrdata.bytesToSend = strlen(serfstr);
		wrdata.comm = serfstr; //pointer already defined
		fprintf(stdout, "interpreting as string (%d).\n", wrdata.bytesToSend);
	} else {
		struct stat st;
		stat(serfstr, &st);
		wrdata.bytesToSend = st.st_size;
		wrdata.comm = (char *)calloc(wrdata.bytesToSend, sizeof(char));
		read(serf_fd, wrdata.comm, wrdata.bytesToSend);
		fprintf(stdout, "opened as file (%d).\n", wrdata.bytesToSend);
	}

  // get chunksize (optional)
	chunksize_s = argv[4];
  if (chunksize_s != NULL) {
    chunksize = atoi(chunksize_s);
    fprintf(stdout, "Got arg: ");
  } else fprintf(stdout, "No arg, default: ");
	fprintf(stdout, "Chunksize %d bytes\n", chunksize);

  // get chunksize (optional)
	gaugerate_s = argv[5];
  if ((gaugerate_s != NULL) && (argc >= 5)) {
    gaugeRate = atoi(gaugerate_s);
    fprintf(stdout, "Got arg: ");
  } else fprintf(stdout, "No arg, default: ");
  gaugeBPeriod=1.0/gaugeRate;
	fprintf(stdout, "gaugeRate %d bytes/s (period: %f)\n", gaugeRate, gaugeBPeriod);

	locBytesToSend = wrdata.bytesToSend; // local copy, so we don't complicate things with mutex
	fflush(stdout);

	sResp = (char *)calloc(wrdata.bytesToSend, sizeof(char));
	sRespTotal = (char *)calloc(wrdata.bytesToSend, sizeof(char));

	// Open and Initialise port
	serport_fd = open( serport, O_RDWR | O_NOCTTY | O_NONBLOCK );
	if ( serport_fd < 0 ) { perror(serport); return 1; }
	initport( serport_fd, serspeed_t );

	// reset DTR
	// get DTR
    if (ioctl(serport_fd, TIOCMGET, &ser_status) == -1) {
        perror("getDTR()");
        return 0;
    }
	ser_status &= ~TIOCM_DTR;
	if (ioctl(serport_fd, TIOCMSET, &ser_status) == -1) {
		perror("setDTR");
		return 0;
	}

	// flush both in and out buffers
	if (ioctl(serport_fd, TCFLSH, TCIOFLUSH) == -1) {
		perror("TCFLSH");
		return 0;
	}

	wrdata.fd = serport_fd;

  // also, init (else bad values in report before thread kicks in):
  wrdata.writtenBytes = 0;
  wrdata.tiocout = 0;
  wrdata.writeFails = 0;

	sentBytes = 0; recdBytes = 0;

	// flush receive - blocks
	//~ readChars = read( serport_fd, sResp, wrdata.bytesToSend);
	//~ fprintf(stderr, "flush %d - %s", readChars, sResp);
	//~ while ( (readChars = read( serport_fd, sResp, wrdata.bytesToSend)) >= 0 )
	//~ {
		//~ fprintf(stderr, "flush %d - %s", readChars, sResp);
	//~ }


	gettimeofday( &timeStart, NULL );
	tsrdPrev = timeStart;

	// start the thread for writing..
	if ( pthread_create( &myWriteThread, NULL, write_thread_function, (void *) &wrdata) ) {
		printf("error creating thread.");
		abort();
	}

	// run read loop
	while ( recdBytes < locBytesToSend )
	{

    // causes trouble with FT245 test ?!
		//~ while ( wait_flag == TRUE );

    //~ if (recdBytes >= wrdata.writtenBytes) {
      //~ // sleep and skip
      //~ sleepTime.tv_sec = floor(gaugeBPeriod);
      //~ sleepTime.tv_nsec=1e9*(gaugeBPeriod - floor(gaugeBPeriod));
      //~ nanosleep(&sleepTime,NULL);
      //~ continue; // hopefully skips rest of this loop (including printout)? yup
    //~ }

		// get count of bytes waiting using FIONREAD:
		if (ioctl(serport_fd, FIONREAD, &count_fionread) == -1) {
			perror("FIONREAD()");
			//return 0;
		}

    // make attempt to 'flush' get if we're underfilled, even if fionread reports 0?
    // cannot, causes: SERIAL read error: 4 = Interrupted system call
    //~ count_get = wrdata.writtenBytes - recdBytes;
    //~ if (count_fionread > count_get) count_get = count_fionread;

		// retrieve exactly the ammount reported by FIONREAD..
		if ( (readChars = read( serport_fd, sResp, count_fionread )) >= 0 ) // was count_get
		{
      if (readChars > 0) {
        //~ fprintf(stdout, "InVAL: (%d) %s\n", readChars, sResp);
        // binary safe - add sResp chunk to sRespTotal
        memmove(sRespTotal+recdBytes, sResp+0, readChars*sizeof(char));
        /* // text safe, but not binary:
        sResp[readChars] = '\0';
        fprintf(stdalt, "%s", sResp);
        */
        recdBytes += readChars;
      } else {
        // in case all is fine, but we got 0 bytes:
        // sleep a bit - so we allow for recv buffer to fill?
        sleepTime.tv_sec = floor(gaugeBPeriod);
				sleepTime.tv_nsec=1e9*(gaugeBPeriod - floor(gaugeBPeriod));
				nanosleep(&sleepTime,NULL);
      }
		} else {
			if ( errno == EAGAIN )
			{
				eagain_count++;
				//fprintf(stdout, "SERIAL EAGAIN ERROR %d\n", eagain_count);
				//return 0;
				// sleep a bit ?? NO

				//~ sleepTime.tv_sec=0;
				//~ sleepTime.tv_nsec=1000;
				//~ nanosleep(&sleepTime,&remainingSleepTime);
				//usleep(1);

			}
			else
			{
				fprintf(stdout, "SERIAL read error: %d = %s\n", errno , strerror(errno));
				return 0;
			}
		}

		// timestamp
		gettimeofday( &tsrdNow, NULL );
		timeval_subtract(&tsrdDelta, &tsrdNow, &tsrdPrev);
		rddeltasec = tsrdDelta.tv_sec+tsrdDelta.tv_usec*1e-6;
		tsrdPrev = tsrdNow;

		rc = pthread_mutex_lock(&mutex);
		//~ if (recdBytes % 2) { // lessen frequency?.. NOT like that.
		// 'realtime' printout to terminal
		// comment it, to see *processor usage* drop significantly without the printout, although not always (it can also sometimes influence transmittion rate too, but not in all cases).
    if (count_fionread > 0)
      fprintf(stderr, "   EAG: %d, WR: %d, WF: %d, rd: %d, wr: %d, FRD: %5d, TOU: %5d, OBS: %5d, RB/s: %10.02f, WB/s: %9.02f    \r", eagain_count, wrdata.writeWrongs, wrdata.writeFails, recdBytes, wrdata.writtenBytes, count_fionread, wrdata.tiocout, wrdata.outBufSize, readChars/rddeltasec, wrdata.wrBps);
		//fflush(stderr);
		//~ }
		rc = pthread_mutex_unlock(&mutex);

		//~ wait_flag = TRUE; // was ==
		//~ usleep(50000);

		// adding for single/two byte drops
		deltaBytes = locBytesToSend - recdBytes;
		if ((deltaBytes > 0) && (deltaBytes <= 2))
		{
			int lastBytesWritten = 0;
			char* addit = "XX";

			rc = pthread_mutex_lock(&mutex);

			fprintf(stderr, "   DROP DETECTED: %d; WILL REWRITE\n", deltaBytes);
			// wait a millisecond ...
			usleep(1000);

			// and then re-write missing number of bytes...
			lastBytesWritten = write( wrdata.fd, addit, deltaBytes );
			//~ my_data->writtenBytes += lastBytesWritten;
			if ( lastBytesWritten < 0 )
			{
				fprintf(stdout, "write failed!\n");
				return 0;
			}
			fprintf(stderr, "   write: %d - %d\n", lastBytesWritten, wrdata.writtenBytes);
			fflush(stderr);
			rc = pthread_mutex_unlock(&mutex);
		}

	} // end while - // run read loop

	if ( pthread_join ( myWriteThread, NULL ) ) {
		printf("error joining thread.");
		abort();
	}

	gettimeofday( &timeEnd, NULL );

	// binary safe - dump sRespTotal to stdalt
	fwrite(sRespTotal, sizeof(char), recdBytes, stdalt);

	// Close the open port
	close( serport_fd );
	if (!(serf_fd < 0)) {
		close( serf_fd );
		free(wrdata.comm);
	}
	free(sResp);
	free(sRespTotal);

	fprintf(stdout, "\n+++DONE+++\n");

	sentBytes = wrdata.writtenBytes;
	totlBytes = sentBytes + recdBytes;
	timeval_subtract(&timeDelta, &timeEnd, &timeStart);
	deltasec = timeDelta.tv_sec+timeDelta.tv_usec*1e-6;
	expectBps = atoi(serspeed)/10.0f;
	measWriteBps = sentBytes/deltasec;
	measReadBps = recdBytes/deltasec;

	fprintf(stdout, "Wrote: %d bytes; Read: %d bytes; Total: %d bytes. \n", sentBytes, recdBytes, totlBytes);
	fprintf(stdout, "Start: %ld s %ld us; End: %ld s %ld us; Delta: %ld s %ld us. \n", timeStart.tv_sec, timeStart.tv_usec, timeEnd.tv_sec, timeEnd.tv_usec, timeDelta.tv_sec, timeDelta.tv_usec);
	fprintf(stdout, "%s baud for 8N1 is %d Bps (bytes/sec).\n", serspeed, (int)expectBps);
	fprintf(stdout, "Measured: write %.02f Bps (%.02f%%), read %.02f Bps (%.02f%%), total %.02f Bps.\n", measWriteBps, (measWriteBps/expectBps)*100, measReadBps, (measReadBps/expectBps)*100, totlBytes/deltasec);

	return 0;
}
