/// Minimal, dependency-free ridge (L2-regularised linear) regression in pure Dart.
///
/// Chosen for the sensitivity/context models because it is fully auditable (you can
/// read the coefficients), trivially retrainable on-device, needs no native runtime,
/// and behaves well with the small, noisy per-user datasets we start with. Solved via
/// the normal equations with a small ridge term, using Gaussian elimination (feature
/// counts here are tiny — a handful of context features).
library;

import 'dart:math' as math;

class RidgeModel {
  RidgeModel({
    required this.weights,
    required this.bias,
    required this.featureMeans,
    required this.featureStds,
  });

  /// Coefficients on the *standardised* features.
  final List<double> weights;
  final double bias;

  /// Standardisation params captured at fit time (applied at predict time).
  final List<double> featureMeans;
  final List<double> featureStds;

  double predict(List<double> features) {
    assert(features.length == weights.length);
    var sum = bias;
    for (var i = 0; i < features.length; i++) {
      final std = featureStds[i] == 0 ? 1.0 : featureStds[i];
      final z = (features[i] - featureMeans[i]) / std;
      sum += weights[i] * z;
    }
    return sum;
  }

  /// Coefficient magnitudes on standardised features → relative feature importance.
  Map<int, double> get importance {
    return {for (var i = 0; i < weights.length; i++) i: weights[i].abs()};
  }

  Map<String, dynamic> toJson() => {
        'weights': weights,
        'bias': bias,
        'featureMeans': featureMeans,
        'featureStds': featureStds,
      };

  static RidgeModel fromJson(Map<String, dynamic> j) => RidgeModel(
        weights: (j['weights'] as List).map((e) => (e as num).toDouble()).toList(),
        bias: (j['bias'] as num).toDouble(),
        featureMeans:
            (j['featureMeans'] as List).map((e) => (e as num).toDouble()).toList(),
        featureStds:
            (j['featureStds'] as List).map((e) => (e as num).toDouble()).toList(),
      );
}

class RidgeRegression {
  const RidgeRegression({this.lambda = 1.0});

  /// L2 penalty strength. Higher = more shrinkage toward the mean (safer with noise).
  final double lambda;

  /// Fit with optional per-sample weights (used by the robust/feedback pipeline to
  /// down-weight annotated-bad or stale samples).
  RidgeModel fit(
    List<List<double>> x,
    List<double> y, {
    List<double>? sampleWeights,
  }) {
    final n = x.length;
    assert(n == y.length && n > 0);
    final d = x.first.length;
    final w = sampleWeights ?? List<double>.filled(n, 1.0);

    // Standardise features (weighted mean/std).
    final means = List<double>.filled(d, 0);
    final stds = List<double>.filled(d, 0);
    var wSum = 0.0;
    for (var i = 0; i < n; i++) {
      wSum += w[i];
    }
    for (var j = 0; j < d; j++) {
      var m = 0.0;
      for (var i = 0; i < n; i++) {
        m += w[i] * x[i][j];
      }
      m /= wSum;
      means[j] = m;
      var v = 0.0;
      for (var i = 0; i < n; i++) {
        final dxj = x[i][j] - m;
        v += w[i] * dxj * dxj;
      }
      stds[j] = math.sqrt(v / wSum);
    }

    // Build standardised design matrix with intercept column.
    final z = List.generate(n, (i) {
      final row = List<double>.filled(d + 1, 0);
      row[0] = 1.0; // intercept
      for (var j = 0; j < d; j++) {
        final s = stds[j] == 0 ? 1.0 : stds[j];
        row[j + 1] = (x[i][j] - means[j]) / s;
      }
      return row;
    });

    // Normal equations: (ZᵀWZ + λI') β = ZᵀWy, no penalty on intercept.
    final p = d + 1;
    final ata = List.generate(p, (_) => List<double>.filled(p, 0));
    final aty = List<double>.filled(p, 0);
    for (var i = 0; i < n; i++) {
      for (var a = 0; a < p; a++) {
        final za = z[i][a] * w[i];
        aty[a] += za * y[i];
        for (var b = 0; b < p; b++) {
          ata[a][b] += za * z[i][b];
        }
      }
    }
    for (var a = 1; a < p; a++) {
      ata[a][a] += lambda; // ridge, skip intercept
    }

    final beta = _solve(ata, aty);
    return RidgeModel(
      weights: beta.sublist(1),
      bias: beta[0],
      featureMeans: means,
      featureStds: stds,
    );
  }

  /// Gaussian elimination with partial pivoting for the small normal-equation system.
  static List<double> _solve(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = List.generate(n, (i) => [...a[i], b[i]]);
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
      final pv = m[col][col];
      if (pv.abs() < 1e-12) continue; // singular-ish; leave row
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = m[r][col] / pv;
        for (var c = col; c <= n; c++) {
          m[r][c] -= factor * m[col][c];
        }
      }
    }
    return List.generate(
        n, (i) => m[i][i].abs() < 1e-12 ? 0.0 : m[i][n] / m[i][i]);
  }
}
