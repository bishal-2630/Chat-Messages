import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    print('NotificationService: Starting initialization...');
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    try {
      await _notificationsPlugin.initialize(initializationSettings);
      
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      print('NotificationService: Initialization COMPLETE, permissions requested');
    } catch (e) {
      print('NotificationService: CRITICAL INITIALIZATION ERROR: $e');
    }
  }

  static Future<void> showNotification(String title, String body) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages_v5',
      'Chat Messages',
      channelDescription: 'New message alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: 'ic_launcher',
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    // Unique ID based on timestamp to avoid overwriting previous notifications
    int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    print('NotificationService: ATTEMPTING to show notification: id=$id, title=$title');
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
      );
      print('NotificationService: PLUGIN.SHOW() call completed successfully');
    } catch (e) {
      print('NotificationService: PLUGIN.SHOW() FAILED: $e');
    }
  }
}
