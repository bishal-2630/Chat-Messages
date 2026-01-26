import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'notification_service.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.hivemq.com'; // Switching to HiveMQ for reliability
  final int port = 1883;
  int? _currentUserId; 
  final String topic = 'test/topic';
  ServiceInstance? _backgroundService;

  // For real-time UI updates
  static final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  Future<void> initialize(int userId, [ServiceInstance? service]) async {
    _currentUserId = userId;
    _backgroundService = service;
    // Use a more unique client ID to avoid conflicts
    final String uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final String stableClientId = 'user_chat_${userId}_$uniqueId';
    
    print('MQTT: Initializing for user $userId with CID $stableClientId');
    
    client = MqttServerClient(broker, stableClientId);
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 30; // Faster failure detection
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.onAutoReconnect = onAutoReconnect; // New callback
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.setProtocolV311();

    final connMess = MqttConnectMessage()
        .withClientIdentifier(stableClientId)
        .startClean() 
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMess;

    print('MQTT: Initialization result - User: $userId, CID: $stableClientId');
    // Attach listener BEFORE connecting to catch early events
    if (client.updates != null) {
      _setupUpdateListener(client.updates!);
    }

    Future<void> doConnect() async {
      try {
        print('MQTT: Attempting to connect to $broker...');
        await client.connect();
      } catch (e) {
        print('MQTT: Connection attempt failed - $e');
        // Retry logic managed by library or manually if needed
      }
    }

    await doConnect();
  }

  void _setupUpdateListener(Stream<List<MqttReceivedMessage<MqttMessage?>>> updates) {
    updates.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      print('MQTT: --> UPDATE RECEIVED! Item count: ${c?.length}');
      if (c == null || c.isEmpty) return;
      
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      
      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final String type = data['type'] ?? 'new_message';
        print('MQTT: Decoded Type: $type');
        
        // Always notify the UI via background service bridge
        _backgroundService?.invoke('onMessage', data);
        _messageStreamController.add(data);

        // ONLY show physical system notification for new messages
        if (type == 'new_message') {
          final String sender = data['sender'] ?? "New Message";
          final String content = data['content'] ?? "";
          print('MQTT: Triggering System Alert for $sender');
          try {
            NotificationService.showNotification(sender, content);
          } catch (e) {
            print('MQTT: FAILED to show system notification: $e');
          }
        }
      } catch (e) {
        print('MQTT: CRITICAL JSON parsing error: $e. Payload was: $payload');
      }
    });
  }

  void onAutoReconnect() {
    print('MQTT: Auto-reconnecting...');
  }

  void onConnected() {
    print('MQTT: Connected to $broker');
    
    if (_currentUserId != null) {
      final String userTopic = 'bishal_chat/user/$_currentUserId';
      client.subscribe(userTopic, MqttQos.atMostOnce);
      print('MQTT: Subscribed to $userTopic');
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
