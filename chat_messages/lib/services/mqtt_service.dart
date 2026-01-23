import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'notification_service.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io';
  final int port = 1883;
  int? _currentUserId; // Store ID for use across methods
  final String topic = 'test/topic';

  Future<void> initialize(int userId) async {
    _currentUserId = userId; // Store the ID
    final String stableClientId = 'user_chat_$userId';
    client = MqttServerClient(broker, stableClientId);
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
        .withClientIdentifier(stableClientId)
        .withCleanSession(false) // Persistent session
        .withWillTopic('willtopic')
        .withWillMessage('Disconnected')
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      print('MQTT: Connecting for user $userId...');
      await client.connect();
    } catch (e) {
      print('MQTT: Connection failed - $e');
      client.disconnect();
    }
  }

  void onConnected() {
    print('MQTT: Connected');
    if (_currentUserId != null) {
      client.subscribe('chat/user/$_currentUserId', MqttQos.atLeastOnce);
    }

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      NotificationService.showNotification("New Message", payload);
    });
  }

  void onDisconnected() => print('MQTT: Disconnected');
  void onSubscribed(String topic) => print('MQTT: Subscribed to $topic');
}
