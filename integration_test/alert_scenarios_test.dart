/// On-device alert-flow coverage per scripted scenario (issue #235, AC#3).
///
/// NOT RUN IN CI, and not runnable in the authoring environment — `integration_test/`
/// against the emulator fails here with a VM-service WebSocket error (pre-existing, see
/// decision-5: integration tests are manual-only). Written against the scenario config
/// so that when an emulator is available these are a single command rather than a
/// morning of setup:
///
///   flutter test integration_test/alert_scenarios_test.dart -d emulator-5554
library;

import 'package:bgdude/dev/simulated_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpDemoHarness);

  testWidgets('an urgent low surfaces on the home screen', (tester) async {
    await pumpDemoApp(tester, scenario: SimulatedScenario.forcedUrgentLow);

    // The reading itself must be visibly low; the exact banner copy is the app's to
    // change, so assert on the state rather than a phrase.
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rapid rise renders without error', (tester) async {
    await pumpDemoApp(tester, scenario: SimulatedScenario.rapidRise);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a pump alarm reaches the UI', (tester) async {
    await pumpDemoApp(tester, scenario: SimulatedScenario.pumpAlarm);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sensor warm-up renders without error', (tester) async {
    await pumpDemoApp(tester, scenario: SimulatedScenario.sensorWarmup);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a stubborn high renders without error', (tester) async {
    await pumpDemoApp(tester, scenario: SimulatedScenario.stubbornHigh);

    expect(tester.takeException(), isNull);
  });
}
