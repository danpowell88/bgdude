/// The pump-configuration mirror (issue #85).
///
/// Values from the captured cargo in doc/pump-protocol.md, so what the card renders
/// is checked against what a real pump actually reported.
library;

import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/ui/widgets/pump_config_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, PumpSnapshot? snapshot) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: PumpConfigCard(snapshot: snapshot)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the captured pump configuration in plain language',
      (tester) async {
    await _pump(
      tester,
      PumpSnapshot(
        time: DateTime(2026, 7, 19, 12),
        autoShutdownEnabled: true,
        autoShutdownHours: 12,
        lowInsulinThresholdUnits: 20,
        cannulaPrimeSizeUnits: 0.30,
        quickBolusEnabled: true,
      ),
    );

    expect(find.textContaining('Auto-shutdown after 12 h idle'), findsOneWidget);
    // The threshold that explains why the pump warns about insulin at a different
    // moment than bgdude does.
    expect(find.textContaining('Pump warns at 20 U left'), findsOneWidget);
    expect(find.textContaining('Cannula prime 0.30 U'), findsOneWidget);
    expect(find.textContaining('Read-only'), findsOneWidget);
  });

  testWidgets('nothing at all before the pump reports', (tester) async {
    // A card listing nothing would read as "the pump has no settings", which is never
    // true — it just hasn't told us yet.
    await _pump(tester, PumpSnapshot(time: DateTime(2026, 7, 19, 12)));

    expect(find.text('Pump configuration'), findsNothing);
  });

  testWidgets('auto-shutdown OFF is stated, not omitted', (tester) async {
    // Omitting it would leave the user assuming the protective shutdown is active.
    await _pump(
      tester,
      PumpSnapshot(
        time: DateTime(2026, 7, 19, 12),
        autoShutdownEnabled: false,
        lowInsulinThresholdUnits: 20,
      ),
    );

    expect(find.textContaining('Auto-shutdown off'), findsOneWidget);
  });

  testWidgets('a feature lock is surfaced only when it is on', (tester) async {
    await _pump(
      tester,
      PumpSnapshot(
        time: DateTime(2026, 7, 19, 12),
        lowInsulinThresholdUnits: 20,
        featureLocked: true,
      ),
    );
    expect(find.textContaining('feature lock is ON'), findsOneWidget);

    await _pump(
      tester,
      PumpSnapshot(
        time: DateTime(2026, 7, 19, 12),
        lowInsulinThresholdUnits: 20,
        featureLocked: false,
      ),
    );
    // "Feature lock off" is the normal state; a row for it is noise.
    expect(find.textContaining('feature lock'), findsNothing);
  });
}
