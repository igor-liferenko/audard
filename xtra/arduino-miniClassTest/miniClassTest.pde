#include "MyClass.h"

//sizeof will work only if size spec. at start

uint8_t testarr[16]; // = {3,2,1,5}; 
uint8_t testvar;

void setup()
{
  pinMode(LED_PIN, OUTPUT);
  testvar = 2; 
}

void loop()
{
  uint8_t testarr[16]; //={3,2}; keeps on resetting
  if (testvar==2) {
    delay(10);
    testarr[0]=3;testarr[1]=2;testarr[2]=1;testarr[3]=5;
    MyClass.init(testarr,(uint8_t)sizeof(testarr));
    delay(10);
    testvar=1;
  }
  else if(testarr[0]==testarr[1]) 
    digitalWrite(LED_PIN, HIGH);
  else
    digitalWrite(LED_PIN, LOW);
}
