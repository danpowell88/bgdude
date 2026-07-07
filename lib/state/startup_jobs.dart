/// Structured startup pipeline (TASK-123). `AppJobs.runStartup` used to be 12
/// sequential steps each in `try{}catch(_){}` — implicit ordering, no aggregated
/// outcome, a broken migration invisible. Here the jobs are an explicit ordered
/// list; each is logged individually and the whole run is summarised into the
/// on-device diagnostics log.
library;

import '../logging/app_log.dart';

class StartupJob {
  const StartupJob(this.name, this.run, {this.enabled = true});

  final String name;
  final Future<void> Function() run;

  /// False disables the job for this run (e.g. hardware-only jobs in demo mode);
  /// it is reported as skipped rather than silently absent.
  final bool enabled;
}

class StartupJobResult {
  const StartupJobResult({
    required this.name,
    required this.ok,
    this.skipped = false,
    this.error,
    this.elapsed = Duration.zero,
  });

  final String name;
  final bool ok;
  final bool skipped;
  final Object? error;
  final Duration elapsed;
}

class StartupReport {
  const StartupReport(this.results);

  final List<StartupJobResult> results;

  Iterable<StartupJobResult> get failures =>
      results.where((r) => !r.ok && !r.skipped);

  bool get allOk => failures.isEmpty;

  /// One-line summary for the diagnostics log.
  String summary() {
    final ran = results.where((r) => !r.skipped).length;
    final skipped = results.length - ran;
    final failed = failures.map((r) => r.name).toList();
    return 'startup: $ran jobs ran'
        '${skipped > 0 ? ', $skipped skipped' : ''}'
        '${failed.isEmpty ? ', all ok' : ', FAILED: ${failed.join(', ')}'}';
  }
}

/// Run [jobs] in their list order. Every job is best-effort — one failing must
/// not abort the rest — but each failure is logged loudly with the job name and
/// carried in the returned [StartupReport].
Future<StartupReport> runStartupJobs(List<StartupJob> jobs) async {
  final results = <StartupJobResult>[];
  for (final j in jobs) {
    if (!j.enabled) {
      results.add(StartupJobResult(name: j.name, ok: true, skipped: true));
      continue;
    }
    final sw = Stopwatch()..start();
    try {
      await j.run();
      results.add(
          StartupJobResult(name: j.name, ok: true, elapsed: sw.elapsed));
    } catch (e) {
      appLog.error('startup', 'job "${j.name}" failed', error: e);
      results.add(StartupJobResult(
          name: j.name, ok: false, error: e, elapsed: sw.elapsed));
    }
  }
  final report = StartupReport(results);
  if (report.allOk) {
    appLog.info('startup', report.summary());
  } else {
    appLog.warn('startup', report.summary());
  }
  return report;
}
