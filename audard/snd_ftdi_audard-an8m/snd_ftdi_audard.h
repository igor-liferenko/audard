/*
 * snd_ftdi_audard.h
 * Driver definitions for the Audio Arduino FTDI USB driver - sound/ALSA related
 * (based on http://www.alsa-project.org/main/index.php/Minivosc {dummy.c; aloop-kernel.c} ) 
 * 
 * USB FTDI SIO driver - 'AudioArduino' modification
 * Copyright (C) 2010 by sdaau (sd@{imi,create}.aau.dk) 
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 */
/*
 *
 * Trying to place (audio) functions in .h file, 
 * since including them in standalone .c might
 * screw up (other) includes... 
 *
 */
/* 
 * Check functions proc_audio_usbbus_read, 
 * proc_audio_usbid_read, snd_usb_audio_create_proc 
 * from usbaudio.c, to see how common proc files are 
 * manipulated to show the usb device info
 */



// * Use our own dbg macro: 
// * http://www.n1ywb.com/projects/darts/darts-usb/darts-usb.c
// * 
// * ftdi-sio seems to include something that defines dbg, 
// * which spews massive ammounts of log; 
// * to tame it down, we define it as nothing here:
#undef dbg
#define dbg(format, arg...) do { } while (0)
//~ static int debug = 1;
//~ #define dbg(format, arg...) do { if (debug) printk( ": " format "\n" , ## arg); } while (0)

#define dbg2(format, arg...) do { } while (0)
//~ #define dbg2(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0) // removed { if (debug) ...

#define dbg3(format, arg...) do { } while (0)
//~ #define dbg3(format, arg...) do { if (debug) printk( ": " format "\n" , ## arg); } while (0)

//~ #define dbg4(format, arg...) do { } while (0)
#define dbg4(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)


// * Here is our user defined breakpoint, to 
// * initiate communication with remote (k)gdb 
// * don't use if not actually using kgdb 
#define BREAKPOINT() asm("   int $3");

// * from usbaudio.h: handling of USB 
// * vendor/product ID pairs as 32-bit numbers 
#define USB_ID(vendor, product) (((vendor) << 16) | (product))
#define USB_ID_VENDOR(id) ((id) >> 16)
#define USB_ID_PRODUCT(id) ((u16)(id))


// * copy from audard.c/aloop-kernel.c: 
#include <linux/jiffies.h>
#include <linux/time.h>
#include <linux/platform_device.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/pcm.h>
#include <sound/initval.h>
#include <sound/info.h> //for snd_card_proc_new

// * "Module parameters" writing.pdf:
// * There are standard module options for ALSA. 
// * At least, each module should have the index, id and enable options. 
// * If the module supports multiple cards (usually up to 8 = 
// * SNDRV_CARDS cards), they should be arrays.
// * If the module supports only a single card, they could be  
// * single variables, instead. 
// * enable option is not always necessary in this case, but it  
// * would be better to have a dummy option for compatibility. 
// * * Of course, SNDRV_CARDS will say - how many actual card 
// * hardwares we have connected to the system, at time of probing

static int index[SNDRV_CARDS] = SNDRV_DEFAULT_IDX;	/* Index 0-MAX */
static char *id[SNDRV_CARDS] = SNDRV_DEFAULT_STR;	/* ID for this card */
static int enable[SNDRV_CARDS] = {1, [1 ... (SNDRV_CARDS - 1)] = 0};

// aloop.c + writing.pdf
module_param_array(index, int, NULL, 0444);
MODULE_PARM_DESC(index, "Index value for Audio Arduino soundcard.");
module_param_array(id, charp, NULL, 0444);
MODULE_PARM_DESC(id, "ID string for Audio Arduino soundcard.");
module_param_array(enable, bool, NULL, 0444);
MODULE_PARM_DESC(enable, "Enable this Audio Arduino soundcard.");

// author, desc defined in main ftdi_sio-audard.c file 
//~ MODULE_AUTHOR("sdaau");
//~ MODULE_DESCRIPTION("An audio Arduino FTDI soundcard module");
//~ MODULE_LICENSE("GPL");

MODULE_SUPPORTED_DEVICE("{{ALSA,Audio Arduino soundcard}}");

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

// * pcm_devs used only in probe, we 
// * .. count on using only 1 here, though
// * .. - so not used here
//~ static int pcm_devs[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 1}; 

static int pcm_substreams[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 1}; // 8}; // otherwise, 8 subdevices in aplay/arecord; although - it's reset in probe



// * here we must have some reference to the 'card':
static struct snd_card *thiscard; 

#define byte_pos(x)	((x) / HZ)
#define frac_pos(x)	((x) * HZ)

//~ #define MAX_BUFFER (32 * 48) 	// from bencol
#define MAX_BUFFER (64*1024)  		// default dummy.c:

// * was a single struct  for capture only previously..
//~ static struct snd_pcm_hardware audard_pcm_hw = 
static struct snd_pcm_hardware audard_pcm_hw_playback =
{
	.info = (SNDRV_PCM_INFO_MMAP |
	SNDRV_PCM_INFO_INTERLEAVED |
	SNDRV_PCM_INFO_BLOCK_TRANSFER |
	SNDRV_PCM_INFO_MMAP_VALID),
	.formats          = SNDRV_PCM_FMTBIT_U8 | SNDRV_PCM_FMTBIT_S16,
	.rates            = SNDRV_PCM_RATE_8000|SNDRV_PCM_RATE_44100,
	.rate_min         = 8000,
	.rate_max         = 44100,
	.channels_min     = 1,
	.channels_max     = 2,
	.buffer_bytes_max = MAX_BUFFER, //(64*1024) dummy.c, was (32 * 48) = 1536, 
	.period_bytes_min = 64, //dummy.c, was 48, 
	.period_bytes_max = MAX_BUFFER, //was 48, coz dummy.c: #def MAX_PERIOD_SIZE MAX_BUFFER
	.periods_min      = 1,
	.periods_max      = 1024, //dummy.c, was 32, 
};

static struct snd_pcm_hardware audard_pcm_hw_capture =
{
	.info = (SNDRV_PCM_INFO_MMAP |
	SNDRV_PCM_INFO_INTERLEAVED |
	SNDRV_PCM_INFO_BLOCK_TRANSFER |
	SNDRV_PCM_INFO_MMAP_VALID),
	.formats          = SNDRV_PCM_FMTBIT_U8,
	.rates            = SNDRV_PCM_RATE_8000|SNDRV_PCM_RATE_44100,
	.rate_min         = 8000,
	.rate_max         = 44100,
	.channels_min     = 1,
	.channels_max     = 1,
	.buffer_bytes_max = MAX_BUFFER, //(64*1024) dummy.c, was (32 * 48) = 1536, 
	.period_bytes_min = 352, // 64, //dummy.c // was 48 // now 2*bytesperjiffy (2*176)  
	.period_bytes_max = MAX_BUFFER, //was 48, coz dummy.c #def MAX_PERIOD_SIZE MAX_BUFFER
	.periods_min      = 1,
	.periods_max      = 1024, //dummy.c, was 32, 
};

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
	int wrapbtw; 	// wrap bytes to write - flag; either 0, or ammount of wrap bytes in wrapbuf
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
	unsigned int playawbprd;	// actually written playback bytes; needed to compare with buf_pos
								//   in case we're missing a frame for CD playback
	// * flags * /
	unsigned int valid;							// (not used)
	unsigned int running;
	unsigned int period_update_pending :1;		// (not used)
	/* from snd_usb_audio struct: */
	u32 usb_id;
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

/* these we don't need - __init/__exit is handled at module (ftdi_sio) level, 
// and we won't use the platform_ stuff: 
static void audard_unregister_all(void)
static int alsa_card_audard_init(void)
*/

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
static void snd_card_audard_pcm_timer_function(unsigned long data);
static snd_pcm_uframes_t snd_card_audard_pcm_pointer(struct snd_pcm_substream *substream);


//~ static struct snd_pcm_ops audard_pcm_ops; // was a single for capture only previously.. 
// * Since now we need separate capture and playback substreams, 
// * we separate callbacks for them - the below is ripped from dummy.c **********
static struct snd_pcm_ops audard_pcm_playback_ops =
{
	.open      = snd_card_audard_pcm_playback_open,
	.close     = snd_card_audard_pcm_playback_close, //audard_pcm_playback_close,
	.ioctl     = snd_pcm_lib_ioctl,
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
	.ioctl     = snd_pcm_lib_ioctl,
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
	struct timer_list timer;
	unsigned int pcm_buffer_size;
	unsigned int pcm_period_size;
	unsigned int pcm_bpj;		/* bytes per 1 jiffies */
	unsigned int pcm_bps;		/* bytes per second */
	unsigned int pcm_hz;		/* HZ */
	unsigned int pcm_irq_pos;	/* IRQ position */
	unsigned int pcm_buf_pos;	/* position in buffer */
	struct snd_pcm_substream *substream;
};


// * FUNCTIONS

static inline void snd_card_audard_pcm_timer_start(struct snd_audard_pcm *dpcm)
{
	dpcm->timer.expires = 1 + jiffies;
	add_timer(&dpcm->timer);
}

static inline void snd_card_audard_pcm_timer_stop(struct snd_audard_pcm *dpcm)
{
	del_timer(&dpcm->timer);
}

static int snd_card_audard_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;
	struct audard_device *mydev = dpcm->mydev; 
	//~ struct ftdi_private *priv = mydev->ftdipr;
	struct usb_serial_port *usport = mydev->ftdipr->port;
	//~ unsigned long flags;
	//~ int result = 0;
	
	int err = 0;
	char cmds[16]="          ";
	char ttystr[32]="          ";
	cmds[15]='\0';
	ttystr[31]='\0';

	// either a playback or a capture substream could trigger here.. 
	
	// do not use ftdi_open/close (call funcs that sleep) in _trigger (it is atomic)!
	// trying to move in hw_params/hw_free
	
	sprintf( &cmds[0], "%d", cmd );
	spin_lock(&dpcm->lock);
	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
	case SNDRV_PCM_TRIGGER_RESUME:
		sprintf( &cmds[0], "%d START", cmd);
		//~ ftdi_open(NULL, mydev->ftdipr->port); // try open port
		// * Start reading from the device */ // NO!!!! 
		//~ result = ftdi_submit_read_urb(usport, GFP_KERNEL);
		//~ if (!result)
			//~ kref_get(&priv->kref); // end start reading
		snd_card_audard_pcm_timer_start(dpcm);
		mydev->running |= (1 << substream->stream); // set running bit @ playback (0) or capture (1) bit position
		break;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		sprintf( &cmds[0], "%d STOP", cmd); 
		//~ ftdi_close(mydev->ftdipr->port); // try close port
		// * shutdown our bulk read */ // NO!!!
		//~ usb_kill_urb(usport->read_urb);
		//~ kref_put(&priv->kref, ftdi_sio_priv_release);	// end shutdown bulk read
		mydev->running &= ~(1 << substream->stream); // clear running bit @ playback (0) or capture (1) bit position
		snd_card_audard_pcm_timer_stop(dpcm);
		break;
	default:
		err = -EINVAL;
		break;
	}
	spin_unlock(&dpcm->lock);
	//~ dbg2("	%s: %s -- portnum %d ", __func__, cmds, mydev->ftdipr->port->number);// OK
	//~ spin_lock_irqsave(&usport->lock, flags);
	// probably no need for spinlock - however usport->port.tty could be 0x0! 
	if (usport->port.tty) {
		sprintf( &ttystr[0], "ttyindx %d, ttyname %s", usport->port.tty->index, usport->port.tty->name );
	} else {
		sprintf( &ttystr[0], "port.tty %p", usport->port.tty);
	}
	
	dbg2("	%s: %s -- portnum %d, %s", __func__, cmds, mydev->ftdipr->port->number, ttystr);
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

	bps = snd_pcm_format_width(runtime->format) * runtime->rate *
		runtime->channels / 8;

	if (bps <= 0)
		return -EINVAL;

	mydev->IMRX.tlRecv = 0;
	mydev->IMRX.hdWsnd = 0;
	
	
	bpj = bps/HZ; // this will be truncated as int(eger)

	// for 1 jiffies, time is 1/HZ ;
	// HZ should be cca 100 Hz, so even for 8K, it is like 80 bytes.. 
	dpcm->pcm_bpj = bpj; 
	
	dpcm->pcm_bps = bps;	
	dpcm->pcm_hz = HZ;
	dpcm->pcm_buffer_size = snd_pcm_lib_buffer_bytes(substream);
	dpcm->pcm_period_size = snd_pcm_lib_period_bytes(substream);
	dpcm->pcm_irq_pos = 0;
	dpcm->pcm_buf_pos = 0;
	
	// since wrapbuf needs not be bigger than pcm_buffer_size,
	// realloc it free (and finally kill it where IMRX.buf is killed)
	if (mydev->IMRX.wrapbuf) 
		kfree(mydev->IMRX.wrapbuf);
	mydev->IMRX.wrapbuf = kzalloc(dpcm->pcm_buffer_size, GFP_KERNEL);

	// tempbuf8b - realloc it (via free) - if playback
	if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
		int samplewidth = snd_pcm_format_width(substream->runtime->format);
		if ((samplewidth == 16) && (substream->runtime->channels == 2)) {
			if (mydev->tempbuf8b) 
				kfree(mydev->tempbuf8b);
			// make sure there is one extra byte in tempbuf8b - for period wrap (isBufFramePreinc)!! 
			mydev->tempbuf8b = kzalloc(bytes_to_frames(substream->runtime, dpcm->pcm_bpj), GFP_KERNEL); //framesToWrite; bytesToWrite = dpcm->pcm_bpj
			// same realloc for tempbuf8b_frame - it needs to be 4 bytes, i.e. 1 frame, in size
			if (mydev->tempbuf8b_frame) 
				kfree(mydev->tempbuf8b_frame);				
			mydev->tempbuf8b_frame = kzalloc(frames_to_bytes(substream->runtime, 1), GFP_KERNEL); 
		}
		// also reset the overflow counter here:
		mydev->tempbuf8b_extra = 0;
		mydev->tempbuf8b_extra_prev = 0;
		mydev->playawbprd = 0;
	}
	
	dbg2("	%s: bps:%d bpj: %d, HZ: %d, buffer_size: %d, pcm_period_size: %d, dma_bytes %d, dma_samples %d, fmt|nch|rt %d|%d|%d", __func__, bps, bpj, HZ, dpcm->pcm_buffer_size, dpcm->pcm_period_size, runtime->dma_bytes, bytes_to_samples(runtime, runtime->dma_bytes), snd_pcm_format_width(runtime->format), runtime->channels, runtime->rate);
	
	snd_pcm_format_set_silence(runtime->format, runtime->dma_area,
			bytes_to_samples(runtime, runtime->dma_bytes));

	if (! mydev->IMRX.wrapbuf)
		dbg2("	cannot alloc wrapbuf!");
		return 1; 	
	
	return 0;
}

// NOTE: this function can be called EITHER by playback OR by capture! 
static void snd_card_audard_pcm_timer_function(unsigned long data)
{
	struct snd_audard_pcm *dpcm = (struct snd_audard_pcm *)data;
	unsigned long flags;
	
	// retrieve a ref to substream in the calling pcm struct:
	struct snd_pcm_substream *ss = dpcm->substream;
	// playback or capture direction.. 
	int dir_playcap = ss->stream;
	// destination - ref to main dma area
	char *dst = ss->runtime->dma_area;
	// ref to device struct
	struct audard_device *mydev = dpcm->mydev;
	
	unsigned int bytesToWrite;
	int imrfill;
	int bytesSilence;
	int bytesToWriteBWrap, bytesToWriteBWrapRemain, actuallyWrittenBytes;
		
	//~ spin_lock_irqsave(&dpcm->lock, flags);
	
	bytesToWrite = dpcm->pcm_bpj; // same for both playback and capture?
	bytesSilence = 0;
	
	if (dir_playcap == SNDRV_PCM_STREAM_PLAYBACK) {
		// we simply assume that ALSA has already written pcm_bpj in the past interval,
		// and given it to us in dma_area? 
		// if so - then just execute ftdi_write? 
		//~ ftdi_write(struct tty_struct *tty, struct usb_serial_port *port, const unsigned char *buf, int count)
		// seems here we only have to handle the case of dma_area wrapping
		// (otherwise, here we have nothing to do with IMRX) 
		// and no need to deal with silence here - just push bytes as long as ALSA says :) 
		struct usb_serial_port *usport = mydev->ftdipr->port;
		int samplewidth = snd_pcm_format_width(ss->runtime->format);
		
		// NOTE: currently, hardware wise, we want Arduino to 
		//   support mono, 8-bit, 44100 Hz: 
		// - `aplay` can support this kind of a stream directly
		// - `audacity` converts internally everything to stereo @ default sample format (16) @ project rate (44100)
		// so for each original 8-bit sample, `audacity` (via ALSA) will here
		//  give us 2 channels * 16 bits = 32 bits = 4 bytes
		// SO: if we use `aplay`, we can handle copy/wrap with bytes calc directly
		// if we use `audacity`, we must cast 4 bytes (stereo 16-bit) to 1 byte
		// snd_pcm_format_width(runtime->format), runtime->channels, runtime->rate
		
		// check wrap of dma_area - only interested in actual bytes (not silence)
		// handle like this, instead of modulo - are we over pcm buffer size with this write?
		bytesToWriteBWrap = dpcm->pcm_buf_pos + bytesToWrite - dpcm->pcm_buffer_size;
		bytesToWriteBWrapRemain = 0; 
		// bytesToWriteBWrap will be negative if no wrap... else:
		// (now must also handle differently 8-bit mono `arecord` and 16-bit stereo `audacity`)
		// for 8-bit mono, no problem with few bytes being wrapped from dma_area (no need for tempbuf8b_extra) 
		if ((samplewidth == 8) && (ss->runtime->channels == 1)) { // this should be `arecord` - 8 bit mono
			if (bytesToWriteBWrap > 0) { // we're wrapping
				bytesToWriteBWrapRemain = bytesToWrite - bytesToWriteBWrap;
				ftdi_write(NULL, usport, dst+dpcm->pcm_buf_pos, bytesToWriteBWrapRemain);
				ftdi_write(NULL, usport, dst, bytesToWriteBWrap);
			} else {
				bytesToWriteBWrap = 0; // set to 0 for neg vals, to avoid confusion
				ftdi_write(NULL, usport, dst+dpcm->pcm_buf_pos, bytesToWrite);
			}
		}
		
		if ((samplewidth == 16) && (ss->runtime->channels == 2)) { // this should be `audacity` - 16 bit stereo
			// here we expect 1 frame = num_channels * sample-size = 2*16 = 32 bit
			// NOTE, here bpj could be 705 (instead of usual 176 for mono 8-bit)
			
			// we want to represent each frame with a single byte (mono 8-bit)
			// we could do mixdown and such, but its pointless:
			// better to extract a 16-bit int from a single channel, and simply 
			// cast that to 8 bit
			
			// well - we cannot just simply "cast" between signed 16 and unsigned 8;
			// we'd also like ranges to match (i.e. [-32767, 32767] -> [0, 256])
			// to do that: MSB(int16) is extracted - and its most significant bit inverted
			// or: to extract MSB: bitshift (int16) right 8 places; ...
			// .... and AND (&) with 8-bit bitmask 0b11111111 = 0xFF (to handle signed bitshift, which may expand to 32 bits)
			// .... and finally, use XOR (^) with mask 0b10000000 = 0x80 to invert most significant bit
			// .. or formula: (sign16bit >> 8 & 0xFF) ^ 0x80 == (sign16bit >> 8 & 0b11111111) ^ 0b10000000
			
			// finally, 1 frame = 2 channels * 16 bits; however, if bpj is an even number; 
			// we may remain with 1, 2 or 3 bytes extra - we should record these in
			// tempbuf8b; and mark with tempbuf8b_extra - for prepending in next period
			
			// assuming we are interleaved here:
			// programmatically, easiest to read through an int pointer
			//  say in while loop, and the _write the extracted byte
			//  BUT - that may be a bad idea, queuing too many _writes ?
			// otherwise, we'll again have to have a temp buffer, and copy into it

			// new algo, handling all kindsa wrap:
			int tbExR; // tempbuf8b_extra Remain help var; also can serve as pcmpreinc
			int framesToWrite; // how many frames to write - changes between periods
			int bytesToWritePWrapRemain; // how many unwritten bytes at end of period
			int frameSizeBytes; // (numchannels*samplesize_in_bytes); frames_to_bytes 
			int breakstap; // 'fake' var, so systemtap can add a breakpoint
			int tframe, isBufFramePreinc, wrapped_dma_buf_pos; 
			int16_t left16bitsample;				
			
			
			frameSizeBytes			= frames_to_bytes(ss->runtime, 1); // for 1 frame, should be 4 bytes - for stereo, 16 bit
			tbExR 					= (frameSizeBytes - mydev->tempbuf8b_extra) % frameSizeBytes;
			framesToWrite 			= bytes_to_frames(ss->runtime, (bytesToWrite - tbExR)); //(bytesToWrite-tbExR)/frameSizeBytes; 
			bytesToWritePWrapRemain = bytesToWrite - tbExR - frames_to_bytes(ss->runtime, framesToWrite); //framesToWrite*frameSizeBytes # this is also "future" tempbuf8b_extra.. 
			isBufFramePreinc = 0; breakstap = 0;
			
			// ok, regardless if we wrap dpcm->buffer_size; we might have a 
			//   wrap due to a frame being split at period (say, odd bytesToWrite);
			// so first check if there's tempbuf8b_extra from last period, 
			//   handle that first, and preincrement counters - and only then, do the rest
			if (mydev->tempbuf8b_extra > 0) {
				// here we should have first tempbuf8b_extra bytes of split frame 
				//   in tempbuf8b_frame - populate with remainder of bytes first;
				//   which should be at beginning of dma_area
				if (tbExR > 0) { // since now, _extra could also be frameSizeBytes - not anymore, but keep it 
					memcpy(mydev->tempbuf8b_frame+mydev->tempbuf8b_extra, dst+dpcm->pcm_buf_pos, tbExR);
					// now tempbuf8b_frame should be having a frame, with full frameSizeBytes (4)
					// "cast" it to byte, and store it in tempbuf8b
					// as tempbuf8b will always get fully used at the end of this function, 
					// here we just fill it from the beginning.. 
					left16bitsample = *(int16_t*)(mydev->tempbuf8b_frame);
					*(mydev->tempbuf8b) = (char) (left16bitsample >> 8 & 0b11111111) ^ 0b10000000;
					// right, now we have the first sample in tempbuf8b - rest of code should know
					// set isBufFramePreinc:
					//    it means 1 byte already in tempbuf8b!
					//  then, we can use it as correct offset for writing in tempbuf8b... 
					isBufFramePreinc = 1; // else it is zero from start. 
				}
			}
			
			// we have now exact number of frames - which will definitely not wrap IN PERIOD - to send this period; handle:
			tframe = 0; 
			while (tframe<framesToWrite) {
				// tframe = 0 -> bytes: L: 0 1 R: 2 3 (stereo, 16-bit, interleave)
				int BwrapBytesRemain; 
				wrapped_dma_buf_pos = dpcm->pcm_buf_pos+tbExR+frameSizeBytes*tframe;
				BwrapBytesRemain = wrapped_dma_buf_pos + frameSizeBytes - (dpcm->pcm_buffer_size - 1); //also advance by frameSizeBytes
				if (BwrapBytesRemain > 0) { // ... however, we may still be in a frame that wraps on dma pcm BUFFER size boundary
					if (BwrapBytesRemain < frameSizeBytes) {
						char brokenEndFrame[4] = ""; // should be frameSizeBytes, but: "error: variable-sized object may not be initialized" for variable-length arrays; and else should again kzmalloc / kfree with _ATOMIC.. so easiest hardcoded for now
						memcpy(&brokenEndFrame[0], dst+wrapped_dma_buf_pos, frameSizeBytes-BwrapBytesRemain); // copy from end of dma_area
						memcpy(&brokenEndFrame[frameSizeBytes-BwrapBytesRemain], dst, BwrapBytesRemain); // copy from start of dma_area
						left16bitsample = *(int16_t*)(&brokenEndFrame[0]);
						*(mydev->tempbuf8b + isBufFramePreinc + tframe) = (char) (left16bitsample >> 8 & 0b11111111) ^ 0b10000000; //(char)left16bitsample;
						tframe+=1; 
					}
					wrapped_dma_buf_pos = (dpcm->pcm_buf_pos+tbExR+frameSizeBytes*tframe) % dpcm->pcm_buffer_size; // not just wrapped_dma_buf_pos % dpcm->pcm_buffer_size; - also refresh new val of tframe?!
				}
				left16bitsample = *(int16_t*)(dst+wrapped_dma_buf_pos);
				// dereference pointer (instead of assigning array)
				*(mydev->tempbuf8b + isBufFramePreinc + tframe) = (char) (left16bitsample >> 8 & 0b11111111) ^ 0b10000000; //(char)left16bitsample;
				tframe+=1;
			}
			
			// tempbuf should be ready now, send
			ftdi_write(NULL, usport, mydev->tempbuf8b, tframe+isBufFramePreinc); // framesToWrite bytes --  corresponding to frames! 
			mydev->playawbprd += (tframe+isBufFramePreinc)*frameSizeBytes; // sync to actual ftdi writes! 
			
			// here we re-set mydev->tempbuf8b_extra again: 
			// after the ftdi_write, we can see if anything should be put in tempbuf8b_frame
			// as obviously: framesToWrite*frameSizeBytes <= bytesToWrite!
			// with framesToWrite - we have exhausted (numchan*samplesize)*framesToWrite bytes
			//   in dma_area; check if some are remaining voa modulo 4 (numchan*samplesize) ...  
			// also (numchan*samplesize) = frames_to_bytes(1)
			// and obviously: (framesToWrite*frameSizeBytes) % frameSizeBytes; is zero! use bytesToWrite...
			// ... actually, bytesToWrite +  tempbuf8b_extra (not isBufFramePreinc)!
			// ... actually - it is the (new) bytesToWritePWrapRemain:
			mydev->tempbuf8b_extra = bytesToWritePWrapRemain; //(bytesToWrite + mydev->tempbuf8b_extra) % frameSizeBytes; // reset counter first
			
			if (mydev->tempbuf8b_extra > 0) {
				// ok we have some leftovers, save:
				// framesToWrite*frameSizeBytes + tempbuf8b_extra (should be =) bytesToWrite
				wrapped_dma_buf_pos = (dpcm->pcm_buf_pos+tbExR+frameSizeBytes*tframe) % dpcm->pcm_buffer_size;
				memcpy(mydev->tempbuf8b_frame, dst+wrapped_dma_buf_pos, mydev->tempbuf8b_extra);
			}
			
			mydev->tempbuf8b_extra_prev = mydev->tempbuf8b_extra; 
			
			if (dpcm->pcm_buf_pos+bytesToWrite >= dpcm->pcm_buffer_size) { // sync playawbprd wrap with  buf_pos
				mydev->playawbprd %= dpcm->pcm_buffer_size;	//dpcm->pcm_buf_pos
			}
			// ok, now that we've done this - let's note, that we have
			//   'actually written' only "framesToWrite"*frameSizeBytes (+ preinc) !!
			// so for the update of pcm_buf_pos below, 
			//    we must correct bytesToWrite! - NEVER, screws up timing..
			//~ bytesToWrite = pcmpreinc+fwrite*frameSizeBytes; 
			// actually NO - now instead of correction, we have temp buffer?? 
			breakstap = breakstap+1; // breakpoint line for systemtap
			//~ kfree(tempbuf8b);
		}
	} // end if (dir_playcap == SNDRV_PCM_STREAM_PLAYBACK) 
	
	// * ONLY bother with IMRX and such if we are capturing; 
	// * so we need to check stream direction, as we use a single timer
	// * function (to handle both playback and capture directions) 
	if (dir_playcap == SNDRV_PCM_STREAM_CAPTURE) {
		
		// * here we call timer_func each 1 jiffy period ... 
		// * can we use dpcm->pcm_bps?? we need bytes per jiffies.. 
		// * > Within the Linux 2.6 operating system kernel, since
		// * >  release 2.6.13, on the Intel i386 platform a jiffy
		// * >  is by default 4 ms, or 1/250 of a second
		// * > The Linux kernel maintains a global variable called
		// * >  jiffies, which represents the number of timer 
		// * >  ticks since the machine started.
		// * > http://www.xml.com/ldd/chapter/book/ch06.html: 
		// * >  jiq_timer.expires = jiffies + HZ; /* one second */ 
		// * >  "jiffies value in seconds %lu\n",(jiffies/HZ))
		// * if there are HZ (system) timer interrupts in a second, 
		// * there are HZ jiffies in a second. - seems jiffy period 
		// * can be like 0.04 sec ... - in the end, bpj=bps/Hz
		// * NOTE ----- will have to fill empty bytes if there is no 
		// *   packet, because pcm_irq_pos determines whether  
		// *   elapsed will fire; 
		// * if we don't, we'll fill just 6633 bytes, and stop, 
		// *   where dpcm->pcm_period_size * dpcm->pcm_hz  
		// *   could be 12000.. 
		// * we also need to protect near end of IMRX...
		
		
		// * we should in principle transfer 'bytesToWrite' = bpj
		// * bytes from IMRX to dma_area during capture..
		// * Check first 'imrfill', though - how many bytes 
		// * remain (as of yet) unprocessed in IMRX
		
		//~ bytesToWrite = dpcm->pcm_bpj;
		imrfill = mydev->IMRX.tail - mydev->IMRX.head;
		if (imrfill < 0) imrfill = 0; 
		if (bytesToWrite > imrfill) bytesToWrite = imrfill; 
		bytesSilence = dpcm->pcm_bpj - bytesToWrite;
		
		// check wrap of dma_area - only interested in actual bytes (not silence)
		// handle like this, instead of modulo - are we over pcm buffer size with this write?
		bytesToWriteBWrap = dpcm->pcm_buf_pos + bytesToWrite - dpcm->pcm_buffer_size;
		bytesToWriteBWrapRemain = 0; 
		// bytesToWriteBWrap will be negative if no wrap... else:
		if (bytesToWriteBWrap > 0) { // we're wrapping
			// oops, wrap - these remaining bytes will have to be written 
			// in the *next* pcm buffer ! so we have to save them somewhere? NOT anymore
			spin_lock_irqsave(&dpcm->lock, flags);			
			mydev->IMRX.wrapbtw = bytesToWriteBWrap;
			bytesToWriteBWrapRemain = bytesToWrite - bytesToWriteBWrap;
			// apparently, we don't need to copy to IMRX.wrapbuf anymore - not used
			//~ memcpy(mydev->IMRX.wrapbuf, mydev->IMRX.buf+mydev->IMRX.head+bytesToWriteBWrapRemain, bytesToWriteBWrap); 
			spin_unlock_irqrestore(&dpcm->lock, flags);
			
			dbg2("  inwrap: bWWR:%d, bWW:%d, bWr:%d ", bytesToWriteBWrapRemain, bytesToWriteBWrap, bytesToWrite);
			//bytesSilence = 0; //since we're wrapping, we need not write silence... well; keep it for this change.. 
			bytesToWrite = bytesToWriteBWrapRemain;
		} else bytesToWriteBWrap = 0; // set to 0 for neg vals, to avoid confusion
		
		dbg2(" %s: bWr:%d bsl:%d pbpos: %d, irqps: %d, hd: %d, tl: %d, sz: %d, tlR: %d, hdW: %d, Wrp: %d-%d", "tmr_fnc", bytesToWrite, bytesSilence, dpcm->pcm_buf_pos, dpcm->pcm_irq_pos, mydev->IMRX.head, mydev->IMRX.tail, mydev->IMRX.size, mydev->IMRX.tlRecv, mydev->IMRX.hdWsnd, bytesToWriteBWrap, mydev->IMRX.wrapbtw);
		
		// * check if by any chance we have wrap from last time? 
		actuallyWrittenBytes = 0; // reset here, so we can take wrapbtw into account
		
		// when IMRX.wrapbtw is set, it is == bytesToWriteBWrap; we don't want to execute in that frame
		// next time, bytesToWriteBWrap will be zero; so  && (! bytesToWriteBWrap)  ensures execution next frame
		
		// k, lets forget the above for now, and try to write while wrapping (circular buffer)
		// here we do the bytesToWriteBWrapRemain up to end of buffer; 
		// and piece after that will write the beginning of dma_area...
		// since we preincrease buf_pos here, we cannot use actuallyWrittenBytes cumulatively to set buf_pos at end.. so we keep aWB just as a check variable
		if (bytesToWriteBWrapRemain > 0) {
			memcpy(dst+dpcm->pcm_buf_pos, mydev->IMRX.buf+mydev->IMRX.head, bytesToWriteBWrapRemain);
			actuallyWrittenBytes += bytesToWriteBWrapRemain; // awb was 0 initially, so == to btWWR now.. 
			dpcm->pcm_irq_pos += bytesToWriteBWrapRemain;
			dpcm->pcm_buf_pos += bytesToWriteBWrapRemain; // this should bring buf_pos up to pcm_buffer_size
			dpcm->pcm_buf_pos %= dpcm->pcm_buffer_size; // buf_pos should now become zero
			mydev->IMRX.head += bytesToWriteBWrapRemain; 
			mydev->IMRX.hdWsnd += bytesToWriteBWrapRemain; 
			
			bytesToWrite = bytesToWriteBWrap; // set to bwWrap now, for piece at beginning
			mydev->IMRX.wrapbtw = 0; // reset this here, as we're not using - so it don't clog the log 
		}
		
		
		// * actual write
		if (bytesToWrite > 0) { // * if we have something, write it, 
								// * and fill rest - if any - with zeroes 
			memcpy(dst+dpcm->pcm_buf_pos, mydev->IMRX.buf+mydev->IMRX.head, bytesToWrite); 
			if (bytesSilence>0) memset(dst+dpcm->pcm_buf_pos+bytesToWrite, 0, bytesSilence);
			// * it is relevant to change head only here - and 
			// * ALWAYS in respect to bytesToWrite! NOT dpcm->pcm_bpj
			mydev->IMRX.head += bytesToWrite; // 
			mydev->IMRX.hdWsnd += bytesToWrite; // 
			actuallyWrittenBytes += bytesToWrite + bytesSilence;
		} else { 	// * no data, just fill zeroes - (silence) -  
					// * - and explicitly pcm_bpj bytes
					// * well... if bWr ==0; bsl = pcm_bpj; so use bsl (so its ok also for wrap? )
			memset(dst+dpcm->pcm_buf_pos, 0, bytesSilence);
			actuallyWrittenBytes += bytesSilence; 
		}
		
		dbg2("  fin: aWB:%d ", actuallyWrittenBytes); // should be bpj now.. 
		
		// * 'recover' IMRX - if we reached end of its 
		// *   contents, set head=tail=0
		if (mydev->IMRX.head == mydev->IMRX.tail) { 
			mydev->IMRX.head = mydev->IMRX.tail = 0; 
		}
	
	} // end if dir_playcap == SNDRV_PCM_STREAM_CAPTURE
	
	// * otherwise, try to move the buf_pos 
	// * counters for both capture and playback: 
	// *   here we can directly increase position 
	// *   counters  by pcm_bpj - since we also fill silence now !!
	dpcm->pcm_irq_pos += bytesToWrite + bytesSilence; //actuallyWrittenBytes; //dpcm->pcm_bpj; 
	dpcm->pcm_buf_pos += bytesToWrite + bytesSilence; //actuallyWrittenBytes; //dpcm->pcm_bpj; 
	// nope - modulo loses bytes at start, and maybe causes drips at end.. 
	//~ dpcm->pcm_buf_pos %= dpcm->pcm_buffer_size; // * wrap, if gone overflowing
												// * though, it shouldn't happen
												// * if we're timed; same as check
												// * .. if (buf_pos >= _buffer_size) ..
	// * handle buffer overflows 'manually' - but now,
	// * with the checks above, we should get max ==, never > 
	// * this should now never happen, since we 'break'/wrap manually (circ) in same array
	// but let's keep it, see if it has an effect.. maybe problematic? 
	// * WE MUST HAVE THIS - when there is just silence, we do NOT handle the 
	// * buf_pos wrap manually ! Then buf_pos just grows - and this is the ONLY 
	// * part to keep it in check! If not there, then getting SEVERE crashes - 
	// * even VirtualBox doesn't break into gdb, but instead crashes with "Guru Meditation" mode!
	// * apparently, because we're out of bounds for the middle layer dma_area!! 
	if (dpcm->pcm_buf_pos >= dpcm->pcm_buffer_size) {
		dbg2("  OVER: _buf_pos:%d ", dpcm->pcm_buf_pos);
		dpcm->pcm_buf_pos %= dpcm->pcm_buffer_size;	// 0; // don;t set to zero, wrap to modulo as originally:
													// when we have data, we should manually wrap (to zero, and then further);
													// when we have *only* silence, this will handle the monotonic
													// increase properly, so it's in sync with timing and irq_pos! 
		if (bytesSilence>0) { // if there was silence at all, blank the start of this wrap - just in case?  
			memset(dst, 0, dpcm->pcm_buf_pos);
		}
	}
	
	spin_lock_irqsave(&dpcm->lock, flags);
	
	// * set off timer, again
	dpcm->timer.expires = 1 + jiffies;
	add_timer(&dpcm->timer);
	
	// * check if we need to call _period_elapsed
	// *   depending on amount of bytes written 
	// *   since last period.. 
	// * modulo for irq_pos should be fine,
	// *   we don't use it to read - and with modulo, more proper timing? 
	if (dpcm->pcm_irq_pos >= dpcm->pcm_period_size) {
		dpcm->pcm_irq_pos %= dpcm->pcm_period_size ;
		spin_unlock_irqrestore(&dpcm->lock, flags);
		snd_pcm_period_elapsed(ss); //(dpcm->substream)
	} else
		spin_unlock_irqrestore(&dpcm->lock, flags);
}

static snd_pcm_uframes_t snd_card_audard_pcm_pointer(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct snd_audard_pcm *dpcm = runtime->private_data;

	// * ALSA middle layer will call this function, to find
	// *   out where we are in this (play or capt) substream
	// *   - we have to answer in frames.
	// * hmm... as we run per jiffy now, we don't use 
	// *   dpcm->pcm_hz anymore, and we calc directly in 
	// *   bytes... so, just return the direct buf_pos.
	
	//~ return bytes_to_frames(runtime, dpcm->pcm_buf_pos / dpcm->pcm_hz);
	return bytes_to_frames(runtime, dpcm->pcm_buf_pos);
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
	init_timer(&dpcm->timer);
	dpcm->timer.data = (unsigned long) dpcm;
	dpcm->timer.function = snd_card_audard_pcm_timer_function;
	spin_lock_init(&dpcm->lock);
	dpcm->substream = substream;
	return dpcm;
}

static int snd_card_audard_new_pcm(struct audard_device *mydev, 
							int device, int substreams) // no __devinit here
{
	struct snd_pcm *pcm;
	int err;

	// * NOTE:
	// * > I want to make sure I'm implementing things properly for full duplex
	// * > capability.  I'm creating the pcm device via:
	// * > 
	// * > snd_pcm_new(
	// * > 		card, "my dev", 0, 1 /* play streams */, 1 /* capt streams */, &pcm)
	// * ... ... ...
	// * in our case: int substreams = pcm_substreams[dev] = 1 ... 
	// * ... ... ...
	// * Also, sometimes:	ret = snd_pcm_new(card, card->driver; 
	// * 					strcpy(pcm->name, mydev->card->shortname);

	
	err = snd_pcm_new(mydev->card, "AudArd PCM", device,
									substreams, substreams, &pcm);
	
	dbg2("%s: snd_pcm_new: %d, dev %d, subs %d", __func__, err, device, substreams); 
	
	if (err < 0)
		return err;
	mydev->pcm = pcm;
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &audard_pcm_playback_ops); 
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &audard_pcm_capture_ops); 
	pcm->private_data = mydev; // 'pcm' is snd_pcm struct - has private_data 
	pcm->info_flags = 0;
	strcpy(pcm->name, "AudArd PCM");
	
	snd_pcm_lib_preallocate_pages_for_all(pcm, SNDRV_DMA_TYPE_CONTINUOUS,
					      snd_dma_continuous_data(GFP_KERNEL),
					      0, 64*1024);
	return 0;
}

//~ static int snd_card_audard_pcm_playback_close(struct snd_pcm_substream *substream)
// end ripped from dummy.c **********



// specifies what func is called @ snd_card_free
// used in snd_device_new
static struct snd_device_ops audard_dev_ops =
{
	.dev_free = snd_card_audard_pcm_dev_free, 
};


// * DRVNAME is 15 chars; include/sound/core.h: 
// *  char driver[16]; char shortname[32]
// * but 15 chars + \0 = 16 ... 
// * so for more than that, sprintf fails. 
// * def'd in ftdi_sio-audard.c
// * #define DRVNAME "ftdi_sio_audard" 

#define SND_AUDARD_DRIVER DRVNAME  //"snd_audard" // using DRVNAME instead


/*
 *
 * Probe/remove functions
 *
 */
// * we cannot use __devinit here anymore 
// * also, we cannot rely on 
// *    audard_probe(struct platform_device *devptr)
// * to tell us the index of the soundcard !! 
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
	dbg4("%s: dev: %d, index %d - %s", __func__, dev, index[dev], buildString);
		
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
	
	ret = snd_card_create(index[dev], "AUDARD",
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
	
	sprintf(card->driver, "%s", SND_AUDARD_DRIVER);
	sprintf(card->shortname, "MySoundCard %s", card->driver); //SND_AUDARD_DRIVER);
	sprintf(card->longname, "%s", card->shortname);
	dbg2("-- mydev %p, card->number %d, card->driver '%s', card->shortname '%s'", mydev, card->number, card->driver, card->shortname);

	// init the IMRX buffer here, MAX_BUFFER for start
	// NOTE: we'll allocate IMRX.wrapbuf, where we know 
	//   pcm_buffer_size (in _prepare); wrapbuf needs not be bigger than that. 
	mydev->IMRX.head = mydev->IMRX.tail = 0;
	mydev->IMRX.buf = kzalloc(MAX_BUFFER, GFP_KERNEL);
	if (! mydev->IMRX.buf)
		goto __nodev; 
	mydev->IMRX.size = MAX_BUFFER;	
	
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
	dbg2("  manufacturer %s, product %s, serial %s, devpath %s", udev->manufacturer, udev->product, udev->serial, udev->devpath); 
	
	if (ret == 0)   	// or... (!ret)
	{
		// * also trying without this platform_set_drvdata 
		// *   so as to lose refs to devptr...
		// * platform_set_drvdata simply does:
		// * "store a pointer to priv (card) data structure".
		//~ platform_set_drvdata(serial->dev, card); //devptr,
		
		return 0; 		// success
	} 
	
	dbg2("  ret %d", ret);
	return ret; 
	
__nodev: 				// as in aloop/dummy...
	dbg2("__nodev reached!!");
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
	
	dbg2("%s: snd_pcm_new: mydev %p, ftdipriv %p, reg/ret %d, audev %p", __func__, mydev, mydev->ftdipr, ret, priv->audev);
	
	return 0; 
}



// * from dummy/aloop:
// * we cannot use __devexit here anymore
//static int audard_remove(struct platform_device *devptr)
static void audard_remove(void)
{
	struct audard_device *mydev = thiscard->private_data;
	dbg2("%s (%s)", __func__, buildString);
	kfree(mydev->IMRX.buf);
	kfree(mydev->IMRX.wrapbuf);
	kfree(mydev->tempbuf8b);
	kfree(mydev->tempbuf8b_frame);
	snd_card_free(thiscard);
	//~ snd_card_free(platform_get_drvdata(devptr));
	//~ platform_set_drvdata(devptr, NULL);
	return;// 0;
}


/*
static void audard_unregister_all(void)
// no __init here.. it crashes
static int alsa_card_audard_init(void)
*/



/*
*
* PCM functions
*
*/

static int snd_card_audard_pcm_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params)
{
	dbg2("%s", __func__);
	
	return snd_pcm_lib_malloc_pages(ss,
	                                params_buffer_bytes(hw_params));
}

static int snd_card_audard_pcm_hw_free(struct snd_pcm_substream *ss)
{
	dbg2("%s", __func__);
	
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
	dbg2("%s", __func__);

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
	dbg2(">audard_xfer_buf: count: %d - %d (P:%d, C:%d)", count, mydev->running, CABLE_PLAYBACK, CABLE_CAPTURE );

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
	
	// * mutex causing increased ammount of kernel warnings here! 
	//~ mutex_lock(&mydev->cable_lock); 
	
	newtail = mydev->IMRX.tail + bytes;
	if (newtail > mydev->IMRX.size - 1) {
		// * instead of falling into this many times, 
		// *   if packets are like 62 bytes each, 
		// *   lets just 'realloc' +MAX_BUFFER bytes
		int newsize = mydev->IMRX.size + MAX_BUFFER;
		char* newimrx = kmalloc(newsize, GFP_ATOMIC); //was GFP_KERNEL
		char* oldhead = mydev->IMRX.buf + mydev->IMRX.head; 
		if (! newimrx) { // handle alloc fail
			dbg2("%s: - new IMRX is %p, tl: %d", __func__, newimrx, mydev->IMRX.tail);
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
	mydev->IMRX.tail += bytes;
	mydev->IMRX.tlRecv += bytes; 
	
	
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
	dbg2("%s", __func__);
	//~ kfree(chip->IMRX.buf); // possibly cause for segfault here? Now in _remove..
	return 0;
}

static int snd_card_audard_pcm_dev_free(struct snd_device *device)
{
	dbg2("%s", __func__);
	return snd_card_audard_pcm_free(device->device_data);
}
 
