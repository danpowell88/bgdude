/// TASK-195: a large CGM history generator for stress-testing report/metrics/training
/// paths at realistic multi-year scale (a year of 5-minute CGM is ~105k rows) — several
/// of those paths recompute over the full list, and nothing had exercised them past a
/// single simulated day until now.
library;

import 'dart:math' as math;

import 'package:bgdude/core/samples.dart';

import 'samples.dart';

/// [days] of 5-minute CGM readings from [start], following a smooth day/night sine
/// wave (not flat — flat data trivially degenerates CV/AGP-percentile computation,
/// masking exactly the kind of bug this stress test exists to catch) plus a small
/// per-sample wobble so no two days are bit-identical.
List<CgmSample> yearsOfCgm({required DateTime start, int days = 365}) {
  const minutesPerDay = 24 * 60;
  final rnd = math.Random(7);
  const perDay = minutesPerDay ~/ 5;
  return sampleEvery5min(
    start: start,
    count: days * perDay,
    mgdl: (i) {
      final minuteOfDay = (i % perDay) * 5;
      final dayPhase = math.sin(minuteOfDay / minutesPerDay * 2 * math.pi);
      final wobble = rnd.nextDouble() * 20 - 10;
      return (140 + dayPhase * 40 + wobble).clamp(45, 380);
    },
  );
}
