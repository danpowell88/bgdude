import 'package:bgdude/core/samples.dart';
import 'package:bgdude/feedback/annotations.dart';
import 'package:bgdude/reports/correlation_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = CorrelationReportBuilder();

  test('§4-4.3: mood correlates with time-in-range when tagged ≥8 days', () {
    final now = DateTime(2026, 7, 20, 12);
    final from = DateTime(2026, 7, 8);
    final range = ReportRange(from: from, to: now, preset: ReportPreset.last14);

    final cgm = <CgmSample>[];
    final annotations = <Annotation>[];
    // 10 days: good-mood days sit in range (110), low-mood days run high (250).
    for (var d = 0; d < 10; d++) {
      final dayStart = from.add(Duration(days: d));
      final goodMood = d.isEven;
      final mgdl = goodMood ? 110.0 : 250.0;
      for (var r = 0; r < 110; r++) {
        cgm.add(CgmSample(
            time: dayStart.add(Duration(minutes: 12 * r)), mgdl: mgdl));
      }
      annotations.add(Annotation(
        id: 'm$d',
        kind: AnnotationKind.mood,
        start: dayStart.add(const Duration(hours: 20)),
        end: dayStart.add(const Duration(hours: 20)),
        note: goodMood ? 'Great' : 'Low',
      ));
    }

    final report = builder.build(
      cgm: cgm,
      health: const [],
      range: range,
      now: now,
      annotations: annotations,
    );

    final mood = report.findings
        .where((f) => f.predictorLabel == 'better mood')
        .toList();
    expect(mood, isNotEmpty, reason: 'mood should be correlated with ≥8 tagged days');
    // Better mood ↔ higher time-in-range.
    final tir =
        mood.firstWhere((f) => f.outcomeLabel == 'time-in-range');
    expect(tir.r, greaterThan(0.5));
  });

  test('§4-4.3: mood is not correlated with fewer than 8 tagged days', () {
    final now = DateTime(2026, 7, 20, 12);
    final from = DateTime(2026, 7, 8);
    final range = ReportRange(from: from, to: now, preset: ReportPreset.last14);
    final cgm = <CgmSample>[];
    final annotations = <Annotation>[];
    for (var d = 0; d < 5; d++) {
      final dayStart = from.add(Duration(days: d));
      for (var r = 0; r < 110; r++) {
        cgm.add(CgmSample(
            time: dayStart.add(Duration(minutes: 12 * r)), mgdl: 120));
      }
      annotations.add(Annotation(
        id: 'm$d',
        kind: AnnotationKind.mood,
        start: dayStart.add(const Duration(hours: 20)),
        end: dayStart.add(const Duration(hours: 20)),
        note: 'OK',
      ));
    }
    final report = builder.build(
      cgm: cgm,
      health: const [],
      range: range,
      now: now,
      annotations: annotations,
    );
    expect(report.findings.any((f) => f.predictorLabel == 'better mood'), isFalse);
  });
}
