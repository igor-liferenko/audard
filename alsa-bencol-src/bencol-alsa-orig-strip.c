/*
http://ben-collins.blogspot.com/2010/04/writing-alsa-driver.html
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
static int my_pcm_open(struct snd_pcm_substream *ss);
static int my_pcm_close(struct snd_pcm_substream *ss);
static int my_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params);
static int my_hw_free(struct snd_pcm_substream *ss);
static int my_pcm_prepare(struct snd_pcm_substream *ss);
static int my_pcm_trigger(struct snd_pcm_substream *ss,
                          int cmd);
static snd_pcm_uframes_t my_pcm_pointer(struct snd_pcm_substream *ss);
static int my_pcm_copy(struct snd_pcm_substream *ss,
                       int channel, snd_pcm_uframes_t pos,
                       void __user *dst,
                       snd_pcm_uframes_t count);

static int my_pcm_dev_free(struct snd_device *device);
//static int my_pcm_free(struct my_device *chip); //behind my_device def


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
	.copy      = my_pcm_copy,
};


static struct snd_device_ops dev_ops =
{
	.dev_free = my_pcm_dev_free, //snd_mychip_dev_free,
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
};

// * first declare functions for this struct describing the driver (to be defined later):
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


	ret = snd_card_create(index[dev], id[dev],
	                      THIS_MODULE, sizeof(struct my_device), &card);

	if (ret < 0)
		goto __nodev; // return ret;

	mydev = card->private_data;
	mydev->card = card;


	sprintf(card->driver, "my_driver-%s", SND_BENCOL_DRIVER); //strcpy(card->driver, "my_driver");
	sprintf(card->shortname, "MySoundCard Audio %s", SND_BENCOL_DRIVER); //strcpy(card->shortname, "MySoundCard Audio");
	sprintf(card->longname, "%s", card->shortname);


	snd_card_set_dev(card, &devptr->dev); //was &pci_dev->dev); // present in dummy, not in aloop though


	ret = snd_device_new(card, SNDRV_DEV_LOWLEVEL, mydev, &dev_ops); //was &ops);

	if (ret < 0)
		goto __nodev; // return ret;


	nr_subdevs = 1; // how many capture substreams we want
	// * we want 0 playback, and 1 capture substreams (4th and 5th arg) ..
	ret = snd_pcm_new(card, card->driver, 0, 0, nr_subdevs, &pcm);

	if (ret < 0)
		goto __nodev; // return ret;


	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &my_pcm_ops); // in both aloop-kernel.c and dummy.c, after snd_pcm_new...
	pcm->private_data = mydev; //here it should be dev/card struct (the one containing struct snd_card *card)
	pcm->info_flags = 0;
	strcpy(pcm->name, card->shortname);


	ret = snd_pcm_lib_preallocate_pages_for_all(pcm,
	        SNDRV_DMA_TYPE_CONTINUOUS,
	        snd_dma_continuous_data(GFP_KERNEL),
	        MAX_BUFFER, MAX_BUFFER); // in both aloop-kernel.c and dummy.c, after snd_pcm_set_ops...

	if (ret < 0)
		goto __nodev; // return ret;

	// * will use the snd_card_register form from aloop-kernel.c/dummy.c here..
	ret = snd_card_register(card);

	if (ret == 0)   // or... (!ret)
	{
		platform_set_drvdata(devptr, card);
		return 0; // success
	}

__nodev: // as in aloop/dummy...
	dbg("__nodev reached!!");
	snd_card_free(card);
	return ret; // err;
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
 * PCM functions
 *
 */
static int my_pcm_open(struct snd_pcm_substream *ss)
{
	struct my_device *my_dev = ss->private_data;

	dbg("%s", __func__);
	ss->runtime->hw = my_pcm_hw;
	ss->private_data = my_dev;

	return 0;
}

static int my_pcm_close(struct snd_pcm_substream *ss)
{
	dbg("%s", __func__);
	ss->private_data = NULL;

	return 0;
}


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

static int my_pcm_prepare(struct snd_pcm_substream *ss)
{
	dbg("%s", __func__);
	return 0;
}


static int my_pcm_trigger(struct snd_pcm_substream *ss,
                          int cmd)
{
	int ret = 0;

	dbg("%s - trig %d", __func__, cmd);

	switch (cmd)
	{
		case SNDRV_PCM_TRIGGER_START:
			// Start the hardware capture
			break;
		case SNDRV_PCM_TRIGGER_STOP:
			// Stop the hardware capture
			break;
		default:
			ret = -EINVAL;
	}

	return ret;
}


static snd_pcm_uframes_t my_pcm_pointer(struct snd_pcm_substream *ss)
{
	struct my_device *my_dev = snd_pcm_substream_chip(ss);

	dbg2("%s hw_idx %d", __func__, my_dev->hw_idx);


	return my_dev->hw_idx;
}

static int my_pcm_copy(struct snd_pcm_substream *ss,
                       int channel, snd_pcm_uframes_t pos,
                       void __user *dst,
                       snd_pcm_uframes_t count)
{
	struct my_device *my_dev = snd_pcm_substream_chip(ss);

	dbg("%s", __func__);
	return copy_to_user(dst, my_dev->buffer + pos, count);
}


//snd_pcm_period_elapsed(my_dev->ss);


/*
 *
 * snd_device_ops free functions
 *
 */
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

