import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static Future<void> initialize() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await _requestNotificationPermission();
    await _initializeLocalNotifications();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpened(initialMessage);
    }

    await _fetchFcmToken();
  }

  /// On iOS the FCM token cannot be minted until APNs has handed us a device
  /// token, so getToken() throws `apns-token-not-set` when called at startup.
  /// Poll briefly for the APNs token first, then ask for the FCM token.
  static Future<String?> _fetchFcmToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        // Notifications denied or APNs unreachable (e.g. Simulator) — no token.
        if (apnsToken == null) return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _requestNotificationPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Permissions are already requested through FirebaseMessaging above; asking
    // again here would be a second no-op prompt path on iOS.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // iOS already presents the incoming remote notification itself because of
    // setForegroundNotificationPresentationOptions(alert: true). Re-posting it
    // as a local notification would show the same alert twice.
    if (Platform.isIOS) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Notification',
      notification.body ?? '',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static void _handleMessageOpened(RemoteMessage message) {
    
  }
}
