import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize({
    bool isBackground = false,
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  }) async {
    print('NotificationService: Starting initialization (isBackground: $isBackground)...');
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
      
      // Permission requests MUST happen on the UI isolate (Activity context)
      if (!isBackground) {
        if (Platform.isAndroid) {
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
        }
        print('NotificationService: Initialization COMPLETE, permissions requested');
      } else {
        print('NotificationService: Initialization COMPLETE (background, no permission request)');
      }
    } catch (e) {
      print('NotificationService: INITIALIZATION ERROR: $e');
    }
  }

  static Future<void> showNotification(String title, String body, {String? payload}) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_messages_v6',
      'Message Alerts',
      channelDescription: 'Real-time chat alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.message,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    // Unique ID based on timestamp to avoid overwriting previous notifications
    int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    print('NotificationService: ATTEMPTING to show notification: id=$id, title=$title, payload=$payload');
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      print('NotificationService: PLUGIN.SHOW() call completed successfully');
    } catch (e) {
       print('NotificationService: ERROR showing notification: $e');
    }
  }
}
