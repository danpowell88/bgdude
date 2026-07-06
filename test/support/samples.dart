/// Shared test fixtures (TASK-108): CGM trace builders and a canonical therapy profile,
/// so tests stop hand-rolling subtly-different copies. Each builder documents the exact
/// cadence/endpoint semantics of the historical private helper it replaces, so migrated
/// tests keep identical sample sets (and therefore identical assertions).
library;

import 'package:bgdude/analytics/therapy_settings.dart';
import 'package:bgdude/core/samples.dart';

/// Canonical single-segment therapy profile used across the advisor/detector tests:
/// ISF 50 mg/dL/U, carb ratio 10 g/U (⇒ carb-sensitivity 5 mg/dL/g), target 100 mg/dL,
/// basal 0.8 U/h, effective all day. [maxBolusUnits] defaults to the model default (25);
/// pass 15 to match the advisor/event tests that pinned a tighter max.
TherapySettings testTherapySettings({double maxBolusUnits = 25}) => TherapySettings(
      segments: const [
        TherapySegment(
          startMinuteOfDay: 0,
          isf: 50,
          carbRatio: 10,
          targetMgdl: 100,
          basalUnitsPerHour: 0.8,
        ),
      ],
      maxBolusUnits: maxBolusUnits,
    );

/// [count] samples from [start] at [stepMin]-minute cadence, each valued by [mgdl](i).
/// The general-purpose builder the others delegate to.
List<CgmSample> sampleEvery5min({
  required DateTime start,
  required int count,
  required double Function(int i) mgdl,
  int stepMin = 5,
  bool sensorWarmup = false,
}) =>
    [
      for (var i = 0; i < count; i++)
        CgmSample(
          time: start.add(Duration(minutes: stepMin * i)),
          mgdl: mgdl(i),
          sensorWarmup: sensorWarmup,
        ),
    ];

/// A flat trace at [mgdl] for [count] samples (every [stepMin] min from [start]).
List<CgmSample> flatTrace({
  required DateTime start,
  required int count,
  required double mgdl,
  int stepMin = 5,
  bool sensorWarmup = false,
}) =>
    sampleEvery5min(
      start: start,
      count: count,
      mgdl: (_) => mgdl,
      stepMin: stepMin,
      sensorWarmup: sensorWarmup,
    );

/// A linear trace from [fromMgdl] to [toMgdl] over [minutes], every 5 min, **inclusive**
/// of both endpoints (yields `minutes ~/ 5 + 1` samples). Matches the historical `_linear`.
List<CgmSample> linear({
  required DateTime start,
  required double fromMgdl,
  required double toMgdl,
  required int minutes,
}) {
  final steps = minutes ~/ 5;
  final perStep = (toMgdl - fromMgdl) / steps;
  return [
    for (var i = 0; i <= steps; i++)
      CgmSample(
        time: start.add(Duration(minutes: 5 * i)),
        mgdl: fromMgdl + perStep * i,
      ),
  ];
}

/// A linear rise from [startMgdl] to [peakMgdl] over [riseMinutes] (inclusive), then a
/// flat plateau at [peakMgdl] for [plateauMinutes], every 5 min. Matches `_rampThenFlat`.
List<CgmSample> ramp({
  required DateTime start,
  required double startMgdl,
  required double peakMgdl,
  required int riseMinutes,
  required int plateauMinutes,
}) {
  final out = <CgmSample>[];
  final steps = riseMinutes ~/ 5;
  final perStep = (peakMgdl - startMgdl) / steps;
  for (var i = 0; i <= steps; i++) {
    out.add(CgmSample(
      time: start.add(Duration(minutes: 5 * i)),
      mgdl: startMgdl + perStep * i,
    ));
  }
  final plateauSteps = plateauMinutes ~/ 5;
  for (var j = 1; j <= plateauSteps; j++) {
    out.add(CgmSample(
      time: start.add(Duration(minutes: riseMinutes + 5 * j)),
      mgdl: peakMgdl,
    ));
  }
  return out;
}

/// [count] samples at a constant [mgdl] going **backward** from [end] at [stepMin]-minute
/// cadence (end, end−5, end−10, …). Matches the historical `_sustainedHigh(now, mgdl)`.
List<CgmSample> sustained({
  required DateTime end,
  required double mgdl,
  int count = 25,
  int stepMin = 5,
}) =>
    [
      for (var i = 0; i < count; i++)
        CgmSample(time: end.subtract(Duration(minutes: stepMin * i)), mgdl: mgdl),
    ];
