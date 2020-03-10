# Description

Turn on/off a LED via Home Assistant with MQTT. If you find an error please open
an issue or a merge request with the problem solved.

# Requirements

**HARDWARE**:

- Espressif ESP-WROOM-32, alias *nodemcu-32s**.
- A router to create a LAN network shared by all the devices.
- Raspberry pi 3/4 or other Home-Assistant's compatible machine.
- *2x* LEDS (I suggest using a red one for the error LED and one with another
  color with a different color for distinguish which LED is controlled by
  Home-Assistant).
- *2x* 330 Ω resistors for LEDS
- *1x* Button
- *1x* 10 KΩ resistor for configure the Button as a pull-down resistor.
- Bread-board.
- a bunch of jumper wires.


**SOFTWARE**
- This project was programmed with PlatformIO, therefore if you use it as well
  you only have to build the code and upload it to the board, PlatformIO will
  take care about downloading needed libraries and configuring the project. More
  information
  [here](https://docs.platformio.org/en/latest/quickstart.html#process-project).
- A working instance of Home-Assistant (I have installed Home-Assistant into a
  Raspberry pi 4).
- A configured and working MQTT broker (I have installed the broker in my
  Raspberry pi 4 as well and I'm using [Mosquitto MQTT
  broker](https://randomnerdtutorials.com/how-to-install-mosquitto-broker-on-raspberry-pi/)).

# Wiring Diagram

A proper wiring diagram is pending, an horrible photo took with my smartphone was
place instead.
[photo](images/2.jpg)

You can take a look at my board's pin-out [here](https://www.instructables.com/id/ESP32-Internal-Details-and-Pinout/)

# ESP32 configuration

You Have to modify some variables from the file *src/main.cpp* according to your
network configuration, and MQTT broker:

```C++
char SSID[] = "Pepito_Network"; // Your router's  SSID
const char PASSWD[] = "1234"; // Your router's Password
const char MQTT_BROKER[] = "192.168.0.34"; // IP to your MQTT broker
unsigned int  MQTT_PORT = 1883; // PORT used by yout MQTT broker
```

## Warnings

- Do not modify any other piece of code unless you know what you're actually
  doing.
- You can have information about the Library I'm using for transforming the
  ESP32 into a MQTT client [here](https://pubsubclient.knolleary.net/api.html).
  That library, doesn't support SSL connections to the broker, and in my code
  I publish the messages to the broker as an *anonymous* entity, therefore
  you have to configure your broker to allow **anonymous entities**.



# Home-Assistant configuration

You have to add the following lines to your *configuration.yaml*:
```YAML
switch:
  - platform: mqtt
    name: "Light 1"
# Command topic settings - HASS will publish to this topic
    command_topic: "/home/Jolu Bedroom/light1/set"
    payload_on: "turn on"
    payload_off: "turn off"
# State topic settings - HASS will subscribe to this topic
    state_topic: "/home/Jolu Bedroom/light1/status"
    state_on: "on"
    state_off: "off"
    qos: 2
# Availability settings - HASS will subscribe to this topic to know if
# the device is available.
    availability_topic: "/home/Jolu Bedroom/light1/available"
    payload_available: "online"
    payload_not_available: "offline"
```

Home-Assistant will create a new entity called *Light 1*. You can control it by
adding a new entity in the **Overview** section.

[hass-capture](images/1.png)

Note that I didn't show any configuration related to the MQTT broker because I
presume that you've already done it.

# State Diagram

A proper diagram is pending, but just know that when you upload the code to the
board the following scenario will happen:

1. It will try to establish a WiFi connection with your router. If it fails it
   will turn on the RED LED, and will try to reconnect every ten seconds until a
   proper connection is met.
2. It will try to establish connection with your MQTT broker, by subscribing to
   some topics, and publishing some messages about the initial state of the
   controlled LED. If it fails it will turn on the RED LED, and will try to
   reconnect every two seconds until a proper connection with the broker is met.
3. When it is properly connected to both, the WiFi and the MQTT broker, it will
   execute it normal operation mode:
   1. It will listen to a certain topic to notice if it has to turn on/off the
   LED, and it will publish some information to other topics once the state
   change.
   2. It will check that the connection to the broker is not broken, if it is,
      it will wipe out all the connections and it will come back to steps 1 and
      then 2 (Try to connect to WiFi and then to MQTT broker).
4. If you press the pull-down button, It will enter in a power-off state, and
   the RED led, will start to blink with a period between blinks of two seconds.
   The device will appear as "*unavailable*" in Home-Assistant, therefore you
   won't be able to control it. If you press again the pull-down button, the
   board will be *reset*, hence the state will come back to step 1.

## Edge cases

I don't implement an action to take in case the device is able to connect to the
WiFi Network and then in the middle of the connection to the broker the device
lost the previous established WiFi connection. If that happen it will loop
infinitely trying to connect o the broker without a WiFi connection, so my
advise is, if the red LED is up for several seconds, and the WiFi network and
the broker are working as expected, reset the device or monitor the device via
*Serial* protocol with your computer, to locate the error.
