/// CGM diagnostics + pump alert-threshold mirror (issue #90).
///
/// The mismatch note is the part with real user value — it answers "why did one of
/// them warn me and not the other" — so most of these pin when it appears, when it
/// stays quiet, and that it names the right direction.
library;

import 'package:bgdude/core/units.dart';
import 'package:bgdude/insights/alert_thresholds.dart';
import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/ui/widgets/cgm_diagnostics_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = AlertThresholds(
  lowMgdl: Mgdl(70),
  highMgdl: Mgdl(180),
  urgentLowMgdl: Mgdl(55),
);

PumpSnapshot _snap({int? low, int? high, String? tx, bool? lowOn}) =>
    PumpSnapshot(
      time: DateTime(2026, 7, 19, 12),
      cgmLowAlertMgdl: low,
      cgmHighAlertMgdl: high,
      cgmTransmitterId: tx,
      cgmLowAlertEnabled: lowOn,
    );

Future<void> _pump(WidgetTester tester, PumpSnapshot? snapshot) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: CgmDiagnosticsCard(
        snapshot: snapshot,
        appThresholds: _app,
        unit: GlucoseUnit.mgdl,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows both sets of thresholds side by side', (tester) async {
    // The captured-cargo values: pump high 200 / low 80.
    await _pump(tester, _snap(low: 80, high: 200, tx: '8BT1AX'));

    expect(find.textContaining('Transmitter 8BT1AX'), findsOneWidget);
    expect(find.textContaining('Pump alerts at 80'), findsOneWidget);
    expect(find.textContaining('bgdude alerts at 70'), findsOneWidget);
  });

  testWidgets('nothing at all when the pump reported none', (tester) async {
    // An empty card here would read as "your CGM has no alerts configured", which is
    // a different and dangerous claim from "the pump never told us".
    await _pump(tester, PumpSnapshot(time: DateTime(2026, 7, 19, 12)));

    expect(find.textContaining('CGM on the pump'), findsNothing);
  });

  testWidgets('a disabled pump alert is marked, not hidden', (tester) async {
    await _pump(tester, _snap(low: 80, high: 200, lowOn: false));

    // Hiding it would imply the pump is watching for lows when it isn't.
    expect(find.textContaining('80 mg/dL (off)'), findsOneWidget);
  });

  group('mismatch note', () {
    String? note({int? pumpLow, int? pumpHigh}) =>
        CgmDiagnosticsCard.mismatchNote(
          pumpLow: pumpLow,
          pumpHigh: pumpHigh,
          appLow: _app.lowMgdl,
          appHigh: _app.highMgdl,
        );

    test('names who alerts first when the pump warns higher for lows', () {
      // Pump 80 vs app 70: the pump trips first on the way down.
      final n = note(pumpLow: 80);
      expect(n, isNotNull);
      expect(n, contains('the pump alerts first'));
    });

    test('names who alerts first when the pump warns lower for lows', () {
      final n = note(pumpLow: 60);
      expect(n, contains('bgdude alerts first'));
    });

    test('silent when they agree', () {
      // No note is the correct output — a "they match" line every time is noise.
      expect(note(pumpLow: 70, pumpHigh: 180), isNull);
    });

    test('silent when the pump has not reported', () {
      // A mismatch claim about a number nobody has would be worse than saying nothing.
      expect(note(), isNull);
    });

    test('a sub-1 mg/dL difference is not called a mismatch', () {
      // The pump stores integers, the app doubles; an exact comparison would report
      // rounding artefacts as disagreements and train the user to ignore the note.
      expect(note(pumpLow: 70, pumpHigh: 180), isNull);
    });
  });
}
