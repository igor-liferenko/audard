#ifdef __cplusplus
extern "C" {
#endif
  #include <inttypes.h>
  #include <avr/io.h>
//  #include <avr/interrupt.h>
  #include <avr/pgmspace.h>
  #include <util/delay.h>
#ifdef __cplusplus
}
#endif
#include "WProgram.h"
#include "wiring.h"
#include "MyClass.h"


MYCLASS MyClass;

MYCLASS::MYCLASS(void)
{
  return;
}

uint8_t MYCLASS::init(uint8_t in[], uint8_t inlen)
{
  uint8_t cltmp;
  cltmp = in[0];
  for(char i=0;i<inlen;i++) {
    in[i] = cltmp;
  }
}
