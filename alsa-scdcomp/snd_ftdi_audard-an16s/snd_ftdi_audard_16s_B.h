/*******************************************************************************
* snd_ftdi_audard_16s_B.h                                                      *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/
/*
 * snd_ftdi_audard_16s.h
 * Driver definitions for the Audio Arduino FTDI USB driver - sound/ALSA related
 * (based on http://www.alsa-project.org/main/index.php/Minivosc {dummy.c; aloop-kernel.c} )
 *
 * USB FTDI SIO driver - 'AudioArduino' modification (16s)
 * Copyright (C) 2013 by sdaau (sd@{imi,create}.aau.dk)
 * Copyright (C) 2010 by sdaau (sd@{imi,create}.aau.dk)
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 */

#undef dbg
#define dbg(format, arg...) do { } while (0)
//~ #define dbg(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)

#define dbg2(format, arg...) do { } while (0)
//~ #define dbg2(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)

#define dbg3(format, arg...) do { } while (0)
//~ #define dbg3(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)


// * from usbaudio.h: handling of USB
// * vendor/product ID pairs as 32-bit numbers
#define USB_ID(vendor, product) (((vendor) << 16) | (product))
#define USB_ID_VENDOR(id) ((id) >> 16)
#define USB_ID_PRODUCT(id) ((u16)(id))

// * copy from audard.c/aloop-kernel.c:
#include <linux/jiffies.h>
#include <linux/time.h>
// keeping the above - but moving to high-resolution timer:
#include <linux/hrtimer.h>
#include <linux/platform_device.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/pcm.h>
#include <sound/initval.h>
#include <sound/info.h> //for snd_card_proc_new
#include <linux/proc_fs.h> //for create_proc_read_entry; which is eliminated 11 Apr 2013 (use proc_create_data() and seq_file instead; see also LDD3)

// '((2) << 16) + ((6) << 8) + (38) == 132646 for 2,6,38
#include <linux/version.h> // for LINUX_VERSION_CODE; KERNEL_VERSION
//~ #define STRINGIFY(s) XSTRINGIFY(s)
//~ #define XSTRINGIFY(s) #s
//~ #pragma message "vers code " STRINGIFY(LINUX_VERSION_CODE) STRINGIFY(KERNEL_VERSION(2,6,38))


// * "Module parameters" writing.pdf:
// * There are standard module options for ALSA.
static int index[SNDRV_CARDS] = SNDRV_DEFAULT_IDX;	/* Index 0-MAX */
static char *id[SNDRV_CARDS] = SNDRV_DEFAULT_STR;	/* ID for this card */
static int enable[SNDRV_CARDS] = {1, [1 ... (SNDRV_CARDS - 1)] = 0};

// aloop.c + writing.pdf
module_param_array(index, int, NULL, 0444);
MODULE_PARM_DESC(index, "Index value for Audio Arduino 16s soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for Audio Arduino 16s soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this Audio Arduino 16s soundcard.");

MODULE_SUPPORTED_DEVICE("{{ALSA,Audio Arduino 16s soundcard}}");

// SO25771
const char *buildString = "This build XXXX was compiled at " __DATE__ ", " __TIME__ ".";

// ripped from dummy.c - for separate substreams:
#define MAX_PCM_DEVICES		4 	// we're not using this here - single device..
#define MAX_PCM_SUBSTREAMS	1 	// 16 // don't have 16 subdevices
								//~ .. ((!sub)streams) per device here,
								//~ .. only 1 (playback+capture).
#ifndef add_playback_constraints
#define add_playback_constraints(x) 0
#endif
#ifndef add_capture_constraints
#define add_capture_constraints(x) 0
#endif

static int pcm_substreams[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 1}; // 8}; // otherwise, 8 subdevices in aplay/arecord; although - it's reset in probe

// * here we must have some reference to the 'card':
static struct snd_card *thiscard;

//~ #define MAX_BUFFER (32 * 48) 	// from bencol
#define MAX_BUFFER (64*1024)  		// default dummy.c:

// so setting the driver default to SNDRV_PCM_FMTBIT_S16_LE

static struct snd_pcm_hardware audard_pcm_hw_playback =
{
	.info = ( SNDRV_PCM_INFO_MMAP |
	SNDRV_PCM_INFO_INTERLEAVED |
	SNDRV_PCM_INFO_BLOCK_TRANSFER |
	SNDRV_PCM_INFO_MMAP_VALID),
	.formats          = SNDRV_PCM_FMTBIT_S16_LE,
	.rates            = SNDRV_PCM_RATE_8000|SNDRV_PCM_RATE_44100,
	.rate_min         = 8000,
	.rate_max         = 44100,
	.channels_min     = 2, // 1,
	.channels_max     = 2,
	.buffer_bytes_max = MAX_BUFFER, //(64*1024) dummy.c, was (32 * 48) = 1536,
	.period_bytes_min = 64, //dummy.c, was 48, // then 64 for 8-bit mono
	.period_bytes_max = MAX_BUFFER, //was 48, coz dummy.c: #def MAX_PERIOD_SIZE 2048, // MAX_BUFFER
	.periods_min      = 2, // 1 or 2 in dummy.c
	.periods_max      = 1024, //dummy.c, was 32,
	.fifo_size =		0, // also in dummy.c
};

static struct snd_pcm_hardware audard_pcm_hw_capture =
{
	.info = ( SNDRV_PCM_INFO_MMAP |
	SNDRV_PCM_INFO_INTERLEAVED |
	SNDRV_PCM_INFO_BLOCK_TRANSFER |
	SNDRV_PCM_INFO_MMAP_VALID),
	.formats          = SNDRV_PCM_FMTBIT_S16_LE,
	.rates            = SNDRV_PCM_RATE_8000|SNDRV_PCM_RATE_44100,
	.rate_min         = 8000,
	.rate_max         = 44100,
	.channels_min     = 2, // 1,
	.channels_max     = 2,
	.buffer_bytes_max = MAX_BUFFER, //(64*1024) dummy.c, was (32 * 48) = 1536,
	.period_bytes_min = 64, //dummy.c, was 48, // then 64 for 8-bit mono
	.period_bytes_max = MAX_BUFFER, //was 48, coz dummy.c: #def MAX_PERIOD_SIZE 2048, // MAX_BUFFER
	.periods_min      = 2, // 1 or 2 in dummy.c
	.periods_max      = 1024, //dummy.c, was 32,
	.fifo_size =		0, // also in dummy.c
};

/* _FRQUANT is frames quantization; simulates increase of pointer by the given quant*/
#define _FRQUANT 8
/* IMRX_BEHAVIOR: 0 - realloc, 1 - circular buffer */
#define IMRX_BEHAVIOR 1


// added - struct for intermediate RX (ring) buffer:
struct ringbuf {
	char *buf;
	// specify 32-bit integers instead of just 'int'
	int32_t size;
	int32_t head;
	int32_t tail;
	uint32_t tlRecv; // total received bytes from USB since last prepare (follows tail)
	uint32_t hdWsnd; // total bytes written to ALSA pcm since last prepare (follows head)
	char *wrapbuf;	// to store remaining bytes when wrapping pcm_buffer/dma_area..
	uint32_t wrapbtw; 	// wrap bytes to write - flag; either 0, or ammount of wrap bytes in wrapbuf
	int32_t cpwrem; // (capture) period wrap remaining bytes
  int32_t cprebuffer; // prebuffer capture - counts of period_bytes
};

struct snd_audard_pcm; // declare this here..
struct audard_device
{
	struct snd_card *card;
	struct snd_pcm *pcm; 						// snd_pcm will describe the
												//~ .. only 'device' in this driver
	struct snd_audard_pcm *playcaptstreams[2]; 	// ref to the playback and
												//~ .. capture streams, related
												//~ .. to the single pcm 'device'
	struct ftdi_private *ftdipr; 				// pointer back
	unsigned char isSerportOpen;
	/* mixer related variables - not used here: */
	//~ spinlock_t mixer_lock;
	//~ int mixer_volume[MIXER_ADDR_LAST+1][2];
	//~ int capture_source[MIXER_ADDR_LAST+1][2];
	struct mutex cable_lock; 					// mutex here - just in case
	struct ringbuf IMRX; 						//intermediate RX buffer...
	char* IMPLY; // debug playback
  // for 8-bit mono; tempbuf8b was used
  // to store 'cast' int16_t from audacity to 8-bit
  // for 16-bit stereo, it doesn't have that role anymore
  //  however, the name is still kept as for 8-bit;
  // we still keep the tempbuf, in order to do correct
  // byte wrapping at frame boundaries (for 16s, 4 bytes)
	char* tempbuf8b; 							// to store 'cast' int16_t from audacity to 8-bit
	char tempbuf8b_extra;						// counter - if we have 1,2 or 3 extra (overflow)
												//   bytes from the stereo, 16-bit dma_area
												//   remaining from the last period (so char
												//   range:-128:127 should be enough)
	char tempbuf8b_extra_prev;					// previous val of _extra: needed to handle specific period wrapping cases
	char* tempbuf8b_frame;						// if _extra > 0, then a frame has been cut;
												//   we will save the pieces in _frame; once
												//   _frame is complete, we can represent it with
												//   a byte in tempbuf8b ..
	unsigned int playawbprd;	// actually written playback bytes; needed to compare with buf_pos; not anymore - now it is total playback bytes written (for debugging)
								//   in case we're missing a frame for CD playback
	// * flags * /
	unsigned int valid;							// (not used)
	unsigned int running;
	unsigned int period_update_pending :1;		// (not used)
	/* from snd_usb_audio struct: */
	u32 usb_id;
  // added here to handle pcm_buffer wrap:
  int BwrapBytesRemain;
  // now that this is here; better to
  // declare it a pointer and kzalloc it:
  char *brokenEndFrame; //brokenEndFrame[4]; // = "";
};

// * here declaration of functions that will need to be in _ops, before they are defined
static int snd_card_audard_pcm_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params);
static int snd_card_audard_pcm_hw_free(struct snd_pcm_substream *ss);

//~ static int audard_pcm_open(struct snd_pcm_substream *ss);
static int snd_card_audard_pcm_playback_open(struct snd_pcm_substream *ss);
static int snd_card_audard_pcm_capture_open(struct snd_pcm_substream *ss);

static int snd_card_audard_pcm_playback_close(
							struct snd_pcm_substream *substream);
static int snd_card_audard_pcm_capture_close(
							struct snd_pcm_substream *substream);

static int snd_card_audard_pcm_dev_free(struct snd_device *device);
static int snd_card_audard_pcm_free(struct audard_device *chip);

// * don't really have to declare these, but here they are:
static int audard_probe(struct usb_serial *serial);
static void audard_remove(void);


// * timer/interrupt functions - _xfer_buf is called from the ftdi_sio-audard.c
static void audard_xfer_buf(struct audard_device *mydev, char *inch, unsigned int count);
static void audard_fill_capture_buf(struct audard_device *mydev, char *inch, unsigned int bytes);

// dummy.c funcs headers:
static int snd_card_audard_new_pcm(struct audard_device *mydev,
				int device, int substreams); // no __devinit here - "Section mismatch in reference from ... This is often because audard_probe lacks a __devinit"
static struct snd_audard_pcm *new_pcm_stream(struct snd_pcm_substream *substream);
static void snd_card_audard_runtime_free(struct snd_pcm_runtime *runtime);


static inline void snd_card_audard_pcm_timer_start(struct snd_audard_pcm *dpcm);
static inline void snd_card_audard_pcm_timer_stop(struct snd_audard_pcm *dpcm);
static int snd_card_audard_pcm_trigger(struct snd_pcm_substream *substream, int cmd);
static int snd_card_audard_pcm_prepare(struct snd_pcm_substream *substream);
//~ static void snd_card_audard_pcm_timer_function(unsigned long data);
static enum hrtimer_restart snd_card_audard_pcm_timer_function(struct hrtimer *timer);
static snd_pcm_uframes_t snd_card_audard_pcm_pointer(struct snd_pcm_substream *substream);
// just for debugging, own ioctl handler
// (via alsa-driver-git/sound/pci/korg1212/korg1212.c)
static int snd_card_audard_pcm_ioctl(struct snd_pcm_substream *substream, unsigned int cmd, void *arg);
static void snd_card_audard_pcm_hrtimer_tasklet(unsigned long priv);



static struct snd_pcm_ops audard_pcm_playback_ops =
{
	.open      = snd_card_audard_pcm_playback_open,
	.close     = snd_card_audard_pcm_playback_close, //audard_pcm_playback_close,
	.ioctl     = snd_card_audard_pcm_ioctl, //snd_pcm_lib_ioctl,
	.hw_params = snd_card_audard_pcm_hw_params,
	.hw_free   = snd_card_audard_pcm_hw_free,
	.prepare   = snd_card_audard_pcm_prepare, //audard_pcm_prepare,
	.trigger   = snd_card_audard_pcm_trigger, //audard_pcm_trigger,
	.pointer   = snd_card_audard_pcm_pointer, //audard_pcm_pointer,
};

static struct snd_pcm_ops audard_pcm_capture_ops =
{
	.open      = snd_card_audard_pcm_capture_open,
	.close     = snd_card_audard_pcm_capture_close, //audard_pcm_capture_close,
	.ioctl     = snd_card_audard_pcm_ioctl, //snd_pcm_lib_ioctl,
	.hw_params = snd_card_audard_pcm_hw_params,
	.hw_free   = snd_card_audard_pcm_hw_free,
	.prepare   = snd_card_audard_pcm_prepare, //audard_pcm_prepare,
	.trigger   = snd_card_audard_pcm_trigger, //audard_pcm_trigger,
	.pointer   = snd_card_audard_pcm_pointer, //audard_pcm_pointer,
};


// * Main pcm struct

struct snd_audard_pcm {
	struct audard_device *mydev;
	spinlock_t lock;
	ktime_t base_time;
	ktime_t pcm_period_ns_kt;
	ktime_t ss_dly_time[2]; /* stream start delay: now an array, as there are two steps with differences from period */
	ktime_t timercb_time;
	atomic_t running;
	atomic_t startseen; /* flag - skip _elapsed if stream not yet seen in callback; also to manage different ss_dly_time */

  int frquant; /* frame quantization */
  atomic_t inTimer; /* flag (to inform .pointer if it's called from callback) */
	//~ struct timer_list timer;
	struct hrtimer timer_hr;
  struct tasklet_struct tasklet;
	unsigned int pcm_buffer_sizeB;
	unsigned int pcm_period_sizeB;
	unsigned int pcm_bpj;		/* bytes per 1 jiffies (or less - see below) */
	unsigned int pcm_bps;		/* bytes per second */
	unsigned int pcm_hz;		/* HZ */
	unsigned int pcm_irq_posB;	/* IRQ position - bytes */
	unsigned int pcm_buf_posB;	/* position in buffer - bytes */
	unsigned int pcm_buf_posF;	/* position in buffer - frames */
	unsigned int pcm_buf_totB;	/* total bytes through buffer (like buf_pos, but isn't wrapped)  debug counter */
	struct snd_pcm_substream *substream;
  unsigned int pcm_bpj_fact;/* bpj factor - if 4; we use bpj/4 for timer function loop (cannot use here: with low res timer we can do min. bpj bytes, so it must be 1; but left as example - unnecesarry with hrtimer) */
};


// * FUNCTIONS

static inline void snd_card_audard_pcm_timer_start(struct snd_audard_pcm *dpcm)
{
	dpcm->base_time = hrtimer_cb_get_time(&dpcm->timer_hr);
  // NB: moving base_time forward/ahead here
  // also re-adjust step two with step one
  //~ if (dpcm->substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
    //~ dpcm->base_time = ktime_sub(dpcm->base_time, ktime_sub(dpcm->pcm_period_ns_kt, ktime_add(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]) ));
  //~ dpcm->base_time = ktime_sub(dpcm->base_time, ktime_set(0, 150*1000ULL)); // additional for playback, as I'm short on frames in PortAudio poll?
  //~ } // end if SNDRV_PCM_STREAM_PLAYBACK
  if (dpcm->substream->stream == SNDRV_PCM_STREAM_CAPTURE) {
    dpcm->base_time = ktime_add(dpcm->base_time, ktime_sub(ktime_add(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]), dpcm->pcm_period_ns_kt ));
  }

  //~ trace_printk("(%d)\n", dpcm->substream->stream); //T11
	hrtimer_start(&dpcm->timer_hr, dpcm->ss_dly_time[0], HRTIMER_MODE_REL); // was dpcm->period_time; step one delay
	atomic_set(&dpcm->running, 1);
}

static inline void snd_card_audard_pcm_timer_stop(struct snd_audard_pcm *dpcm)
{
	atomic_set(&dpcm->running, 0);
	hrtimer_cancel(&dpcm->timer_hr);
}

// this for without debug:
static int snd_card_audard_pcm_ioctl(struct snd_pcm_substream *substream, unsigned int cmd, void *arg)
{
  return snd_pcm_lib_ioctl(substream, cmd, arg);
}


static int snd_card_audard_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
  /*
  * this section now made to resemble azx_pcm_trigger;
  * utilizing snd_pcm_group_for_each_entry (in case of
  * full-duplex snd_pcm_link)
  */
  struct snd_pcm_substream *s;
  int start, nsync = 0;
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;
	struct audard_device *mydev = dpcm->mydev;
	//~ struct ftdi_private *priv = mydev->ftdipr;
	struct usb_serial_port *usport = mydev->ftdipr->port;
	//~ unsigned long flags;
	//~ int result = 0;

	// either a playback or a capture substream could trigger here..
  // playback or capture direction..
  int dir_playcap = substream->stream;

	//~ int err = 0;
	char cmds[16]="          ";
	char ttystr[32]="          ";
	cmds[15]='\0';
	ttystr[31]='\0';

	// either a playback or a capture substream could trigger here..

	// do not use ftdi_open/close (call funcs that sleep) in _trigger (it is atomic)!
	// trying to move in hw_params/hw_free

  //~ printk("	%s::(%d) %s\n", __func__, dir_playcap, cmds); //dbg

	sprintf( &cmds[0], "%d", cmd );
	spin_lock(&dpcm->lock);
	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
	case SNDRV_PCM_TRIGGER_RESUME:
		sprintf( &cmds[0], "%d START", cmd);
		//~ snd_card_audard_pcm_timer_start(dpcm);
		mydev->running |= (1 << substream->stream); // set running bit @ playback (0) or capture (1) bit position
    start = 1;
		break;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		sprintf( &cmds[0], "%d STOP", cmd);
		mydev->running &= ~(1 << substream->stream); // clear running bit @ playback (0) or capture (1) bit position
		//~ snd_card_audard_pcm_timer_stop(dpcm);
    start = 0;
		break;
	default:
		return -EINVAL; //err = -EINVAL;
		break;
	}

	snd_pcm_group_for_each_entry(s, substream) {
    //~ printk("_for_each_entry1: s %p %d %p sub %p %d %p\n", s, s->stream, s->pcm->card, substream, substream->stream, substream->pcm->card);
		if (s->pcm->card != substream->pcm->card)
			continue;
		nsync++;
		snd_pcm_trigger_done(s, substream);
	}

	snd_pcm_group_for_each_entry(s, substream) {
    //~ printk("_for_each_entry2: s %p %d %p sub %p %d %p\n", s, s->stream, s->pcm->card, substream, substream->stream, substream->pcm->card);
		if (s->pcm->card != substream->pcm->card)
			continue;
		if (start) {
      snd_card_audard_pcm_timer_start(s->runtime->private_data); //(dpcm) here is only of this substream, not the iterated s!
		} else {
      snd_card_audard_pcm_timer_stop(s->runtime->private_data);
		}
	}

	spin_unlock(&dpcm->lock);

	//~ spin_lock_irqsave(&usport->lock, flags);
	// probably no need for spinlock - however usport->port.tty could be 0x0!
	if (usport->port.tty) {
		sprintf( &ttystr[0], "ttyindx %d, ttyname %s", usport->port.tty->index, usport->port.tty->name );
	} else {
		sprintf( &ttystr[0], "port.tty %p", usport->port.tty);
	}

	dbg("	%s:(%d) %s stop_th %ld -- portnum %d, %s", __func__, dir_playcap, cmds, runtime->stop_threshold, mydev->ftdipr->port->number, ttystr);
	//~ spin_unlock_irqrestore(&usport->lock, flags);

	return 0;
}


static int snd_card_audard_pcm_prepare(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;
	struct audard_device *mydev = dpcm->mydev; // just for tlRecv;hdWsnd; reset

	int bps;
	int bpj; // no float in kernel; "__floatsisf" undefined !!
	unsigned int period;
	unsigned int rate = runtime->rate;
	unsigned long nsecs100u = 100*1000ULL;
	unsigned long nsecs_step1 = nsecs100u;
	unsigned long nsecs16f = div_u64(16UL * 1000000000ULL + rate - 1, rate);
	unsigned long nsecs48f = div_u64(48UL * 1000000000ULL + rate - 1, rate);
	long sec;
	unsigned long nsecs;

  tasklet_kill(&dpcm->tasklet);

	bps = snd_pcm_format_width(runtime->format) * runtime->rate *
		runtime->channels / 8;

	if (bps <= 0)
		return -EINVAL;

  period = runtime->period_size;
	sec = period / rate;
	period %= rate;
	nsecs = div_u64(period * 1000000000ULL + rate - 1, rate);
	dpcm->pcm_period_ns_kt = ktime_set(sec, nsecs);

  // stream start delay: in two steps; and depending on period
  // taking first (ASAP) schedule to be 100 us;
  //~ dpcm->ss_dly_time[0] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      //~ ? ktime_set(0L, nsecs_step1) // capture step one, same regardless of (period <= 64)
                      //~ : (period <= 64) ? ktime_set(0L, nsecs_step1+nsecs16f) : ktime_set(0L, nsecs_step1); // playback step one
  //~ dpcm->ss_dly_time[1] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      //~ ? ktime_set(sec, nsecs) // capture step two, same regardless of (period <= 64)
                      //~ : (period <= 64) ? ktime_set(sec, nsecs) : ktime_set(sec, nsecs-nsecs48f); // playback step two
  dpcm->ss_dly_time[0] = ktime_set(0L, nsecs_step1);
  dpcm->ss_dly_time[1] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      ? ktime_set(sec, nsecs+nsecs48f) // capture step two, same regardless of (period <= 64)
                      : ktime_set(sec, nsecs) ; // playback step two

  // adjust step two with step one
  dpcm->ss_dly_time[1] = ktime_sub(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]);
  // mark stream as not yet "seen":
  atomic_set(&dpcm->startseen, 0);
  atomic_set(&dpcm->inTimer, 0);
  dpcm->frquant = _FRQUANT; // keep like this

  // leftovers:
  dpcm->pcm_bpj_fact = 1;
	bpj = (bps/HZ)/dpcm->pcm_bpj_fact; // this will be truncated as int(eger)
	dpcm->pcm_bpj = bpj;
	dpcm->pcm_bps = bps;
	dpcm->pcm_hz = dpcm->pcm_bpj_fact*HZ;

	dpcm->pcm_buffer_sizeB = snd_pcm_lib_buffer_bytes(substream);
	dpcm->pcm_period_sizeB = snd_pcm_lib_period_bytes(substream);
	dpcm->pcm_irq_posB = 0;
	dpcm->pcm_buf_posB = 0;
	dpcm->pcm_buf_posF = 0;
	dpcm->pcm_buf_totB = 0;



	// since wrapbuf needs not be bigger than pcm_buffer_size, ... moved down

  // cannot this - snd_pcm_sw_params_user is not in header
  // (and when copying it here, not much happens)
  //~ ret = snd_pcm_sw_params_user(substream, &swparams);
  //~ dbgp("  snd_pcm_sw_params_user ret:%d", ret );


	// tempbuf8b - realloc it (via free) - if playback
	if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
		int samplewidth = snd_pcm_format_width(substream->runtime->format);
		if ((samplewidth == 16) && (substream->runtime->channels == 2)) {
			if (mydev->tempbuf8b)
				kfree(mydev->tempbuf8b);
			// make sure there is one extra byte in tempbuf8b - for period wrap (isBufFramePreinc)!!
      // NB: this was for 8-bit mono; we wanted to represent each frame by a byte; so we used bytes_to_frames:
			//~ mydev->tempbuf8b = kzalloc(bytes_to_frames(substream->runtime, dpcm->pcm_bpj), GFP_KERNEL); //framesToWrite; bytesToWrite = dpcm->pcm_bpj
      // now for 16 bit stereo, we allocate the full ammount of bytes (as per stereo, 16bit frame):
			mydev->tempbuf8b = kzalloc(dpcm->pcm_period_sizeB, GFP_KERNEL); // was dpcm->pcm_bpj

			// same realloc for tempbuf8b_frame - it needs to be 4 bytes, i.e. 1 frame, in size
			if (mydev->tempbuf8b_frame)
				kfree(mydev->tempbuf8b_frame);
			mydev->tempbuf8b_frame = kzalloc(frames_to_bytes(substream->runtime, 1), GFP_KERNEL);
		}
		// also reset the overflow counter (for pcm_period_size) here:
		mydev->tempbuf8b_extra = 0;
		mydev->tempbuf8b_extra_prev = 0;
		mydev->playawbprd = 0;
    // also for pcm_buffer_size overflow wrap:
    //~ mydev->brokenEndFrame = "";
    mydev->BwrapBytesRemain = 0;
    memset(mydev->IMPLY, 0x00, MAX_BUFFER);
    if (mydev->brokenEndFrame)
      kfree(mydev->brokenEndFrame);
    mydev->brokenEndFrame = kzalloc(frames_to_bytes(substream->runtime, 1), GFP_KERNEL);
	}

  // wrap IMRX init for capture only
	if (substream->stream == SNDRV_PCM_STREAM_CAPTURE) {
    mydev->IMRX.tlRecv = 0;
    mydev->IMRX.hdWsnd = 0;
    // also, added:
    mydev->IMRX.head = 0;
    mydev->IMRX.tail = 0;
    mydev->IMRX.wrapbtw = 0;
    mydev->IMRX.cpwrem = 0;
    // added - prebuffer 2 periods
    mydev->IMRX.cprebuffer = 2;

    // since wrapbuf needs not be bigger than pcm_buffer_size, ... moved down
    // realloc it free (and finally kill it where IMRX.buf is killed)
    if (mydev->IMRX.wrapbuf)
      kfree(mydev->IMRX.wrapbuf);
    mydev->IMRX.wrapbuf = kzalloc(dpcm->pcm_buffer_sizeB, GFP_KERNEL);
    // clean up IMRX.buf as well
    memset(mydev->IMRX.buf, 0x00, MAX_BUFFER);
  }

	dbg("  >%s: ss:%d bps:%d bpj: %d, HZ: %d, buffer_size: %d, pcm_period_size: %d, dma_bytes %d, dma_samples %d, fmt|nch|rt %d|%d|%d", __func__, substream->stream, bps, bpj, dpcm->pcm_hz, dpcm->pcm_buffer_sizeB, dpcm->pcm_period_sizeB, runtime->dma_bytes, bytes_to_samples(runtime, runtime->dma_bytes), snd_pcm_format_width(runtime->format), runtime->channels, runtime->rate);
  dbg("  >start_th: %ld, stop_th: %ld, silence_th: %ld, silence_sz: %ld, boundary: %ld, sil_start: %ld, sil_fill: %ld \n", runtime->start_threshold, runtime->stop_threshold, runtime->silence_threshold, runtime->silence_size, runtime->boundary, runtime->silence_start, runtime->silence_filled );

	snd_pcm_format_set_silence(runtime->format, runtime->dma_area,
			bytes_to_samples(runtime, runtime->dma_bytes));

	if ((substream->stream == SNDRV_PCM_STREAM_CAPTURE) && (! mydev->IMRX.wrapbuf)) {
		dbg("	cannot alloc wrapbuf!");
		return 1;
  }

	return 0;
}


// NOTE: this function can be called EITHER by playback OR by capture!
//~ static void snd_card_audard_pcm_timer_function(unsigned long data)
static enum hrtimer_restart snd_card_audard_pcm_timer_function(struct hrtimer *timer)
{
	//~ struct snd_audard_pcm *dpcm = (struct snd_audard_pcm *)data;
	struct snd_audard_pcm *dpcm = container_of(timer, struct snd_audard_pcm, timer_hr);
	dpcm->timercb_time = ktime_get();
  //~ printk("%s (%d)\n", __func__, dpcm->substream->stream);
	if (!atomic_read(&dpcm->running))
		return HRTIMER_NORESTART;
  if (!atomic_read(&dpcm->startseen)) {
    atomic_set(&dpcm->startseen, 1);
    hrtimer_forward_now(timer, dpcm->ss_dly_time[1]); // step two delay
  } else {
    tasklet_schedule(&dpcm->tasklet);
		hrtimer_forward_now(timer, dpcm->pcm_period_ns_kt);
  }
	return HRTIMER_RESTART;
}


static void snd_card_audard_pcm_hrtimer_tasklet(unsigned long priv)
{
  struct snd_audard_pcm *dpcm = (struct snd_audard_pcm *)priv;

	//~ unsigned long flags;

	// retrieve a ref to substream in the calling pcm struct:
	struct snd_pcm_substream *ss = dpcm->substream;
	// playback or capture direction..
	int dir_playcap = ss->stream;
	// destination - ref to main dma area
	char *dst = ss->runtime->dma_area;
	// ref to device struct
	struct audard_device *mydev = dpcm->mydev;

  int bytesToWrite;
  u64 delta;
  u32 pos;
  u32 posb;
  int imrdiff;
	int imrfill;
	int bytesSilence, bytesData;
	int bytesToWriteBWrap, bytesToWriteBWrapRemain, actuallyWrittenBytes;
  int endingPlayback;
  int frameSizeBytes;
  // to handle different wrapping of pcm buffer for playback and capture:
  int bufferWrapAt;
  unsigned long flags;
  struct snd_pcm_runtime *runtime = ss->runtime;
  bytesData = bytesToWriteBWrap = bytesToWriteBWrapRemain = 0 ; //init to avoid warnings

  //~ printk("%s (%d)\n", __func__, dir_playcap);
  frameSizeBytes	= frames_to_bytes(ss->runtime, 1);

	if (atomic_read(&dpcm->running)) {

    delta = ktime_us_delta(dpcm->timercb_time, //hrtimer_cb_get_time(&dpcm->timer),
               dpcm->base_time);
    delta = div_u64(delta * runtime->rate + 999999, 1000000);
    div_u64_rem(delta, runtime->buffer_size, &pos);
    pos = (((pos-1)/dpcm->frquant)*dpcm->frquant+1); // quantize pos; frames
    dpcm->pcm_buf_posF = pos;

    atomic_set(&dpcm->inTimer, 1); // will effect playback stream, too
    posb = frames_to_bytes(runtime, pos);

    if (posb >=dpcm->pcm_buf_posB)
      bytesToWrite = posb - dpcm->pcm_buf_posB;
    else
      bytesToWrite = dpcm->pcm_buffer_sizeB - dpcm->pcm_buf_posB+posb;

    // bytesToWriteBWrap - bytes after "this" current period end (in start of "next" period; but also start of "this" buffer due circular/ring buffer; negative if no wrap)
    // bytesToWriteBWrapRemain - bytes within "this" current period, up to its end (or 0, if no wrap)
      bytesToWrite = dpcm->pcm_period_sizeB; //hack

		if (dir_playcap == SNDRV_PCM_STREAM_PLAYBACK) { //
      u32 offset; // easier debug

      struct usb_serial_port *usport = mydev->ftdipr->port;
      int samplewidth = snd_pcm_format_width(ss->runtime->format);

      bufferWrapAt = dpcm->pcm_buffer_sizeB; // to distinguish from capture
      // for printout:
      imrdiff = imrfill = bytesSilence = 0;
      bytesData = bytesToWrite;

      offset = (dpcm->pcm_buf_posB+bytesToWrite)%dpcm->pcm_buffer_sizeB; //posb; // or dpcm->pcm_buf_posB;
      // check wrap of dma_area - only interested in actual bytes (not silence)
      bytesToWriteBWrap = offset + bytesToWrite - bufferWrapAt;
      bytesToWriteBWrapRemain = 0;

      //~ print_hex_dump(KERN_DEBUG, "pdma: ", DUMP_PREFIX_ADDRESS, 16, 1, dst, 16, false); // causes segfault here?? no // T11

      if (bytesToWriteBWrap > 0) { // we're wrapping
        bytesToWriteBWrapRemain = bytesToWrite - bytesToWriteBWrap;
        //bytesSilence = 0; //since we're wrapping, we need not write silence... well; keep it for this change..
        //~ bytesToWrite = bytesToWriteBWrapRemain;
      } else bytesToWriteBWrap = 0; // set to 0 for neg vals, to avoid confusion

      //~ memcpy(mydev->IMPLY, dst, dpcm->pcm_buffer_sizeB); // always whole buffer
      //~ memcpy(mydev->IMPLY+(dpcm->pcm_buf_posB%dpcm->pcm_period_sizeB)*dpcm->pcm_period_sizeB, (dpcm->pcm_buf_posB%dpcm->pcm_period_sizeB)*dpcm->pcm_period_sizeB, dpcm->pcm_period_sizeB); // kernel panic!
      //~ memcpy(mydev->IMPLY, dst+3*dpcm->pcm_buffer_sizeB/4, dpcm->pcm_buffer_sizeB/4);
      if (bytesToWriteBWrapRemain > 0) {
        memcpy(mydev->IMPLY+offset, dst+offset, bytesToWriteBWrapRemain);
        memcpy(mydev->IMPLY, dst, bytesToWriteBWrap);
        ftdi_write(NULL, usport, dst+offset, bytesToWriteBWrapRemain);
        ftdi_write(NULL, usport, dst, bytesToWriteBWrap);
      } else {
        memcpy(mydev->IMPLY+offset, dst+offset, bytesToWrite);
        ftdi_write(NULL, usport, dst+offset, bytesToWrite);
      }
      //~ ftdi_write(NULL, usport, mydev->IMPLY, bytesToWrite);

      /*
      if ((samplewidth == 16) && (ss->runtime->channels == 2)) { // this should be `audacity` - 16 bit stereo
			// new algo, handling all kindsa wrap:
			int tbExR; // tempbuf8b_extra Remain help var; also can serve as pcmpreinc
			int framesToWrite; // how many frames to write - changes between periods
			int bytesToWritePWrapRemain; // how many unwritten bytes at end of period
			//~ int frameSizeBytes; // (numchannels*samplesize_in_bytes); frames_to_bytes // moved up
			int breakstap; // 'fake' var, so systemtap can add a breakpoint
			int tframe, isBufFramePreinc, wrapped_dma_buf_pos;

			tbExR 					= (frameSizeBytes - mydev->tempbuf8b_extra) % frameSizeBytes;
      // framesToWrite should be less (than corresponding to bpj) if there's a wrap:
			framesToWrite 	= bytes_to_frames(ss->runtime, (bytesToWrite - tbExR)); //(bytesToWrite-tbExR)/frameSizeBytes;
			bytesToWritePWrapRemain = bytesToWrite - tbExR - frames_to_bytes(ss->runtime, framesToWrite); //framesToWrite*frameSizeBytes # this is also "future" tempbuf8b_extra..
			isBufFramePreinc = 0; breakstap = 0;
      //~ mydev->BwrapBytesRemain = 0;
      // also init these - so we have expected values in log (and avoid compiler warnings);
      tframe = -1; wrapped_dma_buf_pos = -1;

      endingPlayback = ( (-mydev->BwrapBytesRemain < bytesToWrite) && snd_pcm_playback_ready(ss) );
			if (mydev->tempbuf8b_extra > 0) {
				if (tbExR > 0) { // since now, _extra could also be frameSizeBytes - not anymore, but keep it
					memcpy(mydev->tempbuf8b_frame+mydev->tempbuf8b_extra, dst+dpcm->pcm_buf_posB+mydev->tempbuf8b_extra, tbExR);
					memcpy(mydev->tempbuf8b, mydev->tempbuf8b_frame, frames_to_bytes(ss->runtime, 1));
					isBufFramePreinc = frames_to_bytes(ss->runtime, 1); // else it is zero from start.
				}
			}
      if (mydev->BwrapBytesRemain > 0) { // ... however, we may still be in a frame that wraps on dma pcm BUFFER size boundary
          memcpy(&mydev->brokenEndFrame[frameSizeBytes-mydev->BwrapBytesRemain], dst, mydev->BwrapBytesRemain); // copy from start of dma_area
          memcpy(mydev->tempbuf8b + isBufFramePreinc, mydev->brokenEndFrame, frames_to_bytes(ss->runtime, 1));
          dbg("  brokenEndFrame B [%02hhX %02hhX %02hhX %02hhX ] dst [%02hhX %02hhX %02hhX %02hhX ] ", mydev->brokenEndFrame[0], mydev->brokenEndFrame[1], mydev->brokenEndFrame[2], mydev->brokenEndFrame[3], dst[0], dst[1], dst[2], dst[3] );
      }

			// we have now exact number of frames - which will definitely not wrap IN PERIOD - to send this period; handle:
			tframe = 0;
			while (tframe<frames_to_bytes(ss->runtime, framesToWrite)) {
        wrapped_dma_buf_pos = (dpcm->pcm_buf_posB+isBufFramePreinc+tframe) % bufferWrapAt;
        if (endingPlayback && (tframe > -mydev->BwrapBytesRemain) ) {
          memset(mydev->tempbuf8b + isBufFramePreinc + tframe, 0, frames_to_bytes(ss->runtime, 1));
        } else { // not ending - usual copy
          memcpy(mydev->tempbuf8b + isBufFramePreinc + tframe, dst+wrapped_dma_buf_pos, frames_to_bytes(ss->runtime, 1));
        }
				tframe+=frameSizeBytes; //frameSizeBytes==frames_to_bytes(ss->runtime, 1);
			}
      wrapped_dma_buf_pos = (dpcm->pcm_buf_posB+isBufFramePreinc+tframe) % bufferWrapAt;

      // dbgs...
			ftdi_write(NULL, usport, mydev->tempbuf8b, tframe+isBufFramePreinc); // (for 8-bit, framesToWrite bytes --  corresponding to frames!); now 16s: tframe does count actual bytes
			mydev->playawbprd += (tframe+isBufFramePreinc); // *frameSizeBytes;//(was for 8-bit!);   // sync to actual ftdi writes!
			mydev->tempbuf8b_extra = bytesToWritePWrapRemain; //(bytesToWrite + mydev->tempbuf8b_extra) % frameSizeBytes; // reset counter first

			if (mydev->tempbuf8b_extra > 0) {
				memcpy(mydev->tempbuf8b_frame, dst+wrapped_dma_buf_pos, mydev->tempbuf8b_extra);
			}
			mydev->tempbuf8b_extra_prev = mydev->tempbuf8b_extra;

      mydev->BwrapBytesRemain = wrapped_dma_buf_pos + frameSizeBytes - (bufferWrapAt - 1); //also advance by frameSizeBytes
      if (mydev->BwrapBytesRemain > 0) { // ... however, we may still be in a frame that wraps on dma pcm BUFFER size boundary
        if (mydev->BwrapBytesRemain < frameSizeBytes) {
          memcpy(&mydev->brokenEndFrame[0], dst+wrapped_dma_buf_pos, frameSizeBytes-mydev->BwrapBytesRemain); // copy from end of dma_area

          dbg("  brokenEndFrame A [%02hhX %02hhX %02hhX %02hhX ] dst [%02hhX %02hhX %02hhX %02hhX ] ", mydev->brokenEndFrame[0], mydev->brokenEndFrame[1], mydev->brokenEndFrame[2], mydev->brokenEndFrame[3], dst[wrapped_dma_buf_pos], dst[wrapped_dma_buf_pos+1], dst[wrapped_dma_buf_pos+2], dst[wrapped_dma_buf_pos+3] );
        }
      }
      // finally, re-sync bytesToWrite to accually written ??
      bytesToWrite = tframe+isBufFramePreinc;

      } // end if 16bit, stereo
      */
    } // end if (dir_playcap == SNDRV_PCM_STREAM_PLAYBACK)


    if (dir_playcap == SNDRV_PCM_STREAM_CAPTURE) { //
      bufferWrapAt = dpcm->pcm_buffer_sizeB; //capt_hw_avail; // to distinguish from playback

      #if (IMRX_BEHAVIOR == 0) // realloc
      if (mydev->IMRX.tail - mydev->IMRX.head>=0) {
        imrdiff = mydev->IMRX.tail - mydev->IMRX.head;
      } else { // we assume IMRX wrap here; tail < head
        // (this seems kinda wrong in retrospect)
        imrdiff = (mydev->IMRX.tail - 0) - (MAX_BUFFER - mydev->IMRX.head);
      }
      #endif
      #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
      imrdiff = mydev->IMRX.tail - mydev->IMRX.head;
      //~ printk(" capt imrdiff first %d t %d h % d ", imrdiff, mydev->IMRX.tail, mydev->IMRX.head); //T11
      if (imrdiff < 0) {
        // mydev->IMRX.size == MAX_BUFFER here
        imrdiff = (mydev->IMRX.tail - 0) + (mydev->IMRX.size - mydev->IMRX.head);
      }
      //~ printk(" second %d \n", imrdiff); //T11
      #endif


      // "round" the byte ammount, to one corresponding to frames
      imrfill = bytes_to_frames(ss->runtime, bytesToWrite)*frameSizeBytes;
      mydev->IMRX.cpwrem += bytesToWrite-imrfill; //(bpj-imrfill)
      // if cpwrem is frameSizeBytes, reset (via modulo) and read one frame more
      /*mydev->IMRX.cpwrem %= frameSizeBytes;
      if (imrfill != bytesToWrite) {
        if (mydev->IMRX.cpwrem == 0) {
          imrfill += frameSizeBytes;
        }
      }*/

      // "prebuffer" - output silence to capture, until IMRX has been filled to required difference (imrdiff)
      if (mydev->IMRX.cprebuffer > 0) {
        bytesSilence = imrfill;
        bytesData = 0;
        mydev->IMRX.cprebuffer--;
      } else {
        if (imrdiff>=imrfill) { // not enough; still silence "drops" (inserts) of pcm_period_size (8192/4 = 2048 samples) can be visible
          bytesData = imrfill; // was bytesToWrite
          bytesSilence = 0;
        } else { // not enough data - wait for more later/whole 'bpj' chunk is now silence:
          bytesSilence = imrfill;
          bytesData = 0;  // was bytesToWrite
        }
      }
      // check wrap of dma_area - only interested in actual bytes (not silence)
      bytesToWriteBWrap = dpcm->pcm_buf_posB + imrfill - bufferWrapAt;
      bytesToWriteBWrapRemain = 0;


      if (bytesToWriteBWrap > 0) { // we're wrapping
        mydev->IMRX.wrapbtw = bytesToWriteBWrap;
        bytesToWriteBWrapRemain = imrfill - bytesToWriteBWrap;
        dbg("  capt inwrap: bWWR:%d, bWW:%d, bWr:%d \n", bytesToWriteBWrapRemain, bytesToWriteBWrap, bytesToWrite);
        //bytesSilence = 0; //since we're wrapping, we need not write silence... well; keep it for this change..
        //~ bytesToWrite = bytesToWriteBWrapRemain;
      } else bytesToWriteBWrap = 0; // set to 0 for neg vals, to avoid confusion


      //~ local_irq_save(flags);    /* interrupts are now disabled; local cpu only! */
      #if (IMRX_BEHAVIOR == 0) // realloc
      if (bytesToWriteBWrapRemain > 0) {
        memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesToWriteBWrapRemain);
        memcpy(dst, mydev->IMRX.buf+mydev->IMRX.head+bytesToWriteBWrapRemain, bytesToWriteBWrap);
      } else {
        memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesData);
        //bytesToWrite here was also likely a mistake (maybe was meant bytesData?):
        if (bytesSilence>0) memset(dst+dpcm->pcm_buf_posB+bytesToWrite, 0, bytesSilence);
      }
      #endif
      #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
      if (bytesData>0) {
        int IMRX_BWrap = mydev->IMRX.head + bytesData - mydev->IMRX.size;
        int IMRX_BWrapRemain = (IMRX_BWrap>0) ? bytesData - IMRX_BWrap : 0; // NOT bytesToWriteBWrapRemain - And must eliminate negative values here too! ; else instacrash! NOTE, IMRX_BWrap can still be negative, however here IMRX_BWrapRemain is used to check, so setting it to 0 is enough to get the algorithm running!
        //~ dbg3(" capt bd %d imbw %d imbwr %d\n", bytesData, IMRX_BWrap, IMRX_BWrapRemain);
        //~ goto __endplay; // debug
        if ((bytesToWriteBWrapRemain > 0) && (IMRX_BWrapRemain > 0)){
          // could be a double whammy here, handle
          if (IMRX_BWrapRemain == bytesToWriteBWrapRemain) { // easiest:
            memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, IMRX_BWrapRemain);
            memcpy(dst, mydev->IMRX.buf, bytesToWriteBWrap);
          } else if (bytesToWriteBWrapRemain > IMRX_BWrapRemain) {
            //~ int firstStop = IMRX_BWrapRemain;
            //~ int secondStop = bytesToWriteBWrapRemain;
            memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, IMRX_BWrapRemain);
            memcpy(dst+dpcm->pcm_buf_posB+IMRX_BWrapRemain, mydev->IMRX.buf, bytesToWriteBWrapRemain-IMRX_BWrapRemain);
            memcpy(dst, mydev->IMRX.buf+bytesToWriteBWrapRemain-IMRX_BWrapRemain, bytesToWriteBWrap);
          } else { // bytesToWriteBWrapRemain < IMRX_BWrapRemain
            //~ int firstStop = bytesToWriteBWrapRemain;
            //~ int secondStop = IMRX_BWrapRemain;
            memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesToWriteBWrapRemain);
            memcpy(dst, mydev->IMRX.buf+mydev->IMRX.head+bytesToWriteBWrapRemain, IMRX_BWrapRemain-bytesToWriteBWrapRemain);
            memcpy(dst+IMRX_BWrapRemain-bytesToWriteBWrapRemain, mydev->IMRX.buf, IMRX_BWrap);
          }
        } else if (bytesToWriteBWrapRemain > 0) { // IMRX can be read in one go
          memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesToWriteBWrapRemain);
          memcpy(dst, mydev->IMRX.buf+mydev->IMRX.head+bytesToWriteBWrapRemain, bytesToWriteBWrap);
        } else if (IMRX_BWrapRemain > 0) { // IMRX cannot be read in one go
          memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, IMRX_BWrapRemain);
          memcpy(dst+dpcm->pcm_buf_posB+IMRX_BWrapRemain, mydev->IMRX.buf, IMRX_BWrap);
        } else { // no bytesToWriteBWrapRemain for neither
          memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesData);
        } // end else if ((bytesToWriteBWrapRemain > 0) ...
      } // end if (bytesData>0)
      if (bytesSilence>0) {
        if (bytesToWriteBWrapRemain > 0) {
          memset(dst+dpcm->pcm_buf_posB, 0, bytesToWriteBWrapRemain);
          memset(dst, 0, bytesToWriteBWrap);
        } else {
          memset(dst+dpcm->pcm_buf_posB, 0, bytesSilence);
        }
      }
      #endif
			//~ local_irq_restore(flags); /* interrupts are restored to their previous state */

      //~ __endplay:
      mydev->IMRX.head += bytesData; // only bytesData here!
      #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
      mydev->IMRX.head %= mydev->IMRX.size;
      #endif
      mydev->IMRX.hdWsnd += bytesData;

      /*
      // * check if by any chance we have wrap from last time?
      actuallyWrittenBytes = 0; // reset here, so we can take wrapbtw into account
      if (bytesToWriteBWrapRemain > 0) {
        memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesToWriteBWrapRemain);
        dbg(" post wrap mem cpy ");
        actuallyWrittenBytes += bytesToWriteBWrapRemain; // awb was 0 initially, so == to btWWR now..
        dpcm->pcm_irq_posB += bytesToWriteBWrapRemain;
        dpcm->pcm_buf_totB += bytesToWriteBWrapRemain;
        dpcm->pcm_buf_posB += bytesToWriteBWrapRemain; // this should bring buf_pos up to pcm_buffer_size
        dpcm->pcm_buf_posB %= bufferWrapAt; // buf_pos should now become zero
        mydev->IMRX.head += bytesToWriteBWrapRemain;
        mydev->IMRX.hdWsnd += bytesToWriteBWrapRemain;
        dbg(" post mem cpy pbpos: %d, irqpos %d ", dpcm->pcm_buf_pos, dpcm->pcm_irq_pos);

        bytesToWrite = bytesToWriteBWrap; // set to bwWrap now, for piece at beginning
        mydev->IMRX.wrapbtw = 0; // reset this here, as we're not using - so it don't clog the log
      }

      // * actual write
      if (bytesToWrite > 0) { // * if we have something, write it,
                  // * and fill rest - if any - with zeroes
        memcpy(dst+dpcm->pcm_buf_posB, mydev->IMRX.buf+mydev->IMRX.head, bytesToWrite);
        if (bytesSilence>0) memset(dst+dpcm->pcm_buf_posB+bytesToWrite, 0, bytesSilence);
        // * it is relevant to change head only here - and
        // * ALWAYS in respect to bytesToWrite! NOT dpcm->pcm_bpj
        mydev->IMRX.head += bytesToWrite; //
        mydev->IMRX.hdWsnd += bytesToWrite; //
        actuallyWrittenBytes += bytesToWrite + bytesSilence;
      } else { 	// * no data, just fill zeroes - (silence) -
            // * - and explicitly pcm_bpj bytes
            // * well... if bWr ==0; bsl = pcm_bpj; so use bsl (so its ok also for wrap? )
        int bslRemain = dpcm->pcm_buf_posB+bytesSilence - bufferWrapAt;
        dbg(" pre wrap mem set silence %d, pbpos %d, wrapat %d, stop_th %ld", bytesSilence, dpcm->pcm_buf_pos, bufferWrapAt, ss->runtime->stop_threshold);
        if (bslRemain > 0) {
          memset(dst+dpcm->pcm_buf_posB, 0, bytesSilence-bslRemain);
          memset(dst, 0, bslRemain);
        } else {
          memset(dst+dpcm->pcm_buf_posB, 0, bytesSilence);
        }
        dbg(" post silence %d, pbpos %d to %d / %d %d", bytesSilence, dpcm->pcm_buf_posB, dpcm->pcm_buf_posB+bytesSilence, bslRemain, dpcm->pcm_buf_posB+bytesSilence-bslRemain);
        actuallyWrittenBytes += bytesSilence;
        dpcm->pcm_buf_posB += bytesSilence;
      }
      */

      // * 'recover' IMRX - if we reached end of its
      // *   contents, set head=tail=0
      if (mydev->IMRX.head == mydev->IMRX.tail) {
        mydev->IMRX.head = mydev->IMRX.tail = 0;
      }
    } // end if (dir_playcap == SNDRV_PCM_STREAM_CAPTURE)

    //~ printk("timer_func: (%d) pbp %d (pb %d) btw %d btwbw %d btwbwr %d bd %d bsl %d imf %d imd %d t %d h %d cpre %d\n", dir_playcap, dpcm->pcm_buf_posB, posb, bytesToWrite, bytesToWriteBWrap, bytesToWriteBWrapRemain, bytesData, bytesSilence, imrfill, imrdiff, mydev->IMRX.tail, mydev->IMRX.head, mydev->IMRX.cprebuffer); //T11
    //~ dpcm->pcm_buf_posB = frames_to_bytes(runtime, pos); // pos already wrapped to pcm_buffer_size (in frames)!
    dpcm->pcm_buf_posB += bytesToWrite;
    dpcm->pcm_buf_posB %= dpcm->pcm_buffer_sizeB;
    dpcm->pcm_buf_posF = bytes_to_frames(ss->runtime, dpcm->pcm_buf_posB);

    dpcm->pcm_irq_posB += bytesToWrite;
    dpcm->pcm_irq_posB %= dpcm->pcm_period_sizeB;

    snd_pcm_period_elapsed(dpcm->substream);
    atomic_set(&dpcm->inTimer, 0);

    //~ if (dir_playcap == SNDRV_PCM_STREAM_PLAYBACK) { memcpy(mydev->IMPLY, dst, dpcm->pcm_buffer_sizeB); }; // always whole buffer; trying after but no dice
  } // end if dpcm->running
} // end pcm_timer_function

static snd_pcm_uframes_t snd_card_audard_pcm_pointer(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;
	u32 pos;
	u64 delta;
  ktime_t ktnow;

  if(!atomic_read(&dpcm->inTimer)) {
    ktnow = hrtimer_cb_get_time(&dpcm->timer_hr);
    if (ktime_to_ns(ktnow) > ktime_to_ns(dpcm->base_time) ) {
      delta = ktime_us_delta(ktnow, //hrtimer_cb_get_time(&dpcm->timer_hr),
                 dpcm->base_time);
      delta = div_u64(delta * runtime->rate + 999999, 1000000);
      div_u64_rem(delta, runtime->buffer_size, &pos);
      pos = (((pos-1)/dpcm->frquant)*dpcm->frquant+1); // quantize pos
      dpcm->pcm_buf_posF = pos;
    } else dpcm->pcm_buf_posF = pos = 0;
  } else {
    pos = dpcm->pcm_buf_posF;
  }

  //~ trace_printk("_pointer: %d (%d) a:%lu h:%lu d:%ld av:%ld hav:%ld c:%pS\n", pos, substream->stream, substream->runtime->control->appl_ptr, substream->runtime->status->hw_ptr, substream->runtime->delay, (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) ? snd_pcm_playback_avail(substream->runtime) : snd_pcm_capture_avail(substream->runtime), (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) ? snd_pcm_playback_hw_avail(substream->runtime) : snd_pcm_capture_hw_avail(substream->runtime), __builtin_return_address(1)); //T11

	return pos;
}

static void snd_card_audard_runtime_free(struct snd_pcm_runtime *runtime)
{
	kfree(runtime->private_data);
}

static struct snd_audard_pcm *new_pcm_stream(struct snd_pcm_substream *substream)
{
	struct snd_audard_pcm *dpcm;

	dpcm = kzalloc(sizeof(*dpcm), GFP_KERNEL);
	if (! dpcm)
		return dpcm;
	/*
	init_timer(&dpcm->timer);
	dpcm->timer.data = (unsigned long) dpcm;
	dpcm->timer.function = snd_card_audard_pcm_timer_function;
	*/
	hrtimer_init(&dpcm->timer_hr, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
	//dpcm->timer_hr.data = (unsigned long) dpcm; // noexist - removed from hrtimer API!
	dpcm->timer_hr.function = &snd_card_audard_pcm_timer_function;
	//
	spin_lock_init(&dpcm->lock);
	dpcm->substream = substream;
  atomic_set(&dpcm->running, 0);
  tasklet_init(&dpcm->tasklet, snd_card_audard_pcm_hrtimer_tasklet, (unsigned long)dpcm);
	return dpcm;
}

static int snd_card_audard_new_pcm(struct audard_device *mydev,
							int device, int substreams) // no __devinit here
{
	struct snd_pcm *pcm;
	int err;

	err = snd_pcm_new(mydev->card, "AudArd 16s PCM", device,
									substreams, substreams, &pcm);

	//~ dbg2("%s: snd_pcm_new: %d, dev %d, subs %d", __func__, err, device, substreams);

	if (err < 0)
		return err;
	mydev->pcm = pcm;
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &audard_pcm_playback_ops);
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &audard_pcm_capture_ops);
	pcm->private_data = mydev; // 'pcm' is snd_pcm struct - has private_data
	pcm->info_flags = 0;
	strcpy(pcm->name, "AudArd 16s PCM");

	snd_pcm_lib_preallocate_pages_for_all(pcm, SNDRV_DMA_TYPE_CONTINUOUS,
					      snd_dma_continuous_data(GFP_KERNEL),
					      0, 64*1024);
	return 0;
}

// end ripped from dummy.c **********

static struct snd_device_ops audard_dev_ops =
{
	.dev_free = snd_card_audard_pcm_dev_free,
};

#define SND_AUDARD_DRIVER DRVNAME


int audard_IMRX_read_procmem(char *bufpage, char **start, off_t offset,
                   int count, int *eof, void *data)
{
	struct snd_card *card;
	struct audard_device *mydev;
  int len=0;

	card = thiscard; 		// get from global var
	mydev = card->private_data;

  // typical:
  //~ int i, j, len = 0;
  //~ int limit = count - 80; // * Don't print more than this
  //~ len += sprintf(buf+len,"\nDevice %i: qset %i, q %i, sz %li\n",
          //~ i, d->qset, d->quantum, d->size);

  // here, memcpy:
  len = count;
  if (count+offset > MAX_BUFFER)
    len = 0; //count+offset-MAX_BUFFER;
  //~ printk("procmem ofs %d cnt %d eof %d len %d\n", offset, count, eof, len);
  memcpy(bufpage, mydev->IMRX.buf+offset, len);
  *start = bufpage; // no offset here!
  if ((len==0) || (count+offset > MAX_BUFFER)) {
    *eof = 1;
    len = 0; // must return 0 at end!
  }

  return len;
}
int audard_IMPLY_read_procmem(char *bufpage, char **start, off_t offset,
                   int count, int *eof, void *data)
{
	struct snd_card *card;
	struct audard_device *mydev;
  int len=0;

	card = thiscard; 		// get from global var
	mydev = card->private_data;

  // here, memcpy:
  len = count;
  if (count+offset > MAX_BUFFER)
    len = 0; //count+offset-MAX_BUFFER;
  //~ printk("procmem ofs %d cnt %d eof %d len %d\n", offset, count, eof, len);
  memcpy(bufpage, mydev->IMPLY+offset, len);
  *start = bufpage; // no offset here!
  if ((len==0) || (count+offset > MAX_BUFFER)) {
    *eof = 1;
    len = 0; // must return 0 at end!
  }

  return len;
}

// this one can also cause an oops (for reboot), but is slightly more robust..
int audard_pdmaddr_read_procmem(char *bufpage, char **start, off_t offset,
                   int count, int *eof, void *data)
{
	struct snd_card *card;
	struct audard_device *mydev;
  struct snd_audard_pcm *dpcm;
  struct snd_pcm_substream *ss;
  char paddrs[32];
  //~ int len=0;
  int MAXbytes;


  if (offset > 0) { // just one string
    *eof = 1;
    return 0;
  }

	if (!(card = thiscard)) {  		// get from global var
    sprintf(&paddrs[0], "no card 0x%p\n", thiscard);
  } else {
    if (!(mydev = card->private_data)) {
      sprintf(&paddrs[0], "no dev 0x%p\n", card->private_data);
    } else {
      if(!(dpcm = mydev->playcaptstreams[SNDRV_PCM_STREAM_PLAYBACK])) {
        sprintf(&paddrs[0], "no dpcm 0x%p\n", mydev->playcaptstreams);
      }
      else {
        if (!(ss = dpcm->substream)) {
          sprintf(&paddrs[0], "no ss 0x%p\n", dpcm->substream);
        } else {
          if (!(ss->runtime)) {
            sprintf(&paddrs[0], "no runt 0x%p\n", ss->runtime);
          } else {
            if (!(ss->runtime->dma_area)) {
              sprintf(&paddrs[0], "no dma 0x%p\n", ss->runtime->dma_area);
            } else {
              sprintf(&paddrs[0], "0x%p\n", ss->runtime->dma_area);
            }
          }
        }
      }
    }
  }


  //dmabuf = ss->runtime->dma_area;
  MAXbytes = strlen(paddrs);

  // here, memcpy:
  //~ len = count;
  //~ if (count+offset > MAXbytes)
    //~ len = 0; //count+offset-MAX_BUFFER;
  //~ printk("procmem ofs %d cnt %d eof %d len %d\n", offset, count, eof, len);
  memcpy(bufpage, paddrs, MAXbytes);
  *start = bufpage; // no offset here!
  //~ if ((len==0) || (count+offset > MAXbytes)) {
    //~ *eof = 1;
    //~ len = 0; // must return 0 at end!
  //~ }

  return MAXbytes;
}


/*
* do NOT use this code; after a user-space stop; the substream (and dma_area) are **destroyed** - so then this operation fails with a kernel Oops due NULL pointer dereference, requiring reboot!
*
int audard_PAREA_read_procmem(char *bufpage, char **start, off_t offset,
                   int count, int *eof, void *data)
{
	struct snd_card *card;
	struct audard_device *mydev;
  struct snd_audard_pcm *dpcm;
  struct snd_pcm_substream *ss;
  char *dmabuf;
  int MAXbytes;
  int len=0;

	card = thiscard; 		// get from global var
	mydev = card->private_data;
  dpcm = mydev->playcaptstreams[SNDRV_PCM_STREAM_PLAYBACK];
  ss = dpcm->substream;
  dmabuf = ss->runtime->dma_area;
  MAXbytes = ss->runtime->dma_bytes;

  // here, memcpy:
  len = count;
  if (count+offset > MAXbytes)
    len = 0; //count+offset-MAX_BUFFER;
  //~ printk("procmem ofs %d cnt %d eof %d len %d\n", offset, count, eof, len);
  memcpy(bufpage, dmabuf+offset, len);
  *start = bufpage; // no offset here!
  if ((len==0) || (count+offset > MAXbytes)) {
    *eof = 1;
    len = 0; // must return 0 at end!
  }

  return len;
}
*/




/*
 *
 * Probe/remove functions
 *
 */
static int audard_probe(struct usb_serial *serial)
{
	struct snd_card *card;
	struct audard_device *mydev;
	int ret, i;
	int err;

	// * this 'dev' used to loop through the *pcm_substreams array
	int dev; // = devptr->id; // from aloop-kernel.c

	// * ref. to master usb device
	struct usb_device *udev = serial->dev;


	// * get the 'device' number
	// * TODO: make it really handle multiple cards
	// * NOTE - apparently, system will set 'enable'
	// *   depending on  ammount of cards connected,
	// *   and user choice - and will present 'enable'
	// *   here ready to be read...
	// * at this point: enable[0]=1; and all other entries
	// *   are 0 (and index[i], for all, is -1 ?! means next?!)
	// * for a single card, we anyway count on just being
	// *   dev=0 - as enable[0]=1 already

	for (i = 0; i < SNDRV_CARDS; i++) {
		if (enable[i]) {
			dev = i;
			break;
		}
	}
	//dev = 1; //explicit set for debug
	dbg("%s: dev: %d, index %d - %s", __func__, dev, index[dev], buildString);

	// * adding AUDARD instead of id[dev] here,
	// *   results with arecord -l (alsa-info) showing:
	// *     card 1: AUDARD [MySoundCard ftdi_sio_audard],
	// * 		device 0: ftdi_sio_audard [MySoundCard ftdi_sio_audard]
	// *     state.AUDARD { in alsa-info etc...
	// * else we have:
	// *   card 1: ftdisioaudard [...
	// *    state.ftdisioaudard {...

	// * NOTE that snd_card_create (via snd_ctl_dev_register)
	// *   will create the /dev/snd/by-path/ControlC% symlink;
	// *   which in this case is:
	// *   pci-0000:00:1d.3 -> ../controlC1
	// * That is not a case for concern, if that is actually the USB bus:
	// *     $ ls /sys/devices/pci0000\:00/0000\:00\:1d.3 | grep usb
	// *   would give:
	// *     usb5 usbmon
	// * And, here is a way to check that usb is actually related to sound:
	// *   $ ls /sys/devices/pci0000\:00/0000\:00\:1d.3/*/* | grep '\(sound\|:$\)' | grep 'sound' -B 1
	// *   /sys/devices/pci0000:00/0000:00:1d.3/usb5/5-2:
	// *   sound

  // now "AUDARD16S":

	ret = snd_card_create(index[dev], "AUDARD16S",
	                      THIS_MODULE, sizeof(struct audard_device), &card); // id[dev]

	// * no need to kzalloc audard_device separately, if it
	// *    is included in the snd_card_create above

	if (ret < 0)
		goto __nodev;

	mydev = card->private_data;
	mydev->card = card;
	thiscard = card;

	mydev->isSerportOpen = 0;

	// * MUST have mutex_init here - else crash on mutex_lock!!
	mutex_init(&mydev->cable_lock);

  // NOTE: in sound/core.h; snd_card struct defines: char id[16]; char driver[16]; char shortname[32]; char longname[80];
  // SND_AUDARD_DRIVER == DRIVER must be max 15 chars, though!

	sprintf(card->driver, "%s", SND_AUDARD_DRIVER);
	sprintf(card->shortname, "MySoundCard %s", card->driver); //SND_AUDARD_DRIVER);
	sprintf(card->longname, "%s", card->shortname);
	dbg("-- mydev %p, card->number %d, card->driver '%s', card->shortname '%s'", mydev, card->number, card->driver, card->shortname);

	// init the IMRX buffer here, MAX_BUFFER for start
	// NOTE: we'll allocate IMRX.wrapbuf, where we know
	//   pcm_buffer_size (in _prepare); wrapbuf needs not be bigger than that.
	mydev->IMRX.head = mydev->IMRX.tail = 0;
	mydev->IMRX.buf = kzalloc(MAX_BUFFER, GFP_KERNEL);
	if (! mydev->IMRX.buf)
		goto __nodev;
	mydev->IMRX.size = MAX_BUFFER;
	mydev->IMPLY = kzalloc(MAX_BUFFER, GFP_KERNEL);
	if (! mydev->IMPLY)
		goto __nodev;

	// * init substreams here
	// *   here we have only one device, unlike in dummy.c
	// *   so, rip from aloop-kernel.c - allocate pcm streams manually
	// *   for the only device, we have dev=0
	if (pcm_substreams[dev] < 1)
		pcm_substreams[dev] = 1;
	if (pcm_substreams[dev] > MAX_PCM_SUBSTREAMS)
		pcm_substreams[dev] = MAX_PCM_SUBSTREAMS;

	// * create the first and only device @ 0 (it will have
	// *   playback and capture substreams)..
	// * pcm_substreams[dev] should be 1 - so we get 1 capture
	// *   AND 1 playback substream
	// * same as in aloop-kernel.c - except there they also
	// *   explicitly allocate second device (cable) -
	// *   as in, (mydev, 1, ...)
	err = snd_card_audard_new_pcm(mydev, 0, pcm_substreams[dev]);
	if (err < 0)
		goto __nodev;


	// * snd_card_set_dev is present in dummy - not in aloop though
	snd_card_set_dev(card, &serial->dev->dev);

	// * this set of audard_dev_ops seems to work, because
	// *   snd_card_audard_pcm_dev_free gets called @ snd_card_free
	ret = snd_device_new(card, SNDRV_DEV_LOWLEVEL, mydev, &audard_dev_ops);

	if (ret < 0)
		goto __nodev;

	// DO NOT USE ftdi_open HERE - AT THIS POINT, ftdipr IS NOT KNOWN!!

	// * from usbaudio.c -  added extra for debugging
	mydev->usb_id = USB_ID(le16_to_cpu(udev->descriptor.idVendor),
		    le16_to_cpu(udev->descriptor.idProduct));

	// * static strings from the device - see also
	// *   udev->descriptor.iManufacturer; udev->descriptor.iProduct
	dbg("  manufacturer %s, product %s, serial %s, devpath %s", udev->manufacturer, udev->product, udev->serial, udev->devpath);

  create_proc_read_entry("audard_IMRX", 0 /* default mode */,
        NULL /* parent dir */, audard_IMRX_read_procmem,
        NULL /* client data */);
  create_proc_read_entry("audard_IMPLY", 0 /* default mode */,
        NULL /* parent dir */, audard_IMPLY_read_procmem,
        NULL /* client data */);
  create_proc_read_entry("audard_pdmaddr", 0 /* default mode */,
        NULL /* parent dir */, audard_pdmaddr_read_procmem,
        NULL /* client data */);

	if (ret == 0)   	// or... (!ret)
	{
		// * also trying without this platform_set_drvdata
		// *   so as to lose refs to devptr...
		// * platform_set_drvdata simply does:
		// * "store a pointer to priv (card) data structure".
		//~ platform_set_drvdata(serial->dev, card); //devptr,

		return 0; 		// success
	}

	dbg("  ret %d", ret);
	return ret;

__nodev: 				// as in aloop/dummy...
	dbg("__nodev reached!!");
	snd_card_free(card); // this will autocall .dev_free (= snd_card_audard_pcm_dev_free)
	return ret;
}

// just to set ftdi_private - _probe 2nd part:
static int audard_probe_fpriv(struct ftdi_private *priv)
{
	struct snd_card *card;
	struct audard_device *mydev;
	int ret;

	card = thiscard; 		// get from global var
	mydev = card->private_data;

	// * ALSO: STORE audard_device ref in ftdi_private HERE:
	priv->audev = mydev;
	mydev->ftdipr = priv;	// .. and reflink back ..

	// * try open port here?? ftdi_open CRASHES - so bad, no messages, with crashdump!!

	// * since this represents end of all _probe allocations,
	// *   we should call snd_card_register ...
	// * THIS snd_card_register MUST BE LAST, AFTER ALL ALLOCS!!
	ret = snd_card_register(card);

	dbg("%s: snd_pcm_new: mydev %p, ftdipriv %p, reg/ret %d, audev %p", __func__, mydev, mydev->ftdipr, ret, priv->audev);

	return 0;
}


// * from dummy/aloop:
// * we cannot use __devexit here anymore
//static int audard_remove(struct platform_device *devptr)
static void audard_remove(void)
{
	struct audard_device *mydev = thiscard->private_data;
	dbg("%s (%s)", __func__, buildString);
  remove_proc_entry("audard_IMPLY", NULL /* parent dir */);
  remove_proc_entry("audard_IMRX", NULL /* parent dir */);
  remove_proc_entry("audard_pdmaddr", NULL /* parent dir */);
	kfree(mydev->IMPLY);
	kfree(mydev->IMRX.buf);
	kfree(mydev->IMRX.wrapbuf);
	kfree(mydev->tempbuf8b);
	kfree(mydev->tempbuf8b_frame);
	kfree(mydev->brokenEndFrame);
	snd_card_free(thiscard);
	//~ snd_card_free(platform_get_drvdata(devptr));
	//~ platform_set_drvdata(devptr, NULL);
	return;// 0;
}


/*
*
* PCM functions
*
*/

static int snd_card_audard_pcm_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params)
{
  // in hw_params, we can simply read  params_buffer_bytes(hw_params) ; also params_channels, params_rate,  params_period_size, params_periods, params_buffer_size,  params_buffer_bytes

	//~ dbgh("%s", __func__);
  int ret;
	struct audard_device *mydev = ss->private_data;
	struct snd_pcm_runtime *runtime = ss->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;
	//~ struct audard_device *mydev = dpcm->mydev; // just for tlRecv;hdWsnd; reset

  //~ dbgh("%s A %d %p %p %p", __func__, ret, mydev, runtime, dpcm); // remains same

  ret = snd_pcm_lib_malloc_pages(ss,
	                                params_buffer_bytes(hw_params));

	mydev = ss->private_data;
	runtime = ss->runtime;
	dpcm = runtime->private_data;

  // no bps:%d bpj: %d here
  // do NOT use bytes_to_samples(runtime, runtime->dma_bytes) here; CRASHES SEVERELY
  //~ dbgh("%s B %d %p %p %p", __func__, ret, mydev, runtime, dpcm);
  //~ dbgh("  >%s: ss:%d ret:%d  HZ: %d, jiffies: %lu, jiffies_ms: %lu, buffer_size: %d, pcm_period_size: %d, dma_bytes %d, fmt|nch|rt %d|%d|%d",
  //~ __func__, ss->stream, ret, HZ, jiffies, jiffies * 1000 / HZ, dpcm->pcm_buffer_size, dpcm->pcm_period_size, runtime->dma_bytes, snd_pcm_format_width(runtime->format), runtime->channels, runtime->rate
  //~ );
  //~ dbgh("  >start_th: %ld, stop_th: %ld, silence_th: %ld, silence_sz: %ld, boundary: %ld, sil_start: %ld, sil_fill: %ld \n", runtime->start_threshold, runtime->stop_threshold, runtime->silence_threshold, runtime->silence_size, runtime->boundary, runtime->silence_start, runtime->silence_filled );

	return ret;
}

static int snd_card_audard_pcm_hw_free(struct snd_pcm_substream *ss)
{
	//~ dbghf("%s", __func__);

	return snd_pcm_lib_free_pages(ss);
}


static int snd_card_audard_pcm_playback_open(struct snd_pcm_substream *ss)
{
	struct audard_device *mydev = ss->private_data;
	struct snd_pcm_runtime *runtime = ss->runtime;
	struct snd_audard_pcm *dpcm;
	int err;
	int dir_playcap = ss->stream;	// * integer - stream direction:
									// * playback or capture?
									// * although, it's implicitly defined,
									// * as this is playback callback

	//BREAKPOINT();
	//~ dbgo("%s", __func__);

	// copied from aloop-kernel.c:
	mutex_lock(&mydev->cable_lock);

	// from dummy.c
	if ((dpcm = new_pcm_stream(ss)) == NULL)
		return -ENOMEM;
	runtime->private_data = dpcm;
	dpcm->mydev = mydev;

	// put a reference to this (playback) stream in mydev:
	mydev->playcaptstreams[dir_playcap] = dpcm;

	/* makes the infrastructure responsible for freeing dpcm */
	runtime->private_free = snd_card_audard_runtime_free;
	runtime->hw = audard_pcm_hw_playback;
	if (ss->pcm->device & 1) {
		runtime->hw.info &= ~SNDRV_PCM_INFO_INTERLEAVED;
		runtime->hw.info |= SNDRV_PCM_INFO_NONINTERLEAVED;
	}
	if (ss->pcm->device & 2)
		runtime->hw.info &= ~(SNDRV_PCM_INFO_MMAP|SNDRV_PCM_INFO_MMAP_VALID);
	err = add_playback_constraints(runtime);
	if (err < 0)
		return err;

	mutex_unlock(&mydev->cable_lock);

	// try ftdi_open here - it calls allocs that sleep, but
	//  hw_params should be a non-atomic callback
	// repeated opens should be handled in that function...
	ftdi_open(NULL, mydev->ftdipr->port);

	return 0;
}

static int snd_card_audard_pcm_playback_close(struct snd_pcm_substream *substream)
{
	struct audard_device *mydev = substream->private_data;
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;

  //~ dbgo("%s", __func__);
  //~ dbgt("	  :: cb_running: %d, active: %d, is_queued: %d, running: %d", hrtimer_callback_running(&dpcm->timer_hr), hrtimer_active(&dpcm->timer_hr), hrtimer_is_queued(&dpcm->timer_hr), dpcm->mydev->running);
  //~ if (dpcm) kfree(dpcm); //crashes kernel!
  if ( hrtimer_active(&dpcm->timer_hr) ) { hrtimer_cancel(&dpcm->timer_hr); } ;
  tasklet_kill(&dpcm->tasklet);
  //~ snd_card_audard_pcm_timer_stop(dpcm); // no need for this anymore (now that hrtimer_cancel is understood to freeze kernel inside the _stop ISR)

	// try ftdi_close here
	// repeated closes should be handled in that function...
	ftdi_close(mydev->ftdipr->port);

	return 0;
}


static int snd_card_audard_pcm_capture_open(struct snd_pcm_substream *ss)
{
	struct audard_device *mydev = ss->private_data;
	struct snd_pcm_runtime *runtime = ss->runtime;
	struct snd_audard_pcm *dpcm;
	int err;
	int dir_playcap = ss->stream;	// * integer - stream direction:
									// * playback or capture?
									// * although, it's implicitly defined,
									// * as this is capture callback

	// copied from aloop-kernel.c:
	mutex_lock(&mydev->cable_lock);

	// from dummy.c
	if ((dpcm = new_pcm_stream(ss)) == NULL)
		return -ENOMEM;
	runtime->private_data = dpcm;
	dpcm->mydev = mydev;

	// put a reference to this (playback) stream in mydev:
	mydev->playcaptstreams[dir_playcap] = dpcm;

	/* makes the infrastructure responsible for freeing dpcm */
	runtime->private_free = snd_card_audard_runtime_free;
	runtime->hw = audard_pcm_hw_capture;
	if (ss->pcm->device & 1) {
		runtime->hw.info &= ~SNDRV_PCM_INFO_INTERLEAVED;
		runtime->hw.info |= SNDRV_PCM_INFO_NONINTERLEAVED;
	}
	if (ss->pcm->device & 2)
		runtime->hw.info &= ~(SNDRV_PCM_INFO_MMAP|SNDRV_PCM_INFO_MMAP_VALID);
	err = add_playback_constraints(runtime);
	if (err < 0)
		return err;

	mutex_unlock(&mydev->cable_lock);

	// try ftdi_open here - it calls allocs that sleep, but
	//  hw_params should be a non-atomic callback
	// repeated opens should be handled in that function...
	ftdi_open(NULL, mydev->ftdipr->port);

	return 0;
}

static int snd_card_audard_pcm_capture_close(struct snd_pcm_substream *substream)
{
	struct audard_device *mydev = substream->private_data;
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;

  //~ dbgo("%s", __func__);
  //~ dbgt("	  :: cb_running: %d, active: %d, is_queued: %d, running: %d", hrtimer_callback_running(&dpcm->timer_hr), hrtimer_active(&dpcm->timer_hr), hrtimer_is_queued(&dpcm->timer_hr), dpcm->mydev->running);
  //~ if (dpcm) kfree(dpcm); //crashes kernel!
  if ( hrtimer_active(&dpcm->timer_hr) ) { hrtimer_cancel(&dpcm->timer_hr); } ;
  tasklet_kill(&dpcm->tasklet);

	// try ftdi_close here
	// repeated closes should be handled in that function...
	ftdi_close(mydev->ftdipr->port);

	return 0;
}



/*
 *
 * called on incoming USB (from _ftdi_audard.c)
 * CABLE_PLAYBACK: 1, CABLE_CAPTURE: 2, CABLE_BOTH: 3
 */

#define CABLE_PLAYBACK	(1 << SNDRV_PCM_STREAM_PLAYBACK)
#define CABLE_CAPTURE	(1 << SNDRV_PCM_STREAM_CAPTURE)
#define CABLE_BOTH	(CABLE_PLAYBACK | CABLE_CAPTURE)

static void audard_xfer_buf(struct audard_device *mydev, char *inch, unsigned int count)
{
	//~ dbg2(">audard_xfer_buf: count: %d - %d (P:%d, C:%d)", count, mydev->running, CABLE_PLAYBACK, CABLE_CAPTURE );

	// * as in aloop-kernel.c...

	switch (mydev->running) {
		case CABLE_CAPTURE:
		case CABLE_BOTH:
			audard_fill_capture_buf(mydev, inch, count);
			break;
	}

}

static void audard_fill_capture_buf(struct audard_device *mydev, char *inch, unsigned int bytes)
{

	// * This function takes care only of adding,
	// *    or copying, to intermediate RX buffer.
	// * First, check if we will fit in IMRX - else "realloc"
	// * But, since no "realloc" in kernel, use trick: http://lkml.indiana.edu/hypermail/linux/kernel/0002.0/0365.html
	// * On incoming bytes (here), we move the tail;
	// *   on pcm_elapsed (timer_func) - the head is moved.

	int newtail;
	char* buftail;
  #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
  int bytesToWriteBWrap, bytesToWriteBWrapRemain;
  #endif
	// * mutex causing increased ammount of kernel warnings here!
	//~ mutex_lock(&mydev->cable_lock);

  #if (IMRX_BEHAVIOR == 0) // realloc
	newtail = mydev->IMRX.tail + bytes;
	if (newtail > mydev->IMRX.size - 1) {
		// * instead of falling into this many times,
		// *   if packets are like 62 bytes each,
		// *   lets just 'realloc' +MAX_BUFFER bytes
		int newsize = mydev->IMRX.size + MAX_BUFFER;
		char* newimrx = kmalloc(newsize, GFP_ATOMIC); //was GFP_KERNEL
		char* oldhead = mydev->IMRX.buf + mydev->IMRX.head;
		if (! newimrx) { // handle alloc fail
			//~ dbg2("%s: - new IMRX is %p, tl: %d", __func__, newimrx, mydev->IMRX.tail);
			return;
		}

		// * the actual 'realloc'
		memcpy(newimrx, oldhead, mydev->IMRX.size);
		kfree(mydev->IMRX.buf);
		mydev->IMRX.buf = newimrx;

		// * since now we start where old tail was, "reset" head and tail
		mydev->IMRX.tail -= mydev->IMRX.head;
		mydev->IMRX.head = 0;
		mydev->IMRX.size = newsize;
	}

	// * ok, now do fill (copy data into) our buffer
	buftail = mydev->IMRX.buf + mydev->IMRX.tail;
	memcpy(buftail, inch, bytes);
  #endif

  #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
	newtail = mydev->IMRX.tail + bytes;
  bytesToWriteBWrap = newtail - mydev->IMRX.size;
  bytesToWriteBWrapRemain = 0;
	buftail = mydev->IMRX.buf + mydev->IMRX.tail;
  if (bytesToWriteBWrap > 0) { // we're wrapping
    bytesToWriteBWrapRemain = bytes - bytesToWriteBWrap;
  } else bytesToWriteBWrap = 0; // set to 0 for neg vals, to avoid confusion
  if (bytesToWriteBWrapRemain > 0) {
    memcpy(buftail, inch, bytesToWriteBWrapRemain);
    memcpy(mydev->IMRX.buf, inch+bytesToWriteBWrapRemain, bytesToWriteBWrap);
  } else {
    memcpy(buftail, inch, bytes);
  }
  #endif

	mydev->IMRX.tail += bytes;
  #if (IMRX_BEHAVIOR == 1) // circular buffer behavior
	mydev->IMRX.tail %= mydev->IMRX.size;
  #endif
	mydev->IMRX.tlRecv += bytes;

  //~ dbg2("  IMRX inch (:%d): [%02hhX %02hhX %02hhX %02hhX ... %02hhX %02hhX %02hhX %02hhX ] ", bytes, inch[0], inch[1], inch[2], inch[3], inch[bytes-4], inch[bytes-3], inch[bytes-2], inch[bytes-1] );


	//~ mutex_unlock(&mydev->cable_lock);
}


/*
 *
 * snd_device_ops / PCM free functions
 *
 */
// * these should eventually get called by
// * snd_card_free (via .dev_free)
// * however, since we do no special allocations,
// * we need not free anything
static int snd_card_audard_pcm_free(struct
audard_device *chip)
{
	//~ dbg2("%s", __func__);
	//~ kfree(chip->IMRX.buf); // possibly cause for segfault here? Now in _remove..
	return 0;
}

static int snd_card_audard_pcm_dev_free(struct snd_device *device)
{
	//~ dbg2("%s", __func__);
	return snd_card_audard_pcm_free(device->device_data);
}

