import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'System Connectivity v5', 
    'System Connectivity',
    description: 'Maintains background system connectivity.',
    importance: Importance.min, // Min importance to hide icon from status bar
  );

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages_v6',
    'Message Alerts',
    description: 'Real-time chat alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);
  await androidPlugin?.createNotificationChannel(chatChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'System Connectivity v5',
      initialNotificationTitle: 'System Sync',
      initialNotificationContent: 'Active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
  
  print('Background service: [onStart v7] triggered');
  WakelockPlus.enable();
  DartPluginRegistrant.ensureInitialized();
  try {
    await NotificationService.initialize(isBackground: true);
    print('Background service: [v7] NotificationService initialized for Background');
  } catch (e) {
    print('Background service: [v7] Notification initialization failed: $e');
  }

  // --- BRIDGE TEST HEARTBEAT ---
  Timer.periodic(const Duration(seconds: 30), (timer) {
    print('Background: [v7] Sending BRIDGE PING to UI...');
    service.invoke('onMessage', {'type': 'bridge_ping', 'timestamp': DateTime.now().toIso8601String()});
  });

  MqttService? mqttService;
  bool isConnecting = false;

  Future<void> startMqtt() async {
    if (isConnecting) {
      print('Background: Already connecting, skipping redundant start.');
      return;
    }
    
    isConnecting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // FORCED RELOAD for cross-isolate sync
      final userId = prefs.getInt('user_id') ?? 0;
      
      if (userId != 0) {
        print('Background Isolate: [v7] Starting MQTT for user $userId (Synced)');
        mqttService?.disconnect(); // Disconnect existing if any
        mqttService = MqttService();
        print('Background Isolate: [v7] Calling mqttService.initialize...');
        await mqttService!.initialize(userId, service);
        print('Background Isolate: [v7] mqttService.initialize COMPLETED.');
      } else {
        print('Background: No User ID found, cannot start MQTT.');
      }
    } catch (e) {
      print('Background: CRITICAL error in startMqtt: $e');
    } finally {
      isConnecting = false;
      print('Background: [v7] startMqtt finished (isConnecting=false).');
    }
  }

  // Small delay at startup to let SharedPreferences stabilize from main isolate
  Timer(const Duration(seconds: 3), () {
    startMqtt();
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('refresh').listen((event) async {
       print('Background: Refreshing MQTT connection...');
       await startMqtt();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('setActiveChat').listen((event) {
    final int? otherId = event?['userId'];
    print('Background: Setting Active Chat to $otherId');
    mqttService?.activeChatUserId = otherId;
  });

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    print('Background service Heartbeat: Active');
  });

  // CONNECTION WATCHDOG: Check every 10s for stability
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (isConnecting) return; // Busy, skip this cycle
    
    if (mqttService != null) {
      if (!mqttService!.isConnected) {
        print('Watchdog: MQTT connection LOST. Re-initializing...');
        await startMqtt();
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;
      if (userId != 0) {
        print('Watchdog: MQTT service found NULL. Auto-starting...');
        await startMqtt();
      }
    }
  });
}
