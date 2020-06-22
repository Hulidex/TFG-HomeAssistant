#include <WiFi.h>
#include <PubSubClient.h>
#include <Servo.h>
#define SERVO_PIN 14
#define STATUS_LED 12
#define POWER_BUTTON 13

// CONFIG
char SSID[] = "IoT_IZQUIERDO";
const char PASSWD[] = "4n5qpCE4";
const char MQTT_BROKER[] = "192.168.1.130";
unsigned int  MQTT_PORT = 64444;

// DO NOT TOUCH THE FOLLOWING VARIABLES
volatile bool powered_off = false;

WiFiClient espClient;
PubSubClient mqtt_client(espClient);
Servo servoLock;

void printWifiData() {
  // print IP address:
  IPAddress ip = WiFi.localIP();
  Serial.print("IP Address: ");
  Serial.println(ip);
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
String byte_to_String(byte *data, unsigned int size) {
  String str;

  for(unsigned i = 0; i < size; ++i){
    str += static_cast<char>(data[i]);
  }

  return str;
}
void receive_payload(const char raw_topic[], byte* raw_payload, unsigned int length) {
  String topic(raw_topic);
  String payload = byte_to_String(raw_payload, length);

  if(topic == "/home/Jolu Bedroom/light1/set"){
    if (payload == "turn on"){
      servoLock.write(180);
      mqtt_client.publish("/home/Jolu Bedroom/light1/status", "on");
    } else {
      servoLock.write(0);
      mqtt_client.publish("/home/Jolu Bedroom/light1/status", "off");
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

    if (mqtt_client.connect("ESP32LIGHT_BULBClient")){
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
  mqtt_client.publish("/home/Jolu Bedroom/light1/available", "online", true);
  mqtt_client.publish("/home/Jolu Bedroom/light1/status", "off", true);
  mqtt_client.subscribe("/home/Jolu Bedroom/light1/set", 1);
}
void no_wait_delay(unsigned long milli_seconds, void (*f)()){
  unsigned long time_now;


  time_now = millis();
  while(millis() < (time_now + milli_seconds)){
    (*f)();
  }
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
void poweroff() {
  powered_off = !powered_off;
}

void setup() {
  pinMode(STATUS_LED, OUTPUT);
  pinMode(POWER_BUTTON, INPUT);
  //attachInterrupt(digitalPinToInterrupt(POWER_BUTTON), poweroff, RISING);
  digitalWrite(STATUS_LED, LOW);
  servoLock.attach(SERVO_PIN);
  Serial.begin(115200);

  connect_wifi();
  connect_mqtt_broker();

}

void loop() {
  if (powered_off) {
    servoLock.write(0);
    mqtt_client.publish("/home/Jolu Bedroom/light1/status", "off", true);
    mqtt_client.publish("/home/Jolu Bedroom/light1/available", "offline", true);
    mqtt_client.unsubscribe("/home/Jolu Bedroom/light1/set");
    delay(5000);
    mqtt_client.disconnect();
    WiFi.disconnect();

    while(powered_off){
      delay(2000);
      digitalWrite(STATUS_LED, LOW);
      delay(2000);
      digitalWrite(STATUS_LED, HIGH);
    }

    ESP.restart();
  } else {
    check_connection();
  }
}
