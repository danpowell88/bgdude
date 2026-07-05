import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/logging/device_changes.dart';
import 'package:bgdude/pump/pump_events.dart';
import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/reports/events_journal.dart';
import 'package:bgdude/reports/glucose_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/reports/therapy_report.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

void main() {
  group('EventsJournalBuilder', () {
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 8));
    const builder = EventsJournalBuilder();

    test('merges all sources newest-first and honours the range', () {
      final entries = builder.build(
        range: range,
        annotations: [
          Annotation(
            id: 'a',
            kind: AnnotationKind.exercise,
            start: DateTime(2026, 7, 3, 17),
            end: DateTime(2026, 7, 3, 18),
            note: 'run',
          ),
          Annotation(
            id: 'old',
            kind: AnnotationKind.illness,
            start: DateTime(2026, 6, 1), // out of range
            end: DateTime(2026, 6, 1, 12),
          ),
        ],
        pumpEvents: [
          PumpEvent(
              time: DateTime(2026, 7, 4, 9),
              kind: PumpEventKind.alarm,
              detail: 'LOW_INSULIN'),
        ],
        deviceChanges: [
          DeviceChange(kind: DeviceKind.site, changedAt: DateTime(2026, 7, 2, 8)),
        ],
        lowEpisodes: [
          GlucoseEpisode(
            start: DateTime(2026, 7, 5, 2),
            end: DateTime(2026, 7, 5, 2, 30),
            extremeMgdl: 58,
            isLow: true,
          ),
        ],
        highEpisodes: const [],
        unit: GlucoseUnit.mmol,
      );

      // 4 in-range entries (exercise note, alarm, site change, low episode);
      // the out-of-range illness note is dropped.
      expect(entries, hasLength(4));
      expect(entries.first.time.isAfter(entries.last.time), isTrue);
      // Newest first: the low episode on 7/5 leads.
      expect(entries.first.category, JournalCategory.lowEpisode);
      expect(entries.any((e) => e.category == JournalCategory.deviceChange), isTrue);
      expect(entries.any((e) => e.title == 'Exercise'), isTrue);
    });

    test('filtering by category works on the built list', () {
      final entries = builder.build(
        range: range,
        annotations: const [],
        pumpEvents: [
          PumpEvent(
              time: DateTime(2026, 7, 4, 9),
              kind: PumpEventKind.alert,
              detail: 'LOW_POWER'),
        ],
        deviceChanges: const [],
        lowEpisodes: const [],
        highEpisodes: const [],
        unit: GlucoseUnit.mmol,
      );
      final pumpOnly =
          entries.where((e) => e.category == JournalCategory.pumpEvent).toList();
      expect(pumpOnly, hasLength(1));
      expect(pumpOnly.single.title, 'Alert');
    });
  });

  group('TherapyReportBuilder', () {
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 3));

    test('insufficient CGM → no data, neutral multiplier', () {
      final report = TherapyReportBuilder().build(
        cgm: const [],
        boluses: const [],
        basal: const [],
        carbs: const [],
        settings: TherapySettings.placeholder(),
        range: range,
        now: DateTime(2026, 7, 3, 8),
      );
      expect(report.hasData, isFalse);
      expect(report.avgMultiplier, 1.0);
    });
  });
}
