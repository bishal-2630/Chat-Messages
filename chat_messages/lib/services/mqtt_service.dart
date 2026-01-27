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
  int? _currentUserId; 
  int? activeChatUserId; // Tracking which chat is currently open in UI
  final String topic = 'test/topic';
  ServiceInstance? _backgroundService;
  StreamSubscription? _updatesSubscription;
 
  // For real-time UI updates (Isolate local)
  static final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  bool get isConnected => 
    client.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> initialize(int userId, [ServiceInstance? service]) async {
    _currentUserId = userId;
    _backgroundService = service;
    _updatesSubscription?.cancel(); // Clear any stale listeners
    // USE TRULY STABLE ID for session persistence
    // REMOVED random suffix to ensure we rejoin the same session if possible, 
    // or at least don't spawn infinite sessions on the broker.
    final String stableClientId = 'bishal_flutter_${userId}_bg_v7';
    
    print('MQTT: [v7] Initializing with STABLE CID: $stableClientId');
    
    client = MqttServerClient(broker, stableClientId);
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 60; 
    client.connectTimeoutPeriod = 5000; // 5s timeout
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.pongCallback = pong; // Add Pong callback
    client.onAutoReconnect = onAutoReconnect; 
    client.autoReconnect = true; 
    client.resubscribeOnAutoReconnect = true;
    client.setProtocolV311();

    final connMess = MqttConnectMessage()
        .withClientIdentifier(stableClientId)
        .startClean(); // Keep clean start for now to avoid state complexity on public broker
    
    client.connectionMessage = connMess;

    print('MQTT: Initialization result - User: $userId, CID: $stableClientId');

    Future<void> doConnect() async {
      int attempts = 0;
      const int maxAttempts = 3;
      
      while (attempts < maxAttempts && !isConnected) {
        try {
          attempts++;
          print('MQTT: [v7] Connection attempt $attempts of $maxAttempts to $broker...');
          await client.connect();
          if (isConnected) {
            print('MQTT: [v7] Connection Successful!');
            break;
          }
        } catch (e) {
          print('MQTT: [v7] Connection attempt $attempts failed: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: 2 * attempts));
          }
        }
      }
    }

    await doConnect();
  }

  void _setupUpdateListener(Stream<List<MqttReceivedMessage<MqttMessage?>>> updates) {
    _updatesSubscription?.cancel(); // Ensure only one listener active
    
    print('MQTT: [v7] Setting up Update Listener...'); 
    _updatesSubscription = updates.listen((c) {
      if (c == null || c.isEmpty) return;
      print('MQTT: --> Batch received. Count: ${c.length}');

      // Iterate through ALL messages in the batch
      for (final message in c) {
        final recMess = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          print('MQTT: [v7] Raw Payload received: $payload');
          final Map<String, dynamic> data = jsonDecode(payload);
          final String type = data['type'] ?? 'new_message';

          // --- 1. RELAY TO UI ISOLATE (ALWAYS DO THIS FIRST) ---
          print('MQTT: [v7] Relaying to UI Isolate via bridge...');
          // Serialize to String to avoid Map type issues across Isolate Bridge
          try {
            final String rawJson = jsonEncode(data);
            _backgroundService?.invoke('onMessage', {'type': 'raw_json', 'payload': rawJson});
            print('MQTT: [v7] Relay invoke called using raw_json method');
          } catch (e) {
            print('MQTT: [v7] Relay FAILED: $e');
          }
          _messageStreamController.add(data);

          // --- 2. SYSTEM NOTIFICATION LOGIC (CONDITIONAL) ---
          if (type == 'new_message') {
            final String sender = data['sender'] ?? "New Message";
            final String content = data['content'] ?? "";
            final int senderId = int.tryParse(data['sender_id'].toString()) ?? -1;

            // SKIP notification if chat is open in UI
            if (activeChatUserId != null && senderId == activeChatUserId) {
              print('MQTT: [v7] Skipping system notification - UI is actively in this chat');
              continue; 
            }

            // SKIP notification if I am the sender
            if (_currentUserId != null && senderId != -1 && senderId == _currentUserId) {
              print('MQTT: [v7] Skipping system notification - I sent this message');
              continue;
            }

            print('MQTT: [v7] Triggering System Notification for $sender');
            try {
              NotificationService.showNotification(sender, content);
            } catch (e) {
              print('MQTT: [v7] FAILED to show notification: $e');
            }
          }
        } catch (e) {
          print('MQTT: [v7] CRITICAL Loop Error: $e. Payload: $payload');
        }
      }
    });
  }

  void onConnected() {
    print('MQTT: [v7] Connected to $broker');
    
    if (_currentUserId != null) {
      final String userTopic = 'bishal_chat/user/$_currentUserId';
      client.subscribe(userTopic, MqttQos.atLeastOnce); // Use QoS 1 for better delivery
      print('MQTT: Subscribing to $userTopic with QoS 1...');
    }
    
    // SETUP LISTENER HERE (Only if needed)
    if (client.updates != null) {
      _setupUpdateListener(client.updates!);
    }
  }

  void onSubscribed(String topic) {
    print('MQTT: Confirmed subscription to $topic');
  }

  
 

  void onAutoReconnect() {
    print('MQTT: Auto-reconnecting...');
  }

  void disconnect() {
    client.disconnect();
    _updatesSubscription?.cancel();
    print('MQTT: Disconnected manually');
  }

  void pong() {
    print('MQTT: [v7] Ping Response received (Pong)');
  }

  void onDisconnected() {
    print('MQTT: Disconnected');
    _updatesSubscription?.cancel();
  }
}
