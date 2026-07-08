/// The illness severity→boost mapping and mood note strings are domain
/// policy — pinned here so a widget refactor can't silently change a clinical
/// multiplier.
library;

import 'package:bgdude/state/quick_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('illness severity maps to the expected resistance boosts', () {
    expect(IllnessSeverity.mild.resistanceBoost, 1.1);
    expect(IllnessSeverity.moderate.resistanceBoost, 1.2);
    expect(IllnessSeverity.severe.resistanceBoost, 1.35);
  });

  test('boosts are monotonic in severity and stay conservative', () {
    final boosts = [
      for (final s in IllnessSeverity.values) s.resistanceBoost,
    ];
    for (var i = 1; i < boosts.length; i++) {
      expect(boosts[i], greaterThan(boosts[i - 1]));
    }
    expect(boosts.first, greaterThan(1.0));
    expect(boosts.last, lessThanOrEqualTo(1.5));
  });

  test('mood notes keep the pre-extraction strings (annotation compatibility)', () {
    expect(MoodLevel.good.note, 'Good');
    expect(MoodLevel.ok.note, 'OK');
    expect(MoodLevel.low.note, 'Low');
  });
}
