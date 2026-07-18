/// The pump-mirror panel (issue #84).
///
/// The enum names are pump-firmware vocabulary; these pin that the user sees words
/// instead, and — more importantly — that "we were never told" never renders as
/// "nothing is wrong".
library;

import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/ui/widgets/pump_mirror_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PumpSnapshot _snap({
  String? basal,
  String? controlIq,
  String? cgmAlert,
  String? bolus,
}) =>
    PumpSnapshot(
      time: DateTime(2026, 7, 19, 12),
      basalStatusIcon: basal,
      apControlStateIcon: controlIq,
      cgmAlertIcon: cgmAlert,
      bolusStatusIcon: bolus,
    );

Future<void> _pump(WidgetTester tester, PumpSnapshot? snapshot) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: PumpMirrorPanel(snapshot: snapshot)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a suspended basal reads as words, not as SUSPEND', (tester) async {
    await _pump(tester, _snap(basal: 'SUSPEND', controlIq: 'STATE_GRAY'));

    expect(find.text('Basal delivery suspended'), findsOneWidget);
    expect(find.textContaining('SUSPEND'), findsNothing);
    expect(find.text('Control-IQ not actively adjusting'), findsOneWidget);
  });

  testWidgets('no panel at all when the pump never answered op 57',
      (tester) async {
    // The important case. An empty card here would say "nothing is happening on your
    // pump", which is a claim the app was never in a position to make.
    await _pump(tester, PumpSnapshot(time: DateTime(2026, 7, 19, 12)));

    expect(find.text('On the pump right now'), findsNothing);
  });

  testWidgets('no panel when there is no snapshot at all', (tester) async {
    await _pump(tester, null);

    expect(find.text('On the pump right now'), findsNothing);
  });

  testWidgets('answered but everything hidden says so explicitly', (tester) async {
    // Distinct from the case above: here the pump DID answer and reported nothing
    // notable, which is genuinely reassuring and worth stating.
    await _pump(tester, _snap(basal: 'BASAL', controlIq: 'HIDE_ICON'));

    expect(find.text('On the pump right now'), findsOneWidget);
    expect(find.text('Basal delivering'), findsOneWidget);
  });

  testWidgets('a benign CGM state produces no row', (tester) async {
    await _pump(tester, _snap(basal: 'BASAL', cgmAlert: 'NO_ERROR'));

    // NO_ERROR is the absence of a problem; a row saying so is noise.
    expect(find.textContaining('CGM alert'), findsNothing);
  });

  testWidgets('a real CGM alert is surfaced', (tester) async {
    await _pump(tester, _snap(basal: 'BASAL', cgmAlert: 'SENSOR_EXPIRED'));

    expect(find.textContaining('sensor expired'), findsOneWidget);
  });

  testWidgets('an unrecognised firmware value is shown, not swallowed',
      (tester) async {
    // A pump reporting something this build has never seen is worth showing — the
    // alternative is a panel that silently omits the one novel thing happening.
    await _pump(tester, _snap(basal: 'SOME_FUTURE_STATE'));

    expect(find.textContaining('some future state'), findsOneWidget);
  });

  group('the row mapping itself', () {
    test('null never becomes a row', () {
      expect(PumpMirrorPanel.basalRow(null), isNull);
      expect(PumpMirrorPanel.controlIqRow(null), isNull);
      expect(PumpMirrorPanel.cgmAlertRow(null), isNull);
      expect(PumpMirrorPanel.bolusRow(null), isNull);
    });

    test('states worth noticing are flagged as warnings', () {
      expect(PumpMirrorPanel.basalRow('SUSPEND')!.warn, isTrue);
      expect(PumpMirrorPanel.controlIqRow('STATE_RED')!.warn, isTrue);
      // Normal delivery is not a warning — flagging everything would flag nothing.
      expect(PumpMirrorPanel.basalRow('BASAL')!.warn, isFalse);
      expect(PumpMirrorPanel.controlIqRow('STATE_GRAY')!.warn, isFalse);
    });
  });
}
