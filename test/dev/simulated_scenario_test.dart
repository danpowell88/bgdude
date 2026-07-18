/// Scripted demo-mode scenarios (issue #235).
///
/// Asserting the UI's REACTION needs a device; asserting that each scenario actually
/// produces the state it claims does not, and is what makes the on-device tests worth
/// writing rather than debugging.
library;

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/dev/simulated_scenario.dart';
import 'package:bgdude/pump/simulated_pump_client.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 4, 12);
SimulatedDay _day() => SimulatedDay.generate(now: _now);

SimulatedDay _applied(SimulatedScenario s) => applyScenario(_day(), s);

void main() {
  test('none leaves the generated day untouched', () {
    final base = _day();
    final out = applyScenario(base, SimulatedScenario.none);

    expect(out.cgm.length, base.cgm.length);
    expect(out.cgm.last.mgdl.value, base.cgm.last.mgdl.value);
  });

  test('forcedUrgentLow ends below the urgent threshold AND falling', () {
    // A flat low would not exercise the rate-based alert paths, which is half of
    // what the scenario exists to test.
    final cgm = _applied(SimulatedScenario.forcedUrgentLow).cgm;

    expect(cgm.last.mgdl.value, lessThan(55));
    expect(cgm.last.mgdl.value, lessThan(cgm[cgm.length - 2].mgdl.value));
  });

  test('rapidRise ends well above where it started, fast', () {
    final cgm = _applied(SimulatedScenario.rapidRise).cgm;
    final tail = cgm.sublist(cgm.length - 6);

    expect(tail.last.mgdl.value - tail.first.mgdl.value, greaterThan(80));
  });

  test('sensorWarmup flags the readings rather than removing them', () {
    // Consumers are supposed to EXCLUDE warm-up readings; they cannot demonstrate
    // that if the scenario simply deletes them.
    final cgm = _applied(SimulatedScenario.sensorWarmup).cgm;

    expect(cgm.last.sensorWarmup, isTrue);
    expect(cgm.length, _day().cgm.length, reason: 'no readings removed');
  });

  test('stubbornHigh stays high across a long stretch', () {
    final cgm = _applied(SimulatedScenario.stubbornHigh).cgm;
    final tail = cgm.sublist(cgm.length - 24);

    expect(tail.every((s) => s.mgdl.value > 250), isTrue);
  });

  test('pumpAlarm does not distort the glucose trace', () {
    // The alarm rides on the snapshot; rewriting the trace as well would make the
    // scenario test two things at once and neither cleanly.
    final base = _day();
    final out = applyScenario(base, SimulatedScenario.pumpAlarm);

    expect(out.cgm.last.mgdl.value, base.cgm.last.mgdl.value);
  });

  test('only pumpAlarm raises an alarm, only sensorWarmup an alert', () {
    for (final s in SimulatedScenario.values) {
      expect(scenarioAlarms(s).isNotEmpty, s == SimulatedScenario.pumpAlarm,
          reason: s.name);
      expect(scenarioAlerts(s).isNotEmpty, s == SimulatedScenario.sensorWarmup,
          reason: s.name);
    }
  });

  test('the earlier day survives — history stays believable', () {
    // A scenario that flattened all 24 hours would make every history screen
    // obviously fake, and would not test what the alerts actually read.
    final base = _day();
    final out = _applied(SimulatedScenario.forcedUrgentLow);

    expect(out.cgm.first.mgdl.value, base.cgm.first.mgdl.value);
    expect(out.cgm[10].mgdl.value, base.cgm[10].mgdl.value);
  });

  test('every scenario yields a usable day', () {
    for (final s in SimulatedScenario.values) {
      final out = _applied(s);
      expect(out.cgm, isNotEmpty, reason: s.name);
      expect(out.settings, isNotNull, reason: s.name);
    }
  });

  test('the client applies its scenario and reports the alarms', () {
    final client = SimulatedPumpClient(
      clock: () => _now,
      scenario: SimulatedScenario.pumpAlarm,
    );
    addTearDown(client.dispose);

    expect(client.scenario, SimulatedScenario.pumpAlarm);
    expect(scenarioAlarms(client.scenario), contains('OCCLUSION'));
  });

  test('the client defaults to no scenario', () {
    final client = SimulatedPumpClient(clock: () => _now);
    addTearDown(client.dispose);

    expect(client.scenario, SimulatedScenario.none);
  });

  test('a scenario applied to an empty day does not crash', () {
    final empty = SimulatedDay(
      start: _now,
      end: _now,
      cgm: const <CgmSample>[],
      boluses: const [],
      basal: const [],
      carbs: const [],
      settings: _day().settings,
      context: _day().context,
    );

    for (final s in SimulatedScenario.values) {
      expect(applyScenario(empty, s).cgm, isEmpty, reason: s.name);
    }
  });
}
