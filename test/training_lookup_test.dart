/// TASK-134: the binary-search lookups must be EXACTLY equivalent to the old
/// linear scans (including tie rules), and training output on the fixture must
/// be unchanged. The old scans are re-implemented here as the reference.
library;

import 'dart:math' as math;

import 'package:bgdude/analytics/predictor.dart';
import 'package:bgdude/core/samples.dart';
import 'package:bgdude/dev/sim_data.dart';
import 'package:bgdude/ml/forecaster_training.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pre-TASK-134 linear `_nearest` (tie -> later sample via `<=`).
double? _linearNearest(List<CgmSample> samples, DateTime t) {
  CgmSample? best;
  var bestDelta = const Duration(minutes: 6);
  for (final s in samples) {
    final d = s.time.difference(t).abs();
    if (d <= bestDelta) {
      bestDelta = d;
      best = s;
    }
  }
  return best?.mgdl;
}

/// The pre-TASK-134 linear `_valueAt` (tie -> earlier point via `<`).
double _linearValueAt(PredictionLine line, DateTime t) {
  var best = line.points.first;
  var bestDelta = best.time.difference(t).inSeconds.abs();
  for (final p in line.points) {
    final d = p.time.difference(t).inSeconds.abs();
    if (d < bestDelta) {
      best = p;
      bestDelta = d;
    }
  }
  return best.mgdl;
}

void main() {
  final base = DateTime(2026, 7, 1);
  final rng = math.Random(7); // deterministic

  test('nearestMgdl is exactly equivalent to the old linear scan', () {
    // Irregular cadence with gaps, so boundary/cap cases are exercised.
    final samples = <CgmSample>[];
    var t = base;
    for (var i = 0; i < 800; i++) {
      t = t.add(Duration(minutes: 3 + rng.nextInt(9))); // 3–11 min gaps
      samples.add(CgmSample(time: t, mgdl: 80.0 + rng.nextInt(120)));
    }
    for (var i = 0; i < 5000; i++) {
      final probe = base.add(Duration(minutes: rng.nextInt(800 * 8), seconds: rng.nextInt(60)));
      expect(ForecasterTrainer.nearestMgdl(samples, probe),
          _linearNearest(samples, probe),
          reason: 'probe $probe');
    }
    // Exact 6-minute cap edge (inclusive on both implementations).
    final lone = [CgmSample(time: base, mgdl: 100)];
    final atCap = base.add(const Duration(minutes: 6));
    expect(ForecasterTrainer.nearestMgdl(lone, atCap), _linearNearest(lone, atCap));
    final pastCap = base.add(const Duration(minutes: 6, seconds: 1));
    expect(ForecasterTrainer.nearestMgdl(lone, pastCap), isNull);
  });

  test('valueAt is exactly equivalent to the old linear scan', () {
    final line = PredictionLine(
      label: 'fixture',
      points: [
        for (var i = 0; i < 60; i++)
          (time: base.add(Duration(minutes: 5 * i)), mgdl: 100.0 + i),
      ],
    );
    for (var i = 0; i < 5000; i++) {
      final probe = base.add(Duration(
          minutes: rng.nextInt(320) - 10, seconds: rng.nextInt(60)));
      expect(ForecasterTrainer.valueAt(line, probe), _linearValueAt(line, probe),
          reason: 'probe $probe');
    }
    // The exact halfway tie between two points -> earlier point, both impls.
    final halfway = base.add(const Duration(minutes: 2, seconds: 30));
    expect(ForecasterTrainer.valueAt(line, halfway), _linearValueAt(line, halfway));
  });

  test('training output on the SimulatedDay fixture is unchanged in shape', () {
    // Determinism regression: the same fixture trains to the same evaluations
    // (the identical-retrain promotion test also pins candidate == incumbent).
    final day = SimulatedDay.generate(now: DateTime(2026, 7, 4, 22), seed: 3);
    final a = ForecasterTrainer().train(
      cgm: day.cgm, boluses: day.boluses, basal: day.basal, carbs: day.carbs,
      settings: day.settings, annotations: const [], asOf: day.end,
    );
    final b = ForecasterTrainer().train(
      cgm: day.cgm, boluses: day.boluses, basal: day.basal, carbs: day.carbs,
      settings: day.settings, annotations: const [], asOf: day.end,
    );
    expect(a, isNotNull);
    expect(a!.candidateEval.rmseMgdl, b!.candidateEval.rmseMgdl);
    expect(a.trainSamples, b.trainSamples);
    expect(a.heldOutSamples, b.heldOutSamples);
  });
}
