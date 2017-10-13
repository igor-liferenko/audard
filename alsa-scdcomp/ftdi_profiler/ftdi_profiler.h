/*******************************************************************************
* ftdi_profiler.h                                                              *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/

// options also visible from:
// ls /sys/module/ftdi_profiler/parameters/

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
//~ #include <sound/core.h>
//~ #include <sound/control.h>
//~ #include <sound/pcm.h>
//~ #include <sound/initval.h>
//~ #include <sound/info.h> //for snd_card_proc_new
#include <linux/proc_fs.h> //for create_proc_read_entry; which is eliminated 11 Apr 2013 (use proc_create_data() and seq_file instead; see also LDD3)
#include <linux/seq_file.h> /* /proc entry */

// '((2) << 16) + ((6) << 8) + (38) == 132646 for 2,6,38
#include <linux/version.h> // for LINUX_VERSION_CODE; KERNEL_VERSION
//~ #define STRINGIFY(s) XSTRINGIFY(s)
//~ #define XSTRINGIFY(s) #s
//~ #pragma message "vers code " STRINGIFY(LINUX_VERSION_CODE) STRINGIFY(KERNEL_VERSION(2,6,38))

#define dbg2(format, arg...) do { } while (0)
//~ #define dbg2(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)
#define dbg3(format, arg...) do { } while (0)
//~ #define dbg3(format, arg...) do { printk( ": " format "\n" , ## arg); } while (0)

#define __FTDI_PROFILER_H

// Module parameters (for me, int==long):
static unsigned int bytes_per_write = 0;
static unsigned long write_period_ns = 0;
static unsigned long test_duration_s = 0;
static unsigned long test_duration_ns = 0;

// the datatypes here: uint, not unsigned int!
// also, for some reason getting errors if specify perms as 0744
module_param(bytes_per_write, uint, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(bytes_per_write, "Write packet size [bytes]");
module_param(write_period_ns, ulong, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(write_period_ns, "Write period [nsecs, sec assumed zero]");
module_param(test_duration_s, ulong, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(test_duration_s, "Test duration [secs]");
module_param(test_duration_ns, ulong, S_IRUGO | S_IWUSR);
MODULE_PARM_DESC(test_duration_ns, "Test duration [nsecs]");

static ktime_t write_period_kt;
static ktime_t test_duration_kt;

static unsigned long byterate;

static int ftdi_profiler_isRunning = 0;
static unsigned long ftdi_profiler_wrcount = 0;
static unsigned long ftdi_profiler_rdcount = 0;
static unsigned long ftdi_profiler_wrtotb = 0;
static unsigned long ftdi_profiler_rdtotb = 0;
static ktime_t ftdi_profiler_base_time;
static struct hrtimer ftdi_profiler_wr_hrtimer;
static struct tasklet_struct ftdi_profiler_wrtasklet;
static unsigned char *ftdi_profiler_wrpacket = NULL;

struct audard_device
{
	struct ftdi_private *ftdipr; 				// pointer back
	unsigned char isSerportOpen;
	/* mixer related variables - not used here: */
	//~ spinlock_t mixer_lock;
	//~ int mixer_volume[MIXER_ADDR_LAST+1][2];
	//~ int capture_source[MIXER_ADDR_LAST+1][2];
	struct mutex cable_lock; 					// mutex here - just in case
	unsigned int valid;							// (not used)
	unsigned int running;
	unsigned int period_update_pending :1;		// (not used)
	/* from snd_usb_audio struct: */
	u32 usb_id;
};

static struct audard_device *ftdi_profiler_mydev;


// now for __FTDI_PROFILER_H - also getting status bytes
static void audard_xfer_buf(struct audard_device *mydev, char *inch, unsigned int count)
{
  int len = count-2;
  if ( (len > 0) && (inch[0] == 1)) {
    ftdi_profiler_rdcount++;
    ftdi_profiler_rdtotb+=len;
  }
  trace_printk("2 %02hhX %02hhX %d %lu %lu %lld\n", inch[0], inch[1], len, ftdi_profiler_rdcount, ftdi_profiler_rdtotb, 0LL);
}

static int ftdi_profiler_are_params_invalid(void) {
  if ( !( bytes_per_write>0 && write_period_ns>0 && test_duration_ns>0 ) ) {
    return 1;
  }
  write_period_kt = ktime_set(0, write_period_ns);
  test_duration_kt = ktime_set(test_duration_s, test_duration_ns);
  byterate = div_u64(bytes_per_write*((unsigned long long)1E9L), write_period_ns);
  return 0;
}


static void ftdi_profiler_wrtasklet_func(unsigned long priv)
{
  //~ struct snd_audard_pcm *dpcm = (struct snd_audard_pcm *)priv;
  u64 delta; // time
  u64 posdelta; //bytes as per byterate
  struct usb_serial_port *usport = ftdi_profiler_mydev->ftdipr->port;
  delta = ktime_us_delta(hrtimer_cb_get_time(&ftdi_profiler_wr_hrtimer),
             ftdi_profiler_base_time);
  if (delta*((unsigned long long)1E3L) >= ktime_to_ns(test_duration_kt)) {
    ftdi_profiler_isRunning = 0;
    ftdi_profiler_mydev->running = 0;
    //~ ftdi_close(ftdi_profiler_mydev->ftdipr->port); // apparently causes kernel panic here!
    return;
  }
  posdelta = div_u64(delta * byterate + 999999, 1000000);

  ftdi_write(NULL, usport, ftdi_profiler_wrpacket, bytes_per_write);
  ftdi_profiler_wrcount++;
  ftdi_profiler_wrtotb+=bytes_per_write;
  trace_printk("1 %02hhX %02hhX %d %lu %lu %lld\n", 0, 0, bytes_per_write, ftdi_profiler_wrcount, ftdi_profiler_wrtotb, posdelta-ftdi_profiler_wrtotb);
}


static enum hrtimer_restart ftdi_profiler_wrtimer_function(struct hrtimer *timer)
{
	if (!ftdi_profiler_isRunning) {
		return HRTIMER_NORESTART;
  }

  tasklet_hi_schedule(&ftdi_profiler_wrtasklet);
  hrtimer_forward_now(&ftdi_profiler_wr_hrtimer, write_period_kt);
  return HRTIMER_RESTART;
}


static void ftdi_profiler_startup(void)
{
  if (ftdi_profiler_isRunning == 0) {
    ftdi_profiler_isRunning = 1;
    ftdi_profiler_mydev->running = 1;
    ftdi_profiler_wrcount = 0;
    ftdi_profiler_rdcount = 0;
    ftdi_profiler_wrtotb = 0;
    ftdi_profiler_rdtotb = 0;
    if (!ftdi_profiler_mydev->isSerportOpen)
      ftdi_open(NULL, ftdi_profiler_mydev->ftdipr->port);
    if (ftdi_profiler_wrpacket != NULL)
      kfree(ftdi_profiler_wrpacket);
    ftdi_profiler_wrpacket = (unsigned char*)kzalloc(bytes_per_write, GFP_KERNEL);
    trace_printk("0\n");
    ftdi_profiler_base_time = hrtimer_cb_get_time(&ftdi_profiler_wr_hrtimer);
    hrtimer_start(&ftdi_profiler_wr_hrtimer, write_period_kt, HRTIMER_MODE_REL_PINNED);
  }
}


static int ftdi_profiler_proc_show(struct seq_file *m, void *v) {
  if (ftdi_profiler_isRunning == 0) {
    if (ftdi_profiler_are_params_invalid()) {
      seq_printf(m, "# ftdi_profiler: invalid params: bytes_per_write, write_period_ns, test_duration_ns must be greater than zero.\n");
      return 0;
    }
    seq_printf(m, "# ftdi_profiler: bytes_per_write %d write_period_kt %lld byterate %lu test_duration_kt %lld packets %llu\n",
      bytes_per_write, ktime_to_ns(write_period_kt), byterate, ktime_to_ns(test_duration_kt),
      div_u64(ktime_to_ns(test_duration_kt), ktime_to_ns(write_period_kt)) );
    //~ seq_printf(m, "# ftdi_profiler proc: startup\n");
    ftdi_profiler_startup();
  } else {
    seq_printf(m, "# ftdi_profiler proc: (is running, %lu %lu)\n", ftdi_profiler_wrcount, ftdi_profiler_rdcount);
  }
  return 0;
}

static int ftdi_profiler_proc_open(struct inode *inode, struct  file *file) {
  return single_open(file, ftdi_profiler_proc_show, NULL);
}

static const struct file_operations ftdi_profiler_proc_fops = {
  .owner = THIS_MODULE,
  .open = ftdi_profiler_proc_open,
  .read = seq_read,
  .llseek = seq_lseek,
  .release = single_release,
};


/*
 *
 * Probe/remove functions
 *
 */
static int audard_probe(struct usb_serial *serial)
{
	//~ struct audard_device *mydev;
  ftdi_profiler_mydev = (struct audard_device *) kzalloc(sizeof(struct audard_device), GFP_KERNEL);
  hrtimer_init(&ftdi_profiler_wr_hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL_PINNED);
  tasklet_init(&ftdi_profiler_wrtasklet, ftdi_profiler_wrtasklet_func, 0); //(unsigned long)dpcm);
  ftdi_profiler_wr_hrtimer.function = &ftdi_profiler_wrtimer_function;
  proc_create("ftdi_profiler", 0, NULL, &ftdi_profiler_proc_fops);
  return 0;
}

// just to set ftdi_private - _probe 2nd part:
static int audard_probe_fpriv(struct ftdi_private *priv)
{
	priv->audev = ftdi_profiler_mydev;
	ftdi_profiler_mydev->ftdipr = priv;	// .. and reflink back ..
  return 0;
}


static void audard_remove(void)
{
  if ( (hrtimer_active(&ftdi_profiler_wr_hrtimer) != 0) || (hrtimer_is_queued(&ftdi_profiler_wr_hrtimer) != 0)  ) {
    hrtimer_cancel(&ftdi_profiler_wr_hrtimer);
  }
  if (ftdi_profiler_mydev->isSerportOpen)
    ftdi_close(ftdi_profiler_mydev->ftdipr->port);
  kfree(ftdi_profiler_mydev);
  if (ftdi_profiler_wrpacket != NULL)
    kfree(ftdi_profiler_wrpacket);
  remove_proc_entry("ftdi_profiler", NULL /* parent dir */);
  return;
}





