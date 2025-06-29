import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Sensor Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: IoTMonitorPage(),
    );
  }
}

class IoTMonitorPage extends StatefulWidget {
  const IoTMonitorPage({super.key});

  @override
  _IoTMonitorPageState createState() => _IoTMonitorPageState();
}

class _IoTMonitorPageState extends State<IoTMonitorPage> {
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = 'Disconnected';
  bool sensorDataActive = false; // Status untuk tombol START/STOP

  // MQTT Configuration - Default values
  String broker = '192.168.8.114'; // Default IP, bisa diubah user
  int port = 1883;
  String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  String username = 'uas25_akmal';
  String password = 'uas25_akmal';

  // Base Topic
  String baseTopic = 'UAS25-IOT/33423102';

  // Topics for data subscription (Diperbarui untuk DS18B20 dan pH)
  String suhuTopic = 'UAS25-IOT/33423102/SUHU';      // Untuk suhu dari DS18B20
  String phTopic = 'UAS25-IOT/33423102/PH';          // Untuk nilai pH
  // Topic for control (sending commands to NodeMCU)
  String controlTopic = 'UAS25-IOT/33423102/status';

  // Sensor Data (Diperbarui)
  double temperature = 0.0;
  double pH = 0.0; // Variabel baru untuk pH

  // Controller untuk input IP Broker
  final TextEditingController _brokerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _brokerController.text = broker;
  }

  void _initializeMqttClient() {
    client = MqttServerClient(_brokerController.text.trim(), clientId);
    client!.port = port;
    client!.keepAlivePeriod = 30;
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;
    client!.onSubscribed = onSubscribed;
    client!.logging(on: false);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('$baseTopic/will')
        .withWillMessage('Flutter client disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    connMess.authenticateAs(username, password);

    client!.connectionMessage = connMess;
  }

  Future<void> connectToMqtt() async {
    setState(() {
      connectionStatus = 'Connecting...';
      broker = _brokerController.text.trim();
    });

    _initializeMqttClient();

    try {
      await client!.connect();

      if (client!.connectionStatus?.state == MqttConnectionState.connected) {
        setState(() {
          connectionStatus = 'Connected';
          isConnected = true;
        });

        // Subscribe ke topik data suhu dan pH
        client!.subscribe(suhuTopic, MqttQos.atMostOnce);
        client!.subscribe(phTopic, MqttQos.atMostOnce);

        client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
          final recMess = c![0].payload as MqttPublishMessage;
          final message = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message,
          );
          handleIncomingMessage(c[0].topic, message);
        });
      } else {
        String reason = '';
        switch (client!.connectionStatus?.returnCode) {
          case MqttConnectReturnCode.badUsernameOrPassword:
            reason = 'Bad username or password';
            break;
          case MqttConnectReturnCode.notAuthorized:
            reason = 'Not authorized (check ACL)';
            break;
          case MqttConnectReturnCode.identifierRejected:
            reason = 'Client ID rejected';
            break;
          case MqttConnectReturnCode.brokerUnavailable:
            reason = 'Connection refused (broker down or wrong IP/port)';
            break;
          default:
            reason =
                'Connection failed: ${client!.connectionStatus?.returnCode}';
        }
        setState(() {
          connectionStatus = 'Connection failed: $reason';
          isConnected = false;
        });
        client!.disconnect();
      }
    } catch (e) {
      print('Exception during MQTT connect: $e');
      setState(() {
        connectionStatus = 'Connection failed: ${e.toString()}';
        isConnected = false;
      });
      client!.disconnect();
    }
  }

  void onConnected() {
    print('Connected to MQTT broker');
  }

  void onDisconnected() {
    setState(() {
      connectionStatus = 'Disconnected';
      isConnected = false;
      sensorDataActive = false;
    });
    print('Disconnected from MQTT broker');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  void handleIncomingMessage(String topic, String message) {
    print('Received message: $message from topic: $topic');

    setState(() {
      try {
        final data = json.decode(message);
        if (topic == suhuTopic) {
          temperature = data['value']?.toDouble() ?? temperature;
        } else if (topic == phTopic) { // Handle topik pH
          pH = data['value']?.toDouble() ?? pH;
        }
      } catch (e) {
        print('Error parsing sensor data for topic $topic: $e');
        // Fallback for non-JSON messages (if any)
        if (topic == suhuTopic) {
          temperature = double.tryParse(message) ?? temperature;
        } else if (topic == phTopic) {
          pH = double.tryParse(message) ?? pH;
        }
      }
    });
  }

  void publishMessage(String topic, String message) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $message to topic: $topic');
    } else {
      print('Not connected to MQTT broker. Cannot publish.');
    }
  }

  void toggleSensorData() {
    setState(() {
      sensorDataActive = !sensorDataActive;
    });

    String command = sensorDataActive ? "start" : "stop";
    Map<String, dynamic> controlMessage = {'command': command};
    publishMessage(controlTopic, json.encode(controlMessage));
  }

  void disconnect() {
    client!.disconnect();
  }

  // Fungsi untuk menentukan kondisi pH
  String getPhCondition(double value) {
    if (value < 6.0) {
      return 'Terdeteksi = Cairan Asam';
    } else if (value > 8.0) {
      return 'Terdeteksi = Cairan Basa';
    } else {
      return 'Terdeteksi = Cairan Netral';
    }
  }

  @override
  void dispose() {
    _brokerController.dispose();
    client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT Sensor Monitor'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MQTT Connection Card
            Card(
              elevation: 4,
              margin: EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MQTT Connection',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    TextField(
                      controller: _brokerController,
                      decoration: InputDecoration(
                        labelText: 'MQTT Broker IP Address',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.network_check),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !isConnected,
                    ),
                    SizedBox(height: 10),
                    Text('Status: $connectionStatus',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        )),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? null : connectToMqtt,
                            icon: Icon(Icons.link),
                            label: Text('Connect'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? disconnect : null,
                            icon: Icon(Icons.link_off),
                            label: Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sensor Data Display Card (Diperbarui)
            Card(
              elevation: 4,
              margin: EdgeInsets.only(bottom: 20),
              color: Colors.orange[100],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor Data',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange),
                    ),
                    SizedBox(height: 15),
                    _buildSensorRow('SUHU', Icons.thermostat,
                        '${temperature.toStringAsFixed(1)} °C', Colors.red),
                    SizedBox(height: 10), // Tambahkan sedikit spasi
                    Column( // Gunakan Column untuk pH dan teks kondisinya
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSensorRow('pH', Icons.science,
                            '${pH.toStringAsFixed(2)}', Colors.purple),
                        Padding(
                          padding: const EdgeInsets.only(left: 45.0), // Sesuaikan padding agar sejajar
                          child: Text(
                            getPhCondition(pH),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: pH < 6.0 ? Colors.red : (pH > 8.0 ? Colors.blue : Colors.green),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Sensor Control Card
            Card(
              elevation: 4,
              margin: EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor Control',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Status: ${sensorDataActive ? 'Active (ON)' : 'Inactive (OFF)'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: sensorDataActive
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isConnected ? toggleSensorData : null,
                        icon: Icon(
                            sensorDataActive ? Icons.stop : Icons.play_arrow),
                        label: Text(
                            sensorDataActive ? 'STOP SENSOR' : 'START SENSOR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              sensorDataActive ? Colors.red : Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(
      String label, IconData icon, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(width: 15),
          Text(
            '$label : $value',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
