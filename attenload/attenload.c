/*

# Part of the attenload package
#
# Copyleft 2012-2013, sdaau
# This program is free software, released under the GNU General Public License.
# NO WARRANTY; for license information see the file LICENSE

*/

/*
# usual compile with libusb-1.0-dev
# (#include <libusb.h>):
gcc -o attenload -g attenload.c `pkg-config --libs --cflags libusb-1.0`

# compile with libusb built from git (for debug) in subfolder libusb-1.0:
# (#include "libusb-1.0/libusb/libusb.h")
gcc -g attenload.c libusb-1.0/libusb/.libs/libusb-1.0.a -I./libusb-1.0/libusb -lpthread -lrt -o attenload

NOTE: this application does not write to stdout, but writes to:
 fd2: stderr - for log information
 fd3: raw 'bulk in' data - all of it
 fd4: raw 'bulk in' data - only relevant packets for wavegraph data
 fd5: raw 'bulk in' data - only relevant packets for bitmap data
 fd6: raw 'bulk in' data - only relevant packets for device settings

# call complete dump - only stderr will be output to terminal
sudo ./attenload

# call complete dump - stderr to terminal + save all raw in data in "usbout.dat"
# NOTE: sudo will not cover redirection; must be called from subshell:
sudo bash -c "./attenload 3>usbout.dat"

# connect only (only stderr will be output to terminal)
sudo ./attenload -c

# get only wavegraph data, and save only data packets from fd4
sudo bash -c "./attenload -w 4>usbout.dat"

# disconnect only (only stderr will be output to terminal)
sudo ./attenload -d
*/


#include <errno.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <libusb.h>
//~ #include "libusb-1.0/libusb/libusb.h"

#define EP_INTR			(1 | LIBUSB_ENDPOINT_IN)
#define EP_DATA			(2 | LIBUSB_ENDPOINT_IN)
#define CTRL_IN			(LIBUSB_REQUEST_TYPE_VENDOR | LIBUSB_ENDPOINT_IN)
#define CTRL_OUT		(LIBUSB_REQUEST_TYPE_VENDOR | LIBUSB_ENDPOINT_OUT)
#define USB_RQ			0x04
#define INTR_LENGTH		64


static int state = 0;
static struct libusb_device_handle *devh = NULL;

static int actual; //used to find out how many bytes were written
static unsigned char fifobuf[512]; // here I have 0x200=512 sized packets; for endpoint in data
static int r = 1; // return code
static unsigned int timeout;
static unsigned int icnt; // for-loop counter
static unsigned int jcnt; // for-loop counter

// devset: writing (Upload) only 5 times 0x200 ; = 2560
// .SET is 2048; .ssf is 2500 bytes
//start header is 20 bytes: settings are 2500 bytes after that; only one header expected in data
// allocate 2560 bytes for raw device settings
#define DSETTINGSSIZE 2560
// init from an actual receive settings packet:
// WITH the receive signature (which adsparse-dvstngs cuts off!)
// (makes it pass fine)..
static unsigned char devsettings[DSETTINGSSIZE] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x48, 0x58, 0x01, 0x05, 0x00, 0x00,
0x00, 0x04, 0x00, 0x00,
  0x27, 0xdc, 0xff, 0xff, 0x56, 0x31, 0x2e, 0x35, 0x00, 0x00, 0x48, 0x42,
0x00, 0x00, 0x48, 0x42, 0x00, 0x00, 0x00, 0x41, 0x00, 0x00, 0xfa, 0x43, 0x00, 0x00, 0x48, 0x42,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x00, 0x00, 0x80, 0x3f,
0x00, 0x00, 0x00, 0x00, 0x4a, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x83, 0x00, 0x00, 0x00,
0x84, 0x00, 0x00, 0x00, 0x84, 0x00, 0x00, 0x00, 0x11, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00,
0xe1, 0x00, 0x00, 0x00, 0xe1, 0x00, 0x00, 0x00, 0xe1, 0x00, 0x00, 0x00, 0xc2, 0x01, 0x00, 0x00,
0x34, 0x00, 0x00, 0x00, 0xd4, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00, 0xb8, 0x01, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0xb9, 0x00, 0x00, 0x63, 0x01, 0x00, 0x00, 0x5c, 0x03, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x74, 0x30, 0x00, 0x00, 0x64, 0x01, 0x00, 0x00, 0x5b, 0x03, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x03, 0x00, 0x00, 0x00,
0xf4, 0x01, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x0f, 0x27, 0x00, 0x00, 0x0f, 0x27, 0x00, 0x00, 0x0f, 0x27, 0x00, 0x00,
0x37, 0x0e, 0x57, 0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc2, 0x01, 0x00, 0x00,
0xc2, 0x01, 0x00, 0x00, 0xc2, 0x01, 0x00, 0x00, 0x11, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x08, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0xc8, 0xcc, 0xcc, 0x3e, 0xcd, 0xcc, 0xcc, 0x3e, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x01, 0x00, 0x00, 0x02, 0x00, 0x01, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00,
0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00,
0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x02, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x02, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00,
0x00, 0x01, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0x07,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x03,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0xba, 0xdc, 0x00, 0x00, 0x09, 0x00, 0x00, 0x00, 0xe6, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x0a, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
0x00, 0x00, 0xa0, 0x41, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00,
0x09, 0x00, 0x00, 0x00, 0xe6, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3f,
0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xa0, 0x41, 0x01, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3c, 0x3c, 0x28, 0x00,
0x86, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static unsigned char dummydevsettings[DSETTINGSSIZE] = { 0x00 };

// unsigned int usecs; 2000000 = 2sec
unsigned int interMsgDelay = 1000000;

double trig_holdoff;
long trig_holdoff_i;

void exit_usb(void);
void init_usb(void);


char ccmd1[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x07, 0x00, 0x40, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

char ccmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

char ccmd3[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

char ccmd4[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

/// char wrcmd1[] = { // same as ccmd1
/// 0x43, 0x6f, 0x6d, 0x6d, 0x07, 0x00, 0x40, 0x00, 0x14, 0x00,

char wrcmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

/// char wrcmd3[] = { // same as ccmd3
/// 0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x10, 0x00,

char wrcmd4[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x4a, 0x68, 0x48, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char wrcmd25[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00,
0x05, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char wrcmd26[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00,
0x06, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

//

char dcmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x02, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

char dcmd4[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };

//

char bcmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x04, 0x00, 0x00,
0x26, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char bcmd4[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x58, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

//

char bpcmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x0b, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char bpcmd4[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x02, 0x1c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char bpcmd5[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x07, 0x00, 0x40, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// modify bpcmd6 manually in the loop afterwards:
/// char bpcmd61[] = {
///   00000000: 44 53 4f 50 50 56 32 30 00 00 00 08 00 0c 00 00
///   00000010: 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 ...
char bpcmd6[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x08, 0x00, 0x0c, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char bpcmd8[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x08, 0x80, 0x00, 0x10, 0xc0, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

char bpcmdxx[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x0d, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

//

char gscmd2[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00,
0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};


char wdcmd1[] = {
0x43, 0x6f, 0x6d, 0x6d, 0x07, 0x00, 0x00, 0x0a, 0xd4, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

// just header
char wdcmdh[] = {
0x44, 0x53, 0x4f, 0x50, 0x50, 0x56, 0x32, 0x30, 0x00, 0x00, 0x09, 0xc4, 0x00, 0x0a, 0x00, 0x00
};



void ads_msg_connect(void)
{
  // connect message

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra   // (c1)

  r = libusb_bulk_transfer(devh, 0x05, ccmd2, sizeof(ccmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // originally 600ms delay here

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000);

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, ccmd4, sizeof(ccmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  //~ usleep(1000);  // no need, seems already delayed enough at this point

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  fprintf(stderr, "cmd complete\n");
} // connect message

void ads_msg_wave_data_refresh(void)
{
  // Wave Graph (Wave Data) refresh  message

  /// ccmd1 ; wrcmd2 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ;
  /// ccmd1 ; wrcmd25 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ;
  /// ccmd1 ; wrcmd26 ; ccmd3 / r200 ; wrcmd4 / 37xr200 ;

  // the original .csv goes like this (linenum data):
  ///    1 2250 ;       2 320 ;       3 1 ;       4 2 ;              ## header
  ///    5 135 (d) ;       6 134 (d) ;       7 135 (d) ;       8 134 (d) ;
  /// 2251 135 (d) ;    2252 135 (d) ;    2253 135 (d) ;    2254 135 (d) ;
  /// 2255 500.00000 ;    2256 0.00us ;    2257 2.000000m ;    2258 84 ;
  /// 2259 Auto ;    2260 **** ;    2261 **** ;    2262 **** ;
  /// 2288 **** ;    2289 **** ;    2290 **** ;    2291 **** ;
  /// 2292 2250 ;    2293 320 ;    2294 1 ;    2295 2 ;             ## header
  /// 2296 128 (d) ;    2297 128 (d) ;    2298 128 (d) ;    2299 128 (d) ;
  /// 4542 128 (d) ;    4543 128 (d) ;    4544 128 (d) ;    4545 128 (d) ;
  /// 4546 500.00000 ;    4547 0.00us ;    4548 2.000000V ;    4549 84 ;
  /// 4550 Auto ;    4551 **** ;    4552 **** ;    4553 **** ;
  /// 4579 **** ;    4580 **** ;    4581 **** ;    4582 **** ;

  // total (only) datarows: 2254-5+1 = 2250; 4545-2296+1 = 2250 .. ok
  // $.>=5 && $.<=2254
  // auto section rows: 2291-2259+1 = 33 ; 4582-4550+1 = 33
  // '2*(4+2250+4+33)' = 4582 = 0x11e6 ok; 4582/2 = 2291 = 0x08f3


  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, wrcmd2, sizeof(wrcmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // 600000us=600ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here = 18944, which is 0x4a00 (in wrcmd4?)
  /// while (actual>0) { // run until exhaust? no, transfer ends up failing; for loop
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    write(3, fifobuf, actual);
    write(4, fifobuf, actual);
    usleep(250);
  }

  usleep(47000); // 500000us=50ms ************


  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, wrcmd25, sizeof(wrcmd25), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(300000); // 300000us=300ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    write(3, fifobuf, actual);
    write(4, fifobuf, actual);
    usleep(250);
  }

  usleep(10000); // 100000us=10ms ************ //(is 10 here)


  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, wrcmd26, sizeof(wrcmd26), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(300000); // 300000us=300ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(10000); // bit more here in orig, 10ms (well, a bit less)

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(10000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    write(3, fifobuf, actual);
    write(4, fifobuf, actual);
    usleep(250);
  }

  fprintf(stderr, "cmd complete\n");
} // Wave Graph (Wave Data) refresh  message

void ads_msg_bitmap_refresh(void)
{
  // DSO bitmap refresh message

  /// ccmd1 ; bpcmd2 ; ccmd3 / r200; bpcmd4 / r200;
  /// bpcmd5; bpcmd6 ; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd61; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd62; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd63; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd64; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd65; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd66; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd67; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd68; ccmd3 / r200; bpcmd8 / 8xr200;
  /// bpcmd5; bpcmd69; ccmd3 / r200; bpcmd8 / 8xr200;
  /// ... up to i=0x53 bpcmd6i; ..
  /// then i=0x54 could repeat up to 6 times; .. then:;
  /// bpcmd5; bpcmdxx; ccmd3 / r200; ccmd3 / r200;

  // 0x55 = 85 ; 0x200 = 512; 85*8*512 = 348160 = 0x55000 ;
  // bmp: 480*234 = 112320 pixels; 480*234*3 = 336960

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 1

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, bpcmd2, sizeof(bpcmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 2


  usleep(100000); // 100000us=100ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 3

  usleep(13000); // bit more here in orig, 15ms, almost 20ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual); // 4
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, bpcmd4, sizeof(bpcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 5

  usleep(6000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual); // 6
  write(3, fifobuf, actual);

  usleep(3000);


  for (jcnt=0x00; jcnt<=0x54; jcnt++) {
    r = libusb_bulk_transfer(devh, 0x03, bpcmd5, sizeof(bpcmd5), &actual, timeout);
    fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 7

    usleep(500);

    bpcmd6[0x17] = jcnt;
    r = libusb_bulk_transfer(devh, 0x05, bpcmd6, sizeof(bpcmd6), &actual, timeout);
    fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 8

    usleep(50000); // 50000us=50ms

    r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
    fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 9

    usleep(2000); // 5ms

    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual); // 10
    write(3, fifobuf, actual);

    r = libusb_bulk_transfer(devh, 0x03, bpcmd8, sizeof(bpcmd8), &actual, timeout);
    fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); // 11

    usleep(4000); // 10ms

    // grab 8 times 0x200 (512) packets here = 4096 = 0x1000
    for (icnt=1; icnt<=8; icnt++) { // we expect actual>0 here - good to start loop;
      r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
      fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
      write(3, fifobuf, actual);
      write(5, fifobuf, actual);
      usleep(400);
    } // end for icnt

    usleep(18000); // 20ms
  } // end for jcnt

  r = libusb_bulk_transfer(devh, 0x03, bpcmd5, sizeof(bpcmd5), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //

  usleep(1000);

  r = libusb_bulk_transfer(devh, 0x05, bpcmdxx, sizeof(bpcmdxx), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //

  usleep(100000); // 100000us=100ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //

  usleep(10000); // 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual); //
  write(3, fifobuf, actual);

  usleep(100000); // 100000us=100ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //

  usleep(10000); // 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual); //
  write(3, fifobuf, actual);

  fprintf(stderr, "cmd complete\n");
} // DSO bitmap refresh message


void ads_msg_get_device_settings(void)
{
  // get device settings message ("Device Settings Oper - Upload")

  /// ccmd1 ; gscmd2 ; ccmd3 / r200 ; wrcmd4 / 37xr200
  //~ int i;

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, gscmd2, sizeof(gscmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // 600000us=600ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here = 18944, which is 0x4a00 (in wrcmd4?)
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    //~ for (i=0; i<20; i++) { // DSETTINGSSIZE
      //~ printf("%02X, ", fifobuf[i]);
    //~ }; printf("\n");

    write(3, fifobuf, actual);
    write(6, fifobuf, actual);
    usleep(250);
  }

  fprintf(stderr, "cmd complete\n");
} // get device settings message


void print_dev_settings_arr(void)
{
  int i;
  for (i=0; i<40; i++) { //DSETTINGSSIZE
    printf("%02X, ", devsettings[i]);
  }; printf("\n");
  printf("--\n");
}

void print_dummydev_settings_arr(void)
{
  int i;
  for (i=0; i<40; i++) { //DSETTINGSSIZE
    printf("%02X, ", dummydevsettings[i]);
  }; printf("\n");
  printf("--\n");
}



void ads_msg_get_device_settings_to_array(void)
{
  // get device settings message ("Device Settings Oper - Upload")
  // to devsettings[] array

  /// ccmd1 ; gscmd2 ; ccmd3 / r200 ; wrcmd4 / 37xr200
  int dind = 0;

  //zero out at first
  memset(devsettings, 0, DSETTINGSSIZE);

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, gscmd2, sizeof(gscmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // 600000us=600ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here = 18944, which is 0x4a00 (in wrcmd4?)
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    write(3, fifobuf, actual);
    write(6, fifobuf, actual);
    if (dind < DSETTINGSSIZE) {
      memcpy(devsettings+dind,fifobuf+dind,actual);
      dind += actual;
    }
    usleep(250);
  }


  //~ print_dev_settings_arr();
  fprintf(stderr, "cmd complete\n");
} // get device settings _to_array

void ads_msg_get_device_settings_to_dummyarray(void)
{
  // get device settings message ("Device Settings Oper - Upload")
  // to devsettings[] array

  /// ccmd1 ; gscmd2 ; ccmd3 / r200 ; wrcmd4 / 37xr200
  int dind = 0;

  //zero out at first
  memset(dummydevsettings, 0, DSETTINGSSIZE);

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, gscmd2, sizeof(gscmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // 600000us=600ms

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(7000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here = 18944, which is 0x4a00 (in wrcmd4?)
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    //~ write(3, fifobuf, actual);
    //~ write(6, fifobuf, actual);
    if (dind < DSETTINGSSIZE) {
      memcpy(dummydevsettings+dind,fifobuf+dind,actual);
      dind += actual;
    }
    usleep(250);
  }


  //~ print_dummydev_settings_arr();
  fprintf(stderr, "cmd complete\n");
} // get device settings _to_array

/*
read and write device settings compare
# in dvstngs- for r: it is after 20 bytes (0x14 0-based)
# then for w it is after 16 bytes
# (the first two bytes are like timestamp - always change?)
# because of differing headers, we must copy to extract
# or rather use memmove for overlaps..

r86 200
    00000000: 44 53 4f 50 50 56 32 30 00 00 48 58 01 05 00 00
    00000010: 00 04 00 00 *66 dc ff ff 56 31 2e 35 00 00 00 40
    00000020: 00 00 fa 44 00 00 40 41 00 00 80 3e 00 00 48 42
w5 200
    00000000: 44 53 4f 50 50 56 32 30 00 00 09 c4 00 0a 00 00
    00000010: *65 dc ff ff 56 31 2e 35 00 00 00 40 00 00 fa 44
    00000020: 00 00 40 41 00 00 80 3e 00 00 48 42 00 00 00 00
r86 200(b)
    00000000: 44 53 4f 50 50 56 32 30 00 00 48 58 01 05 00 00
    00000010: 00 04 00 00 *a0 d7 ff ff 56 31 2e 35 00 00 00 40
    00000020: 00 00 00 40 00 00 00 00 00 00 fa 43 00 00 48 42
w5 200(b)
    00000000: 44 53 4f 50 50 56 32 30 00 00 09 c4 00 0a 00 00
    00000010: *c8 d7 ff ff 56 31 2e 35 00 00 00 40 00 00 00 40
    00000020: 00 00 00 00 00 00 fa 43 00 00 48 42 00 00 00 00

upload dev settings:
write wdcmd1; write with header wdcmdh 5 times 0x200 , write ccmd3; receive 0x200; write dcmd4; receive 0x200;
*/


void ads_msg_set_device_settings_from_array(void)
{
  // set device settings message ("Device Settings Oper - Download")
  // from devsettings[] array

  //~ for (i=0; i<40; i++) { //DSETTINGSSIZE
    //~ printf("%02X, ", devsettings[i]);
  //~ }; printf("\n");
  //~ printf("--\n");

  // assume devsettings array is already populated by get _to_array
  // overwrite first portion of devsettings array with write header
  memcpy(devsettings, wdcmdh, sizeof(wdcmdh));

  //~ devsettings[0x14] = 0x27;
  //~ devsettings[0x14+1] = 0xdc;
  // now move data already present 4 bytes left
  // (must use memmove, since ranges overlap):
  memmove(devsettings+0x10,devsettings+0x14,(DSETTINGSSIZE-0x14)*sizeof(char));
  // zero out last bytes just in case
  memset(devsettings+DSETTINGSSIZE-1-0x14, 0, 0x14);

  //~ print_dev_settings_arr();

  // ready to send
  r = libusb_bulk_transfer(devh, 0x03, wdcmd1, sizeof(wdcmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(2000);

  // just this seems to cause "Location Empty" on scope;
  // actually that happens if the init devsettings is null
  // with actual init devsettings data, it works:
  // just beeps and loads new settings!
  // then complete transfer is ok for 2000 usleep for these two...

  for (icnt=0; icnt<5; icnt++) { // we expect actual>0 here - good to start loop;
    int offs=icnt*0x200;
    r = libusb_bulk_transfer(devh, 0x05, &devsettings[offs], 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

    usleep(2000);
  }

  usleep(600000); // was 60000; down to 5000 causes r:-7 (and Loc Empty); 4000 Ok; but then even 3000 chokes sometimes?


  // also (EasyScope does this too) - download to device turns the screen green!
  // also if screensaver is on, screen is not refreshed in the background, and some beeps missing!

  //apparently, these are unneeded? returned r:-7, error anyways (but not allways)

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // was 10000

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  /// write(3, fifobuf, actual);

  usleep(70000); //was 3000

  r = libusb_bulk_transfer(devh, 0x03, dcmd4, sizeof(dcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(3000); //was 3000

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  /// write(3, fifobuf, actual);


} // set device settings _from_array


void ads_get_set_device_settings(void)
{
  // just testing:
  // get device settings to array
  // set device settings from array


  // this saves to original devsettings array
  ads_msg_get_device_settings_to_array();
  exit_usb();

  // apparently, from get to set the first two bytes (checksum? timestamp? signature)
  //  MUST change - else the set is denied with "Location Empty" and error beep
  // the very same set a bit later (from file), with just ts changed from get, works?
  // so = seems that retrieving get to dummy, and waiting until the signature changes,
  // allows same settings to be pasted?
  // nope, that trick doesn't work;
  // dummy settings loops with differences 1, until you change something on scope
  // then it is indeed changed - but it still won't accept setting;
  // only after attenload program exit (and re-call) can be set succesfully
  // so set/reset for now not possible from C - but maybe possible from perl (by calling attenload twice)

  // init for `while` loop:
  dummydevsettings[0x14+0] = devsettings[0x14+0];
  dummydevsettings[0x14+1] = devsettings[0x14+1];
  while ( (abs(dummydevsettings[0x14+0] - devsettings[0x14+0]) < 2) && (abs(dummydevsettings[0x14+1] - devsettings[0x14+1]) < 2) ) {
    //~ usleep(interMsgDelay);
    sleep(1);
    init_usb();
    // this saves to dummydevsettings array
    ads_msg_get_device_settings_to_dummyarray();
    exit_usb();
  }
  //~ write(7,dummydevsettings, DSETTINGSSIZE); // for debug


  sleep(2);
  //~ usleep(interMsgDelay);
  // out here should be safe to re-set back the same (original) devsettings
  init_usb();
  ads_msg_set_device_settings_from_array();
}

void ads_set_trigger_holdoff_time(void)
{
  // get device settings to array
  // change holdoff time
  // set device settings from array

  // in perl:
  /// @atmp[0..3] = @ssfExtractDat[0xcc..0xcf];
  /// $ssf_trig_holdoff_i = unpack("l", pack("C4", @atmp));
  /// $ssf_trig_holdoff = $ssf_trig_holdoff_i*10e-9;
  float cc=5e1;
  char bx202;
  int step;

  //~ print_dev_settings_arr();

  ads_msg_get_device_settings_to_array();

  sleep(1);
  ads_msg_get_device_settings_to_dummyarray();

  sleep(1);
  ads_msg_get_device_settings_to_dummyarray();

  trig_holdoff = 100e-9;
  trig_holdoff_i = (long)(trig_holdoff/10e-9+0.5);
  // definitely float - not double
  printf("%e %ld .. %e %d\n",trig_holdoff,trig_holdoff_i, *(float*)(0x14+0x08+&devsettings[0]), sizeof(float)); // *(float*)(&devsettings[0x14+0x08]));
  printf("0x%8.8lX\n", *((long*)&cc));

  // at this point, devsettings data is still offset by 20 (0x14)

  //~ memcpy(&devsettings[0x14+0xcc], &trig_holdoff, sizeof(long)/sizeof(char));
  //~ memcpy(devsettings+0x14+0xcc, &trig_holdoff_i, sizeof(long)/sizeof(char));
  //~ memset(devsettings+0x14+0xcc, 2, 4); // nope..

  // just this line can mess up things!
  //~ memcpy(devsettings+0x14+0x08, &cc, sizeof(float));
  // no *(char*)(&cc+0); // not ((char*)&cc)[3];
  // it is *(((char*)&xx)+3) or  *((char*)&xx+3)
  // if cc=5e1 0x42480000 as in original packet - then no problem,
  // 0,1,2,3 - or 3,2,1,0!
  // must be a checksum of a sort - because if
  // add X to one loc, and subtract X from other, then it passes!
  // must be first two bytes too! 0x42/0x48 default, 0x49/0x41 are ok too, 0x4a/0x40 also ok
  // so it's some simple checksum, and does not detect order?
  // although, the VDIV number is not set to anything bizarre, but to orig value,
  // so some error correction, too?
  // but for the same setting (holdoff), some time later, these bytes are changed:
  // [0x00, 0x01, 0x70, 0x74, 0x78, 0x84, 0x88]?
  // then for min max check, two other ssfs - only first two bytes:
  // F6 DA (min) => B7 D8 (max) and C7 DA (min) => 87 D8 (max)
  // 100n: 0A 00 00 00; 1.5: 80 D1 F0 08 0x80+0xD1+0xF0+0x08 = 0x249%0xFF = 0x4b
  // -h 0xDA-0xD8 = 0x02; -h 0xB7-0xF6 = -0x3f; -h 0x87-0xC7 = -0x40
  //~ devsettings[0x14+0x08] = 0x00; //0x42; //*(((char*)&cc)+0);
  //~ devsettings[0x14+0x08+1] = 0x00; //*(((char*)&cc)+1);
  //~ devsettings[0x14+0x08+2] = 0x49; //*(((char*)&cc)+2);
  //~ devsettings[0x14+0x08+3] =  0x41;//0x48; //*(((char*)&cc)+3);

  // note, when getting the same .ssf from scope 1 second apart;
  // usually (but not always) there is a change at byte [0] (checksum?) and byte [0x202] (and often also byte [0xe4])
  // when [0x202]: 01 00 -> [0x00]: f7 f8; but 00 02 -> f7 f5
  // when [0x202]: 01 00 -> [0x00]: d2 d3;
  //~ bx202 = devsettings[0x14+0x202];
  //~ if (bx202 == 0) {step = 1;} else {step = -1;};
  //~ devsettings[0x14+0x202] = devsettings[0x14+0x202] + step;
  //~ devsettings[0x14+0x00] = devsettings[0x14+0x00] - step;
  //~ for (i=0; i<40; i++) { //DSETTINGSSIZE
    //~ printf("%02X, ", devsettings[i]);
  //~ }; printf("\n");
  //~ printf("--\n");


  //~ exit_usb();

  //~ usleep(interMsgDelay);
  sleep(1); //secs

  //~ init_usb();
  ads_msg_set_device_settings_from_array();
}


void ads_msg_mb1_click(void)
{
  // virtual click of Option Button MB_1 message
  // (front panel menu operational buttons to the right of the display screen, top button)

  ///   ccmd1,   bcmd2,   ccmd3,   bcmd4,  +   ccmd1,   wrcmd2,   ccmd3,   wrcmd4 + 37 r

  // NOTE: virtual click works - but only if screensaver is not turned on!
  // (it cannot wake the scope from sleep/screensaver!)

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //1

  usleep(1000);

  r = libusb_bulk_transfer(devh, 0x05, bcmd2, sizeof(bcmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //2

  usleep(100000); // originally 100ms delay here

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //3

  usleep(2000); // (should be more, but seems here it is enough 1000?)

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);                                          //4

  r = libusb_bulk_transfer(devh, 0x03, bcmd4, sizeof(bcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //5

  //~ usleep(1000);  // no need, seems already delayed enough at this point

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);                                          //6


  usleep(200000); // originally 200ms delay here

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //7

  usleep(1000);

  r = libusb_bulk_transfer(devh, 0x05, wrcmd2, sizeof(wrcmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //8


  usleep(200000); // originally 200ms delay here

  r = libusb_bulk_transfer(devh, 0x05, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //9

  //~ usleep(1000); // bit more here in orig, 10ms .. but no need for it

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);                                          //10

  r = libusb_bulk_transfer(devh, 0x03, wrcmd4, sizeof(wrcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual); //11

  usleep(10000); // bit more here in orig, 10ms

  // grab 37 times 0x200 (512) packets here
  for (icnt=1; icnt<=37; icnt++) { // we expect actual>0 here - good to start loop;
    r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
    fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
    write(3, fifobuf, actual);
    usleep(250);
  }

  fprintf(stderr, "cmd complete\n");
} //virtual click of Option Button MB_1 message


void ads_msg_disconnect(void)
{
  // disconnect message

  r = libusb_bulk_transfer(devh, 0x03, ccmd1, sizeof(ccmd1), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000); // added some xtra

  r = libusb_bulk_transfer(devh, 0x05, dcmd2, sizeof(dcmd2), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(600000); // originally 600ms delay here

  r = libusb_bulk_transfer(devh, 0x03, ccmd3, sizeof(ccmd3), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  usleep(1000);

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  r = libusb_bulk_transfer(devh, 0x03, dcmd4, sizeof(dcmd4), &actual, timeout);
  fprintf(stderr, "bulk transfer (out): r:%d, act:%d\n", r, actual);

  //~ usleep(1000);  // no need, seems already delayed enough at this point

  r = libusb_bulk_transfer(devh, 0x86, fifobuf, 0x200, &actual, timeout);
  fprintf(stderr, "bulk transfer (in ): r:%d, act:%d\n", r, actual);
  write(3, fifobuf, actual);

  fprintf(stderr, "cmd complete\n");
} // disconnect message












struct sigaction sigact;
char buf[256]; // for string data from config

libusb_device *dev;
struct libusb_device_descriptor desc;
struct libusb_config_descriptor *configDesc ;

const struct libusb_interface *inter;
const struct libusb_interface_descriptor *interdesc;
const struct libusb_endpoint_descriptor *epdesc;


void exit_usb(void)
{
out_release:
	libusb_release_interface(devh, 0);
  fprintf(stderr, "released interface\n");
//~ out: // just label will give "undefined reference" if used with extern void below - must be asm!
asm volatile("out:");
  fprintf(stderr, "closing device\n");
	libusb_close(devh);
	libusb_exit(NULL);

}


void init_usb(void)
{
  extern void out(); // for label; see http://stackoverflow.com/a/2278647/277826

	r = libusb_init(NULL);
	if (r < 0) {
		fprintf(stderr, "failed to initialise libusb\n");
		exit(1);
	}

  //~ libusb_set_debug(NULL, 0); // ignored; --enable-debug-log in libusb-1.0 overrides

  devh = libusb_open_device_with_vid_pid(NULL, 0xf4ec, 0xee38);
  r = devh ? 0 : -EIO;
	if (r < 0) {
		fprintf(stderr, "Could not find/open device\n");
		goto *(long)&out;// out;
	}
  fprintf(stderr, "Found ADS scope device; perf. reset..\n");

  // with detach_driver here; (was last before start) - no more "did not claim interface 0 before use"
  if(libusb_kernel_driver_active(devh, 0) == 1) { //find out if kernel driver is attached
    fprintf(stderr, "Kernel Driver Active\n");

    if(libusb_detach_kernel_driver(devh, 0) == 0) //detach it
      fprintf(stderr, "Kernel Driver Detached!\n");
  } else fprintf(stderr, "Kernel Driver Not Active\n");

  //~ libusb_reset_device(devh); // no need twice
  r = libusb_reset_device(devh);
	if (r < 0) {
		fprintf(stderr, "failed to reset device\n");
		exit(1);
	}

  dev = libusb_get_device(devh);
  if (dev) {
		fprintf(stderr, "Got device from handle\n");
  }

  // set_configuration MUST be before claim_interface!
	r = libusb_set_configuration(devh, 1);
	if (r < 0) {
		fprintf(stderr, "libusb_set_configuration error %d\n", r);
		goto *(long)&out;
	}

	r = libusb_claim_interface(devh, 0);
	if (r < 0) {
		fprintf(stderr, "usb_claim_interface error %d\n", r);
		goto *(long)&out;
	}
	fprintf(stderr, "claimed interface\n");

  r = libusb_set_interface_alt_setting (devh, 0, 0); // int interface_number, int alternate_setting
	if (r < 0) {
		fprintf(stderr, "libusb_set_configuration error %d\n", r);
		goto *(long)&out;
	}
	fprintf(stderr, "alt_setting set\n");


  r = libusb_get_device_descriptor(dev, &desc);
  if (r < 0) {
    fprintf(stderr, "failed to get device descriptor");
    return;
  }

  fprintf(stderr, "Dev.Desc: %04x:%04x (bus %d, device %d)\n",
  desc.idVendor, desc.idProduct,
  libusb_get_bus_number(dev), libusb_get_device_address(dev));


  r = libusb_get_string_descriptor_ascii(devh, desc.iManufacturer, buf, sizeof(buf));
  if (r < 0) {
    fprintf(stderr, "Coudn't get iManufacturer\n");
  }
  fprintf(stderr, "iManufacturer is: %s\n", buf);

  timeout = 100; // was 10;

}


void devset_from_file(int argc, char *argv[])
{
  unsigned char x;
  int dind =0;
  extern void out(); // for label;

  if (argc < 3) {
    fprintf(stderr, "!!! need devsettings filename\n");
    goto *(long)&out;
    exit(-1); // no return -1 anymore
  }
  // We assume argv[1] is a filename to open
  FILE *file = fopen( argv[2], "r" );
  // fopen returns 0, the NULL pointer, on failure
  if ( file == 0 ) {
    printf( "!!! Could not open file\n" );
    goto *(long)&out;
    exit(-1);
  }

  // just for printout;
  //~ ads_msg_get_device_settings_to_array();

  // don't use fgetc - exits at "negative" bytes! use fread!
  // ssf files don't have the 0x14 receive header - handle!
  //~ while  ( ( x = fgetc( file ) ) != EOF ) {
  while  ( fread(&x, sizeof(unsigned char), 1, file ) == 1 ) { // expected 1 at a time
    if (dind < DSETTINGSSIZE-0x14) {
      //~ printf( "-%02X- ", x );
      devsettings[dind+0x14] = x;
    }
    dind++;
  }
  //~ printf("\n");
  fclose( file );

  ads_msg_set_device_settings_from_array();
}




int main(int argc, char *argv[])
{
  //write(7,devsettings, DSETTINGSSIZE); // for debug

  init_usb();


  // START ************

  if (argc > 1) {
    if (strcmp(argv[1], "-c") == 0) {
      fprintf(stderr, "* CONNECT\n");
      ads_msg_connect();
    }
    if (strcmp(argv[1], "-w") == 0) {
      fprintf(stderr, "* WAVEGRAPH/DATA REFRESH\n");
      ads_msg_wave_data_refresh();
    }
    if (strcmp(argv[1], "-d") == 0) {
      fprintf(stderr, "* DISCONNECT\n");
      ads_msg_disconnect();
    }
    if (strcmp(argv[1], "-k") == 0) {
      fprintf(stderr, "* MB_1 CLICK\n");
      ads_msg_mb1_click();
    }
    if (strcmp(argv[1], "-b") == 0) {
      fprintf(stderr, "* BITMAP REFRESH\n");
      ads_msg_bitmap_refresh();
    }
    if (strcmp(argv[1], "-s") == 0) {
      fprintf(stderr, "* GET DEVICE SETTINGS\n");
      ads_msg_get_device_settings();
    }
    if (strcmp(argv[1], "-ts") == 0) {
      fprintf(stderr, "* test set DEVICE SETTINGS\n");
      ads_msg_set_device_settings_from_array();
    }
    if (strcmp(argv[1], "-gs") == 0) {
      fprintf(stderr, "* get/set DEVICE SETTINGS\n");
      ads_get_set_device_settings();
    }
    if (strcmp(argv[1], "-th") == 0) {
      fprintf(stderr, "* set trigger holdoff (via devsettings)\n");
      ads_set_trigger_holdoff_time();
    }
    if (strcmp(argv[1], "-ss") == 0) {
      fprintf(stderr, "* set devsettings from file\n");
      devset_from_file(argc, argv);
    }
  } else {

    fprintf(stderr, "* CONNECT\n");
    ads_msg_connect();

    usleep(interMsgDelay);


    fprintf(stderr, "* WAVEFORM/DATA REFRESH\n");
    ads_msg_wave_data_refresh();

    usleep(interMsgDelay);


    fprintf(stderr, "* BITMAP REFRESH\n");
    ads_msg_bitmap_refresh();

    usleep(interMsgDelay);


    fprintf(stderr, "* GET DEVICE SETTINGS\n");
    ads_msg_get_device_settings();

    usleep(interMsgDelay);


    fprintf(stderr, "* DISCONNECT\n");
    ads_msg_disconnect();
  }

  exit_usb();

	return r >= 0 ? r : -r;
}




