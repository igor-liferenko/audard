#ifndef MYCLASS_h
#define MYCLASS_h

#ifdef __cplusplus
extern "C" {
#endif
  #include <inttypes.h>
  #include <avr/pgmspace.h>
#ifdef __cplusplus
}
#endif
#include "WProgram.h"

#define LED_PIN (13)

extern class MYCLASS MyClass;

class MYCLASS
{
  public:
    MYCLASS();

    uint8_t init(uint8_t in[], uint8_t inlen);
};

#endif //MYCLASS_h