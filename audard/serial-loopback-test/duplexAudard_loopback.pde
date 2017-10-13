/*

original filename was duplexTstamp_b2b_inloop.pde:
duplexTstamp - b2b - 8 bit - one channel - profiler
// sdaau 2010
(no timestamps profiling in here, though)

b2b - byte by byte
read incoming byte;
then send it back

// DISCLAIMER:
// The author is in no way responsible for any problems or damage caused by
// using this code. Use at your own risk.
//
// LICENSE:
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
*/

static const long SERSPEED=2000000;

//static uint8_t serAvail;
static volatile unsigned char _c;

#include <pins_arduino.h>
int ledPin = 6;
uint8_t bitl;
uint8_t portl;
volatile uint8_t *outl;

//http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1231326297/0
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))

//http://arduino.ghearing.com/
void serialBeginU2X(long baud) {
	// enable U2X mode
	UCSR0A |= 1 << U2X0;

	// set the baud rate
	int ubbr = ( F_CPU / 4 / baud - 1 ) / 2;
	UBRR0H = ubbr >> 8;
	UBRR0L = ubbr;

	// enable the serial pins
	sbi(UCSR0B, RXEN0);
	sbi(UCSR0B, TXEN0);

	// enable the serial interrupt
	sbi(UCSR0B, RXCIE0);
}


// not using interrupt ISRs here:
//#if defined(__AVR_ATmega8__)
////SIGNAL(SIG_UART_RECV)
//ISR(SIG_UART_RECV)
//#else
////SIGNAL(USART_RX_vect)
//ISR(USART_RX_vect)
//#endif
//{
//}


void setup()
{
  cli(); // Disable interrupts while setting registers

  TIMSK0 = 0; // disable timer 0 interrupt - Reset Timer/Counter0 Interrupt Mask Register
  TIMSK1 = 0;
  TIMSK2 = 0;

  //UCSR0B &= ~UDRIE0; //disable USART Data Register Empty Interrupt
  EECR &= ~(1 << EERIE); //disable EEPROM Ready Interrupt Enable

  WDTCSR &= ~(1 << WDIE); // disable Watchdog Interrupt Enable

  PCICR &= ~(1 << PCIE2); // disable Pin Change Interrupt Enable 2
  PCICR &= ~(1 << PCIE1); // disable Pin Change Interrupt Enable 1
  PCICR &= ~(1 << PCIE0); // disable Pin Change Interrupt Enable 0

  SPCR &= ~(1 << SPIE); //disable SPI Interrupt
  TWCR &= ~(1 << TWIE); // disable TWI Interrupt Enable
  ACSR &= ~(1 << ACIE); // disable Analog Comparator Interrupt Enable
  ADCSRA &= ~(1 << ADIE); // disable ADC Interrupt Enable
  SPMCSR &= ~(1 << SPMIE); // disable SPM Interrupt Enable

  //Serial.begin(SERSPEED);  // cannot use .begin here
  serialBeginU2X(SERSPEED);
  //serialBeginU2X(115200);
  pinMode(ledPin, OUTPUT);
  bitl = digitalPinToBitMask(ledPin);
  portl = digitalPinToPort(ledPin);
  outl = portOutputRegister(portl);

  //sei(); // Enable interrupts once registers have been updated

}


// going directly with UDR0, since I know I'm not using ATmega8
//#if defined(__AVR_ATmega8__)
//  unsigned char c = UDR;
//#else
//  unsigned char c = UDR0;
//#endif
// http://jimsmindtank.com/how-to-atmega-usart-in-uart-mode-with-circular-buffers/
// size was also 256
#define rx_buffer_size 512
#define rx_buffer_mask (rx_buffer_size - 1)
volatile unsigned char rx_buffer[rx_buffer_size];
volatile unsigned char rx_buffer_point = 0;

void loop()
{
  // read bit 7 (RXC0) from UCSR0A - USART Receive Complete
  // indicates if there are unread data present in the receive buffer
  while ((UCSR0A) & (1 << RXC0)) {
    // increase counter - with wrapping (as with modulo, but with mask)
    rx_buffer_point = (rx_buffer_point + 1) & rx_buffer_mask;

    // read byte
    //_c = UDR0;
    rx_buffer[rx_buffer_point] = UDR0;

    // send byte
//    while (!((UCSR0A) & (1 << UDRE0)))
//      ;
//    UDR0 = _c;
  }

  // now send bytes in buffer:
  while(rx_buffer_point) {
    while (!((UCSR0A) & (1 << UDRE0)))
      ;
    UDR0 = rx_buffer[rx_buffer_point];
    rx_buffer_point--;
  }

  // again - for indication
  // read bit 7 (RXC0) from UCSR0A - USART Receive Complete
//  if ((UCSR0A) & (1 << RXC0)) *outl |= bitl; //HIGH
//  else *outl &= ~bitl; // LOW
}


