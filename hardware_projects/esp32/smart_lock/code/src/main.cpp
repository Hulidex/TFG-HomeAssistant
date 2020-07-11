#include "Shared.h"
#include <WiFi.h>
#include <PubSubClient.h>
#include <Servo.h>
#include <Keypad.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

//###############################################################################
// CONFIG
//###############################################################################

// WIFI CREDENTIALS
char SSID[] = "IoT_IZQUIERDO";
const char PASSWD[] = "4n5qpCE4";

// MQTT SETTINGS
const char MQTT_BROKER[] = "192.168.1.130";
unsigned int  MQTT_PORT = 64444;

// KEYBOARD
#define ROW_SIZE 4
#define COL_SIZE 4
#define PASSWORD_SIZE 4
String lock_password = "*0#D";


//Keyboard layout
char KEYBOARD_LAYOUT[ROW_SIZE][COL_SIZE] = {{'1','2','3','A'},
                                            {'4','5','6','B'},
                                            {'7','8','9','C'},
                                            {'*','0','#','D'}};

// LCD
#define LCD_ROWS 2
#define LCD_COLS 16
#define LCD_ADDR 0x27

//###############################################################################
// PINS
//###############################################################################

#define SERVO_PIN 26
#define POWER_BUTTON 35
// Keyboard pins
byte KEYBOARD_ROWS[ROW_SIZE] = {16,17,5,18};
byte KEYBOARD_COLS[COL_SIZE] = {15,2,0,4};

//###############################################################################
// Objects
//###############################################################################

WiFiClient espClient;
PubSubClient mqtt_client(espClient);
Servo servoLock;
Keypad keyboard = Keypad(makeKeymap(KEYBOARD_LAYOUT), KEYBOARD_ROWS, KEYBOARD_COLS, ROW_SIZE, COL_SIZE);
LiquidCrystal_I2C lcd(LCD_ADDR, 2, 1, 0, 4, 5, 6, 7, 3, POSITIVE);  // Set the LCD I2C address
volatile bool locked = false;
//###############################################################################
// Methods
//###############################################################################

void printLCD(String text){
  lcd.clear();
  lcd.home();

  if (text.length() > 16) {
    lcd.print(text.substring(0, 16).c_str());
    lcd.setCursor(0,1);
    lcd.print(text.substring(16).c_str());
  } else {
    lcd.print(text.c_str());
  }
}

String byte_to_String(byte *data, unsigned int size) {
  String str;

  for(unsigned i = 0; i < size; ++i){
    str += static_cast<char>(data[i]);
  }

  return str;
}

void printWifiData() {
  // print IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);

  // print your MAC address:
  byte mac[6];
  WiFi.macAddress(mac);
  Serial.print("MAC address: ");
  Serial.print(mac[5], HEX);
  Serial.print(":");
  Serial.print(mac[4], HEX);
  Serial.print(":");
  Serial.print(mac[3], HEX);
  Serial.print(":");
  Serial.print(mac[2], HEX);
  Serial.print(":");
  Serial.print(mac[1], HEX);
  Serial.print(":");
  Serial.println(mac[0], HEX);

  // print your subnet mask:
  IPAddress subnet = WiFi.subnetMask();
  Serial.print("NetMask: ");
  Serial.println(subnet);

  // print your gateway address:
  IPAddress gateway = WiFi.gatewayIP();
  Serial.print("Gateway: ");
  Serial.println(gateway);
}

void connect_wifi() {
  int status;
  unsigned long time_now;
  bool exit;


  do {
    Serial.print("Trying to connect to SSID: ");
    Serial.println(SSID);
    WiFi.begin(SSID, PASSWD);

    time_now = millis();
    exit = false;
    while(millis() < (time_now + 10000 ) && !exit){
      status = WiFi.status();
      if(status == WL_CONNECTED){
        digitalWrite(STATUS_LED, LOW);
        exit = true;
      } else {
        digitalWrite(STATUS_LED, HIGH);
      }
    }
  } while(WiFi.status() != WL_CONNECTED);

  Serial.println("Connected!");
  printWifiData();
}

void lock_device(){
  locked = true;
  servoLock.write(0);
  mqtt_client.publish("/home/Jolu Bedroom/lock1/status", "lock");
  printLCD("Device Locked");
  delay(2500);
  printLCD("Type a key to insert password");
}

void unlock_device(){
  locked = false;
  servoLock.write(180);
  mqtt_client.publish("/home/Jolu Bedroom/lock1/status", "unlock");
  printLCD("Device unlocked");
  delay(2500);
  printLCD("Type a key to insert password");
}

void receive_payload(const char raw_topic[], byte* raw_payload, unsigned int length) {
  String topic(raw_topic);
  String payload = byte_to_String(raw_payload, length);

  if(topic == "/home/Jolu Bedroom/lock1/set"){
    if (payload == "lock"){
      lock_device();
    } else {
      unlock_device();
    }
  }
}

void connect_mqtt_broker() {
  mqtt_client.setCallback(receive_payload);
  mqtt_client.setServer(MQTT_BROKER, MQTT_PORT);

  while(!mqtt_client.connected()){
    Serial.print("Connecting to MQTT broker: ");
    Serial.print(MQTT_BROKER);
    Serial.print(":");
    Serial.println(MQTT_PORT);

    if (mqtt_client.connect("ESP32Lockclient")){
      digitalWrite(STATUS_LED, LOW);
      Serial.println("Connected!");
    } else {
      digitalWrite(STATUS_LED, HIGH);
      Serial.print("Failed with state:");
      Serial.println(mqtt_client.state());
      delay(2000);
    }
  }

  // Subscribe and publish to topics
  mqtt_client.publish("/home/Jolu Bedroom/lock1/available", "online", true);
  mqtt_client.subscribe("/home/Jolu Bedroom/lock1/set", 1);
}

void check_connection() {
  while(!mqtt_client.loop()){
    digitalWrite(STATUS_LED, HIGH);
    Serial.print("Failed with state:");
    Serial.println(mqtt_client.state());
    delay(2000);

    if (WiFi.status() != WL_CONNECTED){
      WiFi.disconnect();
      connect_wifi();
    }

    mqtt_client.disconnect();
    connect_mqtt_broker();
  }
}

void scan_I2C_devices(){
  int devices = 0;
  byte error;

  Serial.println("Scanning for I2C devices...");

  for(byte addr = 1; addr < 127; ++addr){
    Wire.beginTransmission(addr);
    error = Wire.endTransmission();
    if (error == 0){
      ++devices;
      Serial.print("I2C device found at address: ");
      Serial.println(addr);
    }
  }

  if (devices == 0){
    Serial.println("No devices found...");
  }
  Serial.println("done!");
}

String read_keyboard_passwd(unsigned long milli_seconds){
  char key;
  String typed_password = "";
  unsigned long time_now = millis();
  byte i = 0;


  lcd.setCursor(0,1);
  lcd.print("                ");
  while ( (i < PASSWORD_SIZE) && (millis() < (time_now + milli_seconds)) ){
    key = keyboard.getKey();

    delay(50);
    if (key){
      lcd.setCursor(i,1);
      lcd.print("*");
      typed_password.concat(key);
      ++i;
    }
  }

  if(typed_password.length() != PASSWORD_SIZE){
    typed_password = "";
  }

  return typed_password;
}



//###############################################################################
// MAIN
//###############################################################################

void setup() {
  // Pin configuration
  pinMode(STATUS_LED, OUTPUT);
  pinMode(POWER_BUTTON, INPUT);
  digitalWrite(STATUS_LED, LOW);
  servoLock.attach(SERVO_PIN);

  // Initialize device
  Serial.begin(115200);
  // Wire.begin();

  lcd.begin(LCD_COLS, LCD_ROWS);
  lcd.backlight();
  lcd.clear();

  printLCD("Connecting to WiFi...");
  connect_wifi();
  printLCD("Connected!");

  printLCD("Connecting to MQTT Broker...");
  connect_mqtt_broker();
  printLCD("Connected!");
  check_connection();

  delay(2000);
  printLCD("Type a key to insert password");
}

void loop() {
  //Press POWER_BUTTON 3 seconds to shutdown the device
  if (digitalRead(POWER_BUTTON) == HIGH){
    no_wait_delay(3000, check_connection);

    if (digitalRead(POWER_BUTTON) == HIGH){
      blink_status_led(300);

      unlock_device();
      mqtt_client.publish("/home/Jolu Bedroom/lock1/status", "unlock", true);
      mqtt_client.publish("/home/Jolu Bedroom/lock1/available", "offline", true);
      mqtt_client.unsubscribe("/home/Jolu Bedroom/lock1/set");
      delay(5000);
      mqtt_client.disconnect();
      WiFi.disconnect();
      lcd.clear();
      lcd.noBacklight();

      while(true){ blink_status_led(1000); }
    }
  } else if (keyboard.getKey()){ // Si se pulsa una tecla

      String typed_password = "";

      printLCD("You have 5 sec...");
      typed_password = read_keyboard_passwd(5000);

      if (typed_password == lock_password) {
        printLCD("Correct!");

        if (locked){
          unlock_device();
        } else {
          lock_device();
        }
      } else {
        printLCD("Password failed!");
        delay(2500);
        printLCD("Press a key to insert password");
      }
  } else {
    check_connection();
  }
}
