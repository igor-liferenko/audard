/*
http://ben-collins.blogspot.com/2010/04/writing-alsa-driver.html
+ timer stuff from aloop-kernel.c
*/

#define DEBUG // 1 // doesn't help
#define CONFIG_MODULE_FORCE_UNLOAD
//http://www.n1ywb.com/projects/darts/darts-usb/darts-usb.c - /* Use our own dbg macro */
#define CONFIG_USB_DEBUG // doesn't help here just on its own - ok with below
#ifdef CONFIG_USB_DEBUG
static int debug = 1;
#else
static int debug;
#endif

/* Use our own dbg macro */
#undef dbg
#define dbg(format, arg...) do { if (debug) printk(KERN_DEBUG __FILE__ ": " format "\n" , ## arg); } while (0)
#define dbg2(format, arg...) do { if (debug) printk( ": " format "\n" , ## arg); } while (0)


/* Here is our user defined breakpoint to */
/* initiate communication with remote (k)gdb */
/* don't use if not actually using kgdb */
#define BREAKPOINT() asm("   int $3");


// copy from aloop-kernel.c:
#include <linux/init.h>
#include <linux/jiffies.h>
#include <linux/slab.h>
#include <linux/time.h>
#include <linux/wait.h>
#include <linux/moduleparam.h>
#include <linux/platform_device.h>
#include <sound/core.h>
#include <sound/control.h>
#include <sound/pcm.h>
#include <sound/initval.h>

MODULE_AUTHOR("Ben Collins;sdaau");
MODULE_DESCRIPTION("bencol soundcard");
MODULE_LICENSE("GPL");
MODULE_SUPPORTED_DEVICE("{{ALSA,bencol soundcard}}");

static int index[SNDRV_CARDS] = SNDRV_DEFAULT_IDX;	/* Index 0-MAX */
static char *id[SNDRV_CARDS] = SNDRV_DEFAULT_STR;	/* ID for this card */
static int enable[SNDRV_CARDS] = {1, [1 ... (SNDRV_CARDS - 1)] = 0};

static struct platform_device *devices[SNDRV_CARDS];

#define byte_pos(x)	((x) / HZ)
#define frac_pos(x)	((x) * HZ)

#define MAX_BUFFER (32 * 48)
static struct snd_pcm_hardware my_pcm_hw =
{
	.info = (SNDRV_PCM_INFO_MMAP |
	SNDRV_PCM_INFO_INTERLEAVED |
	SNDRV_PCM_INFO_BLOCK_TRANSFER |
	SNDRV_PCM_INFO_MMAP_VALID),
	.formats          = SNDRV_PCM_FMTBIT_U8,
	.rates            = SNDRV_PCM_RATE_8000,
	.rate_min         = 8000,
	.rate_max         = 8000,
	.channels_min     = 1,
	.channels_max     = 1,
	.buffer_bytes_max = MAX_BUFFER, //(32 * 48),
	.period_bytes_min = 48,
	.period_bytes_max = 48,
	.periods_min      = 1,
	.periods_max      = 32,
};


// * here declaration of functions that will need to be in _ops, before they are defined
static int my_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params);
static int my_hw_free(struct snd_pcm_substream *ss);
static int my_pcm_open(struct snd_pcm_substream *ss);
static int my_pcm_close(struct snd_pcm_substream *ss);
static int my_pcm_prepare(struct snd_pcm_substream *ss);
static int my_pcm_trigger(struct snd_pcm_substream *ss,
                          int cmd);
static snd_pcm_uframes_t my_pcm_pointer(struct snd_pcm_substream *ss);
/*static int my_pcm_copy(struct snd_pcm_substream *ss,
                       int channel, snd_pcm_uframes_t pos,
                       void __user *dst,
                       snd_pcm_uframes_t count);*/

static int my_pcm_dev_free(struct snd_device *device);
//static int my_pcm_free(struct my_device *chip); //needs 'my_device' def.

// note snd_pcm_ops can usually be separate _playback_ops and _capture_ops
static struct snd_pcm_ops my_pcm_ops =
{
	.open      = my_pcm_open,
	.close     = my_pcm_close,
	.ioctl     = snd_pcm_lib_ioctl,
	.hw_params = my_hw_params,
	.hw_free   = my_hw_free,
	.prepare   = my_pcm_prepare,
	.trigger   = my_pcm_trigger,
	.pointer   = my_pcm_pointer,
	//.copy      = my_pcm_copy,
};

// specifies what func is called @ snd_card_free
// used in snd_device_new
static struct snd_device_ops dev_ops =
{
	.dev_free = my_pcm_dev_free, 
};


struct my_device
{
	struct snd_card *card;
	struct snd_pcm *pcm;
	spinlock_t mixer_lock;
	//int mixer_volume[MIXER_ADDR_LAST+1][2];
	//int capture_source[MIXER_ADDR_LAST+1][2];
	const struct my_pcm_ops *timer_ops;
	unsigned char *buffer;
	int hw_idx;
	/*
	* we have only one substream, so all data in this struct
	*/
	/* copied from struct loopback: */
	struct mutex cable_lock;
	/* copied from struct my_loopback_cable: */
	/* PCM parameters */
	unsigned int pcm_period_size;
	unsigned int pcm_bps;		/* bytes per second */
	/* flags */
	unsigned int valid;
	unsigned int running;
	unsigned int period_update_pending :1;
	/* timer stuff */
	unsigned int irq_pos;		/* fractional IRQ position */
	unsigned int period_size_frac;
	unsigned long last_jiffies;
	struct timer_list timer;
	/* copied from struct my_loopback_pcm: */
	struct snd_pcm_substream *substream;
	unsigned int pcm_buffer_size;
	unsigned int buf_pos;	/* position in buffer */
	unsigned int silent_size;
};


// * declare timer functions - copied from aloop-kernel.c
static void my_loopback_timer_start(struct my_device *mydev);
static void my_loopback_timer_stop(struct my_device *mydev);
static void my_loopback_pos_update(struct my_device *mydev);
static void my_loopback_timer_function(unsigned long data);
static void my_loopback_xfer_buf(struct my_device *mydev, unsigned int count);
static void my_fill_capture_buf(struct my_device *mydev, unsigned int bytes);

// * functions for driver/kernel module initialization
static void bencol_unregister_all(void);
static int __init alsa_card_bencol_init(void);
static void __exit alsa_card_bencol_exit(void);

// * declare functions for this struct describing the driver (to be defined later):
static int __devinit bencol_probe(struct platform_device *devptr);
static int __devexit bencol_remove(struct platform_device *devptr);

#define SND_BENCOL_DRIVER	"snd_bencol"

// * we need a struct describing the driver:
static struct platform_driver bencol_driver =
{
	.probe		= bencol_probe,
	.remove		= __devexit_p(bencol_remove),
//~ #ifdef CONFIG_PM
	//~ .suspend	= bencol_suspend,
	//~ .resume		= bencol_resume,
//~ #endif
	.driver		= {
		.name	= SND_BENCOL_DRIVER,
		.owner = THIS_MODULE
	},
};


/*
 *
 * Probe/remove functions
 *
 */
static int __devinit bencol_probe(struct platform_device *devptr)
{

	struct snd_card *card;
	struct my_device *mydev;
	int ret;

	int nr_subdevs; // how many capture substreams we want
	struct snd_pcm *pcm;

	int dev = devptr->id; // from aloop-kernel.c

	dbg("%s: probe", __func__);


	// no need to kzalloc my_device separately, if the sizeof is included here
	ret = snd_card_create(index[dev], id[dev],
	                      THIS_MODULE, sizeof(struct my_device), &card);

	if (ret < 0)
		goto __nodev;
	
	mydev = card->private_data;
	mydev->card = card;
	// must have mutex_init here - else crash on mutex_lock!!
	mutex_init(&mydev->cable_lock); 
	
	dbg2("-- mydev %p", mydev);

	sprintf(card->driver, "my_driver-%s", SND_BENCOL_DRIVER);
	sprintf(card->shortname, "MySoundCard Audio %s", SND_BENCOL_DRIVER);
	sprintf(card->longname, "%s", card->shortname);


	snd_card_set_dev(card, &devptr->dev); // present in dummy, not in aloop though


	ret = snd_device_new(card, SNDRV_DEV_LOWLEVEL, mydev, &dev_ops);

	if (ret < 0)
		goto __nodev;


	nr_subdevs = 1; // how many capture substreams we want
	// * we want 0 playback, and 1 capture substreams (4th and 5th arg) ..
	ret = snd_pcm_new(card, card->driver, 0, 0, nr_subdevs, &pcm);

	if (ret < 0)
		goto __nodev;


	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &my_pcm_ops); // in both aloop-kernel.c and dummy.c, after snd_pcm_new...
	pcm->private_data = mydev; //here it should be dev/card struct (the one containing struct snd_card *card) - this DOES NOT end up in substream->private_data 

	pcm->info_flags = 0;
	strcpy(pcm->name, card->shortname);
	//mydev->substream->private_data = mydev; //added, to prevent mutex_lock crash - now crashes here.. 


	ret = snd_pcm_lib_preallocate_pages_for_all(pcm,
	        SNDRV_DMA_TYPE_CONTINUOUS,
	        snd_dma_continuous_data(GFP_KERNEL),
	        MAX_BUFFER, MAX_BUFFER); // in both aloop-kernel.c and dummy.c, after snd_pcm_set_ops...

	if (ret < 0)
		goto __nodev;

	// * will use the snd_card_register form from aloop-kernel.c/dummy.c here..
	ret = snd_card_register(card);

	if (ret == 0)   // or... (!ret)
	{
		platform_set_drvdata(devptr, card);
		return 0; // success
	}

__nodev: // as in aloop/dummy...
	dbg("__nodev reached!!");
	snd_card_free(card); // this will autocall .dev_free = my_pcm_dev_free
	return ret;
}

// from dummy/aloop:
static int __devexit bencol_remove(struct platform_device *devptr)
{
	dbg("%s", __func__);
	snd_card_free(platform_get_drvdata(devptr));
	platform_set_drvdata(devptr, NULL);
	return 0;
}


/*
 *
 * hw alloc/free functions
 *
 */
static int my_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params)
{
	dbg("%s", __func__);
	return snd_pcm_lib_malloc_pages(ss,
	                                params_buffer_bytes(hw_params));
}

static int my_hw_free(struct snd_pcm_substream *ss)
{
	dbg("%s", __func__);
	return snd_pcm_lib_free_pages(ss);
}


/*
 *
 * PCM functions
 *
 */
static int my_pcm_open(struct snd_pcm_substream *ss)
{
	struct my_device *mydev = ss->private_data;

	//BREAKPOINT();
	dbg("%s", __func__);

	// copied from aloop-kernel.c:
	mutex_lock(&mydev->cable_lock);
	ss->runtime->hw = my_pcm_hw;
	//ss->private_data = mydev; // circular - pointless
	/* assing runtime->private_data as in aloop-kernel.c 
	 though we don't really need it now ;
	 as substream->private_data works fine -
	 even though it should be runtime->private_data that sets it, 
	 as per "You can allocate a record for the substream and 
	store it in runtime->private_data" ... tjaah:
	struct snd_pcm_runtime *runtime = substream->runtime; ... so: */
				//seems I need this as well: 
	mydev->substream = ss; 	//save system given substream ss in our structure field
	ss->runtime->private_data = mydev; 
	// RUN THE TIMER HERE:
	setup_timer(&mydev->timer, my_loopback_timer_function,
	            (unsigned long)mydev);
	mutex_unlock(&mydev->cable_lock);
	return 0;
}

static int my_pcm_close(struct snd_pcm_substream *ss)
{
	struct my_device *mydev = ss->private_data;

	dbg("%s", __func__);
	
	// copied from aloop-kernel.c:
	// * even though mutexes are retrieved from ss->private_data:
	mutex_lock(&mydev->cable_lock);
	// * not much else to do here, but set to null:
	ss->private_data = NULL;
	mutex_unlock(&mydev->cable_lock);

	return 0;
}


static int my_pcm_prepare(struct snd_pcm_substream *ss)
{
	// empty originally, copying from aloop-kernel.c
	
	// turns out, this type of call, via runtime->private_data.
	// ends up with mydev as null pointer causing SIGSEGV
	// .. unless runtime->private_data is assigned in _open? 
	struct snd_pcm_runtime *runtime = ss->runtime;
	struct my_device *mydev = runtime->private_data;
	unsigned int bps;
	
	dbg("%s", __func__);
	
	bps = runtime->rate * runtime->channels;
	bps *= snd_pcm_format_width(runtime->format);
	bps /= 8;
	if (bps <= 0)
		return -EINVAL;

	mydev->buf_pos = 0;
	mydev->pcm_buffer_size = frames_to_bytes(runtime, runtime->buffer_size);
	dbg2("	bps: %u; runtime->buffer_size: %lu; mydev->pcm_buffer_size: %u", bps, runtime->buffer_size, mydev->pcm_buffer_size);
	if (ss->stream == SNDRV_PCM_STREAM_CAPTURE) {
		/* clear capture buffer */
		mydev->silent_size = mydev->pcm_buffer_size; // if this is set like this, then clear_capture_buf exits immediately!
		memset(runtime->dma_area, 0, mydev->pcm_buffer_size);
	}

	if (!mydev->running) {
		mydev->irq_pos = 0;
		mydev->period_update_pending = 0;
	}
	

	mutex_lock(&mydev->cable_lock);
	if (!(mydev->valid & ~(1 << ss->stream))) {
		mydev->pcm_bps = bps;
		mydev->pcm_period_size =
			frames_to_bytes(runtime, runtime->period_size);
		mydev->period_size_frac = frac_pos(mydev->pcm_period_size);

		/* don't need this, as our params here are fixed in my_pcm_hw ?
		/ * if they were variable, we would have had to have a struct like this: 
		mydev->hw.formats = (1ULL << runtime->format);
		mydev->hw.rate_min = runtime->rate;
		mydev->hw.rate_max = runtime->rate;
		mydev->hw.channels_min = runtime->channels;
		mydev->hw.channels_max = runtime->channels;
		mydev->hw.period_bytes_min = mydev->pcm_period_size;
		mydev->hw.period_bytes_max = mydev->pcm_period_size;
		*/
	}
	mydev->valid |= 1 << ss->stream;
	mutex_unlock(&mydev->cable_lock);
	
	return 0;
}


static int my_pcm_trigger(struct snd_pcm_substream *ss,
                          int cmd)
{
	int ret = 0;
	//copied from aloop-kernel.c
	//struct snd_pcm_runtime *runtime = ss->runtime;
	//struct my_device *mydev= runtime->private_data;
	struct my_device *mydev = ss->private_data; //can we? 
	
	dbg("%s - trig %d", __func__, cmd);

	switch (cmd)
	{
		case SNDRV_PCM_TRIGGER_START:
			// Start the hardware capture
			// from aloop-kernel.c:
			if (!mydev->running) {
				mydev->last_jiffies = jiffies;
				my_loopback_timer_start(mydev);
			}
			mydev->running |= (1 << ss->stream);
			break;
		case SNDRV_PCM_TRIGGER_STOP:
			// Stop the hardware capture
			// from aloop-kernel.c:
			mydev->running &= ~(1 << ss->stream);
			if (!mydev->running)
				my_loopback_timer_stop(mydev);
			break;
		default:
			ret = -EINVAL;
	}

	return ret;
}


static snd_pcm_uframes_t my_pcm_pointer(struct snd_pcm_substream *ss)
{
	/*struct my_device *mydev = snd_pcm_substream_chip(ss);
	dbg2("%s hw_idx %d", __func__, mydev->hw_idx);
	return mydev->hw_idx;*/

	//copied from aloop-kernel.c
	struct snd_pcm_runtime *runtime = ss->runtime;
	struct my_device *mydev= runtime->private_data;

	dbg2("+my_loopback_pointer ");
	my_loopback_pos_update(mydev);
	dbg2("+	bytes_to_frames(: %lu, mydev->buf_pos: %d", bytes_to_frames(runtime, mydev->buf_pos),mydev->buf_pos);
	return bytes_to_frames(runtime, mydev->buf_pos);

}

/*static int my_pcm_copy(struct snd_pcm_substream *ss,
                       int channel, snd_pcm_uframes_t pos,
                       void __user *dst,
                       snd_pcm_uframes_t count)
{
	struct my_device *mydev = snd_pcm_substream_chip(ss);

	dbg("%s", __func__);
	return copy_to_user(dst, mydev->buffer + pos, count);
}*/


//snd_pcm_period_elapsed(mydev->ss); - now in my_loopback_timer_function
/*
 *
 * Timer functions
 *
 */
static void my_loopback_timer_start(struct my_device *mydev)
{
	unsigned long tick;
	dbg2("my_loopback_timer_start: mydev->period_size_frac: %u; mydev->irq_pos: %u jiffies: %lu pcm_bps %u", mydev->period_size_frac, mydev->irq_pos, jiffies, mydev->pcm_bps);
	tick = mydev->period_size_frac - mydev->irq_pos;
	tick = (tick + mydev->pcm_bps - 1) / mydev->pcm_bps;
	mydev->timer.expires = jiffies + tick;
	add_timer(&mydev->timer);
}

static void my_loopback_timer_stop(struct my_device *mydev)
{
	dbg2("my_loopback_timer_stop");
	del_timer(&mydev->timer);
}

static void my_loopback_pos_update(struct my_device *mydev)
{
	unsigned int last_pos, count;
	unsigned long delta;

	if (!mydev->running)
		return;

	dbg2("*my_loopback_pos_update: running ");

	delta = jiffies - mydev->last_jiffies;
	dbg2("*	: jiffies %lu, ->last_jiffies %lu, delta %lu", jiffies, mydev->last_jiffies, delta);

	if (!delta)
		return;

	mydev->last_jiffies += delta;

	last_pos = byte_pos(mydev->irq_pos);
	mydev->irq_pos += delta * mydev->pcm_bps;
	count = byte_pos(mydev->irq_pos) - last_pos;
	dbg2("*	: last_pos %d, c->irq_pos %d, count %d", last_pos, mydev->irq_pos, count);

	if (!count)
		return;

	// FILL BUFFER HERE
	my_loopback_xfer_buf(mydev, count);
	if (mydev->irq_pos >= mydev->period_size_frac)
	{
		dbg2("*	: mydev->irq_pos >= mydev->period_size_frac %d", mydev->period_size_frac);
		mydev->irq_pos %= mydev->period_size_frac;
		mydev->period_update_pending = 1;
	}
}

static void my_loopback_timer_function(unsigned long data)
{
	struct my_device *mydev = (struct my_device *)data;
	//int i;

	if (!mydev->running)
		return;

	dbg2("my_loopback_timer_function: running ");
	my_loopback_pos_update(mydev);
	my_loopback_timer_start(mydev);

	if (mydev->period_update_pending)
	{
		mydev->period_update_pending = 0;

		//for (i = 0; i < 2; i++) { // we have only single substream here
		if (mydev->running)  // & (1 << i)) {
		{
			//struct my_loopback_pcm *dpcm = mydev->streams[i];
			dbg2("	: calling snd_pcm_period_elapsed");
			snd_pcm_period_elapsed(mydev->substream);
		}

		//}
	}
}

#define CABLE_PLAYBACK	(1 << SNDRV_PCM_STREAM_PLAYBACK)
#define CABLE_CAPTURE	(1 << SNDRV_PCM_STREAM_CAPTURE)
#define CABLE_BOTH	(CABLE_PLAYBACK | CABLE_CAPTURE)

static void my_loopback_xfer_buf(struct my_device *mydev, unsigned int count)
{
	//int i;

	dbg2(">my_loopback_xfer_buf: count: %d ", count );
	
	switch (mydev->running) {
	case CABLE_CAPTURE:
		my_fill_capture_buf(mydev, //->streams[SNDRV_PCM_STREAM_CAPTURE],
				  count);
		break;
	// in this case, we have only capture ... // case CABLE_BOTH: 
	}

	// only single buffer here
	//for (i = 0; i < 2; i++) {
		if (mydev->running) { // & (1 << i)) {
			//struct my_loopback_pcm *dpcm = mydev->streams[i];
			mydev->buf_pos += count;
			mydev->buf_pos %= mydev->pcm_buffer_size;
			dbg2(">	: mydev->buf_pos: %d ", mydev->buf_pos);
		}
	//}
}

static void my_fill_capture_buf(struct my_device *mydev, unsigned int bytes)
{
	char *dst = mydev->substream->runtime->dma_area;
	unsigned int dst_off = mydev->buf_pos; // buf_pos is in bytes, not in samples !
	float wrdat; // was char
	float tmpdat[]={-1.0, -1.0, -0.5, -0.5, 0.5, 0.5, 1.0, 1.0};
	unsigned int tdsz=sizeof(tmpdat);//*sizeof(float);
	unsigned int dpos = 0; //added

	dbg2("_ my_fill_capture_buf ss %d bs %d bytes %d buf_pos %d sizeof %d jiffies %lu", mydev->silent_size, mydev->pcm_buffer_size, bytes, dst_off, sizeof(*dst), jiffies);
	
	// let's clear the entire requested area
	memset(dst, 255, bytes);
	// let's just copy tmpdat at start of dst buffer!! 
	memcpy(dst, tmpdat, tdsz); // YUP, with this, its tight... !
	// loop it.. fill a value until end.. 
	wrdat=0.5;
	while (dpos < bytes)
	{
		memcpy(dst + dst_off + dpos, &wrdat, sizeof(wrdat)); 
		dpos += sizeof(wrdat);
		if (dpos >= bytes) break;
	}
	
	if (mydev->silent_size >= mydev->pcm_buffer_size)
		return;
	
	// usually, the code has returned by now - it doesn't even come here!
	
	if (mydev->silent_size + bytes > mydev->pcm_buffer_size)
		bytes = mydev->pcm_buffer_size - mydev->silent_size;

	wrdat = -0.2; // value to copy, instead of 0 for silence (if needed)
	
	for (;;) {
		unsigned int size = bytes;
		dpos = 0; //added
		dbg2("_ clearrr..	%d", bytes);
		if (dst_off + size > mydev->pcm_buffer_size)
			size = mydev->pcm_buffer_size - dst_off;

		//memset(dst + dst_off, 255, size); //0, size);
		while (dpos < size)
		{
			memcpy(dst + dst_off + dpos, &wrdat, sizeof(wrdat)); 
			dpos += sizeof(wrdat);
			if (dpos >= size) break;
		}
		mydev->silent_size += size;
		bytes -= size;
		if (!bytes)
			break;
		dst_off = 0;
	}
}





/*
 *
 * snd_device_ops free functions
 *
 */
// these should eventually get called by snd_card_free (via .dev_free)
// however, since we do no special allocations, we need not free anything 
static int my_pcm_free(struct my_device *chip)
{
	//~ ....
	//~ if (chip->iobase_virt)
	//~ iounmap(chip->iobase_virt);
	//~ ....
	//~ pci_release_regions(chip->pci);
	//~ ....
	dbg("%s", __func__);
	return 0;
}

static int my_pcm_dev_free(struct snd_device *device)
{
	dbg("%s", __func__);
	return my_pcm_free(device->device_data);
}



/*
 *
 * functions for driver/kernel module initialization
 * (_init, _exit)
 * copied from aloop-kernel.c (same in dummy.c)
 *
 */
static void bencol_unregister_all(void)
{
	int i;

	dbg("%s", __func__);

	for (i = 0; i < ARRAY_SIZE(devices); ++i)
		platform_device_unregister(devices[i]);

	platform_driver_unregister(&bencol_driver);
}

static int __init alsa_card_bencol_init(void)
{
	int i, err, cards;

	dbg("%s", __func__);
	err = platform_driver_register(&bencol_driver);

	if (err < 0)
		return err;


	cards = 0;

	for (i = 0; i < SNDRV_CARDS; i++)
	{
		struct platform_device *device;

		if (!enable[i])
			continue;

		device = platform_device_register_simple(SND_BENCOL_DRIVER,
		         i, NULL, 0);

		if (IS_ERR(device))
			continue;

		if (!platform_get_drvdata(device))
		{
			platform_device_unregister(device);
			continue;
		}

		devices[i] = device;
		cards++;
	}

	if (!cards)
	{
#ifdef MODULE
		printk(KERN_ERR "bencol-alsa: No enabled, not found or device busy\n");
#endif
		bencol_unregister_all();
		return -ENODEV;
	}

	return 0;
}

static void __exit alsa_card_bencol_exit(void)
{
	dbg("%s", __func__);
	bencol_unregister_all();
}

module_init(alsa_card_bencol_init)
module_exit(alsa_card_bencol_exit)

