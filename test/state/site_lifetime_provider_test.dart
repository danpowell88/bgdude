/// TASK-152 (#166): siteLifetimeReportProvider wiring — proves the provider
/// feeds the builder ONLY `DeviceKind.site` changes (a sensor change logged
/// between the site change and a failure must not shorten the computed failure
/// age) and the report-range dataset, rather than re-testing the builder maths
/// (covered in test/reports/site_lifetime_report_test.dart).
library;

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/reports/report_dataset.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'only DeviceKind.site changes reach the builder — a later sensor change '
      'does not shorten the failure age', () async {
    KvStore.useMemory(); // DeviceChangeNotifier persists via KvStore
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 15);
    final range = ReportRange(from: from, to: to, preset: ReportPreset.custom);

    final siteChangedAt = DateTime(2026, 7, 3, 8);
    // Logged between the site change and the failure: if the provider passed
    // ALL device changes (not just .site), lastChangeBefore(failure) would be
    // this sensor change and the age would read 24 h, not 48 h.
    final sensorChangedAt = DateTime(2026, 7, 4, 8);
    final failureAt = siteChangedAt.add(const Duration(hours: 48));

    final container = ProviderContainer(overrides: [
      reportDatasetProvider.overrideWith((ref, r) async => ReportDataset(
            range: r,
            cgm: [
              // Day 1 of wear, in range -> tirBySetDay[1] == 1.0.
              CgmSample(
                  time: siteChangedAt.add(const Duration(hours: 2)),
                  mgdl: 110),
            ],
            boluses: const [],
            basal: const [],
            carbs: const [],
            health: const [],
            annotations: [
              Annotation(
                id: 'f1',
                kind: AnnotationKind.siteFailure,
                start: failureAt,
                end: failureAt.add(const Duration(hours: 1)),
              ),
              // A non-siteFailure annotation must not count as a failure.
              Annotation(
                id: 'x1',
                kind: AnnotationKind.exercise,
                start: siteChangedAt.add(const Duration(hours: 20)),
                end: siteChangedAt.add(const Duration(hours: 21)),
              ),
            ],
          )),
    ]);
    addTearDown(container.dispose);

    container.read(reportRangeProvider.notifier).state = range;

    // Create the notifier FIRST, then let its initial (empty-store) restore
    // settle, so that restore cannot land after the records below and wipe them.
    final device = container.read(deviceStateProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await device.record(DeviceKind.site, at: siteChangedAt);
    await device.record(DeviceKind.sensor, at: sensorChangedAt);

    // Keep the autoDispose provider alive while we await it.
    container.listen(siteLifetimeReportProvider, (_, __) {});
    final report = await container.read(siteLifetimeReportProvider.future);

    expect(report.failureAgesHours, [48.0],
        reason: 'age must be measured from the SITE change (48 h), not the '
            'later sensor change (24 h)');
    expect(report.tirBySetDay, {1: 1.0});
  });
}
