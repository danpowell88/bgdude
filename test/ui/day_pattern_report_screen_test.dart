/// Widget coverage for the Patterns report screen (TASK-154 / issue #168):
/// every render branch — full report with a learned (k-means) grouping, the
/// below-threshold "needs more days" hint, the no-data empty state, the
/// provider-error state, the empty-cluster row, and the no-overlay fallback —
/// driven through the real DayPatternReportBuilder so the chart renders from
/// real AGP buckets, not hand-faked ones.
library;

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/data/kv_store.dart';
import 'package:bgdude/reports/day_pattern_report.dart';
import 'package:bgdude/reports/report_range.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/reports/day_pattern_report_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReportRange _range(DateTime from, DateTime to) =>
    ReportRange(from: from, to: to, preset: ReportPreset.custom);

/// A full day of 5-min samples flat at [mgdl].
List<CgmSample> _day(DateTime day, {required double mgdl}) => [
      for (var m = 0; m < 24 * 60; m += 5)
        CgmSample(time: day.add(Duration(minutes: m)), mgdl: mgdl),
    ];

/// A real report built from [days] flat-glucose days (alternating 90/220 mg/dL
/// so k-means, when it runs, has an unambiguous split).
DayPatternReport _buildReport(int days) {
  final first = DateTime(2026, 7, 1);
  final cgm = <CgmSample>[
    for (var i = 0; i < days; i++)
      ..._day(first.add(Duration(days: i)), mgdl: i.isEven ? 90 : 220),
  ];
  final range = _range(first, first.add(Duration(days: days)));
  return const DayPatternReportBuilder().build(
    cgm: cgm,
    range: range,
    now: first.add(Duration(days: days)),
  );
}

Future<void> _pumpScreen(WidgetTester tester,
    {required Future<DayPatternReport> Function() report}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dayPatternReportProvider.overrideWith((ref) => report()),
      ],
      child: const MaterialApp(home: DayPatternReportScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(KvStore.useMemory);

  testWidgets(
      'with 2+ weeks of two-regime history: weekday/weekend section, learned '
      'k-means section, overlay charts and per-cluster rows all render',
      (tester) async {
    final report =
        _buildReport(DayPatternReportBuilder.minDaysForKMeans);
    expect(report.kMeansClusters, isNotNull,
        reason: 'precondition: enough days for the learned grouping');

    await _pumpScreen(tester, report: () async => report);

    expect(find.text('Patterns'), findsWidgets);
    expect(find.text('Weekday vs weekend'), findsOneWidget);
    expect(find.text('Learned pattern (independent of the calendar)'),
        findsOneWidget);
    // Legend + row labels for both groupings.
    expect(find.text('Weekday'), findsWidgets);
    expect(find.text('Weekend'), findsWidgets);
    expect(find.text('Pattern 1'), findsWidgets);
    expect(find.text('Pattern 2'), findsWidgets);
    // Two overlay charts (weekday/weekend + learned).
    expect(find.byType(LineChart), findsNWidgets(2));
    // Cluster rows show day counts and metrics.
    expect(find.textContaining('days', findRichText: true), findsWidgets);
    expect(find.textContaining('Mean '), findsWidgets);
    expect(find.textContaining('TIR '), findsWidgets);
  });

  testWidgets(
      'below minDaysForKMeans: no learned section, shows the "needs at least '
      'N days" hint with the current count', (tester) async {
    final report = _buildReport(3);
    expect(report.kMeansClusters, isNull);

    await _pumpScreen(tester, report: () async => report);

    expect(find.text('Learned pattern (independent of the calendar)'),
        findsNothing);
    expect(
        find.textContaining(
            'Needs at least ${DayPatternReportBuilder.minDaysForKMeans} days'),
        findsOneWidget);
    expect(find.textContaining('3 so far'), findsOneWidget);
  });

  testWidgets('no usable days at all: the empty state renders, no sections',
      (tester) async {
    final report = _buildReport(0);
    expect(report.hasData, isFalse);

    await _pumpScreen(tester, report: () async => report);

    expect(find.textContaining('Not enough CGM history'), findsOneWidget);
    expect(find.text('Weekday vs weekend'), findsNothing);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('provider error surfaces as the error message, not a crash',
      (tester) async {
    await _pumpScreen(tester,
        report: () async => throw StateError('db unavailable'));

    expect(find.textContaining('Could not build report'), findsOneWidget);
  });

  testWidgets(
      'an empty cluster renders the "no days in range" row (weekday-only '
      'history has an empty Weekend group)', (tester) async {
    // _buildReport starts at 2026-07-01, a Wednesday — three consecutive days
    // (Wed/Thu/Fri) are all weekdays, so the Weekend group is empty.
    final report = _buildReport(3);
    expect(
        report.weekdayVsWeekend
            .firstWhere((c) => c.label == 'Weekend')
            .dayCount,
        0);

    await _pumpScreen(tester, report: () async => report);

    expect(find.text('Weekend: no days in range'), findsOneWidget);
  });

  testWidgets(
      'clusters that all lack AGP data fall back to the no-overlay text '
      'instead of an empty chart', (tester) async {
    // Hand-constructed: day features exist (hasData true) but neither cluster
    // carries AGP buckets — the overlay must degrade to text, not render an
    // empty LineChart.
    final day = DateTime(2026, 7, 6);
    final report = DayPatternReport(
      range: _range(day, day.add(const Duration(days: 1))),
      generatedAt: day.add(const Duration(days: 1)),
      dayFeatures: [
        DayFeatures(
            date: day, meanMgdl: 100, tir: 1, tbr: 0, peakHour: 12),
      ],
      weekdayVsWeekend: const [
        DayCluster(label: 'Weekday', days: [], agp: []),
        DayCluster(label: 'Weekend', days: [], agp: []),
      ],
    );
    await _pumpScreen(tester, report: () async => report);

    expect(find.text('Not enough data for an overlay yet.'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
