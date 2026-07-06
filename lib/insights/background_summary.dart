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
import 'notifications.dart';
import 'weekly_digest.dart';

const _summaryTask = 'bgdude.morning-summary';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
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
}
