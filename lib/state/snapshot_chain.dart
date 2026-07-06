/// The app-root per-snapshot safety chain (TASK-125). Persisting the reading and
/// evaluating alerts used to be chained with a bare `.then(...)` — one ingest
/// exception silently skipped alert evaluation for that snapshot. Here each stage
/// fails loudly (logged) and the alert evaluation ALWAYS runs, even when ingest
/// failed: alerting on a slightly stale day state beats not alerting at all.
library;

import 'dart:async';

import '../logging/app_log.dart';

/// Persist the snapshot via [ingest], then evaluate alerts via [evaluateAlerts].
/// Neither stage's failure propagates, and an ingest failure does not stop the
/// alert evaluation.
Future<void> ingestThenEvaluateAlerts({
  required Future<void> Function() ingest,
  required Future<void> Function() evaluateAlerts,
}) async {
  try {
    await ingest();
  } catch (e) {
    appLog.error('snapshot', 'ingest failed — alerts run on the previous day state',
        error: e);
  }
  try {
    await evaluateAlerts();
  } catch (e) {
    appLog.error('alerts', 'alert evaluation failed', error: e);
  }
}

/// Fire-and-forget a best-effort background [future] (e.g. a network push),
/// logging instead of surfacing an unhandled async error if it fails.
void unawaitedLogged(Future<void> future, String tag, String message) {
  unawaited(future.catchError((Object e) {
    appLog.error(tag, message, error: e);
  }));
}
