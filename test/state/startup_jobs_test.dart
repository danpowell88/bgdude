/// The startup pipeline runs every job in order, survives a failing
/// job, records the failure, and summarises the run into the diagnostics log.
library;

import 'package:bgdude/logging/app_log.dart';
import 'package:bgdude/state/startup_jobs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(appLog.clear);

  test('jobs run in list order', () async {
    final order = <String>[];
    await runStartupJobs([
      StartupJob('a', () async => order.add('a')),
      StartupJob('b', () async => order.add('b')),
      StartupJob('c', () async => order.add('c')),
    ]);
    expect(order, ['a', 'b', 'c']);
  });

  test('a failing job does not stop the rest and is recorded + logged', () async {
    final order = <String>[];
    final report = await runStartupJobs([
      StartupJob('first', () async => order.add('first')),
      StartupJob('broken', () async => throw StateError('migration exploded')),
      StartupJob('last', () async => order.add('last')),
    ]);
    expect(order, ['first', 'last'],
        reason: 'jobs after the failure must still run');
    expect(report.allOk, isFalse);
    expect(report.failures.single.name, 'broken');
    expect(report.failures.single.error, isA<StateError>());
    // The failure is loud in the log, and the summary names the failed job.
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.error &&
            e.tag == 'startup' &&
            e.message.contains('broken')),
        isTrue);
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.warn && e.message.contains('FAILED: broken')),
        isTrue);
  });

  test('disabled jobs are reported as skipped, not silently absent', () async {
    final report = await runStartupJobs([
      StartupJob('hardware-only', () async => fail('must not run'),
          enabled: false),
      StartupJob('normal', () async {}),
    ]);
    expect(report.allOk, isTrue);
    expect(report.results.first.skipped, isTrue);
    expect(report.summary(), contains('1 skipped'));
  });

  test('an all-ok run logs an info summary', () async {
    await runStartupJobs([StartupJob('only', () async {})]);
    expect(
        appLog.entries.any((e) =>
            e.level == LogLevel.info && e.message.contains('all ok')),
        isTrue);
  });
}
