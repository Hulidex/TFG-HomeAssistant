#ifndef __SHARED_H__
#define __SHARED_H__
#define STATUS_LED 12

// FUNCTIONS
void no_wait_delay(unsigned long milli_seconds, void (*f)());
void blink_status_led(unsigned long milli_seconds);

#endif
