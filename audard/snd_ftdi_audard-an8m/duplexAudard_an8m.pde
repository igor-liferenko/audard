/*
duplexAudard_an8m.pde 
mono 8-bit 
companion to snd_ftdi_audard.ko (snd_ftdi_audard-an8m)
// sdaau 2010

mono stream - sample considered 8 bit here 
Interrupt (ISR) version [default]

@ whenever:
  receive byte (sample) from USB into RX buffer ; 
@ 44100 (1/44100 = 22.6757 μs):
  * sample (byte) from RX buffer to PWM
  * sample (byte) from Ain to serial TX -> USB
  
NOTE: if symlinking to ~/sketchbook; 
  do NOT save from Arduino IDE! (symlink will be overwritten)


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

#include <avr/interrupt.h>
#include <avr/io.h>


struct fifo_buf {
  unsigned char data[256];
  unsigned char pos; // since it can have from 0:255, would also wrap at buffer boundary
                     // pos now becomes 'head', as in 'circular buffer'
  unsigned char tail;
};
fifo_buf rx_buffer =  { { 0 }, 0 };

static const long SERSPEED=2000000;

// F_CPU is predefined system clock frequency of Arduino
// from cores/Makefile: -DF_CPU=$(AVR_FREQ) 
// duemillanove/diecimila: AVR_FREQ = 16000000L 

// the "analog" sampling rate of the "card"
static const int ARate=44100;
// period corresponding to ARate (PCM rate) for F_CPU (=16MHz),
//   also, the number we'll use to compare with 16-bit counter
// periodARate should be 362; 
//   362/16e6 = 22.625 μs; 1/22.625e-6 = 44198.9 Hz
// note: sometimes it seems, periodARate gives 35.62 KC;  
//   so have to subtract -100 from periodARate, in order  
//   to measure 46.36KC ; -50 for 40.29KC (imprecise)
// trying to calculate ticks for entire loop (90) and first part (42)
//  based on that, can find treshold values for close to 44KHz..
// -62 is the best value (meas 42.2KC) but sometimes drops
// with a diff. strategy (wait with `while` at end) we should not have to change periodARate? 
//  but in fact we do - also, the `while` check loop changes in increments of 7/8 clock ticks; so it makes sense to check only in increments of -8
static const unsigned int periodARate=F_CPU/44100;
static const unsigned int periodPwmRate=F_CPU/62500;
// the period number we actually compare with (so periodARate stays == 362):
static const unsigned int periodARateCmp = periodARate-44;
// the 'current' 16-bit timer count value - "timestamp"
static unsigned int timerCountTS;
static unsigned int timerCountTS_now;

//static uint8_t serAvail;
static unsigned char _c; 

#include <pins_arduino.h>
int AInpPin = 0;	// analog   input pin
int AOutPin = 6;	// analog output pin (PWM = Ard.dig.out 6 = OC0A/p12)
int ledPin = 13;  
int end_PwmPin = 5;  // OC0B (dout 5): end of PWM period
int end1PwmPin = 3;  // OC2B (dout 3): one step before end of PWM period
int end2PwmPin = 11;  // OC2A (dout 11): two steps before end of PWM period

uint8_t bitl;
uint8_t portl;
volatile uint8_t *outl;

// these - to avoid bit negation calculations, which cost 14 cycles (assignment costs 4) 
//~ static unsigned char LED13ON;
//~ static unsigned char LED13OFF;
// WELL - bitl already performs this function, 
//  but it is a bitmask - and we must or/and with it, so we don't disturb the other pins in the port! - and that is what eats most of the cycles..
// so we cannot do direct assignment.... 

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
  //serialBeginU2X(115200);
  serialBeginU2X(SERSPEED);
  
  
  // set digital pin for "analog out" as output
  pinMode(AOutPin, OUTPUT); 
  // .. and also for pwm period indicators
  pinMode(end_PwmPin, OUTPUT); 
  pinMode(end1PwmPin, OUTPUT); 
  pinMode(end2PwmPin, OUTPUT); 
  
  pinMode(ledPin, OUTPUT); 
  bitl = digitalPinToBitMask(ledPin);
  portl = digitalPinToPort(ledPin);  
  outl = portOutputRegister(portl);
 
  digitalWrite(ledPin, HIGH);
  
  // **************************   
  // * halt timers first, to allow them to start synchronized (simultaneously)
  
  // GTCCR - General Timer/Counter Control Register
  // TSM - - - - - PSRASY PSRSYNC
  // Bit 7 - TSM: Timer/Counter Synchronization Mode - 1 activates
  // PSRASY - Clear: Prescaler for Timer/Counter2; 1 (setting) resets
  // Bit 0 - PSRSYNC: Prescaler Reset; 1 resets Timer/Counter1 and Timer/Counter0 prescaler (shared)
  GTCCR = 0b10000011;
  
  
  // **************************   
  // * use the 16-bit timer, without prescaler, for detecting 44.1KHz period
  
  // for Atmega328, that is Timer/Counter1 
  // 'Chap.15 16-bit Timer/Counter1 with PWM ... 114' in datasheet
  // note (datasheet):  'The 16-bit register 
  //  MUST BE BYTE ACCESSED USING **TWO** read or write operations.
  //  Note that when using "C", the compiler handles the 16-bit access.'
  // unsigned int i; i = TCNT1;
  // also: http://www.arduino.cc/playground/Code/InfraredReceivers

  //  Timer/Counter: Modes of Operation
  //  Waveform Generation mode (WGM13:0) - Normal WGM13:0 = 0
  //  Normal port operation, OC1A/OC1B disconnected.

  // TCCR1A – Timer/Counter1 Control Register A: COM1:a1a0b1b0 - - wgm11,wgm10
  // "// COM1A1=0, COM1A0=0 => Disconnect Pin OC1 from Timer/Counter 1 -- PWM11=0,PWM10=0 => PWM Operation disabled"
  
  // ## NOW - we use interrupts, so CTC mode... 
  // "matches either the OCR1A (WGM13:0 = 4) or the ICR1 (WGM13:0 =12)."
  // "Using the ICR1 Register for defining TOP works well when using fixed TOP values. By using ICR1, the OCR1A Register is free to be used for generating a PWM output on OC1A. "
  // ICR1 is 16 bit (has L and H).. so choosing it: WGM13:0 =12 (1100)
  TCCR1A = 0;
  ICR1 = periodARate;
  
  // TCCR1B – Timer/Counter1 Control Register B
  // ICNC1 ICES1 – WGM13 WGM12 CS12 CS11 CS10
  // // "ICNC1=0 => Capture Noise Canceler disabled -- ICES1=0 => Input Capture Edge Select (not used) -- WGM12=CTC1 => Clear Timer/Counter 1 on Compare/Match"
  // Bit 2:0 – CS12:0: Clock Select -
  //  select the clock source to be used by the Timer/Counter,
  //  0 0 1 clkI/O/1 (No prescaling) == 16 MHz
  TCCR1B = 0b00011001; // 0b00000001;
  // TCCR1C – Timer/Counter1 Control Register C
  // Force Output Compare
  TCCR1C = 0;
  
  // An interrupt can be generated at each time the counter value reaches the TOP value by either using the OCF1A or ICF1 Flag according to the register used to define the TOP value. 
  // TIMSK1: Bit 5 – ICIE1: Timer/Counter1, Input Capture Interrupt Enable - executed when the ICF1 Flag...
  // so I'd need: TIMER1_CAPT_vect  _VECTOR(10)  /* Timer/Counter1 Capture Event
  TIMSK1 = 0b00100000;
  //~ TIFR1  = 0b00100111;
  
  
  // ************************** 
  // * use 8-bit timer for PWM: 
 
  // for Atmega328, that is Timer/Counter0 or Timer/Counter2 - use 0 
  // here we would like to choose Phase Correct PWM Mode (dual-slope) 
  //   for "better" audio - however, that goes only up to 16000000/510 = 31372.5 Hz
  // so here we choose fast PWM, which with no prescaler =1, then freq 62500
  // fast PWM mode (WGM02:0 = 3 or 7) - choose WGM2:0 = 3 = 011
  // 'TOP is defined as 0xFF when WGM2:0 = 3, and OCR0A when WGM2:0 = 7
  // Setting the COM0x1:0 bits to two will produce a non-inverted PWM and an inverted PWM output can be generated by setting the COM0x1:0 to three:' - choose two=10
  // clock select CS: 0 0 1 clkI/O/(No prescaling) - Hz: 16000000 clock -> 62500 PWM
  // keep interrupts disabled
  // if needed: TCNT0 – Timer/Counter Register
  // OCRnA (Output Compare Register A) 
  // ... compares with TCNTn to gen OCnA (and can also be set to TOP)!
  // so: set OCR0A - to write to OC0A pin PWM! 
  
  // on 28 PDIP - 
  // OC0A is (PCINT22/OC0A/AIN0) PD6 == pin 12 on Atmega 
  //  - that is digitalOut pin 6 on J1 (where RXD, TXD are pins 0, 1) on Arduino Duemilanove
  // OC0B is (PCINT21/OC0B/T1) PD5 == pin 11 on Atmega
  //  - that is digitalOut pin 5 on J1 
  
  // -b 253 = 0b11111101 -b 254 = 0b11111110 -b 255 = 0b11111111 
  // NOTE - seemingly; 8-bit compare match cannot be made to react to val 255 in fast PWM! 
  
  // TCCR0A – Timer/Counter Control Register A
  // COM0A1 COM0A0 COM0B1 COM0B0 – – WGM01 WGM00
  // 10------: Clear OC0A on Compare Match, set OC0A at BOTTOM, (non-inverting mode).    (### the PWM)
  // --11----: Set OC0B on Compare Match, clear OC0B at BOTTOM, (inverting mode).  (## at very end)
  // [WGM2:0]=011; ------11: Fast PWM TOP=0xFF UpdOCRx=BOTTOM TOV=MAX

  TCCR0A = 0b10110011;
  
  // TCCR0B – Timer/Counter Control Register B
  // FOC0A FOC0B – – WGM02 CS02 CS01 CS00
  // 00------: Force Output Compare A/B (only non-PWM mode.)
  // -----001: Clock Select - clkI/O/(No prescaling)
  //    for no clock prescaling (N=1), pwm period for fast pwm is: 
  //    f_clk/[N*(1+TOP)] = '16000000/(1*(1+255))' = 62500
  TCCR0B = 0b00000001; 
  
  OCR0A = 0b10000000; // must set this once (duty cycle 50), in order to see PWM on out at very start.. 
  OCR0B = 0b11111110; // pin OC0B should indicate very end (final step) of PWM period 0b11111111 (but cannot, so -1) 
  
  // set interrupt when reaching OCR0B (-> TIMER0_COMPB_vect): Bit 2 - OCIE0B: 
  TIMSK0 = 0b00000100; 
  
  // ************************** 
  // * use 8-bit timer2 as 'copy' of timer0; since now
  // * we have to derive "copy pcm buffer cap" and "blank pcm buffer cap" signals
  // * (before the 'next' PWM period starts). 
  
  // OC2A is PB3 (MOSI/OC2A/PCINT3) == pin 17 on Atmega
  //  - that is digitalOut pin 11 on J3
  // OC2B is (PCINT19/OC2B/INT1) PD3 == pin 5 on Atmega
  //  - that is digitalOut pin 3 on J1
  
  // 11------:Set OC2A on Compare Match, clear OC2A at BOTTOM, (inverting mode).
  // --11----: Set OC2B on Compare Match, clear OC2B at BOTTOM, (inverting mode).
  TCCR2A = 0b11110011; // ... else, same as above
  TCCR2B = 0b00000001; // same as above
  
  OCR2A = 0b11111100; // pin OC2A should indicate two steps before end of PWM period (but cannot, so -1) 
  OCR2B = 0b11111101; // pin OC2B should indicate one step before end of PWM period (but cannot, so -1) 
  
  
  // **************************   
  // * use fast ADC: 

  // 'In Free Running mode, always select the channel before starting the first conversion. '
  // ADMUX – ADC Multiplexer Selection Register
  // REFS1 REFS0 ADLAR – MUX3 MUX2 MUX1 MUX0
  // REFS[1:0]: Reference Selection Bits: 0 1 AVCC with external capacitor at AREF pin
  // ADLAR: ADC Left Adjust Result: Consequently, if the result is left adjusted and no more than 8-bit precision is required,  it is sufficient to read ADCH ; 1 to set MS data in ADCH! 
  // MUX3...0 Single Ended Input - 0000 ADC0
  ADMUX = 0b01100000;
  
  // ADCSRB – ADC Control and Status Register B
  // – ACME – – – ADTS2 ADTS1 ADTS0
  // Bit 2:0 – ADTS[2:0]: ADC Auto Trigger Source - 0 0 0 Free Running mode
  ADCSRB = 0b00000000; 

  //ADCSRA – ADC Control and Status Register A
  // ADEN ADSC ADATE ADIF ADIE ADPS2 ADPS1 ADPS0
  // ADEN: ADC Enable ; 
  // ADSC: ADC Start Conversion ; In Free Running mode, write this bit to one to ***start the first conversion***.
  // Bit 5 – ADATE: ADC Auto Trigger Enable When this bit is written to one, Auto Triggering of the ADC is enabled.  selected by setting ADTS in ADCSRB
  // Bit 4 – ADIF: ADC Interrupt Flag
  // Bit 3 – ADIE: ADC Interrupt Enable
  // Bits 2:0 – ADPS[2:0]: ADC Prescaler Select Bits
  // analog rate is f_clk/PRESCALE/13 (13 ADC cycles to complete conv):
  // 16000000/16/13 = 76923.1 ; 16000000/32/13 = 38461.5
  // so we'll go with 77K free running, and we'll read at lesser interval: 
  // ADPS[2:0]: 1 0 0  - 16
  ADCSRA = 0b11100100;

  // reset buffer
  rx_buffer.pos = 0; 
  rx_buffer.tail = 0; 
  
  // reset 
  timerCountTS = 0;
  timerCountTS_now =0;
  
  // we have no interrupts - but wait a ms, to let 
  // the first ADC conversion finish  
  //~ delay(1); // NEVER use delay in setup! else digwrite after it - and all in loop - doesn't work!
   
  digitalWrite(ledPin, LOW);
  
  TCNT1 = 0; 
  TCNT0 = 0; 
  TCNT2 = 0; 
  
  // **************************   
  // * unhalt timers, to allow them to start synchronized (simultaneously)
  
  // clearing bit 7 TSM should clear other bits, and "start counting simultaneously"
  GTCCR = 0b00000000;  
  
  sei(); // Enable interrupts once registers have been updated

} 

// receive USB ISR:
#if defined(__AVR_ATmega8__)
//SIGNAL(SIG_UART_RECV)
ISR(SIG_UART_RECV, ISR_NAKED)
#else
//SIGNAL(USART_RX_vect)
ISR(USART_RX_vect, ISR_NAKED)
#endif
{
  //cli(); // Disable interrupts so we don't interrupt ourselves
  //*outl |= bitl; //digitalWrite(ledPin, HIGH);
  
//~ #if defined(__AVR_ATmega8__)
  //~ unsigned char c = UDR;
//~ #else
  //~ unsigned char c = UDR0;
//~ #endif
  
  // read bit 7 (RXC0) from UCSR0A - USART Receive Complete
  // indicates if there are unread data present in the receive buffer
  //~ while ((UCSR0A) & (1 << RXC0)) { // do NOT fully drain/flush here....
  //~ if ((UCSR0A) & (1 << RXC0)) { // ... go byte by byte! 
    
    //~ // increase counter - will autowrap for buffer size 256
    //~ rx_buffer.pos += 1;

    //~ // read byte
    //~ rx_buffer.data[rx_buffer.pos] = UDR0;    
  //~ }
  //~ else { // the below is completely unnecesarry, but just to stabilize timing
    //~ _c = rx_buffer.pos-1; //write in prev loc
    //~ rx_buffer.data[_c] = UDR0;
  //~ }
  //~ if (TCNT1 < periodPwmRate) GTCCR = 0b00000000;
  //~ else GTCCR = 0b10000000;
  //~ _c = (((UCSR0A) & (1 << RXC0)) > 0); //% (1 << RXC0);
  //~ *outl |= bitl; //HIGH (LED Dout13)
  while ( !(UCSR0A & (1<<RXC0)) ) ; /* Wait for data to be received ? no help, really - but doesn't look like its a problem to keep it.  */

  rx_buffer.pos += 1; //_c; //(_c >> RXC0); //interrupt now
  rx_buffer.data[rx_buffer.pos] = UDR0;
  reti();
}

// this should fire when PCM period has expired - via Timer1 in CTC mode. 
// TIMER1_CAPT_vect - since here we use ICR1 as TOP comparison for CTC mode.. 
ISR(TIMER1_CAPT_vect, ISR_NAKED)
{
  unsigned char sreg;

  sreg = SREG;  /* Save global interrupt flag */
  cli(); /* Disable interrupts */
  //~ GTCCR = 0b10000011;
  //~ TCNT2 = 250; TCNT0 = 250; 
  //~ TCCR0A = 0b10110011; TCCR2A = 0b11110011; // connect compare output from pins
  //~ TCCR0B = 0b00000001; TCCR2B = 0b00000001; // unkill clocks -  TCCRnB; NOT TCCRnA!
  
  *outl |= bitl; //HIGH (LED Dout13)
  
    // now write next (FIFO!) value in RX buffer to PWM:
    //~ if (rx_buffer.pos) {
      //~ // ~ OCR0A = rx_buffer.data[rx_buffer.pos];
      //~ rx_buffer.pos--;
    //~ }
    /// reduce branching in code - remove `if`:
    //~ rx_buffer.pos -= (rx_buffer.pos > 0);
    
    OCR0A = rx_buffer.data[rx_buffer.tail]; // use += 1; to test.. 
    rx_buffer.tail += (rx_buffer.pos != rx_buffer.tail); // not >, just != 
    //~ TCNT0 = 0; TCNT2 = 0; 
    //~ sei();
    //~ GTCCR = 0b00000000;
    //~ TIMSK0 = 0b00000100; // enable ISR
    
    // read whatever value is there now in ADC (free-running - ADCH)
    // read ADCH only - this time, 8-bit is enough
  // NOTE: doing UDR0 = ADCH; will likely result with nothing at all!
    _c = ADCH;
    // and send to TX -> USB ;
    //~ while (!((UCSR0A) & (1 << UDRE0)))  // maybe no need for wait here? Nope..
      //~ ;
    UDR0 = _c;
  
  *outl &= ~bitl; // LOW (LED Dout13)  
  
  SREG = sreg; /* Restore global interrupt flag */
  //~ TCNT1 = 0;  // reset should be done automatically here?? 
  
  reti();
}

// this should fire when PWM period has expired (or close to)
ISR(TIMER0_COMPB_vect, ISR_NAKED)
{
  // "When no clock source is selected (CS02:0 = 0) the timer is stopped. However, the TCNT0 value can be accessed by the CPU, regardless of whether clkT0 is present or not. "
  //~ *outl |= bitl; //HIGH (LED Dout13)
  
  //~ TCCR0B = 0b00000000; TCCR2B = 0b00000000; // kill clocks -  TCCRnB; NOT TCCRnA!
  //~ TCCR0A = 0b00000000; TCCR2A = 0b00000000; // disconnect compare output from pins
  //~ GTCCR = 0b10000000; // try not resetting prescalers?? nah.. doesn't do much - and it stops working if we use ------11 so we reset timer1 anyways (as it is bound to timer0). Seems to not have infulence here anyways... 
  //~ TIMSK0 = 0b00000000; //disable ISR
  //TCNT2 = 255; TCNT0 = 255; // first stop, then reset TCNT! still the same, if reset to 0 ! 
  
  //~ *outl &= ~bitl; // LOW (LED Dout13)  
  
  reti();
}

void loop() 
{
  // ciao - see u next round :) 
}


