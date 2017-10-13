/*******************************************************************************
* playmini.c                                                                   *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/
/*
sdaau 2013; compiled from:
* [http://www.linuxjournal.com/article/6735?page=0,2 Introduction to Sound Programming with ALSA | Linux Journal]
* [http://equalarea.com/paul/alsa-audio.html A tutorial on using the ALSA Audio API]
* [ALSA Programming HOWTO v.1.0.0](http://alsamodular.sourceforge.net/alsa_programming_howto.html#sect03)
* alsa-utils-1.0.24.2/aplay/aplay.c
* [http://article.gmane.org/gmane.linux.alsa.user/29803 Re: Redirecting Mic Input in software (no arecord / aplay involved)]

Build with (basic):

gcc -Wall -g playmini.c -lasound -o playmini

# gcc -Wall -g -finstrument-functions playmini.c -lasound -o playmini
# gcc -Wall -g -pg -finstrument-functions playmini.c -lasound -o playmini #  callgraphs; -pg for gprof
# gcc -Wall -g -fdump-rtl-all -da playmini.c -lasound -o playmini # extra RTL callgraphs

Run with:

./playmini

Tested on ALSA version 1.0.24.2

*/

#include <stdio.h>
#include <stdlib.h>
#include <alsa/asoundlib.h>

// set this to 0 for one read, 1 for two reads
#ifndef TWOREADS
#define TWOREADS 1
#endif

#ifndef CARDNUM
#define CARDNUM 0
#endif

#ifndef AD_PRINT
#define AD_PRINT 1
#endif

#ifndef PLAY_SWPARAMS
#define PLAY_SWPARAMS 1
#endif

#ifndef PLAY_WAIT
#define PLAY_WAIT 1
#endif

#ifndef PLAY_DOSTART
#define PLAY_DOSTART 0
#endif

// NB: as it is, this locks doPlayback_v01
#ifndef PLAY_ADWAIT
#define PLAY_ADWAIT 1
#endif

// 280000 ns (280 μs) - determined as "sweet spot" for hda-intel (by playdelay.sh) - but including _avail
// 310000 ns (310 μs) - "sweet spot" without _avail (just sleep)
#ifndef NSDLY
#define NSDLY 310000L
#endif


static snd_output_t *log;

static snd_pcm_sframes_t (*writei_func)(snd_pcm_t *handle, const void *buffer, snd_pcm_uframes_t size);
static snd_pcm_sframes_t (*writen_func)(snd_pcm_t *handle, void **bufs, snd_pcm_uframes_t size);

static snd_pcm_t *playbck_pcm_handle;
static snd_pcm_hw_params_t *hw_params;
static snd_pcm_sw_params_t *sw_params;
static snd_pcm_status_t *status;
static int reterr;
static int dir;
static int ret1;
#if TWOREADS
static int ret2;
#endif
static u_char *audiobuf = NULL;

//set here:
static int cardnum = CARDNUM; // change just this (not pcm_name) - via define now
static int devicenum = 0;
static char pcm_name[] = "hw:0,0"; // hw:cardnum,devicenum
static snd_pcm_stream_t streamdir = SND_PCM_STREAM_PLAYBACK; //SND_PCM_STREAM_CAPTURE;
static snd_pcm_format_t format = SND_PCM_FORMAT_S16_LE;
static unsigned int rate = 44100;
unsigned int channels = 2;
static int mmap_flag = 0;
static snd_pcm_uframes_t period_chunksize_frames = 32;  //32 frames *4 = 128 bytes.
static snd_pcm_uframes_t buffer_size_frames = 64;       //64 frames *4 = 256 bytes.
static size_t period_chunksize_bytes; // period_chunksize_frames in bytes

// for ftrace:
static int trace_fd = -1;
static int marker_fd = -1;
static char tracpath[] = "/sys/kernel/debug/tracing/tracing_on";
static char markpath[] = "/sys/kernel/debug/tracing/trace_marker";
static char abuf2[256] = {[0 ... 255] = 5}; // initialization gcc specific

struct timespec tsp;
struct timespec trem;

// declare alternative function versions ...
void doPlayback_v01(void); // NB: as it is, locks at PLAY_ADWAIT...
void doPlayback_v02(void); // uses variable NSDLY for playdelay.sh
void doPlayback_v03(void); // uses (fixed default) NSDLY for run-alsa-capttest.sh
// ... and choose alternative function here:
static void (*doPlayback)(void) = doPlayback_v03;


void doPlayback_v03() {
  int waerr;
  tsp.tv_sec  = 0;
  tsp.tv_nsec = NSDLY; // 50 us = 50000 ns // nanosleep(&tsp , &trem);

  write(trace_fd, "1", 1); // enable ftrace logging

  if (! (waerr=snd_pcm_wait(playbck_pcm_handle, 1))) {
    fprintf(stderr, " error wait: %d (%s) \n", waerr, snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  }

  write(marker_fd, "readi_func\n", 11);
  ret1 = writei_func(playbck_pcm_handle, audiobuf, period_chunksize_frames);

  nanosleep(&tsp , &trem);

  write(marker_fd, "readi_func\n", 11);
  ret2 = writei_func(playbck_pcm_handle, abuf2, period_chunksize_frames);

  write(marker_fd, "spcm_drain\n", 11);
  if (snd_pcm_drain(playbck_pcm_handle)) {
    fprintf(stderr, " error drain \n");
  }

  write(trace_fd, "0", 1); // disable ftrace logging
}


void doPlayback_v02() {
  snd_pcm_sframes_t avail, delay;
  int state, aderr, waerr;//, i;
  tsp.tv_sec  = 0;
  tsp.tv_nsec = NSDLY; // 50 us = 50000 ns // nanosleep(&tsp , &trem);

  write(trace_fd, "1", 1); // enable ftrace logging

  // this snd_pcm_start will NOT make the >A: section stream turn from _PREPARED into _RUNNING;
  // for that, an actual writei is needed!
  snd_pcm_start(playbck_pcm_handle);

  do {
    state=snd_pcm_state(playbck_pcm_handle);
    waerr=snd_pcm_wait(playbck_pcm_handle, 1);
    aderr=snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
    fprintf(stderr, " >A: %s wait: %d avail:%ld delay:%ld (%d) \n", snd_pcm_state_name(state),waerr,avail,delay,aderr);
  } while (aderr != 0); // (state != SND_PCM_STATE_RUNNING);


  write(marker_fd, "readi_func\n", 11);
  ret1 = writei_func(playbck_pcm_handle, audiobuf, period_chunksize_frames);


  //~ i = 6;
  //~ do {
    state=snd_pcm_state(playbck_pcm_handle);
    waerr=snd_pcm_wait(playbck_pcm_handle, 1);
    // calling snd_pcm_avail() in the fprintfs causes XRUN! snd_pcm_avail_update survives..
    // also snd_pcm_delay (just as return) as first causes XRUNs everywhere.. (as last, sometimes even succeeds; any earlier than last - bad) ; same for snd_pcm_hwsync
    // also snd_pcm_status - if any but last, causes XRUN to propagate..
  //~ fprintf(stderr, " wait: %d %s %ld\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)), snd_pcm_avail_update(playbck_pcm_handle)); //32/44100 = 0.000725624 ~ 1 ms
  //~ fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  //~ fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  //~ fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  //~ fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  //~ fprintf(stderr, " wait: %d %s %d\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)), snd_pcm_status(playbck_pcm_handle, status));
  //~ fprintf(stderr, " wait: %d %s %d\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)), snd_pcm_avail_update(playbck_pcm_handle));
    //~ aderr=snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay); // here causes xrun next wait!;
    // nanosleep 500000L (500u) seems to work too instead of 6 fprintfs
    nanosleep(&tsp , &trem);
    aderr=snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay); // without prev (and at least 6 statements), here OK
    fprintf(stderr, " >B: %s wait: %d avail:%ld delay:%ld (%d) \n", snd_pcm_state_name(state),waerr,avail,delay,aderr);
    //~ fprintf(stderr, " >B: %s wait: %d \n", snd_pcm_state_name(state),waerr);
  //~ } while (aderr != 0); // (state != SND_PCM_STATE_RUNNING);


  write(marker_fd, "readi_func\n", 11);
  ret2 = writei_func(playbck_pcm_handle, abuf2, period_chunksize_frames);


  //~ do {
    //~ state=snd_pcm_state(playbck_pcm_handle);
    //~ waerr=snd_pcm_wait(playbck_pcm_handle, 1);
    //~ aderr=snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
    //~ fprintf(stderr, " >C: %s wait: %d avail:%ld delay:%ld (%d) \n", snd_pcm_state_name(state),waerr,avail,delay,aderr);
  //~ } while (aderr != 0); // (state != SND_PCM_STATE_RUNNING);

  write(trace_fd, "0", 1); // disable ftrace logging

}



void doPlayback_v01() {
  snd_pcm_sframes_t avail, delay;
  int st;

  tsp.tv_sec  = 0;
  tsp.tv_nsec = 500000000L; // 50 us = 50000 ns

  // note: _read/_write function ask for size in frames
  // (and return actually processed also in frames)

  st=snd_pcm_state(playbck_pcm_handle);
  fprintf(stderr, " state: %d (%s)\n", st, snd_pcm_state_name(st));

  #if PLAY_ADWAIT
  avail = 64L;
  #endif

  write(trace_fd, "1", 1); // enable ftrace logging

  #if PLAY_DOSTART
  //~ if (snd_pcm_state(playbck_pcm_handle) == SND_PCM_STATE_PREPARED) { // by this time, it is not PREPARED anymore!
  if (st == SND_PCM_STATE_PREPARED) {
    write(marker_fd, "pcm_startr\n", 11);
    snd_pcm_start(playbck_pcm_handle);
  }
  #endif

  write(marker_fd, "readi_func\n", 11);
  #if PLAY_WAIT
  fprintf(stderr, " wait: %d\n", snd_pcm_wait(playbck_pcm_handle, 1)); //32/44100 = 0.000725624 ~ 1 ms
  #endif
  #if AD_PRINT
  st = snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
  fprintf(stderr, " pb avail:%ld delay:%ld %s (%d)\n", avail, delay, snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)), st); // typ 64 / 0
  #endif

  ret1 = writei_func(playbck_pcm_handle, audiobuf, period_chunksize_frames);
  // to save on disk, we could have done here:
  // write(fd, audiobuf, c) != c) ... (where c in bytes)
  // however here, just for test, we run read again

  #if PLAY_ADWAIT
  //~ while (avail > period_chunksize_frames) {
    //~ int stserr;
    //~ snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
    //~ snd_pcm_wait(playbck_pcm_handle, 1);
    //~ stserr = snd_pcm_status(playbck_pcm_handle, status);
    //~ fprintf(stderr, " Apb avail:%ld delay:%ld stserr:%d\n", avail, delay, stserr);
    //~ fprintf(stderr, " Apb avail:%ld delay:%ld stserr:%d\n", snd_pcm_avail(playbck_pcm_handle), snd_pcm_avail_update(playbck_pcm_handle), snd_pcm_hwsync(playbck_pcm_handle));
    //~ nanosleep(&tsp , &trem);
  //~ }
  #endif


  #if TWOREADS
  write(marker_fd, "readi_func\n", 11);
  # if PLAY_WAIT
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle))); //32/44100 = 0.000725624 ~ 1 ms
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  fprintf(stderr, " wait: %d %s\n", snd_pcm_wait(playbck_pcm_handle, 1), snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)));
  # endif
  # if AD_PRINT
  st = snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
  fprintf(stderr, " pb avail:%ld delay:%ld %s (%d)\n", avail, delay, snd_pcm_state_name(snd_pcm_state(playbck_pcm_handle)), st); // typ 32 / 32; or 64 / 0 ; or 33 / 31
  # endif
  ret2 = writei_func(playbck_pcm_handle, abuf2, period_chunksize_frames);
  # if PLAY_ADWAIT
  while (avail > 0) {
    int stserr, wterr;
    wterr = snd_pcm_wait(playbck_pcm_handle, 1);
    snd_pcm_status(playbck_pcm_handle, status);
    stserr = snd_pcm_avail_delay(playbck_pcm_handle, &avail, &delay);
    fprintf(stderr, " Bpb avail:%ld delay:%ld stserr:%d wterr:%d\n", avail, delay, stserr, wterr);
    fprintf(stderr, " Bpb avail:%ld delay:%ld stserr:%d\n", snd_pcm_avail(playbck_pcm_handle), snd_pcm_avail_update(playbck_pcm_handle), snd_pcm_hwsync(playbck_pcm_handle));
    nanosleep(&tsp , &trem);
  }
  # endif
  #endif

  write(trace_fd, "0", 1); // disable ftrace logging
}

int main() {

  // open ftrace tracing files (only works with sudo!) ; skipping errorchecks for these
  trace_fd = open(tracpath, O_WRONLY);
  marker_fd = open(markpath, O_WRONLY);

	if (mmap_flag) {
		writei_func = snd_pcm_mmap_writei;
		writen_func = snd_pcm_mmap_writen;
	} else {
		writei_func = snd_pcm_writei;
		writen_func = snd_pcm_writen;
	}

  // re-write name if variables above changed
  sprintf(pcm_name, "hw:%d,%d", cardnum, devicenum);

  // Open PCM device for playback //recording (capture). * /
  reterr = snd_pcm_open(&playbck_pcm_handle, pcm_name, streamdir, 0); // _PLAYBACK; //streamdir = SND_PCM_STREAM_CAPTURE
  if (reterr < 0) {
    fprintf(stderr, "unable to open audio pcm device (%s): %s\n",
            pcm_name, snd_strerror(reterr));
    exit(1);
  }
  fprintf(stderr, "opened audio pcm device %s\n", pcm_name);

  // Attach snd debug log to stderr, for later dump * /
  reterr = snd_output_stdio_attach(&log, stderr, 0);
  if (reterr < 0) {
    fprintf(stderr, "cannot attach debug log to stderr (%s)\n",
            snd_strerror (reterr));
    exit(1);
  }

  // Allocate a hardware parameters object. * /
  //reterr = snd_pcm_hw_params_malloc(&hw_params);
  //if (reterr < 0) {
  //  fprintf(stderr, "cannot allocate hardware parameter structure (%s)\n",
  //          snd_strerror (reterr));
  //  exit(1);
  //}
  snd_pcm_hw_params_alloca(&hw_params);

  // Fill it in with default values. * /
  reterr = snd_pcm_hw_params_any (playbck_pcm_handle, hw_params);
  if (reterr < 0) {
    fprintf(stderr, "cannot initialize hardware parameter structure (%s)\n",
            snd_strerror(reterr));
    exit(1);
  }

  // Set the desired hardware parameters. * /

  // Interleaved mode * /
	if (mmap_flag) {
		snd_pcm_access_mask_t *mask = alloca(snd_pcm_access_mask_sizeof());
		snd_pcm_access_mask_none(mask);
		snd_pcm_access_mask_set(mask, SND_PCM_ACCESS_MMAP_INTERLEAVED);
		snd_pcm_access_mask_set(mask, SND_PCM_ACCESS_MMAP_NONINTERLEAVED);
		snd_pcm_access_mask_set(mask, SND_PCM_ACCESS_MMAP_COMPLEX);
		reterr = snd_pcm_hw_params_set_access_mask(playbck_pcm_handle, hw_params, mask);
	} else
    reterr = snd_pcm_hw_params_set_access (playbck_pcm_handle, hw_params, SND_PCM_ACCESS_RW_INTERLEAVED);

  if (reterr < 0) {
    fprintf(stderr, "cannot set access type (%s)\n",
            snd_strerror(reterr));
    exit(1);
  }

  // Signed 16-bit little-endian format ; format = SND_PCM_FORMAT_S16_LE * /
  reterr = snd_pcm_hw_params_set_format (playbck_pcm_handle, hw_params, format);
  if (reterr < 0) {
    fprintf(stderr, "cannot set sample format (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // 44100 bits/second sampling rate (CD quality) * /
  // rate = 44100; but it may be changed after function returns:
  fprintf(stderr, "Setting rate near %u ... ", rate);
  reterr = snd_pcm_hw_params_set_rate_near (playbck_pcm_handle, hw_params, &rate, 0);
  if (reterr < 0) {
    fprintf(stderr, "cannot set sample rate (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }
  fprintf(stderr, "got rate %u\n", rate);

  // Two channels (stereo) ; channels = 2* /
  reterr = snd_pcm_hw_params_set_channels (playbck_pcm_handle, hw_params, channels);
  if (reterr < 0) {
    fprintf(stderr, "cannot set channel count (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Set period size to 32 frames *4 = 128 bytes. ; period_chunksize_frames = 32; * /
  reterr = snd_pcm_hw_params_set_period_size_near(playbck_pcm_handle, hw_params, &period_chunksize_frames, &dir);
  if (reterr < 0) {
    fprintf(stderr, "cannot set period size (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Set buffer size to 64 frames *4 = 256 bytes. ; buffer_size_frames = 64; * /
  reterr = snd_pcm_hw_params_set_buffer_size_near(playbck_pcm_handle, hw_params, &buffer_size_frames);
  if (reterr < 0) {
    fprintf(stderr, "cannot set buffer size (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Write the parameters to the driver * /
  reterr = snd_pcm_hw_params (playbck_pcm_handle, hw_params);
  if (reterr < 0) {
    fprintf(stderr, "cannot set hw_params parameters (%s)\n",
            snd_strerror (reterr));
    snd_pcm_hw_params_dump(hw_params, log);
    exit (1);
  }

  snd_pcm_status_alloca(&status);

  // Dump stuff * /
  fprintf(stderr, "\n\nhw_params dump\n\n");
  snd_pcm_hw_params_dump(hw_params, log);

  fprintf(stderr, "\n\nsw_params dump\n\n");
  // Allocate a software parameters object. * /
  snd_pcm_sw_params_alloca(&sw_params);
  snd_pcm_sw_params_current(playbck_pcm_handle, sw_params);
  #if PLAY_SWPARAMS
	// start the transfer when the buffer is almost full (default is 1): * /
	// (buffer_size / avail_min) * avail_min * /
	reterr = snd_pcm_sw_params_set_start_threshold(playbck_pcm_handle, sw_params, period_chunksize_frames);
	if (reterr < 0) {
		SNDERR("Unable to set start threshold mode for (%s)", snd_strerror(reterr));
		return reterr;
	}
	// allow the transfer when at least period_size samples can be processed * /
  // I get by default, avail_min set to 32 == period_chunksize_frames
  // so skipping this command:
	//~ reterr = snd_pcm_sw_params_set_avail_min(playbck_pcm_handle, sw_params, period_chunksize_frames);
	//~ if (reterr < 0) {
		//~ SNDERR("Unable to set avail min for (%s)", snd_strerror(reterr));
		//~ return reterr;
	//~ }
	// write the parameters to the playback device * /
	reterr = snd_pcm_sw_params(playbck_pcm_handle, sw_params);
	if (reterr < 0) {
		SNDERR("Unable to set sw params for (%s)", snd_strerror(reterr));
		return reterr;
	}
  #endif
  snd_pcm_sw_params_dump(sw_params, log);

  fprintf(stderr, "\n\npcm_dump on playbck_pcm_handle\n\n");
  snd_pcm_dump(playbck_pcm_handle, log);

  fprintf(stderr, "\n\npcm_dump_setup on playbck_pcm_handle\n\n");
  snd_pcm_dump_setup(playbck_pcm_handle, log); // snd_pcm_dump_hw_setup && snd_pcm_dump_sw_setup

  // Re-get the period & buffer sizes in frames, to make sure ALSA has allocated the demanded * /
	snd_pcm_hw_params_get_period_size(hw_params, &period_chunksize_frames, 0);
	snd_pcm_hw_params_get_buffer_size(hw_params, &buffer_size_frames);
  period_chunksize_bytes = period_chunksize_frames * snd_pcm_format_physical_width(format) * channels / 8;

  fprintf(stderr, "\nGot final period_chunksize_frames: %lu (bytes: %d); buffer_size_frames: %lu \n", period_chunksize_frames, period_chunksize_bytes, buffer_size_frames);

  // Allocate this program's audio buffer * /
  audiobuf = (u_char *)malloc(period_chunksize_bytes);
	if (audiobuf == NULL) {
		fprintf(stderr, "not enough memory\n");
    exit (1);
	}

  // Prepare capture stream * /
  reterr = snd_pcm_prepare (playbck_pcm_handle);
  if (reterr < 0) {
    fprintf(stderr, "cannot prepare audio interface for use (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  doPlayback();

  #if TWOREADS
  fprintf(stderr, "Asked for 2x %lu frames --> got: %d then %d frames %s\n",
          period_chunksize_frames, ret1, ret2, (ret2 < 0) ? snd_strerror(ret2) : "");
  #else
  fprintf(stderr, "Asked for 1x %lu frames --> got: %d frames\n",
          period_chunksize_frames, ret1 );
  #endif

  snd_pcm_drain(playbck_pcm_handle);
	snd_pcm_close(playbck_pcm_handle);
	playbck_pcm_handle = NULL;
	free(audiobuf);
  snd_output_close(log);
  close(marker_fd);
  close(trace_fd);
  exit(0);
}

