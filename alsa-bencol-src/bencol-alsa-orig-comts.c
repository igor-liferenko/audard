/*
http://ben-collins.blogspot.com/2010/04/writing-alsa-driver.html

My driver needed to be pretty simple. The encoder produced 8Khz mono G.723-24 ADPCM. So you can avoid the wikepedia trip, that's 3-bits per sample, or 24000 bits per second. The card produced this at a rate of 128 samples per interrupt (48 bytes) for every channel available (you cannot disable each channel).

The card delivered this data in a 32kbyte buffer, split into 32 pages. Each page was written as 48*20 channels, which took up 960 bytes of the 1024 byte page (it could do up to this number, but for my purposes I was only using 4, 8 or 16 channels of encoded data depending on the capabilities of the card).

...

First, where to start in ALSA. I had to decide how to expose these capture interfaces. I could have exposed a capture device for each channel, but instead I chose to expose one capture interface with a subdevice for each channel. This made programming a bit easier, gave a better overview of the devices as perceived by ALSA, and kept /dev/snd/ less cluttered (especially when you had multiple 16-channel cards installed). It also made programming userspace easier since it kept channels hierarchically under the card/device.
*/

#define DEBUG // 1 // doesn't help
#define CONFIG_MODULE_FORCE_UNLOAD

//~ #define CONFIG_USB_DEBUG // doesn't help here

// i have a typical 'hello world' module, on off-the-shelf ubuntu karmic, and can not get it to printk anything, anywhere, anyhow.... all the while with a tail -f /var/log/kern.log running.
// http://old.nabble.com/printk-is-not-my-friend-td28141909.html

//http://www.n1ywb.com/projects/darts/darts-usb/darts-usb.c - /* Use our own dbg macro */
#define CONFIG_USB_DEBUG

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
/* initiate communication with remote gdb */

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
//static int pcm_substreams[SNDRV_CARDS] = {[0 ... (SNDRV_CARDS - 1)] = 8}; // try without this - i.e. one stream per card

static struct platform_device *devices[SNDRV_CARDS];


//Here is a look at the snd_pcm_hardware structure I have for my driver. It's fairly simplistic:
// This structure describes how my hardware lays out the PCM data for capturing. As I described before, it writes out 48 bytes at a time for each stream, into 32 pages. A period basically describes an interrupt. It sums up the "chunk" size that the hardware supplies data in. - so MAX_BUFFER
// This hardware only supplies mono data (1 channel) and only 8000HZ sample rate. Most hardware seems to work in the range of 8000 to 48000, and there is a define for that of SNDRV_PCM_RATE_8000_48000. This is a bit masked field, so you can add whatever rates your harware supports.
#define MAX_BUFFER (32 * 48)
static struct snd_pcm_hardware my_pcm_hw = {
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

// Next we must associate the handlers for capturing sound data from our hardware. We have a struct defined as such:
// In the previous post, Writing an ALSA driver: Setting up capture, we defined my_pcm_ops, which was used when calling snd_pcm_set_ops() for our PCM device. Here is that structure again:
static struct snd_pcm_ops my_pcm_ops = {
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

// from takashi: "Next, initialize the fields, and register this chip record as a low-level device with a specified ops,... snd_mychip_dev_free() is the device-destructor function, which will call the real destructor."
static struct snd_device_ops dev_ops = {
	.dev_free = my_pcm_dev_free, //snd_mychip_dev_free,
};


// *  we need a struct describing the device? - corresponds to struct snd_dummy (dummy.c) or struct loopback (aloop-kernel.c) // not given in the original article
struct my_device {
	struct snd_card *card;
	struct snd_pcm *pcm;
	spinlock_t mixer_lock;
	//int mixer_volume[MIXER_ADDR_LAST+1][2];
	//int capture_source[MIXER_ADDR_LAST+1][2];
	//const struct dummy_timer_ops *timer_ops;
	const struct my_pcm_ops *timer_ops;
	unsigned char *buffer;
	int hw_idx; 
};

// * we need a struct describing the driver:
// * first declare functions for this struct, to be defined later:
static int __devinit bencol_probe(struct platform_device *devptr);
static int __devexit bencol_remove(struct platform_device *devptr);

#define SND_BENCOL_DRIVER	"snd_bencol"

static struct platform_driver bencol_driver = {
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

// in __devinit  
// in aloop-kernel.c __devinit loopback_pcm_new (called from loopback_probe), we have 'platform_set_drvdata(devptr, card);' 
// in dummy.c __devinit snd_dummy_probe, we have (as well as in bencol) 'snd_card_set_dev(card, &devptr->dev);'




static int __devinit bencol_probe(struct platform_device *devptr)
{
//So first off I needed to register with ALSA that we actually have a sound card. This bit is easy, and looks like this:
// This asks ALSA to allocate a new sound card with the name "MySoundCard". This is also the name that appears in /proc/asound/ as a symlink to the card ID (e.g. "card0"). In my particular instance I actually name the card with an ID number, so it ends up being "MySoundCard0". This is because I can, and typically do, have more than one installed at a time for this type of device
// * should be in _probe
struct snd_card *card;
struct my_device *mydev;
int ret;
	
int nr_subdevs; // how many capture substreams we want
struct snd_pcm *pcm;

int dev = devptr->id; // from aloop-kernel.c

dbg("%s: probe", __func__); 


//(writing-an-alsa-driver.pdf: "Chip-Specific Data/ 1. Allocating via snd_card_create(). 2. Allocating an extra device.")
// if 0 in snd_card_create, then we *must* do mydev=kzalloc... afterwards, and mydev *must* contain ->card
// id sizeof(struct my_device) in snd_card_create, then we don't have to do separate kzalloc! 
//ret = snd_card_create(SNDRV_DEFAULT_IDX1, "MySoundCard",
ret = snd_card_create(index[dev], id[dev],
//                      THIS_MODULE, 0, &card);
		      THIS_MODULE, sizeof(struct my_device), &card);
//err = snd_card_create(index[dev], id[dev], THIS_MODULE,
//		      sizeof(struct snd_dummy), &card);
if (ret < 0)
        goto __nodev; // return ret;
// in both aloop-kernel.c and dummy.c, after snd_card_create we have these moves:
mydev = card->private_data;
mydev->card = card;


// Next, we set some of the properties of this new card.
// Here, we've assigned the name of the driver that handles this card, which is typically the same as the actual name of your driver. Next is a short description of the hardware, followed by a longer description. Most drivers seem to set the long description to something containing the PCI info. If you have some other bus, then the convention would follow to use information from that particular bus. Finally, set the parent device associated with the card. Again, since this is a PCI device, I set it to that.
strcpy(card->driver, "my_driver");
strcpy(card->shortname, "MySoundCard Audio");
//sprintf(card->longname, "%s on %s IRQ %d", card->shortname, pci_name(pci_dev), pci_dev->irq); // no PCI here
sprintf(card->longname, "%s", card->shortname);
// takashi: "Registration of Device Struct: At some point, typically after calling snd_device_new(), you need to register the struct device of the chip you're handling for udev and co. ALSA provides a macro for compatibility with older kernels. Simply call like the following: snd_card_set_dev...  so that it stores the PCI's device pointer to the card. This will be referred by ALSA core functions later when the devices are registered. In the case of non-PCI, pass the proper device struct pointer of the BUS instead. (In the case of legacy ISA without PnP, you don't have to do anything.) "
snd_card_set_dev(card, &devptr->dev); //was &pci_dev->dev); // present in dummy, not in aloop though

// Now to set this card up in ALSA along with a decent description of how the hardware works. We add the next bit of code to do this:
// We're basically telling ALSA to create a new card that is a low level sound driver. The mydev argument is passed as the private data that is associated with this device, for your convenience. We leave the ops structure as a no-op here for now.
// takashi: "After the card is created, you can attach the components (devices) to the card instance. In an ALSA driver, a component is represented as a struct snd_device object. A component can be a PCM instance, a control interface, a raw MIDI interface, etc. Each such instance has one component entry. A component can be created via snd_device_new() function. This function itself doesn't allocate the data space. THE DATA MUST BE ALLOCATED MANUALLY BEFOREHAND, and its pointer is passed as the argument. This pointer is used as the (chip identifier in the above example) for the instance. " - so we need mydev = kzalloc ...? or just above with the sizeof?  
// static struct snd_device_ops ops = { NULL };
// also snd_device_new not found in either dummy nor aloop-kernel - those have snd_pcm_new. 
// SO: takashi: "After the card is created, you can attach the components (devices) to the card instance. In an ALSA driver, a component is represented as a struct snd_device object. A component can be a PCM instance, a control interface, a raw MIDI interface, etc. Each such instance has one component entry. A component can be created via snd_device_new() function. " ...
// AND: takashi: "A pcm instance is allocated by the snd_pcm_new() function. It would be better to create a constructor for pcm, "  
// ALSO: snd_device_ops:: .dev_free = snd_mychip_dev_free; not the pcm ops trigger etc.. 
// ------
// so I should probably go directly with snd_pcm_new - as the ops struct is also snd_pcm_ops? NO because snd_pcm_new is below - added a snd_device_ops struct
// NOTE: note: expected ‘struct snd_device_ops *’ but argument is of type ‘struct snd_pcm_ops *’
ret = snd_device_new(card, SNDRV_DEV_LOWLEVEL, mydev, &dev_ops); //was &ops); //mydev == devptr?? probably not.. 
if (ret < 0)
        goto __nodev; // return ret;


//ALSA provides a PCM API in its middle layer. We will be making use of this to register a single PCM capture device that will have a number of subdevices depending on the low level hardware I have. NOTE: All of the initialization below must be done just before the call to snd_card_register() in the last posting.
// we allocate a new PCM structure. We pass the card we allocated beforehand. The second argument is a name for the PCM device, which I have just conveniently set to the same name as the driver. It can be whatever you like. The third argument is the PCM device number. Since I am only allocating one, it's set to 0.
//The third (fourth!) and fourth (fifth!) arguments are the number of playback and capture streams associated with this device. For my purpose, playback is 0 and capture is the number I have detected that the card supports (4, 8 or 16).
//The last argument is where ALSA allocates the PCM device. It will associate any memory for this with the card, so when we later call snd_card_free(), it will cleanup our PCM device(s) as well.
// * 0 playback, 1 capture substream (nr_subdevs).. 
nr_subdevs = 1; // how many capture substreams we want
//ret = snd_pcm_new(card, card->driver, 0, 0, nr_subdevs, &pcm);
ret = snd_pcm_new(card, card->driver, 0, 0, nr_subdevs, &pcm);
if (ret < 0)
        goto __nodev; // return ret;



// I will go into the details of how to define these handlers in the next post, but for now we just want to let the PCM middle layer know to use them:
// Here, we first set the capture handlers for this PCM device to the one we defined above. Afterwards, we also set some basic info for the PCM device such as adding our main device as part of the private data (so that we can retrieve it more easily in the handler callbacks).
// takashi:"After the pcm is created, you need to set operators for each pcm stream... The operators are defined typically like this:... All the callbacks are described in the Operators subsection."
snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &my_pcm_ops); // in both aloop-kernel.c and dummy.c, after snd_pcm_new...
pcm->private_data = mydev; //mydev == devptr?? nope, here it should be driver struct (like 'struct snd_dummy *dummy' or 'struct loopback *loopback'; that is the one containing struct snd_card *card) - so struct my_device *mydev; somewhere up 
pcm->info_flags = 0;
strcpy(pcm->name, card->shortname);


// Now that we've made the device, we want to initialize the memory management associated with the PCM middle layer. ALSA provides some basic memory handling routines for various functions. We want to make use of it since it allows us to reduce the amount of code we write and makes working with userspace that much easier.
// The MAX_BUFFER is something we've defined earlier and will be discussed further in the next post. Simply put, it's the maximum size of the buffer in the hardware (the maximum size of data that userspace can request at one time without waiting on the hardware to produce more data).
// We are using the simple continuous buffer type here. Your hardware may support direct DMA into the buffers, and as such you would use something like snd_dma_dev() along with your PCI device to initialize this. I'm using standard buffers because my hardware will require me to handle moving data around manually.
ret = snd_pcm_lib_preallocate_pages_for_all(pcm,
                     SNDRV_DMA_TYPE_CONTINUOUS,
                     snd_dma_continuous_data(GFP_KERNEL),
                     MAX_BUFFER, MAX_BUFFER); // in both aloop-kernel.c and dummy.c, after snd_pcm_set_ops... 
if (ret < 0)
        goto __nodev; // return ret;





// Lastly, to complete the registration with ALSA: 
//ALSA now knows about this card, and lists it in /proc/asound/ among other places such as /sys. We still haven't told ALSA about the interfaces associated with this card (capture/playback).
/*
if ((ret = snd_card_register(card)) < 0)
        return ret;
*/
// * will use the form from aloop-kernel.c/dummy.c here.. 
ret = snd_card_register(card);
if (ret == 0) { // or... (!ret)
	platform_set_drvdata(devptr, card);
	return 0; // success
}


__nodev: // as in aloop/dummy... 
//One last thing, when you cleanup your device/driver, you must do so through ALSA as well, like this: 
// This will cleanup all items associated with this card, including any devices that we will register later.
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


//First let's start off with the open and close methods defined in this structure. This is where your driver gets notified that someone has opened the capture device (file open) and subsequently closed it.
// This is the minimum you would do for these two functions. If needed, you would allocate private data for this stream and free it on close.
static int my_pcm_open(struct snd_pcm_substream *ss)
{
	// note in _open: struct snd_dummy *dummy = snd_pcm_substream_chip(substream);
	//struct snd_pcm_runtime *runtime = ss->runtime;
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


// The next three callbacks handle hardware setup.
// Since we've been using standard memory allocation routines from ALSA, these functions stay fairly simple. If you have some special exceptions between different versions of the hardware supported by your driver, you can make changes to the ss->hw structure here (e.g. if one version of your card supports 96khz, but the rest only support 48khz max).
// The PCM prepare callback should handle anything your driver needs to do before alsa-lib can ask it to start sending buffers. My driver doesn't do anything special here, so I have an empty callback.
static int my_hw_params(struct snd_pcm_substream *ss,
                        struct snd_pcm_hw_params *hw_params)
{
	// takashi: "Once the buffer is pre-allocated, you can use the allocator in the hw_params callback: ... Note that you have to pre-allocate (snd_pcm_lib_preallocate_pages_for_all) to use this function."
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


// This next handler tells your driver when ALSA is going to start and stop capturing buffers from your device. Most likely you will enable and disable interrupts here.
static int my_pcm_trigger(struct snd_pcm_substream *ss,
                          int cmd)
{
        //struct my_device *my_dev = snd_pcm_substream_chip(ss);
        int ret = 0;

	dbg("%s - trig %d", __func__, cmd); 

        switch (cmd) {
        case SNDRV_PCM_TRIGGER_START:
                // Start the hardware capture
                break;
        case SNDRV_PCM_TRIGGER_STOP:
                // Stop the hardware capture
                break;
        default:
                ret = -EINVAL;
        }

	// just for fun??
	// don't try snd_pcm_period_elapsed here - not even for fun!! TOTAL FREEZE
	//snd_pcm_period_elapsed(ss);  
	// it should be called from timer_function, when it fires.. 
	
        return ret;
}


// Let's move on to the handlers that are the work horse in my driver. Since the hardware that I'm writing my driver for cannot directly DMA into memory that ALSA has supplied for us to communicate with userspace, I need to make use of the copy handler to perform this operation.
// So here we've defined a pointer function which gets called by userspace to find our where the hardware is in writing to the buffer.
static snd_pcm_uframes_t my_pcm_pointer(struct snd_pcm_substream *ss)
{
        struct my_device *my_dev = snd_pcm_substream_chip(ss);

	dbg2("%s hw_idx %d", __func__, my_dev->hw_idx); 
	
	// just for fun??
	// don't try snd_pcm_period_elapsed here - not even for fun!! TOTAL FREEZE
	//snd_pcm_period_elapsed(ss);  
	// it should be called from timer_function, when it fires.. 
        
	return my_dev->hw_idx;
}

//Next, we have the actual copy function. You should note that count and pos are in sample sizes, not bytes. The buffer I've shown we assume to have been filled during interrupt.
static int my_pcm_copy(struct snd_pcm_substream *ss,
                       int channel, snd_pcm_uframes_t pos,
                       void __user *dst,
                       snd_pcm_uframes_t count)
{
        struct my_device *my_dev = snd_pcm_substream_chip(ss);

	dbg("%s", __func__); 
        return copy_to_user(dst, my_dev->buffer + pos, count);
}


// Speaking of interrupt, that is where you should also signal to ALSA that you have more data to consume. In my ISR (interrupt service routine), I have this:
// * also in dummy_systimer_callback/dummy_hrtimer_pcm_elapsed ; or loopback_timer_function
// * tasklet_init(&dpcm->tasklet, dummy_hrtimer_pcm_elapsed, 		     (unsigned long)dpcm); in dummy_hrtimer_create
// * setup_timer(&cable->timer, loopback_timer_function, 			    (unsigned long)cable); in loopback_open
//snd_pcm_period_elapsed(my_dev->ss);

//static int snd_mychip_free(struct my_dev *chip)
//static int my_pcm_free(struct my_dev *chip)
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


//static int snd_mychip_dev_free(struct snd_device *device) // snd_device is alsa (core.h)
static int my_pcm_dev_free(struct snd_device *device)
{
	dbg("%s", __func__); 
	return my_pcm_free(device->device_data);
}



// functions for driver/kernel module initialization - copied from aloop-kernel.c (same in dummy.c) 
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
	for (i = 0; i < SNDRV_CARDS; i++) {
		struct platform_device *device;
		if (!enable[i])
			continue;
		device = platform_device_register_simple(SND_BENCOL_DRIVER,
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

