#include <WiFi.h>

const char * SSID = "IoT_IZQUIERDO";
const char * PASSWD = "4n5qpCE4";

void connect_wifi() {
  Serial.println("Trying to connect to AP...");
  while (WiFi.status() != WL_CONNECTED);
  Serial.println("Connected!");
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(SSID, PASSWD);

  connect_wifi();
}

void loop() {
}
