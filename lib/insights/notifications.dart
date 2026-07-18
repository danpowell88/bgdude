/// Category-aware notifications. Each [NotificationCategory] has its own Android channel
/// whose importance / sound / vibration come from the user's [NotificationPrefs], so
/// alerts can be opted in/out and tuned for intensity. Repeated-alert timing is handled
/// by the caller (AlertService) using each category's `repeatMinutes`.
///
/// All alerts are *additive* to the pump/CGM's own alarms — never a replacement.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../logging/app_log.dart';
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
          id: morningSummaryId, bigText: true);

  /// The weekly digest (§4-4.5). TASK-145: routed through the reportDigest
  /// category (so ITS prefs toggle gates it, as the settings screen claims) with
  /// id 1003 — 1002 collided with the scheduled weekly-report nudge and the two
  /// silently replaced each other in the tray.
  Future<void> showWeeklyDigest(String headline, String body) =>
      show(NotificationCategory.reportDigest, headline, body,
          id: weeklyDigestId, bigText: true);

  /// Fixed notification ids for the scheduled/summary surfaces — must stay
  /// distinct or Android replaces one with the other (TASK-145).
  static const int dailySummaryId = 1000;
  static const int morningSummaryId = 1001;
  static const int weeklyReportNudgeId = 1002;
  static const int weeklyDigestId = 1003;

  /// Next wall-clock [hour]:[minute] in [now]'s location, strictly ahead of [now].
  /// Pure and location-aware (TASK-175); constructing tomorrow via `day + 1` (not
  /// `+24h`) keeps the wall-clock hour across a DST transition.
  static tz.TZDateTime nextDailyInstant(tz.TZDateTime now, int hour, int minute) {
    var scheduled =
        tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(
          now.location, now.year, now.month, now.day + 1, hour, minute);
    }
    return scheduled;
  }

  /// Next [weekday] (1=Mon..7=Sun) at [hour]:00 in [now]'s location, strictly
  /// ahead of [now]. Day arithmetic, so DST-safe like [nextDailyInstant].
  static tz.TZDateTime nextWeeklyInstant(tz.TZDateTime now, int weekday, int hour) {
    var days = 0;
    var scheduled = tz.TZDateTime(now.location, now.year, now.month, now.day, hour);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      days += 1;
      scheduled =
          tz.TZDateTime(now.location, now.year, now.month, now.day + days, hour);
    }
    return scheduled;
  }

  /// Schedule the daily summary reminder at [hour]:[minute] local.
  Future<void> scheduleDailySummary({int hour = 7, int minute = 0}) async {
    final scheduled = nextDailyInstant(tz.TZDateTime.now(tz.local), hour, minute);
    await _plugin.zonedSchedule(
      dailySummaryId,
      'Preparing your morning summary…',
      '',
      scheduled,
      _details(NotificationCategory.morningSummary,
          _prefs.of(NotificationCategory.morningSummary)),
      androidScheduleMode: summaryScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule a weekly "your report is ready" nudge on [weekday] (1=Mon..7=Sun) at
  /// [hour]:00 local. Opting out via the reportDigest category disables the channel.
  Future<void> scheduleWeeklyReport({int weekday = DateTime.monday, int hour = 8}) async {
    final scheduled =
        nextWeeklyInstant(tz.TZDateTime.now(tz.local), weekday, hour);
    await _plugin.zonedSchedule(
      weeklyReportNudgeId,
      'Your weekly report is ready',
      'Tap to review your glucose, insulin and trends from the past week.',
      scheduled,
      _details(NotificationCategory.reportDigest,
          _prefs.of(NotificationCategory.reportDigest)),
      androidScheduleMode: summaryScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Summaries/nudges tolerate Doze slack — they stay inexact (TASK-182).
  static const AndroidScheduleMode summaryScheduleMode =
      AndroidScheduleMode.inexactAllowWhileIdle;

  /// The pre-bolus timer's mode: EXACT when the exact-alarm permission is
  /// granted, else the inexact fallback (Android 14 denies SCHEDULE_EXACT_ALARM
  /// by default for new installs). Pure so tests pin the mode per path.
  static AndroidScheduleMode preBolusScheduleMode({required bool canExact}) =>
      canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

  /// TASK-239: whether the OS currently allows exact-alarm scheduling — the
  /// same check [schedulePreBolusTimer] gates on, exposed so a Settings tile
  /// can show the current state without having to schedule a real timer.
  Future<bool> canScheduleExactAlarms() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  /// Whether the OS will actually deliver this app's notifications (issue #376).
  ///
  /// Every alert this app raises — including urgent lows — is a notification, so a
  /// denied or later-revoked `POST_NOTIFICATIONS` grant silently disables the entire
  /// alerting surface. [init] requests the permission once, but nothing read the
  /// answer, so a refusal was indistinguishable from working normally.
  ///
  /// Defaults to **true** when the platform can't say (non-Android, or no plugin
  /// implementation registered): a warning shown on a platform that simply doesn't
  /// report the state would be crying wolf, and this drives a prominent warning.
  ///
  /// Must never throw. It is called from a widget's `initState` to decide whether to
  /// show that warning, so an exception here is an unhandled async error in Settings
  /// rather than a missing row. `resolvePlatformSpecificImplementation` throws a
  /// `LateError` — not a `MissingPluginException` — when no platform implementation
  /// is registered, which is why this catches broadly rather than a specific type.
  Future<bool> areNotificationsEnabled() async {
    try {
      return await _android?.areNotificationsEnabled() ?? true;
    } catch (e) {
      appLog.info('alerts', 'notification-enabled state unavailable: $e');
      return true;
    }
  }

  /// Re-request the notification permission. Android only shows the system dialog
  /// while the grant is still askable; after a permanent denial this resolves without
  /// any UI, which is why the caller re-checks [areNotificationsEnabled] and keeps
  /// pointing at system settings when it stays false.
  Future<void> requestNotificationsPermission() async {
    await _android?.requestNotificationsPermission();
  }

  /// Opens the system's exact-alarm settings screen for this app (Android 12+
  /// requires navigating there — unlike most permissions there is no simple
  /// runtime consent dialog). Returns whatever the plugin reports; the caller
  /// re-checks [canScheduleExactAlarms] on return since the OS doesn't fire a
  /// callback when the user grants/denies from that screen.
  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  /// Schedule a one-shot pre-bolus timer that survives the app being backgrounded.
  /// TASK-182: in Doze an inexact alarm can fire 30–40 min late — a pre-bolus
  /// timer that fires after the meal is useless, so this one path asks for
  /// exact-alarm semantics (gated on the runtime permission).
  Future<void> schedulePreBolusTimer(Duration lead, String mealName) async {
    final when = tz.TZDateTime.now(tz.local).add(lead);
    final canExact =
        await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      3000,
      'Time to eat',
      '${lead.inMinutes} min pre-bolus for $mealName is up — enjoy.',
      when,
      _details(NotificationCategory.preBolusTimer,
          _prefs.of(NotificationCategory.preBolusTimer)),
      androidScheduleMode: preBolusScheduleMode(canExact: canExact),
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
