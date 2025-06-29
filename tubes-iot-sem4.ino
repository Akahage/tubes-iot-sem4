#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// --- WiFi Configuration ---
const char* ssid = "STARLINK 5G";
const char* password = "umrjateng";

// --- MQTT Configuration ---
const char* mqtt_server = "192.168.8.114";
const int mqtt_port = 1883;
const char* mqtt_client_id = "esp32_33423102";
const char* mqtt_username = "uas25_akmal";
const char* mqtt_password = "uas25_akmal";

// --- MQTT Topics ---
const char* BASE_TOPIC = "UAS25-IOT/33423102";
const char* temp_topic = "UAS25-IOT/33423102/SUHU";
const char* ph_topic = "UAS25-IOT/33423102/PH";
const char* control_topic = "UAS25-IOT/33423102/status";

// --- Pin Configuration --- 
#define ONE_WIRE_BUS 4     // GPIO4 for DS18B20
#define PH_PIN 34          // Analog input pin (ESP32: GPIO34 recommended for analog)

// --- Objects ---
WiFiClient espClient;
PubSubClient client(espClient);
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);
DeviceAddress tempDeviceAddress;

// --- Variables ---
bool sensorActive = false;
unsigned long lastSensorPublish = 0;
const unsigned long sensorInterval = 5000;

void setup_wifi();

void setup() {
  Serial.begin(115200);
  delay(100);

  Serial.println("\nStarting ESP32 Setup...");


  sensors.begin();
  Serial.print("Jumlah sensor ditemukan: ");
  Serial.println(sensors.getDeviceCount());

  if (!sensors.getAddress(tempDeviceAddress, 0)) {
    Serial.println("Sensor DS18B20 TIDAK ditemukan. Cek koneksi.");
  } else {
    Serial.print("Sensor ditemukan dengan alamat: ");
    for (uint8_t i = 0; i < 8; i++) {
      Serial.print(tempDeviceAddress[i], HEX);
      Serial.print(" ");
    }
    Serial.println();
  }

  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  Serial.println("ESP32 IoT Device Ready!");
}

void setup_wifi() {
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");

  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  if (String(topic) == control_topic) {
    DynamicJsonDocument doc(128);
    deserializeJson(doc, message);

    if (doc.containsKey("command")) {
      String command = doc["command"];
      if (command == "start") {
        sensorActive = true;

        Serial.println("Sensor ON");
      } else if (command == "stop") {
        sensorActive = false;

        Serial.println("Sensor OFF");
      }
    }
  }
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection to ");
    Serial.print(mqtt_server);
    Serial.println("...");

    if (client.connect(mqtt_client_id, mqtt_username, mqtt_password)) {
      Serial.println("Connected to MQTT broker");
      client.subscribe(control_topic);
      Serial.print("Subscribed to: ");
      Serial.println(control_topic);

    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" retry in 5 seconds");
      delay(5000);
    }
  }
}

void publishSensorData() {
  if (!sensorActive) return;

  sensors.requestTemperatures();
  float temperature = sensors.getTempCByIndex(0);
  if (temperature == DEVICE_DISCONNECTED_C) {
    Serial.println("Gagal baca suhu!");
    temperature = 0.0;
  }

  int nilaiADC = analogRead(PH_PIN);
  float voltase = (3.3 / 4095.0) * nilaiADC;
  float nilaiPH = 7.0 + ((2 - voltase) / 0.18);

  Serial.print("Suhu: "); Serial.print(temperature); Serial.println(" °C");
  Serial.print("pH: "); Serial.print(nilaiPH); Serial.print(" (ADC: "); Serial.print(nilaiADC); Serial.print(", Volt: "); Serial.print(voltase); Serial.println(")");

  DynamicJsonDocument tempDoc(64);
  tempDoc["value"] = temperature;
  String tempJson;
  serializeJson(tempDoc, tempJson);
  client.publish(temp_topic, tempJson.c_str());

  DynamicJsonDocument phDoc(64);
  phDoc["value"] = nilaiPH;
  String phJson;
  serializeJson(phDoc, phJson);
  client.publish(ph_topic, phJson.c_str());
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  unsigned long now = millis();
  if (sensorActive && now - lastSensorPublish > sensorInterval) {
    lastSensorPublish = now;
    publishSensorData();
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost! Reconnecting...");
    setup_wifi();
  }

  delay(10);

}