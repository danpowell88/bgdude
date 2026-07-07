/// Minimal, dependency-free gradient-boosted regression trees (GBM) in pure Dart.
///
/// Chosen for the learned residual because it captures nonlinear feature
/// interactions (dawn phenomenon × time-of-day, exercise × IOB, …) that the
/// linear/ridge models cannot, while staying fully on-device, auditable, and free
/// of any native runtime. Shallow CART trees (default depth 3) are boosted under
/// squared-error loss with a small learning rate; splits are chosen greedily on the
/// best weighted variance reduction. The whole ensemble JSON-serialises so a nightly
/// training job can persist it and the app can load it back deterministically.
///
/// Deterministic by construction — there is no randomness (no feature/row
/// subsampling), so identical inputs always produce identical models and tests are
/// stable.
library;

import 'dart:math' as math;

/// Thrown when a persisted model blob fails structural validation (TASK-128) —
/// out-of-range child indices or feature slots would otherwise decode fine and
/// crash with a RangeError at predict time on the live forecast path.
class ModelFormatException extends FormatException {
  const ModelFormatException(super.message);
}

/// A single node in a CART regression tree. Internal nodes carry a split
/// (feature/threshold + child indices); leaves carry a constant [value].
class TreeNode {
  TreeNode.leaf(this.value)
      : feature = -1,
        threshold = 0.0,
        left = -1,
        right = -1;

  TreeNode.split({
    required this.feature,
    required this.threshold,
    required this.left,
    required this.right,
  }) : value = 0.0;

  TreeNode._({
    required this.feature,
    required this.threshold,
    required this.left,
    required this.right,
    required this.value,
  });

  /// Split feature index, or -1 for a leaf.
  final int feature;
  final double threshold;

  /// Child node indices within the owning tree's node list (-1 for a leaf).
  final int left;
  final int right;

  /// Prediction for a leaf (unused for internal nodes).
  final double value;

  bool get isLeaf => feature < 0;

  Map<String, dynamic> toJson() => {
        'f': feature,
        't': threshold,
        'l': left,
        'r': right,
        'v': value,
      };

  static TreeNode fromJson(Map<String, dynamic> j) => TreeNode._(
        feature: (j['f'] as num).toInt(),
        threshold: (j['t'] as num).toDouble(),
        left: (j['l'] as num).toInt(),
        right: (j['r'] as num).toInt(),
        value: (j['v'] as num).toDouble(),
      );
}

/// A flat-array CART regression tree. Node 0 is the root.
class RegressionTree {
  RegressionTree(this.nodes);

  final List<TreeNode> nodes;

  double predict(List<double> features) {
    if (nodes.isEmpty) return 0.0;
    var i = 0;
    // Bounded by depth; guard against malformed trees just in case.
    for (var guard = 0; guard < nodes.length + 1; guard++) {
      final n = nodes[i];
      if (n.isLeaf) return n.value;
      i = features[n.feature] <= n.threshold ? n.left : n.right;
    }
    return nodes[i].value;
  }

  Map<String, dynamic> toJson() =>
      {'nodes': nodes.map((n) => n.toJson()).toList()};

  static RegressionTree fromJson(Map<String, dynamic> j) => RegressionTree(
        (j['nodes'] as List)
            .map((e) => TreeNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Gradient-boosted regression trees under squared-error loss.
class GbmRegressor {
  GbmRegressor({
    this.maxDepth = 3,
    this.nEstimators = 50,
    this.learningRate = 0.1,
    this.minSamplesLeaf = 5,
  })  : _base = 0.0,
        _trees = [];

  GbmRegressor._({
    required this.maxDepth,
    required this.nEstimators,
    required this.learningRate,
    required this.minSamplesLeaf,
    required double base,
    required List<RegressionTree> trees,
  })  : _base = base,
        _trees = trees;

  final int maxDepth;
  final int nEstimators;
  final double learningRate;

  /// Minimum weighted "row count" (number of samples) allowed in a leaf.
  final int minSamplesLeaf;

  /// Initial constant prediction (weighted mean of the targets).
  double _base;
  final List<RegressionTree> _trees;

  bool get isTrained => _trees.isNotEmpty;
  int get treeCount => _trees.length;

  /// Fit the ensemble. Optional [sampleWeights] scale each row's contribution to
  /// the squared-error loss (used by the feedback pipeline to down-weight stale or
  /// low-confidence samples).
  void fit(
    List<List<double>> x,
    List<double> y, {
    List<double>? sampleWeights,
  }) {
    final n = x.length;
    assert(n == y.length && n > 0);
    final w = sampleWeights ?? List<double>.filled(n, 1.0);
    assert(w.length == n);

    _trees.clear();

    // Initial prediction: weighted mean minimises squared error.
    var wSum = 0.0;
    var wy = 0.0;
    for (var i = 0; i < n; i++) {
      wSum += w[i];
      wy += w[i] * y[i];
    }
    _base = wSum > 0 ? wy / wSum : 0.0;

    // Running predictions.
    final pred = List<double>.filled(n, _base);

    for (var m = 0; m < nEstimators; m++) {
      // Pseudo-residuals for squared error are simply (y - pred).
      final residual = List<double>.generate(n, (i) => y[i] - pred[i]);
      final tree = _fitTree(x, residual, w);
      // Update running predictions with the shrunken tree.
      for (var i = 0; i < n; i++) {
        pred[i] += learningRate * tree.predict(x[i]);
      }
      _trees.add(tree);
    }
  }

  double predict(List<double> features) {
    var sum = _base;
    for (final t in _trees) {
      sum += learningRate * t.predict(features);
    }
    return sum;
  }

  // ---- Tree fitting (greedy CART, weighted squared error) ----

  RegressionTree _fitTree(
    List<List<double>> x,
    List<double> target,
    List<double> w,
  ) {
    final nodes = <TreeNode>[];
    final indices = List<int>.generate(x.length, (i) => i);
    _buildNode(nodes, x, target, w, indices, 0);
    return RegressionTree(nodes);
  }

  /// Recursively build a subtree over [rows]; returns the index of the created
  /// node in [nodes].
  int _buildNode(
    List<TreeNode> nodes,
    List<List<double>> x,
    List<double> target,
    List<double> w,
    List<int> rows,
    int depth,
  ) {
    final leafValue = _weightedMean(target, w, rows);

    // Reserve this node's slot so children get later indices.
    final myIndex = nodes.length;
    nodes.add(TreeNode.leaf(leafValue));

    if (depth >= maxDepth || rows.length <= 1) {
      return myIndex;
    }

    final split = _bestSplit(x, target, w, rows);
    if (split == null) {
      return myIndex; // no useful split; stay a leaf.
    }

    final leftRows = <int>[];
    final rightRows = <int>[];
    for (final r in rows) {
      if (x[r][split.feature] <= split.threshold) {
        leftRows.add(r);
      } else {
        rightRows.add(r);
      }
    }
    // Guard: a degenerate split (all on one side) — keep as leaf.
    if (leftRows.isEmpty || rightRows.isEmpty) {
      return myIndex;
    }

    final leftIndex =
        _buildNode(nodes, x, target, w, leftRows, depth + 1);
    final rightIndex =
        _buildNode(nodes, x, target, w, rightRows, depth + 1);

    nodes[myIndex] = TreeNode.split(
      feature: split.feature,
      threshold: split.threshold,
      left: leftIndex,
      right: rightIndex,
    );
    return myIndex;
  }

  /// Best (feature, threshold) by weighted squared-error reduction, or null.
  _Split? _bestSplit(
    List<List<double>> x,
    List<double> target,
    List<double> w,
    List<int> rows,
  ) {
    final d = x.first.length;

    // Parent weighted sums.
    var parentW = 0.0;
    var parentWy = 0.0;
    for (final r in rows) {
      parentW += w[r];
      parentWy += w[r] * target[r];
    }
    if (parentW <= 0) return null;

    _Split? best;
    var bestGain = 0.0;

    for (var f = 0; f < d; f++) {
      // Sort rows by this feature's value (deterministic).
      final sorted = List<int>.of(rows)
        ..sort((a, b) => x[a][f].compareTo(x[b][f]));

      var leftW = 0.0;
      var leftWy = 0.0;
      var leftCount = 0;

      for (var k = 0; k < sorted.length - 1; k++) {
        final r = sorted[k];
        leftW += w[r];
        leftWy += w[r] * target[r];
        leftCount++;

        final vCur = x[r][f];
        final vNext = x[sorted[k + 1]][f];
        // Only split between distinct feature values.
        if (vCur == vNext) continue;

        final rightCount = rows.length - leftCount;
        if (leftCount < minSamplesLeaf || rightCount < minSamplesLeaf) {
          continue;
        }

        final rightW = parentW - leftW;
        final rightWy = parentWy - leftWy;
        if (leftW <= 0 || rightW <= 0) continue;

        // Weighted SSE reduction ∝ leftWy²/leftW + rightWy²/rightW − parentWy²/parentW.
        final gain = (leftWy * leftWy) / leftW +
            (rightWy * rightWy) / rightW -
            (parentWy * parentWy) / parentW;

        if (gain > bestGain + 1e-12) {
          bestGain = gain;
          best = _Split(
            feature: f,
            threshold: (vCur + vNext) / 2.0,
          );
        }
      }
    }
    return best;
  }

  static double _weightedMean(
    List<double> target,
    List<double> w,
    List<int> rows,
  ) {
    var sw = 0.0;
    var swy = 0.0;
    for (final r in rows) {
      sw += w[r];
      swy += w[r] * target[r];
    }
    return sw > 0 ? swy / sw : 0.0;
  }

  // ---- Persistence ----

  Map<String, dynamic> toJson() => {
        'maxDepth': maxDepth,
        'nEstimators': nEstimators,
        'learningRate': learningRate,
        'minSamplesLeaf': minSamplesLeaf,
        'base': _base,
        'trees': _trees.map((t) => t.toJson()).toList(),
      };

  /// Decode a persisted model. TASK-128: the structure is VALIDATED here — child
  /// indices in range and (when [featureCount] is given) every split feature within
  /// the expected vector length — throwing [ModelFormatException] so the store can
  /// fail safe at load time instead of a RangeError on the live forecast path.
  static GbmRegressor fromJson(Map<String, dynamic> j, {int? featureCount}) {
    final model = GbmRegressor._(
      maxDepth: (j['maxDepth'] as num).toInt(),
      nEstimators: (j['nEstimators'] as num).toInt(),
      learningRate: (j['learningRate'] as num).toDouble(),
      minSamplesLeaf: (j['minSamplesLeaf'] as num).toInt(),
      base: (j['base'] as num).toDouble(),
      trees: (j['trees'] as List)
          .map((e) => RegressionTree.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    model._validateStructure(featureCount);
    return model;
  }

  void _validateStructure(int? featureCount) {
    for (var t = 0; t < _trees.length; t++) {
      final nodes = _trees[t].nodes;
      for (var i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        if (n.isLeaf) continue;
        if (n.left < 0 ||
            n.left >= nodes.length ||
            n.right < 0 ||
            n.right >= nodes.length) {
          throw ModelFormatException(
              'tree $t node $i: child index out of range '
              '(left=${n.left}, right=${n.right}, nodes=${nodes.length})');
        }
        if (featureCount != null && n.feature >= featureCount) {
          throw ModelFormatException(
              'tree $t node $i: split feature ${n.feature} out of range for '
              'featureCount $featureCount');
        }
      }
    }
  }

  /// Weighted RMSE of the model on a dataset (used to estimate residual sigma).
  double weightedRmse(
    List<List<double>> x,
    List<double> y, {
    List<double>? sampleWeights,
  }) {
    final n = x.length;
    if (n == 0) return 0.0;
    final w = sampleWeights ?? List<double>.filled(n, 1.0);
    var sw = 0.0;
    var se = 0.0;
    for (var i = 0; i < n; i++) {
      final e = y[i] - predict(x[i]);
      sw += w[i];
      se += w[i] * e * e;
    }
    return sw > 0 ? math.sqrt(se / sw) : 0.0;
  }
}

class _Split {
  const _Split({required this.feature, required this.threshold});
  final int feature;
  final double threshold;
}
