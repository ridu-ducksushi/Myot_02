import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  try {
    // Initialize local notifications
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );
    await _localNotifications.initialize(initSettings);

    // FCM setup (will fail gracefully if Firebase not configured)
    final messaging = FirebaseMessaging.instance;
    
    // Request permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get token for debugging
    final token = await messaging.getToken();
    log('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

  } catch (e) {
    log('Notifications init failed (Firebase not configured?): $e');
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  const androidDetails = AndroidNotificationDetails(
    'default_channel',
    'Default',
    importance: Importance.max,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await _localNotifications.show(
    message.hashCode,
    message.notification?.title,
    message.notification?.body,
    details,
  );
}
