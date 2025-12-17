import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A service class for handling local notifications (device-only).
/// - Android focused
/// - Respects Firestore setting: users/{uid}.pushNotifications (default true)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: null, // Android only
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  /// Android 13+ runtime permission (safe to call on older versions)
  Future<bool> requestAndroidNotificationPermissionIfNeeded() async {
    await init();

    final androidImpl =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final result = await androidImpl?.requestNotificationsPermission();
    return result ?? true; // plugin/version may return null
  }

  /// Read user's pushNotifications setting from Firestore.
  /// Default true if missing.
  Future<bool> isPushEnabled() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final enabled = (doc.data()?['pushNotifications'] as bool?) ?? true;
      return enabled;
    } catch (_) {
      // If Firestore fails, don't spam the user; treat as disabled
      return false;
    }
  }

  /// Only show notification if Firestore pushNotifications is enabled.
  Future<void> showIfEnabled(String title, String body) async {
    await init();

    final enabled = await isPushEnabled();
    if (!enabled) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'kiosk_status_channel',
      'Kiosk Status',
      channelDescription: 'Notifications for kiosk status updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
    );
  }
}
