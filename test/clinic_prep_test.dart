import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/reports/clinic_prep.dart';
import 'package:bgdude/reports/glucose_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:flutter_test/flutter_test.dart';

/// Build a GlucoseReport over [days] from CGM at [mgdl] every 5 min, so metrics/episodes
/// come from the real machinery rather than hand-set numbers.
GlucoseReport _report(double mgdl, {int days = 14}) {
  final now = DateTime(2026, 7, 6, 12);
  final from = now.subtract(Duration(days: days));
  final range = ReportRange(from: from, to: now, preset: ReportPreset.last14);
  final cgm = <CgmSample>[];
  for (var d = 0; d < days; d++) {
    final dayStart = DateTime(from.year, from.month, from.day).add(Duration(days: d));
    for (var r = 0; r < 288; r++) {
      cgm.add(CgmSample(time: dayStart.add(Duration(minutes: 5 * r)), mgdl: mgdl));
    }
  }
  return const GlucoseReportBuilder()
      .build(cgm: cgm, annotations: const [], range: range, now: now);
}

void main() {
  const builder = ClinicPrepBuilder();

  test('§4-4.4: in-range data produces a summary and the always-on closers', () {
    final prep =
        builder.build(report: _report(120), unit: GlucoseUnit.mgdl);
    expect(prep.summary, contains('time in range'));
    expect(prep.summary, contains('GMI'));
    // Steady 120 → no low/high/CV questions; only the two closers remain.
    expect(prep.questions.length, 2);
    expect(prep.questions.any((q) => q.contains('pump settings')), isTrue);
    expect(prep.questions.any((q) => q.contains('alert thresholds')), isTrue);
  });

  test('§4-4.4: a high-glucose period surfaces a time-above and TIR question', () {
    final prep = builder.build(report: _report(260), unit: GlucoseUnit.mgdl);
    expect(prep.questions.any((q) => q.contains('time in range is')), isTrue);
    expect(prep.questions.any((q) => q.contains('above 180')), isTrue);
  });

  test('§4-4.4: a low period surfaces a below-70 question', () {
    final prep = builder.build(report: _report(60), unit: GlucoseUnit.mgdl);
    expect(prep.questions.any((q) => q.contains('below 70')), isTrue);
  });

  test('§4-4.4: mmol summary renders glucose in the chosen unit', () {
    final prep = builder.build(report: _report(120), unit: GlucoseUnit.mmol);
    expect(prep.summary, contains('mmol/L'));
  });

  group('LLM phrasing is optional (AC#4)', () {
    test('NoopClinicPhraser keeps the template summary', () async {
      final prep = builder.build(report: _report(120), unit: GlucoseUnit.mgdl);
      final out = await polishClinicPrep(prep, const NoopClinicPhraser());
      expect(out.summary, prep.summary);
      expect(out.questions, prep.questions);
    });

    test('a phraser that returns text replaces the summary only', () async {
      final prep = builder.build(report: _report(120), unit: GlucoseUnit.mgdl);
      final out = await polishClinicPrep(prep, _FixedPhraser('Nicely put.'));
      expect(out.summary, 'Nicely put.');
      expect(out.questions, prep.questions);
    });
  });
}

class _FixedPhraser implements ClinicPhraser {
  _FixedPhraser(this.text);
  final String text;
  @override
  Future<String?> polish(String template) async => text;
}
