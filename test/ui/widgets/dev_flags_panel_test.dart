/// The Developer menu's experiment-flag panel (issue #96).
library;

import 'package:bgdude/state/dev_flags.dart';
import 'package:bgdude/ui/widgets/dev_flags_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<(String, bool)>> _pump(
  WidgetTester tester, {
  Map<String, bool> values = const {},
  VoidCallback? onReset,
}) async {
  final changes = <(String, bool)>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          DevFlagsPanel(
            values: values,
            onChanged: (f, v) => changes.add((f.id, v)),
            onReset: onReset,
          ),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('every declared flag is rendered with its description',
      (tester) async {
    await _pump(tester);

    for (final f in devFlags) {
      expect(find.text(f.label), findsOneWidget, reason: f.id);
      // The description is the point — a switch with an unremembered effect is
      // worse than no switch.
      expect(find.text(f.description), findsOneWidget, reason: f.id);
    }
  });

  testWidgets('an unset flag shows its default', (tester) async {
    await _pump(tester);

    final flag = devFlags.first;
    final tile = tester.widget<SwitchListTile>(
        find.byKey(Key('dev-flag-${flag.id}')));
    expect(tile.value, flag.defaultValue);
  });

  testWidgets('toggling reports the flag and the new value', (tester) async {
    final flag = devFlags.first;
    final changes = await _pump(tester, values: {flag.id: false});

    await tester.tap(find.byKey(Key('dev-flag-${flag.id}')));
    await tester.pumpAndSettle();

    expect(changes, [(flag.id, true)]);
  });

  testWidgets('reset is offered only when the caller can handle it',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('dev-flags-reset')), findsNothing);

    var reset = 0;
    await _pump(tester, onReset: () => reset++);
    expect(find.byKey(const Key('dev-flags-reset')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev-flags-reset')));
    await tester.pumpAndSettle();
    expect(reset, 1);
  });
}
