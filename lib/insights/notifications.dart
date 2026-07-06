/// Category-aware notifications. Each [NotificationCategory] has its own Android channel
/// whose importance / sound / vibration come from the user's [NotificationPrefs], so
/// alerts can be opted in/out and tuned for intensity. Repeated-alert timing is handled
/// by the caller (AlertService) using each category's `repeatMinutes`.
///
/// All alerts are *additive* to the pump/CGM's own alarms — never a replacement.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_prefs.dart';

class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPrefs? prefs,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _prefs = prefs ?? NotificationPrefs.defaults();

  final FlutterLocalNotificationsPlugin _plugin;
  NotificationPrefs _prefs;

  NotificationPrefs get prefs => _prefs;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    await _createChannels();
    await _android?.requestNotificationsPermission();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Apply updated preferences: channels are recreated so importance/sound/vibration
  /// changes take effect (Android channel settings are fixed at creation).
  Future<void> applyPrefs(NotificationPrefs prefs) async {
    _prefs = prefs;
    for (final c in NotificationCategory.values) {
      await _android?.deleteNotificationChannel(c.name);
    }
    await _createChannels();
  }

  Future<void> _createChannels() async {
    for (final c in NotificationCategory.values) {
      final p = _prefs.of(c);
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        c.name,
        c.label,
        description: c.description,
        importance: _importance(p.importance),
        playSound: p.sound,
        enableVibration: p.vibrate,
      ));
    }
  }

  /// Show a notification for [category], respecting its enabled state and style.
  /// Returns true if it fired (false if the category is opted out).
  Future<bool> show(
    NotificationCategory category,
    String title,
    String body, {
    int? id,
    bool bigText = false,
  }) async {
    final p = _prefs.of(category);
    if (!p.enabled) return false;
    // Hold back non-critical notifications during quiet hours (urgent lows still fire).
    if (_prefs.quietHours.activeAt(DateTime.now()) &&
        !category.bypassesQuietHours) {
      return false;
    }
    await _plugin.show(
      id ?? 2000 + category.index,
      title,
      body,
      _details(category, p, bigText: bigText),
    );
    return true;
  }

  Future<void> showMorningSummary(String headline, String body) =>
      show(NotificationCategory.morningSummary, headline, body,
          id: 1001, bigText: true);

  /// The weekly digest (§4-4.5) — shares the morning-summary opt-in/quiet settings but a
  /// distinct id so it doesn't clobber the daily summary.
  Future<void> showWeeklyDigest(String headline, String body) =>
      show(NotificationCategory.morningSummary, headline, body,
          id: 1002, bigText: true);

  /// Schedule the daily summary reminder at [hour]:[minute] local.
  Future<void> scheduleDailySummary({int hour = 7, int minute = 0}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      1000,
      'Preparing your morning summary…',
      '',
      scheduled,
      _details(NotificationCategory.morningSummary,
          _prefs.of(NotificationCategory.morningSummary)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule a weekly "your report is ready" nudge on [weekday] (1=Mon..7=Sun) at
  /// [hour]:00 local. Opting out via the reportDigest category disables the channel.
  Future<void> scheduleWeeklyReport({int weekday = DateTime.monday, int hour = 8}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      1002,
      'Your weekly report is ready',
      'Tap to review your glucose, insulin and trends from the past week.',
      scheduled,
      _details(NotificationCategory.reportDigest,
          _prefs.of(NotificationCategory.reportDigest)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Schedule a one-shot pre-bolus timer that survives the app being backgrounded.
  Future<void> schedulePreBolusTimer(Duration lead, String mealName) async {
    final when = tz.TZDateTime.now(tz.local).add(lead);
    await _plugin.zonedSchedule(
      3000,
      'Time to eat',
      '${lead.inMinutes} min pre-bolus for $mealName is up — enjoy.',
      when,
      _details(NotificationCategory.preBolusTimer,
          _prefs.of(NotificationCategory.preBolusTimer)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  NotificationDetails _details(NotificationCategory category, CategoryPref p,
          {bool bigText = false}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          category.name,
          category.label,
          channelDescription: category.description,
          importance: _importance(p.importance),
          priority: _priority(p.importance),
          playSound: p.sound,
          enableVibration: p.vibrate,
          styleInformation: bigText ? const BigTextStyleInformation('') : null,
        ),
      );

  static Importance _importance(NotifImportance i) => switch (i) {
        NotifImportance.silent => Importance.min,
        NotifImportance.low => Importance.low,
        NotifImportance.normal => Importance.defaultImportance,
        NotifImportance.high => Importance.high,
        NotifImportance.urgent => Importance.max,
      };

  static Priority _priority(NotifImportance i) => switch (i) {
        NotifImportance.silent => Priority.min,
        NotifImportance.low => Priority.low,
        NotifImportance.normal => Priority.defaultPriority,
        NotifImportance.high => Priority.high,
        NotifImportance.urgent => Priority.max,
      };
}
