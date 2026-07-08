/// The promotion gate judges each horizon on its own evidence — pooled
/// stats let a candidate that improves the short horizon but regresses the
/// clinically important long one ship. Promotion is all-pass across trained
/// horizons (one persisted blob; no per-horizon promotion).
library;

import 'package:bgdude/ml/model_registry.dart';
import 'package:flutter_test/flutter_test.dart';

ModelEvaluation _eval({required double rmse, int samples = 200}) =>
    ModelEvaluation(
      rmseMgdl: rmse,
      abFraction: 1.0,
      dangerousFraction: 0.0,
      hypoSensitivity: null,
      hypoFalseAlarmRate: null,
      sampleCount: samples,
    );

void main() {
  const gate = PromotionGate(minSampleCount: 96);

  test('improving every horizon promotes', () {
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {30: _eval(rmse: 18), 120: _eval(rmse: 30)},
      baselineByHorizon: {30: _eval(rmse: 22), 120: _eval(rmse: 36)},
      incumbentByHorizon: {30: _eval(rmse: 20), 120: _eval(rmse: 34)},
      trainedHorizons: const [30, 120],
    );
    expect(d.promoted, isTrue);
    expect(d.reasons, isEmpty);
  });

  test('winning the short horizon but regressing the long one is NOT promoted',
      () {
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {30: _eval(rmse: 16), 120: _eval(rmse: 40)},
      baselineByHorizon: {30: _eval(rmse: 22), 120: _eval(rmse: 36)},
      incumbentByHorizon: {30: _eval(rmse: 20), 120: _eval(rmse: 34)},
      trainedHorizons: const [30, 120],
    );
    expect(d.promoted, isFalse);
    expect(d.reasons, contains('no RMSE improvement over the active model'));
    // The per-horizon gate itself also flags the regression beyond tolerance.
    expect(d.reasons.any((r) => r.startsWith('120m:')), isTrue);
  });

  test('minSampleCount applies PER horizon, not on the pool', () {
    // 200 + 40 pooled would clear a 96 minimum; the thin long horizon must fail.
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {
        30: _eval(rmse: 16, samples: 200),
        120: _eval(rmse: 30, samples: 40),
      },
      baselineByHorizon: {30: _eval(rmse: 22), 120: _eval(rmse: 36)},
      trainedHorizons: const [30, 120],
    );
    expect(d.promoted, isFalse);
    expect(
        d.reasons.any(
            (r) => r.startsWith('120m:') && r.contains('insufficient held-out')),
        isTrue);
  });

  test('an untrained horizon keeps baseline behaviour and is not gated', () {
    // The candidate only trained 30-min; 120-min stays baseline — that is not a
    // regression, so promotion is judged on the trained horizon alone.
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {30: _eval(rmse: 16), 120: _eval(rmse: 36)},
      baselineByHorizon: {30: _eval(rmse: 22), 120: _eval(rmse: 36)},
      trainedHorizons: const [30],
    );
    expect(d.promoted, isTrue);
  });

  test('a tie with the incumbent never ships', () {
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {30: _eval(rmse: 20)},
      baselineByHorizon: {30: _eval(rmse: 24)},
      incumbentByHorizon: {30: _eval(rmse: 20)},
      trainedHorizons: const [30],
    );
    expect(d.promoted, isFalse);
    expect(d.reasons, contains('no RMSE improvement over the active model'));
  });

  test('no trained horizons -> not promoted with a clear reason', () {
    final d = gate.decideAcrossHorizons(
      candidateByHorizon: {30: _eval(rmse: 16)},
      baselineByHorizon: {30: _eval(rmse: 22)},
      trainedHorizons: const [],
    );
    expect(d.promoted, isFalse);
    expect(d.reasons, contains('no trained horizons to gate'));
  });
}
