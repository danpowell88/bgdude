/// Startup notification setup, individually guarded (TASK-180). A plugin/channel
/// init throw on an OEM ROM used to happen BEFORE runApp with no catch —
/// crash-looping the whole app (no UI, no alerts, no service). Notification
/// scheduling is a nice-to-have at startup; it must never prevent booting.
library;

import '../logging/app_log.dart';
import 'notifications.dart';

/// Run every notification startup step, each in its own guard, logging failures.
/// ALWAYS completes normally so `main()` reaches `runApp` no matter what throws.
Future<void> bootstrapNotifications(
  NotificationService notifications, {
  Future<void> Function()? registerBackground,
}) async {
  Future<void> step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      appLog.error('notifications', 'startup "$name" failed — continuing boot',
          error: e);
    }
  }

  await step('init', notifications.init);
  await step('scheduleDailySummary',
      () => notifications.scheduleDailySummary(hour: 7));
  await step('scheduleWeeklyReport', notifications.scheduleWeeklyReport);
  if (registerBackground != null) {
    await step('registerBackgroundSummary', registerBackground);
  }
}
