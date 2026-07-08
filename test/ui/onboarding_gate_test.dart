import 'package:bgdude/pump/pump_snapshot.dart';
import 'package:bgdude/state/providers.dart';
import 'package:bgdude/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: on the onboarding "Get connected" step, choosing demo mode made
/// pumpClientProvider the simulator, which reports "connected" instantly — so the pair
/// card wrongly showed "Pump connected" and the demo card looked unselected, even though
/// tapping Get started put the app in demo. The two cards must key off the explicit
/// choice, and a live connection must not count while in demo.
Future<void> _toGate(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 1100));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Pretend a pump connection is being reported (as the simulator does).
        pumpConnectionProvider.overrideWith(
            (ref) => Stream.value(const PumpConnection(
                stage: PumpConnectionStage.connected))),
        pumpPairingRequestProvider.overrideWith((ref) => const Stream.empty()),
        pumpErrorProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(home: OnboardingScreen(onDone: () {})),
    ),
  );
  await tester.pumpAndSettle();
  // page 1 → pairing warning
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('I understand and want to continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  // profile → connect gate
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  expect(find.text('Get connected'), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => TestWidgetsFlutterBinding.instance.reset());

  testWidgets('choosing demo selects demo and does not show the pump connected',
      (tester) async {
    await _toGate(tester);

    await tester.ensureVisible(find.text('Use demo mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use demo mode'));
    await tester.pumpAndSettle();

    // Demo is the selected path…
    expect(find.text('Demo mode selected'), findsOneWidget);
    // …and the pump card must NOT claim it's connected/ready.
    expect(find.text('Pump connected. You\'re ready to go.'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Get started'), findsOneWidget);
  });
}
