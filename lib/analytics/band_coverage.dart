/// Forecast-band trust: what fraction of recent predictions had the actual reading land
/// inside the predicted [lower, upper] band (TASK-56). A well-calibrated 90% band should
/// catch ~9 of 10. Pure — fed reconciled predictions, computes coverage.
library;

class BandCoverage {
  const BandCoverage({required this.covered, required this.total});

  /// Reconciled predictions whose actual reading fell within the band.
  final int covered;

  /// Reconciled predictions scored in the window.
  final int total;

  /// 0..1; 0 when nothing has been scored yet.
  double get fraction => total == 0 ? 0 : covered / total;

  bool get hasData => total > 0;
}

/// Coverage over the given reconciled predictions. Each item is `(actual, lower, upper)` in
/// mg/dL; items with a null [actual] (not yet reconciled) are ignored.
BandCoverage computeBandCoverage(
    Iterable<({double? actual, double lower, double upper})> predictions) {
  var covered = 0;
  var total = 0;
  for (final p in predictions) {
    final a = p.actual;
    if (a == null) continue;
    total++;
    if (a >= p.lower && a <= p.upper) covered++;
  }
  return BandCoverage(covered: covered, total: total);
}
