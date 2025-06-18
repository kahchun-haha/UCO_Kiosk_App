import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A service class for handling local notifications.
class NotificationService {
  // A singleton instance of the NotificationService.
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification service.
  ///
  /// This method sets up the platform-specific initialization settings
  /// for Android and requests notification permissions on iOS.
  Future<void> init() async {
    // Android-specific initialization settings.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization settings for all platforms.
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: null, // Set to null as we are focusing on Android
    );

    // Initialize the plugin with the settings.
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  /// Displays a notification with the given [title] and [body].
  Future<void> showNotification(String title, String body) async {
    // Android-specific notification details.
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'kiosk_status_channel', // A unique channel ID.
      'Kiosk Status', // A channel name to be displayed to the user.
      channelDescription:
          'Notifications for kiosk status updates', // A description for the channel.
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    // Platform-specific notification details.
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show the notification.
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
