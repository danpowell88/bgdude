/// TASK-131: the local wall-clock contract for time-of-day features. UTC
/// timestamps (e.g. parsed Nightscout ISO strings) must be converted ONCE at
/// ingest; the ml boundary asserts against leaks; and bucketing is by wall
/// clock, so the same local time lands in the same bucket across a DST change.
library;

import 'package:bgdude/core/samples.dart';
import 'package:bgdude/ml/forecast_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CgmSample normalizes a UTC ingest time to local (same instant)', () {
    final utc = DateTime.utc(2026, 7, 4, 2, 0); // e.g. a Nightscout dateString
    final s = CgmSample(time: utc, mgdl: 120);
    expect(s.time.isUtc, isFalse, reason: 'stored time must be wall-clock');
    expect(s.time.millisecondsSinceEpoch, utc.millisecondsSinceEpoch,
        reason: 'conversion changes representation, never the instant');
  });

  test('a local ingest time passes through untouched', () {
    final local = DateTime(2026, 7, 4, 12, 0);
    expect(CgmSample(time: local, mgdl: 120).time, local);
  });

  test('feature build asserts on a UTC timestamp (debug leak detector)', () {
    expect(
      () => ForecastFeatures.build(
        now: DateTime.utc(2026, 7, 4, 2),
        currentMgdl: 120,
        recentRocMgdlPerMin: 0,
        boluses: const [],
        basal: const [],
        carbs: const [],
        horizonMinutes: 30,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('hour features depend on wall clock only — same across a DST change', () {
    // 07:00 the day before and the day after a DST transition are different
    // UTC instants, but the SAME wall-clock bucket — the documented intent
    // (fixed local buckets, dawn phenomenon is a wall-clock effect).
    List<double> at(DateTime t) => ForecastFeatures.build(
          now: t,
          currentMgdl: 120,
          recentRocMgdlPerMin: 0,
          boluses: const [],
          basal: const [],
          carbs: const [],
          horizonMinutes: 30,
        );
    // Sydney 2026 DST starts Oct 4; wall-clock 07:00 either side.
    final before = at(DateTime(2026, 10, 3, 7, 0));
    final after = at(DateTime(2026, 10, 5, 7, 0));
    // hour_sin / hour_cos are feature slots 4 and 5.
    expect(before[4], after[4]);
    expect(before[5], after[5]);
  });
}
