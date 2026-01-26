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
    importance: Importance.low, 
  );

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages_v5',
    'Chat Channel',
    description: 'New chat message notifications',
    importance: Importance.max,
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
      foregroundServiceIconName: 'ic_launcher', // Explicitly set icon
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
  
  print('Background service: [onStart] triggered');
  WakelockPlus.enable();
  DartPluginRegistrant.ensureInitialized();
  try {
    await NotificationService.initialize();
    print('Background service: NotificationService initialized successfully');
  } catch (e) {
    print('Background service: Notification initialization failed: $e');
  }

  MqttService? mqttService;

  Future<void> startMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // FORCED RELOAD for cross-isolate sync
    final userId = prefs.getInt('user_id') ?? 0;
    print('Background Isolate: Starting MQTT for user $userId (Synced)');

    if (userId != 0) {
      mqttService?.disconnect(); // Disconnect existing if any
      mqttService = MqttService();
      await mqttService!.initialize(userId,service);
    }
  }

  // Small delay at startup to let SharedPreferences stabilize from main isolate
  Future.delayed(const Duration(seconds: 3), () async {
    await startMqtt();
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

  Timer.periodic(const Duration(minutes: 1), (timer) async {
    print('Background service running...');
  });

  // CONNECTION WATCHDOG: Check every 10s (Faster response to network drops)
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (mqttService != null) {
      if (!mqttService!.isConnected) {
        print('Watchdog: MQTT disconnected. Attempting restart...');
        await startMqtt();
      }
    } else {
      // If service is started but mqtt is null, try starting it
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;
      if (userId != 0) {
        print('Watchdog: MQTT service null but user logged in. Initializing...');
        await startMqtt();
      }
    }
  });
}
