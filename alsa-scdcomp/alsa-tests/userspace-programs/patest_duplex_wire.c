/*******************************************************************************
* patest_duplex_wire.c                                                         *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/
/** @file patest_duplex_wire.c
	@ingroup test_src
	@brief play to output, read input at the same time, for X seconds
 NB: playCallback and wireCallback are not used, nor checked if they
 work properly; they are just copied for reference

	Note that some HW devices, for example many ISA audio cards
	on PCs, do NOT support full duplex! For a PC, you normally need
	a PCI based audio card such as the SBLive.

	@author Phil Burk  http://www.softsynth.com
	@author sdaau      sdaau [at] users.sourceforge.net

 While adapting to V19-API, I excluded configs with framesPerCallback=0
 because of an assert in file pa_common/pa_process.c. Pieter, Oct 9, 2003.

*/
/*
 * $Id: patest_duplex_wire.c X 2013-07-05,2013-09-19 00:38:27Z sdaau $
 * Id: patest_wire.c 1368 2008-03-01 00:38:27Z rossb $
 *
 * This program uses the PortAudio Portable Audio Library.
 * For more information see: http://www.portaudio.com
 * Copyright (c) 1999-2000 Ross Bencina and Phil Burk
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files
 * (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
 * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 * CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/*
 * The text above constitutes the entire PortAudio license; however,
 * the PortAudio community also makes the following non-binding requests:
 *
 * Any person wishing to distribute modifications to the Software is
 * requested to send the modifications to the original developer so that
 * they can be incorporated into the canonical version. It is also
 * requested that these non-binding requests be included along with the
 * license above.
 */

#include <stdio.h>
#include <math.h>
#include <stdlib.h> // malloc, free
#include <fcntl.h>  // O_WRONLY
#include <getopt.h> // POSIX only - may have alternatives for Windows
#include "portaudio.h"
#include <time.h> // added for CLOCK_REALTIME

// just for alsa dump:
#include <alsa/asoundlib.h> // added for snd_output_t
// also including these structs (from pa_linux_alsa.c)
#include "pa_stream.h" // for PaUtilStreamRepresentation
#include "pa_cpuload.h" // for PaUtilCpuLoadMeasurer
#include "pa_process.h" // for PaUtilBufferProcessor
#include "pa_unix_util.h" // for PaUnixThread
// tried to cheat by using "extern" here, but cannot;
// so must copy the full structs here:
typedef enum
{
    StreamDirection_In,
    StreamDirection_Out
} StreamDirection;
typedef struct
{
    PaSampleFormat hostSampleFormat;
    unsigned long framesPerBuffer;
    int numUserChannels, numHostChannels;
    int userInterleaved, hostInterleaved;
    int canMmap;
    void *nonMmapBuffer;
    unsigned int nonMmapBufferSize;
    PaDeviceIndex device;     //* Keep the device index * /

    snd_pcm_t *pcm;
    snd_pcm_uframes_t bufferSize;
    snd_pcm_format_t nativeFormat;
    unsigned int nfds;
    int ready;  //* Marked ready from poll * /
    void **userBuffers;
    snd_pcm_uframes_t offset;
    StreamDirection streamDir;

    snd_pcm_channel_area_t *channelAreas;  //* Needed for channel adaption * /
} PaAlsaStreamComponent;
//* Implementation specific stream structure * /
typedef struct PaAlsaStream
{
    PaUtilStreamRepresentation streamRepresentation;
    PaUtilCpuLoadMeasurer cpuLoadMeasurer;
    PaUtilBufferProcessor bufferProcessor;
    PaUnixThread thread;

    unsigned long framesPerUserBuffer, maxFramesPerHostBuffer;

    int primeBuffers;
    int callbackMode;              //* bool: are we running in callback mode? * /
    int pcmsSynced;                //* Have we successfully synced pcms * /
    int rtSched;

    //* the callback thread uses these to poll the sound device(s), waiting
    //* for data to be ready/available * /
    struct pollfd* pfds;
    int pollTimeout;

    //* Used in communication between threads * /
    volatile sig_atomic_t callback_finished; //* bool: are we in the "callback finished" state? * /
    volatile sig_atomic_t callbackAbort;    //* Drop frames? * /
    volatile sig_atomic_t isActive;         //* Is stream in active state? (Between StartStream and StopStream || !paContinue) * /
    PaUnixMutex stateMtx;                   //* Used to synchronize access to stream state * /

    int neverDropInput;

    PaTime underrun;
    PaTime overrun;

    PaAlsaStreamComponent capture, playback;
}
PaAlsaStream;




#include "pa_util.h" // PaUtil_GetTime?
/*
* PaUtil_GetTime is in pa_util.h/pa_unix_util.c/libportaudio.so;
* In principle, just #include "pa_util.h" should be enough to get
* PaUtil_GetTime; unfortunately, this function is local
* (symbol not exported) in the libportaudio.so; thus the linking
* step chokes with undefined reference to `PaUtil_GetTime';
* the same choke with undefined reference for extern too:
* extern PaTime PaUtil_GetTime( void );
* So, repeating that function below:
*/
PaTime PaUtil_GetTime( void )
{
#ifdef HAVE_MACH_ABSOLUTE_TIME
    return mach_absolute_time() * machSecondsConversionScaler_;
#elif defined(HAVE_CLOCK_GETTIME)
    struct timespec tp;
    clock_gettime(CLOCK_REALTIME, &tp);
    return (PaTime)(tp.tv_sec + tp.tv_nsec * 1e-9);
#else
    struct timeval tv;
    gettimeofday( &tv, NULL );
    return (PaTime) tv.tv_usec * 1e-6 + tv.tv_sec;
#endif
}


#define PLAYFILE "/media/disk2/tmp/out16s.dat"
#define RECFILE "duwrecorded.raw"


#define VALUE_TO_STRING(x) #x
#define VALUE(x) VALUE_TO_STRING(x)
#define VAR_NAME_VALUE(var) #var "="  VALUE(var)

/* // these are now variables settable through command line options
#ifdef USE_PLAYREC_CALLBACKS
  #pragma message "Got USE_PLAYREC_CALLBACKS ..."
#else
  #pragma message "Did NOT get USE_PLAYREC_CALLBACKS ..."
  #define USE_PLAYREC_CALLBACKS 1   // if 1, uses play+rec callbacks;
                                    // if 0, uses wire callback
#endif


// if wire callback used:
#define WIRE_CALLBACK_INTERLEAVED 1   // if 1, play and record ops are interleaved
                                      // if 0, play ops go first, then record

#ifdef FRAMES_PER_BUFFER
  #pragma message "Got FRAMES_PER_BUFFER ..."
#else
  #pragma message "Did NOT get FRAMES_PER_BUFFER ..."
  #define FRAMES_PER_BUFFER (512) // (512) // paFramesPerBufferUnspecified is (0)
#endif

#pragma message "Using " VAR_NAME_VALUE(USE_PLAYREC_CALLBACKS) " and " VAR_NAME_VALUE(FRAMES_PER_BUFFER)
#define NUM_SECONDS     (2) //(5)

#define INPUT_DEVICE           (0) // (Pa_GetDefaultInputDevice())
#define OUTPUT_DEVICE          (0) //(Pa_GetDefaultOutputDevice())
*/

#define SAMPLE_RATE            (44100)
#define NUM_CHANNELS    (2)
/* #define DITHER_FLAG     (paDitherOff) */
#define DITHER_FLAG     (0) /**/

static int use_playrec_callbacks = 1;
static int wire_callback_interleaved = 1;
static int frames_per_buffer = 512;
static float num_seconds = 2.0;
static int num_frames = 0; //num_seconds*SAMPLE_RATE
static int input_device = 0;
static int output_device = 0;
static int msleep = 500; // argument for Pa_Sleep in the main loops

static struct option long_option[] =
{
  //{"help", 0, NULL, 'h'},
  {"use_playrec_callbacks", 1, NULL, 'c'},
  {"wire_callback_interleaved", 1, NULL, 'w'},
  {"frames_per_buffer", 1, NULL, 'b'},
  {"num_seconds", 1, NULL, 's'},
  {"num_frames", 1, NULL, 'f'},
  {"input_device", 1, NULL, 'i'},
  {"output_device", 1, NULL, 'o'},
  {"msleep", 1, NULL, 'm'},
  {"timepad", 1, NULL, 'p'},
  {NULL, 0, NULL, 0},
};

// ALSA-specific for dumping
snd_output_t *dumpoutput = NULL;

typedef struct WireConfig_s
{
    int isInputInterleaved;
    int isOutputInterleaved;
    int numInputChannels;
    int numOutputChannels;
    int framesPerCallback;
} WireConfig_t;


#define USE_FLOAT_INPUT        (0)
#define USE_FLOAT_OUTPUT       (0)

/* Latencies set to defaults. */

#if USE_FLOAT_INPUT
    #define INPUT_FORMAT  paFloat32
    typedef float INPUT_SAMPLE;
    typedef float SAMPLE;           //add
    #define SAMPLE_SILENCE  (0.0f)  //add
#else
    #define INPUT_FORMAT  paInt16
    typedef short INPUT_SAMPLE;
    typedef short SAMPLE;           //add
    #define SAMPLE_SILENCE  (0)     //add
#endif

#if USE_FLOAT_OUTPUT
    #define OUTPUT_FORMAT  paFloat32
    typedef float OUTPUT_SAMPLE;
#else
    #define OUTPUT_FORMAT  paInt16
    typedef short OUTPUT_SAMPLE;
#endif

// from patest_record.c
typedef struct
{
    int          frameIndex;  /* Index into sample array. */
    int          maxFrameIndex;
    SAMPLE      *recordedSamples;
}
paTestDataRC; //paTestData; // rec/capture

// from patest_wmme_ac3.c
typedef struct
{
    SAMPLE *buffer;
    int bufferSampleCount;  // unit: samples!
    int bufferFrameCount;   //added for debug; unit in frames (samples*NUM_CHANNELS)
    int playbackIndexSamples; // unit: samples!
}
paTestDataPY; //paTestData; playback

typedef struct
{
    paTestDataRC *rc;
    paTestDataPY *py;
    WireConfig_t *wc;
}
paTestDataDX;

//~ double gInOutScaler = 1.0;
//~ #define CONVERT_IN_TO_OUT(in)  ((OUTPUT_SAMPLE) ((in) * gInOutScaler))


// NB: trace_marker will require sudo when calling this program
// for ftrace: //added
static int trace_fd = -1;
static int marker_fd = -1;
static char tracpath[] = "/sys/kernel/debug/tracing/tracing_on";
static char markpath[] = "/sys/kernel/debug/tracing/trace_marker";



static PaError SetConfiguration( WireConfig_t *config , PaStreamParameters *inputParameters, PaStreamParameters *outputParameters );


/* patest_record.c
** This routine will be called by the PortAudio engine when audio is needed.
** It may be called at interrupt level on some machines so don't do anything
** that could mess up the system like calling malloc() or free().
*/
static int recordCallback( const void *inputBuffer, void *outputBuffer,
                           unsigned long framesPerBuffer,
                           const PaStreamCallbackTimeInfo* timeInfo,
                           PaStreamCallbackFlags statusFlags,
                           void *userData )
{
    paTestDataRC *data = (paTestDataRC*)userData;
    const SAMPLE *rptr = (const SAMPLE*)inputBuffer;
    SAMPLE *wptr = &data->recordedSamples[data->frameIndex * NUM_CHANNELS];
    long framesToCalc;
    long i;
    int finished;
    unsigned long framesLeft = data->maxFrameIndex - data->frameIndex;

    (void) outputBuffer; /* Prevent unused variable warnings. */
    (void) timeInfo;
    (void) statusFlags;
    (void) userData;

    dprintf( marker_fd, "PACallback p:0 c:1 fpb:%lu cfleft:%lu cdmaxfi:%d cdfi:%d pbsc:%d ppi:%d\n" , framesPerBuffer, framesLeft, data->maxFrameIndex, data->frameIndex, -1, -1);

    if( framesLeft < framesPerBuffer )
    {
        framesToCalc = framesLeft;
        finished = paComplete;
    }
    else
    {
        framesToCalc = framesPerBuffer;
        finished = paContinue;
    }

    if( inputBuffer == NULL )
    {
        for( i=0; i<framesToCalc; i++ )
        {
            *wptr++ = SAMPLE_SILENCE;  /* left */
            if( NUM_CHANNELS == 2 ) *wptr++ = SAMPLE_SILENCE;  /* right */
        }
    }
    else
    {
        for( i=0; i<framesToCalc; i++ )
        {
            *wptr++ = *rptr++;  /* left */
            if( NUM_CHANNELS == 2 ) *wptr++ = *rptr++;  /* right */
        }
    }
    data->frameIndex += framesToCalc;
    return finished;
}

/* patest_record.c
** This routine will be called by the PortAudio engine when audio is needed.
** It may be called at interrupt level on some machines so don't do anything
** that could mess up the system like calling malloc() or free().
*/
static int playCallback( const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData )
{
    paTestDataRC *data = (paTestDataRC*)userData;
    SAMPLE *rptr = &data->recordedSamples[data->frameIndex * NUM_CHANNELS];
    SAMPLE *wptr = (SAMPLE*)outputBuffer;
    unsigned int i;
    int finished;
    unsigned int framesLeft = data->maxFrameIndex - data->frameIndex;

    (void) inputBuffer; /* Prevent unused variable warnings. */
    (void) timeInfo;
    (void) statusFlags;
    (void) userData;

    if( framesLeft < framesPerBuffer )
    {
        /* final buffer... */
        for( i=0; i<framesLeft; i++ )
        {
            *wptr++ = *rptr++;  /* left */
            if( NUM_CHANNELS == 2 ) *wptr++ = *rptr++;  /* right */
        }
        for( ; i<framesPerBuffer; i++ )
        {
            *wptr++ = 0;  /* left */
            if( NUM_CHANNELS == 2 ) *wptr++ = 0;  /* right */
        }
        data->frameIndex += framesLeft;
        finished = paComplete;
    }
    else
    {
        for( i=0; i<framesPerBuffer; i++ )
        {
            *wptr++ = *rptr++;  /* left */
            if( NUM_CHANNELS == 2 ) *wptr++ = *rptr++;  /* right */
        }
        data->frameIndex += framesPerBuffer;
        finished = paContinue;
    }
    return finished;
}

/* patest_wmme_ac3.c (playback)
** This routine will be called by the PortAudio engine when audio is needed.
** It may called at interrupt level on some machines so don't do anything
** that could mess up the system like calling malloc() or free().
* NB: it will loop if made to run above file length (due capture length spec.)
*/
static int patestCallback( const void *inputBuffer, void *outputBuffer,
                            unsigned long framesPerBuffer,
                            const PaStreamCallbackTimeInfo* timeInfo,
                            PaStreamCallbackFlags statusFlags,
                            void *userData )
{
    paTestDataPY *data = (paTestDataPY*)userData;
    short *out = (short*)outputBuffer;
    unsigned long i,j;

    (void) timeInfo; /* Prevent unused variable warnings. */
    (void) statusFlags;
    (void) inputBuffer;

    dprintf( marker_fd, "PACallback p:1 c:0 fpb:%lu cfleft:%d cdmaxfi:%d cdfi:%d pbsc:%d ppi:%d\n" , framesPerBuffer, -1, -1, -1, data->bufferSampleCount, data->playbackIndexSamples);

    /* stream out contents of data->buffer looping at end */

    for( i=0; i<framesPerBuffer; i++ )
    {
        for( j = 0; j < NUM_CHANNELS; ++j ){
            *out++ = data->buffer[ data->playbackIndexSamples++ ];

            if( data->playbackIndexSamples >= data->bufferSampleCount )
                data->playbackIndexSamples = 0; /* loop at end of buffer */
        }
    }

    return paContinue;
}


/* patest_wire.c
** This routine will be called by the PortAudio engine when audio is needed.
** It may be called at interrupt level on some machines so don't do anything
** that could mess up the system like calling malloc() or free().
*/

static int wireCallback( const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData )
{
    INPUT_SAMPLE *in;
    OUTPUT_SAMPLE *out;
    int inStride;
    int outStride;
    int inDone = 0;
    int outDone = 0;
    //~ WireConfig_t *config = (WireConfig_t *) userData;
    paTestDataDX *dxdata = (paTestDataDX *) userData;
    WireConfig_t *config = dxdata->wc;
    paTestDataPY *pdata = dxdata->py;
    paTestDataRC *rdata = dxdata->rc;
    unsigned int i;
    int inChannel, outChannel;
    const SAMPLE *rptr = (const SAMPLE*)inputBuffer;
    SAMPLE *wptr = &rdata->recordedSamples[rdata->frameIndex * NUM_CHANNELS];
    unsigned long rframesLeft = rdata->maxFrameIndex - rdata->frameIndex;


    /* This may get called with NULL inputBuffer during initial setup. */
    if( inputBuffer == NULL) return 0;

    inChannel=0, outChannel=0;
    while( !(inDone && outDone) )
    {
        if( config->isInputInterleaved )
        {
            in = ((INPUT_SAMPLE*)inputBuffer) + inChannel;
            inStride = config->numInputChannels;
        }
        else
        {
            in = ((INPUT_SAMPLE**)inputBuffer)[inChannel];
            inStride = 1;
        }

        if( config->isOutputInterleaved )
        {
            out = ((OUTPUT_SAMPLE*)outputBuffer) + outChannel;
            outStride = config->numOutputChannels;
        }
        else
        {
            out = ((OUTPUT_SAMPLE**)outputBuffer)[outChannel];
            outStride = 1;
        }

        for( i=0; i<framesPerBuffer; i++ )
        {
            *out = *in ; //CONVERT_IN_TO_OUT( *in );
            out += outStride;
            in += inStride;
        }

        if(inChannel < (config->numInputChannels - 1)) inChannel++;
        else inDone = 1;
        if(outChannel < (config->numOutputChannels - 1)) outChannel++;
        else outDone = 1;
    }
    return 0;
}

static int wireCallback2( const void *inputBuffer, void *outputBuffer,
                         unsigned long framesPerBuffer,
                         const PaStreamCallbackTimeInfo* timeInfo,
                         PaStreamCallbackFlags statusFlags,
                         void *userData )
{
    paTestDataDX *dxdata = (paTestDataDX *) userData;
    WireConfig_t *config = dxdata->wc;
    paTestDataPY *pdata = dxdata->py;
    paTestDataRC *rdata = dxdata->rc;

    short *out = (short*)outputBuffer;
    unsigned long i,j;

    //~ paTestDataRC *data = (paTestDataRC*)userData;
    const SAMPLE *rrptr = (const SAMPLE*)inputBuffer;
    SAMPLE *rwptr = &rdata->recordedSamples[rdata->frameIndex * NUM_CHANNELS];
    long rframesToCalc;
    int rfinished;
    unsigned long rframesLeft = rdata->maxFrameIndex - rdata->frameIndex;

    dprintf( marker_fd, "PACallback p:1 c:1 fpb:%lu cfleft:%lu cdmaxfi:%d cdfi:%d pbsc:%d ppi:%d\n" , framesPerBuffer, rframesLeft, rdata->maxFrameIndex, rdata->frameIndex, pdata->bufferSampleCount, pdata->playbackIndexSamples);

    // playback
    /* stream out contents of data->buffer looping at end */
  if (!(wire_callback_interleaved)) { // #if !(WIRE_CALLBACK_INTERLEAVED)
    for( i=0; i<framesPerBuffer; i++ )
    {
        for( j = 0; j < NUM_CHANNELS; ++j ){
            *out++ = pdata->buffer[ pdata->playbackIndexSamples++ ];

            if( pdata->playbackIndexSamples >= pdata->bufferSampleCount )
                pdata->playbackIndexSamples = 0; //* loop at end of buffer * /
        }
    }
  } // #endif

    // capture
    if( rframesLeft < framesPerBuffer )
    {
        rframesToCalc = rframesLeft;
        rfinished = paComplete;
    }
    else
    {
        rframesToCalc = framesPerBuffer;
        rfinished = paContinue;
    }

    if( inputBuffer == NULL )
    {
        for( i=0; i<rframesToCalc; i++ )
        {
            *rwptr++ = SAMPLE_SILENCE;  /* left */
            if( NUM_CHANNELS == 2 ) *rwptr++ = SAMPLE_SILENCE;  /* right */

          if (wire_callback_interleaved) { //#if WIRE_CALLBACK_INTERLEAVED
            for( j = 0; j < NUM_CHANNELS; ++j ){
                *out++ = pdata->buffer[ pdata->playbackIndexSamples++ ];

                if( pdata->playbackIndexSamples >= pdata->bufferSampleCount )
                    pdata->playbackIndexSamples = 0; //* loop at end of buffer * /
            }
          } //#endif
        }
    }
    else
    {
        for( i=0; i<rframesToCalc; i++ )
        {
            *rwptr++ = *rrptr++;  /* left */
            if( NUM_CHANNELS == 2 ) *rwptr++ = *rrptr++;  /* right */

          if (wire_callback_interleaved) { //#if WIRE_CALLBACK_INTERLEAVED
            for( j = 0; j < NUM_CHANNELS; ++j ){
                *out++ = pdata->buffer[ pdata->playbackIndexSamples++ ];

                if( pdata->playbackIndexSamples >= pdata->bufferSampleCount )
                    pdata->playbackIndexSamples = 0; //* loop at end of buffer * /
            }
          } //#endif
        }
    }
    rdata->frameIndex += rframesToCalc;
    return rfinished;

}

// modded/copied from latency.c
void showstat(snd_pcm_t *handle)//, size_t frames)
{
  int err;
  snd_pcm_status_t *status;

  snd_pcm_status_alloca(&status);
  if ((err = snd_pcm_status(handle, status)) < 0) {
    printf("Stream status error: %s\n", snd_strerror(err));
    exit(0);
  }
  //~ printf("*** frames = %li ***\n", (long)frames);
  snd_pcm_status_dump(status, dumpoutput);
}

/*
// PaAlsaStreamComponent *component = NULL;
// PaAlsaStream *stream = (PaAlsaStream*)s; PaStream* s
// component = &stream->capture; // playback ;
NOTE: here I'm getting the playback struct *shifted* in memory:

(gdb) p &((PaAlsaStream*)pstream)->playback
$1 = (PaAlsaStreamComponent *) 0x808a548

(gdb) p *(PaAlsaStreamComponent *) 0x808a548
$5 = {hostSampleFormat = 0, framesPerBuffer = 8, numUserChannels = 256, numHostChannels = 2, userInterleaved = 2,
  hostInterleaved = 1, canMmap = 1, nonMmapBuffer = 0x1, nonMmapBufferSize = 0, device = 0, pcm = 0x0,
  bufferSize = 134781048, nativeFormat = 512, nfds = 2, ready = 1, userBuffers = 0x0, offset = 0,
  streamDir = StreamDirection_In, channelAreas = 0x1}

(gdb) p *(PaAlsaStreamComponent *) (0x808a548+0x4)
$9 = {hostSampleFormat = 8, framesPerBuffer = 256, numUserChannels = 2, numHostChannels = 2, userInterleaved = 1,
  hostInterleaved = 1, canMmap = 1, nonMmapBuffer = 0x0, nonMmapBufferSize = 0, device = 0, pcm = 0x8089878,
  bufferSize = 512, nativeFormat = SND_PCM_FORMAT_S16_LE, nfds = 1, ready = 0, userBuffers = 0x0, offset = 0,
  streamDir = StreamDirection_Out, channelAreas = 0x0}

... probably happens because of double struct declaration ? (both here and
in pa_linux_alsa.c?? anyways - go through address, and make a check based
on numUserChannels - and adjust if necessarry
(seems to work for both separate playrec callbacks; and for single wire callback!)
*/
void showALSAstat(PaStream* s)
{
  PaAlsaStream *stream = (PaAlsaStream*)s;
  int caddr = (int) &(stream->capture);
  int paddr = (int) &(stream->playback);
  PaAlsaStreamComponent *ccomponent = (PaAlsaStreamComponent *) caddr;
  PaAlsaStreamComponent *pcomponent = (PaAlsaStreamComponent *) paddr;
  printf("showALSAstat: cnc %d, pnc %d ; ", ccomponent->numUserChannels, pcomponent->numUserChannels);
  printf("capture %08x/%p, playback %08x/%p ; ", caddr, ccomponent->pcm, paddr, pcomponent->pcm);
  if ((pcomponent->numUserChannels > 0) && (pcomponent->numUserChannels != NUM_CHANNELS)) {
    // adjust address [[ by 4 = sizeof (PaSampleFormat hostSampleFormat;) = int? ]]
    paddr += sizeof(PaSampleFormat);
    pcomponent = (PaAlsaStreamComponent *) paddr;
    printf("II: capture %08x/%p, playback %08x/%p ; ", caddr, ccomponent->pcm, paddr, pcomponent->pcm);
  }
  printf("\n");
  if (ccomponent->pcm) { printf("capture:  "); showstat(ccomponent->pcm); }
  if (pcomponent->pcm) { printf("playback: "); showstat(pcomponent->pcm); }
}
void showALSAdump(PaStream* s)
{
  PaAlsaStream *stream = (PaAlsaStream*)s;
  int caddr = (int) &(stream->capture);
  int paddr = (int) &(stream->playback);
  PaAlsaStreamComponent *ccomponent = (PaAlsaStreamComponent *) caddr;
  PaAlsaStreamComponent *pcomponent = (PaAlsaStreamComponent *) paddr;
  printf("showALSAdump: cnc %d, pnc %d ; ", ccomponent->numUserChannels, pcomponent->numUserChannels);
  printf("capture %08x/%p, playback %08x/%p ; ", caddr, ccomponent->pcm, paddr, pcomponent->pcm);
  if ((pcomponent->numUserChannels > 0) && (pcomponent->numUserChannels != NUM_CHANNELS)) {
    // adjust address [[ by 4 = sizeof (PaSampleFormat hostSampleFormat;) = int? ]]
    paddr += sizeof(PaSampleFormat);
    pcomponent = (PaAlsaStreamComponent *) paddr;
    printf("II: capture %08x/%p, playback %08x/%p ; ", caddr, ccomponent->pcm, paddr, pcomponent->pcm);
  }
  printf("\n");
  //~ printf("showALSAdump: capture %p, playback %p\n", stream->capture.pcm, stream->playback.pcm);
  //~ if (stream->capture.pcm) snd_pcm_dump(stream->capture.pcm, dumpoutput);
  //~ if (stream->playback.pcm) snd_pcm_dump(stream->playback.pcm, dumpoutput);
  if (ccomponent->pcm) snd_pcm_dump(ccomponent->pcm, dumpoutput);
  if (pcomponent->pcm) snd_pcm_dump(pcomponent->pcm, dumpoutput);
}

/*******************************************************************/
int main( int argc, char* argv[] );
int main( int argc, char* argv[] )
{
    PaError err = paNoError;
    WireConfig_t CONFIG;
    WireConfig_t *config = &CONFIG;
    int configIndex = 0;;

    PaStreamParameters  inputParameters,
                        outputParameters;
    PaStream*           rstream;
    paTestDataRC        rdata;
    int                 i;
    int                 totalFrames;
    int                 numSamples;
    int                 numBytes;
    SAMPLE              max, val;
    double              average;
    const char *rfileName = RECFILE;

    FILE *fp;
    const char *pfileName = PLAYFILE;
    paTestDataPY pdata;
    pdata.buffer = NULL;
    PaStream *pstream;
    PaTime starttime, now, dt;
    PaTime tpad = 0.0; // timepad: allow for a bit more leeway when detecting forced exit (may take up to 0.5 sec more to exit proper captures)? or not - then it will explicitly come out always - so capture ok if recorded frames == demanded frames; now settable as command line option
    int w_err; // error status for the ftrace writes

    while (1) {
      int c;
      if ((c = getopt_long(argc, argv, "c:w:b:s:f:i:o:m:p:", long_option, NULL)) < 0)
        break;
      switch (c) {
      case 'c':
        use_playrec_callbacks = atoi(optarg);
        break;
      case 'w':
        wire_callback_interleaved = atoi(optarg);
        break;
      case 'b':
        frames_per_buffer = atoi(optarg);
        break;
      case 's':
        num_seconds = atof(optarg);
        break;
      case 'f':
        num_frames = atoi(optarg);
        break;
      case 'i':
        input_device = atoi(optarg);
        break;
      case 'o':
        output_device = atoi(optarg);
        break;
      case 'm':
        msleep = atoi(optarg);
        break;
      case 'p': // timepad
        tpad = atof(optarg);
        break;
        //~ pdevice = strdup(optarg);
      }
    }
    err = snd_output_stdio_attach(&dumpoutput, stdout, 0);
    if (err < 0) {
      printf("Output failed: %s\n", snd_strerror(err));
      return 0;
    }
    printf("patest_duplex_wire.c (args)\n");
    printf(":: use playrec callbacks: %d (%s); wire callback interleaved: %d (%s); msleep %d \n",
      use_playrec_callbacks, (use_playrec_callbacks) ? "true:playrec" : "false:wire",
      wire_callback_interleaved, (wire_callback_interleaved) ? "true" : "false",
      msleep
    );
    marker_fd = open(markpath, O_WRONLY); //added
    trace_fd  = open(tracpath, O_WRONLY); //added
    printf("  opening /sys/kernel/debug/tracing/: trace_marker %s, tracing_on %s\n", (marker_fd < 0) ? "failed" : "OK", (trace_fd < 0) ? "failed" : "OK");

    if (num_frames == 0) {  // num_frames unset - set num_frames according to num_seconds
      num_frames = (int)(num_seconds * SAMPLE_RATE);
    } else {                // if num_frames set, set num_seconds according to num_frames
      num_seconds = num_frames*1.0f / SAMPLE_RATE;
    }
    printf("Test duration: %f seconds (%d frames).\n", num_seconds, num_frames);
    printf("Recording to: %s ...", RECFILE);
    rdata.maxFrameIndex = totalFrames = num_frames; /* Record for a few seconds. */
    rdata.frameIndex = 0;
    numSamples = totalFrames * NUM_CHANNELS;
    numBytes = numSamples * sizeof(SAMPLE);
    rdata.recordedSamples = (SAMPLE *) malloc( numBytes ); /* From now on, recordedSamples is initialised. */
    if( rdata.recordedSamples == NULL )
    {
        printf("Could not allocate record array.\n");
        goto done;
    }
    printf("allocated %d bytes (%d samples = %d frames) for recording.\n", numBytes, numSamples, totalFrames);
    for( i=0; i<numSamples; i++ ) rdata.recordedSamples[i] = 0;

    printf("Playing from: %s ; opening ... ", pfileName);
    // from ./patest_wmme_ac3.c
    fp = fopen( pfileName, "rb" );
    if( !fp ){
        fprintf( stderr, "error opening raw file %s.\n", pfileName );
        return -1;
    }
    /* get file size */
    fseek( fp, 0, SEEK_END );
    // NOTE: this is bufferSampleCount (total samples) - NOT framecount (total frames!)
    // framecount would be bufferSampleCount/NUM_CHANNELS!
    pdata.bufferSampleCount = ftell( fp ) / sizeof(OUTPUT_SAMPLE);
    fseek( fp, 0, SEEK_SET );
    pdata.bufferFrameCount = pdata.bufferSampleCount/NUM_CHANNELS;
    printf("got %d bytes ... ", pdata.bufferSampleCount*sizeof(OUTPUT_SAMPLE) );
    /* allocate buffer, read the whole file into memory */
    pdata.buffer = (short*)malloc( pdata.bufferSampleCount * sizeof(OUTPUT_SAMPLE) );
    if( !pdata.buffer ){
        fprintf( stderr, "error allocating buffer.\n" );
        return -1;
    }
    if ( !fread( pdata.buffer, sizeof(OUTPUT_SAMPLE), pdata.bufferSampleCount, fp ) ) {
        fprintf( stderr, "error allocating buffer.\n" );
        return -1;
    }
    fclose( fp );
    pdata.playbackIndexSamples = 0;
    printf("allocated %d bytes (%d samples = %d frames) for playback.\n", pdata.bufferSampleCount * sizeof(OUTPUT_SAMPLE), pdata.bufferSampleCount, pdata.bufferFrameCount);


    err = Pa_Initialize();
    if( err != paNoError ) goto error;

    printf("input format = %lu (%s)\n", INPUT_FORMAT, (INPUT_FORMAT == paInt16) ? "paInt16" : "" );
    printf("output format = %lu (%s)\n", OUTPUT_FORMAT, (OUTPUT_FORMAT == paInt16) ? "paInt16" : "" );
    printf("input device ID  = %d (%s)\n", input_device, Pa_GetDeviceInfo(input_device)->name );
    printf("output device ID = %d (%s)\n", output_device, Pa_GetDeviceInfo(output_device)->name );

    config->isInputInterleaved = 1;
    config->isOutputInterleaved = 1;
    config->numInputChannels = NUM_CHANNELS;
    config->numOutputChannels = NUM_CHANNELS;
    config->framesPerCallback = frames_per_buffer;

    err = SetConfiguration( config , &inputParameters, &outputParameters);
    if( err != paNoError ) goto error;
    printf("  Doublecheck: outputParameters.channelCount %d \n", outputParameters.channelCount);

if (use_playrec_callbacks) { // #if USE_PLAYREC_CALLBACKS

    err = Pa_OpenStream(
              &rstream,
              &inputParameters,
              NULL,                  /* &outputParameters, */
              SAMPLE_RATE,
              config->framesPerCallback,
              paClipOff,      /* we won't output out of range samples so don't bother clipping them */
              recordCallback,
              &rdata );
    if( err != paNoError ) goto error;

    showALSAdump( rstream );
    w_err = write(trace_fd, "1", 1); // enable ftrace logging; err= to prevent warn_unused_result
    err = Pa_StartStream( rstream );
    if( err != paNoError ) goto error;
    printf("\n=== Recording started. ===\n"); fflush(stdout);

    err = Pa_OpenStream(
              &pstream,
              NULL, /* no input */
              &outputParameters,
              SAMPLE_RATE,
              config->framesPerCallback,
              0,
              patestCallback,
              &pdata );
    if( err != paNoError ) goto error;

    showALSAdump( pstream );
    err = Pa_StartStream( pstream );
    if( err != paNoError ) goto error;
    printf("\n=== Playback started. ===\n"); fflush(stdout);

    starttime = PaUtil_GetTime();
    while( ( err = Pa_IsStreamActive( rstream ) ) == 1 )
    {
        Pa_Sleep(msleep);
        now = PaUtil_GetTime();
        printf("play index = %.f ; rec/capt index = %d [frames]\n", 1.0*pdata.playbackIndexSamples/NUM_CHANNELS, rdata.frameIndex );
        if ( (dt = now-starttime) > num_seconds+tpad) {
          printf("NOTE: elapsed time %f more than duration %f; forcing break!\n", dt, num_seconds);
          break;
        }
    }
    w_err = write(trace_fd, "0", 1); // disable ftrace logging; err= to prevent warn_unused_result
    printf("\n");
    showALSAstat(rstream);
    showALSAstat(pstream);
    if( err < 0 ) goto error;

    err = Pa_CloseStream( pstream );
    if( err != paNoError ) goto error;
    err = Pa_CloseStream( rstream );
    if( err != paNoError ) goto error;

} else // #else

  {
    paTestDataDX dxdata;
    PaStream*           dstream;
    dxdata.rc = &rdata;
    dxdata.py = &pdata;
    dxdata.wc = config;

    err = Pa_OpenStream(
              &dstream,
              &inputParameters,
              &outputParameters,
              SAMPLE_RATE,
              config->framesPerCallback, /* frames per buffer */
              0, //paNeverDropInput, /* paNeverDropInput works only with paFramesPerBufferUnspecified; however may segfault */
              wireCallback2,
              &dxdata );
    if( err != paNoError ) goto error;

    showALSAdump( dstream );
    w_err = write(trace_fd, "1", 1); // enable ftrace logging; err= to prevent warn_unused_result
    err = Pa_StartStream( dstream );
    if( err != paNoError ) goto error;

    starttime = PaUtil_GetTime();
    while( ( err = Pa_IsStreamActive( dstream ) ) == 1 )
    {
        Pa_Sleep(msleep);
        now = PaUtil_GetTime();
        printf("play index = %.f ; rec/capt index = %d [frames]\n", 1.0*pdata.playbackIndexSamples/NUM_CHANNELS, rdata.frameIndex );
        if ( (dt = now-starttime) > num_seconds+tpad) {
          printf("NOTE: elapsed time %f more than duration %f; forcing break!\n", dt, num_seconds);
          break;
        }
    }
    w_err = write(trace_fd, "0", 1); // disable ftrace logging; err= to prevent warn_unused_result
    printf("\n");
    showALSAstat(dstream);
    if( err < 0 ) goto error;

    err = Pa_CloseStream( dstream );
    if( err != paNoError ) goto error;
  }
// #endif

  printf("\nAt end: play index = %.f ; rec/capt index = %d [frames] duration %f [s]\n", 1.0*pdata.playbackIndexSamples/NUM_CHANNELS, rdata.frameIndex, dt ); fflush(stdout);

    /* Write recorded data to a file. */
    {
        FILE  *fid;
        fid = fopen(rfileName, "wb");
        if( fid == NULL )
        {
            printf("Could not open file %s for saving capture.\n", rfileName);
        }
        else
        {
            fwrite( rdata.recordedSamples, NUM_CHANNELS * sizeof(SAMPLE), totalFrames, fid );
            fclose( fid );
            printf("Wrote data to '%s'\n", rfileName);
        }
    }
    printf("\n=== Wrote capture to file %s. ===\n", rfileName); fflush(stdout);

done:
    Pa_Terminate();
    if( rdata.recordedSamples )       /* Sure it is NULL or valid. */
        free( rdata.recordedSamples );
    if( pdata.buffer )
        free( pdata.buffer );
    close(marker_fd); //added
    close(trace_fd); //added
    printf("Full duplex sound test complete.\n"); fflush(stdout);
    //~ printf("Hit ENTER to quit.\n");  fflush(stdout);
    //~ getchar();
    return 0;

error:
    Pa_Terminate();
    if( rdata.recordedSamples )       /* Sure it is NULL or valid. */
        free( rdata.recordedSamples );
    if( pdata.buffer )
        free( pdata.buffer );
    close(marker_fd); //added
    close(trace_fd); //added
    fprintf( stderr, "An error occured while using the portaudio stream\n" );
    fprintf( stderr, "Error number: %d\n", err );
    fprintf( stderr, "Error message: %s\n", Pa_GetErrorText( err ) );
    printf("Hit ENTER to quit.\n");  fflush(stdout);
    getchar();
    return -1;
}

static PaError SetConfiguration( WireConfig_t *config , PaStreamParameters *inputParameters, PaStreamParameters *outputParameters )
{
    int c;
    PaError err = paNoError;
    PaStream *stream;
    //~ PaStreamParameters inputParameters, outputParameters;

    printf("input %sinterleaved!\n", (config->isInputInterleaved ? " " : "NOT ") );
    printf("output %sinterleaved!\n", (config->isOutputInterleaved ? " " : "NOT ") );
    printf("input channels = %d\n", config->numInputChannels );
    printf("output channels = %d\n", config->numOutputChannels );
    printf("framesPerCallback = %d\n", config->framesPerCallback );

    inputParameters->device = input_device;              /* default input device */
    if (inputParameters->device == paNoDevice) {
        fprintf(stderr,"Error: No default input device.\n");
        goto error;
    }
    inputParameters->channelCount = config->numInputChannels;
    inputParameters->sampleFormat = INPUT_FORMAT | (config->isInputInterleaved ? 0 : paNonInterleaved);
    inputParameters->suggestedLatency = Pa_GetDeviceInfo( inputParameters->device )->defaultLowInputLatency;
    inputParameters->hostApiSpecificStreamInfo = NULL;

    outputParameters->device = output_device;            /* default output device */
    if (outputParameters->device == paNoDevice) {
        fprintf(stderr,"Error: No default output device.\n");
        goto error;
    }
    outputParameters->channelCount = config->numOutputChannels;
    outputParameters->sampleFormat = OUTPUT_FORMAT | (config->isOutputInterleaved ? 0 : paNonInterleaved);
    outputParameters->suggestedLatency = Pa_GetDeviceInfo( outputParameters->device )->defaultLowOutputLatency;
    outputParameters->hostApiSpecificStreamInfo = NULL;

    return paNoError;

error:
    return err;
}
