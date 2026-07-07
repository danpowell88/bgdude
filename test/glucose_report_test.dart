import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/reports/clinic_prep.dart';
import 'package:bgdude/reports/glucose_report.dart';
import 'package:bgdude/reports/report_exporter.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

List<CgmSample> _flat(DateTime start, int count, double mgdl,
        {int stepMin = 5}) =>
    [
      for (var i = 0; i < count; i++)
        CgmSample(time: start.add(Duration(minutes: stepMin * i)), mgdl: mgdl),
    ];

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

void main() {
  group('EpisodeDetector', () {
    final base = DateTime(2026, 7, 4, 3);
    const det = EpisodeDetector();

    test('detects a low episode ≥15 min', () {
      final cgm = _flat(base, 5, 60); // 20 min below 70
      final lows = det.detect(cgm, low: true);
      expect(lows, hasLength(1));
      expect(lows.first.extremeMgdl, 60);
      expect(lows.first.duration.inMinutes, 20);
    });

    test('ignores a dip shorter than 15 min', () {
      final cgm = _flat(base, 2, 60); // 5 min
      expect(det.detect(cgm, low: true), isEmpty);
    });

    test('a single in-range blip does not split one episode', () {
      final cgm = <CgmSample>[
        ..._flat(base, 5, 60), // 0..20 low
        CgmSample(time: base.add(const Duration(minutes: 25)), mgdl: 90), // blip
        ..._flat(base.add(const Duration(minutes: 30)), 4, 60), // 30..45 low
      ];
      final lows = det.detect(cgm, low: true);
      expect(lows, hasLength(1)); // merged across the ≤15-min gap
    });

    test('detects a high episode', () {
      final highs = det.detect(_flat(base, 5, 260), low: false);
      expect(highs, hasLength(1));
      expect(highs.first.extremeMgdl, 260);
    });
  });

  group('GlucoseReportBuilder', () {
    final day = DateTime(2026, 7, 4, 2);
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 5));
    final now = DateTime(2026, 7, 5, 8);
    const builder = GlucoseReportBuilder();

    test('excludes compression-low-annotated readings from stats', () {
      final cgm = <CgmSample>[
        ..._flat(day, 6, 120), // in range
        ..._flat(day.add(const Duration(hours: 1)), 4, 55), // artifact lows
      ];
      final annotations = [
        Annotation(
          id: 'c',
          kind: AnnotationKind.compressionLow,
          start: day.add(const Duration(minutes: 55)),
          end: day.add(const Duration(hours: 1, minutes: 30)),
        ),
      ];
      final report = builder.build(
          cgm: cgm, annotations: annotations, range: range, now: now);
      expect(report.excludedSampleCount, 4);
      // The excluded lows must not produce a low episode.
      expect(report.lowEpisodes, isEmpty);
      expect(report.metrics.readingCount, 6);
    });

    test('keeps site-failure highs (real exposure, not an artifact)', () {
      final cgm = _flat(day, 6, 300);
      final annotations = [
        Annotation(
          id: 's',
          kind: AnnotationKind.siteFailure,
          start: day.subtract(const Duration(minutes: 10)),
          end: day.add(const Duration(hours: 1)),
        ),
      ];
      final report = builder.build(
          cgm: cgm, annotations: annotations, range: range, now: now);
      expect(report.excludedSampleCount, 0);
      expect(report.metrics.readingCount, 6);
      expect(report.highEpisodes, isNotEmpty);
    });

    test('ignores readings outside the range', () {
      final cgm = [
        ..._flat(day, 6, 120),
        ..._flat(DateTime(2026, 8, 1), 6, 120), // outside range
      ];
      final report = builder.build(
          cgm: cgm, annotations: const [], range: range, now: now);
      expect(report.metrics.readingCount, 6);
      expect(report.daysWithData, 1);
    });
  });

  group('ReportExporter', () {
    final range = _range(DateTime(2026, 7, 1), DateTime(2026, 7, 5));
    final report = const GlucoseReportBuilder().build(
      cgm: _flat(DateTime(2026, 7, 4, 8), 12, 130),
      annotations: const [],
      range: range,
      now: DateTime(2026, 7, 5, 8),
    );
    const exporter = ReportExporter();

    test('summary CSV carries key fields', () {
      final csv = exporter.summaryCsv(report, GlucoseUnit.mmol);
      expect(csv, contains('tir_70_180_pct'));
      expect(csv, contains('gmi_pct')); // TASK-164: not gmi_eA1c_pct -- no eA1c is computed
      expect(csv.split('\n').first, 'field,value');
    });

    test('raw CSV has a header + one row per reading', () {
      final samples = _flat(DateTime(2026, 7, 4, 8), 12, 130);
      final csv = exporter.rawReadingsCsv(samples, GlucoseUnit.mmol);
      expect(csv.split('\n'), hasLength(samples.length + 1));
    });

    test('PDF builds to non-empty bytes', () async {
      final bytes = await exporter.buildPdf(report, GlucoseUnit.mmol);
      expect(bytes.length, greaterThan(500));
    });

    test('clinic-prep PDF builds to non-empty bytes (§4-4.4 AC#3)', () async {
      final prep =
          const ClinicPrepBuilder().build(report: report, unit: GlucoseUnit.mmol);
      final bytes = await exporter.buildClinicPrepPdf(prep, report.generatedAt);
      expect(bytes.length, greaterThan(500));
    });
  });
}
