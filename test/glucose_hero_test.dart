import 'package:bgdude/core/samples.dart';
import 'package:bgdude/core/units.dart';
import 'package:bgdude/ui/widgets/glucose_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows the value + unit and paints the day trend behind it',
      (tester) async {
    await tester.pumpWidget(_wrap(GlucoseHero(
      mgdl: 120,
      trend: GlucoseTrend.flat,
      unit: GlucoseUnit.mmol,
      time: DateTime(2026, 7, 4, 12), // fixed instant (TASK-170)
      dayTrend: List<double>.generate(288, (i) => 90 + (i % 60).toDouble()),
    )));

    // Number (6.7 mmol/L) and unit render over the trend.
    expect(find.text('6.7'), findsOneWidget);
    expect(find.text('mmol/L'), findsOneWidget);
    // The trend is drawn via a CustomPaint layer behind the number.
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('renders fine with too few points to draw a trend',
      (tester) async {
    await tester.pumpWidget(_wrap(const GlucoseHero(
      mgdl: 200,
      trend: GlucoseTrend.singleUp,
      unit: GlucoseUnit.mgdl,
      dayTrend: [200], // < 2 points → no sparkline, no crash
    )));
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('handles a flat day trend (zero span) without dividing by zero',
      (tester) async {
    await tester.pumpWidget(_wrap(const GlucoseHero(
      mgdl: 100,
      trend: GlucoseTrend.flat,
      unit: GlucoseUnit.mgdl,
      dayTrend: [100, 100, 100, 100],
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('100'), findsOneWidget);
  });

  group('screen-reader semantics (TASK-150)', () {
    test('the composed label reads value, unit, trend words and range', () {
      expect(
        GlucoseHero.semanticLabelFor(
            mgdl: 120, trend: GlucoseTrend.flat, unit: GlucoseUnit.mgdl),
        '120 mg/dL, steady, in range',
      );
      expect(
        GlucoseHero.semanticLabelFor(
            mgdl: 60, trend: GlucoseTrend.doubleDown, unit: GlucoseUnit.mgdl),
        '60 mg/dL, falling fast, low',
      );
      expect(
        GlucoseHero.semanticLabelFor(
            mgdl: null, trend: GlucoseTrend.unknown, unit: GlucoseUnit.mmol),
        'No glucose reading',
      );
    });

    testWidgets('the hero exposes a non-empty semantic label', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: GlucoseHero(
            mgdl: 120,
            trend: GlucoseTrend.flat,
            unit: GlucoseUnit.mgdl,
          ),
        ),
      ));
      final semantics =
          tester.getSemantics(find.byType(GlucoseHero));
      expect(semantics.label, isNotEmpty);
      expect(semantics.label, contains('120 mg/dL'));
      expect(semantics.label, contains('steady'));
    });
  });
}
