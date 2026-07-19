/// Background morning-summary job. Runs in a headless WorkManager isolate so the
/// briefing is delivered even on days the app isn't opened. The isolate has no Riverpod,
/// so it reopens the encrypted store directly, computes the summary, and posts a local
/// notification.
///
/// Reliability caveat: WorkManager periodic tasks run at OS discretion (≥15-min
/// granularity, deferred under Doze). The foreground path (AppJobs.maybeShowMorningSummary)
/// remains the primary trigger; this is the backstop.
library;

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart';

import '../analytics/context_builder.dart';
import '../analytics/metrics.dart';
import '../core/local_timezone.dart';
import '../data/database.dart';
import '../data/history_repository.dart';
import '../data/secure_key.dart';
import '../ml/sensitivity_model.dart';
import 'morning_summary.dart';
import '../alerts/headless_alert_watch.dart';
import '../data/kv_store.dart';
import 'alert_monitor.dart';
import 'notification_prefs.dart';
import 'notifications.dart';
import 'weekly_digest.dart';

const _summaryTask = 'bgdude.morning-summary';

/// Issues #51 / #28 stage 3: headless forecast-based alerting, so a predicted low is
/// still caught when Android has evicted the app.
const _alertWatchTask = 'bgdude.alert-watch';

// Key names live on AlertWatchStore so the foreground app and this isolate cannot
// drift apart on them.

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _alertWatchTask) return _runAlertWatch();
    if (task != _summaryTask) return true;
    try {
      final now = DateTime.now();
      if (now.hour < 6 || now.hour > 11) return true; // morning window only

      tzdata.initializeTimeZones();
      // TASK-175: each isolate has its own tz.local; without this the isolate
      // schedules in UTC.
      await configureLocalTimezone();
      final notifications = NotificationService();
      await notifications.init();

      final keys = await SecureKeyStore.open();
      final db = AppDatabase(openEncryptedDatabase(keys.getOrCreatePassphrase()));
      final repo = DriftHistoryRepository(db);

      final from = now.subtract(const Duration(hours: 24));
      final cgm = await repo.cgm(from, now);
      if (cgm.length >= 12) {
        final overnight = const MetricsCalculator()
            .compute([for (final s in cgm) if (s.time.hour < 7) s]);
        // 14-day baseline LBGI for the daily hypo-risk score (§4-2.2). Needs at least a
        // day of data; 0 disables the vs-baseline comparison.
        final baselineCgm =
            await repo.cgm(now.subtract(const Duration(days: 14)), now);
        final baselineLbgi = baselineCgm.length >= 288
            ? const MetricsCalculator().compute(baselineCgm).lbgi
            : 0.0;
        final features = ContextBuilder.build(
          today: await repo.health(from, now),
          baseline: await repo.health(now.subtract(const Duration(days: 14)), now),
        );
        if (features != null) {
          final summary = const MorningSummaryGenerator().generate(
            date: now,
            overnightMetrics: overnight,
            context: features,
            sensitivity: heuristicSensitivity(features),
            baselineLbgi: baselineLbgi,
          );
          final body = [for (final i in summary.insights.take(3)) '• ${i.detail}']
              .join('\n');
          await notifications.showMorningSummary(summary.headline, body);
        }

        // Weekly digest (§4-4.5): once a week (Monday morning) summarise this week vs
        // last, reusing the 14-day CGM pull.
        if (now.weekday == DateTime.monday) {
          final weekAgo = now.subtract(const Duration(days: 7));
          final twoWeeksAgo = now.subtract(const Duration(days: 14));
          final thisWeek = const MetricsCalculator().compute(
              [for (final s in baselineCgm) if (!s.time.isBefore(weekAgo)) s]);
          final lastWeek = const MetricsCalculator().compute([
            for (final s in baselineCgm)
              if (s.time.isBefore(weekAgo) && !s.time.isBefore(twoWeeksAgo)) s
          ]);
          final digest = const WeeklyDigestGenerator()
              .generate(thisWeek: thisWeek, lastWeek: lastWeek);
          if (digest != null) {
            await notifications.showWeeklyDigest(digest.headline, digest.body);
          }
        }
      }
      await db.close();
    } catch (_) {
      // Never fail the task hard; try again next window.
    }
    return true;
  });
}

/// The headless alert pass (issues #51 / #28).
///
/// Deliberately conservative: it opens the database, evaluates the SAME pure core the
/// foreground uses, and posts at most one notification. Any failure returns true rather
/// than throwing — a background task that fails hard gets backed off by WorkManager, and
/// an alerting safety net that WorkManager has stopped scheduling is worse than useless
/// because nobody would notice.
Future<bool> _runAlertWatch() async {
  try {
    tzdata.initializeTimeZones();
    await configureLocalTimezone();

    final keys = await SecureKeyStore.open();
    final db = AppDatabase(openEncryptedDatabase(keys.getOrCreatePassphrase()));
    try {
      KvStore.init(db);
      final now = DateTime.now();

      final beatRaw = await KvStore.getString(AlertWatchStore.foregroundBeatKey);
      final beat = AlertWatchStore.decodeBeat(beatRaw);
      if (!shouldEvaluateHeadless(
          lastForegroundEvaluation: beat, now: now)) {
        return true;
      }

      final repo = DriftHistoryRepository(db);
      final cgm = await repo.cgm(now.subtract(const Duration(hours: 1)), now);
      final readings = [
        for (final s in cgm)
          if (!s.sensorWarmup && !s.isCalibration && s.mgdl > 0)
            (time: s.time, mgdl: s.mgdl.value),
      ];

      final fireLog = AlertFireLog.decode(
          await KvStore.getString(AlertWatchStore.fireLogKey));
      final alert = evaluateHeadless(
        readings: readings,
        fireLog: fireLog,
        now: now,
        lastForegroundEvaluation: beat,
      );
      if (alert == null) return true;

      final notifications = NotificationService();
      await notifications.init();
      await notifications.show(
        _categoryFor(alert.kind),
        alert.title,
        alert.body,
      );

      // Record the fire BEFORE returning so the next pass — and the foreground app —
      // both see the cooldown.
      await KvStore.setString(
        AlertWatchStore.fireLogKey,
        fireLog.withFired(alert.kind, now).encode(),
      );
    } finally {
      await db.close();
    }
  } catch (_) {
    // Try again next cycle.
  }
  return true;
}

/// Maps an alert kind onto its notification category, so the user's per-category
/// preferences and quiet hours apply to a headless alert exactly as they do to a
/// foreground one — a background pass must not become a way to bypass them.
NotificationCategory _categoryFor(GlucoseAlertKind kind) => switch (kind) {
      GlucoseAlertKind.urgentLow => NotificationCategory.urgentLow,
      GlucoseAlertKind.predictedLow => NotificationCategory.predictedLow,
      GlucoseAlertKind.predictedHigh => NotificationCategory.predictedHigh,
    };

/// Register the periodic background summary. Call once after onboarding.
Future<void> registerBackgroundSummary() async {
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _summaryTask,
    _summaryTask,
    frequency: const Duration(hours: 6),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  // 15 minutes is WorkManager's floor for periodic work. Coarser than the app's own
  // 5-minute cadence, and far better than nothing once the app has been evicted.
  await Workmanager().registerPeriodicTask(
    _alertWatchTask,
    _alertWatchTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.notRequired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
