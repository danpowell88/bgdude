/// TASK-180: notification startup must never brick boot. Every step is guarded
/// individually — a throwing init is logged, the remaining steps still run, and
/// the bootstrap completes so main() reaches runApp.
library;

import 'package:bgdude/insights/notification_bootstrap.dart';
import 'package:bgdude/insights/notifications.dart';
import 'package:bgdude/logging/app_log.dart';
import 'package:flutter_test/flutter_test.dart';

class _ExplodingInitService extends NotificationService {
  bool dailyScheduled = false;
  bool weeklyScheduled = false;

  @override
  Future<void> init() async => throw StateError('OEM channel init exploded');

  @override
  Future<void> scheduleDailySummary({int hour = 7, int minute = 0}) async {
    dailyScheduled = true;
  }

  @override
  Future<void> scheduleWeeklyReport(
      {int weekday = DateTime.monday, int hour = 8}) async {
    weeklyScheduled = true;
  }
}

class _AllExplodingService extends NotificationService {
  @override
  Future<void> init() async => throw StateError('boom');
  @override
  Future<void> scheduleDailySummary({int hour = 7, int minute = 0}) async =>
      throw StateError('boom');
  @override
  Future<void> scheduleWeeklyReport(
          {int weekday = DateTime.monday, int hour = 8}) async =>
      throw StateError('boom');
}

void main() {
  setUp(appLog.clear);

  test('a throwing init is logged and the later steps still run', () async {
    final service = _ExplodingInitService();
    var backgroundRegistered = false;

    // Completing normally IS the boot guarantee — runApp follows this call
    // unconditionally in main().
    await bootstrapNotifications(service, registerBackground: () async {
      backgroundRegistered = true;
    });

    expect(service.dailyScheduled, isTrue);
    expect(service.weeklyScheduled, isTrue);
    expect(backgroundRegistered, isTrue);
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.error &&
            e.tag == 'notifications' &&
            e.message.contains('"init" failed')),
        isTrue);
  });

  test('even every step throwing cannot break the boot path', () async {
    await bootstrapNotifications(_AllExplodingService(),
        registerBackground: () async => throw StateError('boom'));
    expect(
        appLog.entries
            .where((e) => e.level == LogLevel.error && e.tag == 'notifications'),
        hasLength(4));
  });
}
