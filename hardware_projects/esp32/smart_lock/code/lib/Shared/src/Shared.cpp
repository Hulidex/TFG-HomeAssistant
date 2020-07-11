#include "Shared.h"
#include "Arduino.h"

void no_wait_delay(unsigned long milli_seconds, void (*f)()){
  unsigned long time_now;

  time_now = millis();
  while(millis() < (time_now + milli_seconds)){
    (*f)();
  }
}

void blink_status_led(unsigned long milli_seconds){
  digitalWrite(STATUS_LED, HIGH);
  delay(milli_seconds);
  digitalWrite(STATUS_LED, LOW);
  delay(milli_seconds);
  digitalWrite(STATUS_LED, HIGH);
  delay(milli_seconds);
  digitalWrite(STATUS_LED, LOW);
  delay(milli_seconds);
}
