/// Estimates pump battery time-to-empty from the recent discharge slope. Deliberately a
/// robust heuristic, not ML: the t:slim X2 is a rechargeable Li-ion pump whose series is
/// non-monotonic (a charge resets it) and user-controlled, so a Theil–Sen slope over the
/// latest *not-charging* run gives an interpretable ETA that works from day one — an ML
/// model would need months of single-device, charge-segmented data to do no better.
library;

import 'battery_history.dart';

class BatteryDrainEstimate {
  const BatteryDrainEstimate({
    required this.hasEstimate,
    required this.charging,
    this.percentPerHour,
    this.timeToEmpty,
    this.emptyAt,
    this.currentPercent,
  });

  /// True when a usable discharge slope was found.
  final bool hasEstimate;

  /// True when the pump is currently charging (no drain ETA then).
  final bool charging;

  /// Discharge rate, percentage points per hour (positive).
  final double? percentPerHour;
  final Duration? timeToEmpty;
  final DateTime? emptyAt;
  final int? currentPercent;

  static const none =
      BatteryDrainEstimate(hasEstimate: false, charging: false);
  static const whileCharging =
      BatteryDrainEstimate(hasEstimate: false, charging: true);
}

class BatteryDrainEstimator {
  const BatteryDrainEstimator({
    this.minSamples = 4,
    this.minSpan = const Duration(minutes: 30),
    this.recentWindow = const Duration(hours: 12),
  });

  final int minSamples;
  final Duration minSpan;
  final Duration recentWindow;

  BatteryDrainEstimate estimate(List<BatterySample> samples,
      {required DateTime now}) {
    final recent = [
      for (final s in samples)
        if (now.difference(s.time) <= recentWindow) s,
    ]..sort((a, b) => a.time.compareTo(b.time));
    if (recent.isEmpty) return BatteryDrainEstimate.none;

    // If the pump is charging right now, there's no drain ETA.
    if (recent.last.charging == true) return BatteryDrainEstimate.whileCharging;

    // Take the latest contiguous discharge run: walk back while not charging and the
    // percent isn't rising (a rise means a charge happened).
    final run = <BatterySample>[recent.last];
    for (var i = recent.length - 2; i >= 0; i--) {
      final s = recent[i];
      if (s.charging == true) break;
      if (s.percent < run.first.percent) break; // percent rose forward → charge event
      run.insert(0, s);
    }
    if (run.length < minSamples) return BatteryDrainEstimate.none;
    if (run.last.time.difference(run.first.time) < minSpan) {
      return BatteryDrainEstimate.none;
    }

    final slope = _theilSen(run); // %/hour, negative while discharging
    if (slope >= 0) return BatteryDrainEstimate.none; // not discharging

    final rate = -slope; // positive drain rate
    final current = run.last.percent;
    final hours = current / rate;
    final tte = Duration(minutes: (hours * 60).round());
    return BatteryDrainEstimate(
      hasEstimate: true,
      charging: false,
      percentPerHour: rate,
      timeToEmpty: tte,
      emptyAt: now.add(tte),
      currentPercent: current,
    );
  }

  /// Theil–Sen slope: median of the pairwise slopes, robust to a few odd readings.
  static double _theilSen(List<BatterySample> run) {
    final slopes = <double>[];
    for (var i = 0; i < run.length; i++) {
      for (var j = i + 1; j < run.length; j++) {
        final dh = run[j].time.difference(run[i].time).inSeconds / 3600.0;
        if (dh <= 0) continue;
        slopes.add((run[j].percent - run[i].percent) / dh);
      }
    }
    if (slopes.isEmpty) return 0;
    slopes.sort();
    final mid = slopes.length ~/ 2;
    return slopes.length.isOdd
        ? slopes[mid]
        : (slopes[mid - 1] + slopes[mid]) / 2;
  }
}
