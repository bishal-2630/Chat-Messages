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
    'System Connectivity', 
    'System Connectivity',
    description: 'Maintains background system connectivity.',
    importance: Importance.low, // Keep it silent but alive
  );

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_messages_v3',
    'Chat Messages',
    description: 'High priority notifications for new chat messages',
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
      notificationChannelId: 'my_foreground_v3',
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
  WakelockPlus.enable();
  DartPluginRegistrant.ensureInitialized();
  await NotificationService.initialize();

  MqttService? mqttService;

  Future<void> startMqtt() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 0;
    print('Background: Starting MQTT for user $userId');

    if (userId != 0) {
      mqttService?.disconnect(); // Disconnect existing if any
      mqttService = MqttService();
      await mqttService!.initialize(userId,service);
    }
  }

  await startMqtt();

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
}
