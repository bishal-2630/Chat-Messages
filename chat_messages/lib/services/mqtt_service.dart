import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'notification_service.dart';

class MqttService {
  late MqttServerClient client;
  final String broker = 'broker.emqx.io'; // Switching to EMQX for better stability
  final int port = 1883;
  int? _currentUserId; 
  final String topic = 'test/topic';
  ServiceInstance? _backgroundService;
  bool _isListenerAttached = false;
 
  // For real-time UI updates
  static final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;

  bool get isConnected => 
    client.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> initialize(int userId, [ServiceInstance? service]) async {
    _currentUserId = userId;
    _backgroundService = service;
    _isListenerAttached = false; // Reset on re-init
    // USE TRULY STABLE ID for session persistence
    final String stableClientId = 'bishal_user_client_$userId';
    
    print('MQTT: Initializing with STABLE CID: $stableClientId');
    
    client = MqttServerClient(broker, stableClientId);
    client.port = port;
    client.logging(on: true);
    client.keepAlivePeriod = 30; // Longer keep-alive for background stability
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;
    client.onAutoReconnect = onAutoReconnect; 
    client.autoReconnect = true; 
    client.resubscribeOnAutoReconnect = true;
    client.setProtocolV311();

    final connMess = MqttConnectMessage()
        .withClientIdentifier(stableClientId)
        .withWillQos(MqttQos.atMostOnce);
    
    client.connectionMessage = connMess;

    print('MQTT: Initialization result - User: $userId, CID: $stableClientId');

    Future<void> doConnect() async {
      int attempts = 0;
      const int maxAttempts = 3;
      
      while (attempts < maxAttempts && !isConnected) {
        try {
          attempts++;
          print('MQTT: Connection attempt $attempts of $maxAttempts to $broker...');
          await client.connect();
          if (isConnected) break;
        } catch (e) {
          print('MQTT: Connection attempt $attempts failed: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: 2 * attempts));
          }
        }
      }
    }

    await doConnect();
  }

  void _setupUpdateListener(Stream<List<MqttReceivedMessage<MqttMessage?>>> updates) {
    if (_isListenerAttached) {
      print('MQTT: Listener already attached, skipping.');
      return;
    }
    _isListenerAttached = true;
    print('MQTT: Setting up Update Listener...'); 
    // REMOVED TYPE ANNOTATION to avoid potential runtime cast errors
    updates.listen((c) {
      if (c == null || c.isEmpty) return;
      print('MQTT: --> Batch received. Count: ${c.length}');

      // Iterate through ALL messages in the batch
      for (final message in c) {
        final recMess = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          print('MQTT: Raw Payload: $payload');
          final Map<String, dynamic> data = jsonDecode(payload);
          final String type = data['type'] ?? 'new_message';

          // Always notify the UI via background service bridge
          _backgroundService?.invoke('onMessage', data);
          _messageStreamController.add(data);

          // ONLY show physical system notification for new messages
          if (type == 'new_message') {
            final String sender = data['sender'] ?? "New Message";
            final String content = data['content'] ?? "";
            final int senderId = int.tryParse(data['sender_id'].toString()) ?? -1;

            // Don't show notification if I sent it myself
            // Check for -1 to ensure we don't skip system messages (which might lack sender_id)
            if (_currentUserId != null && senderId != -1 && senderId == _currentUserId) {
              print('MQTT: Skipping notification for self-sent message');
              continue;
            }

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
      }
    });
  }

  void onConnected() {
    print('MQTT: Connected to $broker');
    
    if (_currentUserId != null) {
      final String userTopic = 'bishal_chat/user/$_currentUserId';
      client.subscribe(userTopic, MqttQos.atMostOnce);
      print('MQTT: Subscribed to $userTopic');
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
    _isListenerAttached = false; // Allow re-attaching if stream changes
  }

  void disconnect() {
    client.disconnect();
    _isListenerAttached = false;
    print('MQTT: Disconnected manually');
  }

  void onDisconnected() {
    print('MQTT: Disconnected');
    _isListenerAttached = false;
  }
}
