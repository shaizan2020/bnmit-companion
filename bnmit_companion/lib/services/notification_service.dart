import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> showAttendanceAlert({
    required String subjectName,
    required double percentage,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'attendance_alerts',
      'Attendance Alerts',
      channelDescription: 'Notifications for low attendance warnings',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      subjectName.hashCode,
      '⚠️ Low Attendance Alert',
      '$subjectName: ${percentage.toStringAsFixed(1)}% — Below 75% threshold!',
      details,
    );
  }

  static Future<void> showShortageWarning(int count) async {
    const androidDetails = AndroidNotificationDetails(
      'attendance_alerts',
      'Attendance Alerts',
      channelDescription: 'Notifications for low attendance warnings',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      '📊 Attendance Warning',
      'You have $count subject${count > 1 ? 's' : ''} below 80% attendance. Check now!',
      details,
    );
  }
}
