/*******************************************************************************
* testjiffy.c                                                                  *
* Part of the {alsa-}scdcomp{-alsa} collection                                 *
*                                                                              *
* Copyleft 2013-2014, sdaau <sd[at]imi.aau.dk>                                 *
* This program is free software, released under the GNU General Public License.*
* NO WARRANTY; for license information see the file LICENSE                    *
*******************************************************************************/
/*
 *  [http://www.tldp.org/LDP/lkmpg/2.6/html/lkmpg.html#AEN189 The Linux Kernel Module Programming Guide]
 */


#include <linux/module.h>	/* Needed by all modules */
#include <linux/kernel.h>	/* Needed for KERN_INFO */
#include <linux/init.h>		/* Needed for the macros */
#include <linux/jiffies.h>
#include <linux/time.h>
#define MAXRUNS 10

//~ #include <linux/spinlock.h> //

static volatile int runcount = 0;

static struct timer_list my_timer;
//~ static spinlock_t my_lock = SPIN_LOCK_UNLOCKED;

static void testjiffy_timer_function(unsigned long data)
{
  int tdelay = 100;
  unsigned long tjlast;
  unsigned long tjnow;

  runcount++;
  if (runcount == 5) {
    while (tdelay > 0) { tdelay--; } // small delay
  }

  printk(KERN_INFO
    " %s: runcount %d \n",
    __func__, runcount);

  if (runcount < MAXRUNS) {
    //~ spin_lock(&my_lock);
    tjlast = my_timer.expires;
    //mod_timer(&my_timer, tjlast + 1);
    mod_timer_pinned(&my_timer, tjlast + 1);
    tjnow = jiffies;
    printk(KERN_INFO
      " testjiffy expires: %lu - jiffies %lu => %lu / %lu last: %lu\n",
      my_timer.expires, tjnow, my_timer.expires-tjnow, jiffies, tjlast);
    //~ spin_unlock(&my_lock);

  }
}


static int __init testjiffy_init(void)
{
	printk(KERN_INFO
    "Init testjiffy: %d ; HZ: %d ; 1/HZ (ms): %d\n",
               runcount,      HZ,        1000/HZ);

  //~ spin_lock_init(&my_lock);
  init_timer(&my_timer);
	my_timer.function = testjiffy_timer_function;
	//my_timer.data = (unsigned long) runcount;
  my_timer.expires = jiffies + 1;
	add_timer(&my_timer);

	return 0;
}

static void __exit testjiffy_exit(void)
{
  // must stop timer here, if it is still running
  int ret_cancel = 0;

  // no explicit checking function here
  //~ ret_cancel = del_timer(&my_timer);
  // del_timer_sync "guarantees that the function is not currently running on other CPUs"
  ret_cancel = del_timer_sync(&my_timer);
  if (ret_cancel == 1) {
    printk(KERN_INFO "testjiffy cancelled timer (%d)\n", ret_cancel);
  } else {
    printk(KERN_INFO "testjiffy timer wasn't running (%d)\n", ret_cancel);
  }

	printk(KERN_INFO "Exit testjiffy\n");
}

module_init(testjiffy_init);
module_exit(testjiffy_exit);

MODULE_LICENSE("GPL");
