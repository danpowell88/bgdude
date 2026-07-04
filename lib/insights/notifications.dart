/// Notification + background scheduling. Two roles:
///   * the morning summary (scheduled daily via WorkManager, delivered as a local
///     notification), and
///   * real-time nudges (predicted low/high, connection lost) fired from the running app.
///
/// Real-time alerts are *additive* to the pump/CGM's own alarms — this never suppresses
/// or replaces them.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _summaryChannel = AndroidNotificationChannel(
    'morning_summary',
    'Morning summary',
    description: 'Your daily diabetes briefing',
    importance: Importance.defaultImportance,
  );

  static const _alertChannel = AndroidNotificationChannel(
    'glucose_alerts',
    'Glucose nudges',
    description: 'Predicted-low/high and connection alerts (additive to CGM alarms)',
    importance: Importance.high,
  );

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_summaryChannel);
    await android?.createNotificationChannel(_alertChannel);
    await android?.requestNotificationsPermission();
  }

  /// Show the generated morning summary immediately (called by the WorkManager job).
  Future<void> showMorningSummary(String headline, String body) async {
    await _plugin.show(
      1001,
      headline,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_summary',
          'Morning summary',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }

  /// Schedule the summary to be generated + shown at [hour]:[minute] local each day.
  /// The WorkManager task (registered in `main.dart`) does the generation; this schedules
  /// the fallback local notification time for reliability.
  Future<void> scheduleDailySummary({int hour = 7, int minute = 0}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      1000,
      'Preparing your morning summary…',
      '',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails('morning_summary', 'Morning summary'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Fire a real-time nudge (predicted low/high, connection lost). Additive to CGM alarms.
  Future<void> showNudge(String title, String body) async {
    await _plugin.show(
      2000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'glucose_alerts',
          'Glucose nudges',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
