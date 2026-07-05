import 'package:bgdude/core/units.dart';
import 'package:bgdude/ui/widgets/error_grid_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(List<({double referenceMgdl, double predictedMgdl})> points,
      {GlucoseUnit unit = GlucoseUnit.mmol}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ErrorGridChart(points: points, unit: unit),
          ),
        ),
      ),
    );
  }

  testWidgets('builds with mixed-zone points without exceptions',
      (tester) async {
    final points = <({double referenceMgdl, double predictedMgdl})>[
      // Zone A: predicted within 20% of reference.
      (referenceMgdl: 100, predictedMgdl: 105),
      (referenceMgdl: 150, predictedMgdl: 140),
      (referenceMgdl: 80, predictedMgdl: 85),
      // Zone E: reference low, predicted very high (wrong treatment).
      (referenceMgdl: 60, predictedMgdl: 250),
    ];

    await tester.pumpWidget(wrap(points));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorGridChart), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('empty points render an empty grid without crashing',
      (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('renders in mg/dL unit and dark theme without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: ErrorGridChart(
              points: [(referenceMgdl: 120, predictedMgdl: 118)],
              unit: GlucoseUnit.mgdl,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
