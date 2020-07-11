#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#define PHOTORESISTOR 34
#define DHT11_PIN 27
#define STATUS_LED 12
#define POWER_BUTTON 13

// CONFIG
char SSID[] = "IoT_IZQUIERDO";
const char PASSWD[] = "4n5qpCE4";
const char MQTT_BROKER[] = "192.168.2.30";
unsigned int  MQTT_PORT = 64444;

WiFiClient espClient;
PubSubClient mqtt_client(espClient);
DHT dht11(DHT11_PIN, DHT11);
int  ambientBrightness;
float humidity;
float temperature;
const char hassAmbientBrightnessConfig[] = "{\
\"unique_id\": \"esp32AmbientBrightness\",\
\"name\": \"ambient Brightness\",\
\"device_class\": \"illuminance\",\
\"unit_of_measurement\": \"lx\",\
\"state_topic\": \"/home/Jolu Bedroom/ambientBrightness/status\",\
\"qos\": 2,\
\"availability_topic\": \"/home/Jolu Bedroom/ambientBrightness/available\",\
\"payload_available\": \"online\",\
\"payload_not_available\": \"offline\",\
\"expire_after\": 5\
}";

const char hassHumidityConfig[] = "{\
\"unique_id\": \"esp32Humidity\",\
\"name\": \"humidity\",\
\"device_class\": \"humidity\",\
\"state_topic\": \"/home/Jolu Bedroom/humidity/status\",\
\"qos\": 2,\
\"availability_topic\": \"/home/Jolu Bedroom/humidity/available\",\
\"payload_available\": \"online\",\
\"payload_not_available\": \"offline\",\
\"expire_after\": 5\
}";

const char hassTemperatureConfig[] = "{\
\"unique_id\": \"esp32Temperature\",\
\"name\": \"Temperature\",\
\"device_class\": \"temperature\",\
\"state_topic\": \"/home/Jolu Bedroom/temperature/status\",\
\"qos\": 2,\
\"availability_topic\": \"/home/Jolu Bedroom/temperature/available\",\
\"payload_available\": \"online\",\
\"payload_not_available\": \"offline\",\
\"expire_after\": 5\
}";

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

  // if(topic == "/home/Jolu Bedroom/ambientBrightness/set"){
  //   if (payload == "turn on"){
  //     digitalWrite(LIGHT_BULB, HIGH);
  //     mqtt_client.publish("/home/Jolu Bedroom/ambientBrightness/status", "on");
  //   } else {
  //     digitalWrite(LIGHT_BULB, LOW);
  //     mqtt_client.publish("/home/Jolu Bedroom/ambientBrightness/status", "off");
  //   }
  // }

}
void connect_mqtt_broker() {
  mqtt_client.setBufferSize(500);
  mqtt_client.setCallback(receive_payload);
  mqtt_client.setServer(MQTT_BROKER, MQTT_PORT);

  while(!mqtt_client.connected()){
    Serial.print("Connecting to MQTT broker: ");
    mqtt_client.setBufferSize(500);
    Serial.print(MQTT_BROKER);
    Serial.print(":");
    Serial.println(MQTT_PORT);

    if (mqtt_client.connect("ESP32SENSORHUBClient")){
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
  mqtt_client.publish("home/sensor/ambientBrightness/config", hassAmbientBrightnessConfig, true);
  mqtt_client.publish("home/sensor/humidity/config", hassHumidityConfig, true);
  mqtt_client.publish("home/sensor/temperature/config", hassTemperatureConfig, true);
  mqtt_client.publish("/home/Jolu Bedroom/ambientBrightness/available", "online", true);
  mqtt_client.publish("/home/Jolu Bedroom/humidity/available", "online", true);
  mqtt_client.publish("/home/Jolu Bedroom/temperature/available", "online", true);
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

void setup() {
  pinMode(PHOTORESISTOR, INPUT);
  pinMode(STATUS_LED, OUTPUT);
  pinMode(POWER_BUTTON, INPUT);
  digitalWrite(STATUS_LED, LOW);
  Serial.begin(115200);
  dht11.begin();

  connect_wifi();
  connect_mqtt_broker();
}

void loop() {
  //Press POWER_BUTTON 3 seconds to shutdown the device
  if (digitalRead(POWER_BUTTON) == HIGH){
    no_wait_delay(3000, check_connection);

    if (digitalRead(POWER_BUTTON) == HIGH){
      digitalWrite(STATUS_LED, HIGH);
      delay(300);
      digitalWrite(STATUS_LED, LOW);
      delay(300);
      digitalWrite(STATUS_LED, HIGH);
      delay(300);
      digitalWrite(STATUS_LED, LOW);

      mqtt_client.publish("/home/Jolu Bedroom/ambientBrightness/available", "offline", true);
      mqtt_client.publish("/home/Jolu Bedroom/humidity/available", "offline", true);
      mqtt_client.publish("/home/Jolu Bedroom/temperature/available", "offline", true);
      delay(5000);
      mqtt_client.disconnect();
      WiFi.disconnect();

      while(true){
        delay(1000);
        digitalWrite(STATUS_LED, LOW);
        delay(1000);
        digitalWrite(STATUS_LED, HIGH);
      }
    }
  } else {
    //Read from photoresistor and convert the gathered dato into lux
    ambientBrightness = 2.442 * analogRead(PHOTORESISTOR); //Save into int and truncate decimals
    //Read from DHT11
    humidity = dht11.readHumidity();
    temperature = dht11.readTemperature();
    Serial.println(temperature);
    mqtt_client.publish("/home/Jolu Bedroom/ambientBrightness/status", String(ambientBrightness).c_str());
    mqtt_client.publish("/home/Jolu Bedroom/humidity/status", String(humidity).c_str());
    mqtt_client.publish("/home/Jolu Bedroom/temperature/status", String(temperature).c_str());


    no_wait_delay(1500, check_connection);
  }
}
