import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'notification_service.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io';
  final int port = 1883;
  int? _currentUserId; // Store ID for use across methods
  final String topic = 'test/topic';

  // For real-time UI updates
  static final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  Future<void> initialize(int userId, [ServiceInstance? service]) async {
    _currentUserId = userId; // Store the ID
    // Use a more unique client ID to avoid conflicts
    final String uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final String stableClientId = 'user_chat_${userId}_$uniqueId';
    
    print('MQTT: Initializing for user $userId with CID $stableClientId');
    
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
        .withWillTopic('willtopic')
        .withWillMessage('Disconnected unexpectedly')
        .startClean() // Important for fresh starts
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      print('MQTT: Connecting to $broker...');
      // IMPORTANT: Set up the listener BEFORE connecting to ensure we don't miss any messages
      client.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
        final recMess = c![0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        print('MQTT: Received message on topic ${c[0].topic}: $payload');
        
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          final String sender = data['sender'] ?? "New Message";
          final String content = data['content'] ?? "";
          service?.invoke('onMessage', data);
          
          // Push to stream for UI updates
          _messageStreamController.add(data);
          
          NotificationService.showNotification(sender, content);
        } catch (e) {
          print('MQTT: Error parsing payload - $e');
          NotificationService.showNotification("New Message", payload);
        }
      });

      await client.connect();
    } catch (e) {
      print('MQTT: Connection failed - $e');
      client.disconnect();
    }
  }

  void onConnected() {
    print('MQTT: Connected successfully');
    if (_currentUserId != null) {
      final String userTopic = 'chat/user/$_currentUserId';
      print('MQTT: Subscribing to $userTopic');
      client.subscribe(userTopic, MqttQos.atLeastOnce);
      
      // Notify for debugging
      NotificationService.showNotification("Chat Service", "Connected for user $_currentUserId");
    }
  }

  void onSubscribed(String topic) {
    print('MQTT: Confirmed subscription to $topic');
  }

  void disconnect() {
    client.disconnect();
    print('MQTT: Disconnected manually');
  }

  void onDisconnected() => print('MQTT: Disconnected');
}
