/// Scriptable demo-mode scenarios (issue #235).
///
/// Demo mode generates a plausible, unremarkable day. That is right for browsing the app,
/// and useless for exercising the alert paths — you cannot wait for an urgent low to
/// happen in a simulator that never has one.
///
/// A scenario overrides the generated day so a specific state is reachable on demand:
/// an urgent low right now, a rapid rise, a pump alarm, a sensor in warm-up, a stubborn
/// high. Pure data plus a pure transform, so what each scenario produces is unit-testable
/// without a device — only asserting the UI's *reaction* needs one.
library;

import '../core/samples.dart';
import 'sim_data.dart';

/// The scenarios demo mode can be pinned to.
enum SimulatedScenario {
  /// The normal generated day.
  none,

  /// Latest reading below the urgent-low threshold, with a falling trend.
  forcedUrgentLow,

  /// A steep sustained rise into the last half hour.
  rapidRise,

  /// The pump reports an active alarm.
  pumpAlarm,

  /// The sensor is warming up — readings present but unreliable.
  sensorWarmup,

  /// High for hours with insulin on board doing nothing.
  stubbornHigh,
}

/// Alarms a scenario puts on the snapshot. Empty for scenarios that don't involve one.
List<String> scenarioAlarms(SimulatedScenario scenario) =>
    scenario == SimulatedScenario.pumpAlarm ? const ['OCCLUSION'] : const [];

/// Alerts a scenario puts on the snapshot.
List<String> scenarioAlerts(SimulatedScenario scenario) =>
    scenario == SimulatedScenario.sensorWarmup
        ? const ['SENSOR_WARMUP']
        : const [];

/// Applies [scenario] to a generated [day].
///
/// Rewrites only the tail of the CGM trace rather than the whole day: the history
/// screens still show a believable 24 hours, and only the part the alert logic actually
/// reads is forced. A scenario that flattened the entire day would make every history
/// view obviously fake and would not test what the alerts see.
SimulatedDay applyScenario(SimulatedDay day, SimulatedScenario scenario) {
  if (scenario == SimulatedScenario.none) return day;

  final cgm = [...day.cgm];
  if (cgm.isEmpty) return day;

  List<CgmSample> tail(int count, double Function(int i) mgdl,
      {bool warmup = false}) {
    final from = cgm.length - count;
    if (from < 0) return cgm;
    final out = [...cgm.sublist(0, from)];
    for (var i = 0; i < count; i++) {
      out.add(CgmSample(
        time: cgm[from + i].time,
        mgdl: mgdl(i),
        sensorWarmup: warmup,
      ));
    }
    return out;
  }

  final rewritten = switch (scenario) {
    // Falling into an urgent low, so both the value AND the trend read as urgent.
    // A flat low would not exercise the rate-based paths.
    SimulatedScenario.forcedUrgentLow => tail(6, (i) => 90 - i * 8.0),

    // ~4 mg/dL/min — comfortably above any rise threshold.
    SimulatedScenario.rapidRise => tail(6, (i) => 120 + i * 20.0),

    // Warm-up readings exist but are flagged unreliable; the point is that consumers
    // EXCLUDE them, which they cannot do if the scenario simply removes them.
    SimulatedScenario.sensorWarmup => tail(6, (i) => 110 + i * 2.0, warmup: true),

    // Stuck high and barely moving.
    SimulatedScenario.stubbornHigh => tail(24, (i) => 260 + (i % 3) * 2.0),

    // The alarm rides on the snapshot, not the trace.
    SimulatedScenario.pumpAlarm => cgm,
    SimulatedScenario.none => cgm,
  };

  return SimulatedDay(
    start: day.start,
    end: day.end,
    cgm: rewritten,
    boluses: day.boluses,
    basal: day.basal,
    carbs: day.carbs,
    settings: day.settings,
    context: day.context,
  );
}
