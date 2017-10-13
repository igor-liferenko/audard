/*******************************************************************************
* dummy-2.6.32-patest-fix.c                                                    *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/
/*
 *  Dummy soundcard
 *  Copyright (c) by Jaroslav Kysela <perex@perex.cz>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program; if not, write to the Free Software
 *   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 *
 */
// started from http://lxr.linux.no/#linux+v2.6.32/sound/drivers/dummy.c
// modded sdaau 2013

#define VALUE_TO_STRING(x) #x
#define VALUE(x) VALUE_TO_STRING(x)
#define VAR_NAME_VALUE(var) #var "="  VALUE(var)


#define CONFIG_MODULE_FORCE_UNLOAD

// DEBUG controls regular printk messages to /var/log/syslog (always on here)
#define DEBUG
#ifdef DEBUG
  #pragma message "Compiling DEBUG ..."
	static int debug = 1;
#else
  #pragma message "Compiling without debug ..."
	static int debug;
#endif

/* Use our own dbg macro */
#undef dbg
//~ #define dbg(format, arg...) do { if (debug) printk(KERN_DEBUG __FILE__ ": " format "\n" , ## arg); } while (0)
#define dbg(format, arg...) do { if (debug) printk(KERN_DEBUG ": " format "\n" , ## arg); } while (0)

// TRACE_DEBUG is for ftrace trace_printk (/sys/kernel/debug/tracing/trace)
#ifdef TRACE_DEBUG
  #pragma message "Compiling TRACE_DEBUG ..."
#else
  #pragma message "Compiling without trace debug ..."
#endif

#ifdef FIXED_BYTES_PER_PERIOD
  #pragma message "Compiling FIXED_BYTES_PER_PERIOD of timer/tasklet ..."
#else
  #pragma message "Compiling with adaptive bytes per period of timer/tasklet..."
#endif

// whether to use HZ to calculate hrtimer period as jiffy (and respective bytes per period)
// comment it from here to disable it (not currently controlled by script)
//~ #define USE_JIFFY_PERIOD
#ifdef USE_JIFFY_PERIOD
  #pragma message "Compiling USE_JIFFY_PERIOD ..."
#else
  #pragma message "Compiling without use of jiffy period ..."
#endif

// whether to simulate timing of period<=64 of hda-intel
// (pointer timing and values more closely resemble hda-intel;
// but as a whole driver is less reliable in that range)
//~ #define SIMULATE_PERIOD64F

#include <linux/init.h>
#include <linux/err.h>
#include <linux/platform_device.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/time.h>
#include <linux/wait.h>
#include <linux/hrtimer.h>
#include <linux/math64.h>
#include <linux/moduleparam.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/tlv.h>
#include <sound/pcm.h>
#include <sound/rawmidi.h>
#include <sound/info.h>
#include <sound/initval.h>

MODULE_AUTHOR("Jaroslav Kysela <perex@perex.cz>");
MODULE_DESCRIPTION("Dummy soundcard (/dev/null)");
MODULE_LICENSE("GPL");
MODULE_SUPPORTED_DEVICE("{{ALSA,Dummy soundcard}}");

#define MAX_PCM_DEVICES		4
#define MAX_PCM_SUBSTREAMS	128
#define MAX_MIDI_DEVICES	2

#if 0 /* emu10k1 emulation */
#define MAX_BUFFER_SIZE		(128 * 1024)
static int emu10k1_playback_constraints(struct snd_pcm_runtime *runtime)
{
	int err;
	err = snd_pcm_hw_constraint_integer(runtime, SNDRV_PCM_HW_PARAM_PERIODS);
	if (err < 0)
		return err;
	err = snd_pcm_hw_constraint_minmax(runtime, SNDRV_PCM_HW_PARAM_BUFFER_BYTES, 256, UINT_MAX);
	if (err < 0)
		return err;
	return 0;
}
#define add_playback_constraints emu10k1_playback_constraints
#endif

#if 0 /* RME9652 emulation */
#define MAX_BUFFER_SIZE		(26 * 64 * 1024)
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S32_LE
#define USE_CHANNELS_MIN	26
#define USE_CHANNELS_MAX	26
#define USE_PERIODS_MIN		2
#define USE_PERIODS_MAX		2
#endif

#if 0 /* ICE1712 emulation */
#define MAX_BUFFER_SIZE		(256 * 1024)
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S32_LE
#define USE_CHANNELS_MIN	10
#define USE_CHANNELS_MAX	10
#define USE_PERIODS_MIN		1
#define USE_PERIODS_MAX		1024
#endif

#if 0 /* UDA1341 emulation */
#define MAX_BUFFER_SIZE		(16380)
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S16_LE
#define USE_CHANNELS_MIN	2
#define USE_CHANNELS_MAX	2
#define USE_PERIODS_MIN		2
#define USE_PERIODS_MAX		255
#endif

#if 0 /* simple AC97 bridge (intel8x0) with 48kHz AC97 only codec */
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S16_LE
#define USE_CHANNELS_MIN	2
#define USE_CHANNELS_MAX	2
#define USE_RATE		SNDRV_PCM_RATE_48000
#define USE_RATE_MIN		48000
#define USE_RATE_MAX		48000
#endif

#if 0 /* CA0106 */
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S16_LE
#define USE_CHANNELS_MIN	2
#define USE_CHANNELS_MAX	2
#define USE_RATE		(SNDRV_PCM_RATE_48000|SNDRV_PCM_RATE_96000|SNDRV_PCM_RATE_192000)
#define USE_RATE_MIN		48000
#define USE_RATE_MAX		192000
#define MAX_BUFFER_SIZE		((65536-64)*8)
#define MAX_PERIOD_SIZE		(65536-64)
#define USE_PERIODS_MIN		2
#define USE_PERIODS_MAX		8
#endif

#if 1 /* patest_duplex test */
#define USE_FORMATS		SNDRV_PCM_FMTBIT_S16_LE
#define USE_CHANNELS_MIN	2
#define USE_CHANNELS_MAX	2
#define USE_RATE		SNDRV_PCM_RATE_8000|SNDRV_PCM_RATE_44100
#define USE_RATE_MIN		8000
#define USE_RATE_MAX		44100
#endif
/* _FRQUANT is frames quantization; simulates increase of pointer by the given quant*/
#define _FRQUANT 8

/* defaults */
#ifndef MAX_BUFFER_SIZE
#define MAX_BUFFER_SIZE		(64*1024)
#endif
#ifndef MAX_PERIOD_SIZE
#define MAX_PERIOD_SIZE		MAX_BUFFER_SIZE
#endif
#ifndef USE_FORMATS
#define USE_FORMATS 		(SNDRV_PCM_FMTBIT_U8 | SNDRV_PCM_FMTBIT_S16_LE)
#endif
#ifndef USE_RATE
#define USE_RATE		SNDRV_PCM_RATE_CONTINUOUS | SNDRV_PCM_RATE_8000_48000
#define USE_RATE_MIN		5500
#define USE_RATE_MAX		48000
#endif
#ifndef USE_CHANNELS_MIN
#define USE_CHANNELS_MIN 	1
#endif
#ifndef USE_CHANNELS_MAX
#define USE_CHANNELS_MAX 	2
#endif
#ifndef USE_PERIODS_MIN
#define USE_PERIODS_MIN 	1
#endif
#ifndef USE_PERIODS_MAX
#define USE_PERIODS_MAX 	1024
#endif
#ifndef add_playback_constraints
#define add_playback_constraints(x) 0
#endif
#ifndef add_capture_constraints
#define add_capture_constraints(x) 0
#endif

static int index[SNDRV_CARDS] = SNDRV_DEFAULT_IDX;	/* Index 0-MAX */
static char *id[SNDRV_CARDS] = SNDRV_DEFAULT_STR;	/* ID for this card */
static int enable[SNDRV_CARDS] = {1, [1 ... (SNDRV_CARDS - 1)] = 0};
static int pcm_devs[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 1};
static int pcm_substreams[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 8};
//static int midi_devs[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 2};
#ifdef CONFIG_HIGH_RES_TIMERS
// the message below will be output,
// if CONFIG_HIGH_RES_TIMERS has been enabled in the kernel
#pragma message "Compiling CONFIG_HIGH_RES_TIMERS ... "
static int hrtimer = 1;
#endif

//static int fake_buffer = 1;
// NOTE: IF WE INTEND TO WRITE TO
// DMA_AREA, fake_buffer CANNOT BE 1
// ELSE VERY SERIOUS CRASHES HAPPEN
static int fake_buffer = 0;

module_param_array(index, int, NULL, 0444);
MODULE_PARM_DESC(index, "Index value for dummy soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for dummy soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this dummy soundcard.");
module_param_array(pcm_devs, int, NULL, 0444);
MODULE_PARM_DESC(pcm_devs, "PCM devices # (0-4) for dummy driver.");
module_param_array(pcm_substreams, int, NULL, 0444);
MODULE_PARM_DESC(pcm_substreams, "PCM substreams # (1-128) for dummy driver.");
//module_param_array(midi_devs, int, NULL, 0444);
//MODULE_PARM_DESC(midi_devs, "MIDI devices # (0-2) for dummy driver.");
module_param(fake_buffer, bool, 0444);
MODULE_PARM_DESC(fake_buffer, "Fake buffer allocations.");
#ifdef CONFIG_HIGH_RES_TIMERS
module_param(hrtimer, bool, 0644);
MODULE_PARM_DESC(hrtimer, "Use hrtimer as the timer source.");
#endif

// seemingly, HWDEBUG_STACK is a problem (kernel freeze) with alsa-driver in debug mode
#define HWDEBUG_STACK 1

#if (HWDEBUG_STACK == 1)
#include <linux/perf_event.h>
#include <linux/hw_breakpoint.h>
struct perf_event * __percpu *sample_hbp;
struct perf_event_attr attr;
int dummy_hw_regged = 0;
#endif


static struct platform_device *devices[SNDRV_CARDS];

#define MIXER_ADDR_MASTER	0
#define MIXER_ADDR_LINE		1
#define MIXER_ADDR_MIC		2
#define MIXER_ADDR_SYNTH	3
#define MIXER_ADDR_CD		4
#define MIXER_ADDR_LAST		4

struct dummy_timer_ops {
	int (*create)(struct snd_pcm_substream *);
	void (*free)(struct snd_pcm_substream *);
	int (*prepare)(struct snd_pcm_substream *);
	int (*start)(struct snd_pcm_substream *);
	int (*stop)(struct snd_pcm_substream *);
	snd_pcm_uframes_t (*pointer)(struct snd_pcm_substream *);
};

struct snd_dummy {
	struct snd_card *card;
	struct snd_pcm *pcm;
	spinlock_t mixer_lock;
	int mixer_volume[MIXER_ADDR_LAST+1][2];
	int capture_source[MIXER_ADDR_LAST+1][2];
	const struct dummy_timer_ops *timer_ops;
};

/*
 * system timer interface
 */

struct dummy_systimer_pcm {
	spinlock_t lock;
	struct timer_list timer;
	unsigned long base_time;
	unsigned int frac_pos;	/* fractional sample position (based HZ) */
	unsigned int frac_period_rest;
	unsigned int frac_buffer_size;	/* buffer_size * HZ */
	unsigned int frac_period_size;	/* period_size * HZ */
	unsigned int rate;
	int elapsed;
	struct snd_pcm_substream *substream;
};

static void dummy_systimer_rearm(struct dummy_systimer_pcm *dpcm)
{
	dpcm->timer.expires = jiffies +
		(dpcm->frac_period_rest + dpcm->rate - 1) / dpcm->rate;
	add_timer(&dpcm->timer);
}

static void dummy_systimer_update(struct dummy_systimer_pcm *dpcm)
{
	unsigned long delta;

	delta = jiffies - dpcm->base_time;
	if (!delta)
		return;
	dpcm->base_time += delta;
	delta *= dpcm->rate;
	dpcm->frac_pos += delta;
	while (dpcm->frac_pos >= dpcm->frac_buffer_size)
		dpcm->frac_pos -= dpcm->frac_buffer_size;
	while (dpcm->frac_period_rest <= delta) {
		dpcm->elapsed++;
		dpcm->frac_period_rest += dpcm->frac_period_size;
	}
	dpcm->frac_period_rest -= delta;
}

static int dummy_systimer_start(struct snd_pcm_substream *substream)
{
	struct dummy_systimer_pcm *dpcm = substream->runtime->private_data;
	spin_lock(&dpcm->lock);
	dpcm->base_time = jiffies;
	dummy_systimer_rearm(dpcm);
	spin_unlock(&dpcm->lock);
	return 0;
}

static int dummy_systimer_stop(struct snd_pcm_substream *substream)
{
	struct dummy_systimer_pcm *dpcm = substream->runtime->private_data;
	spin_lock(&dpcm->lock);
	del_timer(&dpcm->timer);
	spin_unlock(&dpcm->lock);
	return 0;
}

static int dummy_systimer_prepare(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct dummy_systimer_pcm *dpcm = runtime->private_data;

	dbg("%s: dummy_systimer_prepare", __func__);

	dpcm->frac_pos = 0;
	dpcm->rate = runtime->rate;
	dpcm->frac_buffer_size = runtime->buffer_size * HZ;
	dpcm->frac_period_size = runtime->period_size * HZ;
	dpcm->frac_period_rest = dpcm->frac_period_size;
	dpcm->elapsed = 0;

	return 0;
}

static void dummy_systimer_callback(unsigned long data)
{
	struct dummy_systimer_pcm *dpcm = (struct dummy_systimer_pcm *)data;
	unsigned long flags;
	int elapsed = 0;

	dbg("%s: dummy_systimer_callback", __func__);

	spin_lock_irqsave(&dpcm->lock, flags);
	dummy_systimer_update(dpcm);
	dummy_systimer_rearm(dpcm);
	elapsed = dpcm->elapsed;
	dpcm->elapsed = 0;
	spin_unlock_irqrestore(&dpcm->lock, flags);
	if (elapsed)
		snd_pcm_period_elapsed(dpcm->substream);
}

static snd_pcm_uframes_t
dummy_systimer_pointer(struct snd_pcm_substream *substream)
{
	struct dummy_systimer_pcm *dpcm = substream->runtime->private_data;
	snd_pcm_uframes_t pos;

	spin_lock(&dpcm->lock);
	dummy_systimer_update(dpcm);
	pos = dpcm->frac_pos / HZ;
	spin_unlock(&dpcm->lock);
	return pos;
}

static int dummy_systimer_create(struct snd_pcm_substream *substream)
{
	struct dummy_systimer_pcm *dpcm;

	dpcm = kzalloc(sizeof(*dpcm), GFP_KERNEL);
	if (!dpcm)
		return -ENOMEM;
	substream->runtime->private_data = dpcm;
	init_timer(&dpcm->timer);
	dpcm->timer.data = (unsigned long) dpcm;
	dpcm->timer.function = dummy_systimer_callback;
	spin_lock_init(&dpcm->lock);
	dpcm->substream = substream;
	return 0;
}

static void dummy_systimer_free(struct snd_pcm_substream *substream)
{
	kfree(substream->runtime->private_data);
}

static struct dummy_timer_ops dummy_systimer_ops = {
	.create =	dummy_systimer_create,
	.free =		dummy_systimer_free,
	.prepare =	dummy_systimer_prepare,
	.start =	dummy_systimer_start,
	.stop =		dummy_systimer_stop,
	.pointer =	dummy_systimer_pointer,
};

#ifdef CONFIG_HIGH_RES_TIMERS
/*
 * hrtimer interface
 */

struct dummy_hrtimer_pcm {
	ktime_t base_time;
	ktime_t period_time;
	ktime_t ss_dly_time[2]; /* stream start delay: now an array, as there are two steps with differences from period */
	ktime_t timercb_time;
	atomic_t running;
	atomic_t startseen; /* flag - skip _elapsed if stream not yet seen in callback; also to manage different ss_dly_time */
	int bufswitch; /* switch for writing (capture buffer only) */
	int bufcount; /* also for writing (capture buffer only) */
  int frquant; /* frame quantization */
  atomic_t inTimer; /* flag (to inform .pointer if it's called from callback) */
	struct hrtimer timer;
	struct tasklet_struct tasklet;
	struct snd_pcm_substream *substream;
  unsigned int pcm_bpp; /* bytes per period */
	unsigned int pcm_buffer_size;
	unsigned int pcm_period_size;
	unsigned int pcm_irq_pos;	/* IRQ position */
	unsigned int pcm_buf_posB;	/* position in buffer [bytes] */
	unsigned int pcm_buf_posF;	/* position in buffer [frames] */
	unsigned int pcm_buf_tot;	/* total bytes through buffer (like buf_pos, but isn't wrapped)  debug counter */
};

#ifdef TRACE_DEBUG
// #define dbgplayvars(label) do { } while (0)
/**/ // must use stream comment for multiline macros ; also trace_printk
#define dbgplayvars(label) do { trace_printk( ":  fwr:%s \
 fSB:%d, iBFP:%d, tfr:%d, wdbp:%d,\
 tbEx:%d, tbExR:%d, fTW:%d, bTWPWR:%d, bwBR:%d,\
 bTW:%d, pr:%d-d:%d-e%d/%d,\
 apt:%ld;%ld hpt:%ld;%ld pav:%ld phwav:%ld\
 pbpos:%d, plyb:%d\n" , \
label, \
4, \
-1, -1, -1, \
-1, -1, -1, -1, -1, \
bytesToWrite, snd_pcm_playback_ready(ss), snd_pcm_playback_data(ss), snd_pcm_playback_empty(ss), -1, \
ss->runtime->control->appl_ptr, ss->runtime->control->appl_ptr*frameSizeBytes, ss->runtime->status->hw_ptr, ss->runtime->status->hw_ptr*frameSizeBytes, snd_pcm_playback_avail(ss->runtime), snd_pcm_playback_hw_avail(ss->runtime), \
dpcm->pcm_buf_posB, dpcm->pcm_buf_tot \
); } while (0)
//~ #define dbgcaptvars(label) do { } while (0)
/**/ // must use stream comment for multiline macros ; also trace_printk
#define dbgcaptvars(label) do { trace_printk( ": tmr_fnc_capt:%s \
 imrf:%d imrd:%d bWr:%d bsl:%d \
 pbpos:%d irqps:%d hd:%d tl:%d \
 sz:%d tlR:%d hdW:%d \
 cpw:%d Wrp: %d-%d st:%d \
 apt:%ld;%ld hpt:%ld;%ld cav:%ld chwav:%ld pbtot:%d\n" , \
label, \
-1, -1, bytesToWrite, -1, \
dpcm->pcm_buf_posB, dpcm->pcm_irq_pos, -1, -1, \
-1, -1, -1, \
-1, -1, -1, ss->runtime->status->state, \
ss->runtime->control->appl_ptr, ss->runtime->control->appl_ptr*4, ss->runtime->status->hw_ptr, ss->runtime->status->hw_ptr*4, snd_pcm_capture_avail(ss->runtime), snd_pcm_capture_hw_avail(ss->runtime), \
dpcm->pcm_buf_tot \
); } while (0)
#else
  #define dbgplayvars(label) do { } while (0)
  #define dbgcaptvars(label) do { } while (0)
#endif


#if (HWDEBUG_STACK == 1)
static void sample_hbp_handler(struct perf_event *bp,
             struct perf_sample_data *data,
             struct pt_regs *regs)
{
  struct perf_event_attr attr = bp->attr;
  struct hw_perf_event   hw  = bp->hw;
  char hwirep[8];
  //it looks like printing %llu, data->type here causes segfault/oops when `cat` runs?
  // apparently, hw.interrupts changes depending on read/write access (1 or 2)
  // when only HW_BREAKPOINT_W, getting hw.interrupts == 1 always;
  // only HW_BREAKPOINT_R - fails for me
  // when both, hw.interrupts is either 1 or 2
  // defined in include/linux/hw_breakpoint.h:
  // HW_BREAKPOINT_R		= 1,  HW_BREAKPOINT_W		= 2,
  // but here it seems to be the opposite? Not always?
  if (attr.bp_type == HW_BREAKPOINT_W) {
    strcpy(hwirep, "_W"); // regardless of hw.interrupts, which would be 1 here
  } else {
    if (hw.interrupts == HW_BREAKPOINT_R) {
      strcpy(hwirep, "_R");
    } else if (hw.interrupts == HW_BREAKPOINT_W) {
      strcpy(hwirep, "_W");
    } else {
      strcpy(hwirep, "__");
    }
  }
  printk("+--- p.dma[0] is accessed %s (.bp_type %d, .type %d, state %d htype %d hwi %llu ) ---+\n", hwirep, attr.bp_type, attr.type, hw.state, hw.info.type, hw.interrupts);
  dump_stack();
  //explicit cast needed to avoid "warning: cast to pointer from integer of different size"
  print_hex_dump(KERN_DEBUG, "b p.dma: ", DUMP_PREFIX_ADDRESS, 16, 1, (void*)(unsigned long)attr.bp_addr, 16, false);

}
#endif


// this is the tasklet:
static void dummy_hrtimer_pcm_elapsed(unsigned long priv)
{
	struct dummy_hrtimer_pcm *dpcm = (struct dummy_hrtimer_pcm *)priv;
	struct snd_pcm_runtime *runtime = dpcm->substream->runtime;
  struct snd_pcm_substream *ss = dpcm->substream;
  u64 delta;
  u32 pos;
  u32 posb;
  int bytesToWrite;
  int frameSizeBytes;
  int doElapsed = 0;
  unsigned long flags;
  frameSizeBytes	= frames_to_bytes(ss->runtime, 1);

	if (atomic_read(&dpcm->running)) {

    //~ #ifdef USE_JIFFY_PERIOD // not needed here; posb is relative to the sampling rate, and to the actual timer period -> and will return appropriate ammount of bytes, regardless if we use a period of jiffy, or a period scaled to period_size
    //~ #else
    // NB: pos will be calculated in frames; because delta gets
    // compared to runtime->rate (44100), which is frames (samples*channels) per second
    delta = ktime_us_delta(dpcm->timercb_time, //hrtimer_cb_get_time(&dpcm->timer),
               dpcm->base_time);
    delta = div_u64(delta * runtime->rate + 999999, 1000000);
    div_u64_rem(delta, runtime->buffer_size, &pos);
    pos = (((pos-1)/dpcm->frquant)*dpcm->frquant+1); // quantize pos
    dpcm->pcm_buf_posF = pos;

    atomic_set(&dpcm->inTimer, 1); // will effect playback stream, too
    posb = frames_to_bytes(runtime, pos);
    //~ #endif

    #ifdef FIXED_BYTES_PER_PERIOD
    bytesToWrite = dpcm->pcm_bpp;
    #else
    //~ if (bytesToWrite < 0) bytesToWrite += dpcm->pcm_buf_posB; // nope, this instead:
    if (posb >=dpcm->pcm_buf_posB)
      bytesToWrite = posb - dpcm->pcm_buf_posB;
    else
      bytesToWrite = dpcm->pcm_buffer_size - dpcm->pcm_buf_posB+posb;
    #endif

    // add "buffer marks" on the capture stream
		if (dpcm->substream->stream == SNDRV_PCM_STREAM_CAPTURE) { //
			unsigned int this_period_start = (dpcm->bufcount)*dpcm->pcm_period_size;
			unsigned int this_period_lastfr = (dpcm->bufcount+1)*dpcm->pcm_period_size-frameSizeBytes;
			int zerostart_delta = dpcm->pcm_buf_posB - (this_period_start);
			int lastfr_delta = (posb > dpcm->pcm_buf_posB) ? posb - this_period_lastfr : dpcm->pcm_buffer_size + posb - this_period_lastfr;
      doElapsed = ( dpcm->pcm_buf_posF >= ((dpcm->bufcount + 1)*runtime->period_size)%runtime->buffer_size );
			//~ printk("bufcount: %d, pcm_buf_posB %d, pcm_buf_posF %d, posb %d, tplf %d, zd %d, ld %d, doElap %d, dma_area %p\n", dpcm->bufcount, dpcm->pcm_buf_posB, dpcm->pcm_buf_posF, posb, this_period_lastfr, zerostart_delta, lastfr_delta, doElapsed, dpcm->substream->runtime->dma_area);
			local_irq_save(flags);    /* interrupts are now disabled; local cpu only! */
			if(dpcm->bufcount == 0){//(dpcm->pcm_buf_posB == dpcm->pcm_irq_pos){//(dpcm->pcm_buf_posB + bytesToWrite >= dpcm->pcm_buffer_size) {
				dpcm->bufswitch = !dpcm->bufswitch;
				//~ memset(dpcm->substream->runtime->dma_area, 0, dpcm->pcm_buffer_size); // blank once? NOPE - if previous period is "shipped" delayed, then it will be completely blanked
			}
			memset(dpcm->substream->runtime->dma_area+dpcm->bufcount*dpcm->pcm_period_size, (dpcm->bufswitch) ? 245 : 11 , dpcm->pcm_period_size); // "background"
			memset(dpcm->substream->runtime->dma_area+this_period_lastfr, 205, frameSizeBytes); // bit longer peak at end of period snippet; done first so it is overwritten by shorter pulse if at same spot
			if(zerostart_delta >= frameSizeBytes) { memset(dpcm->substream->runtime->dma_area+this_period_start, 0, zerostart_delta); } // blank only in-between snippet if it exists ; is forward-only (when posb>period)
			if(zerostart_delta >= 0) {
				memset(dpcm->substream->runtime->dma_area+dpcm->pcm_buf_posB, 26, frameSizeBytes); // shorter peak - wherever pcm_buf_posB is; was 230, make it "positive"
			}
			if(lastfr_delta <= 0) {
				memset(dpcm->substream->runtime->dma_area+posb, 26, frameSizeBytes); // shorter peak - wherever posb is; was 230, make it "positive"
			}
			if(dpcm->bufcount != 0){//
			} else {
				memset(dpcm->substream->runtime->dma_area+(unsigned int)(16*dpcm->bufcount), 150, frameSizeBytes); // longest peak - start of buffer size; had this run each time, the pulses at start would be 4 frames (16 bytes) apart - but even then, max two can be shown, since after _elapsed; that particular section is transferred to userspace, and subsequent writes to that area do not matter; also would overwrite possible single-frame zerostart_delta
			}
			local_irq_restore(flags); /* interrupts are restored to their previous state */
      dbgcaptvars("A");
    } else { // SNDRV_PCM_STREAM_PLAYBACK
      print_hex_dump(KERN_DEBUG, "  p.dma: ", DUMP_PREFIX_ADDRESS, 16, 1, dpcm->substream->runtime->dma_area, 16, false);
      dbgplayvars("D");
    }

    #ifdef FIXED_BYTES_PER_PERIOD
    dpcm->pcm_buf_posB += bytesToWrite;
    dpcm->pcm_buf_posB %= dpcm->pcm_buffer_size;
    #else
    dpcm->pcm_buf_posB = frames_to_bytes(runtime, pos); // pos already wrapped to pcm_buffer_size (in frames)!
    #endif

    dpcm->pcm_irq_pos += bytesToWrite;
    #ifdef USE_JIFFY_PERIOD
    doElapsed = (dpcm->pcm_irq_pos >= dpcm->pcm_period_size);
    #else
    doElapsed = 1; //doElapsed; //1; // adding additional check (from above)
    #endif
    dpcm->pcm_irq_pos %= dpcm->pcm_period_size;
		dpcm->bufcount = (dpcm->bufcount + 1) % (dpcm->pcm_buffer_size/dpcm->pcm_period_size); // must be set *after* calcs!!! so here (even if it is not used in playback)
    //~ dbg("%s: pos: %u", __func__, pos);

		if (doElapsed) snd_pcm_period_elapsed(dpcm->substream);
    atomic_set(&dpcm->inTimer, 0);
	}
}

/*
* here, we approximate the timer callback to an IRQ handler;
* since the first callback now can occur before a period
* has expired (due to implementing a quarter period delay),
* we use dpcm->startseen to prevent _elapsed call via tasklet
* (which somewhat approximates azx_position_ok() in
*  azx_interrupt() - in hda-intel)
*/
static enum hrtimer_restart dummy_hrtimer_callback(struct hrtimer *timer)
{
	struct dummy_hrtimer_pcm *dpcm;

	//~ dbg("%s: dummy_hrtimer_callback", __func__);

	dpcm = container_of(timer, struct dummy_hrtimer_pcm, timer);
	dpcm->timercb_time = ktime_get();
	if (!atomic_read(&dpcm->running))
		return HRTIMER_NORESTART;
  if (!atomic_read(&dpcm->startseen)) {
    atomic_set(&dpcm->startseen, 1);
    // we do not want to call tasklet here, because
    // we know we definitely have not reached one period
    // yet at this time; if it is enabled, then the very first
    // buffer start pulse will be missing in the capture
    //~ tasklet_schedule(&dpcm->tasklet);
    //~ dpcm->base_time = hrtimer_cb_get_time(&dpcm->timer); // crashes severely!
    //~ dpcm->base_time = hrtimer_cb_get_time(timer); // crashes severely!
    hrtimer_forward_now(timer, dpcm->ss_dly_time[1]); // step two delay
  } else {
    tasklet_schedule(&dpcm->tasklet);
		hrtimer_forward_now(timer, dpcm->period_time);
  }
	return HRTIMER_RESTART;
}

static int dummy_hrtimer_start(struct snd_pcm_substream *substream)
{
	struct dummy_hrtimer_pcm *dpcm = substream->runtime->private_data;

	dpcm->base_time = hrtimer_cb_get_time(&dpcm->timer);
  // NB: moving base_time forward/ahead here (ktime_add with positive)
  // causes a fewer frames per period - and very quickly results with kernel panic/freeze/reboot!
  // moving it behind (ktime_sub with positive) increases the
  // measured frames per period, and typically no crash then
	//~ if(substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
	//~ dpcm->base_time = ktime_sub(dpcm->base_time, dpcm->ss_dly_time[0]); // ktime_add(hrtimer_cb_get_time(&dpcm->timer), dpcm->ss_dly_time[0]);
	//~ }
  //~ dpcm->base_time = ktime_add(dpcm->base_time, dpcm->ss_dly_time[0]); // causes XRUN?
  // also re-adjust step two with step one
  if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
    #ifdef SIMULATE_PERIOD64F
    dpcm->base_time = (substream->runtime->period_size <= 64)
                      ? ktime_add(dpcm->base_time, ktime_sub(ktime_add(dpcm->ss_dly_time[0], dpcm->ss_dly_time[1]), ktime_add(dpcm->period_time, dpcm->period_time) ))
                      : ktime_sub(dpcm->base_time, ktime_sub(dpcm->period_time, ktime_add(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]) ));
  //~ trace_printk("(%d) b:%lld.%.9ld (%lld)\n", substream->stream, (long long)ktime_to_timespec(dpcm->base_time).tv_sec, ktime_to_timespec(dpcm->base_time).tv_nsec, ktime_to_ns(dpcm->base_time)) ;
    #else
    dpcm->base_time = ktime_sub(dpcm->base_time, ktime_sub(dpcm->period_time, ktime_add(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]) ));
    dpcm->base_time = ktime_sub(dpcm->base_time, ktime_set(0, 150*1000ULL)); // additional for playback, as I'm short on frames in PortAudio poll?
    #endif
  } // end if SNDRV_PCM_STREAM_PLAYBACK
  trace_printk("(%d)\n", substream->stream);

	hrtimer_start(&dpcm->timer, dpcm->ss_dly_time[0], HRTIMER_MODE_REL); // was dpcm->period_time; step one delay
	atomic_set(&dpcm->running, 1);
	return 0;
}

static int dummy_hrtimer_stop(struct snd_pcm_substream *substream)
{
	struct dummy_hrtimer_pcm *dpcm = substream->runtime->private_data;

	atomic_set(&dpcm->running, 0);
	hrtimer_cancel(&dpcm->timer);
	return 0;
}

static inline void dummy_hrtimer_sync(struct dummy_hrtimer_pcm *dpcm)
{
	tasklet_kill(&dpcm->tasklet);
}

static snd_pcm_uframes_t
dummy_hrtimer_pointer(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct dummy_hrtimer_pcm *dpcm = runtime->private_data;
	u32 pos;
  // originally, delta calc was here; (now moved in the tasklet)
  // actually, moving it back here again - for accuracy,
  // since there is no other timing base
	u64 delta;

  // bail out early - we don't want to increase pointer if called from tasklet/callback (it's calced there already); actually, handle as case (instead of early return), so we include the printk regardless; simply return last available value
  if(!atomic_read(&dpcm->inTimer)) {
	delta = ktime_us_delta(hrtimer_cb_get_time(&dpcm->timer),
			       dpcm->base_time);
	delta = div_u64(delta * runtime->rate + 999999, 1000000);
	div_u64_rem(delta, runtime->buffer_size, &pos);
	pos = (((pos-1)/dpcm->frquant)*dpcm->frquant+1); // quantize pos
	dpcm->pcm_buf_posF = pos;
  } else {
    pos = dpcm->pcm_buf_posF;
  }
  //~ pos = bytes_to_frames(runtime, dpcm->pcm_buf_posB);
  //~ dbg("%s: pos: %u", __func__, pos);
  // report in frames directly (calc in bytes elsewhere);
  // function name is auto-printed by trace_printk - but not in function_graph!
  // also report __builtin_return_address(2) caller - can distinguish if in _elapsed
  trace_printk("_pointer: %d (%d) a:%lu h:%lu d:%ld av:%ld hav:%ld ss:%lu hb:%lu hi:%lu c:%pS\n", pos, substream->stream, substream->runtime->control->appl_ptr, substream->runtime->status->hw_ptr, substream->runtime->delay, (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) ? snd_pcm_playback_avail(substream->runtime) : snd_pcm_capture_avail(substream->runtime), (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) ? snd_pcm_playback_hw_avail(substream->runtime) : snd_pcm_capture_hw_avail(substream->runtime), substream->runtime->silence_size, substream->runtime->hw_ptr_base, substream->runtime->hw_ptr_interrupt, __builtin_return_address(2));
  //~ dump_stack();

	return pos;
}

static int dummy_hrtimer_prepare(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct dummy_hrtimer_pcm *dpcm = runtime->private_data;
  #ifdef USE_JIFFY_PERIOD
  #else
	unsigned int period;
	unsigned int rate = runtime->rate;
	// for offsets - time duration of 16 and 48 frames
  // on my platform, this gives nsecs 16f: 70638 48f: 17129 128f: 78140;
  // wrong because on my platform UINT_MAX == ULONG_MAX (32 bit). and ULLONG_MAX is 64 bit!
  // yet, div_u64 takes first arg as u64, which is unsigned long, so not 64 bit, but 32 on my platform?
  // Nope - still should use div_u64 (else WARNING: "__udivdi3" [.ko] undefined!);
  // but 1000000000 must be ULL, so result of multiplication is also ULL!
	//~ unsigned long nsecs16f = div_u64(16UL * 1000000000UL + rate - 1, rate);
	//~ unsigned long nsecs48f = div_u64(48UL * 1000000000UL + rate - 1, rate);
	unsigned long nsecs100u = 100*1000ULL;
	unsigned long nsecs_step1 = nsecs100u;
	unsigned long nsecs16f = div_u64(16UL * 1000000000ULL + rate - 1, rate);
	unsigned long nsecs48f = div_u64(48UL * 1000000000ULL + rate - 1, rate);
  #endif
	long sec;
	unsigned long nsecs;
  int bps;

	dummy_hrtimer_sync(dpcm);
  #ifdef USE_JIFFY_PERIOD
  sec = 0L; // we know that jiffies will be less than a second
  nsecs = div_u64(1000000000UL + HZ - 1, HZ);
  #else
	period = runtime->period_size;
	sec = period / rate;
	period %= rate;
	//~ nsecs = div_u64((u64)period * 1000000000UL + rate - 1, rate);
	nsecs = div_u64(period * 1000000000ULL + rate - 1, rate);
  #endif
	dpcm->period_time = ktime_set(sec, nsecs);
  // stream start delay: in two steps; and depending on period
  // taking first (ASAP) schedule to be 100 us;
  dpcm->ss_dly_time[0] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      ? ktime_set(0L, nsecs_step1) // capture step one, same regardless of (period <= 64)
                      : (period <= 64) ? ktime_set(0L, nsecs_step1+nsecs16f) : ktime_set(0L, nsecs_step1); // playback step one
  #ifdef SIMULATE_PERIOD64F
  dpcm->ss_dly_time[1] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      ? ktime_set(sec, nsecs) // capture step two, same regardless of (period <= 64)
                      : (period <= 64) ? ktime_set(sec, nsecs+nsecs16f) : ktime_set(sec, nsecs-nsecs48f); // playback step two
  #else
  dpcm->ss_dly_time[1] = (substream->stream == SNDRV_PCM_STREAM_CAPTURE)
                      ? ktime_set(sec, nsecs) // capture step two, same regardless of (period <= 64)
                      : (period <= 64) ? ktime_set(sec, nsecs) : ktime_set(sec, nsecs-nsecs48f); // playback step two
  #endif
  // adjust step two with step one
  dpcm->ss_dly_time[1] = ktime_sub(dpcm->ss_dly_time[1], dpcm->ss_dly_time[0]);
  // mark stream as not yet "seen":
  atomic_set(&dpcm->startseen, 0);
  atomic_set(&dpcm->inTimer, 0);
  // make the frame quant 16th of the period size in frames:? nah:
  //~ dpcm->frquant = (runtime->period_size + (16-1))/16;
  dpcm->frquant = _FRQUANT; // keep like this
	dpcm->pcm_buffer_size = snd_pcm_lib_buffer_bytes(substream);
	dpcm->pcm_period_size = snd_pcm_lib_period_bytes(substream);
	dpcm->pcm_irq_pos = 0;
	dpcm->pcm_buf_posB = 0;
	dpcm->pcm_buf_posF = 0;
	dpcm->pcm_buf_tot = 0;
	dpcm->bufswitch = 0;
	dpcm->bufcount = 0;

	bps = snd_pcm_format_width(runtime->format) * runtime->rate *
		runtime->channels / 8;

  #ifdef USE_JIFFY_PERIOD
  dpcm->pcm_bpp = bps/HZ;
  #else
  // NOTE: here the period time is specifically calculated
  // to match the time it takes period_size frames (= pcm_period_size bytes)
  // to transfer at the requested rate
  // thus, bytes per period will always be pcm_period_size bytes!
  // we therefore don't really need an extra variable,
  // however, we set it here for formality's sake:
  dpcm->pcm_bpp = dpcm->pcm_period_size;
  #endif

	snd_pcm_format_set_silence(runtime->format, runtime->dma_area,
			bytes_to_samples(runtime, runtime->dma_bytes));

	dbg("  >%s: ss:%d bps:%d bpp: %d, HZ: %d, buffer_size: %d (runtime: %ld), pcm_period_size: %d, dma_bytes %d, dma_samples %d, fmt|nch|rt %d|%d|%d", __func__, substream->stream, bps, dpcm->pcm_bpp, HZ, dpcm->pcm_buffer_size, runtime->buffer_size, dpcm->pcm_period_size, runtime->dma_bytes, bytes_to_samples(runtime, runtime->dma_bytes), snd_pcm_format_width(runtime->format), runtime->channels, runtime->rate);
  dbg("  >period sec %ld nsecs %lu ; start_th: %ld, stop_th: %ld, silence_th: %ld, silence_sz: %ld, boundary: %ld, sil_start: %ld, sil_fill: %ld", sec, nsecs, runtime->start_threshold, runtime->stop_threshold, runtime->silence_threshold, runtime->silence_size, runtime->boundary, runtime->silence_start, runtime->silence_filled );
  dbg("  >nsecs 16f: %lu 48f: %lu ss_dly[0]: %lld ss_dly[1]: %lld\n", nsecs16f, nsecs48f,  ktime_to_ns(dpcm->ss_dly_time[0]),  ktime_to_ns(dpcm->ss_dly_time[1]));

	return 0;
}

static int dummy_hrtimer_create(struct snd_pcm_substream *substream)
{
	struct dummy_hrtimer_pcm *dpcm;

	dpcm = kzalloc(sizeof(*dpcm), GFP_KERNEL);
	if (!dpcm)
		return -ENOMEM;
	substream->runtime->private_data = dpcm;
	hrtimer_init(&dpcm->timer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
	dpcm->timer.function = dummy_hrtimer_callback;
	dpcm->substream = substream;
	atomic_set(&dpcm->running, 0);
	tasklet_init(&dpcm->tasklet, dummy_hrtimer_pcm_elapsed,
		     (unsigned long)dpcm);
	return 0;
}

static void dummy_hrtimer_free(struct snd_pcm_substream *substream)
{
	struct dummy_hrtimer_pcm *dpcm = substream->runtime->private_data;
	dummy_hrtimer_sync(dpcm);
	kfree(dpcm);
}

static struct dummy_timer_ops dummy_hrtimer_ops = {
	.create =	dummy_hrtimer_create,
	.free =		dummy_hrtimer_free,
	.prepare =	dummy_hrtimer_prepare,
	.start =	dummy_hrtimer_start,
	.stop =		dummy_hrtimer_stop,
	.pointer =	dummy_hrtimer_pointer,
};

#endif /* CONFIG_HIGH_RES_TIMERS */

/*
 * PCM interface
 */

static int dummy_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
  /*
  * this section now made to resemble azx_pcm_trigger;
  * utilizing snd_pcm_group_for_each_entry (in case of
  * full-duplex snd_pcm_link)
  */
  struct snd_pcm_substream *s;
  int start, nsync = 0;
	struct snd_dummy *dummy = snd_pcm_substream_chip(substream);

	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
	case SNDRV_PCM_TRIGGER_RESUME:
		//~ return dummy->timer_ops->start(substream);
    start = 1;
    #if (HWDEBUG_STACK == 1)
    if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
      attr.bp_addr = (uintptr_t) &(substream->runtime->dma_area[0]); // playback dma_area now exists/available
      //~ attr.bp_addr = (uintptr_t) substream->runtime->dma_area; // same address obtained as above
      sample_hbp = register_wide_hw_breakpoint(&attr, (perf_overflow_handler_t)sample_hbp_handler);
      if (IS_ERR((void __force *)sample_hbp)) {
        int ret = PTR_ERR((void __force *)sample_hbp);
        printk(KERN_INFO "Breakpoint registration failed %d (0x%p)\n", ret, (void*)(uintptr_t)attr.bp_addr);
        //~ return ret; // don't return failure here, let it go;
        dummy_hw_regged = 0; // record instead
      } else {
        dummy_hw_regged = 1;
        printk(KERN_INFO "HW Breakpoint for p.dma[0] write installed (0x%p)\n", (void*)(uintptr_t)attr.bp_addr);
      }
    }
    #endif
    break;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		//~ return dummy->timer_ops->stop(substream);
    #if (HWDEBUG_STACK == 1)
    if ((substream->stream == SNDRV_PCM_STREAM_PLAYBACK) && (dummy_hw_regged == 1)) {
      unregister_wide_hw_breakpoint(sample_hbp);
      printk(KERN_INFO "HW Breakpoint for p.dma[0] uninstalled\n");
    }
    #endif
		start = 0;
    break;
	default:
		return -EINVAL;
	}

	snd_pcm_group_for_each_entry(s, substream) {
    printk("_for_each_entry1: s %p %d %p sub %p %d %p\n", s, s->stream, s->pcm->card, substream, substream->stream, substream->pcm->card);
		if (s->pcm->card != substream->pcm->card)
			continue;
		nsync++;
		snd_pcm_trigger_done(s, substream);
	}

  //~ spin_lock(&chip->reg_lock);
	snd_pcm_group_for_each_entry(s, substream) {
    printk("_for_each_entry2: s %p %d %p sub %p %d %p\n", s, s->stream, s->pcm->card, substream, substream->stream, substream->pcm->card);
		if (s->pcm->card != substream->pcm->card)
			continue;
		//~ azx_dev = get_azx_dev(s);
		if (start) {
			//~ azx_dev->start_wallclk = azx_readl(chip, WALLCLK);
			//~ azx_stream_start(chip, azx_dev);
      dummy->timer_ops->start(s);
		} else {
			//~ azx_stream_stop(chip, azx_dev);
      dummy->timer_ops->stop(s);
		}
		//~ azx_dev->running = start; // handled in hrtimer_start/_stop
	}
	//~ spin_unlock(&chip->reg_lock);
  /* // skip waiting section
	if (start) {
		if (nsync == 1)
			return 0;
    // wait until all FIFOs get ready /
	} else {
    // wait until all RUN bits are cleared /
  } */

  /* // skip reset SYNC bits section
  if (nsync > 1) {
		// reset SYNC bits /
	} */

	//~ return -EINVAL;
	return 0;
}

static int dummy_pcm_prepare(struct snd_pcm_substream *substream)
{
	struct snd_dummy *dummy = snd_pcm_substream_chip(substream);

	dbg("%s: dummy_pcm_prepare", __func__);
	return dummy->timer_ops->prepare(substream);
}

static snd_pcm_uframes_t dummy_pcm_pointer(struct snd_pcm_substream *substream)
{
	struct snd_dummy *dummy = snd_pcm_substream_chip(substream);

	return dummy->timer_ops->pointer(substream);
}

static struct snd_pcm_hardware dummy_pcm_hardware = {
	.info =			(SNDRV_PCM_INFO_MMAP |
				 SNDRV_PCM_INFO_INTERLEAVED |
				 SNDRV_PCM_INFO_RESUME |
				 SNDRV_PCM_INFO_MMAP_VALID),
	.formats =		USE_FORMATS,
	.rates =		USE_RATE,
	.rate_min =		USE_RATE_MIN,
	.rate_max =		USE_RATE_MAX,
	.channels_min =		USE_CHANNELS_MIN,
	.channels_max =		USE_CHANNELS_MAX,
	.buffer_bytes_max =	MAX_BUFFER_SIZE,
	.period_bytes_min =	64,
	.period_bytes_max =	MAX_PERIOD_SIZE,
	.periods_min =		USE_PERIODS_MIN,
	.periods_max =		USE_PERIODS_MAX,
	.fifo_size =		0,
};

static int dummy_pcm_hw_params(struct snd_pcm_substream *substream,
			       struct snd_pcm_hw_params *hw_params)
{
	if (fake_buffer) {
		/* runtime->dma_bytes has to be set manually to allow mmap */
		substream->runtime->dma_bytes = params_buffer_bytes(hw_params);
		return 0;
	}
	return snd_pcm_lib_malloc_pages(substream,
					params_buffer_bytes(hw_params));
}

static int dummy_pcm_hw_free(struct snd_pcm_substream *substream)
{
	if (fake_buffer)
		return 0;
	return snd_pcm_lib_free_pages(substream);
}

static int dummy_pcm_open(struct snd_pcm_substream *substream)
{
	struct snd_dummy *dummy = snd_pcm_substream_chip(substream);
	struct snd_pcm_runtime *runtime = substream->runtime;
	int err;

	dummy->timer_ops = &dummy_systimer_ops;
#ifdef CONFIG_HIGH_RES_TIMERS
	if (hrtimer)
		dummy->timer_ops = &dummy_hrtimer_ops;
#endif

	err = dummy->timer_ops->create(substream); // this calls dummy_hrtimer_create, where dpcm->substream is set to substream
	if (err < 0)
		return err;

	runtime->hw = dummy_pcm_hardware;
	//dpcm->substream = substream; // already done in _create
	if (substream->pcm->device & 1) {
		runtime->hw.info &= ~SNDRV_PCM_INFO_INTERLEAVED;
		runtime->hw.info |= SNDRV_PCM_INFO_NONINTERLEAVED;
	}
	if (substream->pcm->device & 2)
		runtime->hw.info &= ~(SNDRV_PCM_INFO_MMAP |
				      SNDRV_PCM_INFO_MMAP_VALID);

	if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK)
		err = add_playback_constraints(substream->runtime);
	else
		err = add_capture_constraints(substream->runtime);
	if (err < 0) {
		dummy->timer_ops->free(substream);
		return err;
	}
	return 0;
}

static int dummy_pcm_close(struct snd_pcm_substream *substream)
{
	struct snd_dummy *dummy = snd_pcm_substream_chip(substream);
	dummy->timer_ops->free(substream);
	return 0;
}

/*
 * dummy buffer handling
 */

static void *dummy_page[2];

static void free_fake_buffer(void)
{
	if (fake_buffer) {
		int i;
		for (i = 0; i < 2; i++)
			if (dummy_page[i]) {
				free_page((unsigned long)dummy_page[i]);
				dummy_page[i] = NULL;
			}
	}
}

static int alloc_fake_buffer(void)
{
	int i;

	if (!fake_buffer)
		return 0;
	for (i = 0; i < 2; i++) {
		dummy_page[i] = (void *)get_zeroed_page(GFP_KERNEL);
		if (!dummy_page[i]) {
			free_fake_buffer();
			return -ENOMEM;
		}
	}
	return 0;
}

static int dummy_pcm_copy(struct snd_pcm_substream *substream,
			  int channel, snd_pcm_uframes_t pos,
			  void __user *dst, snd_pcm_uframes_t count)
{
	dbg("%s: dummy_pcm_copy", __func__);
	return 0; /* do nothing */
}

static int dummy_pcm_silence(struct snd_pcm_substream *substream,
			     int channel, snd_pcm_uframes_t pos,
			     snd_pcm_uframes_t count)
{
	return 0; /* do nothing */
}

static struct page *dummy_pcm_page(struct snd_pcm_substream *substream,
				   unsigned long offset)
{
	return virt_to_page(dummy_page[substream->stream]); /* the same page */
}

static struct snd_pcm_ops dummy_pcm_ops = {
	.open =		dummy_pcm_open,
	.close =	dummy_pcm_close,
	.ioctl =	snd_pcm_lib_ioctl,
	.hw_params =	dummy_pcm_hw_params,
	.hw_free =	dummy_pcm_hw_free,
	.prepare =	dummy_pcm_prepare,
	.trigger =	dummy_pcm_trigger,
	.pointer =	dummy_pcm_pointer,
};

static struct snd_pcm_ops dummy_pcm_ops_no_buf = {
	.open =		dummy_pcm_open,
	.close =	dummy_pcm_close,
	.ioctl =	snd_pcm_lib_ioctl,
	.hw_params =	dummy_pcm_hw_params,
	.hw_free =	dummy_pcm_hw_free,
	.prepare =	dummy_pcm_prepare,
	.trigger =	dummy_pcm_trigger,
	.pointer =	dummy_pcm_pointer,
	.copy =		dummy_pcm_copy,
	.silence =	dummy_pcm_silence,
	.page =		dummy_pcm_page,
};

static int __devinit snd_card_dummy_pcm(struct snd_dummy *dummy, int device,
					int substreams)
{
	struct snd_pcm *pcm;
	struct snd_pcm_ops *ops;
	int err;

	err = snd_pcm_new(dummy->card, "Dummy-fix PCM", device,
			       substreams, substreams, &pcm);
	if (err < 0)
		return err;
	dummy->pcm = pcm;
	if (fake_buffer)
		ops = &dummy_pcm_ops_no_buf;
	else
		ops = &dummy_pcm_ops;
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, ops);
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, ops);
	pcm->private_data = dummy;
	pcm->info_flags = 0;
	strcpy(pcm->name, "Dummy-fix PCM");
	if (!fake_buffer) {
		snd_pcm_lib_preallocate_pages_for_all(pcm,
			SNDRV_DMA_TYPE_CONTINUOUS,
			snd_dma_continuous_data(GFP_KERNEL),
			0, 64*1024);
	}
	return 0;
}

/*
 * mixer interface
 */

#define DUMMY_VOLUME(xname, xindex, addr) \
{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, \
  .access = SNDRV_CTL_ELEM_ACCESS_READWRITE | SNDRV_CTL_ELEM_ACCESS_TLV_READ, \
  .name = xname, .index = xindex, \
  .info = snd_dummy_volume_info, \
  .get = snd_dummy_volume_get, .put = snd_dummy_volume_put, \
  .private_value = addr, \
  .tlv = { .p = db_scale_dummy } }

static int snd_dummy_volume_info(struct snd_kcontrol *kcontrol,
				 struct snd_ctl_elem_info *uinfo)
{
	uinfo->type = SNDRV_CTL_ELEM_TYPE_INTEGER;
	uinfo->count = 2;
	uinfo->value.integer.min = -50;
	uinfo->value.integer.max = 100;
	return 0;
}

static int snd_dummy_volume_get(struct snd_kcontrol *kcontrol,
				struct snd_ctl_elem_value *ucontrol)
{
	struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
	int addr = kcontrol->private_value;

	spin_lock_irq(&dummy->mixer_lock);
	ucontrol->value.integer.value[0] = dummy->mixer_volume[addr][0];
	ucontrol->value.integer.value[1] = dummy->mixer_volume[addr][1];
	spin_unlock_irq(&dummy->mixer_lock);
	return 0;
}

static int snd_dummy_volume_put(struct snd_kcontrol *kcontrol,
				struct snd_ctl_elem_value *ucontrol)
{
	struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
	int change, addr = kcontrol->private_value;
	int left, right;

	left = ucontrol->value.integer.value[0];
	if (left < -50)
		left = -50;
	if (left > 100)
		left = 100;
	right = ucontrol->value.integer.value[1];
	if (right < -50)
		right = -50;
	if (right > 100)
		right = 100;
	spin_lock_irq(&dummy->mixer_lock);
	change = dummy->mixer_volume[addr][0] != left ||
	         dummy->mixer_volume[addr][1] != right;
	dummy->mixer_volume[addr][0] = left;
	dummy->mixer_volume[addr][1] = right;
	spin_unlock_irq(&dummy->mixer_lock);
	return change;
}

static const DECLARE_TLV_DB_SCALE(db_scale_dummy, -4500, 30, 0);

#define DUMMY_CAPSRC(xname, xindex, addr) \
{ .iface = SNDRV_CTL_ELEM_IFACE_MIXER, .name = xname, .index = xindex, \
  .info = snd_dummy_capsrc_info, \
  .get = snd_dummy_capsrc_get, .put = snd_dummy_capsrc_put, \
  .private_value = addr }

#define snd_dummy_capsrc_info	snd_ctl_boolean_stereo_info

static int snd_dummy_capsrc_get(struct snd_kcontrol *kcontrol,
				struct snd_ctl_elem_value *ucontrol)
{
	struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
	int addr = kcontrol->private_value;

	spin_lock_irq(&dummy->mixer_lock);
	ucontrol->value.integer.value[0] = dummy->capture_source[addr][0];
	ucontrol->value.integer.value[1] = dummy->capture_source[addr][1];
	spin_unlock_irq(&dummy->mixer_lock);
	return 0;
}

static int snd_dummy_capsrc_put(struct snd_kcontrol *kcontrol, struct snd_ctl_elem_value *ucontrol)
{
	struct snd_dummy *dummy = snd_kcontrol_chip(kcontrol);
	int change, addr = kcontrol->private_value;
	int left, right;

	left = ucontrol->value.integer.value[0] & 1;
	right = ucontrol->value.integer.value[1] & 1;
	spin_lock_irq(&dummy->mixer_lock);
	change = dummy->capture_source[addr][0] != left &&
	         dummy->capture_source[addr][1] != right;
	dummy->capture_source[addr][0] = left;
	dummy->capture_source[addr][1] = right;
	spin_unlock_irq(&dummy->mixer_lock);
	return change;
}

static struct snd_kcontrol_new snd_dummy_controls[] = {
DUMMY_VOLUME("Master Volume", 0, MIXER_ADDR_MASTER),
DUMMY_CAPSRC("Master Capture Switch", 0, MIXER_ADDR_MASTER),
DUMMY_VOLUME("Synth Volume", 0, MIXER_ADDR_SYNTH),
DUMMY_CAPSRC("Synth Capture Switch", 0, MIXER_ADDR_SYNTH),
DUMMY_VOLUME("Line Volume", 0, MIXER_ADDR_LINE),
DUMMY_CAPSRC("Line Capture Switch", 0, MIXER_ADDR_LINE),
DUMMY_VOLUME("Mic Volume", 0, MIXER_ADDR_MIC),
DUMMY_CAPSRC("Mic Capture Switch", 0, MIXER_ADDR_MIC),
DUMMY_VOLUME("CD Volume", 0, MIXER_ADDR_CD),
DUMMY_CAPSRC("CD Capture Switch", 0, MIXER_ADDR_CD)
};

static int __devinit snd_card_dummy_new_mixer(struct snd_dummy *dummy)
{
	struct snd_card *card = dummy->card;
	unsigned int idx;
	int err;

	spin_lock_init(&dummy->mixer_lock);
	strcpy(card->mixername, "Dummy Mixer");

	for (idx = 0; idx < ARRAY_SIZE(snd_dummy_controls); idx++) {
		err = snd_ctl_add(card, snd_ctl_new1(&snd_dummy_controls[idx], dummy));
		if (err < 0)
			return err;
	}
	return 0;
}

#if defined(CONFIG_SND_DEBUG) && defined(CONFIG_PROC_FS)
/*
 * proc interface
 */
static void print_formats(struct snd_info_buffer *buffer)
{
	int i;

	for (i = 0; i < SNDRV_PCM_FORMAT_LAST; i++) {
		if (dummy_pcm_hardware.formats & (1ULL << i))
			snd_iprintf(buffer, " %s", snd_pcm_format_name(i));
	}
}

static void print_rates(struct snd_info_buffer *buffer)
{
	static int rates[] = {
		5512, 8000, 11025, 16000, 22050, 32000, 44100, 48000,
		64000, 88200, 96000, 176400, 192000,
	};
	int i;

	if (dummy_pcm_hardware.rates & SNDRV_PCM_RATE_CONTINUOUS)
		snd_iprintf(buffer, " continuous");
	if (dummy_pcm_hardware.rates & SNDRV_PCM_RATE_KNOT)
		snd_iprintf(buffer, " knot");
	for (i = 0; i < ARRAY_SIZE(rates); i++)
		if (dummy_pcm_hardware.rates & (1 << i))
			snd_iprintf(buffer, " %d", rates[i]);
}

#define get_dummy_int_ptr(ofs) \
	(unsigned int *)((char *)&dummy_pcm_hardware + (ofs))
#define get_dummy_ll_ptr(ofs) \
	(unsigned long long *)((char *)&dummy_pcm_hardware + (ofs))

struct dummy_hw_field {
	const char *name;
	const char *format;
	unsigned int offset;
	unsigned int size;
};
#define FIELD_ENTRY(item, fmt) {		   \
	.name = #item,				   \
	.format = fmt,				   \
	.offset = offsetof(struct snd_pcm_hardware, item), \
	.size = sizeof(dummy_pcm_hardware.item) }

static struct dummy_hw_field fields[] = {
	FIELD_ENTRY(formats, "%#llx"),
	FIELD_ENTRY(rates, "%#x"),
	FIELD_ENTRY(rate_min, "%d"),
	FIELD_ENTRY(rate_max, "%d"),
	FIELD_ENTRY(channels_min, "%d"),
	FIELD_ENTRY(channels_max, "%d"),
	FIELD_ENTRY(buffer_bytes_max, "%ld"),
	FIELD_ENTRY(period_bytes_min, "%ld"),
	FIELD_ENTRY(period_bytes_max, "%ld"),
	FIELD_ENTRY(periods_min, "%d"),
	FIELD_ENTRY(periods_max, "%d"),
};

static void dummy_proc_read(struct snd_info_entry *entry,
			    struct snd_info_buffer *buffer)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(fields); i++) {
		snd_iprintf(buffer, "%s ", fields[i].name);
		if (fields[i].size == sizeof(int))
			snd_iprintf(buffer, fields[i].format,
				    *get_dummy_int_ptr(fields[i].offset));
		else
			snd_iprintf(buffer, fields[i].format,
				    *get_dummy_ll_ptr(fields[i].offset));
		if (!strcmp(fields[i].name, "formats"))
			print_formats(buffer);
		else if (!strcmp(fields[i].name, "rates"))
			print_rates(buffer);
		snd_iprintf(buffer, "\n");
	}
}

static void dummy_proc_write(struct snd_info_entry *entry,
			     struct snd_info_buffer *buffer)
{
	char line[64];

	while (!snd_info_get_line(buffer, line, sizeof(line))) {
		char item[20];
		const char *ptr;
		unsigned long long val;
		int i;

		ptr = snd_info_get_str(item, line, sizeof(item));
		for (i = 0; i < ARRAY_SIZE(fields); i++) {
			if (!strcmp(item, fields[i].name))
				break;
		}
		if (i >= ARRAY_SIZE(fields))
			continue;
		snd_info_get_str(item, ptr, sizeof(item));
		if (strict_strtoull(item, 0, &val))
			continue;
		if (fields[i].size == sizeof(int))
			*get_dummy_int_ptr(fields[i].offset) = val;
		else
			*get_dummy_ll_ptr(fields[i].offset) = val;
	}
}

static void __devinit dummy_proc_init(struct snd_dummy *chip)
{
	struct snd_info_entry *entry;

	if (!snd_card_proc_new(chip->card, "dummy_pcm", &entry)) {
		snd_info_set_text_ops(entry, chip, dummy_proc_read);
		entry->c.text.write = dummy_proc_write;
		entry->mode |= S_IWUSR;
	}
}
#else
#define dummy_proc_init(x)
#endif /* CONFIG_SND_DEBUG && CONFIG_PROC_FS */

static int __devinit snd_dummy_probe(struct platform_device *devptr)
{
	struct snd_card *card;
	struct snd_dummy *dummy;
	int idx, err;
	int dev = devptr->id;

	dbg("%s: probe", __func__);

	err = snd_card_create(index[dev], id[dev], THIS_MODULE,
			      sizeof(struct snd_dummy), &card);
	if (err < 0)
		return err;
	dummy = card->private_data;
	dummy->card = card;
	for (idx = 0; idx < MAX_PCM_DEVICES && idx < pcm_devs[dev]; idx++) {
		if (pcm_substreams[dev] < 1)
			pcm_substreams[dev] = 1;
		if (pcm_substreams[dev] > MAX_PCM_SUBSTREAMS)
			pcm_substreams[dev] = MAX_PCM_SUBSTREAMS;
		err = snd_card_dummy_pcm(dummy, idx, pcm_substreams[dev]);
		if (err < 0)
			goto __nodev;
	}
	err = snd_card_dummy_new_mixer(dummy);
	if (err < 0)
		goto __nodev;
	strcpy(card->driver, "Dummy");
	strcpy(card->shortname, "Dummy-fix");
	sprintf(card->longname, "%s %i", card->shortname, dev + 1);

	dummy_proc_init(dummy);

	snd_card_set_dev(card, &devptr->dev);

	err = snd_card_register(card);
	if (err == 0) {
		platform_set_drvdata(devptr, card);
		return 0;
	}
      __nodev:
	snd_card_free(card);
	return err;
}

static int __devexit snd_dummy_remove(struct platform_device *devptr)
{
	snd_card_free(platform_get_drvdata(devptr));
	platform_set_drvdata(devptr, NULL);
	return 0;
}

#ifdef CONFIG_PM
static int snd_dummy_suspend(struct platform_device *pdev, pm_message_t state)
{
	struct snd_card *card = platform_get_drvdata(pdev);
	struct snd_dummy *dummy = card->private_data;

	snd_power_change_state(card, SNDRV_CTL_POWER_D3hot);
	snd_pcm_suspend_all(dummy->pcm);
	return 0;
}

static int snd_dummy_resume(struct platform_device *pdev)
{
	struct snd_card *card = platform_get_drvdata(pdev);

	snd_power_change_state(card, SNDRV_CTL_POWER_D0);
	return 0;
}
#endif

#define SND_DUMMY_DRIVER	"snd_dummy"

static struct platform_driver snd_dummy_driver = {
	.probe		= snd_dummy_probe,
	.remove		= __devexit_p(snd_dummy_remove),
#ifdef CONFIG_PM
	.suspend	= snd_dummy_suspend,
	.resume		= snd_dummy_resume,
#endif
	.driver		= {
		.name	= SND_DUMMY_DRIVER,
		.owner = THIS_MODULE
	},
};

static void snd_dummy_unregister_all(void)
{
	int i;

	for (i = 0; i < ARRAY_SIZE(devices); ++i)
		platform_device_unregister(devices[i]);
	platform_driver_unregister(&snd_dummy_driver);
	free_fake_buffer();
}

static int __init alsa_card_dummy_init(void)
{
	int i, cards, err;

	err = platform_driver_register(&snd_dummy_driver);
	if (err < 0)
		return err;

	err = alloc_fake_buffer();
	if (err < 0) {
		platform_driver_unregister(&snd_dummy_driver);
		return err;
	}

	cards = 0;
	for (i = 0; i < SNDRV_CARDS; i++) {
		struct platform_device *device;
		if (! enable[i])
			continue;
		device = platform_device_register_simple(SND_DUMMY_DRIVER,
							 i, NULL, 0);
		if (IS_ERR(device))
			continue;
		if (!platform_get_drvdata(device)) {
			platform_device_unregister(device);
			continue;
		}
		devices[i] = device;
		cards++;
	}
	if (!cards) {
#ifdef MODULE
		printk(KERN_ERR "Dummy soundcard not found or device busy\n");
#endif
		snd_dummy_unregister_all();
		return -ENODEV;
	}

  #if (HWDEBUG_STACK == 1)
  hw_breakpoint_init(&attr);
  attr.bp_len = HW_BREAKPOINT_LEN_1;
  // NB: just HW_BREAKPOINT_R results with: "Breakpoint registration failed" (insmod: error inserting './testhrarr.ko': -1 Invalid parameters)
  // just HW_BREAKPOINT_W works
  attr.bp_type = HW_BREAKPOINT_W;// | HW_BREAKPOINT_R;
  // attr.bp_addr // later, when playback dma_area exists/available
  #endif
	return 0;
}

static void __exit alsa_card_dummy_exit(void)
{
	snd_dummy_unregister_all();
}

module_init(alsa_card_dummy_init)
module_exit(alsa_card_dummy_exit)
