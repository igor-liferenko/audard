/*******************************************************************************
* captmini.c                                                                   *
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

Build with (basic):

gcc -Wall -g captmini.c -lasound -o captmini

# gcc -Wall -g -finstrument-functions captmini.c -lasound -o captmini
# gcc -Wall -g -pg -finstrument-functions captmini.c -lasound -o captmini #  callgraphs; -pg for gprof
# gcc -Wall -g -fdump-rtl-all -da captmini.c -lasound -o captmini # extra RTL callgraphs

Run with:

./captmini

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


static snd_output_t *log;

static snd_pcm_sframes_t (*readi_func)(snd_pcm_t *handle, void *buffer, snd_pcm_uframes_t size);
static snd_pcm_sframes_t (*readn_func)(snd_pcm_t *handle, void **bufs, snd_pcm_uframes_t size);

static snd_pcm_t *capture_pcm_handle;
static snd_pcm_hw_params_t *hw_params;
static snd_pcm_sw_params_t *sw_params;
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
static snd_pcm_stream_t streamdir = SND_PCM_STREAM_CAPTURE;
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

void doCapture() {

  write(trace_fd, "1", 1); // enable ftrace logging

  // note: _read function ask for size in frames
  // (and return actually processed also in frames)
  write(marker_fd, "readi_func\n", 11);
  ret1 = readi_func(capture_pcm_handle, audiobuf, period_chunksize_frames);
  // to save on disk, we could have done here:
  // write(fd, audiobuf, c) != c) ... (where c in bytes)
  // however here, just for test, we run read again
  #if TWOREADS
  write(marker_fd, "readi_func\n", 11);
  ret2 = readi_func(capture_pcm_handle, audiobuf, period_chunksize_frames);
  #endif

  write(trace_fd, "0", 1); // disable ftrace logging
}

int main() {

  // open ftrace tracing files (only works with sudo!) ; skipping errorchecks for these
  trace_fd = open(tracpath, O_WRONLY);
  marker_fd = open(markpath, O_WRONLY);

	if (mmap_flag) {
		readi_func = snd_pcm_mmap_readi;
		readn_func = snd_pcm_mmap_readn;
	} else {
		readi_func = snd_pcm_readi;
		readn_func = snd_pcm_readn;
	}

  // re-write name if variables above changed
  sprintf(pcm_name, "hw:%d,%d", cardnum, devicenum);

  // Open PCM device for recording (capture). * /
  reterr = snd_pcm_open(&capture_pcm_handle, pcm_name, streamdir, 0); // streamdir = SND_PCM_STREAM_CAPTURE
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
  reterr = snd_pcm_hw_params_any (capture_pcm_handle, hw_params);
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
		reterr = snd_pcm_hw_params_set_access_mask(capture_pcm_handle, hw_params, mask);
	} else
    reterr = snd_pcm_hw_params_set_access (capture_pcm_handle, hw_params, SND_PCM_ACCESS_RW_INTERLEAVED);

  if (reterr < 0) {
    fprintf(stderr, "cannot set access type (%s)\n",
            snd_strerror(reterr));
    exit(1);
  }

  // Signed 16-bit little-endian format ; format = SND_PCM_FORMAT_S16_LE * /
  reterr = snd_pcm_hw_params_set_format (capture_pcm_handle, hw_params, format);
  if (reterr < 0) {
    fprintf(stderr, "cannot set sample format (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // 44100 bits/second sampling rate (CD quality) * /
  // rate = 44100; but it may be changed after function returns:
  fprintf(stderr, "Setting rate near %u ... ", rate);
  reterr = snd_pcm_hw_params_set_rate_near (capture_pcm_handle, hw_params, &rate, 0);
  if (reterr < 0) {
    fprintf(stderr, "cannot set sample rate (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }
  fprintf(stderr, "got rate %u\n", rate);

  // Two channels (stereo) ; channels = 2* /
  reterr = snd_pcm_hw_params_set_channels (capture_pcm_handle, hw_params, channels);
  if (reterr < 0) {
    fprintf(stderr, "cannot set channel count (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Set period size to 32 frames *4 = 128 bytes. ; period_chunksize_frames = 32; * /
  reterr = snd_pcm_hw_params_set_period_size_near(capture_pcm_handle, hw_params, &period_chunksize_frames, &dir);
  if (reterr < 0) {
    fprintf(stderr, "cannot set period size (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Set buffer size to 64 frames *4 = 256 bytes. ; buffer_size_frames = 64; * /
  reterr = snd_pcm_hw_params_set_buffer_size_near(capture_pcm_handle, hw_params, &buffer_size_frames);
  if (reterr < 0) {
    fprintf(stderr, "cannot set buffer size (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  // Write the parameters to the driver * /
  reterr = snd_pcm_hw_params (capture_pcm_handle, hw_params);
  if (reterr < 0) {
    fprintf(stderr, "cannot set hw_params parameters (%s)\n",
            snd_strerror (reterr));
    snd_pcm_hw_params_dump(hw_params, log);
    exit (1);
  }

  // Dump stuff * /
  fprintf(stderr, "\n\nhw_params dump\n\n");
  snd_pcm_hw_params_dump(hw_params, log);

  fprintf(stderr, "\n\nsw_params dump\n\n");
  // Allocate a software parameters object. * /
  snd_pcm_sw_params_alloca(&sw_params);
  snd_pcm_sw_params_current(capture_pcm_handle, sw_params);
  snd_pcm_sw_params_dump(sw_params, log);

  fprintf(stderr, "\n\npcm_dump on capture_pcm_handle\n\n");
  snd_pcm_dump(capture_pcm_handle, log);

  fprintf(stderr, "\n\npcm_dump_setup on capture_pcm_handle\n\n");
  snd_pcm_dump_setup(capture_pcm_handle, log); // snd_pcm_dump_hw_setup && snd_pcm_dump_sw_setup

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
  reterr = snd_pcm_prepare (capture_pcm_handle);
  if (reterr < 0) {
    fprintf(stderr, "cannot prepare audio interface for use (%s)\n",
            snd_strerror (reterr));
    exit (1);
  }

  doCapture();

  #if TWOREADS
  fprintf(stderr, "Asked for 2x %lu frames --> got: %d then %d frames %s\n",
          period_chunksize_frames, ret1, ret2, (ret2 < 0) ? snd_strerror(ret2) : "");
  #else
  fprintf(stderr, "Asked for 1x %lu frames --> got: %d frames\n",
          period_chunksize_frames, ret1 );
  #endif

  snd_pcm_drain(capture_pcm_handle);
	snd_pcm_close(capture_pcm_handle);
	capture_pcm_handle = NULL;
	free(audiobuf);
  snd_output_close(log);
  close(marker_fd);
  close(trace_fd);
  exit(0);
}

