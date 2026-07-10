// Focused unit tests for lib/reports/report_range.dart -- kept "tiny and pure" per its own
// doc comment, but had no dedicated test file: the last30/last90/custom preset branches and
// ReportRange.days were untested, so a copy-paste error in the switch (e.g. last90 silently
// returning the last30 day count, or an off-by-one in the inclusive day count) would not have
// been caught by any test in the suite.
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportPresetX', () {
    test('days maps every preset to its correct window length', () {
      expect(ReportPreset.last7.days, 7);
      expect(ReportPreset.last14.days, 14);
      expect(ReportPreset.last30.days, 30);
      expect(ReportPreset.last90.days, 90);
      expect(ReportPreset.custom.days, 0);
    });

    test('label maps every preset to its display string', () {
      expect(ReportPreset.last7.label, 'Last 7 days');
      expect(ReportPreset.last14.label, 'Last 14 days');
      expect(ReportPreset.last30.label, 'Last 30 days');
      expect(ReportPreset.last90.label, 'Last 90 days');
      expect(ReportPreset.custom.label, 'Custom');
    });
  });

  group('ReportRange', () {
    test('preset factory anchors "to" at now and "from" preset.days-1 back', () {
      final now = DateTime(2026, 7, 11, 14, 30);
      final range = ReportRange.preset(ReportPreset.last30, now: now);
      expect(range.to, now);
      expect(range.from, DateTime(2026, 6, 12)); // 30 days incl. today -> 29 back, midnight
      expect(range.preset, ReportPreset.last30);
    });

    test('days is an inclusive day count, not a raw duration difference', () {
      final sameDay = ReportRange(
        from: DateTime(2026, 7, 4),
        to: DateTime(2026, 7, 4, 23, 0),
        preset: ReportPreset.custom,
      );
      expect(sameDay.days, 1);

      final fiveDaySpan = ReportRange(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 5),
        preset: ReportPreset.custom,
      );
      expect(fiveDaySpan.days, 5);
    });

    test('label uses the preset label unless custom, which formats the dates', () {
      final preset = ReportRange(
        from: DateTime(2026, 6, 12),
        to: DateTime(2026, 7, 11),
        preset: ReportPreset.last30,
      );
      expect(preset.label, 'Last 30 days');

      final custom = ReportRange(
        from: DateTime(2026, 7, 1),
        to: DateTime(2026, 7, 5),
        preset: ReportPreset.custom,
      );
      expect(custom.label, '2026-07-01 - 2026-07-05');
    });
  });
}
