import 'package:bgdude/analytics/basal_reconstruction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 7, 5, 8);

  test('merges equal contiguous rates and splits on change', () {
    final obs = [
      (time: t0, unitsPerHour: 0.8),
      (time: t0.add(const Duration(minutes: 5)), unitsPerHour: 0.8),
      (time: t0.add(const Duration(minutes: 10)), unitsPerHour: 0.8),
      (time: t0.add(const Duration(minutes: 15)), unitsPerHour: 1.2),
      (time: t0.add(const Duration(minutes: 20)), unitsPerHour: 1.2),
    ];
    final segs = const BasalReconstructor()
        .reconstruct(obs, until: t0.add(const Duration(minutes: 25)));
    expect(segs, hasLength(2));
    expect(segs.first.unitsPerHour, 0.8);
    expect(segs.first.start, t0);
    expect(segs.first.end, t0.add(const Duration(minutes: 15)));
    expect(segs.last.unitsPerHour, 1.2);
  });

  test('caps a segment at maxGap across a long data gap', () {
    final obs = [
      (time: t0, unitsPerHour: 0.9),
      (time: t0.add(const Duration(hours: 3)), unitsPerHour: 0.9),
    ];
    final segs = const BasalReconstructor(maxGap: Duration(minutes: 30))
        .reconstruct(obs, until: t0.add(const Duration(hours: 3)));
    // First segment is capped at 30 min, not stretched across the 3h gap.
    expect(segs.first.end, t0.add(const Duration(minutes: 30)));
  });

  test('total units integrates rate over time', () {
    final obs = [(time: t0, unitsPerHour: 1.0)];
    final segs = const BasalReconstructor()
        .reconstruct(obs, until: t0.add(const Duration(minutes: 30)));
    expect(segs.single.totalUnits, closeTo(0.5, 1e-9)); // 1 U/h for 30 min
  });

  test('empty input yields no segments', () {
    expect(const BasalReconstructor().reconstruct(const []), isEmpty);
  });
}
