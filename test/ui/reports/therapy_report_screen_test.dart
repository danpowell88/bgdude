/// TASK-152 (#166): TherapyReportScreen renders the infusion-site lifetime
/// section — the learned "failures cluster after ~N days" estimate and the
/// TIR-by-day-of-wear chart — and hides it when there is nothing learned yet.
/// Also exercises the pre-existing headline / time-of-day / basal-link
/// branches the section sits between.
library;

import 'package:bgdude/ml/autotune.dart';
import 'package:bgdude/ml/basal_recommender.dart';
import 'package:bgdude/ml/time_of_day_sensitivity.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/reports/site_lifetime_report.dart';
import 'package:bgdude/reports/therapy_report.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/reports/therapy_report_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _range = ReportRange(
    from: DateTime(2026, 7, 1),
    to: DateTime(2026, 7, 15),
    preset: ReportPreset.custom);
final _generatedAt = DateTime(2026, 7, 15, 12);

TherapyReport _therapyReport({bool withData = false}) => TherapyReport(
      range: _range,
      generatedAt: _generatedAt,
      days: withData
          ? [
              for (var i = 0; i < 3; i++)
                DayResult(
                  day: DateTime(2026, 7, 2 + i),
                  sensitivityMultiplier: 1.1 + i * 0.05,
                  sampleCount: 200,
                  carbFreeMinutes: 400,
                ),
            ]
          : const [],
      avgMultiplier: withData ? 1.15 : 1.0,
    );

SiteLifetimeReport _siteReport({
  List<double> failureAgesHours = const [],
  double? medianFailureAgeHours,
  Map<int, double> tirBySetDay = const {},
}) =>
    SiteLifetimeReport(
      range: _range,
      generatedAt: _generatedAt,
      failureAgesHours: failureAgesHours,
      medianFailureAgeHours: medianFailureAgeHours,
      tirBySetDay: tirBySetDay,
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required TherapyReport therapy,
  required SiteLifetimeReport site,
  TimeOfDayProfile? profile,
  BasalRecommendation? basal,
}) async {
  // Tall surface so the whole (lazily built) ListView renders in one frame.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        therapyReportProvider.overrideWith((ref) async => therapy),
        siteLifetimeReportProvider.overrideWith((ref) async => site),
        timeOfDayProfileProvider.overrideWith((ref) => profile),
        basalRecommendationProvider
            .overrideWithValue(basal ?? BasalRecommendation.none(_generatedAt)),
      ],
      child: const MaterialApp(home: TherapyReportScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a learned lifetime renders the median estimate and the '
      'TIR-by-day-of-wear chart', (tester) async {
    await _pumpScreen(
      tester,
      therapy: _therapyReport(),
      site: _siteReport(
        failureAgesHours: const [50, 60, 70],
        medianFailureAgeHours: 60,
        tirBySetDay: const {1: 0.82, 2: 0.74, 3: 0.55},
      ),
    );

    expect(find.text('Infusion-site lifetime'), findsOneWidget);
    // 60 h median -> ~2.5 days, over 3 logged failures.
    expect(find.textContaining('Failures cluster after ~2.5'), findsOneWidget);
    expect(find.textContaining('median of 3 logged'), findsOneWidget);
    expect(find.text('Time in Range by day of wear'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets(
      'below minFailuresForMedian the section says "not enough yet" and '
      'draws no chart', (tester) async {
    await _pumpScreen(
      tester,
      therapy: _therapyReport(),
      site: _siteReport(failureAgesHours: const [30]),
    );

    expect(find.text('Infusion-site lifetime'), findsOneWidget);
    expect(
        find.textContaining('1 logged site failure(s) in range'), findsOneWidget);
    expect(find.textContaining('not enough yet'), findsOneWidget);
    expect(find.text('Time in Range by day of wear'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets(
      'with no site data the section is absent while the rest of the report '
      '(headline, time-of-day, basal link) still renders', (tester) async {
    final profile = TimeOfDayProfile(
      multipliers: [1.3, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.9],
      confidences: [0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5],
    );
    final basal = BasalRecommendation(
      segments: const [
        BasalSegmentRecommendation(
          startMinuteOfDay: 0,
          endMinuteOfDay: 180,
          currentRate: 0.8,
          suggestedRate: 0.9,
          avgMultiplier: 1.2,
          confidence: 0.7,
          trainedDays: 21,
          rationale: 'ran resistant overnight',
        ),
      ],
      trainedDays: 21,
      generatedAt: _generatedAt,
    );

    await _pumpScreen(
      tester,
      therapy: _therapyReport(withData: true),
      site: _siteReport(), // no failures, no TIR curve -> hasData == false
      profile: profile,
      basal: basal,
    );

    expect(find.text('Infusion-site lifetime'), findsNothing);
    expect(find.textContaining('more resistant'), findsOneWidget);
    expect(find.text('Time-of-day sensitivity'), findsOneWidget);
    expect(find.text('1 segment(s) worth reviewing'), findsOneWidget);
  });
}
