import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'notification_service.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io';
  final int port = 1883;
  final String clientId =
      'flutter_bg_client_${DateTime.now().millisecondsSinceEpoch}';
  final String topic = 'test/topic';

  Future<void> initialize() async {
    client = MqttServerClient(broker, clientId);
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.setProtocolV311();

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      print('MQTT: Connecting...');
      await client.connect();
    } on NoConnectionException catch (e) {
      print('MQTT: Client exception - $e');
      client.disconnect();
    } on SocketException catch (e) {
      print('MQTT: Socket exception - $e');
      client.disconnect();
    }
  }

  void onConnected() {
    print('MQTT: Connected');
    client.subscribe(topic, MqttQos.atMostOnce);

    // Listen for messages
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      print('MQTT: Received message: $payload from topic: ${c[0].topic}');

      // Show notification
      NotificationService.showNotification("New MQTT Message", payload);
    });
  }

  void onDisconnected() {
    print('MQTT: Disconnected');
    // detailed logic can be added here to auto-reconnect
  }

  void onSubscribed(String topic) {
    print('MQTT: Subscribed to $topic');
  }
}
