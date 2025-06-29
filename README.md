# Flutter IoT MQTT Controller

A comprehensive Flutter application for controlling and monitoring IoT devices through MQTT protocol. This app provides real-time control of LED devices, environmental monitoring, and automated lighting based on light sensor readings.

## Features

### 🔌 MQTT Connectivity
- Secure MQTT broker connection with authentication
- Real-time connection status monitoring
- Automatic reconnection handling
- Customizable broker configuration

### 💡 LED Control System
- **Individual LED Control**: Control up to 3 LEDs independently
- **Group Operations**: Turn all LEDs on/off or trigger blinking patterns
- **Real-time Feedback**: LED states are synchronized with actual device status
- **Auto-Light Mode**: Automatic LED control based on ambient light conditions

### 📊 Environmental Monitoring
- **Temperature Sensing**: Real-time temperature readings in Celsius
- **Humidity Monitoring**: Ambient humidity percentage display
- **Light Detection**: LDR (Light Dependent Resistor) sensor integration
- **Device Status**: Online/offline status with uptime tracking

### 🌟 Smart Features
- **Adaptive Lighting**: Automatic LED control based on light threshold
- **Configurable Thresholds**: Adjustable light sensitivity settings
- **Light Condition Analysis**: Categorized lighting conditions (Dark, Dim, Normal, Bright, Very Bright)
- **Sensor Calibration**: Built-in LDR calibration functionality

## Prerequisites

- Flutter SDK (>=2.0.0)
- Dart SDK (>=2.12.0)
- MQTT Broker (e.g., Mosquitto, HiveMQ)
- ESP8266/ESP32 or compatible IoT device

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  mqtt_client: ^9.7.2
```

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/GreyRust/flutter-iot-mqtt-controller.git
   cd flutter-iot-mqtt-controller
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

## Configuration

### MQTT Broker Setup

Update the MQTT configuration in the app:

```dart
String broker = '192.168.1.100';  // Your MQTT broker IP
int port = 1883;                  // MQTT port
String username = 'your_username'; // MQTT username
String password = 'your_password'; // MQTT password
```

### MQTT Topics

The application uses the following MQTT topics:

| Topic | Purpose | Message Format |
|-------|---------|----------------|
| `esp8266/led` | LED control commands | `{"led1": true, "led2": false}` |
| `esp8266/sensor` | Environmental data | `{"temperature": 25.5, "humidity": 60.2}` |
| `esp8266/status` | Device status | `{"status": "online", "uptime": 3600}` |
| `esp8266/ldr` | Light sensor data | `{"ldr_raw": 512, "light_percentage": 50.0}` |

## Device Integration

### ESP8266/ESP32 Requirements

Your IoT device should support the following functionalities:

1. **MQTT Client**: Connect to MQTT broker and handle pub/sub operations
2. **LED Control**: Handle individual and group LED operations
3. **Sensor Reading**: DHT22/DHT11 for temperature/humidity, LDR for light detection
4. **Status Reporting**: Regular status updates and uptime reporting

### Sample Arduino Code Structure

```cpp
// Essential libraries
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>

// MQTT Topics
const char* LED_TOPIC = "esp8266/led";
const char* SENSOR_TOPIC = "esp8266/sensor";
const char* STATUS_TOPIC = "esp8266/status";
const char* LDR_TOPIC = "esp8266/ldr";
```

## Usage

### Basic Operations

1. **Connect to MQTT Broker**
   - Enter your MQTT broker details
   - Provide username and password if required
   - Tap "Connect" button

2. **Control LEDs**
   - Use individual switches for precise control
   - Use group buttons for bulk operations
   - Enable auto-mode for light-based automation

3. **Monitor Sensors**
   - View real-time temperature and humidity
   - Check light levels and conditions
   - Monitor device status and uptime

### Advanced Features

#### Auto-Light Mode
- Toggle the auto-light switch to enable automatic LED control
- Adjust the light threshold using the slider
- LEDs will automatically turn on/off based on ambient light

#### Sensor Calibration
- Use the calibration feature to optimize LDR readings
- Helps improve accuracy of light detection

## API Reference

### MQTT Message Formats

#### LED Control Commands
```json
{
  "led1": true,
  "led2": false,
  "led3": true,
  "command": "all_on|all_off|blink",
  "auto_light": true,
  "ldr_threshold": 300
}
```

#### Sensor Data Response
```json
{
  "temperature": 25.5,
  "humidity": 60.2,
  "led1_state": true,
  "led2_state": false,
  "led3_state": true
}
```

#### Status Response
```json
{
  "status": "online",
  "uptime": 3600,
  "led1_state": true,
  "led2_state": false,
  "led3_state": true
}
```

#### LDR Data Response
```json
{
  "ldr_raw": 512,
  "light_percentage": 50.0,
  "light_condition": "Normal",
  "auto_mode": true,
  "threshold": 300
}
```

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Verify MQTT broker IP and port
   - Check username/password credentials
   - Ensure network connectivity

2. **No Sensor Data**
   - Confirm device is publishing to correct topics
   - Check MQTT topic subscriptions
   - Verify device online status

3. **LED Control Not Working**
   - Ensure device is subscribed to LED control topic
   - Check JSON message format
   - Verify device connection status

### Debug Mode

Enable debug mode by setting:
```dart
client!.logging(on: true);
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- MQTT Client library contributors
- IoT community for inspiration and support

## Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/GreyRust/flutter-iot-mqtt-controller/issues) page
2. Create a new issue with detailed description
3. Join our community discussions