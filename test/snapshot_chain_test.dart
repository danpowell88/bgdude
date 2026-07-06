/// TASK-125: the app-root snapshot chain must keep alerting when ingest fails, and
/// best-effort background pushes must log instead of raising unhandled async errors.
library;

import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/state/snapshot_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(appLog.clear);

  group('ingestThenEvaluateAlerts', () {
    test('runs ingest then alerts, in order, on success', () async {
      final calls = <String>[];
      await ingestThenEvaluateAlerts(
        ingest: () async => calls.add('ingest'),
        evaluateAlerts: () async => calls.add('alerts'),
      );
      expect(calls, ['ingest', 'alerts']);
    });

    test('an ingest failure is logged and alerts STILL run', () async {
      var alertsRan = false;
      await ingestThenEvaluateAlerts(
        ingest: () async => throw StateError('db locked'),
        evaluateAlerts: () async => alertsRan = true,
      );
      expect(alertsRan, isTrue);
      final logged = appLog.entries
          .where((e) => e.level == LogLevel.error && e.tag == 'snapshot');
      expect(logged, hasLength(1));
      expect(logged.single.message, contains('ingest failed'));
    });

    test('an alert-evaluation failure is logged, not propagated', () async {
      await ingestThenEvaluateAlerts(
        ingest: () async {},
        evaluateAlerts: () async => throw StateError('boom'),
      );
      final logged = appLog.entries
          .where((e) => e.level == LogLevel.error && e.tag == 'alerts');
      expect(logged, hasLength(1));
    });
  });

  group('unawaitedLogged', () {
    test('a failing background push is logged instead of unhandled', () async {
      unawaitedLogged(
          Future<void>.error(StateError('offline')), 'nightscout', 'push failed');
      // Let the microtask queue drain so the catchError runs.
      await Future<void>.delayed(Duration.zero);
      final logged = appLog.entries
          .where((e) => e.level == LogLevel.error && e.tag == 'nightscout');
      expect(logged, hasLength(1));
      expect(logged.single.message, 'push failed');
    });

    test('a successful push logs nothing', () async {
      unawaitedLogged(Future<void>.value(), 'nightscout', 'push failed');
      await Future<void>.delayed(Duration.zero);
      expect(appLog.entries, isEmpty);
    });
  });
}
